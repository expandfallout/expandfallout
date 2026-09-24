--[[
	Super Mutant.

	GENERATED from Phoenix's `libs/races/supermutants/sh_race_supermutant.lua`.
	Re-run `_docs/tools/genraces.py` rather than editing.

	NOT CARRIED ACROSS - these are function fields whose bodies
	call `nut.` APIs this schema does not have, and a function
	that fails when somebody triggers it is worse than one that
	is absent:

	    startingGear
	    painSounds
	    deathSounds
	    foodSteps
]]

RACE.name = "Super Mutant"
RACE.class = "supermutant"
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
        "gen2"
    },
    female = {
        "gen2"
    }
}
RACE.defaultModels = {
    male = "models/roadkill/fallout/player/supermutant/defaultbody.mdl",
    female = "models/roadkill/fallout/player/supermutant/defaultbody.mdl"
}
RACE.skins = {
    male = {
        gen2 = 0
    },
    female = {
        gen2 = 0
    }
}
RACE.heads = {
    male = {
        gen2 = "models/roadkill/fallout/player/supermutant/head.mdl"
    },
    female = {
        gen2 = "models/roadkill/fallout/player/supermutant/head.mdl"
    }
}
RACE.hairs = {
    male = {
        "models/roadkill/fallout/player/supermutant/hair1.mdl",
        "models/roadkill/fallout/player/supermutant/hair2.mdl"
    },
    female = {
        "models/roadkill/fallout/player/supermutant/hair1.mdl",
        "models/roadkill/fallout/player/supermutant/hair2.mdl"
    }
}
RACE.beards = {
    male = false
}
RACE.faceSkins = {
    male = false,
    female = false
}
RACE.genderCanColorHair = {
    male = true,
    female = true
}
RACE.muscles = {
    male = false,
    female = false
}
RACE.broadShoulders = true
RACE.scale = 0.85
RACE.baseHealth = 275
RACE.resistance = 0
RACE.jumpBoost = 70
RACE.hasRadiation = false
RACE.chemWhitelist = {
    ["aid_stimpak"] = true,
    ["aid_superstimpak"] = true,
    ["aid_stealthboy"] = true,
    ["aid_healing_powder"] = true,
    ["aid_cleansing_powder"] = true,
    ["aid_radaway"] = true,
    ["aid_daytripper"] = true,
    ["aid_daddyo"] = true,
    ["injector_behemoth"] = true,
    ["injector_behemoth_unity"] = true,
    ["injector_centaur"] = true
}
RACE.viewOffset = {
    normal = Vector(0,0,80),
    ducked = Vector(0,0,80)
}
RACE.hull = {
    normal = Vector(16,16,72),
    ducked = Vector(16,16,72)
}
RACE.raceColor = Color(5, 92, 5)
RACE.editorAnimation = "idle"
