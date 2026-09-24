--[[
	Deathclaw.

	GENERATED from Phoenix's `libs/races/deathclaws/sh_race_deathclaw.lua`.
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

RACE.name = "Deathclaw"
RACE.class = "deathclaw"
RACE.description = ""
RACE.defaultFaction = ""
RACE.animationModel = "models/fallout/deathclaw.mdl"
RACE.hideBody = true
RACE.genders = {
    male = true,
    female = false
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
    male = "models/fallout/deathclaw.mdl",
    female = "models/fallout/deathclaw.mdl"
}
RACE.skins = {
    male = {
        default = 0
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
RACE.baseHealth = 750
RACE.resistance = 0
RACE.jumpBoost = 125
RACE.hasRadiation = false
RACE.canEquipWeapons = false
RACE.canEquipArmors = true
RACE.noSelectRaces = {
}
RACE.viewOffset = {
    normal = Vector(0,0,100),
    ducked = Vector(0,0,90)
}
RACE.hull = {
    normal = Vector(16,16,105),
    ducked = Vector(16,16,90)
}
RACE.raceColor = Color(200, 0, 0)
RACE.editorAnimation = "mtidle"
RACE.spawnMessage = {
    Color(255,255,255), "You are a ", Color(255,0,0), "Deathclaw", Color(255,255,255), ".\n",
    "You are ", Color(255,0,0), "KOS.",Color(255,255,255), " You must attack other players on sight.\n\n",
    Color(255,255,0), "Raise your Fists to preform attacks.\n",
    Color(255,255,255), "[Mouse 1] - Melee Attack."
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
ix.anim.SetModelClass("models/fallout/deathclaw.mdl", "deathclaw")
