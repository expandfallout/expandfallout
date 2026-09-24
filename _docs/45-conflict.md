# 45 — Lockpicking, ambushes, raids and wars

Four systems that landed together, three of which are the same one wearing
different clothes. Phoenix are the reference for all four.

| | |
|---|---|
| **Lockpicking** | `sh/sv/cl_lockpick.lua`, `derma/cl_lockpick.lua` |
| **Ambushes** | `sh/sv/cl_ambush.lua` |
| **Raids & hostilities** | `sh/sv/cl_raid.lua`, `derma/cl_raidstats.lua` |
| **Wars** | `sh/sv/cl_war.lua` — a raid type with ground and an approval |

---

## Lockpicking

The New Vegas lock: a cylinder you turn with the left mouse button and a bobby
pin you rotate with the mouse. Same two models and the same sounds Phoenix use
(`lockpickinterface.mdl`, `bobbypin01.mdl`, `hrp/fx/lockpicking/*`), all from
`af_content_pack_1`, which this schema already mounts.

**Looters only, for now.** `ix.lockpick.canPick` is the list of classes a lock
may go on and it holds one entry. Doors, workbenches and teleporters each have
their own idea of what "locked" means; adding them is a decision about those
systems rather than about this one.

### The answer lives on the server

The client never learns where the sweet spot is. It sends the angle the pin is
at; the server replies with **one number** — how far the cylinder turns from
there, 0 to 1, where 1 opens it. That is the same shape Phoenix use and the only
shape that cannot be read out of a client's memory.

```lua
ix.lockpick.Difference(angle, sweetSpot, level)
```

Difficulty is a **tolerance in degrees** — how far off you may be and still
open it — rather than Phoenix's 0.9-to-1.0 thresholds, because degrees are the
thing being aimed at:

| | Very Easy | Easy | Average | Hard | Very Hard |
|---|---|---|---|---|---|
| tolerance | 20° | 14° | 9° | 6° | 3° |

Outside the tolerance the cylinder still turns *some* of the way, falling off
with the distance and capped below 1. That partial turn is the whole minigame:
a cylinder that barely moves says "nowhere near", one that almost goes round
says "a hair to the left".

### Pins, and what a snapped one costs

Holding the turn against the stop wears the pin down; at zero it snaps, the
server takes one **Bobby Pin** (`equipment_lockpick`) out of the inventory, and
a **new sweet spot is rolled**. A player who could learn the angle once would
only ever have to pick a container once.

The pin's condition is drawn as a bar, which Phoenix do not do — without it the
snap is a surprise every time.

### Placing a lock

| | |
|---|---|
| the lootable tool | a **Lock** dropdown, alongside model and respawn |
| `/lootconfig` | a **LOCK** row of six buttons, used by PLACE HERE and ARM TOOL |
| `/lootlock <0-5>` | set the lock on the container you are looking at |

A picked container **relocks itself** after `lockpickOpenTime` (300s), and a
container that respawns its loot comes back locked. Otherwise a lock is a lock
exactly once, on the day the map was made.

---

## Ambushes

`/ambush` asks for confirmation, then marks your faction as fighting for
`ambushDuration`. Everybody on the server hears distant gunfire and reads one
of Phoenix's seven lines in orange — **late**, after `ambushNoticeDelay`,
because the line is the sound of a fight reaching everybody else rather than
the announcement of one. Your faction sees a countdown at the top of the
screen; `/ambush` again offers to end it early.

**The cooldown is per faction**, not per player — an ambush is the faction
acting, so it cannot send its next enlisted man to do it again a minute later.
Enlisted and up (`ambushMinRank`, rank 1); wastelanders are the default faction
and cannot, and neither can a faction marked immune.

`/ambushend` and `/ambushcooldownclear` are the admin half.

---

## Raids and hostilities

**One conflict at a time**, it has a type, and the type decides everything else.

| | Hostilities | Raid | War |
|---|---|---|---|
| shape | 1v1 | any number of factions | 1v1 plus ground |
| assist | no | yes | yes |
| skirmish | no | yes | yes |
| called by | scoreboard button | scoreboard button | `/war`, then approval |

Every faction row on the scoreboard carries **RAID** and **HOSTILITIES**
buttons, and each asks before it does anything: calling one commits your whole
faction for a quarter of an hour and puts it on cooldown for longer. A button
that cannot be pressed is **shown disabled with the reason in its tooltip**
rather than hidden — "why can I not raid them" is the question, and an empty
row does not answer it.

Once a conflict is running the buttons change to **ASSIST** (join a side) and
**SKIRMISH** (fight everybody), on the factions already in it. The faction that
called it stays at the top of its column and assists sort **under** it in a
fixed order — `pairs` order changed with every sync, so an assisting faction
could push the principal down and swap places with another while nobody had done
anything.

### Three sides, not two

`attackers`, `defenders` and `skirmishers`. Phoenix leave skirmishers off the
result bar; this schema puts them on it, which is the honest answer to who won.

### Cooldowns

**Per faction, and global to the faction.** Taking part at all — caller, target,
assister or skirmisher — puts you on cooldown when it ends, and a faction on
cooldown can neither call one nor be called on. That is the rule that stops
three factions taking turns on one victim.

Cooldowns and shields are **saved as seconds remaining**, not as `CurTime`
values: `CurTime` restarts with the map, so a stored 4000 would be either the
past or the future depending on how long the server had been up. Without that,
a restart is a weapon.

### Raid shields

`/raidshield` (officer and up) makes a faction unraidable for
`raidShieldDuration`; `/cancelraidshield` drops it early **without refunding
the cooldown**. Admins force one on or off with `/raidshieldset <faction>
<minutes>`, 0 to remove.

### Faction flags

Both live in `/liveedit` under FACTIONS, both default off:

- **Immune to raids** — cannot be raided *and cannot raid*, which is the half
  people forget. Immunity is being out of the fighting, not being safe in it.
- **Hidden from the tab menu** — gone from the scoreboard entirely, buttons and
  all. You cannot raid a faction you cannot see.

### `/raidstats`

Kills and deaths, per faction and per person, recorded **as the conflict
happens** — a player who disconnects mid-raid still fought in it. A kill only
counts when both parties are in the conflict, or the scoreline would measure
who found more bystanders.

**A death counts however it happened** — falling off a roof, drowning, or being
shot by your own side all cost the faction the same thing, and a scoreline that
only counted tidy enemy kills would flatter whoever died carelessly rather than
whoever died fighting. A **kill** is narrower: a real player, on a side, on a
*different* side. Shooting a bystander is not a raid kill, and neither is
shooting your own man — the death already costs your faction, and paying a kill
for it too would make team-killing a way to inflate a ratio.

The bar is each side's share of the killing. Click a faction's icon (its own
`FACTION.icon`) for the people who fought for it, sorted by kills and then by
fewest deaths — the ratio without the division by zero.

### Admin

`/stopattack` (or `/raidstop`), `/raidstoggle` (switch raids off entirely for an
event) and `/raidcooldownclear`.

**The attacking faction can call its own conflict off** — a CALL OFF button on
the defender's scoreboard row, NCO and above. The defenders get no such button:
"call off the raid on us" is a surrender that costs the other faction their
fight. The cooldown still applies either way, or calling one off would be a way
to dodge it.

**The report is kept, not shown.** The ending announcement says to type
`/raidstats`; a window that opened itself over everybody's screen at the final
whistle appeared exactly while people were still shooting.

`/raidforceside <faction> <attackers|defenders|skirmishers>` and
`/raidtestskirmish` put a faction into a running conflict whatever the rules
say — for testing, because there is no other way to see what a skirmish looks
like on a quiet server.

### Cooldowns, cleared

```
/cooldownclear [faction]     everything stopping them fighting
/cooldowns                   who is on what, right now
```

**One command for all three cooldowns**, because "clear their cooldowns" is one
thought and remembering which of them a war used is not — a war *is* a raid
here, so its cooldown is in the same table. `/raidcooldownclear`,
`/warcooldownclear` and `/clearcooldowns` are aliases of the same command. With
no faction it clears everybody, which is the event-night case.

It clears the **conflict** cooldown, the **shield** cooldown (how soon another
shield may go up) and the **ambush** cooldown. It does **not** drop an active
raid shield — that is something a faction chose and paid for, not a cooldown;
`/raidshieldset <faction> 0` removes one, and the reply says so when the faction
you just cleared is still shielded.

`/cooldowns` lists only the factions with something running — conflict, shield,
next-shield and ambush — because a page of forty-five "nothing" rows is a page
nobody reads to the bottom of. It is the answer to "why can't we raid them".

`/ambushcooldownclear [faction]` is the narrow one, for when the ambush is all
you mean.

---

## Wars

A raid with ground and somebody's permission. Three steps, because a war is an
event and events are arranged:

```
/war <faction> <reason>      a faction LEAD declares. Nothing starts.
/warreason <faction> approve staff approve it. It joins the queue.
/startwar                    staff begin it, when everyone is ready.
```

`/startwar` takes no faction when there is only one approved war, which is the
normal case — one conflict at a time is the rule the whole system is built on.
It still accepts one for the case that needs it: two factions approved at once,
and somebody has to say which.

**Both factions' cooldowns are checked again at the moment it starts**, not just
the defender's. Checking only the target was how a faction that had just fought
a war could be walked straight into another one.

Only staff with the **`war.approve`** permission are told a war has been
declared — announcing it to the server would start the fighting before anybody
had approved anything. They get it **in chat**, with the reason and the two
lines that answer it:

```
/warreason <faction> approve
/warreason <faction> deny
```

A command rather than a window: a box over whatever staff are doing gets
dismissed by whoever happened to be moving their mouse, and a war can wait.
`/warlist` is the queue, and the **War Point Placer's panel lists it too**, with
`(NO POINT)` against either faction that still needs ground.

The rules are **checked again at the moment it starts**: a war approved an hour
ago is a war whose target may since have been raided, shielded or emptied.

### A war is won on the ground, not on the clock

Taking the enemy's point **ends the war** — the clock is only a fallback for a
war where nothing changed hands. Both flags start **already owned by the side
whose ground it is**, so a faction cannot capture its own (the flag does nothing
when the claim matches the owner) and each side has something to take rather
than an empty square to reach first.

`/warmulticap` is not a command - it is two settings in the terminal:

| | |
|---|---|
| `warMultiCap` | off, a point falls to whoever walks onto it |
| `warCapPlayers` | how many of them it takes when it is on |

On a big map, one is a war decided by the person who left the fight.

The whole server hears what is happening on a point: **being taken** when
somebody walks onto it, **contested**, **no longer being taken** when they are
killed or step off, and **needs N people** when multicap refuses a lone capturer.
Each line is said once, and a state that comes back after a different one is a
new event and is said again - "being taken", "contested", "being taken" is three
things happening rather than one repeated.

**Walking off loses the progress.** Giving up on a point is giving it up; the
only thing that HOLDS progress where it is is somebody standing there contesting
it, which is the one case where both sides are still fighting over it.

The flags are removed when the war ends - from the list, and then by sweeping
the map for anything flagged `ixWarPoint`, because a Lua refresh rebuilds the
list as empty while the entities it named are still standing there.

The ending names a **winner**: whoever holds ground they did not start with. A
war where neither side took anything is a draw, which goes to nobody rather
than to the defender by default.

### The ground

Each faction has a war point, placed with the **War Point Placer** tool — pick
the faction, left click to place, right click to ask whose a point is (and set
the tool to them), reload to clear one. `/warpointset <faction>` does the same
thing from where you stand. Points are **invisible between wars** on purpose, so
the tool flashes every one of them up for fifteen seconds after each action.

**The ground is required at `/startwar`, not at `/war`.** A war is declared
first and arranged afterwards: staff read the reason, approve it, and then place
points for the two factions in the queue — which is when they know which two
those are. **One point is enough** (a war over one piece of ground); two is one
each.

**Assisting factions capture the other side's point.** `ix_captureflag` normally
groups the people standing on it by faction; a war point groups them by *side*,
so a faction that came to help attack can take the defender's ground and cannot
contest its own side's. The holder shows as "Attackers" or "Defenders" in the
principal faction's colour. The `ix_captureflag` entity is borrowed rather than
rebuilt — it already answers "who is standing here and for how long" — and two
of them are spawned when a war starts and removed when it ends. They are given
a record by hand rather than going through `ix.points.Add`, so they never end
up in the saved point list where a restart would bring them back with no war to
explain them.

War points pay no caps. A war point pays in ground; paying for one would make
standing in a square more profitable than fighting over it.

---

## Settings

Every dial for all four systems is in the dev terminal under **ALL SETTINGS**,
in the `Lockpicking`, `Ambush` and `Raids` categories.

| | |
|---|---|
| `lockpickXP`, `lockpickOpenTime` | reward, and how long a picked lock stays open |
| `ambushDuration`, `ambushCooldown`, `ambushNoticeDelay`, `ambushMinRank` | |
| `raidTime`, `raidCooldown`, `raidMinPlayers` | and the same three for `hostilities` and `war` |
| `raidShieldDuration`, `raidShieldCooldown`, `raidShieldRank` | |
| `warPointCapture` | seconds of standing to take a war point |
