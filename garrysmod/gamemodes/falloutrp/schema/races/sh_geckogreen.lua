--[[
	Green Gecko.

	GENERATED from Phoenix's `libs/races/geckos/sh_race_gecko_green.lua`.
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

RACE.name = "Green Gecko"
RACE.class = "geckogreen"
RACE.description = ""
RACE.defaultFaction = ""
RACE.animationModel = "models/fallout/gecko.mdl"
RACE.hideBody = true
RACE.genders = {
    male = true,
    female = true
}
RACE.races = {
    male = {
        "default"
    },
    female = {
        "default"
    }
}
RACE.defaultModels = {
    male = "models/fallout/gecko.mdl",
    female = "models/fallout/gecko.mdl"
}
RACE.skins = {
    male = {
        default = 3
    },
    female = {
        default = 3
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
RACE.raceBodygroups = {}
RACE.genderCanColorHair = {
    male = true,
    female = true
}
RACE.muscles = false -- Deprecated
RACE.scale = 0.85
RACE.baseHealth = 200
RACE.resistance = 0
RACE.jumpBoost = 100
RACE.hasRadiation = false
RACE.canEquipWeapons = false
RACE.canEquipArmors = true
RACE.noSelectRaces = {}
RACE.viewOffset = {
    normal = Vector(0, 0, 50),
    ducked = Vector(0, 0, 50)
}
RACE.hull = {
    normal = Vector(16, 16, 55),
    ducked = Vector(16, 16, 55)
}
RACE.raceColor = Color(5, 92, 5)
RACE.editorAnimation = "mtidle"
RACE.spawnMessage = {Color(255, 255, 255), "You are a ", Color(255, 0, 0), "Gecko", Color(255, 255, 255), ".\n", "You are ", Color(255, 0, 0), "KOS.", Color(255, 255, 255), Color(255, 255, 0), "\n\nRaise your Fists to preform attacks.\n", Color(255, 255, 255), "[Mouse 1] - Melee Attack.\n[Mouse 2] - Jump."}
