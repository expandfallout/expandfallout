# 06 — The NutScript compatibility layer

Scraped weapons call into Phoenix's schema. Rather than editing 176 weapon
files (which would also break diffing against future scrapes), there's a
compatibility layer in `addons/falloutrp_weapons/lua/autorun/`.

## THE LOAD-ORDER RULE

**`lua/autorun` runs BEFORE the gamemode loads. `ix` does not exist there.**

Touching it at file scope throws
`attempt to index global 'ix' (a nil value)`.

Worse, *guarding* it silently does nothing:

```lua
local CHARACTER = ix and ix.meta and ix.meta.character   -- always nil here
if CHARACTER then                                        -- never runs
```

That version didn't error — it just quietly installed nothing, and the bug it
was meant to fix kept reproducing with no clue why. **Failing loudly would have
been better.**

Correct pattern — both files use it:

```lua
local function Install()
    if not ix then return end
    ...
end

hook.Add("Initialize", "uniqueName", Install)

-- covers lua_reload / auto-refresh
if ix then Install() end
```

Weapon, entity and effect files *can* assume the gamemode is up, because
they're instantiated at runtime. Only `lua/autorun` has this problem.

## `sh_falloutrp_compat.lua`

**Player/character method aliases** so scraped code works unmodified:

| NutScript | Maps to |
|---|---|
| `PLAYER:getChar` | `GetCharacter` |
| `CHARACTER:getInv` | `GetInventory` |
| `CHARACTER:getData` / `setData` / `getName` | Helix equivalents |
| `CHARACTER:getRace` | returns `"human"` — delete this when races land |
| `CHARACTER:addRadiation` / `getRadiation` | no-op / 0 |

**`PLAYER:falloutNotify`** — Phoenix's notification, falling through Helix →
NutScript → chat. Five weapons call it. This one mattered: it errored in the
laser designator *immediately after* the klaxon started and *before* the timer
that faded it and spawned the beams, so the siren looped forever and no strike
ever happened.

## `sh_falloutrp_nut_stubs.lua`

A minimal `nut` table so Phoenix's own guard clauses can work. Without it,
`if not nut.psyker then return end` throws on the `nut` index itself — the
guard can't do its job.

**Two rules:**

1. **Never let a stub lie about a system existing.** Where a weapon checks for
   a subsystem before using it, leave that subsystem **nil** so the check
   correctly fails. `nut.psyker` is absent on purpose — the FEV spewer then
   skips cleanly.
2. Where a weapon calls straight in without checking, give a **no-op** that
   returns a sensible default.

| Stub | Behaviour |
|---|---|
| `nut.item` | **Real bridge** to `ix.item` — same shape |
| `nut.gui.palette` | Helix theme colour |
| `nut.psyker` | **absent on purpose** |
| `nut.buffs` | no-op (`has` returns false) |
| `nut.rib` | no-ops; `slowHeal` approximates by healing at once |
| `nut.simpleDrugMaking` | no-op |

Verified safe: the only two places testing `nut` for framework detection are in
`ls_base`, and both check `ix` first.

**Delete each stub as its real system is built.**

## Weapons that depend on this

`ls_syringe_pistol`, `ls_bellumbanner`, `ls_caustic_shotgun`, `ls_cryolator`,
`ls_fev_spewer`, `ls_radiation_scanner`, `ls_cit_v3n_biorifle`.

Plus `meleearts_blunt_boomstick`, which was patched directly instead (see
`04-melee.md`).
