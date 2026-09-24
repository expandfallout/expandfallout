# 23 - Looting

A GECK equivalent: admins author loot tables and place containers **in game**,
without writing Lua. Library `schema/libs/sh_loot.lua`, server half
`sv_loot.lua`, entity `ix_lootable`, looting window `derma/cl_loot.lua`,
configurer `derma/cl_lootconfig.lua`.

`/lootconfig` opens the editor. `fo_loot_report` prints what exists and whether
it would actually produce anything.

---

## The model: their four modes, made one setting

Their export carries `useAll`, `calcToLevel` and `calcAllInCount` as three
separate booleans, which reads like three independent options. Their editor
gives it away — ticking any one **disables the other two**:

```lua
self.calcFromLevel.OnChange = function(s)
    if s:GetChecked() then self.useAll:SetChecked(false) end
    self.useAll:SetDisabled(self.calcForEach:GetChecked() or checked)
                -- geck/derma/cl_geck_loottableeditor.lua
```

So it is one setting with four states, and it is stored that way — a `mode`.
Three booleans that cannot co-exist is a shape that lets you save nonsense.

| Mode | What it does |
|---|---|
| `one` | one entry, chosen by weight (their default) |
| `all` | every entry (`useAll`) |
| `rolls` | N independent picks (`calcAllInCount`) |
| `level` | one entry from those the looter's level allows (`calcToLevel`) |

```lua
{
    name = "Looter_Weapons", spawnChance = 100, mode = "one", rolls = 1,
    items = {
        {class = "weapon_10mm_pistol", weight = 10, chance = 100, min = 1, max = 1, level = 1},
        {table = "Looter_Ammo",        weight = 1,  chance = 50,  min = 1, max = 3, level = 1},
    }
}
```

### What this adds that the GECK could not do

Their entries carry a flat `count` and nothing else, so every entry in a table
was equally likely and always gave the same amount. Here each entry also has:

- **`weight`** — relative likelihood when one is picked, so a common item can be
  ten times as likely as a rare one *inside one table* instead of needing a nest
  of tables to express odds. Weight 0 parks an entry without deleting it.
- **`chance`** — a per-entry percentage applied *after* it is picked, so an entry
  can be "usually nothing, sometimes this".
- **`min`/`max`** — a count range rather than a fixed number.

Old data still loads: a plain `count` reads as `min = max = count`, and
`useAll` reads as `mode = "all"`. `ix.loot.Normalise` runs on load and on
anything arriving from the editor, so a table saved before modes existed is
upgraded when touched rather than needing a migration pass.

`count` on a nested table means "roll that table N times", each draw subject to
its own spawn chance.

### Preview

`ix.loot.Simulate` rolls a table N times and totals what came out. This is the
feature that makes authoring odds possible at all — weights, per-entry chances
and nested tables multiply through each other in ways nobody can do in their
head. Phoenix had a "Preview Results" button for the same reason.

It reports **how often the table produced nothing**, which is the number that
actually tells you whether a container will usually be empty.

It previews the copy being **edited**, not the copy on the server. The first
version previewed the saved table and told you to save first, which is the wrong
way round: preview is how you decide whether a change is right *before*
committing it. The editor swaps the working copy into `ix.loot.tables` for the
duration of the simulation and takes it straight back out — necessary because a
roll crosses table boundaries and has to resolve sub-tables by name.

Changing anything clears the last run rather than leaving it on screen, since a
simulation is a statement about a specific table and stale numbers cannot be
told from fresh ones by looking.

### The analytic odds

`ix.loot.SelectionChances` gives how often each entry **wins a pick**;
`ix.loot.EntryChances` gives how often it **produces something**;
`ix.loot.BuildTree` multiplies those down the nesting so every node carries the
share of one container opening that reaches it. `ix.loot.FormatChance` prints
them, switching to scientific notation below a hundredth of a percent because
their own data goes to 0.000001 and `0.00%` says nothing.

**Selection and per-entry chance are not two multiplications.** Under `rolls`
the chance gate is rolled once per draw, so the entry's chance has to be folded
in *before* the repetition:

    right    1 - (1 - share x chance)^N
    wrong    (1 - (1 - share)^N) x chance

With two rolls, a half share and a half chance those are 43.75% and 37.5%. The
first was checked against 400,000 simulated openings across five table shapes
(nesting, `by level` above and below the threshold, skewed weights under
`ROLL 4`) and tracks to within 0.1 percentage points; the second is six points
low. The wrong form was in the first draft of this and was caught by
simulating it, not by reading it.

One documented simplification: a **sub-table entry with a count above one** is
rolled that many times, and the tree shows the chance of the first of those
rolls. The `xN` on the row says the count, so the row is not claiming otherwise.

## A save is refused until the load has happened

`ix.loot.loadedTables` and `ix.loot.loadedPlaced` gate `Save` and `SavePlaced`.

The failure they exist for is total and silent. If a load does not run — a hook
that never fires, an error earlier in the file, a timer that is cancelled — then
`ix.loot.tables` is still the empty table it was initialised as, and the *next
save writes that empty table over a file full of work*. Placed containers hit
exactly this: `lootables.txt` came back as `[[]]`.

It is the same fault as the one that let a map cleanup erase every container,
and it takes the same fix: **a save is refused until the thing it would
overwrite has actually been read.** Losing a session's edits is recoverable;
overwriting the file is not. The refusal is an `ErrorNoHalt`, so it is loud.

Loot tables are now loaded at **file scope** rather than from `InitPostEntity`.
Reading them touches nothing but `ix.data` — no entities, no players, no
database — so there was never a reason to wait, and waiting is what made it
fragile. Placed containers genuinely do have to wait, because restoring one
spawns an entity.

### `InitPostEntity` does not reach this schema

That was the actual bug, and the save guard is what exposed it:

```
Lua Error: [falloutrp] refusing to save lootables - they were never loaded
```

Every `hook.Add("InitPostEntity", ...)` in `schema/libs` registered correctly
and never ran, so `LoadPlaced` never happened, every placed container vanished,
and before the guard existed the next save wrote the empty list over the file.
It is the third time this session a listener has been registered after its
event, and the lesson is the same each time: **pick the event the framework
promises to run, not the one that looks like it happens at the right moment.**

Persistence now hangs off `LoadData`, which Helix runs itself from
`ix.plugin.RunLoadData` after the database connects and again after a map
cleanup — precisely when persistence should load. `hook.SafeRun("LoadData")`
ends in `hook.ixCall`, so plain listeners are dispatched; no plugin table is
needed.

Three triggers, all guarded so whichever arrives first wins:

| Trigger | Why |
|---|---|
| `LoadData` / `PostLoadData` | the framework's own, and the correct moment |
| `InitPostEntity` | kept for the case where it does fire |
| `timer.Simple(10, ...)` | depends on nothing but the server ticking |

The timer is not paranoia for its own sake — this has silently destroyed data
twice, and it is a no-op in every case where either hook fired.

`PostCleanupMap` also re-spawns any record whose entity has gone. The records
survive a cleanup by design; without this they would survive it *invisibly*,
with the map empty until the next restart.

Both loads print unconditionally, including zero. "No message" and "no tables"
have to be distinguishable, or a load that never ran looks exactly like a server
that has none. Each container is spawned under `pcall`, so one bad record cannot
stop the other forty.

---

## Where the data lives

Locally, through `ix.data`, in two separate stores:

| Store | Scope | Why |
|---|---|---|
| `lootTables` | schema-wide, **not** per map | tables are reusable content and should survive a map change |
| `lootables` | **per map** | a placed container is a position on one map and means nothing on another |

Phoenix fetched every collection over HTTP from a hardcoded address — and the
**client** made those calls, so every player's game talked to the backend
directly. `reference/10_geck_and_crafting.md` records that as a design flaw
worth not repeating. Here the server owns the data and networks it down; the
client's copy is a mirror kept only so the editor can filter without a round
trip per keystroke.

---

## Containers are not inventories

A container holds a plain list of `{uniqueID, count}` on the entity, and a real
item is created only when something is taken out. A hundred crates on a map
should not mean a hundred inventories of database rows nobody has looked at.
Phoenix reached the same conclusion with their `FakeInventory`.

Contents are rolled **once** and kept until the respawn timer expires, so two
players opening the same crate see the same crate — re-rolling per viewer would
let one player empty it and the next find it full. Every viewer is updated on
each take, because two people looting one crate is the normal case.

Taking decrements the count and blanks the slot at zero rather than removing it:
`table.remove` would renumber every later slot and invalidate the indices other
viewers are holding.

The respawn timer starts when a container is **emptied**, not when it is opened
— a crate somebody looked at and left alone should stay as it is.

---

## Luck

This is the first consumer of `ix.special.GetBonusLootCount`, which has had its
maths written and no caller since the SPECIAL work.

The bonus is extra **rolls of the same table**, not extra copies of one item, so
a lucky character finds a fuller container rather than three of whatever the
first draw happened to be. Disable with `lootLuckBonus`.

---

## The configurer

Laid out around the thing the GECK could not show you: the **tree**. Their
editor gave one flat list per table and left the nesting in your head, so a drop
running through four tables at 60%, 50%, 25% and 12% was a number nobody could
state.

| Region | Holds |
|---|---|
| left | every table, each with its entry count, spawn chance and mode badge |
| centre | **TREE**, **ENTRIES**, **PREVIEW**, **HELP** |
| right | the inspector: the table, and the selected entry |
| footer | the hint line, SAVE, ARM TOOL, PLACE HERE, CLOSE |

**TREE** is the screen the rest hangs off. Rows indent by depth with a
connecting hairline, expand and collapse, and carry three right-aligned columns:
the mode badge, the count (`x1`, `x1-3`), and the percentage of one container
opening that reaches that row. Table names are amber, item names grey, anything
broken red. Left click opens or closes a branch and selects the row when it
belongs to the table being edited; right click on a sub-table goes and edits
*that* table. `EXPAND ALL` marks every path in the built tree rather than
setting a flag the drawing checks — a flag collapses the whole tree the moment
you click any row, because the click has to clear it.

**ENTRIES** is the same entries flat, with `PICKED` and `REACHED` per row and
arrows to reorder. **HELP** is the full reference in prose, built from the same
strings the inspector shows under its fields, so the two cannot drift.

**Every field carries a line saying what it does.** This is an editor for
probabilities, used occasionally, by people who did not write it; a label
reading `WEIGHT` only means something to someone who already knows the model.
Fields the current mode *ignores* are greyed with the reason ("NOT USED — this
table uses USE ALL ENTRIES, where nothing competes") rather than hidden, because
"why is this doing nothing" is the question the greying answers. `ROLLS` is the
exception and is hidden outright: outside its mode it has no meaning at all.

Mode is **one button cycling four states**, not three checkboxes that switch
each other off — you cannot look at a state the system cannot be in.

Adding an entry opens a **full-window picker** rather than competing for a
fourth column, which is what gets it room for an item's name, category and
uniqueID on one line. It stays open after an add, because filling a tier table
means adding eight things in a row. Capped at 80 with the remainder counted —
it rebuilds on every keystroke over a couple of thousand items, the same
problem the dev terminal hit.

DUPLICATE exists because that is how a tier gets made: copy Tier1, change three
entries, save as Tier2.

Editing works on a **copy**, so changing a table and clicking away does not
leave the client's mirror altered while the server still has the original. A
rename is handled as delete-plus-add, or the old name would linger as a
duplicate. Switching tables or closing with unsaved changes asks first, and a
sync arriving from the server refreshes the *list* without touching what is
being edited — a save by another admin must not silently discard your work.

### Sizing

Nothing is sized by eye, because "text is cut off" was the complaint that
prompted the rebuild:

- fonts are the configurer's own (22/16/15/13/11 px), scaled by
  `ix.fallout.GetFontScale()` like the rest of the UI, rather than reusing the
  HUD's 12px for prose
- row heights are the **measured** height of the fonts in them plus padding
- the right-hand columns are the **measured** width of the widest value each
  can hold, so the numbers line up down the page
- a name too long for what is left is cut with an ellipsis instead of running
  under the column beside it — memoised, since sixty rows binary-searching
  their own width every frame is five hundred text measurements a frame
- every explanation wraps in `PerformLayout` against the width it was actually
  given, and its field grows to fit; a paragraph wrapped at creation is wrong on
  every screen but the one it was guessed on
- the frame is clamped to the screen as well as to a maximum

`PLACE HERE` drops a single container where you are looking, and refuses while
there are unsaved changes — a container uses the *saved* copy.

**For placing many, use the tool.** `entities/tools/lootable.lua` is a toolgun
mode: pick a table and model once, then left-click your way around the map.
Right-click copies the settings off a container you point at — which is how you
match an existing one without remembering what it was set to, and how you fix a
batch placed with the wrong table. Reload removes one. **Superadmin**, checked
server-side in all three actions, because placing containers is level design
rather than moderation.

The configurer's `ARM TOOL` button loads the selected table onto the tool and
switches to it. Every net handler re-checks admin: the configurer decides what
to *offer*, the server decides what *happens*.

Validation runs **client-side before sending as well as server-side on
arrival**. The server's answer is the one that counts, but it answers with a
notification in the corner, several steps from the field that was wrong;
checking the same rules in the editor puts the reason on the hint line under it.
Validation refuses a table at the point the mistake is made — a missing item, a
chance outside 0-100, an entry that is neither item nor table, or a table
referencing itself. Rolling also guards against cycles at depth 8, since a
table that eventually references itself is easy to author by accident in an
editor like this and would otherwise recurse until the server died.

---

## Sounds

All of them are the New Vegas originals, already on the server —
`roadkill/fallout/containers/*` in `af_content_pack_5`, `phoenix/ui/*` in
`phoenix_sound_content`. Every generated path was checked against the files on
disk before shipping, because **a missing sound in GMod is silence, not an
error**, and a typo in a path would simply never be noticed.

| When | Sound | Where from |
|---|---|---|
| open a **fresh** container | the XP chime, `ui_experience_up` | client-side, from the XP panel |
| open an **already looted** one | `drs_<set>_open` | on the entity, so people nearby hear it |
| last viewer closes | `drs_<set>_close` | once, not per viewer |
| take an item | `ui_items_<kind>_up` | on the player, after the add succeeds |
| Luck grants extra loot | `ui_score_boost_01` | to the looter only |
| gain XP | `ui_experience_up` | Phoenix's own, through `CreateSound` |

### Fresh and picked over are two different sounds

Opening something nobody has been through is a find; opening one that has
already been emptied is just a lid. The first version played the container's own
open sound in both cases, which made every discovery sound like a re-check.

Freshness belongs to the **container**, not the player — the contents are
shared, so the second person to reach a crate is not discovering anything. A
respawn clears the flag, since a refilled container is new again.

**The find's sound is the XP chime**, and nothing else is emitted. A fresh
container awards `xpPerContainer` unmuted, and the panel in `cl_leveling.lua`
plays `ui_experience_up` client-side — Phoenix's own sound, where Phoenix plays
it. A fresh container that has no reward to give (no character, or
`xpPerContainer` at 0) falls through to the lid sound.

#### The ordering mistake, because it is worth not repeating

This briefly had a `lootFreshSound` config, emitted server-side, alongside a
*muted* XP award. The XP panel plays its note **client-side the instant the
message arrives**; a server `EmitSound` has to travel. So the panel's chime
always landed first and the configured sound arrived a beat later as a thud.

Asked to remove "the second sound", I muted the panel — which silenced the
chime and kept the thud, exactly backwards. Two sounds racing across a network
boundary do not arrive in the order they are written.

### Taking is category-based

A rifle, a stimpak and a handful of caps make three different noises, the way
the games do it. Phoenix already does exactly this for ammunition in
`items/base/sh_clip.lua`; this follows that file and extends it to guns, melee,
clothing, grenades, bottles and caps, falling back to `ui_items_generic_up`.

Matched against the item's `category` first and then its uniqueID, so
`ammo_10mm` is recognised however it is filed.

The client no longer plays a UI blip on the take button. The server emits the
item's own sound once it knows the take actually succeeded — the blip fired
even when the take was refused for lack of room.

### The Luck sound is a choice, not a port

Phoenix's is emitted server-side and glua-steal only ever captured client
files, so there is no way to know which one they used. `ui_score_boost_01` is
the Fallout 76 cue for a bonus taking effect, which is what a Luck proc is.

It fires only when the bonus **actually produced something** — `bonus > 0`
alone would ring on every container a lucky character opens, including the many
where the extra rolls came up empty, and a cue that fires whether or not
anything happened teaches players to ignore it.

---

## Notes

- Admins see a container's table name in the entity tooltip; players do not.
  Knowing a crate is `Looter_RareCrap` tells a player whether it is worth
  walking to.
- The looting window is a **list**, not their tetris grid. You are emptying a
  container, not arranging it, and a list can show the item's real name and
  count.
- `ENT:OnRemove` skips saving during `ix.shuttingDown`. On shutdown every
  entity is removed, and saving then would write an empty list and wipe every
  placed container.
- **No loot tables ship with the schema.** They are authored in game. Their 94
  tables were not imported: 257 of the 318 item classes they reference are
  blueprints, frames, materials, ammo and chems that do not exist here, so the
  imported result would have been mostly empty tables.
