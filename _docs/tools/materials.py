# The materials roster.
#
# (id, name, category, model, stackable, w, h, tint, description[, bodygroup])
#
#   stackable  whether two of them merge into one slot. Five to a stack
#              unless the base says otherwise - `libs/sh_stack.lua`.
#              FALSE is not laziness: a bar of steel is a quantity of a
#              substance and five in a slot is the truth, while an
#              Enclave access pad is one specific object and two of them
#              sharing a slot would be a lie about what is in the room.
#   tint       a colour for the corner marker, for items that share a
#              model. Thirty-one component models cover eighty-odd
#              materials, so the ores all look alike and a bronze bar
#              uses the copper model. Same answer as the chems.
#   bodygroup  OPTIONAL, and only the ores use it: which option of
#              bodygroup 0 the model shows. Helix has no bodygroup
#              support of its own - `libs/sh_itembodygroup.lua` adds it
#              for the dropped entity and the inventory icon - and the
#              seven ores are one model with five looks on it.
#
# Phoenix's whole `items/junk` folder is here, names and models carried
# across, plus the components their roster misses that the model pack
# already ships - aluminium, asbestos, bone, concrete, cork, fertiliser,
# fibre optics and lead among them - and the access pads.
#
# FOUR OF THEIR MODELS ARE NOT INSTALLED HERE and are substituted rather
# than dropped: their blueprint paper, an Anchorage barrel and two gore
# props. The generator checks every path against disk and refuses to
# write a missing one.
#
# THE ORES USE THE REAL MODEL AGAIN. `zrms_resource.mdl` was one of the
# substitutions, because `phoenix_mining_content` was not installed; the
# mining system needed that addon, so it is, and the ores are back on the
# model Phoenix use - one model, bodygroups 0 to 4.

MATERIALS = [

    # ---- Materials ---------------------------------------------------------
    ("mat_acid", "Bottle of Acid", "Materials",
     "models/mosi/fallout4/props/junk/components/acid.mdl",
     True, 1, 1, None,
     "Used as a crafting material."),
    ("mat_adhesive", "Bottle of Adhesive", "Materials",
     "models/mosi/fallout4/props/junk/components/adhesive.mdl",
     True, 1, 1, None,
     "Used as a crafting material."),
    ("mat_aluminium", "Aluminium", "Materials",
     "models/mosi/fallout4/props/junk/components/aluminum.mdl",
     True, 1, 1, None,
     "Light, and it does not rust. Half the pre-War world was made "
     "of it."),
    ("mat_antiseptic", "Antiseptic", "Materials",
     "models/mosi/fallout4/props/junk/components/antiseptic.mdl",
     True, 1, 1, None,
     "A bottle of antiseptic. What stands between a cut and a fever."),
    ("mat_asbestos", "Asbestos", "Materials",
     "models/mosi/fallout4/props/junk/components/asbestos.mdl",
     True, 1, 1, None,
     "Fireproof, and the reason a lot of pre-War builders died "
     "early."),
    ("mat_ballistic_fiber", "Ballistic Fiber", "Materials",
     "models/mosi/fallout4/props/junk/components/ballisticfiber.mdl",
     True, 1, 1, None,
     "Used as a crafting material."),
    ("mat_barbronze", "Bronze Bar", "Materials",
     "models/mosi/fallout4/props/junk/components/copper.mdl",
     True, 1, 1, "184, 115, 51",
     "A bar of bronze, durable and resistant to corrosion."),
    ("mat_bargold", "Gold Bar", "Materials",
     "models/mosi/fallout4/props/junk/components/gold.mdl",
     True, 1, 1, "212, 175, 55",
     "A bar of gold, valuable and shiny."),
    ("mat_bariron", "Iron Bar", "Materials",
     "models/mosi/fallout4/props/junk/components/steel.mdl",
     True, 1, 1, "120, 120, 128",
     "A bar of iron, strong and durable."),
    ("mat_barsaturnite", "Saturnite Bar", "Materials",
     "models/mosi/fallout4/props/junk/components/silver.mdl",
     True, 1, 1, "150, 200, 210",
     "A bar of saturnite, a polymer alloy that was developed at "
     "BigMT."),
    ("mat_barsilver", "Silver Bar", "Materials",
     "models/mosi/fallout4/props/junk/components/silver.mdl",
     True, 1, 1, "192, 192, 200",
     "A bar of gold, valuable and shiny."),
    ("mat_baruranium", "Uranium Bar", "Materials",
     "models/mosi/fallout4/props/junk/components/silver.mdl",
     True, 1, 1, "120, 200, 80",
     "A bar of uranium, highly radioactive and valuable."),
    ("mat_battery", "Makeshift Battery", "Materials",
     "models/mosi/fallout4/props/junk/makeshiftbattery.mdl",
     True, 1, 1, None,
     "Somebody's idea of a battery. It holds a charge, mostly."),
    ("mat_bloatflygland", "Bloatfly Gland", "Materials",
     "models/mosi/fallout4/props/junk/bloatflygland.mdl",
     True, 1, 1, None,
     "A bloatfly gland, still wet. The base of half the chems in the "
     "Mojave."),
    ("mat_bone", "Bone", "Materials",
     "models/mosi/fallout4/props/junk/components/bone.mdl",
     True, 1, 1, None,
     "Bone, cleaned and dried. Nobody asks whose."),
    ("mat_ceramic", "Ceramic", "Materials",
     "models/mosi/fallout4/props/junk/components/ceramic.mdl",
     True, 1, 1, None,
     "Used as a crafting material."),
    ("mat_circuitboard", "Military Circuit Board", "Materials",
     "models/mosi/fallout4/props/junk/circuitboard.mdl",
     True, 1, 1, None,
     "A hardened board out of something military. Worth more than "
     "the sum of its parts."),
    ("mat_circuitry", "Circuitry", "Materials",
     "models/mosi/fallout4/props/junk/components/circuitry.mdl",
     True, 1, 1, None,
     "Used as a crafting material."),
    ("mat_cloth", "Cloth", "Materials",
     "models/mosi/fallout4/props/junk/components/cloth.mdl",
     True, 1, 1, None,
     "Used as a crafting material."),
    ("mat_concrete", "Concrete", "Materials",
     "models/mosi/fallout4/props/junk/components/concrete.mdl",
     True, 1, 1, None,
     "A bag of dry mix. Heavy, and the only thing that holds a wall "
     "up."),
    ("mat_coolant", "Coolant", "Materials",
     "models/mosi/fallout4/props/junk/coolant.mdl",
     True, 1, 1, None,
     "A canister of coolant. Keeps a reactor from becoming a crater."),
    ("mat_copper", "Copper", "Materials",
     "models/mosi/fallout4/props/junk/components/copper.mdl",
     True, 1, 1, None,
     "Used as a crafting material."),
    ("mat_cork", "Cork", "Materials",
     "models/mosi/fallout4/props/junk/components/cork.mdl",
     True, 1, 1, None,
     "Cork sheeting. Seals a bottle, quietens a room."),
    ("mat_cottonyarn", "Cotton Yarn", "Materials",
     "models/mosi/fallout4/props/junk/cottonyarn.mdl",
     True, 1, 1, None,
     "A bundle of cotton yarn. Cloth, given a loom and a week."),
    ("mat_crudeoil", "Barrel Of Crude Oil", "Materials",
     "models/mosi/fallout4/props/fortifications/metalbarrel01.mdl",
     True, 2, 2, None,
     "Used as a crafting material."),
    ("mat_crystal", "Crystal", "Materials",
     "models/mosi/fallout4/props/junk/components/crystal.mdl",
     True, 1, 1, None,
     "Used as a crafting material."),
    ("mat_deathclawhide", "Deathclaw Hide", "Materials",
     "models/mosi/fallout4/props/junk/deathclaw_hide.mdl",
     True, 1, 1, "180, 60, 40",
     "The hide off a deathclaw. Nothing man-made stops a bullet "
     "better, and getting it cost somebody something."),
    ("mat_duct_tape", "Duct Tape", "Materials",
     "models/mosi/fallout4/props/junk/ducttape.mdl",
     True, 1, 1, None,
     "Used as a crafting material."),
    ("mat_egg", "Egg", "Materials",
     "models/models/fallout/mantisegg.mdl",
     False, 1, 1, None,
     "Egg."),
    ("mat_fertilizer", "Fertiliser", "Materials",
     "models/mosi/fallout4/props/junk/components/fertilizer.mdl",
     True, 1, 1, None,
     "A sack of fertiliser. Grows food, and makes something else "
     "entirely if you know the recipe."),
    ("mat_fiberglass", "Fiberglass", "Materials",
     "models/mosi/fallout4/props/junk/components/fiberglass.mdl",
     True, 1, 1, None,
     "Used as a crafting material."),
    ("mat_fiberoptics", "Fibre Optics", "Materials",
     "models/mosi/fallout4/props/junk/components/fiberoptic.mdl",
     True, 1, 1, None,
     "A spool of fibre optic cable. Pre-War, and nobody is making "
     "more."),
    ("mat_fuse", "Fuse", "Materials",
     "models/mosi/fallout4/props/junk/fuse.mdl",
     True, 1, 1, None,
     "A ceramic fuse. The cheapest part of anything, and the one "
     "that goes."),
    ("mat_gears", "Box of Gears", "Materials",
     "models/mosi/fallout4/props/junk/components/gears.mdl",
     True, 1, 1, None,
     "Used as a crafting material."),
    ("mat_glass", "Glass", "Materials",
     "models/mosi/fallout4/props/junk/components/glass.mdl",
     True, 1, 1, None,
     "Used as a crafting material."),
    ("mat_gold", "Gold", "Materials",
     "models/mosi/fallout4/props/junk/components/gold.mdl",
     True, 1, 1, None,
     "Used as a crafting material."),
    ("mat_hide", "Tanned Hide", "Materials",
     "models/mosi/fallout4/props/junk/hide.mdl",
     True, 1, 1, None,
     "A tanned hide. Leather, once somebody has cut it to shape."),
    ("mat_highqualframe", "High Quality Frame", "Materials",
     "models/mosi/fallout4/props/junk/modcrate.mdl",
     True, 1, 1, None,
     "A material used for crafting higher tier armaments."),
    ("mat_lead", "Lead", "Materials",
     "models/mosi/fallout4/props/junk/components/lead.mdl",
     True, 1, 1, "90, 90, 110",
     "A lump of lead. Soft, heavy, and it stops what comes through a "
     "wall."),
    ("mat_leather", "Leather", "Materials",
     "models/mosi/fallout4/props/junk/components/leather.mdl",
     True, 1, 1, None,
     "Used as a crafting material."),
    ("mat_magnet", "High-Powered Magnet", "Materials",
     "models/mosi/fallout4/props/junk/highpoweredmagnet.mdl",
     True, 1, 1, None,
     "A magnet strong enough to be a nuisance in a pocket full of "
     "caps."),
    ("mat_moleratteeth", "Molerat Teeth", "Materials",
     "models/mosi/fallout4/props/junk/moleratteeth.mdl",
     True, 1, 1, None,
     "A handful of molerat teeth. Somebody buys these."),
    ("mat_nuclear", "Nuclear Material", "Materials",
     "models/mosi/fallout4/props/junk/components/nuclear.mdl",
     True, 1, 1, None,
     "Used as a crafting material."),
    ("mat_oil", "Bottle of Oil", "Materials",
     "models/mosi/fallout4/props/junk/components/oil.mdl",
     True, 1, 1, None,
     "Used as a crafting material."),
    ("mat_orebronze", "Bronze Ore", "Materials",
     "models/zerochain/props_mining/zrms_resource.mdl",
     True, 1, 1, "184, 115, 51",
     "A chunk of bronze ore", 1),
    ("mat_orecoal", "Coal Ore", "Materials",
     "models/zerochain/props_mining/zrms_resource.mdl",
     True, 1, 1, "40, 40, 44",
     "A chunk of coal ore", 4),
    ("mat_oregold", "Gold Ore", "Materials",
     "models/zerochain/props_mining/zrms_resource.mdl",
     True, 1, 1, "212, 175, 55",
     "A chunk of gold ore", 3),
    ("mat_oreiron", "Iron Ore", "Materials",
     "models/zerochain/props_mining/zrms_resource.mdl",
     True, 1, 1, "120, 120, 128",
     "A chunk of iron ore", 0),
    ("mat_oresaturnite", "Saturnite Ore", "Materials",
     "models/zerochain/props_mining/zrms_resource.mdl",
     True, 1, 1, "150, 200, 210",
     "A chunk of saturnite ore", 2),
    ("mat_oresilver", "Silver Ore", "Materials",
     "models/zerochain/props_mining/zrms_resource.mdl",
     True, 1, 1, "192, 192, 200",
     "A chunk of silver ore", 2),
    ("mat_oreuranium", "Uranium Ore", "Materials",
     "models/zerochain/props_mining/zrms_resource.mdl",
     True, 1, 1, "120, 200, 80",
     "A chunk of uranium ore", 3),
    ("mat_plastic", "Plastic", "Materials",
     "models/mosi/fallout4/props/junk/components/plastic.mdl",
     True, 1, 1, None,
     "Used as a crafting material."),
    ("mat_prewarmoney", "Pre-War Money", "Materials",
     "models/mosi/fallout4/props/junk/prewarmoney.mdl",
     True, 1, 1, None,
     "A bundle of pre-War banknotes. Worthless as money, and "
     "excellent as paper."),
    ("mat_processedoil", "Barrel Of Proccessed Oil", "Materials",
     "models/models/fallout/dlcbarrel.mdl",
     True, 2, 2, None,
     "Used as a crafting material."),
    ("mat_relaycoil", "Relay Coil", "Materials",
     "models/mosi/fallout4/props/junk/relaycoil.mdl",
     True, 1, 1, None,
     "A relay coil. Half of what makes a teleporter, if you believe "
     "the Institute has one."),
    ("mat_rubber", "Rubber", "Materials",
     "models/mosi/fallout4/props/junk/components/rubber.mdl",
     True, 1, 1, None,
     "Used as a crafting material."),
    ("mat_scrapelectronics", "Scrap Electronics", "Materials",
     "models/roadkill/fallout/clutter/junk/scrapelectronic.mdl",
     True, 1, 1, None,
     "Used as a crafting material."),
    ("mat_scrapmetal", "Scrap Metal", "Materials",
     "models/roadkill/fallout/clutter/junk/scrapmetal.mdl",
     True, 1, 1, None,
     "Used as a crafting material."),
    ("mat_screws", "Box of Screws", "Materials",
     "models/mosi/fallout4/props/junk/components/screws.mdl",
     True, 1, 1, None,
     "Used as a crafting material."),
    ("mat_sensormodule", "Sensor Module", "Materials",
     "models/mosi/fallout4/props/junk/sensormodule.mdl",
     True, 1, 1, None,
     "A sensor module out of a robot. Still warm, occasionally."),
    ("mat_silver", "Silver", "Materials",
     "models/mosi/fallout4/props/junk/components/silver.mdl",
     True, 1, 1, None,
     "Used as a crafting material."),
    ("mat_springs", "Box of Springs", "Materials",
     "models/mosi/fallout4/props/junk/components/springs.mdl",
     True, 1, 1, None,
     "Used as a crafting material."),
    ("mat_steel", "Steel", "Materials",
     "models/mosi/fallout4/props/junk/components/steel.mdl",
     True, 1, 1, None,
     "Used as a crafting material."),
    ("mat_technical_documents", "Technical Documents", "Materials",
     "models/mosi/fallout4/props/junk/technicaldocument.mdl",
     True, 1, 1, "80, 160, 220",
     "Used as a crafting material."),
    ("mat_turpentine", "Turpentine", "Materials",
     "models/mosi/fallout4/props/junk/turpentine.mdl",
     True, 1, 1, None,
     "A can of turpentine. Thins paint, strips varnish, ruins lungs."),
    ("mat_vacuumtube", "Vacuum Tube", "Materials",
     "models/mosi/fallout4/props/junk/vacuumtube.mdl",
     True, 1, 1, None,
     "A glass valve. The reason pre-War computers are the size of a "
     "room and still work."),
    ("mat_wonderglue", "Wonderglue", "Materials",
     "models/mosi/fallout4/props/junk/wonderglue.mdl",
     True, 1, 1, None,
     "A tube of Wonderglue. Adhesive, if you are willing to boil it "
     "down."),
    ("mat_wood", "Wood", "Materials",
     "models/mosi/fallout4/props/junk/components/wood.mdl",
     True, 1, 1, None,
     "Used as a crafting material."),

    # ---- Junk --------------------------------------------------------------
    ("equipment_c4", "Timed C4 Explosive", "Junk",
     "models/weapons/w_c4_planted.mdl",
     False, 1, 1, None,
     "A powerful explosive that can be set to detonate after a "
     "certain amount of time."),
    ("equipment_lockpick", "Bobby Pin", "Junk",
     "models/mosi/fnv/props/gore/robobit05.mdl",
     True, 1, 1, None,
     "A Bobby Pin used to pick open locks. Can be used to pick open "
     "doors, workbenches and containers."),
    #  NO FUSION CORE HERE. It is a hand-written item at
    #  `items/sh_junk_fusioncore.lua`, because it carries behaviour a roster
    #  entry cannot express: the `isFusionCore` marker that
    #  `ix.armor.EquipFusionCore` searches for, a `charge` percentage, and a
    #  description that reads the charge off the instance.
    #
    #  It was in this roster as well, and both files register as
    #  `junk_fusioncore` - `ix.item.Load` takes the uniqueID from the filename
    #  after `sh_`. `LoadFromDir` loads folders first and root files last, and
    #  `ix.item.Register` REUSES the table for an id it has seen, so the two
    #  definitions merged into a hybrid nobody wrote: the root file's fields on
    #  top of `base_material`, which the root file never asked for. The check
    #  in `genmaterials.py` refuses that now.
    ("requisition_resource", "Requisition Resource", "Junk",
     "models/models/bos/militarycrate.mdl",
     True, 2, 2, "120, 200, 120",
     "A crate full of resources, commonly used in trading with the "
     "larger wasteland or back to homebase."),
    ("sabotage_case", "Sabotage Case", "Junk",
     "models/mosi/fnv/props/junk/radiationkit.mdl",
     True, 1, 1, None,
     "Turn these in to redeem for various kinds of sabotages (custom "
     "ones included): poisoning a water well, adding a rad zone "
     "somewhere (within building rules), converting to enclave "
     "access pads, and any custom ones you'd like (create ticket in "
     "main discord). These can also reverse the effects."),

    # ---- Valuables ---------------------------------------------------------
    ("loot_fevcan", "FEV Canister", "Valuables",
     "models/models/enclave/fevcanister.mdl",
     True, 1, 1, None,
     "A dangerous device if tampered with. Can be investigated "
     "further with research."),
    ("loot_geck", "G.E.C.K", "Valuables",
     "models/models/fallout/geck.mdl",
     True, 1, 1, None,
     "Garden of Eden creation kit. Advanced terraforming tool that "
     "can be used in research."),
    ("loot_myssyring", "Mysterious Syringe", "Valuables",
     "models/mosi/fallout4/props/aid/mysteriousserum.mdl",
     True, 1, 1, None,
     "Filled with a potent and unknown chemical. Can be investigated "
     "further with research"),
    ("loot_platfragment", "Platinum Chip Fragment", "Valuables",
     "models/models/fallout/platinumchip.mdl",
     True, 1, 1, "200, 80, 80",
     "A fragment of the platinum chip, House has been desperately "
     "searching for this. 1/3 Pieces"),
    ("loot_platinumchip", "Platinum Chip", "Valuables",
     "models/models/fallout/platinumchip.mdl",
     True, 1, 1, "80, 160, 220",
     "The completed platinum chip."),
    ("loot_sevear", "Severed Ear", "Valuables",
     "models/mosi/fnv/props/gore/meatbit02.mdl",
     True, 1, 1, None,
     "Severed ear of a do-gooder. Can be sold."),
    ("loot_sevfinger", "Severed Finger", "Valuables",
     "models/mosi/fnv/props/gore/meatbit01.mdl",
     True, 1, 1, None,
     "Severed finger of a disreputable character. Can be sold."),
    ("loot_snowglobe_bigmt", "Snow Globe - Big MT", "Valuables",
     "models/models/fallout/snowglobebigmt.mdl",
     False, 1, 1, None,
     "A Pre-War artifact, a Snow Globe with a miniature of the Big "
     "MT inside."),
    ("loot_snowglobe_goodsprings", "Snow Globe - Goodsprings", "Valuables",
     "models/models/fallout/snowglobe_goodsprings.mdl",
     False, 1, 1, None,
     "A Pre-War artifact, a Snow Globe with a miniature of "
     "Goodsprings inside."),
    ("loot_snowglobe_hooverdam", "Snow Globe - Hoover Dam", "Valuables",
     "models/models/fallout/snowglobe_hooverdam.mdl",
     False, 1, 1, None,
     "A Pre-War artifact, a Snow Globe with a miniature of the "
     "Hoover Dam inside."),
    ("loot_snowglobe_lonesomeroad", "Snow Globe - Lonesome Road", "Valuables",
     "models/models/fallout/snowglobelonesomerd.mdl",
     False, 1, 1, None,
     "A Pre-War artifact, a Snow Globe with a miniature of the "
     "Lonesome Road inside."),
    ("loot_snowglobe_mormonfort", "Snow Globe - Mormon Fort", "Valuables",
     "models/models/fallout/snowglobe_mormon.mdl",
     False, 1, 1, None,
     "A Pre-War artifact, a Snow Globe with a miniature of the "
     "Mormon Fort inside."),
    ("loot_snowglobe_mtcharleston", "Snow Globe - Mt. Charleston", "Valuables",
     "models/models/fallout/snowglobe_mtcharleston.mdl",
     False, 1, 1, None,
     "A Pre-War artifact, a Snow Globe with a miniature of Mt. "
     "Charleston inside."),
    ("loot_snowglobe_nellisafb", "Snow Globe - Nellis Air Force Base", "Valuables",
     "models/models/fallout/snowglobes_nelis.mdl",
     False, 1, 1, None,
     "A Pre-War artifact, a Snow Globe with a miniature of Nellis "
     "Air Force Base inside."),
    ("loot_snowglobe_sierramadre", "Snow Globe - Sierra Madre", "Valuables",
     "models/models/fallout/snowglobesierramadre.mdl",
     False, 1, 1, None,
     "A Pre-War artifact, a Snow Globe with a miniature of the "
     "Sierra Madre inside."),
    ("loot_snowglobe_testsite", "Snow Globe - Test Site", "Valuables",
     "models/models/fallout/snowglobes_testsite.mdl",
     False, 1, 1, None,
     "A Pre-War artifact, a Snow Globe with a miniature of a Nuclear "
     "Test Site inside."),
    ("loot_snowglobe_thestrip", "Snow Globe - The Strip", "Valuables",
     "models/models/fallout/snowglobes_thestrip.mdl",
     False, 1, 1, None,
     "A Pre-War artifact, a Snow Globe with a miniature of The Strip "
     "inside."),
    ("loot_snowglobe_zionnationalpark", "Snow Globe - Zion National Park", "Valuables",
     "models/models/fallout/snowglobezion.mdl",
     False, 1, 1, None,
     "A Pre-War artifact, a Snow Globe with a miniature of the Zion "
     "National Park inside."),

    # ---- Schematics --------------------------------------------------------
    ("armor_mod_insertion_schematics", "Armor Mod-Insertion Schematics", "Schematics",
     "models/mosi/fallout4/props/junk/blueprint.mdl",
     False, 1, 1, "200, 80, 80",
     "Obtain and submit this AND the Building Framework to the "
     "*upper skygods* to have these items redeemed."),
    ("black_market_vendor_schematics", "Black Market Vendor Schematics", "Schematics",
     "models/mosi/fallout4/props/junk/schematic.mdl",
     False, 1, 1, "200, 80, 80",
     "Obtain and submit this AND the Building Framework to the "
     "*upper skygods* to have these items redeemed."),
    ("blueprint_vendor_schematics", "Blueprint Vendor Schematics", "Schematics",
     "models/mosi/fallout4/props/junk/folder.mdl",
     False, 1, 1, "200, 80, 80",
     "Obtain and submit this AND the Building Framework to the "
     "*upper skygods* to have these items redeemed."),
    ("building_framework", "Building Framework", "Schematics",
     "models/models/bos/militarycrate.mdl",
     False, 1, 1, "200, 80, 80",
     "Obtain and submit this AND any schematic to the *upper "
     "skygods* to have these items redeemed"),
    ("field_data", "Field Data", "Schematics",
     "models/mosi/fallout4/props/junk/clipboard.mdl",
     False, 1, 1, "200, 80, 80",
     "Research Boost item made by the FoA, check rules for "
     "specifics."),
    ("frame_vendor_schematics", "Frame Vendor Schematics", "Schematics",
     "models/mosi/fallout4/props/junk/technicaldocument.mdl",
     False, 1, 1, "200, 80, 80",
     "Obtain and submit this AND the Building Framework to the "
     "*upper skygods* to have these items redeemed."),
    ("fusion_generator_schematics", "Fusion Generator Schematics", "Schematics",
     "models/mosi/fallout4/props/junk/blueprint.mdl",
     False, 1, 1, "80, 160, 220",
     "Obtain and submit this AND the Building Framework to the "
     "*upper skygods* to have these items redeemed."),
    ("junk_silo_map", "Map To A Nuclear Silo", "Schematics",
     "models/mosi/fallout4/props/junk/schematic.mdl",
     False, 1, 1, "80, 160, 220",
     "Now all you need is to find a Caravan to take you to this "
     "place, something tells you this is valuable beyond all "
     "measure. [CONTACT THE SKY GODS BEFORE USING THIS OR IT WILL "
     "NOT WORK AND WILL NOT BE REFUNDED]"),
    ("melee_vendor_schematics", "Melee Vendor Schematics", "Schematics",
     "models/mosi/fallout4/props/junk/folder.mdl",
     False, 1, 1, "80, 160, 220",
     "Obtain and submit this AND the Building Framework to the "
     "*upper skygods* to have these items redeemed."),
    ("mines_schematics", "Mines Schematics", "Schematics",
     "models/mosi/fallout4/props/junk/clipboard.mdl",
     False, 1, 1, "80, 160, 220",
     "Obtain and submit this AND the Building Framework to the "
     "*upper skygods* to have these items redeemed."),
    ("oil_derrick_schematics", "Oil Derrick Schematics", "Schematics",
     "models/mosi/fallout4/props/junk/technicaldocument.mdl",
     False, 1, 1, "120, 200, 120",
     "Obtain and submit this AND the Building Framework to the "
     "*upper skygods* to have these items redeemed."),
    ("oil_refinery_schematics", "Oil Refinery Schematics", "Schematics",
     "models/mosi/fallout4/props/junk/blueprint.mdl",
     False, 1, 1, "120, 200, 120",
     "Obtain and submit this AND the Building Framework to the "
     "*upper skygods* to have these items redeemed."),
    ("oil_vendor_schematics", "Oil Vendor Schematics", "Schematics",
     "models/mosi/fallout4/props/junk/schematic.mdl",
     False, 1, 1, "120, 200, 120",
     "Obtain and submit this AND the Building Framework to the "
     "*upper skygods* to have these items redeemed."),
    ("power_armor_framework", "Power Armor Framework", "Schematics",
     "models/models/bos/militarycrate.mdl",
     False, 1, 1, "80, 160, 220",
     "A crate full of parts and exo-skeleton needed to research "
     "power armor."),
    ("purified_water_well_schematics", "Purified Water Well Schematics", "Schematics",
     "models/mosi/fallout4/props/junk/folder.mdl",
     False, 1, 1, "120, 200, 120",
     "Obtain and submit this AND the Building Framework to the "
     "*upper skygods* to have these items redeemed."),
    ("sharecropper_schematics", "Sharecropper Schematics", "Schematics",
     "models/mosi/fallout4/props/junk/clipboard.mdl",
     False, 1, 1, "120, 200, 120",
     "Obtain and submit this AND the Building Framework to the "
     "*upper skygods* to have these items redeemed."),
    ("stash_schematics", "Stash Schematics", "Schematics",
     "models/mosi/fallout4/props/junk/technicaldocument.mdl",
     False, 1, 1, "230, 190, 60",
     "Obtain and submit this AND the Building Framework to the "
     "*upper skygods* to have these items redeemed."),
    ("tribal_chem_bench_schematics", "Tribal Chem Bench Schematics", "Schematics",
     "models/mosi/fallout4/props/junk/blueprint.mdl",
     False, 1, 1, "230, 190, 60",
     "Obtain and submit this AND the Building Framework to the "
     "*upper skygods* to have these items redeemed."),

    # ---- Access ------------------------------------------------------------
    ("access_bigmt", "Big MT Access Pad", "Access",
     "models/mosi/fallout4/props/junk/holotape.mdl",
     False, 1, 1, "120, 200, 120",
     "A Big MT access pad. It has opinions about being carried."),
    ("access_bos", "Brotherhood Access Pad", "Access",
     "models/mosi/fallout4/props/junk/keycard.mdl",
     False, 1, 1, "60, 60, 180",
     "A Brotherhood access pad. Scribe-issued and logged."),
    ("access_cit", "CIT Access Pad", "Access",
     "models/mosi/fallout4/props/junk/keycard.mdl",
     False, 1, 1, "220, 220, 230",
     "A CIT access pad. Clean, unlabelled, and it knows who is "
     "holding it."),
    ("access_enclave", "Enclave Access Pad", "Access",
     "models/mosi/fallout4/props/junk/keycard.mdl",
     False, 1, 1, "40, 60, 90",
     "An Enclave access pad. Opens one door, for one person, once "
     "somebody decides you may."),
    ("access_ncr", "NCR Requisition Pad", "Access",
     "models/mosi/fallout4/props/junk/keycard.mdl",
     False, 1, 1, "180, 140, 60",
     "An NCR requisition pad. Signed, countersigned and probably "
     "forged."),
    ("access_vaulttec", "Vault-Tec Access Pad", "Access",
     "models/mosi/fallout4/props/junk/keycard.mdl",
     False, 1, 1, "230, 190, 60",
     "A Vault-Tec access pad. Still works, which says something "
     "about Vault-Tec."),
]
