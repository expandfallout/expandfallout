# Race Dataset — 44 races (Divide Rebirth)

Registered by `nut.races.list[RACE.class] = RACE` at the bottom of each file.
In Helix this becomes our own `ix.races` library (no framework fork needed).

| class | Name | HP | Scale | Jump | Rads? | Hunger? | Weapons | Armors | OverridePunch | Default faction |
|---|---|---|---|---|---|---|---|---|---|---|
| giantant | Giant Ant | 200 | 0.85 | 100 | false |  | false | true | true |  |
| giantant_fire | Giant Fire Ant | 200 | 0.85 | 100 | false |  | false | true | true |  |
| citgen1 | Generation 1 Synth | 100 | 0.85 |  |  |  |  |  |  | wastelanders |
| citgen2 | Generation 2 Synth | 100 | 0.85 |  |  |  |  |  |  | wastelanders |
| sporecarrier | Spore Carrier | 200 | 0.85 | 100 | false |  | false | true | true |  |
| deathclaw | Deathclaw | 750 | 0.85 | 125 | false |  | false | true | true |  |
| deathclaw_alpha | Deathclaw Alpha | 500 | 0.85 | 100 | false |  | false | true | true |  |
| deathclaw_baby | Deathclaw Baby | 150 | 0.85 | 100 | false |  | false | true | true |  |
| deathclaw_matriarch | Deathclaw Matriarch | 500 | 0.85 | 100 | false |  | false | true | true |  |
| dog | Dog | 250 | 0.85 | 85 | false |  | false | true | true |  |
| legion_mongrel | Legion Mongrel | 250 | 0.85 | 85 | false |  | false | true | true |  |
| gecko | Gecko | 200 | 0.85 | 100 | false |  | false | true | true |  |
| geckogreen | Green Gecko | 200 | 0.85 | 100 | false |  | false | true | true |  |
| feralghoul | Feral Ghoul | 275 | 0.85 | 150 | false |  | false | true | true |  |
| feralghoul_armored | Armored Feral Ghoul | 200 | 0.85 | 100 | false |  | false | true | true |  |
| feralghoul_glowing | Glowing One | 200 | 0.85 | 100 | false |  | false | true | true |  |
| feralghoul_reaver | Feral Ghoul Reaver | 200 | 0.85 | 100 | false |  | false | true | true |  |
| radroach | Radroach | 85 | 0.85 | 100 | false |  | false | true | true |  |
| radroach_glowing | Glowing Radroach | 200 | 0.85 | 100 | false |  | false | true | true |  |
| radroach_nuka | Nuka Radroach | 200 | 0.85 | 100 | false |  | false | true | true |  |
| radscorpion | Radscorpion | 200 | 0.85 | 100 | false |  | false | true | true |  |
| radscorpion_baby | Baby Radscorpion | 200 | 0.5 | 100 | false |  | false | true | true |  |
| radscorpion_glowing | Glowing Radscorpion | 200 | 0.85 | 100 | false |  | false | true | true |  |
| radscorpion_nuka | Nuka Radscorpion | 200 | 0.85 | 100 | false |  | false | true | true |  |
| eyebot | Eyebot | 200 | 0.85 | 64 | false | false | false | true | true |  |
| libertyprime | Liberty Prime | 30000 | 0.85 | 0 | false | false | false | true | true |  |
| mistergutsy | Mister Gutsy | 350 | 0.85 | 64 | false | false | false | true | true |  |
| protectron | Protectron | 300 | 0.85 | 64 | false | false | false | true | true |  |
| robobrain | Robobrain | 100 | 0.85 | 50 | false | false |  |  |  | vaulttec |
| roboscorpion | Roboscorpion | 300 | 0.5 | 100 | false | false | false | true | true |  |
| securitron | Securitron | 500 | 0.85 | 70 | false | false |  |  |  |  |
| securitronexecutive | Securitron Executive | 600 | 0.85 | 60 | false | false |  |  |  |  |
| sentrybot | Sentry Bot | 600 | 0.85 | 64 | false | false | false | true | true |  |
| human | Human | 100 | 0.85 |  |  |  |  |  |  | wastelanders |
| legion_legatus | Legatus | 130 | 0.95 |  |  |  |  |  |  | wastelanders |
| zetan | Zetan | 100 | 0.85 | 50 | false |  |  |  |  | zetan |
| behemoth | Behemoth | 8000 | 0.85 | 350 | false |  | false | true | true |  |
| behemoth_unity | Unity Behemoth | 6500 | 0.85 | 200 | false |  | false | true | true |  |
| centaur | Centaur | 800 | 0.85 | 64 | false |  | false | true | true |  |
| centaur_evolved | Centaur Evolved | 1000 | 0.85 | 64 | false |  | false | true | true |  |
| frankhorrigan | Frank Horrigan | 1750 | 1.2 | 350 | false |  | false | true | true |  |
| nightkin | Nightkin | 250 | 0.85 | 70 | false |  |  |  |  |  |
| supermutant | Super Mutant | 275 | 0.85 | 100 | false |  |  |  |  |  |

## 15 unimplemented stub races
These files contain only `print("")` — placeholders the Phoenix devs never finished:

`giantant_queen`, `giantant_fire_queen`, `bighorner`, `bloatfly`, `brahmin`, `cazador`, `cazador_baby`,
`giantrat`, `mantis`, `molerat`, `gecko_fire`, `gecko_golden`, `mirelurk`, `mirelurk_hunter`, `mirelurk_king`

So the real count is **43 implemented, 15 stubs**. If we want mirelurks or brahmin we build them ourselves.

## Race definition contract (full field list)

**Identity:** `name`, `class` (the unique ID), `description`, `defaultFaction`, `raceColor`
**Appearance:** `animationModel`, `defaultModels{male,female}`, `hideBody`, `genders{}`, `races{}`
  (ethnicities per gender), `skins{}` (ethnicity → skin index), `heads{}`, `hairs{}`, `beards{}`,
  `faceSkins{}`, `muscles{}`, `genderCanColorHair{}`, `raceBodygroups`, `headSubMaterials`, `ragdollOverride`
**Physical:** `baseHealth`, `scale`, `jumpBoost`, `resistance`, `hull{normal,ducked}`,
  `viewOffset{normal,ducked}`, `broadShoulders`
**Rules:** `hasRadiation`, `hasHunger`, `canEquipWeapons`, `canEquipArmors`, `overridePunch`,
  `noSelectRaces`, `noInjector`, `chemWhitelist`, `chemBlacklist`, `startingGear{itemID = count}`
**Presentation:** `painSounds`, `deathSounds`, `footstepSounds`, `foodSteps`, `voiceLines`, `emotes`,
  `spawnMessage`, `editorAnimation`
**Callbacks:** `OnSpawn`, `OnThink`, `OnDeath`, `OnClear`, `OnMelee`, `OnLand`, `OnFootStep`,
  `OnAnimEvent`, `CustomKeys`

## Key design observations

- **Humans are the only fully-featured race.** 725 lines: 5 ethnicities (caucasian, african, asian,
  hispanic, **ghoul**), male/female, heads, hairs, beards, faceSkins (134 lines of them), 90 emotes,
  16 voice line sets. Note **ghoul is an ethnicity of human, not a separate race** — non-feral ghouls are
  humans with skin index 4.
- **Every monster race sets `canEquipWeapons = false`, `overridePunch = true`.** They fight with race-specific
  melee via `RACE.OnMelee`, not SWEPs. But `canEquipArmors = true` — creature "armor" is cosmetic/DR.
- **Robots set `hasHunger = false`** and all races set `hasRadiation = false` except humans (which omit it,
  so it defaults truthy). Radiation is a human-only mechanic.
- **`scale = 0.85` on almost everything** — a global model-scale convention, not a per-race stat.
  Exceptions: `radscorpion_baby`/`roboscorpion` 0.5, `legion_legatus` 0.95, `frankhorrigan` 1.2.
- **HP spread is enormous:** radroach 85 → human 100 → supermutant/feralghoul 275 → deathclaw 750 →
  centaur 800 → frankhorrigan 1750 → behemoth 8000 → **Liberty Prime 30000**. Event/boss races clearly
  share the same system as player races — worth deciding early whether we keep that.
- **`startingGear`** is per-race, not per-faction. Human default kit:
  wasteland wanderer armor, rusty 9mm, 9mm ammo, stimpak, radaway, 2× pork and beans, 2× purified water.
