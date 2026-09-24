# 34 - Zones, points and doors

Everything placed on the map with a toolgun: named and claimable areas,
radiation, out of bounds, cap stashes, capture points, drop sites, teleport
doors and the map's own teleports.

| | |
|---|---|
| `libs/sh_zones.lua`, `sv_zones.lua`, `cl_zones.lua` | volumes |
| `libs/sh_points.lua`, `sv_points.lua` | placed entities |
| `libs/sh_doors.lua`, `sv_doors.lua`, `cl_doors.lua` | door rules and teleports |
| `entities/tools/fo_zone.lua` | Zone Editor |
| `entities/tools/fo_point.lua` | Point Placer |
| `entities/tools/fo_teleport.lua` | Teleport Door |
| `entities/tools/fo_worldtp.lua` | World Teleport Remover |
| `entities/tools/fo_worldprop.lua` | World Entity Remover |
| `entities/entities/ix_capstash.lua` | a cache of caps |
| `entities/entities/ix_captureflag.lua` | a capture point |
| `entities/entities/ix_orbitalpad.lua` | a drop site marker |

| command | needs | what |
|---|---|---|
| `/claimarea [name]` | faction rank 3 | take the area you are in |
| `/unclaimarea [name]` | faction rank 3 | give it up |
| `/areas` | — | who holds what |
| `/zones` | `zone.edit` | every zone, including the invisible ones |
| `/zonedelete <name>` | `zone.edit` | delete by name |
| `/points`, `/droppoints` | `point.edit` | what is placed on this map |
| `/doorfactions` | `door.edit` | who may use the door you are looking at |
| `/doorfactionadd <faction>` | `door.edit` | let another one in |
| `/doorfactionremove <faction>` | `door.edit` | take one out |
| `/doorteleportclear` | `door.edit` | make a teleport an ordinary door |
| `/tplock` | the teleport's own faction list | lock or unlock one by hand |
| `/buydoor` | — | buy the teleport you are looking at |
| `/selldoor` | — | sell one you own back |

Permissions: `zone.edit`, `point.edit` and `door.edit` are **admin**;
`zone.claim.force` and `door.worldtp` are **super admin** — one takes ground off
a faction that earned it, the other deletes something out of the map for good.

---

## Zones

**Helix already has an area system** — `helix/plugins/area` stores named
axis-aligned boxes, saves them per map, syncs them compressed to every client
and gives each one a table of typed properties. A zone here *is* one of those
areas. Writing a second box system would have meant a second store, a second
sync and a second editor.

Four types, differing only in what reads them:

    area          a named place; its name appears when you walk in
    claim         the same, and a faction lead can take it
    radiation     adds rads for as long as you stand in it
    outofbounds   kills you after a few seconds

### What is *not* reused: "the area you are in"

`PLUGIN:AreaThink` keeps **one** area per player — `overlappingBoxes[1]`,
whichever the hash table yielded first — and that is wrong twice over here. A
radiation cloud drawn over a town would be your "area" some of the time and the
town the rest, and a player standing in two zones needs *both* to act on them.

So membership is worked out at each end for itself. The client picks the
**smallest** displayable box it is inside, which is what nesting is for — a shop
inside a town says "shop". The server walks every radiation and out-of-bounds
box separately, so overlapping rad clouds **add up** and the **shortest** kill
timer wins. Neither uses `client:GetArea()`. `ix.area.stored` is a complete copy
on both realms, so this costs nothing.

Helix's own notice — bottom left, into the chatbox, one character at a time — is
suppressed by returning `false` from `ShouldDisplayArea`, its own extension
point. The banner is drawn across the top instead.

### The tool

Left click places a corner, left click again places the other and makes the
zone. Right click deletes the zone you are **standing in** — a volume has no
surface to point at, and the smallest one wins for the same reason the banner
picks the smallest. Reload forgets the corner; so does putting the tool away,
because a corner placed yesterday would otherwise make a box across half the map
from a position nobody remembers choosing.

**The box grows upwards from the lower click.** Two points on a floor describe a
rectangle with no height, and a zone with no height contains nobody.

Every zone is drawn as a wireframe while the tool is out, and not otherwise — a
town is a name, not a glowing crate.

### Music

`libs/sh_zonemusic.lua`, `cl_zonemusic.lua`, `entities/tools/fo_zonemusic.lua`.
Any zone can carry a `music` property: a station from `sh_radio.lua`, one
song, or nothing —

    ""                        nothing
    station:newvegas          a station, shuffled
    song:phoenix/music/...    one file, on repeat

— one string, because Helix types and networks area properties one at a time
and the tool panel that sets it is a convar. **The smallest zone around a
player that has music wins**, so a shop drawn inside a town with no music of
its own keeps the town's.

The **Zone Music** tool: left click the floor of a zone (or stand in one) to
give it the track picked in the panel's combo box — every station, every song
of every station, the title themes, and *None* — right click to silence it,
reload to hear the pick for twenty seconds wherever you are. The Zone Editor's
own panel has the same combo, applied when a zone is made, and Helix's area
editor shows the property as a plain text field. The zones' wireframes draw
for both tools. `zone.edit` for all of it; logged as `zoneMusic`.

On the client one channel plays and a list of channels fades out: entering a
zone brings its music up from silence over a second, leaving takes a second
and a half down, and walking from one zone into another does both at once. It
sits under everything else: silent while the character menu is up (that has
its own music), silent while the radio is tuned (the player chose that), off
with `fo_zone_music 0`, and at `fo_zone_music_volume` (0.3) otherwise.

### Claiming

Walking into an unclaimed claimable area prints a line **in chat** saying nobody
holds it and naming `/claimarea`. Chat rather than a notification: a
notification is the same channel as "you are out of ammo" and vanishes the same
way, while a chat line stays in the log and is where somebody would look for the
name of a command. Once every five minutes per place, so walking along a border
does not spam it.

`/claimarea` **starts a capture, it does not finish one.** It needs **faction
rank 3** — the bar `ix.factionmgmt.CanKick` uses — and then you have to still be
standing in the area when the clock runs out. A bar shows the progress; leaving,
dying or being interrupted cancels it. The time is per area, set on the tool.

The earlier version wrote the owner and returned, which made holding ground a
matter of typing first. A capture is something the other side can see happening
and do something about.

A claimed area shows its faction on a **second, smaller line** under the name, in
the faction's colour. Not appended to the name: "Springvale [BoS]" on one line
makes the second half look like part of the name of the town.

**A default faction cannot claim anything.** Wastelanders are the faction nobody
joins deliberately, and "everybody who has not picked a side" is not an
organisation that can hold a town — taking one would hand it to every
unaffiliated character on the server at once. An earlier version let them hold
one *personally*, mirroring `ix.bench.CaptureFor`; that is right for a workbench
one person stands at and wrong for a town.

The faction check comes **before** the admin override, too: `zone.claim.force`
lets somebody take ground off whoever holds it, it does not turn a factionless
admin into a faction. Otherwise the owner written would be one nobody can be a
member of, and nothing could ever release it.

**Taking one off somebody is not a chat command.** Ground changes hands when the
holder releases it or an admin with `zone.claim.force` steps in — otherwise the
whole thing is decided by who typed last.

### Radiation and out of bounds

Rads are a **rate and an interval** — so many rads every so many seconds. Rate
alone could not say "one rad every ten seconds", which is what a lightly
contaminated area is: the smallest step it could take was one per second, and 60
rads a minute is a death sentence rather than a hazard. Each cloud keeps its own
clock per player, so a heavy one and a light one both do what they say while
somebody stands in both, and the clock resets on entry so walking in and out
does not farm doses.

**The fog is Phoenix's, copied exactly**, because what it produces does not look
like particles at all:

```lua
particle/smokesprites_0007..0016   -- large soft smoke sprites
SetVelocity(Vector(0, 0, -100000)) -- with SetCollide(true)
SetLifeTime(0), SetDieTime(1e15)   -- it never dies; it is removed by hand
SetColor(0, 100, 0), alpha 120, size 100
density = surface area / 10000
```

Sprites are spawned anywhere in the box and dropped through the air with no
resistance until collision stops them, so the fog **lies on the ground following
its contours** rather than hanging in a cube. My first version was drifting
motes — small, sparse and obviously spawned, which is a different effect
entirely.

It is built for **every** radiation zone on the map, not only the one you are
standing in: fog that appears as you walk up is fog you can watch appearing, and
the point of it is to be visible from a distance so people know to go round.
Phoenix triggered theirs from `NotifyShouldTransmit` on the area entity; these
zones are table entries with no entity, so a range does the same job.
`fo_radfog_density` thins it, and a per-zone cap stops a box drawn across the
whole map from being a frame rate.

The out-of-bounds countdown is cleared on death as well as on leaving. It was
only cleared on leaving, so the tick — which skips dead players entirely — threw
away its own bookkeeping and never told the client anything, and the countdown
stayed on screen over the death screen. Nothing on this HUD is drawn while you
are dead now; every piece of it is a fact about where you are standing, and a
corpse is not standing anywhere.

---

## Points

A **point is an entity, a zone is a volume**, and that is the whole of the split:
an area is a box you are inside and has no surface, while these are objects you
walk up to and press E on.

**The record is authoritative, not the entity** — the rule `sv_permaprop.lua`
states. A map cleanup removes every entity; if the list were rebuilt by walking
entities, the next save would write an empty one and every cap stash would be
gone for good. Loaded from `LoadData` with a save guard, because
`InitPostEntity` never fires in this schema (see
[07-gotchas.md](07-gotchas.md)).

**Cap stash** — press E and it is **gone**: the caps go to you and the stash is
**removed** until its timer brings it back.

Removed, not hidden, and that took three attempts — the third of which found
the actual fault, which was never the hiding at all. See gotcha 12 in
[07-gotchas.md](07-gotchas.md). The first hid it with
`SetNoDraw` and `SetNotSolid`; the second added a networked `Hidden` flag that
`ENT:Draw` read. Neither worked in game — the model stayed exactly where it was
— and rather than keep guessing which of the three was not arriving, the state
is now one the client cannot disagree about: an entity either exists or it does
not.

That also moved the refill timer off the entity, which is where it belonged
anyway. A stash waiting to come back has no entity to run a `Think`, so the
first version hid the entity so that its own `Think` could unhide it — the
moment the entity went, the timer went with it. `ix.points.Tick` walks the
records instead, once a second, and `/pointdelete <id>` deletes one that is not
currently standing there to be pointed at.

The refill time is stored as **`os.time`**, not `CurTime`. `CurTime` restarts
from about zero on every map load, so a refill saved as `CurTime() + 900` came
back after a restart as a moment nine hundred seconds into a session that had
just begun — the timer was nonsense across a restart in both directions. An empty stash you can still
walk up to is one people keep walking up to, and a label reading "empty —
12:04" is a countdown timer standing in the wasteland. The caps are a number,
not an inventory: a stash is a thing that empties and comes back, not a
container to put things in. The remaining amount is written back to the record,
so a stash emptied two minutes before a restart is still empty afterwards —
otherwise restarting the server would be the fastest way to farm caps.

The payout happens **before** the bookkeeping. Everything after it is saving and
networking, and any of that going wrong used to take the payout with it — the
stash emptied and the caps went nowhere. Two models with no collision hull also
get a bounding box: `PhysicsInit(SOLID_VPHYSICS)` silently does nothing on a
model without one, and a stash that is not solid is one the use trace goes
straight through.

**Capture point** — a square of ground marked in red. Standing in it starts the
capture; walking out stops it where it is. Somebody from another faction in the
square makes it **contested**, which stops it for everybody, so taking ground
means clearing it first. Somebody who may not capture it contests it too —
otherwise a Wastelander would be the ideal escort.

A square and not a sphere: `ents.FindInBox` is what the red outline actually
describes, and a sphere drawn as a box is a point that captures from corners you
were told were outside it.

Leaving **pauses**, it does not reset. A point worn down over an evening is
something two factions can fight over across a session; one that empties the
moment you step off is a test of who can stand still longest without being shot.

Each point can name the factions allowed to take it (blank means any real one),
and pays its holder — every online member of the faction — a configurable number
of caps every configurable few minutes, as a notice and a sound rather than a
chat line. That is the point of holding one.

**Every point starts each session unheld.** A point is held by whoever is
standing on it and willing to keep standing on it; carrying yesterday's holder
across a restart would mean a faction that logged off at three in the morning
still owning the map at noon, and being paid for it. Areas are the opposite and
keep their owner — an area is a claim, a point is a fight.

**Turning a lock stops if you look away.** `BeginLock` used `SetAction`,
which is a progress bar and a timer: it finished wherever you were and whatever
you were pointing at, so a lock started at a door turned three seconds later
even if you had walked round a corner. It is a `DoStaredAction` now — Helix's
own, and what every other timed act in this schema uses — which re-traces every
tenth of a second and cancels the moment the door leaves your crosshair.

A teleport's **name has a colour**, set on the teleport tool with the stock
colour picker and stored on the link as three plain numbers — not a `Color`,
because links travel as JSON and a colour comes back from that as a table with
no metatable, which every drawing function refuses. Nothing set falls back to
the pair the sign always used (red locked, pale blue not); a colour that is set
wins in both cases, since the word LOCKED is on the line underneath anyway.

Reload on the teleport tool now applies **everything in the panel** — colour,
price, factions — and a blank name leaves the existing one alone rather than
skipping the write. It used to require retyping the name to change anything
else, and getting that wrong renamed a door somebody had bought.

The tool's **reload applies the whole panel** to the point you are looking at —
name, caps, respawn, capture time, radius, payout, factions — not just the name.
A blank name is left alone, so adjusting a payout does not silently rename it.

**Orbital drop site** — a named position that the orbital drop system picks
from. It was placed here as a marker before that system existed, on the grounds
that "what that system will want is already there: a stable id, a position, a
name, and a record that survives a map change". It is. See
[35-orbital.md](35-orbital.md).

**Plant** - wasteland flora you press E on for the fruit and some experience,
and which grows back on a timer. Seventeen kinds, twenty items, and the reason a
plant is a point at all is the sentence at the top of this section: it is an
object you walk up to and press E on. See [38-plants.md](38-plants.md).

**Stash** - a box that opens **your own** storage. Every stash on the map opens
the same one for a given character, two people at the same box open two
different ones, and deleting a box takes nobody's things with it: the inventory
id lives in character data, not on the record. It is a point for the same reason
a plant is - it is an object you walk up to and press E on - and being one means
`/points` lists it and `/pointdelete` removes it with no second implementation
of any of that. See
[41-crosshair-stash-and-modulators.md](41-crosshair-stash-and-modulators.md).

Models are the ones this server actually has, checked with
`_docs/tools/resolve_asset.py`. A missing model is an error-textured box that
still spawns, still saves and still works.

---

## Doors

### Why this is a layer, not an edit

`helix/plugins/doors` saves a fixed list of net vars:

```lua
local variables = {"disabled", "name", "price", "ownable", "faction",
    "class", "visible"}
```

It is a **local**. A `factions` net var added from the schema would work
perfectly until the next map change and then be gone, because `SaveDoorData`
only writes what is in that table and nothing outside the plugin can add to it.

So the extra rules live in the schema, keyed by `MapCreationID`, saved per map,
and applied through `CanPlayerAccessDoor` — the hook the plugin already asks.
**The hook only ever says yes.** Returning `false` would take access away from
somebody Helix had already granted, so a door with no list behaves exactly as it
did before.

`MapCreationID` is the key because it is the only id a map entity keeps across a
restart. An entity index is assigned at spawn and a position is a float; both
would silently attach a teleport to the wrong door one day.

### Multiple factions

`/doorfactionadd <faction>` on the door you are looking at, or Reload with the
Teleport Door tool. Helix's own `/DoorSetFaction` still sets its single faction;
this is the list beside it.

`ix.faction.Get` is index-or-uniqueID only, so it answers nil for "Brotherhood
of Steel" — the only name a player has ever seen. `ix.doors.FindFaction` tries
the uniqueID, then the display name, then a unique prefix of it. **A prefix that
matches two factions is no match**, because guessing would one day put the wrong
faction on somebody's front door.

### Teleport doors

Click a door **or a prop**, then click where it should send you. **A destination
is a position, not another door**: linking two doors makes every teleport
two-way whether anybody wanted that, breaks when one of the pair is deleted, and
cannot send somebody to the middle of a room.

**A prop works, with one condition.** A map door has a `MapCreationID` and is
there every restart; a spawned prop has neither, so its teleport is remembered
by the prop's **model and position** — which means it lasts exactly as long as
the prop does. Make the prop permanent with the permaprop tool and the teleport
is permanent with it; leave it and both are gone at the next restart, like
anything else dropped on the floor. The tool says so at the moment you make one,
because finding that out the hard way is an evening's work lost.

The load sweep is what enforces it: after `PostLoadData` and again on a timer,
every prop link looks for an entity with its model at its position, and any that
finds nothing is dropped. The sweep runs late rather than on `LoadData` because
`sv_permaprop.lua` restores from the same event, and two listeners on one event
run in whatever order the table iterated.

Reload sets the **name and the faction list** together — both are on the panel,
and having to re-link a teleport to rename it would mean clicking the
destination again to change one word.

### One way and two way

A **two-way** teleport is two ordinary links that name each other, not a third
kind of record. Each side keeps its own destination, name and faction list;
`pair` is one extra field naming the far end, so everything that works on a
one-way teleport works on half of a pair without knowing pairs exist. In two-way
mode the second click is the far **door or prop** rather than a position, and
each side's exit is the doorstep of the other — just outside the face you
clicked.

**Locking one locks the other.** For map doors that is done from Helix's
`PlayerLockedDoor` / `PlayerUnlockedDoor` hooks, which fire after `ix_keys` has
turned the real lock.

### Locking

A prop has no engine lock, and `ix_keys` gates on `entity:IsDoor()` — so a crate
with a teleport on it was not something the keys could be pointed at. The keys'
`PrimaryAttack` and `SecondaryAttack` are **wrapped** to add exactly that case;
every ordinary door still goes to the original untouched. `/tplock` does the
same thing without needing the keys in your hands, and asks the same question:
are you allowed through this.

**It takes three seconds**, with Helix's own action bar — the one a search or a
bandage uses, so it looks like every other thing in the game that takes a moment
and is cancelled the same way. Helix's `doorLockTime` default is raised from 1 to
3 to match, through `ix.config.Add`, which replaces the default and keeps
whatever an admin has actually set. The access check runs twice, before and
after: three seconds is long enough for somebody to have lost the right to do
this halfway through.

### Buying one

A teleport with a **price** set on the tool belongs to whoever buys it with
`/buydoor`, and only they can use or lock it. `/selldoor` sells it back at
`doorSellRatio` — Helix's own config, so a door and a teleport return the same
fraction. Both halves of a two-way pair change hands together; buying one end of
a corridor and finding the other still open to everybody would make the purchase
worth nothing.

Re-pointing a teleport somebody has bought does **not** take it off them.
Selling and breaching are what do that.

`ix.doors.Breach` clears the owner and unlocks both halves. **Nothing calls it
yet** — the breaching charge is a later job, and this is the half of it that
belongs to the door system, written now because the shape of "it becomes unowned
again" is decided here rather than by the item.

Helix already has `/DoorBuy` and `/DoorSell` for its own ownable doors and they
are not these: those work on a map door with `ownable` set and store the owner in
Helix's door data, while a teleport is a link record that can be on a prop. Two
names because they are two things.

**What a teleport says about itself** is drawn by us, on the HUD, when you look
at one — its name, whether it is locked, who owns it or what it costs, and who
may use it. Which way it goes is deliberately **not** on it: that is a property
of how it was built rather than anything the person in front of it can act on,
and the line is only readable at a glance while everything on it is something
they need. Helix's own door sign cannot do it: its draw pass is

```lua
if (!IsValid(v) or !v:IsDoor() or !v:GetNetVar("visible")) then
```

so a teleport on a prop is skipped for not being a door, and a door is skipped
unless something has explicitly set `visible` on it, which nothing does by
default.

The sound going through one is a door opening, not the four-second teleporter
windup it used to play at full volume — that is a set piece rather than a sound
effect, and a corridor of these was unbearable.

`PlayerUse` handles it and returns `false`, so the door does **not** open —
opening it would show the wall behind it on this side of the map.

**Who may use it is who may lock it.** The faction list is the same list
`CanPlayerAccessDoor` answers with, so the factions allowed through a teleport
are exactly the ones who can turn its lock with `ix_keys`. That is "lock the tp
with keys like a door" with no second lock and no second list to disagree with
the first. The lock state is read from the engine's own `m_bLocked`, so a door
locked by keys, by the map or by an admin all count.

An **empty faction list means anybody**, not nobody — a public shortcut is a
door without a list, and the other reading would break every teleport the moment
somebody cleared its list to open it up.

While the tool is out, every teleport draws a line to its destination and a box
where you land. Without it a teleport is invisible until you walk into it.

### The map's own teleports

The engine recreates every map entity on every load; nothing Lua does can change
the BSP. So a deleted teleport is kept on a list and removed **again** after the
map loads and after every cleanup. It is deleted every time rather than deleted
once, which comes to the same thing from inside the game and is the only thing
that is possible.

`trigger_teleport`, `point_teleport`, `trigger_teleport_relative` and
`trigger_changelevel` all count — the last matters most, since on a persistent
server it is the entity that throws everybody at a map that does not exist.

**A trigger has no model**, so `trace.Entity` on one returns the world. The tool
finds the nearest trigger to where you clicked, and every one is drawn as an
orange wireframe box while the tool is out so there is something to aim at.

Those boxes are drawn from **a list the server sends**, not from
`ents.GetAll()`. `trigger_teleport` and its relatives are server-only entities —
no model, never transmitted — so the client's entity list does not contain a
single one, and the first version highlighted nothing at all because it was
asking somebody to point at something their game had never been told about.

The **tool panel lists everything deleted on this map**, with a button per row
to restore it — not just the last one you deleted, and not just this session.
The list carries the class, model and position of each, because "map entity 412"
is not something anybody recognises three weeks later.

Restoring only takes the entry off the list, and both the button and the reload
**say plainly** that it comes back on the next map load rather than implying it
has reappeared.

### The world entity remover

`fo_worldprop` is the same mechanism aimed at everything else the map made —
doors, railings, lights, the ladder in the wrong place. It shares the deleted
list; the two tool panels filter it rather than owning it, because "things taken
out of this map" is one fact and two lists of it would be two lists to keep in
step.

It only touches map entities. A prop somebody spawned has no `MapCreationID`;
recording one would write an id that means a different entity after the next
restart, and the wrong thing would go missing.

---

## Logging

Everything here is logged. Map-building lands under **Admin**; the three things a
player rather than an admin does are routed elsewhere by a longer prefix —
`pointLoot` to Economy, `pointCapture` to Factions, `doorTeleport` and
`zoneOutOfBounds` to Characters — so the admin log does not fill with somebody
walking through a door forty times.
