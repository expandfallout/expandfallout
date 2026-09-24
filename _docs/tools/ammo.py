# The ammunition roster.
#
# (id, name, ammoType, rounds, price, model, w, h, description)
#
#   ammoType  the `SWEP.Primary.Ammo` string, EXACTLY - including its
#             capitalisation, which is the weapons' own and is not consistent
#             ("12Gauge", "45Auto", but "10mm" and "grenade"). Rounds go into the
#             player's pool for that name, so a typo puts them somewhere no
#             weapon can reach - the item is spent, the counter does not move,
#             and nothing errors. `genammo.py` reads every weapon in
#             `addons/falloutrp_weapons` and refuses to write a type none of
#             them fires, and warns about any type that has no item.
#   rounds    what one box is worth.
#   price     caps, for the faction shop. Roughly Phoenix's own economy:
#             common pistol rounds are near-free, energy cells and explosives
#             are not.
#
# GRENADES AND MINES SHARE POOLS, because the weapons do: `fraggrenade` is what
# frag, plasma AND pulse grenades fire, and `fragmine` covers five mines. One
# item per pool is not a simplification, it is what the weapons were built
# against.
#
# Models are Phoenix's where they have one, and our own weapon items' world
# models for the throwables they never itemised. Every path is checked against
# disk by the generator.

AMMO = [
    # ---- pistol and rifle ---------------------------------------------------
    ("22lr", ".22LR Rounds", "22LR", 50, 20,
     "models/ammo/22lrammo.mdl", 1, 1,
     "A box of .22 long rifle. Barely worth carrying, and it is what most "
     "people have."),
    ("32", ".32 Rounds", "32", 50, 25,
     "models/ammo/32ammo.mdl", 1, 1,
     "A box of .32 calibre. Old, common, and unfussy about what fires it."),
    ("38", ".38 Rounds", "38", 50, 25,
     "models/ammo/357ammo.mdl", 1, 1,
     "A box of .38 special. The cheapest thing a revolver will take."),
    ("357magnum", ".357 Magnum Rounds", "357Magnum", 24, 60,
     "models/ammo/357ammo.mdl", 1, 1,
     "A box of .357 magnum. Loud, and it puts things down."),
    ("44magnum", ".44 Magnum Rounds", "44Magnum", 24, 80,
     "models/ammo/44mmammo.mdl", 1, 1,
     "A box of .44 magnum. More gun than most people can hold straight."),
    ("45auto", ".45 Auto Rounds", "45Auto", 50, 45,
     "models/ammo/45autoammo.mdl", 1, 1,
     "A box of .45 auto. Slow, heavy and it does not care about armour."),
    ("9mm", "9mm Rounds", "9mm", 50, 30,
     "models/ammo/9mmammo.mdl", 1, 1,
     "A box of 9mm. The round the wasteland runs on."),
    ("10mm", "10mm Rounds", "10mm", 50, 40,
     "models/ammo/10mmammo.mdl", 1, 1,
     "A box of 10mm. Standard issue for anyone with a supply line."),
    ("127mm", "12.7mm Rounds", "127mm", 24, 110,
     "models/ammo/127mmammo.mdl", 1, 1,
     "A box of 12.7mm. Pistol rounds that behave like rifle rounds."),
    ("5mm", "5mm Rounds", "5mm", 100, 90,
     "models/ammo/5mmammo.mdl", 1, 1,
     "A belt of 5mm. Sold by the hundred because nothing that takes it fires "
     "slowly."),
    ("556mm", "5.56mm Rounds", "556mm", 50, 70,
     "models/ammo/556ammo.mdl", 1, 1,
     "A box of 5.56mm. What every serious outfit standardised on."),
    ("308", ".308 Rounds", "308", 30, 85,
     "models/ammo/308ammo.mdl", 1, 1,
     "A box of .308. For the rifles people take their time with."),
    ("4570govt", ".45-70 Gov't Rounds", "45-70Govt", 20, 100,
     "models/ammo/4570govammo.mdl", 1, 1,
     "A box of .45-70 government. Pre-war hunting stock, and it still works."),
    ("50mg", ".50 MG Rounds", "50MG", 20, 200,
     "models/ammo/50mgammo.mdl", 1, 1,
     "A box of .50 machine gun. Nothing man-sized survives being hit by it."),

    # ---- shotgun ------------------------------------------------------------
    ("12gauge", "12 Gauge Shells", "12Gauge", 25, 50,
     "models/ammo/shotgunshells.mdl", 1, 1,
     "A box of 12 gauge shells."),
    ("20gauge", "20 Gauge Shells", "20Gauge", 25, 40,
     "models/ammo/20gaugeammo.mdl", 1, 1,
     "A box of 20 gauge shells. Lighter, and easier on the shoulder."),

    # ---- energy -------------------------------------------------------------
    ("energycell", "Small Energy Cells", "EnergyCell", 40, 90,
     "models/ammo/energycell.mdl", 1, 1,
     "A carton of small energy cells. The laser pistol's staple."),
    ("microfusioncell", "Microfusion Cells", "MicrofusionCell", 30, 160,
     "models/ammo/mfcell.mdl", 1, 1,
     "A carton of microfusion cells. Pre-war manufacture, and nobody has "
     "managed to make more."),
    ("electronchargepack", "Electron Charge Packs", "ElectronChargePack",
     40, 140, "models/ammo/ecpack.mdl", 1, 1,
     "A carton of electron charge packs. What the Gauss and plasma weapons "
     "drink."),
    ("flamerfuel", "Flamer Fuel", "FlamerFuel", 60, 120,
     "models/ammo/flamerfuel.mdl", 1, 2,
     "A tank of flamer fuel. Heavy, and you would rather not be shot "
     "carrying it."),

    # ---- explosive ----------------------------------------------------------
    ("25mmgrenade", "25mm Grenades", "25mmGrenade", 10, 220,
     "models/ammo/25mmammo.mdl", 1, 1,
     "A case of 25mm grenades for an automatic launcher."),
    ("40mmgrenade", "40mm Grenades", "40mmGrenade", 10, 260,
     "models/ammo/25mmammo.mdl", 1, 1,
     "A case of 40mm grenades. One at a time, and one is usually enough."),
    ("missile", "Missiles", "Missile", 5, 400,
     "models/ammo/missile.mdl", 1, 3,
     "A rack of missiles. Awkward, obvious, and worth every cap when it "
     "lands."),
    ("mininuke", "Mini Nuke", "MiniNuke", 1, 1500,
     "models/ammo/mininuke.mdl", 2, 2,
     "One mini nuke. Sold singly, for reasons that should not need "
     "explaining."),

    # ---- thrown and placed --------------------------------------------------
    #
    # The pools these go into are shared: `fraggrenade` is what frag, plasma
    # and pulse grenades all fire, and `fragmine` covers five different mines.
    ("fraggrenade", "Frag Grenades", "FragGrenade", 5, 150,
     "models/roadkill/fallout/weapons/world/grenade/w_frag.mdl", 1, 1,
     "A bandolier of grenades. Feeds anything you throw - frag, plasma or "
     "pulse."),
    ("fragmine", "Frag Mines", "FragMine", 3, 180,
     "models/roadkill/fallout/weapons/world/mines/w_fragmine.mdl", 1, 1,
     "A satchel of mines. Feeds anything you put on the ground and walk away "
     "from."),
    ("cryogrenade", "Cryo Grenades", "CryoGrenade", 5, 200,
     "models/roadkill/fallout/weapons/world/grenade/w_pulse.mdl", 1, 1,
     "A bandolier of cryogenic grenades."),
    ("cryomine", "Cryo Mines", "CryoMine", 3, 230,
     "models/roadkill/fallout/weapons/world/mines/w_fragmine.mdl", 1, 1,
     "A satchel of cryogenic mines."),
    ("incingrenade", "Incendiary Grenades", "IncinGrenade", 5, 190,
     "models/roadkill/fallout/weapons/world/grenade/w_incin.mdl", 1, 1,
     "A bandolier of incendiary grenades."),
    ("smokegrenade", "Smoke Grenades", "SmokeGrenade", 5, 70,
     "models/roadkill/fallout/weapons/world/grenade/w_incin.mdl", 1, 1,
     "A bandolier of smoke grenades. The only one of these meant to get "
     "somebody out alive."),
    ("flashgrenade", "Flashbangs", "FlashGrenade", 5, 90,
     "models/catmop/fallout/weapons/world/grenade/flashbang.mdl", 1, 1,
     "A bandolier of flashbangs."),
    ("dynamitegrenade", "Dynamite", "DynamiteGrenade", 5, 80,
     "models/roadkill/fallout/weapons/world/grenade/w_dynamite.mdl", 1, 1,
     "A bundle of dynamite with the fuses cut short."),
    ("holygrenade", "Holy Hand Grenade", "HolyGrenade", 1, 2000,
     "models/catmop/fallout/weapons/world/grenade/holy_hand_grenade.mdl",
     1, 1,
     "And the Lord spake, saying, first shalt thou take out the Holy Pin."),
    ("spear", "Throwing Spears", "grenade", 3, 60,
     "models/catmop/fallout/weapons/world/grenade/spear.mdl", 1, 3,
     "A bundle of spears, sharpened and balanced for throwing."),
]
