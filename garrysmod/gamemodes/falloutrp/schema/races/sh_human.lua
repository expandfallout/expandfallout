--[[
	S.P.E.C.I.A.L. schema race - Human.

	Ported from Phoenix's `libs/races/sh_race_human.lua`. The appearance tables
	are their data verbatim; what changed is the surrounding contract, which is
	`ix.races` rather than `nut.races`.

	CONTENT STATUS at time of writing - see `fo_races_report` for the live
	answer, which is the one that counts:

	    bodies    male + female       installed (af_content_pack_1)
	    heads     both, incl. ghoul   installed
	    hairs     10 male, 22 female  installed
	    beards    14 male             NOT INSTALLED
	    faceSkins 112 materials       NOT INSTALLED (phoenix_anims ships only
	                                  the animation model, not the face pack)

	The unavailable ones are left declared rather than deleted. `ix.races` drops
	what is missing at load, so adding the content later needs a restart and no
	code change - and the declaration is the record of what this race is
	supposed to have.

	`RACE.startingGear` is deliberately NOT ported. Phoenix's list names items
	like `armorv2_wasteland_wanderer` and `weapon_9mm_pistol_rusty` that do not
	exist in this schema, and handing a spawn hook item IDs that resolve to
	nothing is a runtime error rather than a missing pistol.
]]

RACE.name = "Human"
RACE.class = "human"
RACE.description = "A member of the human species, known for their adaptability " ..
	"and resilience in the wasteland."
RACE.defaultFaction = "wastelanders"

--[[
	The meshless animation carrier. Every visible part is bone-merged onto it -
	see `libs/cl_bodyparts.lua` for why, and `hideBody` is what declares the
	intent even though this particular model has no mesh to hide.
]]
RACE.animationModel = "models/phoenix/humans/animations.mdl"
RACE.hideBody = true

RACE.genders = {
	male = true,
	female = true
}

RACE.races = {
	male = {
		"caucasian",
		"african",
		"asian",
		"hispanic",
		"ghoul",
	},
	female = {
		"caucasian",
		"african",
		"asian",
		"hispanic",
		"ghoul",
	},
}

RACE.defaultModels = {
	male = "models/roadkill/fallout/player/male/defaultbody.mdl",
	female = "models/roadkill/fallout/player/female/defaultbody.mdl"
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
	},
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
	},
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
	female = false,

}

RACE.faceSkins = {
	male = {
		caucasian = {
			"phoenix/humans/shared/skin/caucasian_facemap",
			"phoenix/humans/shared/skin/caucasian_facemap_30",
			"phoenix/humans/shared/skin/caucasian_facemap_40",
			"phoenix/humans/shared/skin/caucasian_facemap_50",
			"phoenix/humans/shared/skin/caucasian_facemap_benny",
			"phoenix/humans/shared/skin/caucasian_facemap_boone",
			"phoenix/humans/shared/skin/caucasian_facemap_caesar",
			"phoenix/humans/shared/skin/caucasian_facemap_lanius",
			"phoenix/humans/shared/skin/caucasian_facemap_lobotomite",
			"phoenix/humans/shared/skin/caucasian_facemap_old",
			"phoenix/humans/shared/skin/caucasian_facemap_raider1",
			"phoenix/humans/shared/skin/caucasian_facemap_raider2",
			"phoenix/humans/shared/skin/caucasian_facemap_raider3",
			"phoenix/humans/shared/skin/caucasian_facemap_raider4",
			"phoenix/humans/shared/skin/caucasian_facemap_rangerandy",
			"phoenix/humans/shared/skin/caucasian_facemap_rugged",
		},
		african = {
			"phoenix/humans/shared/skin/african_facemap",
			"phoenix/humans/shared/skin/african_facemap_30",
			"phoenix/humans/shared/skin/african_facemap_30",
			"phoenix/humans/shared/skin/african_facemap_40",
			"phoenix/humans/shared/skin/african_facemap_50",
			"phoenix/humans/shared/skin/african_facemap_benny",
			"phoenix/humans/shared/skin/african_facemap_boone",
			"phoenix/humans/shared/skin/african_facemap_caesar",
			"phoenix/humans/shared/skin/african_facemap_lanius",
			"phoenix/humans/shared/skin/african_facemap_lobotomite",
			"phoenix/humans/shared/skin/african_facemap_old",
			"phoenix/humans/shared/skin/african_facemap_raider1",
			"phoenix/humans/shared/skin/african_facemap_raider2",
			"phoenix/humans/shared/skin/african_facemap_raider3",
			"phoenix/humans/shared/skin/african_facemap_raider4",
			"phoenix/humans/shared/skin/african_facemap_rangerandy",
			"phoenix/humans/shared/skin/african_facemap_rugged",
		},
		asian = {
			"phoenix/humans/shared/skin/asian_facemap",
			"phoenix/humans/shared/skin/asian_facemap_30",
			"phoenix/humans/shared/skin/asian_facemap_40",
			"phoenix/humans/shared/skin/asian_facemap_50",
			"phoenix/humans/shared/skin/asian_facemap_benny",
			"phoenix/humans/shared/skin/asian_facemap_boone",
			"phoenix/humans/shared/skin/asian_facemap_caesar",
			"phoenix/humans/shared/skin/asian_facemap_lanius",
			"phoenix/humans/shared/skin/asian_facemap_lobotomite",
			"phoenix/humans/shared/skin/asian_facemap_old",
			"phoenix/humans/shared/skin/asian_facemap_raider1",
			"phoenix/humans/shared/skin/asian_facemap_raider2",
			"phoenix/humans/shared/skin/asian_facemap_raider3",
			"phoenix/humans/shared/skin/asian_facemap_raider4",
			"phoenix/humans/shared/skin/asian_facemap_rangerandy",
			"phoenix/humans/shared/skin/asian_facemap_rugged",
		},
		hispanic = {
			"phoenix/humans/shared/skin/hispanic_facemap",
			"phoenix/humans/shared/skin/hispanic_facemap_30",
			"phoenix/humans/shared/skin/hispanic_facemap_40",
			"phoenix/humans/shared/skin/hispanic_facemap_50",
			"phoenix/humans/shared/skin/hispanic_facemap_benny",
			"phoenix/humans/shared/skin/hispanic_facemap_boone",
			"phoenix/humans/shared/skin/hispanic_facemap_caesar",
			"phoenix/humans/shared/skin/hispanic_facemap_lanius",
			"phoenix/humans/shared/skin/hispanic_facemap_lobotomite",
			"phoenix/humans/shared/skin/hispanic_facemap_old",
			"phoenix/humans/shared/skin/hispanic_facemap_raider1",
			"phoenix/humans/shared/skin/hispanic_facemap_raider2",
			"phoenix/humans/shared/skin/hispanic_facemap_raider3",
			"phoenix/humans/shared/skin/hispanic_facemap_raider4",
			"phoenix/humans/shared/skin/hispanic_facemap_rangerandy",
			"phoenix/humans/shared/skin/hispanic_facemap_rugged",
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
	},
}

RACE.headSubMaterials = {
	male = 6,
	female = 0
}


--[[
	Hair tint brightness, per gender.

	Colour modulation multiplies the texture, and this race's male and female
	hair textures are not equally bright, so one tint value cannot serve both:
	male hair needs roughly five times the modulation to land on the colour
	that was picked, female hair is correct at unity.

	This lives with the race rather than in the UI because it is a property of
	the ASSETS - a race shipping different hair models needs its own value, and
	nothing about the customiser can work it out on its own.
]]
RACE.hairBoost = {
	male = 5.0,
	female = 1.5
}

RACE.genderCanColorHair = {
	male = true,
	female = true,
}

RACE.muscles = {
	male = true,
	female = true,
}

RACE.scale = 0.85

RACE.baseHealth = 100

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
