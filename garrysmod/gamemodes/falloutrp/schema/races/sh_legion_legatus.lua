--[[
	Legatus.

	GENERATED from Phoenix's `libs/races/radroaches/sh_race_legate.lua`.
	Re-run `_docs/tools/genraces.py` rather than editing.

	NOT CARRIED ACROSS - these are function fields whose bodies
	call `nut.` APIs this schema does not have, and a function
	that fails when somebody triggers it is worse than one that
	is absent:

	    OnSpawn
	    startingGear
	    emotes
	    voiceLines
	    painSounds
	    deathSounds
]]

RACE.name = "Legatus"
RACE.class = "legion_legatus"
RACE.description = "The Beast of the East, massacrer of many, servant of Mars."
RACE.defaultFaction = "wastelanders"
RACE.animationModel = "models/phoenix/humans/animations.mdl"
RACE.hideBody = true
RACE.genders = {
    male = true,
    female = false
}
RACE.races = {
    male = {
        "caucasian",
        "african",
        "asian",
        "hispanic",
        "ghoul"
    },
    female = {
        "caucasian",
        "african",
        "asian",
        "hispanic",
        "ghoul"
    }
}
RACE.defaultModels = {
    male = "models/roadkill/fallout/player/male/defaultbody.mdl"
}
RACE.skins = {
    male = {
        caucasian = 0,
        african = 1,
        hispanic = 2,
        asian = 3,
        ghoul = 4
    },
    female = {
        caucasian = 0,
        african = 1,
        hispanic = 2,
        asian = 3,
        ghoul = 4
    }
}
RACE.heads = {
    male = {
        caucasian = "models/roadkill/fallout/player/male/head.mdl",
        african = "models/roadkill/fallout/player/male/head.mdl",
        asian = "models/roadkill/fallout/player/male/head.mdl",
        hispanic = "models/roadkill/fallout/player/male/head.mdl",
        ghoul = "models/roadkill/fallout/player/male/headghoul.mdl"
    },
    female = {
        caucasian = "models/roadkill/fallout/player/female/head.mdl",
        african = "models/roadkill/fallout/player/female/head.mdl",
        asian = "models/roadkill/fallout/player/female/head.mdl",
        hispanic = "models/roadkill/fallout/player/female/head.mdl",
        ghoul = "models/roadkill/fallout/player/female/headghoul.mdl"
    }
}
RACE.hairs = {
    male = {
        "models/roadkill/fallout/player/male/hair/buzz_cut.mdl",
        "models/roadkill/fallout/player/male/hair/pompadour.mdl",
        "models/roadkill/fallout/player/male/hair/punked.mdl",
        "models/roadkill/fallout/player/male/hair/sarge.mdl",
        "models/roadkill/fallout/player/male/hair/shaggy_suave.mdl",
        "models/roadkill/fallout/player/male/hair/smooth_wave.mdl",
        "models/roadkill/fallout/player/male/hair/terrorsaur.mdl",
        "models/roadkill/fallout/player/male/hair/tunnel_snake.mdl",
        "models/roadkill/fallout/player/male/hair/warhawk.mdl",
        "models/roadkill/fallout/player/male/hair/waster.mdl"
    },
    female = {
        "models/roadkill/fallout/player/female/hair/bedraggled.mdl",
        "models/roadkill/fallout/player/female/hair/blast_back.mdl",
        "models/roadkill/fallout/player/female/hair/buzz_cut.mdl",
        "models/roadkill/fallout/player/female/hair/clean_cut.mdl",
        "models/roadkill/fallout/player/female/hair/domestic_goddess.mdl",
        "models/roadkill/fallout/player/female/hair/fairytails.mdl",
        "models/roadkill/fallout/player/female/hair/fallen_angel.mdl",
        "models/roadkill/fallout/player/female/hair/frazzled.mdl",
        "models/roadkill/fallout/player/female/hair/iron_maiden.mdl",
        "models/roadkill/fallout/player/female/hair/lil_devil.mdl",
        "models/roadkill/fallout/player/female/hair/mangy.mdl",
        "models/roadkill/fallout/player/female/hair/no_nonsense.mdl",
        "models/roadkill/fallout/player/female/hair/pretty_cherry.mdl",
        "models/roadkill/fallout/player/female/hair/pretty_puff.mdl",
        "models/roadkill/fallout/player/female/hair/prim_n-proper.mdl",
        "models/roadkill/fallout/player/female/hair/rough_nite.mdl",
        "models/roadkill/fallout/player/female/hair/rude_ridge.mdl",
        "models/roadkill/fallout/player/female/hair/sarge.mdl",
        "models/roadkill/fallout/player/female/hair/seductress.mdl",
        "models/roadkill/fallout/player/female/hair/the_sophisticate.mdl",
        "models/roadkill/fallout/player/female/hair/unladylike.mdl",
        "models/roadkill/fallout/player/female/hair/wendy_the_welder.mdl"
    }
}
RACE.beards = {
    male = {
        "models/roadkill/fallout/player/male/beard/chincurtain.mdl",
        "models/roadkill/fallout/player/male/beard/chinstrip.mdl",
        "models/roadkill/fallout/player/male/beard/chinwide.mdl",
        "models/roadkill/fallout/player/male/beard/chopper.mdl",
        "models/roadkill/fallout/player/male/beard/circle.mdl",
        "models/roadkill/fallout/player/male/beard/full.mdl",
        "models/roadkill/fallout/player/male/beard/goatee.mdl",
        "models/roadkill/fallout/player/male/beard/goateewide.mdl",
        "models/roadkill/fallout/player/male/beard/mustache.mdl",
        "models/roadkill/fallout/player/male/beard/mustachecurly.mdl",
        "models/roadkill/fallout/player/male/beard/muttonchops.mdl",
        "models/roadkill/fallout/player/male/beard/sideburns.mdl",
        "models/roadkill/fallout/player/male/beard/soulpatch.mdl",
        "models/roadkill/fallout/player/male/beard/thin.mdl"
    },
    female = false

}
RACE.faceSkins = {
    male = {
        caucasian = {
            "phoenix/humans/shared/skin/caucasian_facemap_lanius"
        },
        african = {
            "phoenix/humans/shared/skin/caucasian_facemap_lanius"
        },
        asian = {
            "phoenix/humans/shared/skin/caucasian_facemap_lanius"
        },
        hispanic = {
            "phoenix/humans/shared/skin/caucasian_facemap_lanius"
        }
    },
    female = {
        caucasian = {
            "phoenix/humans/shared/skin/female/caucasian_facemap",
            "phoenix/humans/shared/skin/female/caucasian_facemap_30",
            "phoenix/humans/shared/skin/female/caucasian_facemap_40",
            "phoenix/humans/shared/skin/female/caucasian_facemap_50",
            "phoenix/humans/shared/skin/female/caucasian_facemap_legateslave",
            "phoenix/humans/shared/skin/female/caucasian_facemap_raider1",
            "phoenix/humans/shared/skin/female/caucasian_facemap_raider2",
            "phoenix/humans/shared/skin/female/caucasian_facemap_raider3",
            "phoenix/humans/shared/skin/female/caucasian_facemap_raider4",
            "phoenix/humans/shared/skin/female/caucasian_facemap_siri",
            "phoenix/humans/shared/skin/female/caucasian_facemap_slave1",
            "phoenix/humans/shared/skin/female/caucasian_facemap_slave2"
        },
        african = {
            "phoenix/humans/shared/skin/female/african_facemap",
            "phoenix/humans/shared/skin/female/african_facemap_30",
            "phoenix/humans/shared/skin/female/african_facemap_40",
            "phoenix/humans/shared/skin/female/african_facemap_50",
            "phoenix/humans/shared/skin/female/african_facemap_legateslave",
            "phoenix/humans/shared/skin/female/african_facemap_raider1",
            "phoenix/humans/shared/skin/female/african_facemap_raider2",
            "phoenix/humans/shared/skin/female/african_facemap_raider3",
            "phoenix/humans/shared/skin/female/african_facemap_raider4",
            "phoenix/humans/shared/skin/female/african_facemap_siri",
            "phoenix/humans/shared/skin/female/african_facemap_slave1",
            "phoenix/humans/shared/skin/female/african_facemap_slave2"
        },
        asian = {
            "phoenix/humans/shared/skin/female/asian_facemap",
            "phoenix/humans/shared/skin/female/asian_facemap_30",
            "phoenix/humans/shared/skin/female/asian_facemap_40",
            "phoenix/humans/shared/skin/female/asian_facemap_50",
            "phoenix/humans/shared/skin/female/asian_facemap_legateslave",
            "phoenix/humans/shared/skin/female/asian_facemap_raider1",
            "phoenix/humans/shared/skin/female/asian_facemap_raider2",
            "phoenix/humans/shared/skin/female/asian_facemap_raider3",
            "phoenix/humans/shared/skin/female/asian_facemap_raider4",
            "phoenix/humans/shared/skin/female/asian_facemap_siri",
            "phoenix/humans/shared/skin/female/asian_facemap_slave1",
            "phoenix/humans/shared/skin/female/asian_facemap_slave2"
        },
        hispanic = {
            "phoenix/humans/shared/skin/female/hispanic_facemap",
            "phoenix/humans/shared/skin/female/hispanic_facemap_30",
            "phoenix/humans/shared/skin/female/hispanic_facemap_40",
            "phoenix/humans/shared/skin/female/hispanic_facemap_50",
            "phoenix/humans/shared/skin/female/hispanic_facemap_legateslave",
            "phoenix/humans/shared/skin/female/hispanic_facemap_raider1",
            "phoenix/humans/shared/skin/female/hispanic_facemap_raider2",
            "phoenix/humans/shared/skin/female/hispanic_facemap_raider3",
            "phoenix/humans/shared/skin/female/hispanic_facemap_raider4",
            "phoenix/humans/shared/skin/female/hispanic_facemap_siri",
            "phoenix/humans/shared/skin/female/hispanic_facemap_slave1",
            "phoenix/humans/shared/skin/female/hispanic_facemap_slave2"
        }
    }
}
RACE.headSubMaterials = {
    male = 6,
    female = 0
}
RACE.genderCanColorHair = {
    male = true,
    female = true
}
RACE.muscles = {
    male = true,
    female = true
}
RACE.broadShoulders = true
RACE.scale = 0.95
RACE.baseHealth = 130
RACE.chemBlacklist = { -- Disable these chems. 
    ["aid_robotrepairkit"] = true,
    ["aid_jet"] = true,
    ["aid_psycho"] = true,
    ["aid_turbo"] = true,
    ["aid_daytripper"] = true
}
RACE.viewOffset = {
    normal = Vector(0,0,73),
    ducked = Vector(0,0,40)
}
RACE.hull = {
    normal = Vector(16,16,72),
    ducked = Vector(16,16,48)
}
RACE.raceColor = Color(247, 208, 124)
RACE.editorAnimation = "mtidle"
