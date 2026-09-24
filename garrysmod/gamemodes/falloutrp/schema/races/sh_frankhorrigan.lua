--[[
	Frank Horrigan.

	GENERATED from Phoenix's `libs/races/supermutants/sh_race_frankhorrigan.lua`.
	Re-run `_docs/tools/genraces.py` rather than editing.

	NOT CARRIED ACROSS - these are function fields whose bodies
	call `nut.` APIs this schema does not have, and a function
	that fails when somebody triggers it is worse than one that
	is absent:

	    OnSpawn
	    OnDeath
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

RACE.name = "Frank Horrigan"
RACE.class = "frankhorrigan"
RACE.description = ""
RACE.defaultFaction = ""
RACE.animationModel = "models/fallout/supermutant.mdl"
RACE.hideBody = true
RACE.genders = {
    male = true,
    female = true
}
RACE.races = {
    male = {
        "frank"
    },
    female = {
        "frank"
    }
}
RACE.defaultModels = {
    male = "models/roadkill/fallout/player/supermutant/defaultbody.mdl",
    female = "models/roadkill/fallout/player/supermutant/defaultbody.mdl"
}
RACE.skins = {
    male = {
        frank = 0
    },
    female = {
        frank = 0
    }
}
RACE.heads = {
    male = {
        frank = "models/roadkill/fallout/player/supermutant/head.mdl"
    },
    female = {
        frank = "models/roadkill/fallout/player/supermutant/head.mdl"
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
RACE.scale = 1.2
RACE.baseHealth = 1750
RACE.resistance = 0
RACE.jumpBoost = 350
RACE.hasRadiation = false
RACE.canEquipWeapons = false
RACE.canEquipArmors = true
RACE.viewOffset = {
    normal = Vector(0,0,120),
    ducked = Vector(0,0,120)
}
RACE.hull = {
    normal = Vector(16,16,120),
    ducked = Vector(16,16,120)
}
RACE.raceColor = Color(5, 92, 5)
RACE.editorAnimation = "idle"
