--[[
	oea.

	GENERATED from Phoenix's `libs/races/robots/sh_race_securitron.lua`.
	Re-run `_docs/tools/genraces.py` rather than editing.

	NOT CARRIED ACROSS - these are function fields whose bodies
	call `nut.` APIs this schema does not have, and a function
	that fails when somebody triggers it is worse than one that
	is absent:

	    OnSpawn
]]

RACE.name = "oea"
RACE.class = "oea"
RACE.description = ""
RACE.defaultFaction = ""
RACE.animationModel = "models/phoenix/humans/animations.mdl"
RACE.hideBody = false
RACE.genders = {
    male = true,
    female = false,
    ghoul = false
}
RACE.races = {
    male = {
        "oea"
    }
}
RACE.defaultModels = {
    male = "models/galang/fallout/player/frontier/robotbody.mdl"
}
RACE.skins = {
    male = {
        oea = 0
    }
}
RACE.heads = {
    male = {
        oea = "models/galang/fallout/player/frontier/robothead.mdl"
    }
}
RACE.hairs = {
    male = false
}
RACE.beards = {
    male = false
}
RACE.faceSkins = {
    male = false,
    female = false,
    ghoul = false
}
RACE.genderCanColorHair = {
    male = false,
    female = false,
    ghoul = false
}
RACE.muscles = {
    male = false,
    female = false,
    ghoul = false
}
RACE.broadShoulders = true
RACE.scale = 0.85
RACE.baseHealth = 500
RACE.resistance = 20
RACE.jumpBoost = 60
RACE.hasHunger = false
RACE.hasRadiation = false
RACE.viewOffset = {
    normal = Vector(0,0,64),
    ducked = Vector(0,0,64)
}
RACE.hull = {
    normal = Vector(16,16,72),
    ducked = Vector(16,16,72)
}
RACE.raceColor = Color(209, 99, 0)
