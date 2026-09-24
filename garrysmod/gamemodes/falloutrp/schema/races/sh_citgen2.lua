--[[
	Generation 2 Synth.

	GENERATED from Phoenix's `libs/races/cit/sh_race_citgen2.lua`.
	Re-run `_docs/tools/genraces.py` rather than editing.

	NOT CARRIED ACROSS - these are function fields whose bodies
	call `nut.` APIs this schema does not have, and a function
	that fails when somebody triggers it is worse than one that
	is absent:

	    startingGear
	    emotes
	    voiceLines
	    painSounds
	    deathSounds
]]

RACE.name = "Generation 2 Synth"
RACE.class = "citgen2"
RACE.description = "A C.I.T Generation 2 Synth, designed to kind of look and act like a human."
RACE.defaultFaction = "wastelanders"
RACE.animationModel = "models/phoenix/humans/animations.mdl"
RACE.genders = {
    male = true,
    female = true
}
RACE.races = {
    male = {
        "synth"
    },
    female = {
        "synth"
    }
}
RACE.defaultModels = {
    male = "models/mosi/fallout4/player/gen2_body.mdl",
    female = "models/mosi/fallout4/player/gen2_body.mdl"
}
RACE.skins = {
    male = {
        synth = 0
    },
    female = {
        synth = 0
    }
}
RACE.heads = {
    male = {
        synth = "models/mosi/fallout4/player/gen2_head.mdl"
    },
    female = {
        synth = "models/mosi/fallout4/player/gen2_head.mdl"
    }
}
RACE.hairs = {
    male = false,
    female = false
}
RACE.beards = {
    male = false,
    female = false
}
RACE.faceSkins = {
    male = false,
    female = false
}
RACE.headSubMaterials = false
RACE.genderCanColorHair = false
RACE.muscles = false
RACE.scale = 0.85
RACE.baseHealth = 100
RACE.chemBlacklist = { -- Disable these chems. 
    ["aid_robotrepairkit"] = true
}
RACE.noInjector = true
RACE.viewOffset = {
    normal = Vector(0,0,66),
    ducked = Vector(0,0,40)
}
RACE.hull = {
    normal = Vector(16,16,72),
    ducked = Vector(16,16,48)
}
RACE.raceColor = Color(247, 208, 124)
RACE.editorAnimation = "mtidle"
