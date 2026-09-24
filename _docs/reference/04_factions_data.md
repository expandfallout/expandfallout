# Faction Dataset — all 33 factions (extracted from Divide Rebirth)

Field schema is uniform across all 33 files:
`name, desc, color, isDefault, icon, models, races, raidImmune, canAmbush, canCapture, canCaptureArea,
  flagModel, flagSkin, karma{kill,passive}, radio{color,sounds,volume,pitch,censor}`
plus `raceSelector` (5 factions) and `hideInScoreboard` (1).

> **Port blocker:** `FACTION.models` is a KEYED table (`["model"] = true`). Helix iterates with `pairs`
> and expects model strings/tables as VALUES — must convert to array form or charcreate breaks silently.

## Summary

| File | Name | Default | RaidImm | Ambush | Capture | CapArea | Karma kill (+/-) | Karma passive (+/-) | Races |
|---|---|---|---|---|---|---|---|---|---|
| sh_bos | Brotherhood of Steel | true | false | true | true | true | 1, 5 | 5, 1 | human  |
| sh_boulderdome | Boulder Dome | false | false | true | false | true | 1, 1 | 1, 1 | human  |
| sh_chimera | Chimera | false | false | true | false | true | 5, 1 | 1, 5 | human  |
| sh_cit | C.I.T | false | false | true | false | true | 2, 1 | 1, 1 | human  |
| sh_creatures | Creatures | false | true | false | false | false | 0,0 | 0,0 | dog  |
| sh_crimsoncaravan | Crimson Caravan © | false | true | false | false | true | 1, 1 | 1, 1 | human  |
| sh_deathclaws | Deathclaws | false | true | false | false | false | 0,0 | 0,0 | deathclaw  |
| sh_desertrangers | Desert Rangers | false | false | true | false | true | 1, 5 | 5, 1 | human  |
| sh_enclave | Enclave Remnants | true | false | true | false | false | 10, 1 | 1, 30 | human  |
| sh_feral | Feral | false | true | false | false | false | 0,0 | 0,0 | feralghoul  |
| sh_fiends | Fiends | false | false | true | false | true | 5, 1 | 1, 5 | human  |
| sh_foa | Followers of the Apocalypse | false | false | true | false | true | 1, 5 | 5, 1 | human  |
| sh_greatkhans | Great Khans © | false | false | true | false | true | 5, 1 | 1, 5 | human  |
| sh_gunners | Gunners | false | false | true | false | true | 2, 2 | 2, 2 | human  |
| sh_gunrunners | Gun Runners © | false | false | true | false | true | 2, 2 | 2, 2 | human  |
| sh_house | House | true | false | true | true | true | 2, 4 | 4, 2 | human  |
| sh_legion | Caesar's Legion | false | false | true | true | true | 5, 1 | 1, 5 | human  |
| sh_marketdistrict | Market District © | false | false | true | false |  | 3, 2 | 2, 3 | human  |
| sh_mef | Midwestern Expeditionary Force | false | false | true | false | true | 1, 5 | 5, 1 | human  |
| sh_minutemen | Minutemen | false | false | true | false | true | 1, 1 | 1, 1 | human  |
| sh_monsters | Monsters | false | true | false | false | false | 0,0 | 0,0 | radscorpion radroach giantant gecko  |
| sh_ncr | New California Republic | false | false | true | true | true | 1, 5 | 5, 1 | human  |
| sh_outcasts | The Outcasts | false | false | true | false | true | 1, 2 | 2, 1 |  |
| sh_robots | Robots | false | true | false | false | false | 0,0 | 0,0 | sentrybot mistergutsy protectron eyebot  |
| sh_shi | Shi | false | false | true | false | true | 2, 2 | 2, 2 | human  |
| sh_sok | Sons Of Kaga | false | false | true | false | true | 1, 5 | 5, 1 |  |
| sh_supermutant | Super Mutants | false | true | true | false | false | 0, 0 | 0, 0 | supermutant  |
| sh_unity | Unity Remnants | false | false | true | false | true | 5, 1 | 1, 5 | human supermutant nightkin  |
| sh_vangraffs | Van Graffs © | false | false | true | false | true | 3, 2 | 2, 3 | human  |
| sh_vaulttec | Vault-Tec | false | false | true | false | true | 1, 5 | 5, 1 | human  |
| sh_wastelanders | Wastelanders | true | true | false | false | false | 1, 1 | 1, 1 | human  |
| sh_westtek | West Tek | false | false | true | false | true | 1, 1 | 1, 1 | human  |
| sh_zetan | ZSD-7 | false | false | true | true | false | 1, 1 | 1, 1 | zetan  |

## Colors, icons and flags

| File | Color | Icon | Flag model | Skin |
|---|---|---|---|---|
| sh_bos | `Color(0, 0, 225)` | phoenix/faction_icons/bos.png | models/dio/flag_redux/bos/brotherhood flags.mdl | 2 |
| sh_boulderdome | `Color(100, 0, 255)` | phoenix/faction_icons/boulderdome_text.png | models/dio/flag_redux/bos/brotherhood flags.mdl | 2 |
| sh_chimera | `Color(255, 255, 255)` | phoenix/faction_icons/onyx.png | models/dio/flag_redux/bos/brotherhood flags.mdl | 2 |
| sh_cit | `Color(255, 255, 255)` | phoenix/faction_icons/institute.png | models/dio/flag_redux/fo4/fallout 4 flags.mdl | 2 |
| sh_creatures | `Color(200, 0, 0)` | phoenix/faction_icons/creature.png | models/dio/flag_redux/new_vegas/new vegas flags.mdl | 9 |
| sh_crimsoncaravan | `Color(153, 0, 0)` | phoenix/faction_icons/crimsoncaravan.png |  |  |
| sh_deathclaws | `Color(200, 0, 0)` | phoenix/faction_icons/monster.png | models/dio/flag_redux/new_vegas/new vegas flags.mdl | 9 |
| sh_desertrangers | `Color(9, 146, 0)` | phoenix/faction_icons/desertrangers.png | models/dio/flag_redux/bos/brotherhood flags.mdl | 2 |
| sh_enclave | `Color(10, 10, 10)` | phoenix/faction_icons/enclave.png | models/dio/flag_redux/enc/enc flags.mdl | 0 |
| sh_feral | `Color(200, 0, 0)` | phoenix/faction_icons/creature.png | models/dio/flag_redux/new_vegas/new vegas flags.mdl | 9 |
| sh_fiends | `Color(255, 207, 98)` | phoenix/faction_icons/fiends.png | models/dio/flag_redux/bos/brotherhood flags.mdl | 2 |
| sh_foa | `Color(200, 200, 200)` | phoenix/faction_icons/foa.png | models/dio/flag_redux/bos/brotherhood flags.mdl | 2 |
| sh_greatkhans | `Color(255, 131, 0)` | phoenix/faction_icons/gk.png | models/dio/flag_redux/bos/brotherhood flags.mdl | 2 |
| sh_gunners | `Color(63, 207, 63)` | phoenix/faction_icons/gunners.png | models/dio/flag_redux/bos/brotherhood flags.mdl | 2 |
| sh_gunrunners | `Color(255, 207, 63)` | phoenix/faction_icons/gr.png | models/dio/flag_redux/bos/brotherhood flags.mdl | 2 |
| sh_house | `Color(0, 8, 134)` | phoenix/faction_icons/house.png | models/dio/flag_redux/pre_war/pre-war flags.mdl | 9 |
| sh_legion | `Color(193, 0, 0)` | phoenix/faction_icons/legion.png | models/dio/flag_redux/new_vegas/new vegas flags.mdl | 2 |
| sh_marketdistrict | `Color(255, 255, 0)` | phoenix/faction_icons/cdc.png | models/dio/flag_redux/bos/brotherhood flags.mdl | 2 |
| sh_mef | `Color(255, 222, 40)` | phoenix/faction_icons/mef.png | models/dio/flag_redux/bos/brotherhood flags.mdl | 2 |
| sh_minutemen | `Color(27, 167, 222)` | factionicons/minutemen.png |  |  |
| sh_monsters | `Color(200, 0, 0)` | phoenix/faction_icons/creature.png | models/dio/flag_redux/new_vegas/new vegas flags.mdl | 9 |
| sh_ncr | `Color(193, 154, 107)` | phoenix/faction_icons/ncr.png | models/dio/flag_redux/new_vegas/new vegas flags.mdl | 9 |
| sh_outcasts | `Color(168, 35, 20)` | phoenix/faction_icons/outcast.png | models/dio/flag_redux/bos/brotherhood flags.mdl | 5 |
| sh_robots | `Color(0, 255, 255)` | phoenix/faction_icons/robot.png | models/dio/flag_redux/new_vegas/new vegas flags.mdl | 9 |
| sh_shi | `Color(255, 0, 0)` | phoenix/faction_icons/shi.png | models/dio/flag_redux/fo2/fallout 2 flags.mdl | 6 |
| sh_sok | `Color(220, 20, 60)` | phoenix/faction_icons/vault_34.png | models/dio/flag_redux/bos/brotherhood flags.mdl | 2 |
| sh_supermutant | `Color(31, 146, 0)` | phoenix/faction_icons/supermutant.png |  | false |
| sh_unity | `Color(0, 255, 0)` | phoenix/faction_icons/unity.png | models/dio/flag_redux/bos/brotherhood flags.mdl | 2 |
| sh_vangraffs | `Color(255, 255, 0)` | phoenix/faction_icons/cdc.png | models/dio/flag_redux/bos/brotherhood flags.mdl | 2 |
| sh_vaulttec | `Color(0, 222, 255)` | phoenix/faction_icons/vaulttec.png | models/dio/flag_redux/bos/brotherhood flags.mdl | 2 |
| sh_wastelanders | `Color(75, 75, 75)` | phoenix/faction_icons/wastelander.png |  |  |
| sh_westtek | `Color(255, 255, 0)` | phoenix/faction_icons/westtek.png |  |  |
| sh_zetan | `Color(0, 255, 255)` | phoenix/faction_icons/zeta.png | models/dio/flag_redux/misc/misc flags.mdl | 6 |

## Descriptions

- **Brotherhood of Steel** — A technocratic military order hoarding and controlling pre-War technology to prevent another apocalypse.
- **Boulder Dome** — A group of scientists effected by the New Plague.
- **Chimera** — A group of humans transformed by spore carriers.
- **C.I.T** — Once a university dedicted to teaching the younger generation, now a hub of scientific advancement.
- **Creatures** — Mutated animals and monsters that inhabit the wasteland.
- **Crimson Caravan ©** — A group of traders and merchants operating in the wasteland.
- **Deathclaws** — Mutated Lizards, extremely aggressive and dangerous. (Don't ERP)
- **Desert Rangers** — A group of desert survivalists.
- **Enclave Remnants** — Remnants of the US Government, now operating in the wasteland.
- **Feral** — Crazied and mutated humans that have lost their minds to the wasteland.
- **Fiends** — A ruthless gang of drug dealers and raiders.
- **Followers of the Apocalypse** — A group dedicated to preserving knowledge and helping others.
- **Great Khans ©** — A group of mercenaries and drug dealers.
- **Gunners** — A mercenary organizaton that known for their 'No Prisoners' mindset.
- **Gun Runners ©** — A group dedicated to the trade and manufacture of firearms.
- **House** — An immortal technocrat ruling New Vegas through Securitrons, preserving order, profit, and pre-War vision.
- **Caesar's Legion** — A brutal slaver empire enforcing order through conquest, fear, and absolute obedience under Caesar.
- **Market District ©** — A group of merchants and traders come together as one group.
- **Midwestern Expeditionary Force** — A detechment of BoS soldiers sent from Roger Maxson's founding chapter.
- **Minutemen** — A lost group of wasters.
- **Monsters** — Mutated animals and monsters that inhabit the wasteland.
- **New California Republic** — A democratic republic attempting to rebuild civilization through law, expansion, and military force.
- **The Outcasts** — A splinter of the Brotherhood of Steel, hellbent on unifying the BoS under their ideals.
- **Robots** — Robots created by humans to serve them, rusted and broken down, they now roam the wasteland in search of purpose.
- **Shi** — Chinese people larping as Japanese
- **Sons Of Kaga** — A warband of tech using tribals.
- **Super Mutants** — A group of wasteland Super Mutants
- **Unity Remnants** — Former Master's Army soldiers, now seeking to restore their former glory.
- **Van Graffs ©** — A group of merchants and traders specializing in high-quality Energy Weapons and ammunition.
- **Vault-Tec** — A pre-war company specializing in the construction of underground vaults.
- **Wastelanders** — Unaffiliated survivors navigating the wasteland through grit, adaptability, and sheer will to endure.
- **West Tek** — A pre-war research and development company.
- **ZSD-7** — Zetan Survey Detachment 7, a groups of extraterrestrials sent ahead of the main Zetan invasion force to scout and gather intel civilizations before annihilation.
