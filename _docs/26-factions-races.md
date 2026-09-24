# 26 - Factions, races, classes and spawns

**45 factions, 44 races, 222 classes.** Phoenix's 33 factions plus 12 they do
not have, 43 of their races plus the hand-written human, and a class ladder for
every faction.

All three rosters are **generated**:

```bash
python _docs/tools/genfactions.py
python _docs/tools/genraces.py
python _docs/tools/genclasses.py
```

---

## Factions

`_docs/tools/factions.py` is the roster. The generator refuses to write it if
two factions share an id or a global, or if there is not exactly one default.

**The array form matters.** Phoenix write models as a keyed table
(`{["models/..."] = true}`) and Helix's `ix.faction.LoadFromDir` iterates with
`pairs` and precaches the *value*. Fed `true` it silently skips precaching and
character creation breaks with no error. Every generated faction uses the array
form.

### The twelve that are not Phoenix's

Added because this schema has the **armour** for them and a set of raider armour
with no raider faction is content nobody can use. Our armour prefixes map onto
Phoenix's roster almost exactly — `raiders` (24 sets) was the one clear gap.

Raiders, Powder Gangers, Boomers, White Glove Society, Omertas, Chairmen, The
Kings, Children of Atom, Talon Company, Regulators, Railroad, Atom Cats.

### The skeleton is gone

`citizen` and `police` were Helix's demo factions. They took two demo classes
and two `IsPolice` metatable functions with them. `items/sh_soda.lua` mentions
`FACTION_POLICE` only inside a comment block, so it was left alone.

---

## Races

Converted from Phoenix's `schema/libs/races`. A single file of theirs can hold
**several** races — the securitron file also defines "oea" — so the unit of work
is a `local RACE = {}` block, not a file.

**Data fields are carried; function fields are not.** `OnSpawn`, `OnMelee`,
`OnDeath`, `OnThink` and the rest are bodies full of `nut.` calls against
systems this schema does not have. Each generated race lists in its header
exactly what was dropped, so nothing goes missing silently. `startingGear` goes
for the same reason the human race drops it: their lists name items that do not
exist here.

### The creature models are junctioned in

They were all in one addon that was not mounted —
`fallout_snpcs_remastered` (workshop `2600347219`), 2.5 GB. Every other addon
in `garrysmod/addons` is a **junction** to `Desktop/phoenixsourceaddons`, so
this one is too, along with `phoenix_faction_icons_3520608245`.

```
mklink /J <addons>allout_snpcs_remastered_2600347219 ^
          <phoenixsourceaddons>allout_snpcs_remastered_2600347219
```

**43 of 44 races are now fully usable**, one is partial (`behemoth_unity`,
missing one of five models), and none are dead.

A junction is the server half only. Players still need the content, which comes
from the workshop collection — the folder names carry their workshop IDs for
exactly that reason: the folder is what the server loads, the ID is what a
client downloads.

#### A detection trap worth knowing

`os.stat()` **follows** a junction and reports the target's attributes, so a
reparse-point check written against it says every junction is a plain
directory. It needs `os.lstat()`. Windows `dir` shows them as `<JUNCTION>` and
is the quickest way to check by hand.

### Faction icons

`phoenix_faction_icons` is junctioned in too, and its file names do not match
our faction ids — it has `creature`, `outcast` and `gk` where we have
`creatures`, `outcasts` and `greatkhans`. The generator maps the twenty-five
that differ and **prints any faction that ends up on a fallback**, so a
mismatch cannot pass silently. All 45 currently resolve to a real icon.

Twelve of ours have no Phoenix equivalent, so they borrow the nearest thing in
the pack — Raiders take `jackals`, Atom Cats take `robco`, the Kings take
`guardsman`.

---

## Classes

`_docs/tools/classes.py` is the roster; `genclasses.py` writes
`schema/classes/`. 222 classes across all 45 factions.

**Flat, because Helix cannot do otherwise.** `ix.class.LoadFromDir` is
`file.Find(dir.."/*.lua")` with no recursion, and the uniqueID comes from the
*file name*. Phoenix's per-faction subfolders cannot survive the port, and two
factions each with an `sh_enlisted.lua` would silently be one class - so every
id is faction-prefixed.

### One default per faction

Helix assigns `isDefault` on joining a faction and picks **whichever loads
first**. Phoenix have four defaults in the Crimson Caravan, four in ZSD-7 and
four of five in the Shi, so on their server a new Crimson Caravan character is
whatever the file system listed first, which can be the Lead. The generator
refuses to write a roster that does that, and refuses several other things that
fail silently:

- two classes sharing a uniqueID (`LoadFromDir` skips the second)
- a class naming a faction that does not exist
- a class naming a race its faction does not allow - nobody could ever take it

### Rank instead of four booleans

Phoenix carry `CLASS.enlisted`, `.nco`, `.officer` and `.lead`, set on about
half their files and read by nothing. Ours is one ordered `CLASS.rank`:

| rank | |
|---|---|
| 1 | enlisted / member |
| 2 | NCO / manager |
| 3 | officer / senior |
| 4 | lead |

`schema/libs/sh_classrank.lua` is what makes it mean something.

**Nobody picks their own class.** There are exactly two ways to get one:

- `/charsetclass` — an admin puts you in it
- the C menu — somebody above you in your faction does

which is the whole point of having a ladder. `/charsetclass` is the counterpart
to `/charsetfaction` and works the same way: sets the field, saves, done. There
is no revoke, for the same reason there is no "un-set faction" — the field
always holds something, so changing it *is* the removal.

### Two doors, and only one of them was visible

Stock Helix lets any member of a faction switch to any of its classes, so a
Legion recruit could be Legion - Lead the second they spawned. Removing the
Classes tab from the F1 menu was the obvious half — and it was the half that
did not matter. Helix also ships **`/becomeclass` as a plain, non-admin
command** that calls `character:JoinClass` on anything in your own faction, so
with the tab gone a recruit could still type

```
/becomeclass "Legion - Lead"
```

and be one. Hiding a button while leaving the command behind it is a restriction
that looks like it works, which is worse than none. `sh_classrank.lua` nils
`ix.command.list["becomeclass"]` on both realms: the server half refuses it, the
client half stops the chatbox offering a completion for a command that no longer
exists.

Removal rather than a `CanPlayerJoinClass` refusal, because the hook cannot tell
*where* a switch came from — the admin command and the faction menu go through
the same `SetClass`, so a hook strict enough to stop this would stop those too.

### The grant system that used to be here

An earlier version stored a per-character list of classes an admin had allowed,
gated everything at or above a configurable rank behind it, and had three
commands of its own. It is gone, and the reason is worth keeping: once
`/charsetclass` had to hand out a grant to be worth using, and the faction
hierarchy had to hand out a grant to be able to promote anyone, **every route
that set a class also granted it** — so the grant recorded nothing the class
itself did not already say. It was guarding a door that is now simply closed.

It also had a problem it could not have solved: character data is `isLocal`, so
one client can never see another's grants, which is why the faction menu had to
skip the very check it was supposedly enforcing.

What is left is not a permission. A **race lock** is a statement of fact: a
Mother is a deathclaw matriarch, and no permission makes a human one.

It hangs off `CanPlayerJoinClass`, not a `CanSwitchTo` written into 222
generated files: one listener covers all of them, and the rule stays somewhere a
person can read it. **Shared**, because the Classes tab builds its list from
`ix.class.CanSwitchTo` client-side - a server-only gate would list every rank and
then refuse them one at a time on click. Character data is `isLocal`, so the
client knows its own grants.

### Race-locked classes

37 classes carry `CLASS.races`. A Mother is a deathclaw matriarch; that is not a
promotion and no permission changes it.

**Below lead they need no grant.** Sentry Bot is rank 3 because it is a bigger
machine, not because it outranks a protectron, and the character already *is*
one - the race was chosen inside a faction they had to be whitelisted into, so
the gate has been passed. Rank 4 and `limit = 1` classes stay behind a grant
however the character is built.

Because every class in Feral and Deathclaws is race-locked, the faction default
is wrong for most of them - a Reaver would load in as Feral Ghoul, a class the
gate says they cannot have, with no way to notice. So `sh_classrank.lua`
reconciles on `PlayerLoadedCharacter` and on any race or faction change: if the
current class is not available, it takes the first one their **race** fits, and
only then the faction default. That also self-heals a grant revoked while
offline and a class file removed between restarts.

### What changed from Phoenix's grouping

- their `house_omerta*`, `house_whiteglove*` and `house_chairmen*` are classes
  inside House. We have those as factions, linked under House by the
  sub-faction system, so they became each faction's own ladder.
- their `marketdistrict` classes are the Crimson Caravan / Gun Runners / Van
  Graffs ladders a second time, for staff posted to the market. Kept - that is
  genuinely what the faction is - with only the first ladder defaulting.
- their `minutemen` files use `FACTION_MM`; ours is `FACTION_MINUTEMEN`.
- **Wastelanders has no ladder.** It is the default faction and not an
  organisation, so a rank in it would mean nothing. Nine trades at rank 1
  instead - Scavenger, Trader, Settler, Farmer, Doctor, Mercenary, Prospector,
  Drifter - so a new character has something to be.

---

## Running a faction from inside it

`schema/libs/sh_factionmgmt.lua`. Phoenix's `factionmanagement` plugin, which is
the reason their classes are worth having: an admin is not in the room when
somebody gets promoted. Hold **C**, right click a player, and what you may do to
them is what your class says you may.

| | who | on whom |
|---|---|---|
| Invite into faction | NCO+ (rank 2) | anyone not already in your faction |
| Kick from faction | Officer+ (rank 3) | a member you outrank |
| Set class | anyone | a member you outrank, to a class below your own |
| Rename | anyone | a member you outrank |

**Outranks means strictly above.** Two officers cannot demote each other and
nobody can act on themselves — `Rank(a) > Rank(b)` is false for equals, so that
falls out rather than being special-cased.

**The Classes tab and `/becomeclass` are both gone** (`cl_special.lua` and
`sh_classrank.lua`). Between them they let anyone in a faction take any of its
classes, which made the whole ladder decorative. This replaces them.

Nilling `tabs["classes"]` from a later `CreateMenuButtons` listener was not
enough, and the reason generalises: **`hook.Add` listeners with string
identifiers run in `pairs` order**, which is not registration order and not
stable. "The schema loads after the framework, so our listener runs second" is
simply not true - it was a coin flip that landed right for the `you` tab and
wrong for this one, with Helix's `ixClasses` putting the tab straight back. The
fix is `hook.Remove("CreateMenuButtons", "ixClasses")`, which cannot lose a
race.

### Rank is the whole rule

You may hand out anything below where you stand. That makes a lead able to
appoint officers, an officer able to appoint NCOs, and **nobody able to appoint
their own equal** — so a faction lead cannot mint another lead, and the top of
every ladder comes from an admin. That falls out of the rank comparison rather
than needing a rule of its own.

The race lock is the one thing rank does not override: a class locked to
securitrons is not something a human gets promoted into. That half is public
character data, so the client can answer it too and the option is simply not
drawn.

### Notes on the implementation

- **`properties.Add` is not blocked by `GM:CanProperty`.** Helix's returns
  `false` for every non-admin, which would have killed all four — but sandbox's
  `properties.OpenEntityMenu` only calls `Filter`, and the server receive only
  calls `Receive`. `CanBeTargeted`/`CanProperty` are for a property to call on
  itself, which sandbox's own do and these do not. Ours are the authority
  instead, and every rule is checked twice: once on the client to draw the row,
  once on the server to honour it.
- **Invites ask the invited person; kicks ask the kicker.** A faction change
  costs you your class and respawns you, so it needs consent. A kick has nothing
  to consent to on the other end, and a misclick in a context menu should not
  cost somebody their faction.
- Both re-check on the way back. A prompt is open for up to a minute, and in
  that time either party can change faction, be demoted, or disconnect.
- The class list is **rebuilt on the server** rather than trusting the id sent.
- Kicking returns you to `RACE.defaultFaction` if your race names one — a super
  mutant thrown out of Unity is not a Wastelander — and Wastelanders otherwise.
- Being invited does **not** whitelist you. Same split `/charsetfaction` keeps.

**A new faction has nobody who can invite**, because everyone starts on the
faction's rank-1 default. An admin has to `/charsetclass` somebody to NCO to
seed it. That is the intended shape of "you have to be put there by staff", not
an oversight.

---

## Sub-factions

`schema/libs/sh_subfaction.lua`, **one level deep on purpose**. House runs the
Omertas, the White Glove Society and the Chairmen; the Great Khans sit under
Arroyo. A tree of arbitrary depth needs cycle checks and a recursive "is X under
Y" to express something nobody asked for.

Links live in `ix.data` per schema, not in the faction files - those are
regenerated whenever the roster changes and a link stored in one would be lost.

`/factionconfig` opens the configurer: the roster on the left, the tree as it
stands on the right. Click a faction to pick it up, click the one it goes under
to place it, right click a sub-faction to detach it. **One gesture, so the
second click is always "under what"** and the relationship cannot be entered
backwards. It sends the same `/factionlink` the command does rather than a net
message of its own, so the server's rules - one level, no self-parenting, both
must exist - live in one place. The panel redraws off the broadcast that follows
a successful change, not off its own click, so a refused link shows the tree that
actually exists.

`ix.faction.GetGroup(id)` is the function most callers want: the parent if there
is one, otherwise itself. "Same side" is `GetGroup(a) == GetGroup(b)`, which
answers correctly for a parent against its own child.

---

## Faction spawns and the death screen

Phoenix hold you on a death screen until you pick where to come back.

| Faction has | What happens |
|---|---|
| one or more locations | death screen, pick by number, respawn there |
| none | the map's own spawn points, exactly as before |

**The fallback is the important half.** Most factions will have no locations for
a long time, and a death screen offering an empty list is worse than none. An
unconfigured faction behaves exactly as it did before this existed.

Keyed by faction **uniqueID**, not index — the index is assigned in load order
and shifts the moment a faction file is added, which would silently move every
spawn point to a different faction.

### How the hold works

`GM:PlayerDeathThink` respawns once `deathTime` passes. A `hook.Add` listener
runs first and, by returning a value, stops the gamemode method running at all.
So the player stays dead until they pick and everything else Helix does around
death is untouched.

The offer is made when the timer *expires*, not at the moment of death — a menu
that appears before the ragdoll has landed reads as an interruption. If the
faction has nowhere of its own, `Offer` returns false and the player falls
through to the normal respawn on the same tick.

The chosen position is applied on a **zero timer** in `PlayerSpawn`, so it runs
after Helix's loadout and anything a plugin adds. A `SetPos` that runs before
another one is a `SetPos` that did nothing.

Only the **yaw** of the admin's angles is kept. Pitch and roll would have players
spawn looking at the sky, which is what happens when a spawn is set while
looking at the floor.

### The screen itself

Drawn in `HUDPaint` and driven by the number keys rather than built as a panel.
A panel needs `MakePopup`, which takes the mouse from a dead player and gives it
back at a moment nothing here controls. Number keys are simpler to use while
looking at your own ragdoll and impossible to misclick. Both the number row and
the numpad work.

---

## Commands

```
/classnameviewer                 searchable faction / race / class / item IDs
/charsetrace <player> <race>     change a character's race
/charracelist                    every race class name, in chat
/factionspawnadd <fac> <name>    a spawn point where you stand
/factionspawnremove <fac> <n>    remove one by number
/factionspawnlist                every spawn point on this map
/factionspawngoto <fac> <n>      teleport to one
/charsetfaction <player> <fac>   move a character; does NOT whitelist
/factionconfig                   the sub-faction configurer
/factionlink <child> <parent>    make one faction a sub-faction
/factionunlink <child>           detach one
/factiontree                     the hierarchy, in chat
/charsetclass <player> <class>   put them in one of their faction's classes
/stealth                         cloak, for anyone who has not bound the key
```

`/charsetfaction` deliberately does **not** whitelist. Moving a character and
letting that player create more of them are two decisions, and Helix already has
a command for the second - `/plywhitelist <player> <faction>`.

## A whitelist gates CREATION, not loading

Helix checks the whitelist twice: at character creation, and again every time a
character is **loaded** (`GM:CanPlayerUseCharacter`). The second one is wrong
for this server and follows straight from the rule above:

- an admin moves somebody into a faction with `/charsetfaction`, which does not
  grant a whitelist
- they log out
- they can never load that character again

The same happens to anybody whose whitelist is removed after a month of playing
that character: it is not deleted, it is simply unloadable, which is a worse
outcome than either kicking them out of the faction or doing nothing.

`libs/sh_whitelist.lua` overrides the load check. Creation still checks it - the
`faction` character var's own `OnValidate`, untouched - so the faction list at
creation still offers only what you may take.

**It repeats the character BAN check, and that is the point of the file.**
`hook.Call` stops at the first non-nil answer (gotcha 27), so returning `true`
skips `GM:CanPlayerUseCharacter` *entirely* - and that function does two things,
the whitelist refusal and the ban refusal. Dropping the second would quietly
unban every banned character on the server.

**Staff are no longer told twice, either.** `/plywhitelist` announced itself to
the target as well as to staff; `libs/sh_commandfixes.lua` replaces both
whitelist commands with versions that tell staff only. A player who has just
been put in a faction does not need a second message about the mechanism behind
it.

`/charsetrace` does not just set the field. A race decides the model, hull, view
offset, base health and animation set, so it also fixes the gender if the new
race does not have the old one (most creature races are male-only), respawns the
player to pick up the hull, and **saves explicitly** — `SetRace` is a generated
setter that writes `self.vars` and networks it without touching the database.
Without the save the character is the new race until a restart and then quietly
is not, which looks like it worked.

`/classnameviewer` is Phoenix's, plus a **races** tab they had no need for.
Clicking a row copies the uniqueID to the clipboard, which is the whole point —
`feralghoul_armored` is not something to type from memory.

---

## Notes

- `FACTION.icon` is set on all 45 and resolves to a real material. Nothing in
  the schema draws it yet — the scoreboard is Helix's — so it is ready rather
  than used.
- Phoenix's race descriptions are mostly empty strings in their own data; the
  generated races carry that faithfully rather than inventing text.
- Creature factions carry `FACTION.isCreature` so anything that assumes a human
  character can tell the difference.
