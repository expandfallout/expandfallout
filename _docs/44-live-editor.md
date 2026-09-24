# The live editor

`/LiveEdit` — changing the schema's numbers without a restart, for everybody,
saved.

| | |
|---|---|
| `schema/libs/sh_live.lua` | the override store and the field machinery |
| `schema/libs/sh_livekinds.lua` | what may be edited: weapons, armour, chems, races, factions |
| `schema/libs/sh_livecombat.lua` | per-weapon hit multipliers and the quality ceiling |
| `schema/libs/sh_livemenu.lua` | the F1 tab order |
| `schema/libs/sv_live.lua` | storage, the net handlers, the sync |
| `schema/libs/cl_live.lua` | applying it on the client too |
| `schema/derma/cl_liveedit.lua` | the window |

---

## Why an override store rather than editing files

Everything in this schema lives in code: an armour is a Lua file, a race is a
Lua file, a weapon is a SWEP table from an addon. Editing those from in game
would mean writing Lua from Lua, and the schema would then have **two sources
of truth** that disagree the moment somebody pulls an update.

So the files stay the files, and the editor keeps a small table of
*differences*:

```lua
ix.live.overrides[kind][id][field] = value
```

applied over the top on load and whenever one changes. The **base value is
remembered** the first time a field is touched, so RESET is exact rather than a
guess — and a field nobody has edited is not in the store at all, so an update
to a weapon pack is picked up normally.

## A "kind" is four things

| | |
|---|---|
| `List` | everything of that kind, for the middle column |
| `Target` | where one subject's fields actually live — a weapon's damage is on the SWEP table, an armour's resistance on the item table |
| `fields` | what may be edited, with bounds and a note — a list, or a **function of the subject** when the subjects differ (SPECIAL) |
| `OnApply` | anything that has to happen after a write |

**Nothing about the window is written per kind.** The sections come from
`ix.live.Sections`, the rows from a kind's `List`, and the controls from its
`fields` — so adding "every ammunition type" to the editor is a table in
`sh_livekinds.lua` and no change at all to `cl_liveedit.lua`. Same arrangement
as the crosshair menu, for the same reason.

**Both realms apply it.** A weapon's damage, spread and ironsight position are
read on the *client* for prediction and the viewmodel and on the *server* for
the damage it does; an item's description is built on the client; a faction's
colour is drawn on the client. An override that reached only one side would
give a rifle that feels wrong and hits right.

**Weapons already in the world are updated too.** `weapons.GetStored` is what a
*new* weapon is built from; one somebody is holding was built from it a minute
ago and kept its own copy, so `OnApply` walks `ents.FindByClass`. Without that,
a damage change would only reach people who drop their rifle and pick it up.

**And the weapon's own cache is rebuilt.** The longsword base builds a
`CachedData` table once per weapon and *fires from that* — damage, cone, recoil
and the pellet count all come out of it. Writing `Primary.NumShots` on a weapon
somebody is holding therefore changed a field nothing reads again, which is why
setting a rifle to fire six pellets appeared to do nothing at all.
`weapon:RebuildCachedData()` is the fix, and it is what makes every other number
take effect mid-fight rather than after a reconnect. See [03-weapons.md](03-weapons.md).

**Armour is taken off and put back on.** `ix.armor.Refresh` recomputes the
resistance pools, but equipping does more than resist damage — bodygroups,
render state, stealth and the SPECIAL bonuses are all applied by
`ix.armor.Equip` — so `OnApply` unequips and re-equips the edited armour on
everybody wearing one, a frame apart so the second half does not race the first.

## What each section edits

| Section | |
|---|---|
| **WEAPONS** | damage, spread cone, fire delay, recoil, **ammo used per shot**, pellets per shot, magazine, automatic, **run and gun**, the seven spread settings, ironsight position and angle — plus the combat block below |
| **ARMOUR** | damage/radiation/fall resistance, speed, jump, all seven SPECIAL bonuses, which body kind it is cut for, whether it **is power armour** at all, and whether a power armour piece is a **salvaged** frame that needs no training (20-armour.md) |
| **CHEMS** | healing, heal time, radiation, addiction chance, price, and **every buff it grants** — the seven SPECIAL stats plus DR, SPD, RADRES, DMG, HP and STEALTH, with a shared duration |
| **SPECIAL** | what each of the seven attributes is *worth* — see below |
| **RACES** | health, **natural damage resistance**, **walk and run speed**, jump, model scale, whether it takes radiation, whether it needs food and water, and **whether it can use chems** |
| **FACTIONS** | name, description, colour, pay, pay interval, whether anyone may join, raid immunity, hidden from the tab menu, and **encrypted comms** — whether bystanders hear `/f` and `/o` as words or as static (47-chat-tickets-and-gore.md) |
| **MENU** | the order of the F1 tabs, for everybody |

Two of those race fields did not exist before and are wired in where they are
read: `naturalResistance` is added into the same pool as armour and chems in
`ScalePlayerDamage` (and clamped once with them, so three sources cannot stack
past immunity), and `walkSpeed`/`runSpeed` are the base `ix.special.Apply`
starts from, falling back to the server config for any race that has none.

### Fields that are not one value in one place

A chem's SPECIAL bonus lives in `ITEM.buffs`, a list of
`{stat = "STR", value = 3, duration = 60}` — there is no `buffs.STR` for the
generic reader to walk to. A field may therefore carry its own `Read` and
`Write`, and is then edited like any other while doing whatever it takes
underneath. `ix.live.BuffFields()` builds thirteen of them plus the shared
duration; the SPECIAL section uses the same hatch to read and write
`ix.config`.

Two consequences worth knowing:

- **the base for RESET is read the same way.** It used to be read from the
  path, which for a `Read` field is nil — so reset put nothing back.
- **`field.default` is what the code does when the field is absent.**
  `RACE.hasRadiation` is nil on almost every race and *means true*
  (`ix.races.TakesRadiation` tests `~= false`), so a switch showing nil as off
  told every human they were radiation-proof.

## Ironsights

The **weapon base already has the WASD editor** —
`longsword_ironsighteditor`: hold the gun, hold a movement key, and the sights
move. It has never had a way to *keep* the result; it prints its state to
console and that is all.

So EDIT SIGHTS toggles it, and **SAVE SIGHTS reads the numbers back off the
weapon in your hands** and stores them as overrides. The position and angle are
also plain fields, so they can be typed in.

**SAVE also closes the editor**, because saving is finishing — it used to leave
you holding the gun with the movement keys still moving the sights, so the next
nudge was unsaved again. Only if it is open: pressing SAVE after typing the
numbers in by hand would otherwise turn the editor *on*.

The base's controls, since it does not say: **left click** selects position and
**right click** selects angle, WASD moves it in the plane, `+use` and `+menu`
move the third axis, and the step is 0.1, or 0.5 with Shift and 0.001 with
Ctrl.

## The combat block, per weapon

The hitgroup profiles in `32-rarity.md` are shared — every rifle uses the rifle
profile — which is right for two hundred weapons and wrong for the handful that
are meant to be special.

| | |
|---|---|
| **Scaled** | head/body/limb multipliers for *this* weapon, replacing the profile's. Quality still multiplies on top |
| **Static** | multipliers quality does **not** touch — the damage is what it says whatever the weapon rolled |
| **Ceiling** | the highest quality multiplier this weapon may reach. 0 is none; Legendary is 1.4 and Pearlescent 2 |
| **Quality ladder** | what *each tier* is worth on this weapon, one box per tier. Blank uses the server-wide ladder, which is the greyed number in the box |

The ceiling and the ladder answer different questions. The ceiling says "no
higher than this"; the ladder says what *shape* quality has on this weapon — a
minigun wants a flat one because it fires nine hundred rounds a minute, and a
bolt-action wants a steep one because a Pearlescent hunting rifle is meant to be
a story. Both are the same ceiling and completely different weapons.
`ix.combat.TierDamage` falls through to the shared tier for anything unset, and
the ceiling is still applied on top.

The difference between the first two is the whole point. A *scaled* multiplier
is "this weapon is better at headshots"; a *static* one is "this weapon does
exactly this", which is how you write a syringe, a called shot or a wrench.

They are read in **`sv_rarity.lua`'s existing damage hook** rather than a new
one — two hooks scaling the same damage is how a number ends up squared. Where
a static multiplier applies, the quality multiplier is deliberately never
applied at all.

## The tab order

Helix builds the F1 tabs with `SortedPairs`, so they are alphabetical by
internal name — which is why the inventory sits in the middle. The editor stores
an order and `sh_livemenu.lua` **re-sorts the buttons** after `PopulateTabs` has
run, rather than reimplementing that loop and owning a copy of every tab's
creation, gating and default-selection logic.

Two things had to be right before it did anything at all:

- **the panel is `ixFOMenu`, not `ixMenu`.** This schema has its own menu
  (`fallout_ui/cl_menu.lua`) and Helix's is not the one on the screen.
- **sorting the array, not setting z positions.** `ixFOMenu` does not dock its
  tab buttons — `PerformLayout` walks `self.tabButtons` and `SetPos`es each in
  turn, so a button's place *is* its index in that table. `SetZPos` is the right
  answer for a docked strip and a real instruction that changes nothing here.

The list of tabs comes from `ix.live.RealTabs()`, which runs `CreateMenuButtons`
exactly as the menu does — so it is **what exists now**, and only that. It used
to be four names written down in the file plus every name anybody had ever
reordered, which is why the editor listed tabs this schema deletes (`you`,
`business`, `classes`) alongside tabs the menu does not have. Stored positions
for a missing tab are kept rather than cleaned up: they cost nothing and put it
back where it was if it ever returns.

## SPECIAL

The only section that edits `ix.config` rather than a table, because that is
where the seven attributes' rates have always lived and a table of our own would
be a second place to disagree with the config menu. It gets there through the
`Read`/`Write` hatch above; `ix.config.Set` networks and saves itself, so a
change made here survives a restart without the live store's help.

Its subjects are the attributes themselves — Endurance's settings and Luck's
have nothing to do with each other — which is what `fields` being a function of
the subject is for.

| Attribute | What you can change |
|---|---|
| **General** | the creation budget (spent *exactly*) and the ceiling on one attribute |
| **Strength** | melee damage per point |
| **Perception** | ballistic damage per point |
| **Endurance** | the stamina pool, stamina per point, the **drain and regeneration rates**, the punch cost, and **jumps from a full bar** (`jumpStaminaCost`, from `sh_jump.lua`) |
| **Charisma** | the share of a mugging demand talked down per point |
| **Intelligence** | laser/plasma/gauss/tesla damage per point |
| **Agility** | **walk** speed per point and **run** speed per point |
| **Luck** | Luck per extra container drop, items per step, experience, crafting |

Four of those are new or changed:

- **the three damage rates are separate.** They were one number
  (`ix.special.damagePerPoint`), which meant making Perception matter more made
  Intelligence matter more too. All three still default to a percent a point.
- **Agility moves you at both speeds.** It used to add to running only, which
  made it an attribute that did nothing in a settlement.
- **Endurance now buys jumps.** Jumping has cost stamina since
  `libs/sh_jump.lua` landed, but at a flat rate, so an Endurance 10 character
  had a bar that lasted twice as long at a sprint and *exactly* the same four
  and a half jumps. `ix.jump.Cost` scales it by the effective pool the same way
  the sprint drain is scaled.
- **the jump box holds jumps, not stamina.** The config underneath is
  `jumpStaminaCost` — stamina out of a hundred — which is the wrong way round
  for the person deciding it. The field's own `Read`/`Write` do the division, so
  the box says 4.5 and the config keeps its own meaning.
- **Luck loot comes in steps.** A tenth of an item per point is a number nobody
  can feel; "one more thing in the box every 5 Luck" is a sentence a player can
  check. Both halves are configurable.

## Asking what actually happened — `fo_live`

Live editing has failed twice for reasons invisible from the window: an override
that was stored, synced and drawn while the thing it described was never written
(gotcha 28), and an override whose RESET put back the wrong number (below). In
both cases the editor looked right and the game did not.

`fo_live` prints every stored override with what the store says, what the target
says **right now**, and whether they match. `fo_live weapon` narrows it to one
kind. Run it on both realms:

| | |
|---|---|
| mismatch on both | the write is not landing — the target or the path is wrong |
| right on the server, wrong on the client | a sync problem, not an apply problem |
| both agree and the game still disagrees | something downstream caches it — see `CachedData` in [03-weapons.md](03-weapons.md) |

## Field kinds, and why `angle` had to exist

A field's `kind` chooses its control *and* its type on the way back in. The
store and the wire carry three numbers for a vector, an angle and a colour —
the save is JSON, and JSON has no `Vector` — so `ToTarget` turns them back into
the real thing before anything is written.

`SWEP.IronSightsPos` is a **Vector** and `SWEP.IronSightsAng` is an **Angle**,
and the base adds to each with its own type. Editing the sights therefore broke
twice over:

- **`OnApply` was handed the raw value.** The weapon kind writes it onto every
  weapon of that class already in the world, so an ironsight edit put a plain
  `{x, y, z}` table where a Vector belonged and `GetOffset` threw
  `bad argument #1 to '__add' (Vector expected, got table)` every frame until
  the weapon was put away. It had been harmless only for as long as writing to
  a live weapon silently did nothing (gotcha 28); fixing that made it fire.
  `ToTarget` now runs once and both the write and `OnApply` get the result.
- **the angle was typed as a vector.** Three numbers either way, but writing a
  `Vector` into `IronSightsAng` is the same error with a different noun. There
  is now an `angle` kind, and SAVE SIGHTS reads an Angle back with
  `isangle`/`.p .y .r` — it tested `isvector` for both keys before, so the
  rotation was never saved at all.

### `items` — a set of item ids

A field whose value is `{[uniqueID] = true}`, drawn as a grid of ticks — every
item the field's `filter` admits, sorted by name — rather than a box nobody
should have to type an id into. The whole set is sent on every click.
`Clean` accepts a set or a list of ids and keeps only ids of items that exist
and pass the filter; **empty is a value**, not a failure, because unticking
everything is how a list is taken off. The same-value check that turns a
no-op edit into a reset compares sets by membership, not by the three indices
a vector has. The first two are the races' chem lists — see
[25-chems.md](25-chems.md).

## What a weapon does not write down

A weapon file says what makes it *that* weapon and inherits the rest: 54 of the
217 in this arsenal have no `SWEP.Spread` table at all, and almost none set
`AmmoPerShot` or `NumShots`. GMod fills those in from `ls_base` with
`table.Inherit` when the entity is made, and `BuildBaseCachedData` falls back to
the same numbers again.

That produced two lies in the editor, both now fixed:

- **it showed 0.** The field was absent, and absent read as zero — so "ammo
  used per shot" said 0 on a gun that plainly used one. Every weapon field now
  carries the base's own value as its `default`, so an unset field shows what
  the weapon actually does.
- **the edit did nothing.** Writing `Spread.Min` on a weapon with no `Spread`
  table failed at the first lookup, and the override was stored, synced and
  drawn anyway. `ix.live.Write` now creates the missing table on the way
  through; an empty one is harmless, because inheritance and the cache fall
  back for every key it does not hold.

## RESET, and targets that remember

`ix.live.base` records what a field was before the first edit, and that is what
RESET puts back. It is captured by *reading the target*, which is right for
everything rebuilt from a file on every boot — a SWEP table, an item, a race.

**A restore is an apply**, so it runs `OnApply` too. Putting the number back
into the SWEP table is only half of a reset — `OnApply` is what carries it to
the weapons already in the world and rebuilds their cache. Without it, RESET
fixed the table nobody was reading: the menu showed the original numbers, the
sights on the gun in your hands did not move, and typing those same numbers in
by hand *did* work. The client's `RestoreAll` was the half that skipped it.

**An absent field is put back by removing it, not by writing a number.**
`"\0none"` is how "there was nothing here" is recorded, since nil cannot be a
table value — and Reset used to see that and do nothing at all, leaving the
typed number in the SWEP table until the next restart while reporting success.
It now writes nil, which hands the field back to `ls_base`.

**`ix.config` is not one of those.** It saves itself, so after a restart the
current value *is* the edit, the base captured on the next `ApplyAll` was the
edit, and RESET put the edit back — which is what "I changed a SPECIAL stat and
cannot change it back" was. A field may therefore provide `Base`, and the
SPECIAL fields answer it with `ix.config.stored[key].default`: the value the
code was written with, which Helix keeps beside the value for exactly this.

Applying is also wrapped in `pcall` in both places it happens. The store is the
decision and applying it is a consequence; a consequence that throws is worth an
error in the console, not a lost decision or — as it was — an edit that was
never saved and vanished at the next restart.

## Safety

- admin-gated at every net handler with `dev.terminal`, re-checked on the
  server rather than trusted from the window (gotcha 15)
- every value is `Clean`ed against its field's own bounds on the server before
  it is stored, so a number field cannot be handed a string
- every change is logged with the kind, the subject, the field and the value
- an override naming something that no longer exists is skipped rather than
  dropped, so a temporarily uninstalled weapon pack does not lose its numbers
