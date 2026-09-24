---

Currently working: 176 ranged weapons, 87 melee weapons, the New Vegas player
animation system, bullet tracers, projectiles, and a bootable server.

---

## Index

| Doc | Contents |
|---|---|
| [01-project-overview.md](01-project-overview.md) | Framework choice, source material, directory layout |
| [02-server-setup.md](02-server-setup.md) | server.cfg, tickrate, launching, admin, addon install rules |
| [03-weapons.md](03-weapons.md) | Longsword base, 176 weapons, tracers, scopes, every fix made |
| [04-melee.md](04-melee.md) | Melee Arts 2 system, 87 weapons |
| [05-animations.md](05-animations.md) | NV animation system, body rendering, race proportions |
| [06-compat-layer.md](06-compat-layer.md) | NutScript→Helix shims and the load-order rule |
| [07-gotchas.md](07-gotchas.md) | **Principles** — the six counter-intuitive things about this codebase |
| [08-open-items.md](08-open-items.md) | Known issues, next steps, what's deliberately unfinished |
| [09-content-map.md](09-content-map.md) | All 76 workshop addons: size, Lua count, contents |
| [10-code-map.md](10-code-map.md) | Where every file lives and what it does |
| [11-helix-api.md](11-helix-api.md) | Helix API notes — hook dispatch, char vars, factions |
| [12-commands-and-workflow.md](12-commands-and-workflow.md) | Dev commands, the edit loop, verification snippets |
| [13-troubleshooting.md](13-troubleshooting.md) | **Symptom → cause lookup.** Check here before theorising |
| [14-procedures.md](14-procedures.md) | Step-by-step: add a weapon, addon, faction, projectile, plugin |
| [15-decisions.md](15-decisions.md) | Why things are the way they are — read before "fixing" something odd |
| [16-ui.md](16-ui.md) | The Fallout UI — palette, fonts, the two styling levers, HUD |
| [17-special.md](17-special.md) | S.P.E.C.I.A.L. — attributes, budget, effects, the duplicate-attribute trap |
| [18-races.md](18-races.md) | Races, appearance vars and the customiser — plus which content is missing |
| [19-items.md](19-items.md) | Weapon items, the developer terminal, and what death costs |
| [20-armour.md](20-armour.md) | 685 armour pieces, slots, DR, power armour, stealth |
| [21-hunger.md](21-hunger.md) | Hunger and thirst |
| [22-leveling.md](22-leveling.md) | XP, levels, perks budget, the respec cost |
| [23-looting.md](23-looting.md) | Lootables, loot tables, the tree configurer, the placer tool |
| [24-devtools.md](24-devtools.md) | The developer terminal, reports, and the hooks that do not fire |
| [25-chems.md](25-chems.md) | 64 chems, buffs, addiction, withdrawal and the screen effects |
| [26-factions-races.md](26-factions-races.md) | 45 factions, 44 races, 222 classes, sub-factions, spawns |
| [27-ammo-and-shops.md](27-ammo-and-shops.md) | 34 ammo items, and the faction shop that replaced Business |
| [28-faction-management.md](28-faction-management.md) | /fm and /afm, faction storage, the deployable ghost, and the class-persistence bug |
| [29-materials.md](29-materials.md) | 114 materials, and the item stacking Helix does not have |
| [30-benches.md](30-benches.md) | workbenches: three modes, the creator, and the bench that would have spilled props for ever |
| [31-blueprints.md](31-blueprints.md) | capturing benches, and 259 weapon frames and blueprints |
| [32-rarity.md](32-rarity.md) | crafted weapon quality, the Luck curve, and the coloured borders |
| [33-admin.md](33-admin.md) | usergroups, bans and warnings, deep logging, the admin menu and the bin |
| [34-world.md](34-world.md) | zones, cap stashes, capture points, drop sites, teleport doors — the toolguns |
| [35-orbital.md](35-orbital.md) | orbital drops — the beacon, the craft, the container |
| [36-pk.md](36-pk.md) | player killing — the mark, what it costs, the head |
| [37-restraints.md](37-restraints.md) | the hold-E menu, zip ties and cuffs, breaching charges, slave collars |
| [38-plants.md](38-plants.md) | harvestable plants, the twenty plant items and their effects, seeds |
| [39-mugging-and-farming.md](39-mugging-and-farming.md) | robbing the restrained, and crop plots that grow what the seeds are for |
| [40-mining.md](40-mining.md) | ore nodes, the soft spot, the node tool and the editable ore list |
| [41-crosshair-stash-and-modulators.md](41-crosshair-stash-and-modulators.md) | the crosshair and hit markers, personal stashes, the trade-up bench and armour modulators |
| [42-karma.md](42-karma.md) | good and bad karma, the fifty titles, faction bands and where karma comes from |
| [43-injectors-and-odds.md](43-injectors-and-odds.md) | race injectors, third person, container sizes, and the smaller fixes of that batch |
| [44-live-editor.md](44-live-editor.md) | `/liveedit` - changing weapons, armour, chems, races and factions without a restart |
| [45-conflict.md](45-conflict.md) | lockpicking, ambushes, raids, hostilities and wars |
| [46-implants-and-audit.md](46-implants-and-audit.md) | implants, food/water/rad tuning, and `/audit` |
| [47-chat-tickets-and-gore.md](47-chat-tickets-and-gore.md) | admin chat, the ticket queue, dismemberment and `/advert` |
| [48-squads.md](48-squads.md) | squads: ranks, invitations by hold-E, the HUD list and markers, `/sq`, and the force commands |
| [49-identification.md](49-identification.md) | citizenship and religion cards worn over the head, Phoenix's thirteen |
| [50-black-market.md](50-black-market.md) | the black market terminal: listings, fees, buying, claiming, logs |
| [51-radio-and-music.md](51-radio-and-music.md) | the character menu's music player, the RADIO tab and its stations, the PERKS tab |
| [52-perks.md](52-perks.md) | what Phoenix's perk system is, read before building ours |
| [53-vehicles.md](53-vehicles.md) | sixteen LVS vehicles, the deploy items, ownership, packing up, despawn and refunds |
| [54-npcs.md](54-npcs.md) | NPC presets in the schema's armour and guns, spawner pods that wake and sleep, the VJ weapon generator |
| [reference/00_README.md](reference/00_README.md) | Mined Phoenix data: factions, races, weapons, configs |

## Tools — `_docs/tools/`

| Script | Use |
|---|---|
| `luacheck.py <dir>` | Lua **tokenizer** — brackets, strings, comments, block structure, `goto continue`, and `obj:method` used as a value, with line numbers. **Run after every edit**; it is the only syntax check available without booting |
| `resolve_asset.py <paths>` | Does an asset exist, and which addon provides it |
| `vmtcheck.py <dir> [--fix]` | Finds and repairs malformed `.vmt` files. Run after installing or updating any content addon |
| `luaglobals.py <dir>` | Finds reads of names never bound in the file — the **nil-global** class `luacheck.py` cannot see, because the file still parses. Re-learn after adding globals: `--learn <dirs>` |
| `fo_phoenix_probe.lua` | **Clientside**, for running on somebody else's server. Copy to `garrysmod/lua/autorun/client/`, stand next to a body and run `fo_probe`: dumps bones, bodygroups, materials and parts to `data/fo_probe.txt`. Read-only |
| `content_map.py` | Regenerates `09-content-map.md` |
| `mdlseq.py [--match \| --act <model> [name...]]` | Reads the sequence names out of a `.mdl`, following `$includemodel`, and scores every animation class against every race's model; `--act` prints each sequence's activity and frame count. **The answer to "why is this race T-posing"** |
| `genraces.py` / `genfactions.py` / `genclasses.py` / `genchems.py` / `genammo.py` / `genmaterials.py` | Regenerate the races, factions, classes, chems and ammo from the rosters beside them. Each refuses to write a roster with a fault in it |
| `genplants.py` | Regenerates the 20 plant items and 17 seed items from the data table at the top of it. See `38-plants.md` |
| `geninjectors.py` | Regenerates the 88 race injector items from the race roster. See `43-injectors-and-odds.md` |

---.
