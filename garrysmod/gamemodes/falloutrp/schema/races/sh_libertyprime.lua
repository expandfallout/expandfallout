--[[
	Liberty Prime.

	GENERATED from Phoenix's `libs/races/robots/sh_race_libertyprime.lua`.
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
	    ragdollOverride

	4 of 6 models are not installed and are filtered at load.
]]

RACE.name = "Liberty Prime"
RACE.class = "libertyprime"
RACE.description = ""
RACE.defaultFaction = ""
RACE.animationModel = "models/fallout/libertyprime.mdl"
RACE.hideBody = false
RACE.genders = {
    male = true,
    female = true
}
RACE.races = {
    male = {
        "liberty"
    },
    female = {
        "liberty"
    }
}
RACE.defaultModels = {
    male = false,
    female = false
}
RACE.skins = {
    male = {
        liberty = 0
    },
    female = {
        liberty = 0
    }
}
RACE.heads = {
    male = {
        liberty = false
    },
    female = {
        liberty = false
    }
}
RACE.hairs = false
RACE.beards = false
RACE.faceSkins = {
    male = false,
    female = false
}
RACE.genderCanColorHair = {
    male = true,
    female = true
}
RACE.muscles = false -- Deprecated
RACE.scale = 0.85
RACE.baseHealth = 30000
RACE.resistance = 0
RACE.jumpBoost = 0
RACE.hasHunger = false
RACE.hasRadiation = false
RACE.canEquipWeapons = false
RACE.canEquipArmors = true
RACE.viewOffset = {
    normal = Vector(0, 0, 500),
    ducked = Vector(0, 0, 500)
}
RACE.hull = {
    normal = Vector(16, 16, 500),
    ducked = Vector(16, 16, 500)
}
RACE.raceColor = Color(5, 92, 5)
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
ix.anim.SetModelClass("models/fallout/libertyprime.mdl", "liberty")
