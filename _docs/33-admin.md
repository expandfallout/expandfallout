# 33 - Administration, punishment, logging and the bin

| | |
|---|---|
| `libs/sh_usergroups.lua` | the ladder, and what each rung may do |
| `libs/sv_usergroups.lua` | storing ranks, applying them, changing them |
| `libs/sv_adminlog.lua` | the searchable log store |
| `libs/sv_tracking.lua` | the logging Helix does not do |
| `libs/sh_punish.lua`, `sv_punish.lua`, `cl_punish.lua` | bans and warnings |
| `derma/cl_adminmenu.lua` | `/admin` |
| `libs/sh_trash.lua`, `sv_trash.lua`, `cl_trash.lua` | the bin |

| command | needs | what |
|---|---|---|
| `/admin` | `player.list` | the menu |
| `/setgroup <player> <group>` | `group.manage` | change a rank |
| `/groups` | `player.list` | the ladder, and who is in it |
| `/plygoto`, `/plybring` | `player.goto` / `.bring` | teleport |
| `/plykick <player> [why]` | `player.kick` | with the reason logged |
| `/logs [text]` | `log.view` | search from chat |
| `/ban <player> <length> [why]` | `player.ban` | `30`, `2h`, `7d`, `0` for ever |
| `/banid <steamid> <length> [why]` | `player.ban` | somebody not connected |
| `/unban <steamid>` | `player.ban` | either id form |
| `/bans` | `player.ban` | the list, in chat |
| `/warn <player> <why>` | `player.warn` | on the record |
| `/warns <player or steamid>` | `player.warn` | read somebody's |
| `/unwarn <steamid> <number>` | `player.warn.remove` | remove one |

---

## Ranks

    user        0    everybody
    vip        10    paid or rewarded; no powers
    helper     20    player list, chat log
    moderator  30    kick, ban (3 days), teleport, every log
    admin      40    spawn items, edit benches, hand out money, 30-day bans
    superadmin 50    edit ranks, use the dev terminal, permanent bans
    owner     100    root - has every permission, including new ones

**The shape is SAM's**, and it replaced a fixed ladder of hardcoded groups that
this file described first. (SAM is Srlion's paid admin mod; none of its code is
here — the ideas below are the ones every serious admin mod converges on.)
Three things it gets right:

**Ranks are data, not code.** They live in `ix.data` and are made in the menu,
so a server can have an `eventstaff` rank without an edit and a restart.

**Permissions are granted per rank, not implied by a threshold.** The first
version gave you every permission at or below your power number — so making a
helper able to read the economy log meant giving them everything a moderator
has. Now a rank grants exactly what it grants.

**Inheritance is separate from authority.** A rank inherits its parent's
permissions and can *revoke* one by granting it `false`. How far up the pecking
order it sits is `immunity`, a number, which is a different question with a
different answer — and a number answers "may this moderator kick that admin" in
one comparison where a chain cannot.

`banLimit` is SAM's too, and worth having for the same reason: the difference
between a moderator and an admin is usually not *whether* they can ban but for
how long.

### The rules that keep it safe

- **Acting on somebody needs strictly more immunity**, so equals cannot touch
  each other — the same rule the faction management uses for ranks.
- **Nobody may hand out, create or edit a rank at or above their own**, or
  `rank.manage` is one step from owning the server.
- **`user` and `owner` cannot be deleted**, and their immunity is forced
  whatever a message claims. They are the floor and the escape hatch.
- **A cycle in the inheritance chain is guarded**, because "moderator inherits
  admin inherits moderator" is a thing somebody will do in a menu eventually —
  and without the guard it is a hung server rather than a wrong answer.
- **Deleting a rank moves its members and children down**, rather than leaving
  them pointing at a rank that no longer exists.

**Permissions are registered, not inferred.** Reading them off the ranks would
only ever show the ones somebody had already granted — so a permission nobody
has yet would be invisible in the very screen you would go to to grant it.

**GMod's own usergroup is kept in sync, coarsely.** Forty-eight places in this
schema ask `IsAdmin()`, as does every third-party addon and sandbox's own tool
permissions, so each rank carries the `user`/`admin`/`superadmin` it maps onto.
The fine rank answers `ix.admin.Can`; the coarse one keeps everything written
before this file from silently breaking.

**Somebody with no stored rank keeps what the server gave them** — which is
what lets the first owner of a fresh server promote themselves without editing
`users.txt`.

### The editor

RANKS in `/admin`: create, edit, delete, and a tickbox per registered
permission grouped by category. An **inherited permission is ticked and greyed**
with the parent's answer standing, so "why can a moderator do that" is
answerable from the screen rather than by walking the chain in your head.

The rank's **ban limit is set here too**, in hours — the difference between a
moderator and an admin is usually not *whether* they can ban but for how long.
Zero lets them ban permanently. It is shown on the rank's row in the list, but
only for a rank that can ban at all.

Unticking writes `nil`, not `false` — the rank stops *deciding* it and the
parent's answer applies again. `false` would revoke it outright, which is a
different thing and not what unticking a box looks like it means.

---

## Commands

**`!` works everywhere `/` does.** A leading `!` is stripped and the rest handed
straight to `ix.command.Parse` — the same function `GM:PlayerSay` calls for a
`/command` — so every command gets both prefixes and there is still exactly one
place access is decided. `!!` is left alone; somebody typing "!!!" is shouting,
not running a command named `!`.

It does **not** rewrite the text and return it. A `hook.Add` that returns a
value stops `GM:PlayerSay` from ever running, so the rewritten string was said
out loud as chat instead of parsed, and every `!` command quietly did nothing.
See gotcha 9 in [07-gotchas.md](07-gotchas.md).

**A chat type is not a command**, and `!ooc hello` used to say "sorry, that
command does not exist". `/ooc`, `/y`, `/w`, `/me` and `/advert` are chat
PREFIXES: Helix matches them in `ix.chat.Parse` and registers a command of that
name on the client only, so the chatbox can autocomplete it - which means
`ix.command.list` on the server has no entry for any of them. The `!` rewrite
now asks `ix.chat.Parse` with `bNoSend` first, and only sends when the answer
is a real chat type; `ic` means nothing matched, and sending that would say
"/ooc hello" out loud in character.

The verbs: `!ignite` `!extinguish` `!slay` `!freeze` `!unfreeze` `!god`
`!ungod` `!strip` `!respawn` `!blind` `!unblind` `!sethealth` `!setarmour`
`!goto` `!bring` `!return` `!plykick`.

Punishment: `!ban` `!banid` `!unban` `!bans` `!warn` `!warns` `!unwarn`.

Talking: `!a` (admin chat), `!report` / `!help` (open a ticket), `!tickets`,
`!ticketclose`, `/ticketstats`. `@` at the start of a line is admin chat for
staff and a ticket for everybody else - see
[47-chat-tickets-and-gore.md](47-chat-tickets-and-gore.md).

Chat: `chat.bypass` skips the `/advert` and `/ooc` cooldowns — see
[47-chat-tickets-and-gore.md](47-chat-tickets-and-gore.md).

Vehicles: `vehicle.manage` drives, packs and `/vehicleremove`s anybody's — see
[53-vehicles.md](53-vehicles.md). NPCs: `npc.manage` places spawners and edits
presets (`/npcpresets`, `/npcspawn`, `/npcclear`) — see [54-npcs.md](54-npcs.md).

Squads: `!forcesquad [name]` puts the person you are **looking at** into the
squad you name, or into your own; `!forcesquadremove` takes them out of theirs.
Both are behind `squad.force`, both say so in staff chat (so `~forcesquad` is
the silent form), and both are logged as `squadForce` — see
[48-squads.md](48-squads.md).

### The physics gun on people

Left-click picks a player up, right-click leaves them **frozen in the air**,
and physgun-reload releases everybody you froze along with your props.
Permission **`player.physgun`**, config `physgunPlayers`.

Helix already had the pickup half, gated on `client:IsSuperAdmin()` or
`IsAdmin()` - Garry's Mod's ladder rather than this schema's, so a moderator
could not do it however their rank was set up and any GMod admin could do it
regardless of what the rank editor said. It now goes through `ix.admin.Can` and
`ix.admin.Outranks`, so equals cannot pick each other up.

**The freeze is `FL_FROZEN`, not a movetype**, and that is the whole trick: it
is the same flag `!freeze` sets, so it survives `GM:PhysgunDrop` handing
`MOVETYPE_WALK` back a moment later, the player hangs exactly where the beam
let go, and `!unfreeze` releases them because it is the same freeze. Freezing
the physics object - which is what the physgun does on its own - does nothing
at all to a walking player, which is why right-click used to drop them.

`spawn.physgun` (props) and `player.physgun` (people) are deliberately separate:
a builder rank with the first should not get the second. The sandbox hook skips
players entirely rather than checking them, because two `hook.Add` listeners on
one event run in `pairs` order and a version that answered for both would
refuse before the player rule ran on some servers and not others.

Nobody is left hanging: the freezes are released when whoever set them
disconnects, and clearing on respawn means somebody killed while frozen does
not come back unable to move.

They are thin on purpose — `!ignite` sets somebody on fire and writes a log
line. What makes them worth having is that every one goes through
`ix.admin.CanActOn`, so a moderator cannot freeze an admin, and every one is
recorded. `!bring` remembers where somebody was so `!return` can undo it.

### Staff see what staff do

`!bring bob` puts `[STAFF] Alice brought Bob.` in front of everybody with
`admin.chat`. It is a chat class of its own, not admin chat, so a line the
server generated cannot be mistaken for one somebody typed. Every verb calls
`ix.admin.Announce`, which is a no-op for a `~` command.

### `~` — the same command without telling them

`~bring bob` does what `!bring bob` does and says nothing to bob. It is for
watching somebody rather than dealing with them: the moment a player knows an
admin is interested they stop doing the thing.

**It is its own permission** (`admin.silent`) — acting on somebody invisibly is
a bigger thing than acting on them — and without it `~` runs the command
normally and says so. **It covers only the moderation verbs**, listed in
`ix.admin.silent`; `~advert` is just an advert, and `warn` is deliberately
excluded because a warning the player never sees is a note. **Everything is
still logged**, with `[silent]` on the line, since "did they know?" is the one
question anybody asks the log afterwards.

Every verb notifies through `ix.admin.Quiet`, so silence is one decision in one
place and a verb added later that forgets it is loud - the safe way round to be
wrong. A kick or ban cannot be hidden, so `~kick` gives the reason without the
name rather than pretending nothing happened.

### Target tokens

    ^   yourself
    @   whoever you are looking at
    *   everybody on the server

`!goto @`, `!bring *`, `!sethealth ^ 1`. They work on **every command with a
player or character argument**, Helix\'s and the schema\'s alike, because
`libs/sh_targets.lua` wraps `ix.command.Run` — which is where both kinds arrive
and neither knows the difference.

Wrapping `ix.util.FindPlayer` would have been the obvious place and is the
wrong one: it takes a name and nothing else, and `^` and `@` are questions
about *who is asking*.

**It substitutes a SteamID, not a name.** `FindPlayer` matches names loosely —
"bob" finds "bobby" — so writing a name back into the arguments would be
handing an exact answer to a fuzzy matcher. **Only declared player slots are
touched**, so a `*` in a ban reason stays a `*` in a ban reason, and a command
with no declared `arguments` table is left alone entirely.

`*` runs the command once per player, clearing the half-second command cooldown
between runs — without that it would act on the first player and silently do
nothing for the rest — and puts it back afterwards. Each run answers for
itself; the caller is told "Ran on N player(s)" once at the end, and it is
logged.

Every command run is logged under **Commands**, its own category.

### Per-command ranks

Helix decides access at **registration** — `adminOnly`, or a CAMI privilege
baked into `OnCheckAccess` when the command was written. Changing that means
editing the file, and every update overwrites it.

So every command's check is **wrapped once** on `InitializedPlugins` and
consults an override table first. It covers Helix's commands and the schema's
identically, because `ix.command.Run` calls `OnCheckAccess` on both and neither
knows the difference. The COMMANDS tab has a SET button per row; an override
shows in the rank's colour, an unchanged command's own check in grey.

**An override is a rank, not a permission.** Permissions describe abilities and
are worth naming; there are a hundred-odd commands and inventing a permission
for each would be a registry nobody reads. **With no override the command's own
check stands**, so a server that never opens this screen behaves exactly as
Helix intended.

---

## Bans and warnings

`libs/sh_punish.lua`, `libs/sv_punish.lua`, `libs/cl_punish.lua`. The BANS tab
in `/admin`, and the WARN / BAN / WARNS buttons on each player row.

**Both are keyed by SteamID64** — not by character, and not by name. A ban that
could be walked away from by making a new character would not be a ban, and a
name is not an identity.

### The door

The ban is checked at **`CheckPassword`**, which runs before the player entity
exists. Every later hook — `PlayerInitialSpawn`, `PlayerAuthed` — means the
person has already joined, so refusing there is a loading screen, a spawn, and
a line in everybody's chat. `CheckPassword` refuses at the door with the
reason, the admin and the time left on their screen.

It **forces the load** rather than trusting `LoadData` to have run, because
somebody can connect during startup and letting a banned account in because the
file had not been read yet is the one failure this hook exists to prevent.

Bans are stored **globally** — not per schema, not per map. Expired ones are
cleared on load rather than skipped for ever.

### Lengths

Written the way people write them: `30` `45m` `2h` `7d` `3w`, and `0` for
permanent. **A bare number is minutes**, because that is what every admin mod
has trained people to expect and disagreeing with that convention produces very
long accidental bans.

`banLimit` on the rank is the longest ban it may hand out, edited in hours in
the rank editor and stored in seconds. **Zero means no limit**, which is also
the number that means *permanent* for a ban length — the two zeroes mean
opposite things, so both are read through named helpers rather than compared
raw anywhere.

**You cannot ban somebody who outranks you**, and the root account cannot be
banned at all. The online check is the one that can be made — an offline
account has a stored rank but no player to read immunity from.

### Warnings are a record, not a punishment

The point of a warning is that **the next admin can see it**. "Third time this
week" is the fact that turns a kick into a ban, and it is the fact nobody has
when warnings live in somebody's memory or a Discord channel.

So a warning is shown in three places: the person warned is told, and told
their running total; the player row in `/admin` carries the count; and everyone
who can read the admin log is notified when somebody crosses
`warningThreshold` (3 by default). Somebody with warnings is reminded of them
**on join**, because that is the one moment they are certain to read something.

Removing one is a separate permission — `player.warn.remove` — from handing one
out. WARNS on a player row lists them with a REMOVE button; `/unwarn` takes the
number shown beside each.

### The menu

BANS lists them newest first with the remaining time **recomputed every frame**,
so a ban with four minutes left says so until it says three without the panel
being rebuilt underneath somebody. Search covers the name, the id, the reason
and the admin. COPY takes the SteamID; UNBAN asks first.

**The BAN button goes through `/ban`, not a net message of its own.** One place
decides whether a ban is allowed — the rank limit, the root account, the
immunity check — and a second route into banning would be a second place for
one of those to be forgotten.

Every ban, unban, warning and removal is logged under **Admin**, with the
staff actions rather than with the characters they were done to.

---

## Cleanup

`gmod_cleanup` and `gmod_admin_cleanup` are behind `cleanup.self` (admin) and
`cleanup.map` (super admin). They were ungated, and `gmod_admin_cleanup` calls
`game.CleanUpMap` — which removes every entity the map did not create: every
lootable, workbench, faction storage, capture point and placed container. The
records survive so most of it returns on the next map load, but until then the
map is empty and anything mid-flight is gone.

**The only way to gate them is to replace the command.** Both live in
`includes/modules/cleanup.lua` as plain `concommand.Add` calls with no hook of
any kind — the admin one's entire check is `if (IsValid(pl) && !pl:IsAdmin())
then return end` — so there is nothing to listen to and nothing to return false
from. `concommand.GetTable()` hands back the live function, which makes it a
wrap rather than a reimplementation: the original still does the work and keeps
its cleanup types and per-player list.

The console is not stopped — an admin at the server console already has every
permission there is, and refusing them would make the command unusable from the
one place it is safe to run. Refusals are logged, because somebody trying to
wipe the map is exactly what the admin log is for.

---

## Logging

**Helix registers exactly one log type of its own** — `charMoneyGive`. A server
running it has no record of who picked up what, who dropped what, who moved
money, or what anybody said. Every question an admin actually gets asked is
about one of those.

**One handler catches everything.** `ix.log.RegisterHandler` is called by the
framework for every log it writes, with the client, the type and the raw
arguments — so one handler captures Helix's logs, this schema's, and anything
added later, without a single call site changing. Nothing has to remember to
log to us.

Entries are structured, not sentences: time, SteamID, name, character id, type,
category, flag, message **and the raw arguments** — so searching an item id
finds it even when the sentence phrases it differently.

**Kept in memory and on disk.** Memory answers the menu instantly and is capped
at 4000 entries, because an unbounded table on a server that runs for a month
is a memory leak with a nice interface. Disk is one JSON object per line, not
one big array — a day's file is appended to thousands of times and re-encoding
the whole thing per entry would be quadratic.

**Categories are matched by prefix**, longest wins, so `charMoney` catches
`charMoneyGive`, `charMoneyTake` and anything added later with that stem.

### What is now tracked

**Money is wrapped, not hooked, because there is no hook.** `SetMoney` is the
single funnel every path goes through — a shop sale, a `/givemoney`, a salary,
an admin's edit — so wrapping it once catches all of them, including ones
written later. Every change logs the before, the after, the delta and a reason.

**Every item transfer between inventories**, with both ends named in a way an
admin can act on: not "12 to 88" but "Bob (char 4) to faction storage 2". That
line is what item laundering looks like.

**Combat**, which nothing recorded before — Helix logs a death and nothing
about how it happened. Hits are **summarised, not logged per bullet**: a
minigun does twenty hits a second, and a log nobody can read is the same as no
log. They accumulate per attacker-victim-weapon and flush as one entry when the
exchange stops — "Bob hit Alice 14 times for 210 with an AK47 [head/chest/…]
over 6s". A **death carries the last thirty seconds of who hit the victim**, in
order, so "who shot first" is answered by the death line itself. Healing above
5 HP is logged too, because a fight nobody could win reads as a bug until you
see the nine stimpaks.

**The Q menu**, all of it: props, weapons, entities, NPCs, vehicles, effects,
ragdolls, tools, physgun pickups, context-menu properties, noclip and undo.
**Refusals are logged as well as successes** — "nobody spawned a minigun" is
not the same as "somebody tried eleven times", and only one of those tells you
who to watch. Tool *successes* are rate-limited to one per tool per player per
minute, since `CanTool` fires on every click.

Plus: items spawned into the world, weapons drawn, every chat line, connects,
disconnects, character loads, creations, deletions and deaths.

**Equipping is logged from `PlayerWeaponChanged`, not `CanPlayerEquipItem`.**
That hook lives inside the item function's `OnCanRun`, which Helix calls every
time it builds a right-click menu — logging there would write a line every time
anybody looked at a gun, and a log that is mostly noise is a log nobody reads.

### Reading it

**Logs survive a restart.** They always persisted to disk, but the *search*
only ever looked at memory — so everything before a restart became invisible to
the menu while sitting in a file. The last three days are read back on start;
older days stay on disk in the same one-JSON-object-per-line format, greppable.
A line that will not parse is skipped rather than stopping the load, because a
half-written entry from a server killed mid-append is exactly what is in those
files.

Every entry carries a **day stamp** and the **faction the character was in at
the time** — captured when it is written, not looked up when it is read, so
somebody who leaves a faction still shows as having been in it.

**Choosing a category clears the search, unless DEPTH is ticked.** Normally
"show me the economy log" means the old text is stale and keeping it gives an
empty result. With DEPTH on the text survives and the category narrows it,
which is what you want hunting one person across several categories. Clicking
LOGS on a player turns DEPTH on automatically, since that is exactly the case
where the strip must not wipe the filter you just set.

**Right-click any entry** for: copy SteamID, only this player, only this entry
type, copy this line, copy everything shown.

The rows **scroll sideways**. A combat entry naming two players, a weapon, a
hitgroup list and a position is wider than the panel, and a log that silently
truncates its own lines hides the part somebody needed.

The search walks **backwards from the newest**, so a search that hits its limit
returns the most recent matches. "What just happened" is the only question
anybody asks — and when it is not, the log is read in **pages**: the server
answers with the newest two hundred matches and says whether older ones exist,
`filter.page` asks for the two hundred before those, and OLDER / NEWER in the
log tab turn them. Every match is counted on the way past, and the gate on the
finer categories is applied inside the search, so the hint under the list says
exactly what it is showing: "Showing 201-400 of 1234 entries - page 2 of 7". A category or a new search starts again at the newest. The
faction log (`sv_factionlog.lua`) pages the same way, two hundred a page, with
its own OLDER / NEWER. One net message cannot carry thousands of lines, which
is why the cap was there; the pages are why it no longer hides anything.

Categories are gated separately: a helper may read the chat log, but the
economy log is where they would see how much money everybody has. With no
category chosen the results are **narrowed to what they may see** rather than
refused.

Every search is itself logged.

---

## The bin

A trash icon in the top right of the **inventory page** in the menu — a child
of the page, not of the inventory panel. It is not on crates, corpses or
workbenches, where it would be a button that throws away somebody else's
things.

The first version hung it inside `ixInventory` itself and it was never visible:
that panel sizes itself to the grid *exactly* (`SetGridSize` is
`w * iconSize + 8` wide), so there is no corner in it that is not a slot, and
the slots are built after `Init`, so they draw over anything added there.
Hooking `MenuSubpanelCreated` instead gives the page, which only exists on the
inventory tab — so the "is this my own inventory" test the old version needed
is gone as well. `fo_trash_report` prints the button's parent, position and
visibility.

**Closing the bin asks, it does not decide.** Nothing is destroyed and nothing
is put back until you answer; an unanswered offer puts everything back after
forty-five seconds, and so does disconnecting. The first version restored
everything the instant the window shut, so by the time the confirmation appeared
there was nothing left to destroy and it answered "the bin was empty" whichever
button was pressed — the question was being asked after the answer had already
been acted on.

**The caps row is turned off at the panel**, not at the anchor. `ix.storage`
needs a valid entity to hang the inventory off and it has to be one the *client*
can also see — the open message is a `net.WriteEntity` and the window refuses to
build if that comes back NULL, which is what an invisible prop below the map
does, being outside every client's PVS. So the anchor is the player, which makes
`ix.storage.Sync` offer their money, and `cl_trash.lua` makes
`SetLocalMoney`/`SetStorageMoney` a no-op for that one inventory.

**Clicking it closes the menu**, then opens the bin as an ordinary storage
window. That is not a nicety: `ixStorageView` is a fullscreen panel whose
children are `SetPaintedManually(true)`, so with the menu popup up it is drawn
underneath and invisible while still taking mouse input — and Helix's
`SetLocalInventory` is `if (IsValid(ix.gui.inv1) and !IsValid(ix.gui.menu))`,
so your own inventory never even goes into it. The button appeared to do
nothing at all. Every other container is opened from the world with no menu up;
closing it puts the bin in the same state as all of them. The menu is not
reopened afterwards.

**It is a real inventory**, so dragging into it is the same gesture as dragging
into a crate and needs no new UI. More usefully, an item in the bin is still a
real item until you confirm: **closing without confirming puts everything
back**, because a bin you cannot change your mind about is a bin nobody will
risk using.

**One per character, made on demand, never saved.** A persistent bin would be a
free extra bag that happens to be called "trash".

Every destroyed item is logged **by name and id**, not as a count — "threw away
6 items" is useless to somebody asking what happened to a rifle.
