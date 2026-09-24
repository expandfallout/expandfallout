# 12 — Commands and workflow

## Working loop

the loop is:

1. **Edit**
2. **`python _docs/tools/luacheck.py <addon-or-schema-dir>`** — the only Lua
   syntax check available. Run it after every edit.
3. **`python _docs/tools/luaglobals.py <dir>`** — catches nil-global reads,
   which is what a half-finished refactor leaves behind. `luacheck.py` cannot
   see them: the file still parses perfectly.
4. **`python _docs/tools/vmtcheck.py garrysmod`** after installing or updating
   any content addon. Catches the KeyValues errors neither Lua check sees.
Re-learn the known-globals set after adding a global of your own (`sW`, `sH`,
`falloutFactionSet`, ...):

```bash
python _docs/tools/luaglobals.py --learn garrysmod/gamemodes/helix garrysmod/gamemodes/falloutrp garrysmod/addons/longsword_base garrysmod/addons/falloutrp_weapons
```

5. **`python _docs/tools/resolve_asset.py`** for any new model/material/sound
6. User restarts and reports
7. If a symptom doesn't match the code, **instrument it** — don't theorise

For runtime verification write to a **file**:

```lua
file.Write("mycheck.txt", results)   -- lands in garrysmod/data/
```

`console.log` is buffered and truncates on force-kill. This is how the weapon
verification report worked.

## Dev commands (temporary — delete with their features)

### Weapons — `sv_dev_weapons.lua`

| Command | Effect |
|---|---|
| `fo_giveall` | one weapon per type, loaded with reserve ammo |
| `fo_giveall <type>` | every weapon of a category (`energy`, `rifles`, …) |
| `fo_give <class>` | one weapon, loaded (`ls_` prefix optional) |
| `fo_ammo [amount]` | top up the held weapon, default 250 |
| `fo_weapons [type]` | list the arsenal, or one category with stats |

All superadmin-only. They exist because **every Longsword weapon ships
`DefaultClip = 0`** — guns spawn empty and, until ammo items exist, there's no
legitimate way to load one.

### Diagnostics

| Command | Effect |
|---|---|
| `fo_firerate` | measured vs configured RPM, both realms, rounds per shot |
| `fo_tracefire` | toggle deep fire tracing |
| `fo_tracefire_report` | configured / asked-for / actually-got delay + ammo per shot |

### Raise

| Command | Effect |
|---|---|
| `fo_toggleraise` | raise/lower. **This is the raise mechanism** — `bind f fo_toggleraise` |

Not a temporary command. Helix's own raise is on `IN_RELOAD`, which collides
with reloading, so `Schema:KeyPress` swallows it and this replaces it. A
`PlayerBindPress` variant also existed for a while; it was redundant and is
gone.

### UI

| Command | Effect |
|---|---|
| `fo_ui_report` | which Helix panel patches applied, which classes were missing, widget registration, active palette/HUD/scale |
| `fo_menu_layout fallout\|helix` | F1 menu. `fallout` is `ixFOMenu`, `helix` restores Helix's own menu |
| `fo_inv_iconsize <n>` | slot size at 1080p for inventories NOT fitted to a container (storage, bags). Default 72; the menu inventory is sized by `FitParent` |
| `fo_menu_width <f>` | F1 window width as a fraction of screen, default 0.467 (Phoenix's sW(896)) |
| `fo_menu_height <f>` | F1 window height as a fraction of screen, default 0.652 (Phoenix's sH(704)) |
| `fo_menu_iconsize <n>` | menu inventory slot size at 1080p, default 64, scales with resolution |
| `fo_charpreview_yaw <n>` | yaw of the character-select preview model, default 225 |
| `falloutScanlines 0\|1` | CRT scanlines (an `ix.option`, set in the options menu) |

Not temporary. Panel patching fails silently when a class name is wrong, so this
is the only way to tell a working restyle from a no-op.

### NV HUD meter alignment (client convars)

```
fo_hud_debug 1      outline the plate (red) and the meter slot (cyan)
fo_hud_slot_x 0.045 slot start, fraction of plate width
fo_hud_slot_w 0.8   slot width, fraction of plate width
fo_hud_slot_y 0.45  slot vertical position, fraction of plate height
```

The tick run is spaced to fill the slot exactly, so it can never overflow - if
the meters sit wrong against the artwork, move the SLOT, not the ticks. Tune
live with the debug overlay on, then bake the value into `cl_hud.lua`.

### Scope tuning (client convars)

```
ls_scope_tune_x 0.0     fraction of screen width;  positive = right
ls_scope_tune_y 0.05    fraction of screen height; positive = down
```

Added to the weapon's own `SWEP.ScopeOffset`. Tune live, then bake the value in
and reset the convar.

### Weapon base debug

```
longsword_debug 1       impact crosses + a debug panel
```

## The chatbox only lists what the CLIENT knows

`ix.command.list` is built where a command was defined, so a command declared in
an `sv_` file exists on the server and is invisible in the chatbox - about fifty
of them here (`/ambush`, `/raidshield`, `/warreason`, `/lootlock`). They always
*ran*, because chat text is parsed on the server; only the list was missing.

`sv_commandsync.lua` sends the list and `cl_commandsync.lua` registers what the
client lacks. Two things about it are worth knowing:

- **it is built per player.** Access here is `ix.admin` ranks, and a client
  asked to work that out for itself answers "no" for a moderator whose rank
  grants it. The server filters the list to what that player may actually run,
  so the stub needs no access check. It is resent when a rank changes, and
  `fo_commands` rebuilds it on demand.
- **stubs go through `ix.command.Add`, never straight into the table.** A
  command is not a plain table by the time anything reads it - `Add` adds
  `GetDescription`, `uniqueID`, `OnCheckAccess` and a tidied `syntax`. Writing a
  hand-made table into `ix.command.list` killed the chatbox on the first
  keystroke with `attempt to call method 'GetDescription' (a nil value)`. If a
  library has a registration function, the shape it produces is part of its
  contract.

**Aliases are how a command gets the name people type.** `PlyGoto`, `PlyBring`
and `PlyKick` are `/goto`, `/bring` and `/kick` - Helix supports `alias` as a
string or a list, and a command nobody can guess the name of is a command
nobody uses.

## Helix commands worth knowing

```
/charsetmodel <name> <model>     model is a stored character var, so
                                 FACTION.models only affects NEW characters
/charsetattribute, /charsetclass, /chargiveflag, /plywhitelist
/togglerase                      Helix's own raise command
```

F1 → Config is the `ix.config` menu (superadmin).

### Schema commands

```
/devmenu                         open the developer terminal
fo_devmenu                       the same, from console
/charsetrads <name> <0-100>      set radiation directly
/charaddrads <name> <amount>     add rads, applying resistance
/charsethunger, /charsetthirst   set either meter, 0-100
/charsetlevel <name> <level>     sets XP to match
/charaddxp <name> <amount>       levels up if it is enough
/lootconfig                      loot tables: tree, editor, preview, placer
gmod_tool lootable               the fast looter placer (superadmin)
gmod_tool permaprop              make props survive restarts (superadmin)
fo_permaprops                    list permanent props and containers
fo_containers                    every container, and why it was kept
/classnameviewer                 searchable faction/race/class/item IDs
/charsetrace <player> <race>     change a character's race
/charracelist                    every race class name, in chat
/factionspawnadd <fac> <name>    a spawn point where you stand
/factionspawnremove <fac> <n>    remove one by number
/factionspawnlist                every spawn point on this map
/factionspawngoto <fac> <n>      teleport to one
/squadcreate <name>              form a squad; /squadleave, /squaddisband
/squadinvite <player>            or hold E on them; /squadaccept, /squaddecline
/squadpromote, /squaddemote      officer and leader ranks; /squadleader hands over
/squadkick, /squadrename         and /squadcolor <1-10>
/squad                           the squad window; /sq <text> is squad chat
/forcesquad [name]               the person you are looking at, into a squad
/forcesquadremove                the person you are looking at, out of theirs
/f <text>                        faction radio; heard nearby too (static if encrypted)
/o <text>                        the officers' channel of the same
fo_radio_next, fo_radio_off      the background radio, from console; the tab tunes it
fo_squad_menu, fo_menu_music     the squad window; menu music on/off (convar)
/charsetfaction <player> <fac>   move a character; does NOT whitelist
/factionconfig                   the sub-faction configurer
/factionlink <child> <parent>    make one faction a sub-faction
/factionunlink <child>           detach one
/factiontree                     the hierarchy, in chat
/charsetclass <player> <class>   put them in one of their faction's classes
/stealth                         cloak, for anyone who has not bound the key
/shopconfig                      configure what each faction sells (admin)
/shoplist                        what your faction sells, in chat
/factionmanagement, /fm          your faction's roster and deployables
/adminfactionmanagement, /afm    every faction (superadmin)
/factionstoragecreate <fac> <w> <h> [name]
/factionstoragelist              every faction storage (admin)
/factionstoragedestroy <id>      irreversible (superadmin)
/benchconfig                     the workbench creator and configurer (admin)
/benchplace <id>                 place a workbench, with the deploy ghost (admin)
/benchremove                     remove the one you are looking at (admin)
/benchlist                       every kind of bench, and how many are out (admin)
/benchrelease                    hand a captured bench back to nobody (admin)
/weaponhitgroup <weapon> [profile]  set a weapon's hitgroup profile (admin)
/weaponhitgrouplist              every profile, and every override (admin)
/testdismember <part>            take a limb off the corpse you are looking at
physgun on a player              left-click holds, right-click freezes in the air
physgun reload                   releases every player you froze, and your props
hold E on a body                 take its head, unmarked ("NCR - Trooper Head")
~goto ~bring ~kick ...           the same command without telling them (admin.silent)
/advert <text>, /global <text>   everybody on the server hears it
/asay, !a, @<text>               admin chat (staff)
/report, !help, @<text>          open a ticket (everybody else)
!tickets                         show every open ticket again (staff)
!ticketclose <n>                 close one by number (staff)
/ticketstats                     claimed, closed, and how long people waited
/ticketstatsclear                wipe the statistics (superadmin)
ix_tickets                       toggle the cursor so ticket cards can be clicked
ix_ticket_claim                  claim the oldest one, no cursor needed
ix_ticket_popups 0               tickets in chat instead of on screen
fo_corpse [spawn]                bodies: settings, the last death, limb damage, a test body
fo_physgun                       who you are holding, and everybody frozen
fo_dismember_report              what every mesh on the body you are looking at thinks its limbs are
fo_grid_report                   what the client thinks is where, and overlaps
fo_stack_report                  why two of the same item will not merge
fo_stack_try <target> <source>   fire the merge a drag would have fired
fo_loot_report                   loot tables, and whether they resolve
fo_xp_report                     XP sources, your level, and a test award
fo_armor_report                  armour, slots, models, your live DR
fo_buffs                         what is currently acting on you
fo_addictions                    what you are hooked on, and how badly
/charcureaddictions <player>     cure every addiction (admin)
```

The terminal is also a spawnable entity - Q menu, Fallout RP, Developer Terminal
- if you want one standing in the world. All three are admin only, and the
permission is re-checked at every net handler: having the menu open is not
permission to take anything out of it.

Inside it: item rows GIVE / x5, armour rows also spawn a **BOT** wearing that
piece, and the footer has **BARE BOT** / **CLEAR BOTS**. Bot slots come out of
`-maxplayers` in `startserver.bat`.

## Verification snippets

**Does a SWEP field exist across the arsenal:**
```bash
grep -l "^SWEP.Events" garrysmod/addons/falloutrp_weapons/lua/weapons/*.lua | wc -l
```

**Find NutScript calls that slipped in:**
```bash
grep -rhoP ":(getChar|getRace|getData|setData|getAttrib|notify)\(" <dir>
grep -rhoP "nut\.\w+" <dir> | sort -u
```

**Check a junction is content-only before installing:**
```powershell
(Get-ChildItem "$src\$addon" -Recurse -Filter *.lua).Count    # must be 0
```

**`find` is unreliable in this tree.** The content junctions make it bail
silently — it returned *nothing* for files that demonstrably exist. Use Python's
`os.walk` for any exhaustive search:

```python
for root, dirs, files in os.walk("garrysmod"):
    ...
```

**Inspect model sequence/attachment names** (they're in the `.mdl` binary):
```python
import re
d = open("path.mdl","rb").read()
names = set(s.decode('ascii','ignore') for s in re.findall(rb"[A-Za-z0-9_]{3,40}", d))
```
Note the character class **must allow leading digits** — `2hareloadj`,
`1hpaim`. Requiring a letter first was how I wrongly concluded those sequences
were absent.

## Things that need the user

- Booting the server
- Anything visual (does the tracer look right, is the scope aligned)
- Feel questions — fire rate, animation timing
- Steam/Workshop, GSLT, anything outward-facing

---

## How the testing loop actually works

AI can't boot the server or see the game, so verification is a
collaboration. Knowing the shape of it saves a lot of round trips.

**What the user provides**
- Console errors, pasted with full stack traces — usually the fastest route to
  a cause
- Screenshots of visual problems. These are genuinely diagnostic: "tracer comes
  from the waist" identified the player origin, and the scoped screenshot
  showed the reticle sat above centre
- Comparisons against Phoenix, which they know well. "On Phoenix these are
  impact but you can arc them" was a complete spec for the grenade launcher
- Feel judgements — fire rate, animation timing, whether something reads right

**What that means for how to work**

- **Say when something is a guess.** Several fixes here were estimates from a
  screenshot; labelling them as such meant they got verified rather than
  trusted. Where a value can't be measured remotely, ship a **tunable** (like
  `ls_scope_tune_y`) instead of a guessed constant.
- **Report failures plainly.** When a fix doesn't work, say so and say why,
  rather than layering another guess on top. Two of the longest debugging
  chains here got shorter the moment the previous attempt was described
  accurately.
- **One change at a time when a symptom is unclear.** Batching fixes makes it
  impossible to tell which one worked.
- **A "that's still broken" report is information, not a complaint.** It
  usually means an assumption is wrong — go to instrumentation, not to another
  theory.

**Things that produced the biggest breakthroughs**

| The user said | It revealed |
|---|---|
| "that 101 pop server uses 12 tick rate" | Tickrate wasn't the cause — `CurTime()` was |
| "the mag empties that fast too" | Prompted measuring ammo per shot, which cleared the fire rate |
| "only broken in third person, not first" | Isolated it to the *player* animation set |
| "the incinerator is a great example" | Gave a working reference for the other projectiles |

Offhand details in these reports are often the key fact. Read them closely.
