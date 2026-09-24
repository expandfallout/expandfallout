--[[
	Behemoth.

	GENERATED from Phoenix's `libs/races/supermutants/sh_race_behemoth.lua`.
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
	    painSounds
	    deathSounds
	    footstepSounds

	3 of 4 models are not installed and are filtered at load.
]]

RACE.name = "Behemoth"
RACE.class = "behemoth"
RACE.description = ""
RACE.defaultFaction = ""
RACE.animationModel = "models/fallout/supermutant_behemoth.mdl"
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
    male = "models/fallout/supermutant_behemoth.mdl",
    female = "models/fallout/supermutant_behemoth.mdl"
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
    male = {
        default = {
            [2] = 1
        }
    },
    female = {
        default = {
            [2] = 1
        }
    }
}
RACE.genderCanColorHair = {
    male = true,
    female = true
}
RACE.muscles = false -- Deprecated
RACE.scale = 0.85
RACE.baseHealth = 10000
RACE.resistance = 0
RACE.jumpBoost = 350
RACE.hasRadiation = false
RACE.canEquipWeapons = false
RACE.canEquipArmors = true
RACE.noSelectRaces = {
}
RACE.noInjector = true
RACE.viewOffset = {
    normal = Vector(0,0,185),
    ducked = Vector(0,0,225)
}
RACE.hull = {
    normal = Vector(16,16,225),
    ducked = Vector(16,16,225)
}
RACE.raceColor = Color(5, 92, 5)
RACE.editorAnimation = "mtidle"
RACE.spawnMessage = {
    Color(255,255,255), "You are a ", Color(255,0,0), "Behemoth", Color(255,255,255), ".\n",
    "You are ", Color(255,0,0), "KOS.",Color(255,255,255), " You must attack other players on sight, unless you are a unity controlled Behemoth.\n\n",
    Color(255,255,0), "Raise your Fists to preform attacks.\n",
    Color(255,255,255), "[Mouse 1] - Melee Attack.\n[Mouse 2] - Rock Throw.\n[R] - Ground Slam."
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
ix.anim.SetModelClass("models/fallout/supermutant_behemoth.mdl", "behemoth")
