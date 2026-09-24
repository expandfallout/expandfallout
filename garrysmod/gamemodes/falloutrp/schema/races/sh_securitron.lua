--[[
	Securitron.

	GENERATED from Phoenix's `libs/races/robots/sh_race_securitron.lua`.
	Re-run `_docs/tools/genraces.py` rather than editing.
]]

RACE.name = "Securitron"
RACE.class = "securitron"
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
        securitron = 0
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
RACE.scale = 0.85
RACE.baseHealth = 500
RACE.resistance = 5
RACE.jumpBoost = 70
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
    normal = Vector(0,0,75),
    ducked = Vector(0,0,75)
}
RACE.hull = {
    normal = Vector(16,16,72),
    ducked = Vector(16,16,72)
}
RACE.raceColor = Color(0, 0, 150)
