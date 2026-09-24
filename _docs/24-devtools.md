# 24 - Developer tools

`/devmenu` (or `fo_devmenu`) opens the developer terminal. It is also a
spawnable entity — Q menu, Fallout RP, Developer Terminal — if you want one
standing in the world.

Admin only, and the permission is re-checked at **every** net handler: having
the terminal open is not permission to take anything out of it.

---

## Four sections, not one list

It began as every item grouped by `ITEM.category`. That was right when the
schema had 218 weapons and nothing else; with 1,100 items and five systems
behind it, "every item, grouped by category" is a browser rather than a tool.

| Section | What it does |
|---|---|
| **ITEMS** | every registered item, filtered by category and search, GIVE / x5 / x10 — **at a chosen quality** |
| **TEST BOTS** | DR presets, then every armour ordered by what it stops |
| **CHARACTER** | health, hunger, thirst, rads, level, XP, skill points, strip inventory |
| **WORLD** | lootables, plants, farming, mining, stashes, reports |
| **ORBITAL** | drops and their timing |
| **PK** | who is marked, what a PK costs |
| **RESTRAINTS** | ties, cuffs, elastic restraints, searching |
| **RARITY** | the curve, a ten-thousand-roll sample, and the trade-up bench |
| **ALL SETTINGS** | every dial the terminal may touch, grouped and searchable |

Each nav button carries a one-line subtitle saying what is behind it, painted
rather than a second label — the button's text colour flips when it is hovered
or active, and a child label would not follow it.

**ALL SETTINGS is built from the same table the server enforces.**
`ix.devmenu.configurable` moved into `sh_devmenu.lua` so the window can be
generated from it: the page cannot offer a row the server would ignore, and a
config added anywhere in the schema appears here with no edit. The subject
pages stay, because they say what each number *means*; this one answers "there
is a setting for this somewhere, where is it".

## Spawning a weapon at a chosen quality

The ITEMS page has a **quality** row above the list. It is a mode rather than a
per-row button — a row already carries three — and it sticks until it is
changed, because the reason to set it is usually "give me these six things at
this tier".

It is the only way to get a specific tier on demand: quality is rolled when a
weapon is **crafted** (`32-rarity.md`), so testing what a Legendary rifle
actually does otherwise meant crafting until the curve produced one. The server
checks the tier exists **and** that the item is a weapon before stamping it —
`ix.rarity.Get` refuses to return an id it does not know, so an unknown tier
would look exactly like a weapon that had lost its quality. The tier is in the
give log with everything else.

Everything is built from `ix.item.list` and `ix.loot.tables` rather than
hand-written lists, so it never goes stale — an item added tomorrow appears
tomorrow with no edit.

The category column belongs to ITEMS alone, so it is hidden with it rather than
being a permanent column taking width from every other section. Search is only
shown where there is a list to filter; an inert box above the CHARACTER buttons
would invite typing into it.

---

## Actions run existing commands

Anything that already has an admin command **runs that command** rather than
being reimplemented — `/charsetrads`, `/charsethunger`, `/charsetlevel`,
`/charaddxp`. One implementation of each rule, already validated and already
logged.

Character names are passed through `string.format("%q", ...)`. Names contain
spaces far more often than not, and Helix splits command arguments on
whitespace unless quoted — so `charsetrads Test Test 50` would read "Test" as
the player and "Test" as the number.

What has no command goes through a **single** `ixFODevAction` net message with
a closed action table: heal, refill, strip inventory, clear ground, and the
lootable operations. A client cannot invent an action, and adding a button does
not mean adding another net string.

The destructive ones (strip inventory, clear ground, clear lootables) confirm
first and log at `FLAG_DANGER`.

`RESET` on container contents forces every placed lootable to re-roll on next
open without moving or re-pointing any of them — the fastest way to test a loot
table change against containers already in the world.

---

## The lootable tool

`entities/tools/lootable.lua`. Placing containers through a dialog means one
dialog per crate and a map needs dozens; this is the fast path.

    left click    place one here
    right click   copy the settings off the one you are pointing at
    reload        remove the one you are pointing at

**Superadmin**, checked server-side in all three actions — placing world content
that persists to the map's data file is level design rather than moderation.

### Helix's tool base is incomplete — the metatable is patched

`ix.meta.tool` says at the top of itself that it is "code replicated from
gamemodes/sandbox/entities/weapons/gmod_tool/stool.lua", and it is a
**partial** copy. Its own `Think` calls `self:ReleaseGhostEntity()` and never
defines it — nor `DrawHUD`, `FreezeMovement`, `ClearObjects` and most of what
the toolgun calls every frame:

```
[ERROR] sandbox/.../gmod_tool/cl_init.lua:61: attempt to call method 'DrawHUD' (a nil value)
[ERROR] helix/.../sh_tool.lua:117: attempt to call method 'ReleaseGhostEntity' (a nil value)
[ERROR] sandbox/.../gmod_tool/object.lua:163: attempt to call method 'GetStage' (a nil value)
```

several times a second for as long as any Helix-registered tool is held.

`libs/sh_toolfix.lua` completes it. **It contains no list of methods**, and
that is the whole design — three earlier versions failed, each in a way worth
recording.

| Attempt | Mechanism | Why it failed |
|---|---|---|
| 1 | rebuild each tool from `ToolObj` in the tool's own file | needs `ToolObj` at include time, and only fixes tools that remember to do it |
| 2 | patch the metatable from `hook.Add("Initialize")` | never ran — Helix loads the schema *during* gamemode initialisation, so the event had already fired |
| 3 | patch the metatable at file scope, from a hand-written list, delegating to `ToolObj[name]` | the lookup never resolved, **and** the list was wrong |
| 4 | set a metatable on `ix.meta.tool` whose `__index` is the real base | current |

#### `ToolObj` does not exist at runtime

The obvious source for the real implementations is the `ToolObj` global, and it
is not there:

```
ToolObj = nil        -- sandbox/entities/weapons/gmod_tool/stool.lua:171
```

Attempt 3 looked it up at call time anyway, on the theory that it might not
exist *yet*. It does not exist *ever*. That version filled in 18 methods and
every one of them quietly did nothing — errors gone, behaviour gone, no sign of
which. It reported `filled in 18 missing method(s)`, which was true and
meaningless.

The table is still alive, just unreferenced. `ToolObj:Create` does
`setmetatable(o, self)`, so every sandbox tool object carries it:

```
weapons.GetStored("gmod_tool").Tool  →  any sandbox tool  →  getmetatable
```

That search skips `ix.meta.tool` explicitly — Helix tools are in the same list,
their metatable is the table being patched, and pointing a table's `__index` at
itself makes every miss loop forever. It identifies the base by what it *has*
(`ReleaseGhostEntity` and `SetObject`) rather than by name.

Registration happens before `stool.lua`'s `if (SERVER) then return end`, so
`SWEP.Tool` is populated on both realms. `ghostentity.lua` and `object.lua` are
included unconditionally at the top of the file, so the recovered base has the
shared methods in both realms too; `DrawHUD` and `RebuildControlPanel` come from
`stool_cl.lua` and are client-only, which is also where they are called from.

#### The list was the mistake, not its contents

Attempt 3's list had 18 entries. The real gap is **23**:

```
ToolObj defines 42 methods
ix.meta.tool defines 19
missing: ClearObjects DrawHUD FreezeMovement GetBone GetClientBool GetEnt
         GetHelpText GetLocalPos GetNormal GetOperation GetPhys GetPos
         GetStage MakeGhostEntity NumObjects RebuildControlPanel
         ReleaseGhostEntity SetObject SetOperation SetStage StartGhostEntity
         UpdateData UpdateGhostEntity
```

The five it omitted were `GetClientBool`, `GetOperation`, `GetStage`,
`SetOperation` and `SetStage` — and sandbox's own `GetHelpText` calls
`self:GetStage()`, so filling in `GetHelpText` correctly *introduced* a new
error at `object.lua:163`, 800 times.

A hand-written enumeration of somebody else's class is wrong the moment they add
a method, and it is wrong quietly. The metatable has no such failure mode:

```
tool:GetStage()
  → not on the instance
  → ix.meta.tool                                   (its own __index)
  → not there either
  → getmetatable(ix.meta.tool).__index = ToolObj   (added here)
  → found
```

`__index` starts as a *function*, because the base cannot be resolved at load;
once it resolves, the function replaces itself with the table so later misses
are plain lookups. Resolution is retried until it succeeds — the warning is
latched, not the failure, so a lookup before the sandbox tools register does not
decide the answer forever.

Nothing Helix defines is overwritten, and here that is guaranteed by the
mechanism rather than by a guard: a metatable is consulted only *after* a lookup
on the table itself has missed.

The load line is now `completed by metatable fallback`, and the first time any
tool method is actually called you get one of:

```
[falloutrp] tool base: delegating to the sandbox implementation.
[falloutrp] tool base: sandbox base NOT reachable - only the per-frame methods are stubbed, the rest are absent.
```

This is almost certainly why nothing else in Helix uses its tool system.

### The convar trap

Helix builds the TOOL and calls `CreateConVars()` **before** including the file
— `create(niceName)` runs, then `IncludeFiles`, in `HandleEntityInclusion`
(`core/libs/sh_plugin.lua`). At that point `ClientConVar` is still the empty
default, so declaring convars in the file is too late and every
`GetClientInfo` reads an empty string.

The file therefore calls `TOOL:CreateConVars()` again after declaring them.
Worth knowing before writing a second Helix tool.

Note also that Helix loads tools from `entities/tools/`, **not** the sandbox
`lua/weapons/gmod_tool/stools/` path — a tool put in the sandbox location is
never loaded by the schema.

---

## The black box

`libs/sv_crashwatch.lua`. A silent crash leaves nothing — no Lua error, no
stack, and `-condebug` ends mid-sentence because the process was gone before the
next line was written. Nothing in Lua can catch that; by the time the engine
dies there is no interpreter left to run a handler in.

So the trail is left **ahead of time**. Every five seconds it writes what the
server is doing to `data/falloutrp_crashwatch.txt`, and on the next boot it
reads the file the previous session left. If that file does not end with a clean
shutdown marker, the session died where the file stops — the file *is* the last
known state, so it is copied to `data/falloutrp_crash_<when>.txt` and the tail
printed to console.

| watched | why |
|---|---|
| edicts | running out is the commonest silent GMod crash. The limit is 8192 and the engine does not warn you |
| entities | the same number from Lua's side, so a leak shows as a climb |
| lua memory | a runaway table kills a server more slowly and just as quietly |
| lua errors | the last error before a crash is very often the cause, and it scrolls off in seconds |
| breadcrumbs | joins, deaths, spawns, weapon draws — the last minute in twenty lines |

`ShutDown` writes the clean marker, so a map change or a deliberate stop is not
reported as a crash. `fo_crashwatch` prints the current state and forces a
write. The edict warning fires once per crossing of 6500 rather than every tick,
and goes into the trail as well as the console — so if a crash follows, the file
says the server was already close.

Cheap on purpose: one small file write every five seconds and a table of sixty
strings. Anything heavier would be a thing to switch off, and a black box that
is switched off is not one.

---

## The world tools

Six more tools live in the same folder and follow the same two rules — the
metatable patch in `libs/sh_toolfix.lua` and the `TOOL:CreateConVars()` call
after the declaration:

| mode | what |
|---|---|
| `fo_zone` | named areas, claimable areas, radiation, out of bounds |
| `fo_zonemusic` | what a zone plays; see `34-world.md` |
| `fo_npcspawn` | NPC spawner pods; see `54-npcs.md` |
| `fo_point` | cap stashes, capture points, orbital drop sites |
| `fo_teleport` | teleport doors, and the faction list on any door |
| `fo_worldtp` | delete the map's own teleports, persistently |
| `fo_worldprop` | the same for the map's doors, props and lights |

All six do their work **on the server only** (the music tool's reload, a preview for the holder's own ears, is the one client-side click) — `LeftClick` returns `true`
immediately on the client. That is the sandbox idiom rather than laziness: the
client runs a predicted click that can be replayed several times for one press,
so anything that spawns or stores must happen at the end that sees it once.
Where the client needs to draw a preview of a click already made, the server
tells it in one message (`ix.zones.SendPending`, `ix.doors.SendPending`).

See [34-world.md](34-world.md).

---

## Permanent props

`gmod_tool permaprop`. Left-click makes a prop survive restarts, right-click
stops it, reload removes it **and** its saved record.

Reload exists because removing a permanent prop is otherwise awkward: the
physgun deletes the entity but not the record, so it returns on the next
restart looking like the delete failed.

Superadmin, checked server-side in all three actions. `fo_permaprops` lists
what is recorded.

Class, model, position, angles, skin, bodygroups, colour, material and frozen
state are kept. A scripted entity is restored by **class only** — it comes
back, but whatever internal state it held does not. `ix_lootable` is
blacklisted because it has its own persistence and would otherwise be restored
twice, giving a duplicate on every restart. Dropped `ix_item` entities are
refused too: they are inventory rows wearing an entity, and restoring the
entity alone gives a ghost nobody can pick up.

---

## The record list is authoritative — in both systems

Both lootables and permaprops originally derived their saved list by walking
live entities. That is wrong in one specific and destructive way:

> A sandbox cleanup removes everything on the map. The next save then writes an
> **empty list** and deletes every container and permanent prop for good.

So in both systems the list of records is kept in Lua and the entities are a
consequence of it:

- a save **refreshes** the transform of anything still alive, so a prop dragged
  with the physgun is written where it was left
- a record whose entity is gone keeps its last known position and **comes
  back** on restart
- the list shrinks through exactly one path — `ix.loot.RemovePlaced` and
  `ix.permaprop.Remove` — which is what "persistent unless you delete it" has
  to mean

`ENT:OnRemove` on a lootable therefore does nothing. Deliberate deletion goes
through the tool's reload, the configurer, or the terminal's CLEAR — all of
which call `RemovePlaced`.

Both save on `ShutDown` as well as on change, since **moving** something does
not otherwise write. A hard crash still loses whatever moved since the last
explicit save; that is the honest limit of doing this without a periodic write.

## Helix storage containers are temporary unless marked

Out of the box every `ix_container` an admin spawns comes back after a restart,
forever. `libs/sv_containerperma.lua` makes that conditional on the permaprop
tool, and the route it takes matters.

**Helix's own hook is a trap.** `PLUGIN:CanSaveContainer` looks like the lever,
but returning false does not mean "skip this one" — the else branch of
`SaveContainer` deletes the container's items and inventory rows
(`helix/plugins/containers/sh_plugin.lua:78`). And `SaveContainer` is reached
from `SaveData`, which runs on `timer.Create("ixSaveData", 600, 0, ...)`
(`core/sh_data.lua:116`). So returning false would empty every unmarked
container on the map, every ten minutes, while people were using them.

Replacing `PLUGIN.SaveContainer` outright is not much better: it means copying
Helix's seven-field save tuple, which stops matching the day they add an
eighth.

So Helix saves and restores untouched, and the schema **removes the containers
that should not have come back**, shortly after boot. Removal goes through
`ENT:OnRemove`, which deletes the items and inventory rows and fires
`ContainerRemoved`, which makes Helix rewrite its own save file without them —
the cleanup is Helix's, triggered rather than reimplemented.

### Two timing traps, both of which delete real data if missed

`ENT:OnRemove` does nothing unless `ix.entityDataLoaded` is true, set two
seconds after `InitPostEntity` (`core/hooks/sv_hooks.lua:770`). Sweeping before
then removes the entities and leaves their rows behind — so they return next
restart, looking like the sweep never ran.

Worse: a restored container does not know its own ID yet.

```lua
ix.inventory.Restore(inventoryID, w, h, function(inventory)
    entity:SetInventory(inventory)      -- this is what calls SetID
end)                    -- helix/plugins/containers/sh_plugin.lua:151
```

That callback is a database round trip, `GetID()` reads 0 until it lands, and
Helix's `RunLoadData` is itself called from the database connect callback rather
than from `InitPostEntity` — so there is no fixed delay that is reliably
"after". A single timed sweep treating an unresolved ID as "not marked" would
**delete permanent containers**.

The sweep therefore runs repeatedly over the first half minute and:

- leaves alone any container whose ID has not resolved, every time — not
  knowing yet is never grounds for deleting somebody's storage
- never touches a container created after the sweep finished; those are tagged
  on `OnEntityCreated`, so an admin putting one down cannot have it swept out
  from under them
- stops as soon as nothing is still waiting

The first version identified restorable containers by reading Helix's own saved
rows and matching inventory IDs. It worked on paper, did not work in practice,
and **was not debuggable from in front of the screen** — it depended on the
field layout of somebody else's save file, and when nothing got removed there
was no way to tell which of five assumptions had failed. Tagging depends on
nothing outside the file, and `fo_containers` prints the decision for every
container on the map: its inventory ID, its model, and whether it was kept as
permanent, kept as a live spawn, left alone for having no inventory yet, or
should have been removed.

### Ownership is a NetVar holding a character ID

Not `SetCreator`, and not CPPI. The first version set both and neither did
anything, because Helix's own prop protection asks a different question:

```lua
if (entity:GetNetVar("owner", 0) != characterID    -- plugins/propprotect.lua:82
```

and Helix stamps ordinary props as

```lua
entity:SetNetVar("owner", client:GetCharacter():GetID())  -- sv_hooks.lua:413
```

A container misses that because it is a **second entity**: Helix stamps the prop
the player spawned, then the containers plugin creates a container and removes
the prop — and the stamp goes with the prop.

The **character**, not the player, because that is what the check compares
against. It also means the same player's other characters cannot move it, which
is the intended behaviour of a character-scoped ownership model rather than an
accident of it. `SetCreator` and `CPPISetOwner` are set as well, for admin tools
and prop-protection addons that read them.

`CanPlayerSpawnContainer` runs immediately before the creation, in the same
tick, which is the only place the player and the container are both knowable.
The two are matched **on the tick number** rather than by clearing a flag on a
zero timer: two zero timers have no defined order between them, so that version
would work most of the time.

### The sweep runs on `PostLoadData`

`InitPostEntity` does not reach this schema — see `23-looting.md` — which is why
the sweep never ran and every container came back. `PostLoadData` is better than
`LoadData` here specifically: Helix runs it after *every* plugin's `LoadData`,
so the containers plugin has already spawned whatever it is going to.

## Dropped items are cleared on restart

`libs/sv_dropcleanup.lua`, through the lever `saveitems` already has:

```lua
if (hook.Run("ShouldDeleteSavedItems") == true) then   -- saveitems.lua:34
```

Returning true is the whole change — the rows go with the entities, so the
database does not fill with items that no longer exist anywhere. Everything
about how and when stays Helix's. Note the comparison is `== true`, not
truthiness, which is why the listener returns a boolean rather than the config
value.

Items in an inventory, a storage container or a bag are not `ix_item` entities
in the world and are untouched. So are lootable containers, which hold a plain
list and create real items only when something is taken out. Off with
`clearDroppedItems`.

Marked **by inventory ID**, because that is the one thing about a container that
survives a restart; a position would not, since a permanent container can be
dragged elsewhere.

### The tool

`ix.permaprop.Add`/`Remove` intercept `ix_container` before the generic path —
restoring one from the prop list would rebuild the prop and not the inventory
behind it, giving a container that opens empty every restart with the real one
still in the database. `ix_container` is also in the blacklist so a direct
`CanPersist` call agrees.

Reload **does not delete a container**. It unmarks it and leaves it standing: a
container is somebody's stored items, and deleting one silently from across the
room with the same key that tidies up a crate is not a mistake worth making
possible.

`fo_permaprops` counts permanent containers separately from props — "why has my
crate gone" is nearly always one that was never marked.
