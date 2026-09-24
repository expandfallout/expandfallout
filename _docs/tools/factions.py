# The faction roster.
#
# (id, GLOBAL, name, (r, g, b), description, races, flags)
#
# `races` is which races may join. Everything unspecified is human-only, which
# is right for the great majority - a Legion recruit is a person.
#
# flags: default  -> selectable at character creation without a whitelist
#        creature -> not a person; excluded from the human-only spawn logic
#
# The first 33 are Phoenix's, converted from their `schema/factions`. The rest
# are ones they do not have, added because this schema has the ARMOUR for them
# and a set of raider armour with no raider faction is content nobody can use.

FACTIONS = [
    # ---- Phoenix's, in their order -----------------------------------------
    ("bos", "BOS", "Brotherhood of Steel", (0, 0, 225),
     "A technocratic military order hoarding pre-War technology to prevent "
     "another apocalypse.", None, []),
    ("boulderdome", "BOULDERDOME", "Boulder Dome", (100, 0, 255),
     "Scientists shut in beneath Boulder, and what the New Plague made of "
     "them.", None, []),
    ("chimera", "CHIMERA", "Chimera", (255, 255, 255),
     "Humans remade by spore carriers. What is left is not quite either.",
     None, []),
    ("cit", "CIT", "C.I.T.", (255, 255, 255),
     "Once a university. Now a hub of scientific advancement, and less "
     "forthcoming about what it advances.", ["human", "citgen1", "citgen2"], []),
    ("creatures", "CREATURES", "Creatures", (200, 0, 0),
     "Mutated animals that inhabit the wasteland.", None, ["creature"]),
    ("crimsoncaravan", "CRIMSONCARAVAN", "Crimson Caravan", (153, 0, 0),
     "Traders and merchants, and the guns they pay to keep the road open.",
     None, []),
    ("deathclaws", "DEATHCLAWS", "Deathclaws", (200, 0, 0),
     "Mutated lizards. Extremely aggressive, and extremely fast.",
     ["deathclaw", "deathclaw_alpha", "deathclaw_baby",
      "deathclaw_matriarch"], ["creature"]),
    ("desertrangers", "DESERTRANGERS", "Desert Rangers", (9, 146, 0),
     "Survivalists out of the Mojave, older than the Republic and less "
     "interested in it than it would like.", None, []),
    ("enclave", "ENCLAVE", "Enclave Remnants", (10, 10, 10),
     "What is left of the United States government, still convinced it is "
     "the United States government.", None, []),
    ("feral", "FERAL", "Feral", (200, 0, 0),
     "Ghouls that lost their minds to the radiation, and everything else "
     "with them.", ["feralghoul", "feralghoul_armored", "feralghoul_glowing",
                    "feralghoul_reaver"], ["creature"]),
    ("fiends", "FIENDS", "Fiends", (255, 207, 98),
     "Raiders out of Vault 3, held together by chems and very little else.",
     None, []),
    ("foa", "FOA", "Followers of the Apocalypse", (200, 200, 200),
     "Doctors and teachers who believe knowledge is worth more shared than "
     "hoarded. Not everyone agrees.", None, []),
    ("greatkhans", "GREATKHANS", "Great Khans", (255, 131, 0),
     "Mercenaries and chem cooks with a long memory and a longer grudge.",
     None, []),
    ("gunners", "GUNNERS", "Gunners", (63, 207, 63),
     "A mercenary outfit known for taking no prisoners, and for being "
     "unusually well equipped about it.", None, []),
    ("gunrunners", "GUNRUNNERS", "Gun Runners", (255, 207, 63),
     "The largest arms manufacturer in the west, and careful to stay out of "
     "everybody's war.", None, []),
    ("house", "HOUSE", "House", (0, 8, 134),
     "An immortal technocrat running New Vegas through Securitrons, in the "
     "service of order, profit and a pre-War vision.",
     ["human", "securitron", "securitronexecutive"], []),
    ("legion", "LEGION", "Caesar's Legion", (193, 0, 0),
     "A slaver empire holding order through conquest, fear and absolute "
     "obedience.", None, []),
    ("marketdistrict", "MARKETDISTRICT", "Market District", (255, 255, 0),
     "Merchants who decided there was more safety in one market than in "
     "twenty stalls.", None, []),
    ("mef", "MEF", "Midwestern Expeditionary Force", (255, 222, 40),
     "A Brotherhood detachment sent out of Maxson's founding chapter, and out "
     "of contact for a very long time.", None, []),
    ("minutemen", "MINUTEMEN", "Minutemen", (27, 167, 222),
     "A militia that answers when somebody calls, which is rarer than it "
     "sounds.", None, []),
    ("monsters", "MONSTERS", "Monsters", (200, 0, 0),
     "The things in the wasteland that were never animals to begin with.",
     None, ["creature"]),
    ("ncr", "NCR", "New California Republic", (193, 154, 107),
     "A democratic republic rebuilding civilisation through law, expansion "
     "and a very stretched army.", None, []),
    ("outcasts", "OUTCASTS", "The Outcasts", (168, 35, 20),
     "A Brotherhood splinter intent on unifying the Brotherhood under their "
     "own reading of the Codex.", None, []),
    ("robots", "ROBOTS", "Robots", (0, 255, 255),
     "Machines built to serve, still running the last order they were given.",
     ["protectron", "mistergutsy", "robobrain", "sentrybot", "eyebot",
      "securitron", "roboscorpion", "libertyprime"], ["creature"]),
    ("shi", "SHI", "Shi", (255, 0, 0),
     "Descendants of a Chinese submarine crew, and the most advanced "
     "chemistry on the west coast.", None, []),
    ("sok", "SOK", "Arroyo", (220, 20, 60),
     "Tribals with technology they were not supposed to have, and no "
     "intention of giving it back.", None, []),
    ("supermutant", "SUPERMUTANT", "Super Mutants", (31, 146, 0),
     "Dipped in FEV and come out enormous. Some of them are still in there.",
     ["supermutant", "nightkin", "behemoth", "frankhorrigan"], []),
    ("unity", "UNITY", "Unity Remnants", (0, 255, 0),
     "The Master's army, still marching for a cause that ended decades ago.",
     ["supermutant", "nightkin", "centaur", "behemoth_unity"], []),
    ("vangraffs", "VANGRAFFS", "Van Graffs", (255, 255, 0),
     "Energy weapons merchants, and ruthless about the competition.",
     None, []),
    ("vaulttec", "VAULTTEC", "Vault-Tec", (0, 222, 255),
     "A pre-War company that built the vaults, and had reasons for building "
     "them the way it did.", None, []),
    ("wastelanders", "WASTELANDERS", "Wastelanders", (150, 130, 100),
     "Unaffiliated survivors, getting by on grit and whatever they can carry.",
     None, ["default"]),
    ("westtek", "WESTTEK", "Happy Trails Caravan Company", (255, 255, 0),
     "A caravan company operating out of Utah, with a pre-War name it did not "
     "choose.", None, []),
    ("zetan", "ZETAN", "ZSD-7", (0, 255, 255),
     "Zetan Survey Detachment 7. Sent ahead of the invasion force to work out "
     "whether one is needed.", ["zetan"], ["creature"]),

    # ---- ours: factions Phoenix has no entry for ---------------------------
    # Every one of these exists because the armour for it is already in the
    # schema, or because it is a gap the roster obviously has.
    ("raiders", "RAIDERS", "Raiders", (140, 40, 40),
     "No cause, no territory worth the name, and twenty-four sets of spiked "
     "armour between them.", None, []),
    ("powdergangers", "POWDERGANGERS", "Powder Gangers", (180, 140, 60),
     "Escaped convicts from the NCRCF, armed with the dynamite they were "
     "sentenced to lay.", None, []),
    ("boomers", "BOOMERS", "Boomers", (200, 90, 40),
     "Vault dwellers who took an airfield and shell anything that approaches "
     "it.", None, []),
    ("whiteglove", "WHITEGLOVE", "White Glove Society", (235, 235, 235),
     "The most civilised people on the Strip, and nobody asks what is on the "
     "menu.", None, []),
    ("omertas", "OMERTAS", "Omertas", (60, 60, 70),
     "Old-world organised crime, running Gomorrah and very little of it "
     "legally.", None, []),
    ("chairmen", "CHAIRMEN", "Chairmen", (90, 60, 140),
     "The Tops. Sharp suits, sharper knives, and a great deal of charm.",
     None, []),
    ("kings", "KINGS", "The Kings", (30, 90, 150),
     "A gang that found a pre-War impersonator school and built an identity "
     "out of it.", None, []),
    ("childrenofatom", "CHILDRENOFATOM", "Children of Atom", (120, 200, 90),
     "They do not fear radiation. They are waiting inside it for the Division.",
     None, []),
    ("taloncompany", "TALONCOMPANY", "Talon Company", (110, 90, 70),
     "Mercenaries out of the Capital Wasteland who take contracts nobody "
     "admits to writing.", None, []),
    ("regulators", "REGULATORS", "Regulators", (150, 120, 80),
     "Bounty hunters who collect fingers, and consider themselves the law "
     "because nobody else is.", None, []),
    ("railroad", "RAILROAD", "Railroad", (200, 60, 60),
     "A cell network smuggling synths out of the Institute, at a cost they do "
     "not discuss.", ["human", "citgen1", "citgen2"], []),
    ("atomcats", "ATOMCATS", "Atom Cats", (230, 120, 40),
     "Power armour mechanics with a garage, a look, and absolutely no "
     "interest in anybody's war.", None, []),
]
