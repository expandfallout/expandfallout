--[[
	Robobrain.

	GENERATED from Phoenix's `libs/races/robots/sh_race_robobrain.lua`.
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

RACE.name = "Robobrain"
RACE.class = "robobrain"
RACE.description = "A Vault-Tec engineered robotic brain unit, designed for various tasks including combat and labor."
RACE.defaultFaction = "vaulttec"
RACE.animationModel = "models/roadkill_fallout/robots/robobrain.mdl"
RACE.hideBody = true
RACE.genders = {
    male = true,
    female = true
}
RACE.races = {
    male = {
        "robobrain"
    },
    female = {
        "robobrain"
    }
}
RACE.defaultModels = {
    male = "models/roadkill_fallout/robots/robobrain.mdl",
    female = "models/roadkill_fallout/robots/robobrain.mdl"
}
RACE.skins = {
    male = {
        robobrain = 0
    },
    female = {
        robobrain = 0
    }
}
RACE.heads = {
    male = {
        robobrain = false
    },
    female = {
        robobrain = false
    }
}
RACE.hairs = {
    male = false,
    female = false
}
RACE.beards = {
    male = false
}
RACE.faceSkins = {
    male = false,
    female = false
}
RACE.genderCanColorHair = {
    male = false,
    female = false
}
RACE.muscles = {
    male = false,
    female = false
}
RACE.scale = 0.85
RACE.baseHealth = 100
RACE.resistance = 0
RACE.jumpBoost = 50
RACE.hasHunger = false
RACE.hasRadiation = false
RACE.viewOffset = {
    normal = Vector(0, 0, 60),
    ducked = Vector(0, 0, 60)
}
RACE.hull = {
    normal = Vector(16, 16, 60),
    ducked = Vector(16, 16, 60)
}
RACE.raceColor = Color(0, 255, 255)
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
ix.anim.SetModelClass("models/roadkill_fallout/robots/robobrain.mdl", "robobrain")
