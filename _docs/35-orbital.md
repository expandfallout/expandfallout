# 35 - Orbital drops

Every so often a beacon lands on one of the drop sites placed with the point
tool. It counts down under a red dome, a cargo craft flies in, and a container
of loot falls out of it. The container is worth fighting over and disappears
after a few minutes.

| | |
|---|---|
| `libs/sh_orbital.lua` | configuration, timings, the asset list |
| `libs/sv_orbital.lua` | when and where one happens |
| `entities/entities/ix_orbital_beacon.lua` | the beacon, the dome, the countdown |
| `entities/entities/ix_orbital_drone.lua` | the cargo craft and the drop |

| command | needs | what |
|---|---|---|
| `/orbital` | `orbital.force` | call one now, at a random site |
| `/orbitalhere` | `orbital.force` | call one at the nearest site |
| `/orbitalcancel` | `orbital.force` | call off the one happening |

**Everything is on the ORBITAL tab of the dev terminal** — the timings, the loot
table (chosen from a menu of the ones that exist), the minimum players, the
announcement, a count of the drop sites, and the buttons that call one and
cancel one. That is where somebody testing the event
already is, and having the numbers three menus away from the button that uses
them is how a countdown gets set to an hour and left there.

Helix's own config menu still has all of them; the terminal is a second way in,
not a replacement, and both write through `ix.config.Set`. The terminal sends a
key and a value, and the server checks the key against **a closed list** —
`ix.config.Set` will happily write any key in the registry, including Helix's
own, and the terminal is not a general config editor. The type is taken from
what is already stored rather than from the message: a number field that arrived
as a string would be saved as a string and read back by `math.max` as an error
some minutes later in a different file.

Drop sites are placed with `fo_point`, which has had an `orbital` type since it
was written — described at the time as "a marker with a name and a position,
placed now so the map work can happen before the drop system exists". This is
that system, and it reads that list.

---

## What came from Phoenix

Their `plugins/orbital_drops`, as closely as this server can carry it. Their
shape, their timings and their configuration, all of which the scrape did
capture:

```
Orbital Event Timer      3600   how often one happens
Orbital Beacon Time       300   how long the beacon counts down
Orbital Self Destruct     300   how long the container lasts
Orbital Minimum Players    30   below this, nothing happens
beacon -> 15 seconds -> drone -> drop at 58% of its pass
radius 640 for the dome and the PVP warning, 2500 to draw it
```

**The event half is reconstructed, not ported.** glua-steal never retrieves
server files, so `sv_plugin.lua` is not in the scrape — what exists of theirs is
the two entities and the config list. The entities name what the missing half
must have done: pick a point, spawn a beacon on it, do that on a timer when
enough people are on.

**The draw code is written, not copied.** Theirs calls `nut.gui.palette` and
their own net vars, and this project's rule is that the scrapes are a reference
and never a source. What it produces is the same.

### The minimum player count is theirs

30, unchanged. On anything smaller than a full server that means nothing ever
happens on its own — which is a real decision about when the event is worth
running, not an oversight, so it was not quietly lowered. `/orbital` forces one
regardless, which is how you test it.

The clock is **not** reset when the check fails, so a drop happens as soon as
the server is busy enough rather than an hour after it becomes busy enough.

### The one addition

Phoenix announce nothing — their beacon is the announcement, and you have to be
within 640 units to see the countdown at all. That works where everybody has
learned the sites. `orbitalAnnounce` (on by default) says which site in chat;
turn it off once the sites are common knowledge and it is exactly theirs.

---

## What could not be carried

Checked with `_docs/tools/resolve_asset.py`, not assumed:

| theirs | why not | instead |
|---|---|---|
| `models/roadkill/fallout/vehicle/cargobot.mdl` | not installed | `models/fallout/vertibird.mdl` |
| `models/galang/fallout/props/airdroppedcontainer.mdl` | not installed | `models/models/fallout/lonesomemilitarycrate.mdl` |
| `fx/orbital/*`, `fallout/orbit/standby.wav` | not installed | Phoenix UI sounds |
| `HL1/fvox/blip.wav`, `flatline.wav` | needs HL1 mounted | Phoenix UI sounds |

They are all in one table, `ix.orbital.assets`, so a server with the real
content has one place to change.

The doubled `models/models/` in the crate path is not a typo — the
two-wastelands pack nests its content one folder deeper than its own root, so
that is the path, and the resolver confirms it.

**The cargobot is the interesting one.** Phoenix drive theirs off a `dropoff`
animation, advancing the cycle by hand and dropping the crate at cycle 0.58:

```lua
if self.Cycle >= 0.58 and SERVER then self:AmazonDelivery() end
if self.Cycle >= 1 and SERVER then self:Remove() end
```

`mdlseq.py` says the vertibird has two sequences, `idle` and `spin`. There is no
dropoff to play. So the cycle drives a **flight path** instead of an animation,
at the same fraction of the same length of time — the crate is let go at 0.58
and the craft is gone at 1.0, exactly as theirs. What changed is that the craft
moves through the air rather than hovering while its model animates, which is if
anything closer to what the animation was depicting.

---

## How it plays out

**The beacon** lands, plays a standby tone and sets a `DropTime` net var — so
the countdown needs no message of its own. A red glow sprite blips, and the blip
runs down faster in the last three seconds; the sound, the dynamic light and the
sprite's size are all driven by the same falling number, so they speed up
together without a second clock. That is theirs and it is a good trick.

**The dome is drawn with a stencil**, which is also theirs and worth keeping. A
plain translucent sphere is drawn over everything inside it, so a player standing
in one would see the world through red. Writing the floor box to the stencil
buffer first and testing the sphere against it means the dome only appears where
the marker on the ground is — a dome sitting on the world rather than a filter
over the camera. The sphere is drawn twice, the second time inside out, so it is
there from within as well.

Inside 640 units you get `Drop Countdown: hh:mm:ss` and `WARNING: PVP ZONE`.

**At zero** the beacon plays an alert and tells anybody nearby to stand clear,
then fifteen seconds later the craft appears and the beacon removes itself. It
hands the event over before it goes: `ix.orbital.active` is what stops a second
drop starting, and a gap between the beacon going and the craft arriving would be
a gap where one could.

**The craft** comes in from a random bearing, is exactly overhead at the moment
it drops, and carries on out the other side. The carried crate is a separate
parented prop — non-solid and in the debris collision group so nobody can shoot
it down or stand on it — and it is **replaced** at release by the real container.
The thing that falls is not the thing that was carried, which is theirs and is
why the carried one never has to hold anything.

**The container** is a real lootable with a real table, spawned with `bNoSave` so
it is not written into the placed list — something that self destructs in five
minutes has no business being restored on the next map load. It is given its
physics back for the fall, because a placed lootable is frozen on purpose.

**It is an ordinary lootable with a different table on it, and nothing else.**
`orbitalLootTable` picks which one, from a menu of the tables that actually
exist — a typed name that does not match is a container that opens empty, and
the misspelling is invisible until somebody flies out to a drop and finds
nothing in it. A missing table is reported to the console rather than swallowed.

Phoenix hardcode theirs as `{table = "Orbital_Looter", count = 4}` and that
`count` was carried across at first: four passes over the table into one
container. It was taken out again. It is a second way of saying "make it
generous" on top of the table itself, so what was in a drop became a function of
two numbers in two different screens. One number in one screen — build the table
to be worth flying out for, and there is nothing else to tune.
