# Armor V2, Radiation, Stamina, Dismemberment

## Armor V2 (44,634 LOC / 688 files — the biggest system by far)
Only ~1,440 LOC is logic; the rest is **~680 armor item definitions** organised by faction:
`items/armorv2/{bos,ncr,legion,enclave,shi,vt,gk,gr,gunners,house,foa,cc,dr,cit,chimera,boulderdome,
minutemen,mef,misc,mutant,outcasts,raiders,robots,sok,unity,vg,wastelander,westtek,zetan}/`

### 14 equipment slots
```lua
nut.armor.types = { "hat", "mask", "eyes", "helmet", "body", "backpack", "bodyAccessory",
                    "neck",                                 -- slave collar
                    "f4_helm","f4_torso","f4_larm","f4_lleg","f4_rarm","f4_rleg" }  -- FO4-style piecemeal
nut.armor.headSlots = { hat, mask, eyes, helmet, f4_helm }
nut.armor.bodySlots = { body, bodyAccessory, backpack, f4_torso, f4_larm, f4_lleg, f4_rarm, f4_rleg }
```

### Storage
`char:getData("equippedArmor:<slot>")` → item uniqueID string. One item per slot.

### DR is split head vs body
```lua
charMeta:getHeadDR()  -- sum of resistance across headSlots, math.Clamp(0, 100)
charMeta:getBodyDR()  -- sum of resistance across bodySlots, math.Clamp(0, 100)
```
Note the base item says `ITEM.resistance` max is 90 but the clamp allows 100.

### Armor base item contract (`items/base/sh_armorv2.lua`) — well documented, port nearly verbatim
| Field | Purpose |
|---|---|
| `bodyType` | which slot it occupies |
| `maleModel` / `femaleModel` | gendered models |
| `skin`, `bodyGroups` | `skin = false` inherits the race's skin |
| `resistance` | damage resist %, max 90 |
| `radResistance` | rad resist %, max 100 |
| `fallProtection` | fall damage reduction %, max 100 |
| `speedBoost`, `jumpBoost` | additive |
| `specialBonus` | `{STR,PER,END,CHR,INT,AGL,LCK}` — **note: 3-letter codes, not attribute names** |
| `armorRace` | `{human=true, supermutant=false, nightkint=false, securitron=false}` |
| `takesType` | slots this occupies/blocks (hat/mask/eyes/helmet/body) |
| `takesBody` | body parts hidden (hair/beard/head) |
| `textureReplace` | map material path → replacement vmt |
| `isPA` | Power Armor: no headshot damage, no stamina drain |
| `noCore` | PA that needs no fusion core |
| `faction`, `factionClass` | appends to description (Enlisted/NCO/Officer/Lead) |
| `playerHeight` | height adjustment when worn |
| `onEquip` / `onUnequip` | callbacks |

**Watch out:** `specialBonus` uses `STR/PER/END/...` while `attributes` uses `Strength/Perception/...` and
the attribute registry keys off lowercase filenames. Three naming conventions for one concept. **Unify this
in our build.**

### Power Armor
- `client:GetNW2Bool("WearingPA")` — the global "am I in PA" flag
- Fusion core drains at `Core Drain Rate` = 0.01/sec **while moving**; `client.noCoreCharge` when dead →
  forced to walk speed
- `Power Armor Max Headshot Mult` = 1.75
- Custom footstep sounds `phoenix/powerarmor/step_1-4.wav`; super mutants get their own VJ sounds
- Only a whitelist of chems usable in PA (`nut.armor.paAllowedChems`) — stimpak, super stimpak, radaway,
  rad-x, healing powder, stealthboy, cleansing powder, coyote tobacco, robot repair kit, spore/centaur injectors

### Stealth (Stealth Boy)
- `Stealth Description Distance` = 50 — how close before your description is readable
- `Stealth Shimmer Velocity` = 5 — move faster than this and you shimmer
- `nut.armor.validStealthWeapons = { nut_keys, nut_hands }` — drawing anything else breaks stealth

### Buff types
`nut.armor.removeBuffType = { DR, HP, DMG, SPD, JMP }` — buffs live on `client.buffs[type]`.

---

## Radiation (164 LOC)
`char:getData("radiation", 0)`, range **0–100**.

**Six debuff tiers** (keyed by threshold), each applying negative SPECIAL:
| Rads | Name | Effect |
|---|---|---|
| 0 | None | — |
| 20 | Minor Radiation Sickness | END −1 |
| 40 | Advanced Radiation Sickness | END −2 |
| 60 | Critical Radiation Sickness | END −3, AGL −1 |
| 80 | Severe Radiation Poisoning | HP −5, END −4, AGL −2 |
| 100 | Fatal Radiation Poisoning | HP −10, END −5, AGL −3 |

At 100 rads you take **10% of max health as damage** from the world.

**Resistance** stacks: `radman` perk (T1 = 50%, T2 = 90%) + every equipped armor's `radResistance` +
`client.buffs["RAD-RES"]`, clamped 0–100. Applied as `amount * (1 - resistance/100)`.

`isCloud` bypasses resistance entirely — rad clouds ignore your gear.
`nut.races:takesRadiation(char)` gates it — ghouls/robots are immune.

---

## Stamina (169 LOC)
`client:setLocalVar("stm", value)`, 0 to `defaultStamina` (100). Ticks every **0.25s**.

- **Run speed** = `runSpeed config + (Agility * 3)`, `+ buffs["SPD"]`, `* 0.775` in water
- **Drain while running** = `math.min(-1.5 + (Endurance / 35), -0.2)` — Endurance softens drain, floor −0.2
- **Regen** = `1.75 * staminaRegenMultiplier` (or `1 *` if offset was already > 0.5); **+1 while crouching**
- **Thirst/hunger modify regen:** thirst > 50 → `+0.5`; thirst ≤ 10 → `halved`; hunger < 10 → `halved`
- **Jump cost** = 20 (`jumpStamina`), PA = 20 (`paJumpStamina`). Blocked via `CMoveData:RemoveKeys(IN_JUMP)`
  if insufficient — clean approach, keep it
- **At 0 stamina** → forced to walk speed + `brth` localvar set; recovers at **25** (hysteresis, good)
- PA: `paRunReduction` 0.9, `paGivesInfStamina` false by default

---

## Dismemberment (423 LOC)
Damage multipliers keyed by **weapon caliber**, read from `SWEP.Type` on the Longsword weapon addon.
All 10 types covered (only `Other`, 3 weapons, is unlisted):

| Type | Head | Chest | Stomach | L.Arm | R.Arm | L.Leg | R.Leg | Dismember % |
|---|---|---|---|---|---|---|---|---|
| Sniper | 3 | 1 | 1 | 0.75 | 0.75 | 0.75 | 0.75 | 100% |
| Shotgun | 1.25 | 1 | 1 | 1 | 1 | 1 | 1 | 50% |
| Pistol | 1.5 | 1 | 1 | 1 | 1 | 1 | 1 | 25% |
| Revolver | 3 | 1 | 1 | 1 | 1 | 1 | 1 | 100% |
| SMG | 1.25 | 1 | 1 | 1 | 1 | 1 | 1 | 25% |
| Rifle | 1.5 | 1 | 1 | 1 | 1 | 1 | 1 | 80% |
| Marksman | 2 | 1 | 1 | 1 | 1 | 1 | 1 | 80% |
| Heavy | 1.25 | 1 | 1 | 1 | 1 | 1 | 1 | 50% |
| Energy | 1.3 | 1.2 | 1.2 | 1.2 | 1.2 | 1.2 | 1.2 | 80% |
| Explosive | 1 | 1 | 1 | 1 | 1 | 15 | 1 | 100% |

**Bug in their data:** `Explosive` has `HITGROUP_LEFTLEG = 15` — a 15x multiplier on one leg only.
Almost certainly meant `1.5`. Don't copy this.

Configs: `Gib Time` 10s, `Head Collection Time` 3s. Severed heads become collectible items (bounty system).
