# 04 — Melee weapons

## What's installed

**87 weapons** across two addons:

- `meleearts2` — Phoenix's Melee Arts 2 base + the 46 stock weapons they carried
- `meleearts2_fallout` — Phoenix's 41 Fallout melee weapons
- `meleearts2_content` — models/materials/sounds, **copied not junctioned**

Spawnmenu: `Fallout RP - Melee - Blades` (15), `Blunt` (13), `Other` (12),
`Spears` (1). The non-Fallout MA2 weapons are parked under
`Melee Arts 2 (non-Fallout)`.

## Why this ported cleanly (and the projectiles didn't)

**Every melee weapon uses `shared.lua` only — zero `init.lua` across all 89
folders.** Melee Arts 2 puts everything in shared files, and shared files are
sent to clients whole, so glua-steal captured the entire system intact.

Nothing had to be invented here. Contrast with the projectile entities, whose
server-only `init.lua` was lost — see `03-weapons.md`.

## The base version question

The **workshop** Melee Arts 2 addon (`melee_arts_2_1825542758`) ships a *newer*
`dangumeleebase` — 516 lines vs Phoenix's 503, diverging by **343 lines**.
Phoenix's is an older version they then modified: they added a blocking system
(`MA2_STARTBLOCK` / `MA2_STOPBLOCK` net messages, `MAGuardening` netvars) and
removed throwing.

**We use Phoenix's**, because their 41 Fallout weapons are written against it.

Consequence: the workshop addon **cannot be junctioned** — its Lua would define
a competing `dangumeleebase` and whichever loaded last would win. Its content
(78 MB, verified zero Lua) was copied into `meleearts2_content` instead.

## Framework patches

Coupling was tiny — 4 `nut.*` references and 2 method calls:

1. **`cl_hud.lua`** — the charge bar used `nut.rib:drawProgressBar` and
   `nut.gui.palette`. Reimplemented as `MA2_DrawChargeBar` with plain `surface`
   calls taking Helix's theme colour, so the base now has **no framework
   dependency at all**.
2. **`meleearts_blunt_boomstick`** — its instant-kill check used
   `ent:getChar()`, `char:getRace()` and `nut.armor:wearingPA(ent)`. Now uses
   Helix's `GetCharacter`, a race fallback of `"human"`, and reads power armour
   from the `WearingPA` netvar that armorv2 sets.
3. `meleearts_blunt_tireiron` references `nut.rib:attemptKnockout` but it's
   already commented out in the source.

## Controls

- **Left click** — attack (hold to charge; the charge bar is the HUD element above)
- **Right click** — block / guard (`MAGuardening`)
- **Walk key** — throw, where `SWEP.CanThrow` is true (Phoenix's base defaults
  it to false)

Melee does **not** use `IN_RELOAD`. The R-key weirdness reported during testing
was Helix's weapon-raise binding, not melee — see `05-animations.md`.

## Known issue: Helix's DoAnimationEvent

Helix's `GM:DoAnimationEvent` indexes `client.ixAnimTable` **without checking
it**, and that's nil for our New Vegas model class. Any melee animation event
that fell through to Helix crashed with
`sh_hooks.lua:202: attempt to index local 'animation' (a nil value)`.

Our `Schema:DoAnimationEvent` now **never falls through** on an advanced
animation model — it falls back to the `normal` tree, then returns
`ACT_INVALID`. Keep that property if you touch it.
