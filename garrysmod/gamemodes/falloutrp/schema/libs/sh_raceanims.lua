--[[
	Every animation set the races use.

	Carried from Phoenix unchanged - `ix.anim` takes the same shape
	`nut.anim` did, so these are their tables renamed.

	IN ONE FILE, ON PURPOSE. Their sets are shared: the four deathclaws
	use one, both centaurs use one, and the table lives in whichever race
	file happened to define it first. Carrying them per race made every
	registration depend on its sibling having loaded already, which is
	alphabetical luck. `libs/` loads before `races/`, so putting them here
	means a race can register against any set without caring.

	GENERATED - re-run `_docs/tools/genraces.py`.
]]

ix.anim = ix.anim or {}

ix.anim.behemoth = {
    useADV = true,
    normal = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "2hmaim", "2hmaim"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "2hmaim", "2hmaim"},
        [ACT_MP_WALK] = {"walk", "walk", "walk"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk", "walk"},
        [ACT_MP_RUN] = {"mtfastforward", "mtfastforward", "mtfastforward"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        sprint = {"mtfastforward", "mtfastforward", "mtfastforward"}
    },
    fist = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "2hmaim", "2hmaim"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "2hmaim", "2hmaim"},
        [ACT_MP_WALK] = {"walk", "walk", "walk"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk", "walk"},
        [ACT_MP_RUN] = {"mtfastforward", "mtfastforward", "mtfastforward"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        sprint = {"mtfastforward", "mtfastforward", "mtfastforward"}
    },
    ["h2h"] = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "2hmaim", "2hmaim"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "2hmaim", "2hmaim"},
        [ACT_MP_WALK] = {"walk", "walk", "walk"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk", "walk"},
        [ACT_MP_RUN] = {"mtfastforward", "mtfastforward", "mtfastforward"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        sprint = {"mtfastforward", "mtfastforward", "mtfastforward"}
    },
}

ix.anim.centaur = {
    useADV = true,
    normal = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_WALK] = {"walk", "walk", "walk"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk", "walk"},
        [ACT_MP_RUN] = {"mtfastforward", "mtfastforward", "mtfastforward"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        sprint = {"walk", "walk", "walk"}
    },
    fist = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_WALK] = {"walk", "walk", "walk"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk", "walk"},
        [ACT_MP_RUN] = {"mtfastforward", "mtfastforward", "mtfastforward"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        sprint = {"walk", "walk", "walk"}
    },
    ["h2h"] = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_WALK] = {"walk", "walk", "walk"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk", "walk"},
        [ACT_MP_RUN] = {"mtfastforward", "mtfastforward", "mtfastforward"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        sprint = {"walk", "walk", "walk"}
    },
}

ix.anim.deathclaw = {
    useADV = true,
    normal = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_WALK] = {"walk", "walk", "walk"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk", "walk"},
        [ACT_MP_RUN] = {"run", "run", "run"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        sprint = {"run", "run", "run"}
    },
    fist = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_WALK] = {"walk", "walk", "walk"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk", "walk"},
        [ACT_MP_RUN] = {"run", "run", "run"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        sprint = {"run", "run", "run"}
    },
    ["h2h"] = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_WALK] = {"walk", "walk", "walk"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk", "walk"},
        [ACT_MP_RUN] = {"run", "run", "run"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        sprint = {"run", "run", "run"}
    },
}

ix.anim.dog = {
    useADV = true,
    normal = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_WALK] = {"walk", "walk_h2h", "walk_h2h"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk_h2h", "walk_h2h"},
        [ACT_MP_RUN] = {"sprint", "sprint", "sprint"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        sprint = {"run", "run", "run"}
    },
    fist = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_WALK] = {"walk", "walk_h2h", "walk_h2h"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk_h2h", "walk_h2h"},
        [ACT_MP_RUN] = {"sprint", "sprint", "sprint"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        sprint = {"run", "run", "run"}
    },
    ["h2h"] = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_WALK] = {"walk", "walk_h2h", "walk_h2h"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk_h2h", "walk_h2h"},
        [ACT_MP_RUN] = {"sprint", "sprint", "sprint"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        sprint = {"run", "run", "run"}
    },
}

ix.anim.eyebot = {
    useADV = true,
    normal = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "mtidle", "mtidle"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "mtidle", "mtidle"},
        [ACT_MP_WALK] = {"walk", "walk", "walk"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk", "walk"},
        [ACT_MP_RUN] = {"walk", "walk", "walk"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        sprint = {"walk", "walk", "walk"}
    },
    fist = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "mtidle", "mtidle"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "mtidle", "mtidle"},
        [ACT_MP_WALK] = {"walk", "walk", "walk"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk", "walk"},
        [ACT_MP_RUN] = {"walk", "walk", "walk"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        sprint = {"walk", "walk", "walk"}
    },
    ["h2h"] = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "mtidle", "mtidle"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "mtidle", "mtidle"},
        [ACT_MP_WALK] = {"walk", "walk", "walk"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk", "walk"},
        [ACT_MP_RUN] = {"walk", "walk", "walk"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        sprint = {"walk", "walk", "walk"}
    },
}

ix.anim.feralghoul = {
    useADV = true,
    normal = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_WALK] = {"walk", "walk", "walk"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk", "walk"},
        [ACT_MP_RUN] = {"run", "run", "run"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        sprint = {"run", "run", "run"}
    },
    fist = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_WALK] = {"walk", "walk", "walk"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk", "walk"},
        [ACT_MP_RUN] = {"run", "run", "run"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        sprint = {"run", "run", "run"}
    },
    ["h2h"] = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_WALK] = {"walk", "walk", "walk"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk", "walk"},
        [ACT_MP_RUN] = {"run", "run", "run"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        sprint = {"run", "run", "run"}
    },
}

ix.anim.gecko = {
    useADV = true,
    normal = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_WALK] = {"mtforward", "mtforward", "mtforward"},
        [ACT_MP_CROUCHWALK] = {"mtforward", "mtforward", "mtforward"},
        [ACT_MP_RUN] = {"mtfastforward", "mtfastforward", "mtfastforward"},
        [ACT_MP_SWIM] = {"mtforward"},
        attack = "",
        sprint = {"mtfastforward", "mtfastforward", "mtfastforward"}
    },
    fist = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_WALK] = {"mtforward", "mtforward", "mtforward"},
        [ACT_MP_CROUCHWALK] = {"mtforward", "mtforward", "mtforward"},
        [ACT_MP_RUN] = {"mtfastforward", "mtfastforward", "mtfastforward"},
        [ACT_MP_SWIM] = {"mtforward"},
        attack = "",
        sprint = {"mtfastforward", "mtfastforward", "mtfastforward"}
    },
    ["h2h"] = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_WALK] = {"mtforward", "mtforward", "mtforward"},
        [ACT_MP_CROUCHWALK] = {"mtforward", "mtforward", "mtforward"},
        [ACT_MP_RUN] = {"mtfastforward", "mtfastforward", "mtfastforward"},
        [ACT_MP_SWIM] = {"mtforward"},
        attack = "",
        sprint = {"mtfastforward", "mtfastforward", "mtfastforward"}
    },
}

ix.anim.giantant = {
    useADV = true,
    normal = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_WALK] = {"walk", "walk", "walk"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk", "walk"},
        [ACT_MP_RUN] = {"mtfastforward", "mtfastforward", "mtfastforward"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        sprint = {"mtfastforward", "mtfastforward", "mtfastforward"}
    },
    fist = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_WALK] = {"walk", "walk", "walk"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk", "walk"},
        [ACT_MP_RUN] = {"mtfastforward", "mtfastforward", "mtfastforward"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        sprint = {"mtfastforward", "mtfastforward", "mtfastforward"}
    },
    ["h2h"] = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_WALK] = {"walk", "walk", "walk"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk", "walk"},
        [ACT_MP_RUN] = {"mtfastforward", "mtfastforward", "mtfastforward"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        sprint = {"mtfastforward", "mtfastforward", "mtfastforward"}
    },
}

ix.anim.gutsy = {
    useADV = true,
    normal = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "1hmaim", "1hmaim"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "1hmaim", "1hmaim"},
        [ACT_MP_WALK] = {"walk", "walk", "walk"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk", "walk"},
        [ACT_MP_RUN] = {"walk", "walk", "walk"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        sprint = {"walk", "walk", "walk"}
    },
    fist = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "1hmaim", "1hmaim"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "1hmaim", "1hmaim"},
        [ACT_MP_WALK] = {"walk", "walk", "walk"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk", "walk"},
        [ACT_MP_RUN] = {"walk", "walk", "walk"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        sprint = {"walk", "walk", "walk"}
    },
    ["h2h"] = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "1hmaim", "1hmaim"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "1hmaim", "1hmaim"},
        [ACT_MP_WALK] = {"walk", "walk", "walk"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk", "walk"},
        [ACT_MP_RUN] = {"walk", "walk", "walk"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        sprint = {"walk", "walk", "walk"}
    },
}

ix.anim.liberty = {
    useADV = true,
    normal = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "mtidle", "mtidle"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "mtidle", "mtidle"},
        [ACT_MP_WALK] = {"walk", "walk", "walk"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk", "walk"},
        [ACT_MP_RUN] = {"walk", "walk", "walk"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        sprint = {"walk", "walk", "walk"}
    },
    fist = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "mtidle", "mtidle"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "mtidle", "mtidle"},
        [ACT_MP_WALK] = {"walk", "walk", "walk"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk", "walk"},
        [ACT_MP_RUN] = {"walk", "walk", "walk"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        sprint = {"walk", "walk", "walk"}
    },
    pistol = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "mtidle", "mtidle"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "mtidle", "mtidle"},
        [ACT_MP_WALK] = {"walk", "walk", "walk"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk", "walk"},
        [ACT_MP_RUN] = {"walk", "walk", "walk"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        reload = "",
        sprint = {"walk", "walk", "walk"}
    },
    ["h2h"] = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "mtidle", "mtidle"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "mtidle", "mtidle"},
        [ACT_MP_WALK] = {"walk", "walk", "walk"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk", "walk"},
        [ACT_MP_RUN] = {"walk", "walk", "walk"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        sprint = {"walk", "walk", "walk"}
    },
    ["1hp"] = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "mtidle", "mtidle"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "mtidle", "mtidle"},
        [ACT_MP_WALK] = {"walk", "walk", "walk"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk", "walk"},
        [ACT_MP_RUN] = {"walk", "walk", "walk"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        reload = "",
        sprint = {"walk", "walk", "walk"}
    },
    ["2hr"] = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "mtidle", "mtidle"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "mtidle", "mtidle"},
        [ACT_MP_WALK] = {"walk", "walk", "walk"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk", "walk"},
        [ACT_MP_RUN] = {"walk", "walk", "walk"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        reload = "",
        sprint = {"walk", "walk", "walk"}
    }
}

ix.anim.protectron = {
    useADV = true,
    normal = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "mtidle", "mtidle"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "mtidle", "mtidle"},
        [ACT_MP_WALK] = {"mtforward", "mtforward", "mtforward"},
        [ACT_MP_CROUCHWALK] = {"mtforward", "mtforward", "mtforward"},
        [ACT_MP_RUN] = {"mtfastforward", "mtfastforward", "mtfastforward"},
        [ACT_MP_SWIM] = {"mtforward"},
        attack = "",
        sprint = {"mtforward", "mtforward", "mtforward"}
    },
    fist = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "mtidle", "mtidle"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "mtidle", "mtidle"},
        [ACT_MP_WALK] = {"mtforward", "mtforward", "mtforward"},
        [ACT_MP_CROUCHWALK] = {"mtforward", "mtforward", "mtforward"},
        [ACT_MP_RUN] = {"mtfastforward", "mtfastforward", "mtfastforward"},
        [ACT_MP_SWIM] = {"mtforward"},
        attack = "",
        sprint = {"mtforward", "mtforward", "mtforward"}
    },
    pistol = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "1hp_mtidle", "1hp_mtidle"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "1hp_mtidle", "1hp_mtidle"},
        [ACT_MP_WALK] = {"mtforward", "1hp_mtforward", "1hp_mtforward"},
        [ACT_MP_CROUCHWALK] = {"mtforward", "1hp_mtforward", "1hp_mtforward"},
        [ACT_MP_RUN] = {"mtfastforward", "1hp_mtfastforward", "1hp_mtfastforward"},
        [ACT_MP_SWIM] = {"mtforward"},
        attack = "",
        reload = "",
        sprint = {"mtforward", "mtforward", "mtforward"}
    },
    ["h2h"] = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "1hp_mtidle", "1hp_mtidle"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "1hp_mtidle", "1hp_mtidle"},
        [ACT_MP_WALK] = {"mtforward", "1hp_mtforward", "1hp_mtforward"},
        [ACT_MP_CROUCHWALK] = {"mtforward", "1hp_mtforward", "1hp_mtforward"},
        [ACT_MP_RUN] = {"mtfastforward", "1hp_mtfastforward", "1hp_mtfastforward"},
        [ACT_MP_SWIM] = {"mtforward"},
        attack = "",
        reload = "",
        sprint = {"mtforward", "mtforward", "mtforward"}
    },
    ["1hp"] = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "1hp_mtidle", "1hp_mtidle"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "1hp_mtidle", "1hp_mtidle"},
        [ACT_MP_WALK] = {"mtforward", "1hp_mtforward", "1hp_mtforward"},
        [ACT_MP_CROUCHWALK] = {"mtforward", "1hp_mtforward", "1hp_mtforward"},
        [ACT_MP_RUN] = {"mtfastforward", "1hp_mtfastforward", "1hp_mtfastforward"},
        [ACT_MP_SWIM] = {"mtforward"},
        attack = "",
        reload = "",
        sprint = {"mtforward", "mtforward", "mtforward"}
    },
}

ix.anim.radroach = {
    useADV = true,
    normal = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_WALK] = {"mtforward", "mtforward", "mtforward"},
        [ACT_MP_CROUCHWALK] = {"mtforward", "mtforward", "mtforward"},
        [ACT_MP_RUN] = {"mtfastforward", "mtfastforward", "mtfastforward"},
        [ACT_MP_SWIM] = {"mtforward"},
        attack = "",
        sprint = {"mtfastforward", "mtfastforward", "mtfastforward"}
    },
    fist = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_WALK] = {"mtforward", "mtforward", "mtforward"},
        [ACT_MP_CROUCHWALK] = {"mtforward", "mtforward", "mtforward"},
        [ACT_MP_RUN] = {"mtfastforward", "mtfastforward", "mtfastforward"},
        [ACT_MP_SWIM] = {"mtforward"},
        attack = "",
        sprint = {"mtfastforward", "mtfastforward", "mtfastforward"}
    },
    ["h2h"] = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_WALK] = {"mtforward", "mtforward", "mtforward"},
        [ACT_MP_CROUCHWALK] = {"mtforward", "mtforward", "mtforward"},
        [ACT_MP_RUN] = {"mtfastforward", "mtfastforward", "mtfastforward"},
        [ACT_MP_SWIM] = {"mtforward"},
        attack = "",
        sprint = {"mtfastforward", "mtfastforward", "mtfastforward"}
    },
}

ix.anim.radscorpion = {
    useADV = true,
    normal = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_WALK] = {"walk", "walk", "walk"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk", "walk"},
        [ACT_MP_RUN] = {"mtfastforward", "mtfastforward", "mtfastforward"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        sprint = {"mtfastforward", "mtfastforward", "mtfastforward"}
    },
    fist = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_WALK] = {"walk", "walk", "walk"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk", "walk"},
        [ACT_MP_RUN] = {"mtfastforward", "mtfastforward", "mtfastforward"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        sprint = {"mtfastforward", "mtfastforward", "mtfastforward"}
    },
    ["h2h"] = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_WALK] = {"walk", "walk", "walk"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk", "walk"},
        [ACT_MP_RUN] = {"mtfastforward", "mtfastforward", "mtfastforward"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        sprint = {"mtfastforward", "mtfastforward", "mtfastforward"}
    },
}

ix.anim.robobrain = {
    useADV = true,
    normal = {
        [ACT_MP_STAND_IDLE] = {"idle", "idle_aim", "idle_aim"},
        [ACT_MP_CROUCH_IDLE] = {"idle", "idle_aim", "idle_aim"},
        [ACT_MP_WALK] = {"walk", "walk_aim", "walk_aim"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk_aim", "walk_aim"},
        [ACT_MP_RUN] = {"run", "run_aim", "run_aim"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        sprint = {"run", "run", "run"}
    },
    fist = {
        [ACT_MP_STAND_IDLE] = {"idle", "idle_aim", "idle_aim"},
        [ACT_MP_CROUCH_IDLE] = {"idle", "idle_aim", "idle_aim"},
        [ACT_MP_WALK] = {"walk", "walk_aim", "walk_aim"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk_aim", "walk_aim"},
        [ACT_MP_RUN] = {"run", "run_aim", "run_aim"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        sprint = {"run", "run", "run"}
    },
    pistol = {
        [ACT_MP_STAND_IDLE] = {"idle", "idle_aim", "idle_aim"},
        [ACT_MP_CROUCH_IDLE] = {"idle", "idle_aim", "idle_aim"},
        [ACT_MP_WALK] = {"walk", "walk_aim", "walk_aim"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk_aim", "walk_aim"},
        [ACT_MP_RUN] = {"run", "run_aim", "run_aim"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
    },
    ["h2h"] = {
        [ACT_MP_STAND_IDLE] = {"idle", "idle_aim", "idle_aim"},
        [ACT_MP_CROUCH_IDLE] = {"idle", "idle_aim", "idle_aim"},
        [ACT_MP_WALK] = {"walk", "walk_aim", "walk_aim"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk_aim", "walk_aim"},
        [ACT_MP_RUN] = {"run", "run_aim", "run_aim"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
    },
}

ix.anim.sentrybot = {
    useADV = true,
    normal = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "mtidle", "mtidle"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "mtidle", "mtidle"},
        [ACT_MP_WALK] = {"walk", "walk", "walk"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk", "walk"},
        [ACT_MP_RUN] = {"walk", "walk", "walk"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        sprint = {"walk", "walk", "walk"}
    },
    fist = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "mtidle", "mtidle"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "mtidle", "mtidle"},
        [ACT_MP_WALK] = {"walk", "walk", "walk"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk", "walk"},
        [ACT_MP_RUN] = {"walk", "walk", "walk"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        sprint = {"walk", "walk", "walk"}
    },
    pistol = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "mtidle", "mtidle"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "mtidle", "mtidle"},
        [ACT_MP_WALK] = {"walk", "walk", "walk"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk", "walk"},
        [ACT_MP_RUN] = {"walk", "walk", "walk"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        reload = "",
        sprint = {"walk", "walk", "walk"}
    },
    ["h2h"] = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "mtidle", "mtidle"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "mtidle", "mtidle"},
        [ACT_MP_WALK] = {"walk", "walk", "walk"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk", "walk"},
        [ACT_MP_RUN] = {"walk", "walk", "walk"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        sprint = {"walk", "walk", "walk"}
    },
    ["1hp"] = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "mtidle", "mtidle"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "mtidle", "mtidle"},
        [ACT_MP_WALK] = {"walk", "walk", "walk"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk", "walk"},
        [ACT_MP_RUN] = {"walk", "walk", "walk"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        reload = "",
        sprint = {"walk", "walk", "walk"}
    },
    ["2hr"] = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "mtidle", "mtidle"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "mtidle", "mtidle"},
        [ACT_MP_WALK] = {"walk", "walk", "walk"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk", "walk"},
        [ACT_MP_RUN] = {"walk", "walk", "walk"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        reload = "",
        sprint = {"walk", "walk", "walk"}
    }
}

ix.anim.sporecarrier = {
    useADV = true,
    normal = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_WALK] = {"walk", "walk", "walk"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk", "walk"},
        [ACT_MP_RUN] = {"mtfastforward", "mtfastforward", "mtfastforward"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        sprint = {"mtfastforward", "mtfastforward", "mtfastforward"}
    },
    fist = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_WALK] = {"walk", "walk", "walk"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk", "walk"},
        [ACT_MP_RUN] = {"mtfastforward", "mtfastforward", "mtfastforward"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        sprint = {"mtfastforward", "mtfastforward", "mtfastforward"}
    },
    ["h2h"] = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "h2haim", "h2haim"},
        [ACT_MP_WALK] = {"walk", "walk", "walk"},
        [ACT_MP_CROUCHWALK] = {"walk", "walk", "walk"},
        [ACT_MP_RUN] = {"mtfastforward", "mtfastforward", "mtfastforward"},
        [ACT_MP_SWIM] = {"walk"},
        attack = "",
        sprint = {"mtfastforward", "mtfastforward", "mtfastforward"}
    },
}

ix.anim.zetan = {
    useADV = true,
    normal = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "mtidle", "mtidle"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "mtidle", "mtidle"},
        [ACT_MP_WALK] = {"mtwalk", "mtwalk", "mtwalk"},
        [ACT_MP_CROUCHWALK] = {"mtwalk", "mtwalk", "mtwalk"},
        [ACT_MP_RUN] = {"mtrun", "mtrun", "mtrun"},
        [ACT_MP_SWIM] = {"mtwalk"},
        attack = "",
        sprint = {"mtrun", "mtrun", "mtrun"}
    },
    fist = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "mtidle", "mtidle"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "mtidle", "mtidle"},
        [ACT_MP_WALK] = {"mtwalk", "mtwalk", "mtwalk"},
        [ACT_MP_CROUCHWALK] = {"mtwalk", "mtwalk", "mtwalk"},
        [ACT_MP_RUN] = {"mtrun", "mtrun", "mtrun"},
        [ACT_MP_SWIM] = {"mtwalk"},
        attack = "",
        sprint = {"mtrun", "mtrun", "mtrun"}
    },
    pistol = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "1hpaim", "1hpaim"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "1hpaim", "1hpaim"},
        [ACT_MP_WALK] = {"mtwalk", "1hpwalk", "1hpwalk"},
        [ACT_MP_CROUCHWALK] = {"mtwalk", "1hpwalk", "1hpwalk"},
        [ACT_MP_RUN] = {"mtrun", "1hprun", "1hprun"},
        [ACT_MP_SWIM] = {"mtwalk"},
        attack = "",
        reload = "",
        sprint = {"mtrun", "1hprun", "1hprun"}
    },
    ["h2h"] = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "mtidle", "mtidle"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "mtidle", "mtidle"},
        [ACT_MP_WALK] = {"mtwalk", "mtwalk", "mtwalk"},
        [ACT_MP_CROUCHWALK] = {"mtwalk", "mtwalk", "mtwalk"},
        [ACT_MP_RUN] = {"mtrun", "mtrun", "mtrun"},
        [ACT_MP_SWIM] = {"mtwalk"},
        attack = "",
        sprint = {"mtrun", "mtrun", "mtrun"}
    },
    ["1hp"] = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "1hpaim", "1hpaim"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "1hpaim", "1hpaim"},
        [ACT_MP_WALK] = {"mtwalk", "1hpwalk", "1hpwalk"},
        [ACT_MP_CROUCHWALK] = {"mtwalk", "1hpwalk", "1hpwalk"},
        [ACT_MP_RUN] = {"mtrun", "1hprun", "1hprun"},
        [ACT_MP_SWIM] = {"mtwalk"},
        attack = "",
        reload = "",
        sprint = {"mtrun", "1hprun", "1hprun"}
    },
    ["2hr"] = {
        [ACT_MP_STAND_IDLE] = {"mtidle", "2hraim", "2hraim"},
        [ACT_MP_CROUCH_IDLE] = {"mtidle", "2hraim", "2hraim"},
        [ACT_MP_WALK] = {"mtwalk", "2hrwalk", "2hrwalk"},
        [ACT_MP_CROUCHWALK] = {"mtwalk", "2hrwalk", "2hrwalk"},
        [ACT_MP_RUN] = {"mtrun", "2hrrun", "2hrrun"},
        [ACT_MP_SWIM] = {"mtwalk"},
        attack = "",
        reload = "",
        sprint = {"mtrun", "2hrrun", "2hrrun"}
    }
}
