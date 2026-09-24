# The class roster.
#
# (faction, id, name, rank, races, flags)
#
#   faction  a faction id from `factions.py`
#   id       the uniqueID, and the file name (`sh_<id>.lua`). Faction-prefixed,
#            because Helix takes the uniqueID from the FILE NAME and loads
#            `schema/classes/` FLAT - `ix.class.LoadFromDir` does
#            `file.Find(dir.."/*.lua")` with no recursion, so Phoenix's
#            per-faction subfolders cannot survive the port and two factions
#            with an `sh_enlisted.lua` would silently be one class.
#   rank     1 enlisted / member
#            2 NCO / manager
#            3 officer / senior
#            4 lead
#            Phoenix carry this as four separate booleans (`CLASS.enlisted`,
#            `.nco`, `.officer`, `.lead`) which they set inconsistently - about
#            half their files set none at all. One ordered number says the same
#            thing and can be compared.
#   races    which races may take it, or None for "whatever the faction allows".
#            Only used where the class is a specific creature or robot.
#   flags    default -> assigned on joining the faction, and preselected at
#                       character creation
#            unique  -> one character on the server at a time (CLASS.limit = 1)
#
# EXACTLY ONE DEFAULT PER FACTION. Phoenix have four in the Crimson Caravan,
# four in ZSD-7 and four of five in the Shi, and Helix's rule is "the first
# `isDefault` class of your faction in load order" - so on their server a new
# Crimson Caravan character is whatever the file system happened to list first,
# which can be the Lead. The generator refuses to write a roster that does that.
#
# THE FIRST 25 FACTIONS ARE PHOENIX'S, names carried across as they wrote them.
# Three of their groupings do not survive contact with our roster:
#
#   - their `house_omerta*`, `house_whiteglove*` and `house_chairmen*` are
#     classes inside House. We have Omertas, White Glove Society and Chairmen
#     as factions of their own, linked under House by the sub-faction system,
#     so those become that faction's own ladder instead.
#   - their `marketdistrict` classes are the same Crimson Caravan / Gun Runners
#     / Van Graffs ladders a second time, for staff posted to the market. Kept,
#     because that is genuinely what the faction is.
#   - their `minutemen` files use FACTION_MM; ours is FACTION_MINUTEMEN.

# ---------------------------------------------------------------- helpers ----
STANDARD = (("enlisted", "Enlisted", 1),
            ("nco", "NCO", 2),
            ("officer", "Officer", 3),
            ("lead", "Lead", 4))


def ladder(faction, label, rungs=STANDARD, prefix=None, races=None,
           default=True):
    """The four-rung ladder most factions have, as Phoenix name them.

    `prefix` is the id prefix when it is not the faction id - the Market
    District holds three ladders, so they cannot all be `marketdistrict_*`.

    `default=False` for the second and third ladder in a faction: the bottom
    rung is the faction's default only when there is one ladder to be the
    bottom of. This is the check that catches the thing Phoenix's roster gets
    wrong in four places.
    """
    prefix = prefix or faction
    out = []

    for i, (suffix, rung, rank) in enumerate(rungs):
        out.append((faction, "%s_%s" % (prefix, suffix),
                    "%s - %s" % (label, rung), rank, races,
                    ["default"] if (i == 0 and default) else []))

    return out


CLASSES = []
add = CLASSES.extend

# ============================================================ Phoenix's ======

add(ladder("bos", "BoS"))
add(ladder("boulderdome", "Boulder Dome"))

# Chimera run a field training office alongside the line units.
add(ladder("chimera", "Chimera"))
add([
    ("chimera", "chimera_fto_enlisted", "FTO - Enlisted", 1, None, []),
    ("chimera", "chimera_fto_nco", "FTO - NCO", 2, None, []),
    ("chimera", "chimera_fto_officer", "FTO - Officer", 3, None, []),
])

# CIT is three research divisions and an internal security bureau rather than a
# rank ladder, so it is written out rather than generated.
add([
    ("cit", "cit_trainee", "CIT - Trainee", 1, None, ["default"]),
    ("cit", "cit_director", "CIT - Director", 4, None, ["unique"]),

    ("cit", "cit_advsys_junior_scientist",
     "CIT - Junior Advanced Systems Scientist", 1, None, []),
    ("cit", "cit_advsys_scientist",
     "CIT - Advanced Systems Scientist", 2, None, []),
    ("cit", "cit_advsys_senior_scientist",
     "CIT - Senior Advanced Systems Scientist", 3, None, []),
    ("cit", "cit_advsys_division_lead",
     "CIT - Advanced Systems Division Lead", 4, None, []),

    ("cit", "cit_biosci_junior_scientist",
     "CIT - Junior BioScience Scientist", 1, None, []),
    ("cit", "cit_biosci_scientist",
     "CIT - BioScience Scientist", 2, None, []),
    ("cit", "cit_biosci_senior_scientist",
     "CIT - Senior BioScience Scientist", 3, None, []),
    ("cit", "cit_biosci_division_lead",
     "CIT - BioScience Division Lead", 4, None, []),

    ("cit", "cit_robotics_junior_engineer",
     "CIT - Junior Robotics Engineer", 1, None, []),
    ("cit", "cit_robotics_engineer",
     "CIT - Robotics Engineer", 2, None, []),
    ("cit", "cit_robotics_senior_engineer",
     "CIT - Senior Robotics Engineer", 3, None, []),
    ("cit", "cit_robotics_division_lead",
     "CIT - Robotics Division Lead", 4, None, []),

    ("cit", "cit_srb_agent", "CIT - SRB Agent", 1, None, []),
    ("cit", "cit_srb_senior_agent", "CIT - SRB Senior Agent", 2, None, []),
    ("cit", "cit_srb_operations_officer",
     "CIT - SRB Operations Officer", 3, None, []),
    ("cit", "cit_srb_director", "CIT - SRB Director", 4, None, []),

    # The synths CIT builds. Their generation decides what they can pass for,
    # which is the whole of the Institute's argument with the Commonwealth.
    ("cit", "cit_synth_gen1", "CIT - Gen 1 Synth", 1, ["citgen1"], []),
    ("cit", "cit_synth_gen2", "CIT - Gen 2 Synth", 2, ["citgen2"], []),
])

add(ladder("crimsoncaravan", "Crimson Caravan"))
add(ladder("desertrangers", "Desert Rangers"))
add(ladder("enclave", "Enclave"))
add(ladder("fiends", "Fiends"))
add(ladder("foa", "FoA"))
add(ladder("greatkhans", "Great Khans"))
add(ladder("gunners", "Gunners"))
add(ladder("gunrunners", "Gun Runners"))

# House is a business, so its rungs are business ones - Phoenix's names.
add(ladder("house", "House",
           (("enlisted", "Member", 1), ("nco", "Manager", 2),
            ("officer", "Executive", 3), ("lead", "CEO", 4))))
add([
    # The robots that actually hold the Strip. A securitron is a securitron
    # whatever it is told to do, so these are race-locked.
    ("house", "house_securitron", "Securitron", 1, ["securitron"], []),
    ("house", "house_securitron_nco", "Securitron NCO", 2, ["securitron"], []),
    ("house", "house_securitron_officer", "Securitron Officer", 3,
     ["securitronexecutive"], []),
])

add(ladder("legion", "Legion"))

# The market: three trading houses under one roof, each with its own ladder.
add(ladder("marketdistrict", "Crimson Caravan", prefix="ccmarket"))
add(ladder("marketdistrict", "Gun Runners", prefix="grmarket",
           default=False))
add(ladder("marketdistrict", "Van Graffs", prefix="vgmarket",
           default=False))

add(ladder("mef", "MEF"))
add(ladder("minutemen", "Minutemen"))
add(ladder("ncr", "NCR"))

add(ladder("shi", "SHI"))
add([("shi", "shi_banker", "SHI - Banker", 2, None, [])])

add(ladder("sok", "Sons Of Kaga"))

add(ladder("unity", "Unity"))
add([
    ("unity", "unity_nightkin_enlisted", "Unity - Nightkin Enlisted", 1,
     ["nightkin"], []),
    ("unity", "unity_nightkin_nco", "Unity - Nightkin NCO", 2,
     ["nightkin"], []),
    ("unity", "unity_nightkin_officer", "Unity - Nightkin Officer", 3,
     ["nightkin"], []),
    ("unity", "unity_nightkin_lead", "Unity - Nightkin Lead", 4,
     ["nightkin"], []),
    # The Master's heavies and his cavalry.
    ("unity", "unity_behemoth", "Unity - Behemoth", 3, ["behemoth_unity"], []),
    ("unity", "unity_centaur", "Unity - Centaur", 1, ["centaur"], []),
])

add(ladder("vangraffs", "Van Graffs"))
add(ladder("vaulttec", "Vault-Tec"))
add(ladder("westtek", "West Tek"))
add(ladder("zetan", "ZSD-7", races=["zetan"]))

# ====================================================== ours, not theirs =====
#
# The twenty factions Phoenix do not have. The ladders follow the same shape so
# nothing behaves differently, but the rungs are named for what the faction
# actually is - the Kings do not have NCOs.

add(ladder("atomcats", "Atom Cats",
           (("greaser", "Greaser", 1), ("mechanic", "Mechanic", 2),
            ("rider", "Rider", 3), ("boss", "Boss", 4))))

add(ladder("boomers", "Boomers",
           (("recruit", "Recruit", 1), ("crew", "Artillery Crew", 2),
            ("wing", "Wing Commander", 3), ("elder", "Elder", 4))))

add(ladder("chairmen", "Chairmen",
           (("member", "Member", 1), ("manager", "Manager", 2),
            ("floorboss", "Floor Boss", 3), ("owner", "Owner", 4))))

add(ladder("childrenofatom", "Children of Atom",
           (("initiate", "Initiate", 1), ("zealot", "Zealot", 2),
            ("confessor", "Confessor", 3),
            ("highconfessor", "High Confessor", 4))))

add(ladder("kings", "The Kings",
           (("greaser", "Greaser", 1), ("sergeant", "Sergeant-at-Arms", 2),
            ("lieutenant", "Lieutenant", 3), ("king", "The King", 4))))

add(ladder("omertas", "Omertas",
           (("member", "Member", 1), ("enforcer", "Enforcer", 2),
            ("capo", "Capo", 3), ("boss", "Boss", 4))))

add(ladder("outcasts", "Outcasts",
           (("initiate", "Initiate", 1), ("knight", "Knight", 2),
            ("paladin", "Paladin", 3), ("defender", "Defender", 4))))

add(ladder("powdergangers", "Powder Gangers",
           (("convict", "Convict", 1), ("enforcer", "Enforcer", 2),
            ("lieutenant", "Lieutenant", 3), ("boss", "Boss", 4))))

add(ladder("raiders", "Raiders",
           (("raider", "Raider", 1), ("veteran", "Veteran", 2),
            ("boss", "Boss", 3), ("warlord", "Warlord", 4))))

# Railroad rungs are the ones the game gives them, and the synths they run.
add(ladder("railroad", "Railroad",
           (("tourist", "Tourist", 1), ("agent", "Agent", 2),
            ("heavy", "Heavy", 3), ("alpha", "Alpha", 4))))
add([
    ("railroad", "railroad_synth_gen1", "Railroad - Escaped Gen 1", 1,
     ["citgen1"], []),
    ("railroad", "railroad_synth_gen2", "Railroad - Escaped Gen 2", 1,
     ["citgen2"], []),
])

add(ladder("regulators", "Regulators",
           (("regulator", "Regulator", 1), ("senior", "Senior Regulator", 2),
            ("captain", "Captain", 3), ("commander", "Commander", 4))))

add(ladder("whiteglove", "White Glove Society",
           (("member", "Member", 1), ("host", "Host", 2),
            ("maitred", "Maitre d'", 3), ("proprietor", "Proprietor", 4))))

add(ladder("taloncompany", "Talon Company",
           (("merc", "Merc", 1), ("sergeant", "Sergeant", 2),
            ("lieutenant", "Lieutenant", 3), ("commander", "Commander", 4))))

# ---------------------------------------------------------------- civilians --
#
# NO LADDER. Wastelanders is the default faction - the one every character
# without a whitelist starts in - and it is not an organisation, so a rank in it
# would mean nothing. These are what somebody DOES instead, all at rank 1, and
# they exist so a new character has something to be other than "Wastelander".
add([
    ("wastelanders", "wastelander", "Wastelander", 1, None, ["default"]),
    ("wastelanders", "wastelander_scavenger", "Scavenger", 1, None, []),
    ("wastelanders", "wastelander_trader", "Trader", 1, None, []),
    ("wastelanders", "wastelander_settler", "Settler", 1, None, []),
    ("wastelanders", "wastelander_farmer", "Farmer", 1, None, []),
    ("wastelanders", "wastelander_doctor", "Doctor", 1, None, []),
    ("wastelanders", "wastelander_mercenary", "Mercenary", 1, None, []),
    ("wastelanders", "wastelander_prospector", "Prospector", 1, None, []),
    ("wastelanders", "wastelander_drifter", "Drifter", 1, None, []),
])

# ----------------------------------------------------------- creature sides --
#
# THE RACE IS THE CLASS. A deathclaw matriarch is not a rank above a young
# deathclaw, it is a different animal, so these are race-locked one to one and
# every rank is 1 except where one genuinely leads the others.
add([
    ("deathclaws", "deathclaw_young", "Young Deathclaw", 1,
     ["deathclaw_baby"], ["default"]),
    ("deathclaws", "deathclaw_adult", "Deathclaw", 1, ["deathclaw"], []),
    ("deathclaws", "deathclaw_alpha", "Alpha Male", 3,
     ["deathclaw_alpha"], []),
    ("deathclaws", "deathclaw_mother", "Mother", 4,
     ["deathclaw_matriarch"], ["unique"]),

    ("feral", "feral_ghoul", "Feral Ghoul", 1, ["feralghoul"], ["default"]),
    ("feral", "feral_armored", "Withered Ghoul", 1,
     ["feralghoul_armored"], []),
    ("feral", "feral_glowing", "Glowing One", 3,
     ["feralghoul_glowing"], []),
    ("feral", "feral_reaver", "Reaver", 4, ["feralghoul_reaver"], []),

    ("supermutant", "supermutant_brute", "Super Mutant", 1,
     ["supermutant"], ["default"]),
    ("supermutant", "supermutant_nightkin", "Nightkin", 2, ["nightkin"], []),
    ("supermutant", "supermutant_behemoth", "Behemoth", 3, ["behemoth"], []),
    ("supermutant", "supermutant_horrigan", "Frank Horrigan", 4,
     ["frankhorrigan"], ["unique"]),

    ("robots", "robot_protectron", "Protectron", 1, ["protectron"],
     ["default"]),
    ("robots", "robot_eyebot", "Eyebot", 1, ["eyebot"], []),
    ("robots", "robot_gutsy", "Mister Gutsy", 2, ["mistergutsy"], []),
    ("robots", "robot_roboscorpion", "Robo-Scorpion", 2, ["roboscorpion"], []),
    ("robots", "robot_securitron", "Securitron", 2, ["securitron"], []),
    ("robots", "robot_robobrain", "Robobrain", 3, ["robobrain"], []),
    ("robots", "robot_sentrybot", "Sentry Bot", 3, ["sentrybot"], []),
    ("robots", "robot_libertyprime", "Liberty Prime", 4, ["libertyprime"],
     ["unique"]),

    # Creatures and Monsters name no races in `factions.py`, so there is
    # nothing to lock these to and one class is the honest answer. If either
    # ever gets a race list, they get a class each the way Deathclaws did.
    ("creatures", "creature_wildlife", "Wasteland Creature", 1, None,
     ["default"]),
    ("monsters", "monster_abomination", "Abomination", 1, None, ["default"]),
])

# Classes there can only be one of at a time, applied after the fact because
# `ladder()` generates its four rungs identically and has no way to say it.
# There is one King; that is the entire point of him.
UNIQUE = {"kings_king"}

CLASSES = [(f, i, n, r, races, flags + ["unique"] if i in UNIQUE else flags)
           for f, i, n, r, races, flags in CLASSES]


# ------------------------------------------------------------- descriptions --
#
# What the character creator shows under the class name.
#
# The four-rung ladders get a generic line off their rank, because two hundred
# hand-written variations on "answers to the one above" would be two hundred
# chances to say something wrong about a faction. The classes that are NOT a
# rung - the civilian trades, the creatures, the robots - get their own line,
# because for those the rank number says nothing true at all.
BY_RANK = {
    1: "The rank and file of the %s.",
    2: "Answers for the rank and file of the %s.",
    3: "Senior enough in the %s for an order to carry.",
    4: "Runs the %s, and answers for it.",
}

DESCRIPTIONS = {
    # ---- civilians: a trade, not a rank ----------------------------------
    "wastelander": "Somebody with no faction and no particular plan.",
    "wastelander_scavenger": "Strips the ruins for anything still worth "
                             "carrying out of them.",
    "wastelander_trader": "Moves goods between settlements, and takes the "
                          "road's risk as the cost of it.",
    "wastelander_settler": "Holding a patch of ground and trying to make it "
                           "worth holding.",
    "wastelander_farmer": "Grows food in dirt that mostly does not want to "
                          "grow anything.",
    "wastelander_doctor": "Patches up whoever can pay, and a fair number who "
                          "cannot.",
    "wastelander_mercenary": "Fights for caps, for whoever has them.",
    "wastelander_prospector": "Works the old vaults and bunkers alone, which "
                              "is how most of them end.",
    "wastelander_drifter": "Never in one place long enough for anyone to ask "
                           "why.",

    # ---- deathclaws --------------------------------------------------------
    "deathclaw_young": "Not yet full grown, and already faster than you.",
    "deathclaw_adult": "Nine feet of muscle, claws and bad temper.",
    "deathclaw_alpha": "The male that holds the nest, and the ground around "
                       "it.",
    "deathclaw_mother": "The matriarch. Everything else in the nest is hers.",

    # ---- ferals ------------------------------------------------------------
    "feral_ghoul": "A ghoul the radiation finished. Nothing of the person is "
                   "left.",
    "feral_armored": "Withered down to leather and bone, and harder for it.",
    "feral_glowing": "So saturated it lights the room, and heals the others "
                     "in it.",
    "feral_reaver": "Old, huge, and it throws what it has been standing on.",

    # ---- super mutants -----------------------------------------------------
    "supermutant_brute": "Eight feet of FEV-grown muscle with a rifle it "
                         "barely needs.",
    "supermutant_nightkin": "A Stealth Boy addict, and paranoid in the way "
                            "that comes with it.",
    "supermutant_behemoth": "What decades of growth does to a super mutant "
                            "that nothing stops.",
    "supermutant_horrigan": "The Enclave's finest work, and the last thing a "
                            "great many people saw.",

    # ---- robots ------------------------------------------------------------
    "robot_protectron": "Slow, blocky, and still running the routine it was "
                        "given before the war.",
    "robot_eyebot": "A flying broadcast relay that will not stop talking.",
    "robot_gutsy": "A combat Mister Handy, still following orders nobody "
                   "alive gave it.",
    "robot_roboscorpion": "Big MT's idea of pest control, walking on its own "
                          "now.",
    "robot_securitron": "Wheeled, armed, and confident about it.",
    "robot_robobrain": "A human brain in a chassis, and aware of it.",
    "robot_sentrybot": "A walking gun emplacement with a reactor that goes "
                       "off when it dies.",
    "robot_libertyprime": "Forty feet of Cold War propaganda with a fusion "
                          "core. Democracy is non-negotiable.",

    # ---- the rest ----------------------------------------------------------
    "creature_wildlife": "Something the wasteland made that has not been "
                         "named yet.",
    "monster_abomination": "Not an animal any more, and never was a person.",
    "cit_trainee": "Newly under the Institute, and not yet told very much.",
    "cit_director": "The Institute answers to one person. This is them.",
    "cit_synth_gen1": "A first-generation synth. Plastic and servos, and no "
                      "pretence otherwise.",
    "cit_synth_gen2": "A second-generation synth. Closer, and still not close "
                      "enough to pass.",
    "railroad_synth_gen1": "A Gen 1 that got out, and the Railroad got to "
                           "first.",
    "railroad_synth_gen2": "A Gen 2 that got out, and is trying to stay out.",
    "house_securitron": "One of the machines that actually holds the Strip.",
    "house_securitron_nco": "A securitron given the others to direct.",
    "house_securitron_officer": "The upgraded chassis, and the authority that "
                                "came with it.",
    "unity_behemoth": "The Master's heaviest, used where a door is in the "
                      "way.",
    "unity_centaur": "The Master's hounds. Made of whatever was to hand.",
    "shi_banker": "Handles the Shi's money, which is most of what the Shi "
                  "are.",
    "kings_king": "There is one King, and he is it.",
}


def describe(faction_name, cid, rank):
    """The line under the class name in character creation."""
    return DESCRIPTIONS.get(cid) or (BY_RANK[rank] % faction_name)
