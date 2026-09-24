# 03 — Ranged weapons

## What's installed

**176 weapons** on the Longsword base, all fully modelled.

| Category | Count | | Category | Count |
|---|---|---|---|---|
| Uniques | 50 | | Heavy | 8 |
| Energy | 33 | | SMGs | 8 |
| Rifles | 27 | | Explosive | 6 |
| Pistols | 17 | | Other | 5 |
| Plasma | 9 | | Snipers | 4 |
| Shotguns | 9 | | | |

Spawnmenu categories are `Fallout RP - <X>`, pulled from the originals rather
than derived from `SWEP.Type` — the original taxonomy is better for browsing
(all 50 Uniques together, Plasma split from Energy, designators under Other).

**`SWEP.Type` and `SWEP.Category` deliberately disagree** in places.
`Type` is the *ballistic class* the dismemberment plugin keys off; `Category`
is how you browse. Don't "fix" the mismatch.

25 ammo types, all registered by `longsword_base/lua/autorun/a_funcs.lua`
(44 `game.AddAmmoType` calls).

**One weapon dropped:** `ls_heavy_plasma_repeater` — its model doesn't exist in
any of the 78 addons.

## Provenance

Longsword is *"a lightweight weapon base by vin"*, recovered from a client-side
scrape, not obtained from its author. Fine for local development. **Before this
server goes public that needs settling** — buy it properly or replace it. Noted
as a release blocker in `addons/longsword_base/README.txt`.

## Base modifications

All documented in `addons/longsword_base/README.txt`. Summary:

1. **Framework bridge** — `lsFramework()`, `lsGetCharacter()`, `lsGetRace()`,
   `lsIsLowered()`, `lsItemGetData()` resolve `ix` or `nut` at call time, so
   the base runs on either framework or neither.
2. **`DrawWorldModel`** — `LookupAttachment` returns **0** (truthy!) when an
   attachment is missing, so the original walked past its own guard and drew
   nothing. Every gun was invisible in the world. Now falls back to
   `ValveBiped.Bip01_R_Hand`.
3. **`FireAnimationEvent`** — returned `true` unconditionally for events
   21/5001/5003/5011/5021/5031, which **suppresses muzzle flashes**. Correct
   for the 44 weapons with a custom `MuzzleFlashEffect`; the other 132 had no
   flash at all. Now only suppresses when a replacement exists.
4. **Fonts** — `UI_Regular` and `UI_Bold` are Phoenix schema fonts we don't
   have. An invalid font makes `surface.GetTextSize` return nil, which is what
   produced `arithmetic on local 'w'` in `draw.SimpleText`.
5. **Lowered pose** — 57 weapons define no `LoweredPos` and so never holstered.
   A file-local default is used in `GetOffset`. **Deliberately not a SWEP
   field**: `CalculateSpread` branches on `if self.LoweredPos` to pick walk vs
   run speed for movement spread, so setting it would silently change balance.
6. **`LowerAngles`/`LowerAngles2` zeroed** — Helix's `CalcViewModelView`
   rotates the viewmodel by these while lowered (default `Angle(30,0,-25)`).
   Longsword lowers the weapon itself, so both fired at once and pushed the gun
   off screen. Framework raise state now feeds Longsword's own pose.

## Tracers

`longsword_base/lua/effects/longsword_tracer/init.lua`. This took several
passes; the failures are instructive.

**Four separate faults:**

1. `FireBullets` gives its tracer effect **Scale 0**, and the stock `Tracer`
   effect treats Scale as travel velocity — so engine tracers never rendered.
   Engine tracers are now disabled (`Tracer = 0`) and we spawn our own.
2. Spawning **only serverside** made the shooter wait a network round trip.
   *But* spawning in **both** callbacks and relying on GMod's prediction filter
   to suppress the server copy gave **two tracers per shot** — which reads
   exactly like the gun firing at double rate. There is now **exactly one
   spawn site**, serverside with `bIgnorePredictionFilter = true`.
3. `render.SetColorMaterial()` is not dependable for `DrawBeam`, which wants
   `$vertexcolor`/`$vertexalpha`. The effect resolves a material at load time
   through a fallback chain: our own `effects/ls_tracer` → `effects/laser1` →
   `trails/laser` → `sprites/physbeam` → `cable/rope`.
4. **`CurTime()` is tick-quantised.** Animating the streak off it made tracers
   step 16×/sec regardless of framerate. Uses **`RealTime()`** throughout.

**Muzzle resolution:** these models are Fallout: New Vegas ports and have **no
`muzzle` attachment** — they use `ProjectileNode`, as a **bone**, not an
attachment. First person uses the viewmodel; third person goes to the hand bone
**first** (the weapon entity's transform sits at the player's origin, because
Longsword draws the world model manually at a bone offset).

**Tunables** at the top of the effect: `Speed`, `Length`, `Width`, `Color`,
`MuzzleInset`, `EyeFallbackForward/Down`.

**Per-weapon tracer selection** in `ShootBullet`:
- `Primary.Tracer` is a string → that effect
- `Primary.Tracer == false` → **none** (6 weapons; `false` is falsy, so an
  `or` fallback silently turned this into "default")
- `MuzzleFlashEffect` set, no `Tracer` → **none** (11 plasma/alien weapons draw
  their own bolt)
- otherwise → `longsword_tracer`

Note: keying this off `SWEP.Type == "Energy"` was **wrong** — five plasma
weapons are typed `Heavy`.

## Scopes

The overlay is stretched full screen, so whatever the texture calls "centre" is
where the reticle lands. Bullets always go to true screen centre (`CalcView` is
empty — scoping changes FOV only).

`SWEP.ScopeOffset = {x, y}` shifts the overlay, in **fractions of screen size**.
The Wattz carried a 0.048 nudge down from a guess that the laserscope reticle
was authored above centre; the scoped laser rifle uses the same texture with
no offset and is centred, so the Wattz's is zero now.
Only the exposed edge strip is filled black — filling the whole screen behind
the overlay blacks out the scope entirely, because the lens is a transparent
hole in that material.

**Live tuning** (client convars, added to the weapon's own offset):

```
ls_scope_tune_x 0.0
ls_scope_tune_y 0.05
```

`ls_wattz_sniper` needs this; its `laserscope` texture is authored off-centre.
**The current value is unverified** — see `08-open-items.md`.

## Projectiles

All seven entity folders lost their `init.lua` to the scrape. Five were
rewritten; the behaviour is ours, the damage/velocity/effects are Phoenix's.

| Entity | Weapons | Behaviour |
|---|---|---|
| `ls_fallout_missile` | 2 | Flat flight, constant velocity, contact detonation |
| `ls_fallout_grenaderifle` | 4 | **Arcs** (gravity on) but **impact-detonating** |
| `ls_fallout_mininuke` | Fat Man | 600u blast, `effect_fo3_fatman` + `ScreenFade` |
| `incin_round` | Incinerator | Ignites target, leaves `env_fire` patches |
| `ls_redglare_missile` | Red Glare | Lighter missile, red trail |

- `ls_euclidbeam` — **complete already**, its logic lives in `shared.lua`.
  Don't write an `init.lua` for it.
- `ls_thor_projectile` — no weapon references it. Left alone.

All have an **arm delay** so clipping your own hitbox on spawn doesn't detonate
in your face. Tunables are named constants at the top of each file.

**`grenade_frag_explode` is visual-only** — unlike `effect_fo3_fatman` it plays
no audio, so the entities emit Phoenix's frag sounds themselves.

## Effects — the NULL owner guard

The 35 scraped `fo3_*` effects read the shooter's velocity so particles inherit
the player's motion:

```lua
particle:SetVelocity(350 * self.Forward + 1.1 * self.WeaponEnt:GetOwner():GetVelocity())
```

`self.WeaponEnt` comes from `data:GetEntity()` and can be **NULL** by the time
the effect runs, so this throws `Tried to use a NULL entity!` — **once per
particle**, which is why it floods the console.

Phoenix had already fixed four of their own effects; that same guard is now on
all of them, plus `if not IsValid(self.WeaponEnt) then return false end` at the
top of every `Think` that builds a `DynamicLight`. Full pattern and the
batch-editing trap are in `13-troubleshooting.md`.

## Branding — a faction's mark and a serial

Right-click a weapon → **Brand**. It costs `weaponBrandCost` (500 by default,
dev terminal → ALL SETTINGS), asks for confirmation, and stamps the weapon with
the faction of the character doing it and a serial in the form
`XXXXX-XXXXX-XXXXX`. **Copy Brand ID** puts the serial on the clipboard.

Phoenix's, from their `sh_moddableweapons.lua`, with the same rules:

- **your own faction only**, and **not the default faction** — a wastelander is
  not an organisation and has nothing to issue kit in the name of. Phoenix
  refuse "Wastelanders" by name; this refuses whichever faction is flagged
  `isDefault`, which is the same faction and stays right if it is renamed
- **it cannot be undone.** There is no unbranding item in theirs either. A mark
  you can take off is not a mark
- the description grows `Branded to: <faction>` and `Brand ID: <serial>`

**The faction NAME is stored, not its id.** A faction renamed later does not
silently rewrite what is stamped on every weapon it ever issued, and a faction
deleted entirely leaves its mark behind rather than a blank — which is the whole
point of a brand: it records what was true when it was made.

**The serial's alphabet leaves out 0, O, 1, I, 5 and S.** A serial exists to be
read off a screen and typed into a ticket by somebody else, and those are the
pairs that get typed wrong — which turns "the rifle with this serial" into an
argument.

Both menu entries are keyed `zBrand` and `zBrandCopy` so they sort to the bottom
of the right-click menu: it is built with `SortedPairs`, and "Brand" would
otherwise sit above "Equip", putting an irreversible 500-cap action where the
muscle memory for equipping a rifle is. Helix's own armour base does the same
thing with `EquipUn`.

The entries are injected into every registered weapon on `InitializedPlugins`
rather than added to `base_weapons` — Helix **copies** a base into each item at
registration rather than leaving a metatable behind, so a function added to the
base afterwards reaches nothing. `cl_rarity.lua` wraps every weapon the same way
for the same reason.

Every brand is logged with the weapon, the faction, the serial and what it cost
(`ix.log` type `weaponBrand`), and the character who did it is kept on the item
as `brandedBy` — not shown on the weapon, because the mark is the faction's, but
there for an admin reading a report six weeks later.

---

## Fire rate — measured, correct, do not "fix"

Verified with instrumentation on both realms:

| Weapon | Configured | Actual |
|---|---|---|
| `ls_tesla_rcw` | 600 RPM | 452 |
| `ls_minigun` | 1200 RPM | 948 |
| `ls_mg42` | 1000 RPM | 924 |

**Everything fires slower than configured, never faster.** Rounds per shot
0.91–0.99, so the magazine isn't over-draining either.

The gap is **tick quantisation** — `SetNextPrimaryFire` resolves on tick
boundaries, so `Delay 0.1` becomes 0.125s at 16 tick. A 12-tick server gives
0.1667s, i.e. 33% slower, which is why it feels different from Phoenix's main.

The fire logic and the weapon data are **byte-identical** between the live
Phoenix scrape and ours. If it needs to feel slower, that's a **tuning
decision** (scale the `Delay` values), not a bug.

---

## Weapon model audit (2026-09-04)

Tool: `_docs/tools/weaponaudit.py`.

`resolve_asset.py --swep` answers "does this model exist", which is not the same
as "is this the right model". A weapon pointing at a real Fallout model that
belongs to a different gun resolves perfectly and is still a placeholder. The
audit classifies MISSING / PLACEHOLDER / OK and suggests candidates by name.

### 27 uniques shared one placeholder

Every `ls_unique_*` weapon except `ls_unique_sprtelwood` pointed at
`v/w_sprtel_wood_9700` — the Sprtel-Wood 9700's own model, which that one
weapon legitimately owns. **Phoenix's scrape has the same placeholder**, so
there was nothing to copy from the dumps; the correct models were sitting
installed and unreferenced the whole time.

The tell was not "missing model" but **weapons sharing a model pair**. That is
the check worth repeating: legitimate sharing exists (scoped/suppressed/
automatic variants) but 28 weapons on one model is not it.

Offsets are model-specific, so each weapon also took `ViewModelOffset`,
`WorldModelOffset*`, `WorldModelScale` and `HoldType` from a **donor** — an
existing, correctly positioned weapon using a model from the same pack and the
same category directory. Same pack and category means the same export
convention, which is what those numbers encode. `ls_unique_maria` had
`HoldType = "ar2"` for a pistol, which the donor also fixed.

### Mismatched pairs

A second check — does the world model's name correspond to the view model's —
found four. Only `ls_unique_alienblaster` was fixable (`w_alien_blaster.mdl`
exists). The other three have **no view model in the content at all**, so their
stand-ins are the best available:

| Weapon | Stand-in |
|---|---|
| `ls_tribeam_laser_rifle` | `v_scatter` — no `v_tribeam` exists |
| `ls_bellumbanner` | `v_bigo` — no flag view model exists |
| `ls_radiation_scanner` | `v_mesmetron` — no scanner view model exists |

### 24 weapons added

Searched every scrape, not just one addon. Found 32 Longsword weapons absent
here; **7 were renamed duplicates** of weapons already present, and one is
blocked:

| Skipped as duplicate | Already here as |
|---|---|
| `ls_45auto_smg` | `ls_45_auto_smg` |
| `ls_50cal` | `ls_50browning` |
| `ls_navyrevolver` | `ls_navy_revolver` |
| `ls_shouldermouted_smg` | `ls_shoulder_mounted_machine_gun` |
| `ls_stimpak_launcher` | `ls_syringe_pistol` |
| `ls_tesla_gauss_rifle` | `ls_tesla_sniper_rifle` |
| `ls_weapon_plasmaglock` | `ls_plasma_glock` |

`ls_heavy_plasma_repeater` is **blocked**: its model
(`models/weapons/heavyplasmarepeater/`) is not installed.

Added: 8 guns — including the **C.I.T laser pistol and rifle** — plus an entire
throwables set (9 grenades, 6 mines, a throwing spear) with its 19 projectile
entities, which was a separate addon we did not have at all.

### Six of them were truncated scrapes

`ls_grenade_plasma`, `ls_grenade_pulse`, `ls_mine_bottlecap`, `ls_mine_c4`,
`ls_mine_plasma` and `ls_mine_pulse` came out of glua-steal at **22 lines**
against 149–181 for a complete sibling — everything below the header was lost,
including models, offsets and the whole `SWEP.Projectile` block.

Rebuilt from their nearest complete sibling with their own identity fields
carried over, each pointed at its own `ent_*` class and model. `ls_mine_pulse`
was named "Plasma Mine" in the source; that is a copy-paste slip and is now
"Pulse Mine".

`ent_grenade_incin` spawned its fire carrier as
`models/hunter/blocks/cube025x025x025.mdl` — stock GMod content **not installed
here**, so every incendiary would have spat an error model. It is invisible
(alpha zero, `RENDERMODE_TRANSCOLOR`), so it now reuses the grenade's own model.

**Result: 204 weapons, 0 missing or placeholder models, 400 model references OK.**

### Corrections to the mapping above

Two uniques had a better model than the donor-category guess:

| Weapon | Was mapped to | Actually has |
|---|---|---|
| `ls_unique_teslabeatonprototype` | `m72gauss` | `v_teslacannon_prototype.mdl` |
| `ls_unique_thesmittyspecial` | `rhys/smitty/v_smitty` | `v_smitty_special.mdl` |

Found by asking a different question — **which installed weapon models have no
SWEP using them** — rather than starting from the weapon list. Note the tesla
world model is on disk as `w_teslacannon_prototype.mdl.mdl`, with a doubled
extension; that is the real filename, not a typo here.

### 26 installed models have no weapon anywhere

That same check found 33 view models with no SWEP. Seven are accounted for
(their weapon uses a different model, or they are the two above). The other
**26 have no SWEP in any dump** — the content is installed but the weapon was
never written, by Phoenix or anyone:

| | |
|---|---|
| guns | Railway Rifle, Infiltrator, Sonic Emitter, Flare Gun, Colt .357, Detonator, Laser Detonator, Bozar variants, G11, Bozar, SPAS, Storm Drum, Uzi, .50 SMG, SMMG, AS VAL, CAWS, Jackhammer, Plasma Rifle, Alien Atomizer, Gauss Minigun |
| melee/unarmed | Ballistic Fist, Power Fist, Zap Glove, Displacement Glove, gloves, h2h |

Adding these is **writing new SWEPs from scratch**, not porting — a different
and much larger job than copying files across. The models, materials and sounds
are all present, so the work is the weapon definitions.

The unarmed ones (h2h, gloves, powerfist) most likely belong with `meleearts2`
rather than as Longsword SWEPs.

### C.I.T weapons

Four are present: `ls_cit_laser`, `ls_cit_laser_pistol`, `ls_cit_laser_rifle`
and `ls_cit_v3n_biorifle` — the middle two added here. Only **one** C.I.T model
pair is installed (`v/w_c.i.t_rifle.mdl` from `phoenix_weapons_extra`), so any
further C.I.T weapon on the live server uses content this install does not have.

### The compat layer needed inventory and item methods

`ls_syringe_pistol` threw `attempt to call method 'getItemsOfType'` every frame
while drawing its stimpak counter. The compat layer aliased player and character
methods but nothing on the inventory or on items, so `char:getInv()` succeeded
and handed back a real Helix inventory that then had no NutScript methods - an
error naming a method nobody wrote, on a weapon that looks fine.

Added: `getItemsOfType`, `getItemCount`, `getItemAt`, `getItems`, `getSize`,
`getID`, `getOwner`, `hasItem`, `remove` on the inventory; `getID`, `getName`,
`getData`, `setData`, `getModel`, `getOwner`, `remove` on items; plus
`addHunger`/`addThirst` as no-ops (like `addRadiation`, pending survival) and
`setRagdolled`, which is a real rename of Helix's `SetRagdolled`.

Every lowerCamelCase method the weapons call is now covered - checked by
extracting the calls rather than by reading.

### 17 weapons written for orphaned content

Generated by `_docs/tools/` scripting from a **donor** — an existing weapon
using a model from the same pack and category directory — so the view/world
offsets, hold type and race overrides are the ones already known to position
that pack's models. Only identity and ballistics were overridden.

| Weapon | Type | Ammo | Dmg | Clip | Donor |
|---|---|---|---|---|---|
| Colt .357 | Revolver | 357Magnum | 34 | 6 | `ls_32_pistol` |
| Flare Gun | Pistol | 20Gauge | 15 | 1 | `ls_32_pistol` |
| Sonic Emitter | Energy | ElectronChargePack | 45 | 10 | `ls_32_pistol` |
| Detonator | Other | none | 0 | 0 | `ls_32_pistol` |
| Laser Detonator | Other | none | 0 | 0 | `ls_32_pistol` |
| Infiltrator | Rifle | 556mm | 26 | 24 | `ls_ak112` |
| Railway Rifle | Heavy | 5mm | 60 | 8 | `ls_ak112` |
| Alien Atomizer | Energy | EnergyCell | 35 | 20 | `ls_10mm_pistol` |
| AS VAL | Rifle | 308 | 32 | 20 | `ls_ak47` |
| CAWS | Shotgun | 12Gauge | 11×7 | 10 | `ls_riot_shotgun` |
| Jackhammer | Shotgun | 12Gauge | 11×7 | 12 | `ls_riot_shotgun` |
| .50 SMG | SMG | 50MG | 28 | 21 | `ls_lockwood` |
| G11 | Rifle | 556mm | 24 | 50 | `ls_lockwood` |
| Silenced Machine Gun | Heavy | 556mm | 20 | 100 | `ls_lockwood` |
| SPAS-12 | Shotgun | 12Gauge | 12×8 | 8 | `ls_lockwood` |
| Storm Drum | Shotgun | 12Gauge | 10×6 | 20 | `ls_lockwood` |
| Uzi | SMG | 9mm | 15 | 32 | `ls_navy_revolver` |

**The stats are a starting point, not canon.** Nothing in the dumps carries
numbers for these because the weapons were never written; they follow the
conventions in `reference/06_weapons_data.md` and the weapon's role in Fallout.
Expect to tune them.

Three need a system that does not exist yet:

- **Detonator** and **Laser Detonator** are triggers for placed explosives.
  They are `Other`/no-ammo like `ls_laser_designator`, and do nothing until a
  detonation system exists.
- **Flare Gun** fires a 20Gauge round as a stand-in; there is no flare ammo type
  and no flare projectile.

### Not written, and why

| | |
|---|---|
| Ballistic Fist, Power Fist, Zap Glove, Displacement Glove, gloves, h2h | **no world model** — unarmed content that belongs with `meleearts2`, not as Longsword SWEPs |
| `fire_bomb` | no world model |
| laser musket, Bozar, gauss minigun, smitty, plasma rifle | a weapon already exists; these are alternate model variants |

### C.I.T weapons were not spawnable

All four had `SWEP.Spawnable = false`, and three also `AdminSpawnable = false` —
so they never appeared in the Q menu at any rank. Every other weapon in the pack
is `true/true`. Matched to the rest.

That is worth checking after any bulk copy from the scrapes: 196 of 200 were
`true/true`, and the four odd ones out were exactly the ones reported missing.

## `Force = 1`, not zero

The bullet table in `ls_base.lua` shipped with `Force = 0`, and the engine
prints a warning for every shot that lands with no force vector:

```
AddMultiDamage: g_MultiDamage.GetDamageForce() == vec3_origin
```

One line per pellet, which buries real errors. **One** is the smallest number
that is not zero — far too small to throw a prop or shove a body, which is the
point: it silences the warning without adding knockback that 176 weapons were
never balanced around.

## The base fires from a cache, not from `Primary`

`BuildBaseCachedData()` copies damage, cone, recoil and `NumShots` into
`SWEP.CachedData` once, and `GetCachedData()` is what the firing code reads.
Writing `Primary.NumShots` on a weapon somebody is already holding therefore
changes a field **nothing reads again** — which is why setting a rifle to fire
six pellets appeared to do nothing at all until it was dropped and picked up.

**A weapon file writes only what makes it that weapon.** 54 of the 217 have no
`SWEP.Spread` table and almost none set `AmmoPerShot`; `table.Inherit` fills
those from `ls_base` when the entity is made. So reading a stored SWEP table
tells you what the file says, not what the gun does — the base's own values are
the rest of the answer.

Two fields, not one, decide what a shot costs and what it throws:
`Primary.AmmoPerShot` is how many rounds leave the magazine and
`Primary.NumShots` is how many pellets arrive — a shotgun spends one shell for
eight pellets, and a gauss rifle can spend five cells for one. Both are cached.

`weapon:RebuildCachedData()` is the fix, and the live editor calls it on every
weapon of the edited class (`SetCached(key, value)` is the single-field version,
and applies the cache as well). Anything else that changes a weapon's numbers at
runtime has to do the same.

## Grenades

The throwables (`addons/falloutrp_weapons/lua/entities/ent_grenade_*.lua`,
Phoenix's `longsword_fallout_throwables` scrape) were half missing and half
pointed at content that is not here. Checked one by one against the mounted
packs:

| grenade | what was wrong | now |
|---|---|---|
| all | bounce sound `phoenix/grenade/grenade_hit1.wav` — no such folder in any pack | HL2 solid-metal impacts, random of three |
| all | the weapon's fuse (`projectile.Timer`, cooking subtracted) was ignored; every grenade counted its own three seconds from the throw | the entity honours `Timer` when the weapon sets it |
| flash bang | `phoenix/grenade/flashbang_explode1.wav` — missing, so silent | HL2 explosion cracks pitched to 150; the white-out and stunstick flash as before |
| plasma | the file was **seven lines** — no model, no effect, no sound; it fell through to the frag base | its own model, `grenade_plasma_explode`, the plasma detonation sounds, a green flash; 300 damage / 300 radius |
| pulse | seven lines too | its own model, a new `grenade_pulse_explode` (arcs, blue haze, a light), the EMP sounds; 50 blast + **250 shock to machines** — robot races and anybody in power armour |
| smoke | `lvs_defence_smoke`, an effect from a vehicle addon not installed, on one shared timer name | `grenade_fallout_smoke` rewritten as a cloud (four large slow puffs per pulse, twenty seconds of pulses), per-canister timer |
| incendiary | `[1]ground_fire_1*` from a .pcf no pack carries, sounds from the missing folder | seven `env_fire` patches for ten seconds — the engine's own fire, which burns whoever walks in — plus HL2's ignite sounds; people in the radius still catch |
| cryo | `nut.rib:applyCryo`, a NutScript call that errored | `ix.buff.Add(SPD, -60, 5s)` — the same library a chem uses — and 60 blast damage |
| dynamite | named "Cryo Grenade" | named Dynamite |
| frag, holy | fine | — |

`ExplosionPitch` is a new per-entity field the base reads when it plays the
detonation. Mines (`ent_mine_*`) were not touched.

## Artillery

The artillery finder's shells "went past where they should". `ls_fallout_missile`
flies at a **constant speed with gravity off** (its Think re-asserts the
velocity), so the launch code's "slight upward bias so gravity creates a visible
arc" did not arc anything — it lifted the whole line of flight, and every shell
sailed over its point and on. Shells are now aimed exactly at their own point
from a battery 2,200 units out and 2,400 up, which comes in steeply enough to
read as artillery, and `missile.Speed` is set to the launch speed so the Think
does not change it.
