--[[
	Protectron.

	GENERATED from Phoenix's `libs/races/robots/sh_race_protectron.lua`.
	Re-run `_docs/tools/genraces.py` rather than editing.

	NOT CARRIED ACROSS - these are function fields whose bodies
	call `nut.` APIs this schema does not have, and a function
	that fails when somebody triggers it is worse than one that
	is absent:

	    OnSpawn
	    OnDeath
	    OnThink
	    OnMelee
	    OnLand
	    OnFootStep
	    OnAnimEvent
	    OnClear
	    CustomKeys
	    overridePunch
	    startingGear
	    voiceLines
	    painSounds
	    deathSounds
	    footstepSounds
]]

RACE.name = "Protectron"
RACE.class = "protectron"
RACE.description = ""
RACE.defaultFaction = ""
RACE.animationModel = "models/fallout/protectron.mdl"
RACE.hideBody = true
RACE.genders = {
    male = true,
    female = false
}
RACE.races = {
    male = {
        "default",
        "ncr",
        "legion",
        "enclave",
        "bos"
    },
    female = {
        "default",
        "ncr",
        "legion",
        "enclave",
        "bos"
    }
}
RACE.defaultModels = {
    male = "models/fallout/protectron.mdl",
    female = "models/fallout/protectron.mdl"
}
RACE.skins = {
    male = {
        default = 0,
        ncr = 1,
        legion = 3,
        enclave = 2,
        bos = 4
    },
    female = {
        default = 0,
        ncr = 1,
        legion = 3,
        enclave = 2,
        bos = 4
    }
}
RACE.heads = {
    male = {
        default = false
    },
    female = {
        default = false
    }
}
RACE.hairs = false
RACE.beards = false
RACE.faceSkins = {
    male = false,
    female = false
}
RACE.genderCanColorHair = {
    male = true,
    female = true
}
RACE.muscles = false -- Deprecated
RACE.scale = 0.85
RACE.baseHealth = 350
RACE.resistance = 0
RACE.jumpBoost = 64
RACE.hasHunger = false
RACE.hasRadiation = false
RACE.canEquipWeapons = false
RACE.canEquipArmors = true
RACE.noSelectRaces = {
    ["ncr"] = true,
    ["legion"] = true,
    ["enclave"] = true,
    ["bos"] = true
}
RACE.viewOffset = {
    normal = Vector(0, 0, 74),
    ducked = Vector(0, 0, 74)
}
RACE.hull = {
    normal = Vector(16, 16, 74),
    ducked = Vector(16, 16, 74)
}
RACE.raceColor = Color(5, 92, 5)
RACE.editorAnimation = "mtidle"
RACE.spawnMessage = {
    Color(255,255,255), "You are a ", Color(0,0,255), "Protectron", Color(255,255,255), ".\n",
    "You are not KOS.\n You are allowed to join a faction.\n\n",
    Color(255,255,0), "Raise your Fists to preform attacks.\n",
    Color(255,255,255), "[Mouse 1] - Melee.\n[Mouse 2] - Laser.\n\n",
    Color(255,255,0), "You can play voice lines via the /emotes command."
}

--[[
	The animation class for this race's model.

	Without it the race falls back to Half-Life 2 player
	animations, which is a character standing with its arms out,
	sliding rather than walking. The SET itself is in
	`libs/sh_raceanims.lua`, which loads first - several races
	share one, and a table defined in a sibling race file would
	make this depend on alphabetical load order.
]]
ix.anim.SetModelClass("models/fallout/protectron.mdl", "protectron")
