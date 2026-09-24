--[[
	Securitron Executive.

	GENERATED from Phoenix's `libs/races/robots/sh_race_securitronexecutive.lua`.
	Re-run `_docs/tools/genraces.py` rather than editing.

	NOT CARRIED ACROSS - these are function fields whose bodies
	call `nut.` APIs this schema does not have, and a function
	that fails when somebody triggers it is worse than one that
	is absent:

	    OnSpawn
]]

RACE.name = "Securitron Executive"
RACE.class = "securitronexecutive"
RACE.description = ""
RACE.defaultFaction = ""
RACE.animationModel = "models/roadkill_fallout/robots/securitron.mdl"
RACE.hideBody = true
RACE.genders = {
    male = true,
    female = false,
    ghoul = false
}
RACE.races = {
    male = {
        "securitron"
    }
}
RACE.defaultModels = {
    male = "models/roadkill_fallout/robots/securitron.mdl",
    female = "models/roadkill_fallout/robots/securitron.mdl"
}
RACE.skins = {
    male = {
        securitron = 1
    }
}
RACE.heads = {
    male = {
        securitron = false
    }
}
RACE.hairs = {
    male = {}
}
RACE.beards = {
    male = {}
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
RACE.baseHealth = 600
RACE.resistance = 15
RACE.jumpBoost = 60
RACE.hasHunger = false
RACE.hasRadiation = false
RACE.chemWhitelist = { -- Only allows these chems.
    ["aid_stealthboy"] = true,
    ["aid_cleansing_powder"] = false,
    ["aid_radaway"] = false,
    ["aid_daytripper"] = false,
    ["aid_robotrepairkit"] = true
}
RACE.viewOffset = {
    normal = Vector(0,0,64),
    ducked = Vector(0,0,64)
}
RACE.hull = {
    normal = Vector(16,16,72),
    ducked = Vector(16,16,72)
}
RACE.raceColor = Color(209, 99, 0)
