# 14 — Procedures

Step-by-step for the things we do repeatedly. Following these avoids the
mistakes in `13-troubleshooting.md`.

---

## Install a content addon

1. **Check it's Lua-free:**
   ```powershell
   (Get-ChildItem "<workshop content folder>\<addon>" -Recurse -Filter *.lua).Count
   ```
   Must be **0**. If not, see "one asset from a Lua-bearing addon" below.

2. **Junction it** (no copy, no duplication):
   ```powershell
   cmd /c mklink /J "<project>\garrysmod\addons\<addon>" "<phoenixsourceaddons>\<addon>"
   ```

3. **Verify** with `resolve_asset.py`, and regenerate `09-content-map.md`.

**To remove:** `cmd /c rmdir "<path>"` — unlinks only the junction. Never
`Remove-Item -Recurse`, which can delete through to the target. Verify the
source survived afterwards.

### One asset from a Lua-bearing addon

**Copy the asset**, don't junction. Put it in the addon that needs it:

```
addons/falloutrp_weapons/materials/sprites/beam_laser.vmt   (+ .vtf)
addons/falloutrp_weapons/models/fallout/weapons/w_multiplasrifle.*
```

For models copy **all** siblings — `.mdl .vvd .phy .dx80.vtx .dx90.vtx
.sw.vtx` — not just the `.mdl`.

If clients need it too, add `resource.AddFile` (see
`longsword_base/lua/autorun/server/sv_ls_resources.lua`) **and** provide a
runtime fallback, since the transfer isn't guaranteed.

---

## Add a ranged weapon

1. Copy from `some_source_code/latest_dev_scape/addons/longsword_fallout/lua/weapons/`
   into `addons/falloutrp_weapons/lua/weapons/`.
2. Strip the two-line glua-steal header.
3. Set `SWEP.Category = "Fallout RP - <X>"`, mapping from the original
   `LS-Fallout: <X>`.
4. Verify models: `python _docs/tools/resolve_asset.py --swep garrysmod/addons/falloutrp_weapons/lua/weapons`
5. Check ammo is registered — `a_funcs.lua` has 44 types; watch the **casing**
   (`50MG`, not `50mg`).
6. Check for NutScript calls:
   ```bash
   grep -oP ":(getChar|getRace|getData|getInv|addRadiation)\(|nut\.\w+" <file>
   ```
   Prefer adding an alias/stub in the compat layer over editing the weapon —
   keeps it diffable against future scrapes.
7. `python _docs/tools/luacheck.py garrysmod/addons/falloutrp_weapons`

**Weapon fields worth knowing:** `Primary.Tracer` (`false` = none, string =
custom effect, nil = default), `MuzzleFlashEffect` (implies it draws its own
bolt, suppresses our tracer), `NVHoldType` + `AttackAnim`/`AttackAnimIS`/
`ReloadAnim` (third-person animations), `SWEP.Events` (timed reload sounds),
`ScopeOffset`, `DefaultClip = 0` on every weapon.

---

## Add a projectile entity

Only needed when its `init.lua` was lost. Check first — `ls_euclidbeam` keeps
everything in `shared.lua` and needs nothing.

Contract set by `SWEP:ShootProjectile`:

```lua
ent.Owner    = owner        ent.damage = data.Damage      ent.Speed = velocity
ent.mydamage = data.Damage  ent.WeaponClass = weapon class
ent:SetAngles(owner:EyeAngles() + Angle(90, 0, 0))   -- model nose points +Z
-- ProjectileModel is often nil, so the entity sets its own model
```

Template: copy `ls_fallout_missile/init.lua`. Must include:

- `AddCSLuaFile("cl_init.lua")` and `AddCSLuaFile("shared.lua")`
- An **arm delay** (`ImpactArm`) or it detonates on the shooter's own hitbox
- A `LifeTime` failsafe timer
- A `Detonated` guard against double-detonation
- Phoenix's effects (`grenade_frag_explode`, `effect_fo3_fatman`) **plus a
  sound**, since `grenade_frag_explode` is silent

Rockets keep gravity **off** and hold velocity in `Think`. Grenade launchers
keep gravity **on** (they arc) but still detonate on contact.

---

## Add a faction

1. `garrysmod/gamemodes/falloutrp/schema/factions/sh_<name>.lua`
2. Data is in `reference/04_factions_data.md` — all 33, with colours, icons,
   flag models, karma weights and capture rules.
3. **Convert `FACTION.models` to an array.** Keyed tables silently break
   character creation.
4. `FACTION.desc` → `FACTION.description`.
5. Give it a class with `isDefault`, or `KickClass` errors.
6. Set the global: `FACTION_<NAME> = FACTION.index`.

Custom fields (`races`, `karma`, `radio`, `flagModel`, `canCapture`,
`canAmbush`, `raidImmune`) carry over as data — we write the code that reads
them.

---

## Port a Phoenix plugin

1. Read `reference/00_plugin_inventory.txt` for size and description.
2. Read the source in `some_source_code/latest_dev_scape/gamemodes/fallout/plugins/<name>/`.
3. **Check what's missing** — `sv_*.lua` files are gone. If the plugin's logic
   lived there, it must be rewritten, not ported.
4. Create `garrysmod/gamemodes/falloutrp/plugins/<name>/sh_plugin.lua`.
   The schema auto-loads `plugins/`, and each plugin auto-loads its own
   `languages/ libs/ attributes/ factions/ classes/ items/ derma/ entities/`.
5. Translate the API — table in `reference/00_README.md`, details in
   `11-helix-api.md`.
6. Delete the matching stub from `sh_falloutrp_nut_stubs.lua`.

---

## Change the tickrate

1. `startserver.bat` — `-tickrate <n>`. **It cannot be set in a cfg file.**
2. `garrysmod/cfg/server.cfg` — set `sv_mincmdrate`, `sv_maxcmdrate`,
   `sv_minupdaterate`, `sv_maxupdaterate` **all to the same value**.

Expect fire rates to change: delays round up to whole ticks, so a lower
tickrate makes weapons fire *slower*. See `03-weapons.md`.

---

## Verify a change without booting

```bash
python _docs/tools/luacheck.py <dir>              # after every edit
python _docs/tools/resolve_asset.py <paths>       # any new asset
grep -rn "nut\.\|:getChar(\|:getRace(" <dir>      # framework leaks
```

For runtime facts, drop a temporary script writing to `garrysmod/data/`:

```lua
hook.Add("InitPostEntity", "check", function()
    timer.Simple(5, function()
        file.Write("check.txt", table.concat(lines, "\n"))
    end)
end)
```

Then ask the user to restart and paste the file. This is how the weapon
verification and fire-rate traces worked.

---

## Edit a file with a script (and not lose half the edit)

Batch edits keep failing the same way: the script does three replacements, the
fourth `assert` throws, and the first three are silently discarded because the
write never happens. Everything looks unchanged, so the bug looks like "the fix
didn't work" rather than "the fix was never saved."

Rules that came out of that, all learned the hard way:

**Run `luacheck.py` after every scripted edit, without exception.** It is a real
tokenizer, so it catches unterminated strings and unclosed blocks - both of the
splice failures below were caught by it and by nothing else. It also reports
four things that are valid Lua and still break the server:

| | |
|---|---|
| `goto continue` / `::continue::` | `continue` is a GMod keyword |
| `obj:method` used as a value | gotcha 23 - call syntax with no arguments |
| a `cl_` file writing to an `ix` table it has not declared | gotcha 26 - `cl_` loads before `sh_`, so the table is nil at file scope |
| a listener returning a value on a hook that only reports events | gotcha 27 - it stops the hook, `GM:<Name>` included |
| two table fields on consecutive lines with no comma between them | a syntax error every bracket-counting check is blind to |

The last two exist because each of them, once, took down far more than the file
it was in - a whole directory of includes, and every player's ability to finish
loading. Neither tool boots the game, so neither catches a runtime error in code
that does load; they catch the classes that take *everything else* with them.

**Anchor on WHOLE LINES, not substrings.** A substring anchor matches a suffix
of a deeper-indented line. Searching for `"\t\t\tif (mins) then"` matched the
five-tab inner `if` instead of the three-tab outer one, and the slice cut a loop
in half:

```python
lines = src.split("\n")
starts = [i for i, l in enumerate(lines) if l == "\t\t\tlocal mins, maxs"]
assert len(starts) == 1, starts          # ambiguity is a bug, not a coin flip
```

**Backslashes survive the two heredoc forms differently.** A `python <<'PY'`
heredoc eats one level, so a `\n` meant for a Lua `string.format` arrives as a
real newline and produces an unterminated string. A `cat <<'LUA'` heredoc
preserves them exactly. So write the payload with `cat`, and use Python only to
splice the file:

```bash
cat > "$SP/new.lua" <<'LUA'
	MsgC(plain, string.format("  %-24s %d\n", "framing", value))
LUA
```

Related: `/tmp` in Bash is not `/tmp` to Python on this machine. Pass files
between them through the scratchpad directory, with the full Windows path.

**NEVER walk backwards to find the start of a comment.** Not "scan up to a blank
line", not "scan up to a `--[[`", not any variant. This rule has been broken four
times in this project and cost a bug every time:

1. split the `Populate` comment in `cl_creation.lua` (stray `]]`);
2. split `ComposeModelPanel`'s comment (unterminated string);
3. clipped the framing comment in `cl_panels.lua`, stranding an orphan `--[[`;
4. **deleted `PANEL:SetPayload` outright** while replacing the method below it,
   which shipped and turned the character menu into a grey screen.

The heuristic cannot tell the comment above a function from the comment above
the PREVIOUS function, and when the target function has a comment *inside* its
body the scan sails straight past its own header. Anchor on an exact line and
assert the line above it is what you expect:

```python
a = [i for i, l in enumerate(lines) if l == "\tRegister a model panel to be driven..."]
assert len(a) == 1, a
start = a[0] - 1
assert lines[start] == "--[[", repr(lines[start])
```

**Deleting code needs a stronger check than luacheck.** A dropped method leaves
the file syntactically perfect; nothing fails until a player clicks. After any
edit that removes or replaces a function, confirm the callers still resolve:

```bash
python - <<'PY'
import io, re
d = io.open("path/to/panel.lua", encoding="utf-8").read()
defined = set(re.findall(r'^function PANEL:(\w+)', d, re.M))
called  = set(re.findall(r'\bcustomizer:(\w+)\(', io.open("caller.lua", encoding="utf-8").read()))
print(sorted(called - defined))
PY
```

`ixFOCustomizer` also self-checks its method list at load, so a future drop
reports itself in console at startup rather than on a click.

**Prefer the Edit tool for anything containing a backslash.** It takes the text
literally and fails loudly on a bad match.

**Then confirm each piece actually landed**, rather than trusting the exit code:

```bash
for pat in 'local function FramePreview' 'FramePreview(this)'; do
  printf '  %-42s %s\n' "$pat" "$(grep -c -- "$pat" $F)"
done
```

A count of `0` means a splice was dropped; a count of `2` means one ran twice.
Deleting a block can also strand the comment above it - that is invisible to
Lua when the orphan `--[[` merges into the next comment, so read the region
back once the counts are right.

---

## Release checklist (not yet — for when going public)

- [ ] **Longsword licensing settled** — recovered from a scrape, not from its author
- [ ] `sv_lan 0`, GSLT set, RCON decided
- [ ] Content delivery: workshop collection or FastDL
- [ ] `sv_kickerrornum` revisited
- [ ] Admin mod installed (CAMI-compatible)
- [ ] All `TEMP`/diagnostic files removed — see `08-open-items.md`
- [ ] `_zz_verify` addon deleted
