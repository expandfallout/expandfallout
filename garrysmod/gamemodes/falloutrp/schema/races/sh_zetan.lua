--[[
	Zetan.

	GENERATED from Phoenix's `libs/races/races/sh_race_zetan.lua`.
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

RACE.name = "Zetan"
RACE.class = "zetan"
RACE.description = "A extraterrestrial race, known for their advanced technology and mysterious origins."
RACE.defaultFaction = "zetan"
RACE.animationModel = "models/roadkill_fallout/player/zetan/defaultbody.mdl"
RACE.hideBody = true
RACE.genders = {
    male = true,
    female = true
}
RACE.races = {
    male = {
        "zetan"
    },
    female = {
        "zetan"
    }
}
RACE.defaultModels = {
    male = "models/roadkill_fallout/player/zetan/defaultbody.mdl",
    female = "models/roadkill_fallout/player/zetan/defaultbody.mdl"
}
RACE.skins = {
    male = {
        zetan = 0
    },
    female = {
        zetan = 0
    }
}
RACE.heads = {
    male = {
        zetan = false
    },
    female = {
        zetan = false
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
ix.anim.SetModelClass("models/roadkill_fallout/player/zetan/defaultbody.mdl", "zetan")
