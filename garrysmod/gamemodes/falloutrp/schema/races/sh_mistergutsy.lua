--[[
	Mister Gutsy.

	GENERATED from Phoenix's `libs/races/robots/sh_race_mistergutsy.lua`.
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
	    painSounds
	    deathSounds
	    footstepSounds
]]

RACE.name = "Mister Gutsy"
RACE.class = "mistergutsy"
RACE.description = ""
RACE.defaultFaction = ""
RACE.animationModel = "models/fallout/mistergutsy.mdl"
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
    male = "models/fallout/mistergutsy.mdl",
    female = "models/fallout/mistergutsy.mdl"
}
RACE.skins = {
    male = {
        default = 0,
        ncr = 6,
        legion = 5,
        enclave = 3,
        bos = 7
    },
    female = {
        default = 0,
        ncr = 6,
        legion = 5,
        enclave = 3,
        bos = 7
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
    normal = Vector(0, 0, 85),
    ducked = Vector(0, 0, 85)
}
RACE.hull = {
    normal = Vector(16, 16, 90),
    ducked = Vector(16, 16, 90)
}
RACE.raceColor = Color(5, 92, 5)
RACE.editorAnimation = "mtidle"

--[[
	The animation class for this race's model.

	Without it the race falls back to Half-Life 2 player
	animations, which is a character standing with its arms out,
	sliding rather than walking. The SET itself is in
	`libs/sh_raceanims.lua`, which loads first - several races
	share one, and a table defined in a sibling race file would
	make this depend on alphabetical load order.
]]
ix.anim.SetModelClass("models/fallout/mistergutsy.mdl", "gutsy")
