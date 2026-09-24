# 09 - Content addon map

The extracted workshop addons in `phoenixsourceaddons/`. This is the asset
source for everything; when a model or sound is missing this table is where to
look before searching the whole tree.

**The `lua` column is the safety-critical one.** Never junction an addon with
Lua unless its dependencies are installed too - see `02-server-setup.md`.
If you need one asset from a Lua-bearing addon, copy that asset instead.

Regenerate this table with `tools/content_map.py` if the folder changes.

| Addon | GB | lua | contains | installed |
|---|---|---|---|---|
| `3d2d_textscreens_109643223` | 0.00 | **6** | - |  |
| `advanced_duplicator_2_773402917` | 0.00 | **16** | - |  |
| `af_additional_weapons_models_3504631185` | 1.03 | 0 | materials,models,sound | yes |
| `af_clothes_pack_1_2191118853` | 0.11 | 0 | materials,models |  |
| `af_content_pack_10_2596619496` | 0.07 | 0 | materials,sound |  |
| `af_content_pack_12_2840787543` | 0.03 | 0 | materials,particles,sound |  |
| `af_content_pack_13_2844162167` | 0.37 | 0 | materials |  |
| `af_content_pack_14_3036523495` | 0.03 | 0 | sound |  |
| `af_content_pack_15_3041037276` | 0.95 | 0 | materials,models,sound | yes |
| `af_content_pack_17_3307469557` | 0.03 | 0 | materials,models,sound |  |
| `af_content_pack_18_3358609251` | 0.34 | 0 | materials,models | yes |
| `af_content_pack_19_3369199489` | 0.61 | 0 | materials,models,sound | yes |
| `af_content_pack_1_2182580313` | 1.25 | 0 | materials,models,sound | yes |
| `af_content_pack_2_2185895884` | 0.87 | 0 | sound |  |
| `af_content_pack_4_2205878880` | 0.94 | 0 | materials,models,sound | yes |
| `af_content_pack_5_2277098363` | 0.02 | 0 | materials,models,sound | yes |
| `af_content_pack_6_2289559348` | 0.06 | 0 | materials,models | yes |
| `af_content_pack_7_2427672337` | 0.34 | 0 | materials,models,sound | yes |
| `af_content_pack_8_2545487375` | 0.19 | 0 | MAP,materials,sound |  |
| `af_content_pack_9_2777220342` | 1.51 | 0 | materials,models | yes |
| `af_extra_content_3342543106` | 1.08 | 0 | materials,models,sound | yes |
| `af_pa_assets_3217826764` | 0.18 | 0 | materials,models | yes |
| `content_pack_16_3087636360` | 0.20 | 0 | materials,models |  |
| `divide_more_map_stuff_3400469270` | 0.17 | 0 | MAP,materials |  |
| `divide_more_map_stuff_mats_2_3400467134` | 0.40 | 0 | materials |  |
| `divide_more_map_stuff_mats_3400463037` | 0.81 | 0 | materials |  |
| `divide_more_map_stuff_models_3400472459` | 0.36 | 0 | models |  |
| `divide_trailblaze_1_3665625103` | 0.40 | 0 | materials,models,particles,sound |  |
| `divide_trailblaze_2_3665637618` | 0.36 | 0 | materials |  |
| `extended_spawnmenu_104603291` | 0.00 | **2** | - |  |
| `fallout_a_prop_pack_of_two_wastelands_2974533993` | 1.02 | 0 | materials,models | yes |
| `fallout_flags_redux_2642656520` | 0.03 | 0 | materials,models |  |
| `fallout_prop_pack_3199172138` | 0.62 | **1** | materials,models |  |
| `fallout_snpcs_remastered_2600347219` | 2.69 | **380** | materials,models,particles,sound | yes |
| `image_tool_your_pictures_in_the_world_2685051966` | 0.00 | **10** | - |  |
| `improved_stacker_264467687` | 0.00 | **8** | - |  |
| `lvs_cars_3027255911` | 0.12 | **56** | materials,models |  |
| `lvs_framework_2912816023` | 0.30 | **332** | materials,models,sound |  |
| `lvs_helicopters_2922255746` | 0.01 | **11** | materials,models |  |
| `media_player_redux_3001397905` | 0.00 | **130** | materials,models |  |
| `medical_gtav_props_pack_2274336307` | 0.02 | 0 | materials,models |  |
| `melee_arts_2_1825542758` | 0.08 | **51** | materials,models,sound |  |
| `no_collide_everything_105955548` | 0.00 | **1** | - |  |
| `nutscript_content_1355625344` | 0.00 | 0 | - |  |
| `pac3_104691717` | 0.01 | **195** | materials,models |  |
| `pcasino_content_2228228831` | 0.22 | 0 | materials,models,sound |  |
| `permaprops_220336312` | 0.00 | **11** | - |  |
| `phoenix_anims_3593569052` | 0.01 | 0 | models | yes |
| `phoenix_armors_3522721568` | 2.23 | 0 | materials,models | yes |
| `phoenix_contributor_content_3504308895` | 0.37 | 0 | materials,models,sound | yes |
| `phoenix_custom_orders_3679448229` | 0.06 | 0 | materials,models | yes |
| `phoenix_dickmosi_stuff_3614856486` | 1.58 | 0 | materials,models,sound | yes |
| `phoenix_drop_models_3728469287` | 0.32 | 0 | materials,models | yes |
| `phoenix_faction_icons_3520608245` | 0.00 | 0 | - | yes |
| `phoenix_hud_content_3498192410` | 0.02 | 0 | materials | yes |
| `phoenix_map_materials_1_3574782143` | 2.74 | 0 | materials |  |
| `phoenix_map_models_1_3574778137` | 1.42 | 0 | models |  |
| `phoenix_map_phoenix_v3_3623162735` | 0.13 | 0 | MAP,particles |  |
| `phoenix_mining_content_3532494780` | 0.09 | 0 | materials,models,particles,sound | yes |
| `phoenix_misc_content_3559547707` | 0.02 | 0 | materials,models,sound |  |
| `phoenix_player_content_3448525969` | 0.09 | 0 | materials,models,sound | yes |
| `phoenix_sound_content_2_3530674528` | 1.00 | **1** | sound |  |
| `phoenix_sound_content_3446558725` | 1.73 | 0 | sound | yes |
| `phoenix_vehicle_content_3495732900` | 0.41 | 0 | materials,models,sound |  |
| `phoenix_weapon_models_3647084547` | 0.27 | 0 | materials,models,particles,sound | yes |
| `phoenix_weapons_extra_3507971036` | 1.92 | 0 | materials,models,sound | yes |
| `phoenix_widowz_content_3791533961` | 1.16 | **1** | materials,models |  |
| `placeable_particle_effects_1551310214` | 0.16 | **113** | materials,models,particles |  |
| `precision_alignment_457478322` | 0.00 | **6** | - |  |
| `precision_tool_104482086` | 0.00 | **1** | - |  |
| `resurgence_misc_2_1999953274` | 0.88 | 0 | materials,models,particles,sound | yes |
| `serverguard_content_685130934` | 0.00 | 0 | - |  |
| `simple_thirdperson_207948202` | 0.00 | **1** | - |  |
| `smartsnap_104815552` | 0.00 | **1** | - |  |
| `the_sit_anywhere_script_108176967` | 0.00 | **6** | - |  |
| `vj_base_131759821` | 0.08 | **96** | materials,models,particles,sound | yes |

**Total: 34.5 GB across 76 addons. 24 carry Lua.**
