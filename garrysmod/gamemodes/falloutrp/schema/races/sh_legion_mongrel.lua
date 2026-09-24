--[[
	Legion Mongrel.

	GENERATED from Phoenix's `libs/races/dogs/sh_race_dog_legion.lua`.
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
	    emotes
	    painSounds
	    deathSounds
	    footstepSounds
]]

RACE.name = "Legion Mongrel"
RACE.class = "legion_mongrel"
RACE.description = ""
RACE.defaultFaction = ""
RACE.animationModel = "models/fallout/dogvicious.mdl"
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
    male = "models/fallout/dogvicious.mdl",
    female = "models/fallout/dogvicious.mdl"
}
RACE.skins = {
    male = {
        default = 1
    },
    female = {
        default = 0
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
RACE.raceBodygroups = {
}
RACE.genderCanColorHair = {
    male = true,
    female = true
}
RACE.muscles = false -- Deprecated
RACE.scale = 0.85
RACE.baseHealth = 250
RACE.resistance = 0
RACE.jumpBoost = 85
RACE.hasRadiation = false
RACE.canEquipWeapons = false
RACE.canEquipArmors = true
RACE.noSelectRaces = {
}
RACE.viewOffset = {
    normal = Vector(0,0,32),
    ducked = Vector(0,0,32)
}
RACE.hull = {
    normal = Vector(16,16,32),
    ducked = Vector(16,16,32)
}
RACE.raceColor = Color(255, 155, 0)
RACE.editorAnimation = "mtidle"
RACE.spawnMessage = {
    Color(255,255,255), "You are a ", Color(0,255,0), "Dog", Color(255,255,255), ".\n",
    "You are ", Color(255,255,0), "Optional KOS.",Color(255,255,255),
    Color(255,255,0), "\n\nRaise your Fists to preform attacks.\n",
    Color(255,255,255), "[Mouse 1] - Melee Attack. [Mouse 2] - Bark."
}

--[[
	The animation class for this race's model.

	Without it the race falls back to Half-Life 2 player
	animations, which is a character standing with its arms out,
	sliding rather than walking. The SET itself is in
	`libs/sh_raceanims.lua`, which loads first - several races
	share one, and a table defined in a sibling race file would
	make this depend on alphabetical load order.
]]
ix.anim.SetModelClass("models/fallout/dogskin.mdl", "dog")
