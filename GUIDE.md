# Using this server

Side Note: This is a burner github account don't try to contact it, it is of no use.

You have been handed a Garry's Mod Fallout roleplay server. This is the
walkthrough for someone who has never seen it. `README-MIGRATION.md` beside this
file records how the folder was built and what was taken out of it; the real
documentation is the 55 numbered files in `_docs/`.

---

## 1. What this folder is

It is the custom half of a server: the schema, the Helix framework it runs on,
45 addons, the map, the configuration and the saved world. It is **not** the
game engine. You install that separately and lay this on top.

```
GUIDE.md              this file
startserver.bat       the launcher
steam_appid.txt       contains 4000, the Garry's Mod app id - do not edit
garrysmod/            addons, cfg, data, gamemodes, maps, settings
_docs/                55 numbered documents, plus reference/ and tools/
```

There is no character database. Helix creates an empty one on first boot, so
the server starts with no characters and no players on record.

---

## 2. Getting it running

**Install the dedicated server.** Get SteamCMD, then:

```
force_install_dir xxxpathxxx
login anonymous
app_update 4020 validate
quit
```

App **4020** is the Garry's Mod dedicated server. The `4000` inside
`steam_appid.txt` is a different thing, the game's own app id, and it must stay
as it is.

**Lay this folder over it.** Copy the *contents* of this folder into
`C:\gmodserver`, merging with what is already there. Not the folder itself, its
contents. When you are done, `srcds.exe` and `startserver.bat` sit side by side.

That matters: the launcher starts with `"%~dp0srcds.exe"`, which means "the
engine next to this batch file". Put the batch file anywhere else and it will
not find the engine. The upside is that the whole install can be moved or
renamed later and it still works.

**Run `startserver.bat`.** That is the whole procedure. Every addon is already
present as a real folder, so nothing downloads first.

### What the launcher is doing

```
"%~dp0srcds.exe" -console -condebug -tickrate 16 +maxplayers 5 +gamemode falloutrp +map rp_utah_a
```

| Argument | Meaning |
|---|---|
| `-console` | Run in a console window rather than the GUI. |
| `-condebug` | Mirror output to `garrysmod/console.log`. It is buffered, so a force-killed server loses the tail. |
| `-tickrate 16` | Simulation rate. Can only be set here, never in `server.cfg`, and the rate values in `server.cfg` are matched to it. Change both together. |
| `+maxplayers 5` | Slot count. Raise it here. |
| `+gamemode falloutrp` | The schema. Never `helix` - loading the framework directly errors. |
| `+map rp_utah_a` | The patched map. The name matters, see section 7. |

Engine settings live in `garrysmod/cfg/server.cfg`, which the engine runs by
itself. Startup arguments live in the batch file. Things like the server name,
LAN mode, passwords and slot limits are commented in `server.cfg` where they
appear.

The server ships as `sv_lan 1`, meaning local network only and no listing in
the public server browser. Set it to `0` when you want to be found.

---

## 3. Make yourself admin

Nobody has admin until you do this, and there is no in-game way around it. Pick
either route; one is enough.

**Route A, the schema's root account.** Open
`garrysmod/gamemodes/falloutrp/schema/libs/sh_usergroups.lua`, find
`ix.admin.rootSteamID`, and replace `PUT_YOUR_STEAMID64_HERE` with your
**SteamID64** - the 17-digit number beginning `7656119`. That account is root
and cannot be demoted by anybody, including itself.

**Route B, the engine's admin list.** Open `garrysmod/settings/users.txt` and
uncomment the example under `"superadmin"`, replacing it with your
**`STEAM_0:X:XXXXXXXX`** id.

The two files want **different formats** and this is the usual way people waste
an evening. `sh_usergroups.lua` wants the 17-digit SteamID64. `users.txt` wants
the old `STEAM_0:` form and silently ignores anything else, including a
SteamID64 or a profile link. Either file is read at server start, so edit before
booting or restart afterwards.

**Do both, in fact.** They grant different things. `rootSteamID` gives you every
permission the schema itself checks, but not Garry's Mod's own `IsAdmin`, which
a few commands and the permanent-prop tool still ask for. `users.txt` gives you
that. Setting both takes a minute and saves a confusing afternoon.

**Be careful with the Lua edit.** The schema loads `libs/` in a plain loop with
no error trapping, so if your edit leaves that file unparseable, every file
after it alphabetically never loads either. The symptom is not a tidy syntax
error, it is several unrelated systems missing at once. Change the one string,
change nothing else, and check it before you boot:

```
python _docs/tools/luacheck.py garrysmod/gamemodes/falloutrp/schema/libs/sh_usergroups.lua
```

That file's name begins `sh_`, so the server sends it to every client. A
SteamID64 is public information and this is normal, but do not put anything
private in that file expecting it to stay on the server.

---

## 4. Letting other people play: the content pack

This is the part that makes a working server look broken, so read it before you
invite anyone.

A dedicated server **does not send models, materials or sounds to players**. Lua
reaches them automatically, so the code runs on their machine, and then it asks
for a model they do not have. The result is a player who connects fine and sees
errors where the guns and armour should be.

Content reaches players one of two ways: a **Steam Workshop collection** that
the server advertises, or a **FastDL** web host set in `sv_downloadurl`.

### The map is the awkward one

The server runs `rp_utah_a`. That is a **locally renamed and patched copy** of
Workshop map `2974325085`, carrying a restored AI nodegraph and extracted
materials. The Workshop copy is called `rp_utah`, so a player who downloads the
collection does **not** end up with the file this server runs, and cannot load
into the map at all.

So one of these has to be true before anyone else can join:

1. You distribute the patched map yourself, over FastDL or as a Workshop item.
2. You run the original `rp_utah` instead and give up the restored nodegraph,
   which is what makes the NPCs path properly.

Before choosing option 1, read the licensing note in `README-MIGRATION.md`. The
map is somebody else's work and this copy is modified; the same caution applies
to `meleearts2_content` and `longsword_base`, which are also not yours. Check
you have the right to publish each one before you upload it.

### One loose end

Four items on the list are not mounted by the server at all: Widowz Content,
Placeable Particle Effects, Nodegraph Editor+ and HintNode Loader. They are
there for the client or for map work. Leave them in.

---

## 5. What the server actually is

A brief tour, so you know what you have.

**Characters** belong to one of 45 factions with 222 classes between them, and
one of 44 races covering humans, ghouls, super mutants, deathclaws, robots and
more. A character is composed at render time from an animation skeleton plus
separate body, head and hair meshes, which is why one armour item fits every
race and both genders.

**S.P.E.C.I.A.L.** is the seven canonical attributes, 15 points to spend at
creation and a ceiling of 25 each. They do real work: Strength, Perception and
Intelligence each add damage to melee, ballistic and energy respectively,
Endurance is the stamina pool, Agility is movement speed, Luck raises XP, loot
rolls and crafting quality, and Charisma limits what a mugger can take.

**Inventory** is a 10 by 7 grid. Items stack by dragging one onto another. Three
bag items take up space in your grid and open a container of their own.

**Weapons** are 217 ranged on the Longsword base and 87 melee on Melee Arts 2,
with tracers, scopes, projectiles and per-weapon hit-group damage profiles. Guns
can be branded to a faction, stamping a mark and serial on that specific weapon
for life.

**Armour** is 686 items across 14 slots, with damage resistance pooled
separately for head and body. Power armour runs on Fusion Cores that drain over
time.

**Survival** is hunger and thirst as independent meters that drain faster the
harder you move, and radiation with six tiers up to a tick that removes a tenth
of your health.

Beyond that: chems with addiction and withdrawal, XP and levels and perks,
crafting at workbenches from blueprints, looting and mining and farming, an
economy with faction shops and a black market, karma, squads, raids and wars,
orbital drops, restraints and mugging, and permanent death.

Each of these has its own document in `_docs/`. Start at `_docs/README.md`,
which is the index.

---

## 6. Running it day to day

The schema adds **150 chat commands**, around 56 console commands and 11 tool
guns. You do not need to learn them; you need to know they are there and how to
find them.

- Type `/` in chat to see what you can use, or run `fo_commands` in the console
  for the schema's own list.
- `/devmenu` and `/liveedit` open the in-game editors. The live editor changes
  balance values at runtime and writes them to `data/helix/falloutrp/liveedit.txt`,
  which means those numbers live **only** in that file and not in any source
  file.
- Admin ranks, bans, warnings and the log viewer are behind `/admin`, `/logs`,
  `/warn`, `/ban` and friends.
- World building is mostly tool guns rather than commands: `permaprop`,
  `lootable`, `fo_zone`, `fo_point`, `fo_mining`, `fo_npcspawn`, `fo_teleport`,
  `fo_worldprop`, `warpoint`. They are in the tool menu under the schema's
  category.
- NPCs have their own set: `/npcspawn`, `/npcpresets`, `/npcclear`,
  `/npcnodes`, `/npcroute`, `/npcwalk`, `/npcignore`.

Anything you place in the world is saved **against the current map name**. That
is worth remembering before you rename a map, and it is the cause of the known
issue in section 7.

---

## 7. Things that will bite you

**The map name is load-bearing.** Every placed object - benches, vendors,
containers, spawners, ore nodes, crop plots, permanent props - is stored with
the name of the map it was placed on, and only comes back when that name
matches. The map was renamed from `rp_utah` to `rp_utah_a` at some point and the
saved data did not follow, so `data/helix/falloutrp/rp_utah/` still holds
permanent props and an NPC spawner registry that the running map will not load.
Both folders are here. Migrating them means rewriting the map name in those
records.

**The nodegraph decides whether NPCs can path.** The engine rebuilds
`garrysmod/maps/graphs/<map>.ain` when it cannot find a usable one, and writes a
16-byte file with zero nodes. That is what happened on the original machine, and
the symptom is NPCs that move over short distances and refuse anything longer.
The real 938,916-byte graph ships here. After first boot, run `/npcnodes`: it
should say **938,916 bytes**. Any other number means the wrong file won, and
`/npcroute` will show you how far the engine can actually path.

**Content does not reach clients by itself.** Section 4.

**`sh_firerate_diag.lua` is still live.** It hooks every bullet fired by anyone
for as long as the server runs. It is a temporary diagnostic and should be
deleted.

**The shipped admin ranks are older than the code.**
`data/helix/adminranks.txt` exists, and the schema prefers a stored rank list
over its own defaults. That file predates several permissions, so on a fresh
boot an `admin` has no world-building rights at all and the zone, point, door
and orbital tools quietly do nothing. Delete the file to fall back to the code's
ranks, or grant the missing permissions in the RANKS tab of `/admin`.

**A few permissions belong to root and to nobody else.** `npc.manage`,
`vehicle.manage`, `mining.edit` and the ticket permissions are granted by no
default rank, so even a superadmin does not have them. `/npcnodes` is one of
them, which is why the nodegraph check above needs `rootSteamID` set rather than
just an entry in `users.txt`.

**Stop the server properly.** Permanent props, benches and loot are written on
shutdown, not continuously. Closing the console window with the X button, or
killing the process, loses everything those three changed since the last save.
Type `quit` in the server console instead.

`_docs/13-troubleshooting.md` is a symptom-to-cause lookup and is the right
place to look before theorising. `_docs/07-gotchas.md` is the list of
counter-intuitive things about this codebase, and it is short enough to read in
one sitting.

---

## 8. Changing things

The schema is `garrysmod/gamemodes/falloutrp/schema/`. Inside it, files are
loaded by folder, and the **prefix decides where the code runs**: `sh_` on both
server and client, `sv_` server only, `cl_` client only. Get that wrong and the
symptom is usually silence rather than an error.

Content lives where you would expect: `items/`, `factions/`, `classes/`,
`races/`, `attributes/`. Systems live in `libs/`, UI in `derma/`, entities and
tool guns in `entities/`.

**Check your work after every edit.** Two tools, run from the install root:

```
python _docs/tools/luacheck.py garrysmod/gamemodes/falloutrp
python _docs/tools/luaglobals.py garrysmod/gamemodes/falloutrp
```

The first finds syntax errors, the second finds globals that are read but never
set - the typo class that a syntax check cannot see. They are fast enough to run
on the whole schema.

`_docs/tools/` also holds generators that write item files in bulk. They now
work out the project root from their own location, so they run wherever this
folder is. They **write and delete schema files**, so run them deliberately and
know what you are asking for. `_docs/14-procedures.md` walks through adding a
weapon, an addon, a faction and a plugin step by step.

---