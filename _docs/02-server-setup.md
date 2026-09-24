# 02 — Server setup

## Launching

**`startserver.bat`** — uses `%~dp0` so it survives the project being moved.

```
srcds.exe -console -condebug -tickrate 16 +maxplayers 5 +gamemode falloutrp +map rp_utah
```

- `+gamemode falloutrp` — **not** `helix`. Loading helix directly errors with
  `Couldn't include file 'helix\schema\sh_schema.lua'`.
- `-condebug` mirrors console output to `garrysmod/console.log`. Note it's
  **buffered** — a force-kill loses the tail.
- **Tickrate can only be set here.** There is no cfg convar for it.

### The map, and workshop content

`rp_utah` — workshop id **2974325085**.

srcds will **not** download an individual workshop addon. It only downloads a
**collection**, and only when given a Steam Web API key, so both of these are
needed together and either alone does nothing:

```
-authkey <key>                    steamcommunity.com/dev/apikey
+host_workshop_collection <id>    the collection holding the map
```

Both are live in `startserver.bat`. Build the collection from `_reference/workshop-content-list.md`.

**The API key is deliberately not written down here.** It lives in
`startserver.bat` and nowhere else, which makes that file sensitive — keep it
out of screenshots, Discord and any public repo. A key is revoked simply by
issuing a new one at `steamcommunity.com/dev/apikey`; the old value stops
working immediately, so reissue on any doubt rather than wondering.

**The collection has to carry the content, not just the map.** Every addon the
server currently mounts by junction is on one machine only; a client joining
without them gets a working map and missing models.

Add these 25 alongside the map (`2974325085`). The trailing number in each
installed folder name *is* the workshop id:

```
3504631185  af_additional_weapons_models      2777220342  af_content_pack_9
3041037276  af_content_pack_15                3342543106  af_extra_content
3358609251  af_content_pack_18                3217826764  af_pa_assets
3369199489  af_content_pack_19                2974533993  fallout_prop_pack_two_wastelands
2182580313  af_content_pack_1                 3593569052  phoenix_anims
2205878880  af_content_pack_4                 3522721568  phoenix_armors
2277098363  af_content_pack_5                 3679448229  phoenix_custom_orders
2289559348  af_content_pack_6                 3614856486  phoenix_dickmosi_stuff
2427672337  af_content_pack_7                 3728469287  phoenix_drop_models
3498192410  phoenix_hud_content               3647084547  phoenix_weapon_models
3448525969  phoenix_player_content            3507971036  phoenix_weapons_extra
1999953274  resurgence_misc_2                 3532494780  phoenix_mining_content
3504308895  phoenix_contributor_content
```

`phoenix_contributor_content` was junctioned for the **stash box**
(`models/galang/fallout/furniture/stashboxcontainer.mdl`) - see
[41-crosshair-stash-and-modulators.md](41-crosshair-stash-and-modulators.md).
Until it is in the collection every client sees an ERROR box where the
stash is; it still opens and still works, which is what makes it easy to
miss.

### What a collection cannot deliver

Seven installed addons have no workshop id, so they cannot go in the collection
at all:

| Addon | What it is |
|---|---|
| `falloutrp_weapons` | our weapon addon |
| `falloutrp_armor_content` | the 581 MB copied out of the Lua-bearing packs |
| `longsword_base` | the weapon base |
| `meleearts2`, `meleearts2_content`, `meleearts2_fallout` | melee |
| `_zz_verify` | temporary diagnostic, delete it |

**Lua from these reaches clients automatically; models and materials do not.**
So a client will run the weapon code and then fail to draw it. Before anyone
else connects, these need either a `sv_downloadurl` FastDL host or to be
uploaded to the workshop and added to the collection. Until then the server is
single-machine only, and that is not a symptom that shows up while testing
alone.

Measured size of that gap, excluding Lua: **1453 files, 658 MB** — 578 MB of it
`falloutrp_armor_content`, 78 MB `meleearts2_content`. Worth knowing before
picking a route: FastDL also needs every one of those files declared with
`resource.AddFile`, since addon content is not sent to clients on its own.

Clients joining should pull the same collection. If any of them turn up missing
the map, add `resource.AddWorkshop("<id>")` server-side as a belt-and-braces
fallback — that forces the download explicitly rather than relying on the
collection mount.

The alternative, if the collection route is ever a problem, is putting the
addon's `.gma` straight into `garrysmod/addons/` — the engine mounts gma files
there — but that only fixes the SERVER, and every client still has to get the
map from somewhere.

Every attempt from a tool call reaches `Server logging data to file logs\...`
and then idles at ~150 MB without ever loading the map — no A2S response, no
`InitPostEntity`, so no Lua runs.

Tried and failed: `-game garrysmod`, `-insecure`, `-nomaster`, `+sv_lan 1` on
the command line, launching via `conhost.exe`, splitting args, `+map` first,
removing server.cfg, stock `sandbox`. With stdin redirected it additionally
dies on `CTextConsoleWin32::GetLine: !GetNumberOfConsoleInputEvents`.

Source's legacy Win32 console needs a genuinely interactive session. **Verify
statically, then ask the user to run the bat.** Don't burn time on this.

For runtime checks, write results to a **file** via `file.Write` — not console,
which truncates.

## server.cfg

`garrysmod/cfg/server.cfg`, ~57 convars, grouped and commented. Current state
is **local development**: `sv_lan 1`, RCON disabled (empty password disables it
entirely), `sv_allowcslua 0`, prop spawning zeroed.

Things worth knowing:

- **Rates are matched to the tickrate** (`sv_mincmdrate`/`maxcmdrate`/
  `minupdaterate`/`maxupdaterate` all 16). If tickrate changes, change these.
- **`maxplayers` is a launch arg**, not a cfg setting.
- Six convars were removed as non-existent in this build: `sv_tags`,
  `sbox_plpldamage` (correct name is `sbox_playershurtplayers`),
  `sbox_maxspawners`, `sbox_maxturrets`, `mp_winlimit`, `mp_fraglimit`,
  `sv_unlag`.
- **Keep it ASCII.** An em dash in `hostname` renders as `Fallout RP`
  — confirmed by reading the live window title.
- There's a "GOING PUBLIC" checklist at the bottom (GSLT, workshop, FastDL).

## Admin

`garrysmod/settings/users.txt`. Helix has no admin list of its own — it uses
CAMI, which falls back to GMod usergroups.

- Must be the **`STEAM_0:X:XXXXXXXX`** format. A SteamID64 silently does nothing.
- Read at **server startup**, so restart after editing.
- Superadmin unlocks the Helix config menu (F1 → Config).

Long term you'll want a CAMI-compatible admin mod (SAM, ULX, ServerGuard);
GMod's built-in groups are bare.

## Addon install rules

`garrysmod/addons/` currently:

| Addon | Type | Purpose |
|---|---|---|
| `longsword_base` | folder | weapon base (patched) |
| `falloutrp_weapons` | folder | 176 weapons, 35 effects, compat shims |
| `meleearts2` | folder | Phoenix's melee base + 46 weapons |
| `meleearts2_fallout` | folder | 41 Fallout melee weapons |
| `meleearts2_content` | folder | melee models/materials (copied, no Lua) |
| `af_content_pack_1/4/6/19` | **junction** | weapon + player models |
| `af_additional_weapons_models` | **junction** | extra weapon models |
| `phoenix_weapons_extra` | **junction** | models + all explosion/reload sounds |
| `phoenix_weapon_models`, `phoenix_custom_orders`, `phoenix_dickmosi_stuff` | **junction** | models |
| `resurgence_misc_2` | **junction** | models |
| `phoenix_anims` | **junction** | `models/phoenix/humans/animations.mdl` |
| `phoenix_mining_content` | **junction** | ore nodes and their sounds |
| `phoenix_contributor_content` | **junction** | the stash box model |
| `simplethirdperson` | folder | edunad's third person camera (Apache 2.0, Lua only - no content) |

### Junctions

Content addons are mounted as **directory junctions**, not copies —
several GB referenced with zero duplication, and updates to the source are
picked up automatically.

```powershell
cmd /c mklink /J "<addons>\<name>" "<phoenixsourceaddons>\<name>"
```

Five more were junctioned for the vehicles (see `53-vehicles.md`):
`lvs_framework_2912816023`, `lvs_cars_3027255911`,
`phoenix_vehicle_content_3495732900`, `divide_trailblaze_1_3665625103` and
`divide_trailblaze_2_3665637618`. Clients need the same five ids on the
workshop collection.

Remove with `cmd /c rmdir "<path>"` — that unlinks **only** the junction.
`Remove-Item -Recurse` can delete *through* to the target in some PowerShell
versions. Always verify the source afterwards.

### THE RULE: never junction a Lua-bearing addon without its dependencies

Junctioning `fallout_snpcs_remastered` for a single 4 KB material dragged in
~150 VJ Base NPCs with no VJ Base installed, producing a wall of
`attempt to index global 'VJ'` and `Trying to derive entity ... from non
existant entity npc_vj_creature_base`.

**Check before junctioning:**

```powershell
(Get-ChildItem "$src\$addon" -Recurse -Filter *.lua).Count   # must be 0
```

If you need one asset from a Lua-bearing addon, **copy that asset** instead.

### Materials are not sent to clients

A dedicated server auto-sends **Lua**, but *not* materials or models. A custom
material that exists only on the server renders as a purple/black error for
every client. Either ship it via workshop/FastDL (`resource.AddFile` is set up
in `longsword_base/lua/autorun/server/sv_ls_resources.lua`) or fall back to
stock assets. The tracer does both — see `03-weapons.md`.
