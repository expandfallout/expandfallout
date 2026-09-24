--[[
	What withdrawal from each chem does.

	Registered centrally rather than on the items, because an
	addiction is not owned by one item - five kinds of Mentats share
	one, and Jet and Ultrajet share another. Putting the withdrawal on
	the item would mean five copies of it, and five chances for them to
	disagree about what Mentats withdrawal costs.

	EFFECTS ARE CUMULATIVE. Severity 3 carries the entries for 1 and 2
	as well, so three identical -15 Speed steps read as -15, -30, -45 -
	which is exactly how Phoenix write Jet, as three separate -15s.

	`interval` is how long WITHOUT A DOSE before severity climbs a step.
	Taking the chem again resets it to zero, which is the whole shape of
	an addiction: free while you feed it, expensive when you cannot.

	`timedClear` addictions burn out on their own once you have gone a
	step past the top. The rest need Fixer or Addictol.

	GENERATED FILE - see `_docs/25-chems.md`.
]]

if (not ix.addiction) then return end

ix.addiction.Register({
	name = "AntNectar",
	label = "Ant Nectar",
	interval = 120,
	timedClear = false,
	effects = {
		[1] = {{stat = "STR", value = -2}},
		[2] = {{stat = "STR", value = -3}, {stat = "PER", value = -1}},
		[3] = {{stat = "STR", value = -4}, {stat = "PER", value = -2}}
	},
	screen = {
		[2] = {"grey"},
		[3] = {"grey", "nausea"}
	},
	messages = {
		[1] = "You feel wrung out.",
		[2] = "You have no strength at all.",
		[3] = "You can barely lift your arms."
	}
})

ix.addiction.Register({
	name = "Berserk",
	label = "Berserk",
	interval = 120,
	timedClear = false,
	effects = {
		[1] = {{stat = "DMG", value = -15}, {stat = "STR", value = -2}},
		[2] = {{stat = "DMG", value = -15}, {stat = "STR", value = -2}},
		[3] = {{stat = "DMG", value = -15}, {stat = "STR", value = -2}, {stat = "HP", value = -20}}
	},
	screen = {
		[2] = {"rage", "sobel"},
		[3] = {"rage", "sobel", "blur"}
	},
	messages = {
		[1] = "The edge is gone.",
		[2] = "You feel wrong without it.",
		[3] = "You would do almost anything for more."
	}
})

ix.addiction.Register({
	name = "Buffjet",
	label = "Buffjet",
	interval = 120,
	timedClear = false,
	effects = {
		[1] = {{stat = "SPD", value = -15}},
		[2] = {{stat = "SPD", value = -15}, {stat = "HP", value = -10}},
		[3] = {{stat = "SPD", value = -15}, {stat = "HP", value = -15}}
	},
	screen = {
		[2] = {"sobel"},
		[3] = {"sobel", "blur"}
	},
	messages = {
		[1] = "You feel sluggish.",
		[2] = "You feel hollow and slow.",
		[3] = "You can hardly stand up straight."
	}
})

ix.addiction.Register({
	name = "Buffout",
	label = "Buffout",
	interval = 120,
	timedClear = true,
	effects = {
		[1] = {{stat = "HP", value = -10}},
		[2] = {{stat = "HP", value = -10}, {stat = "END", value = -1}},
		[3] = {{stat = "HP", value = -15}, {stat = "END", value = -2}}
	},
	screen = {
		[2] = {"grey"},
		[3] = {"grey", "blur"}
	},
	messages = {
		[1] = "You feel hollow.",
		[2] = "Your chest aches.",
		[3] = "You can hardly stand."
	}
})

ix.addiction.Register({
	name = "Bufftats",
	label = "Bufftats",
	interval = 120,
	timedClear = true,
	effects = {
		[1] = {{stat = "INT", value = -1}},
		[2] = {{stat = "INT", value = -1}, {stat = "HP", value = -10}},
		[3] = {{stat = "INT", value = -2}, {stat = "HP", value = -15}}
	},
	screen = {
		[2] = {"sobel"},
		[3] = {"sobel", "grey"}
	},
	messages = {
		[1] = "Your head is thick.",
		[2] = "You feel weak and stupid.",
		[3] = "Nothing is working properly."
	}
})

ix.addiction.Register({
	name = "Calmex",
	label = "Calmex",
	interval = 120,
	timedClear = true,
	effects = {
		[1] = {{stat = "PER", value = -1}},
		[2] = {{stat = "PER", value = -2}},
		[3] = {{stat = "PER", value = -3}, {stat = "DMG", value = -10}}
	},
	screen = {
		[2] = {"sharpen"},
		[3] = {"sharpen", "blur"}
	},
	messages = {
		[1] = "You are jumpy.",
		[2] = "You cannot settle.",
		[3] = "Every noise makes you flinch."
	}
})

ix.addiction.Register({
	name = "Cateye",
	label = "Cateye",
	interval = 120,
	timedClear = true,
	effects = {
		[1] = {{stat = "PER", value = -1}},
		[2] = {{stat = "PER", value = -2}},
		[3] = {{stat = "PER", value = -3}}
	},
	screen = {
		[2] = {"sharpen"},
		[3] = {"sharpen", "sobel"}
	},
	messages = {
		[1] = "Your eyes are aching.",
		[2] = "The light hurts.",
		[3] = "You can hardly see straight."
	}
})

ix.addiction.Register({
	name = "CloudKiss",
	label = "Cloud Kiss",
	interval = 120,
	timedClear = false,
	effects = {
		[1] = {{stat = "END", value = -1}},
		[2] = {{stat = "END", value = -2}, {stat = "PER", value = -1}},
		[3] = {{stat = "END", value = -2}, {stat = "PER", value = -2}, {stat = "HP", value = -10}}
	},
	screen = {
		[2] = {"nausea"},
		[3] = {"nausea", "grey", "blur"}
	},
	messages = {
		[1] = "Your chest is tight.",
		[2] = "You cannot get a full breath.",
		[3] = "Every breath burns."
	}
})

ix.addiction.Register({
	name = "Coyote",
	label = "Coyote Tobacco",
	interval = 120,
	timedClear = true,
	effects = {
		[1] = {{stat = "PER", value = -1}},
		[2] = {{stat = "PER", value = -1}, {stat = "END", value = -1}},
		[3] = {{stat = "PER", value = -2}, {stat = "END", value = -1}}
	},
	screen = {
		[2] = {"grey"},
		[3] = {"grey", "sobel"}
	},
	messages = {
		[1] = "You want a chew.",
		[2] = "You cannot think past wanting one.",
		[3] = "Your hands will not keep still."
	}
})

ix.addiction.Register({
	name = "DaddyO",
	label = "Daddy-O",
	interval = 120,
	timedClear = false,
	effects = {
		[1] = {{stat = "INT", value = -1}},
		[2] = {{stat = "INT", value = -2}},
		[3] = {{stat = "INT", value = -2}, {stat = "PER", value = -1}}
	},
	screen = {
		[2] = {"grey"},
		[3] = {"grey", "blur"}
	},
	messages = {
		[1] = "Your head is fogging up.",
		[2] = "You keep forgetting things.",
		[3] = "You cannot follow what anyone is saying."
	}
})

ix.addiction.Register({
	name = "Datura",
	label = "Datura",
	interval = 120,
	timedClear = false,
	effects = {
		[1] = {{stat = "PER", value = -1}},
		[2] = {{stat = "PER", value = -2}, {stat = "DR", value = -5}},
		[3] = {{stat = "PER", value = -3}, {stat = "DR", value = -10}}
	},
	screen = {
		[2] = {"toytown"},
		[3] = {"toytown", "blur", "nausea"}
	},
	messages = {
		[1] = "The colours are wrong.",
		[2] = "Things are moving that should not be.",
		[3] = "You cannot tell what is real."
	}
})

ix.addiction.Register({
	name = "DayTripper",
	label = "Day Tripper",
	interval = 120,
	timedClear = false,
	effects = {
		[1] = {{stat = "CHR", value = -1}},
		[2] = {{stat = "CHR", value = -2}, {stat = "LCK", value = -1}},
		[3] = {{stat = "CHR", value = -2}, {stat = "LCK", value = -2}}
	},
	screen = {
		[2] = {"grey"},
		[3] = {"grey", "sobel"}
	},
	messages = {
		[1] = "The world is greyer than it was.",
		[2] = "Nothing seems worth saying.",
		[3] = "You cannot look anyone in the eye."
	}
})

ix.addiction.Register({
	name = "Fury",
	label = "Fury",
	interval = 120,
	timedClear = false,
	effects = {
		[1] = {{stat = "STR", value = -2}, {stat = "DMG", value = -15}},
		[2] = {{stat = "STR", value = -2}, {stat = "DMG", value = -15}},
		[3] = {{stat = "STR", value = -2}, {stat = "DMG", value = -15}, {stat = "HP", value = -20}}
	},
	screen = {
		[2] = {"grey", "sobel"},
		[3] = {"grey", "sobel", "blur"}
	},
	messages = {
		[1] = "The rage is draining out of you.",
		[2] = "You feel small and slow.",
		[3] = "You are barely holding together."
	}
})

ix.addiction.Register({
	name = "Hydra",
	label = "Hydra",
	interval = 120,
	timedClear = true,
	effects = {
		[1] = {{stat = "END", value = -1}},
		[2] = {{stat = "END", value = -2}},
		[3] = {{stat = "END", value = -2}, {stat = "HP", value = -15}}
	},
	screen = {
		[2] = {"nausea"},
		[3] = {"nausea", "grey"}
	},
	messages = {
		[1] = "Your old wounds are aching.",
		[2] = "Everything that was broken hurts again.",
		[3] = "You feel like you are coming apart."
	}
})

ix.addiction.Register({
	name = "Jet",
	label = "Jet",
	interval = 120,
	timedClear = false,
	effects = {
		[1] = {{stat = "SPD", value = -15}},
		[2] = {{stat = "SPD", value = -15}},
		[3] = {{stat = "SPD", value = -15}}
	},
	screen = {
		[2] = {"sobel"},
		[3] = {"sobel", "blur"}
	},
	messages = {
		[1] = "You feel sluggish.",
		[2] = "You feel fatigued.",
		[3] = "You are in severe withdrawal."
	}
})

ix.addiction.Register({
	name = "MedX",
	label = "Med-X",
	interval = 120,
	timedClear = false,
	effects = {
		[1] = {{stat = "DR", value = -5}},
		[2] = {{stat = "DR", value = -5}, {stat = "END", value = -1}},
		[3] = {{stat = "DR", value = -10}, {stat = "END", value = -1}}
	},
	screen = {
		[2] = {"nausea"},
		[3] = {"nausea", "blur"}
	},
	messages = {
		[1] = "Everything is starting to hurt.",
		[2] = "The pain is getting hard to ignore.",
		[3] = "Every step is agony."
	}
})

ix.addiction.Register({
	name = "Mentats",
	label = "Mentats",
	interval = 120,
	timedClear = true,
	effects = {
		[1] = {{stat = "INT", value = -1}},
		[2] = {{stat = "INT", value = -1}, {stat = "PER", value = -1}},
		[3] = {{stat = "INT", value = -2}, {stat = "PER", value = -1}}
	},
	screen = {
		[2] = {"sobel"},
		[3] = {"sobel", "toytown"}
	},
	messages = {
		[1] = "Your thoughts are getting slow.",
		[2] = "You keep losing the thread.",
		[3] = "You cannot hold an idea in your head."
	}
})

ix.addiction.Register({
	name = "Overdrive",
	label = "Overdrive",
	interval = 120,
	timedClear = true,
	effects = {
		[1] = {{stat = "LCK", value = -1}},
		[2] = {{stat = "LCK", value = -2}, {stat = "DMG", value = -10}},
		[3] = {{stat = "LCK", value = -2}, {stat = "DMG", value = -15}}
	},
	screen = {
		[2] = {"grey"},
		[3] = {"grey", "blur"}
	},
	messages = {
		[1] = "Nothing is going your way.",
		[2] = "You keep missing.",
		[3] = "You cannot hit anything."
	}
})

ix.addiction.Register({
	name = "Psycho",
	label = "Psycho",
	interval = 120,
	timedClear = false,
	effects = {
		[1] = {{stat = "DMG", value = -10}},
		[2] = {{stat = "DMG", value = -10}, {stat = "STR", value = -1}},
		[3] = {{stat = "DMG", value = -10}, {stat = "STR", value = -2}}
	},
	screen = {
		[2] = {"grey"},
		[3] = {"grey", "sobel"}
	},
	messages = {
		[1] = "Your temper is fraying.",
		[2] = "You feel weak and angry.",
		[3] = "You cannot think through the rage."
	}
})

ix.addiction.Register({
	name = "PsychoJet",
	label = "Psycho-Jet",
	interval = 120,
	timedClear = false,
	effects = {
		[1] = {{stat = "SPD", value = -15}, {stat = "DMG", value = -10}},
		[2] = {{stat = "SPD", value = -15}, {stat = "DMG", value = -10}},
		[3] = {{stat = "SPD", value = -15}, {stat = "DMG", value = -10}}
	},
	screen = {
		[2] = {"sobel", "grey"},
		[3] = {"sobel", "grey", "blur"}
	},
	messages = {
		[1] = "You are coming down hard.",
		[2] = "Everything is slow and pointless.",
		[3] = "You can barely move for wanting more."
	}
})

ix.addiction.Register({
	name = "Psychobuff",
	label = "Psychobuff",
	interval = 120,
	timedClear = false,
	effects = {
		[1] = {{stat = "DMG", value = -10}},
		[2] = {{stat = "DMG", value = -10}, {stat = "HP", value = -10}},
		[3] = {{stat = "DMG", value = -10}, {stat = "HP", value = -15}, {stat = "STR", value = -2}}
	},
	screen = {
		[2] = {"grey"},
		[3] = {"grey", "sobel"}
	},
	messages = {
		[1] = "Your temper is fraying.",
		[2] = "You feel weak and furious.",
		[3] = "You are shaking with it."
	}
})

ix.addiction.Register({
	name = "Psychotats",
	label = "Psychotats",
	interval = 120,
	timedClear = false,
	effects = {
		[1] = {{stat = "PER", value = -1}},
		[2] = {{stat = "PER", value = -2}, {stat = "DMG", value = -10}},
		[3] = {{stat = "PER", value = -3}, {stat = "DMG", value = -10}}
	},
	screen = {
		[2] = {"sobel"},
		[3] = {"sobel", "toytown"}
	},
	messages = {
		[1] = "The edges are going soft.",
		[2] = "You cannot focus on anything.",
		[3] = "Everything is noise."
	}
})

ix.addiction.Register({
	name = "RadAway",
	label = "RadAway",
	interval = 120,
	timedClear = true,
	effects = {
		[1] = {{stat = "END", value = -1}},
		[2] = {{stat = "END", value = -1}, {stat = "HP", value = -10}},
		[3] = {{stat = "END", value = -2}, {stat = "HP", value = -15}}
	},
	screen = {
		[2] = {"nausea"},
		[3] = {"nausea", "blur"}
	},
	messages = {
		[1] = "You feel washed out.",
		[2] = "Your veins are burning.",
		[3] = "You cannot keep anything down."
	}
})

ix.addiction.Register({
	name = "Rebound",
	label = "Rebound",
	interval = 120,
	timedClear = true,
	effects = {
		[1] = {{stat = "AGL", value = -1}},
		[2] = {{stat = "AGL", value = -1}, {stat = "SPD", value = -10}},
		[3] = {{stat = "AGL", value = -2}, {stat = "SPD", value = -10}}
	},
	screen = {
		[2] = {"grey"},
		[3] = {"grey", "blur"}
	},
	messages = {
		[1] = "You feel heavy.",
		[2] = "Your legs are lead.",
		[3] = "You can barely lift your feet."
	}
})

ix.addiction.Register({
	name = "Steady",
	label = "Steady",
	interval = 120,
	timedClear = true,
	effects = {
		[1] = {{stat = "PER", value = -1}},
		[2] = {{stat = "PER", value = -2}},
		[3] = {{stat = "PER", value = -2}}
	},
	screen = {
		[2] = {"blur"},
		[3] = {"blur", "sobel"}
	},
	messages = {
		[1] = "Your aim is drifting.",
		[2] = "You cannot keep the sights still.",
		[3] = "Your hands will not stop shaking."
	}
})

ix.addiction.Register({
	name = "Turbo",
	label = "Turbo",
	interval = 120,
	timedClear = false,
	effects = {
		[1] = {{stat = "AGL", value = -1}},
		[2] = {{stat = "AGL", value = -1}, {stat = "SPD", value = -15}},
		[3] = {{stat = "AGL", value = -1}, {stat = "SPD", value = -20}}
	},
	screen = {
		[2] = {"blur"},
		[3] = {"blur", "sobel"}
	},
	messages = {
		[1] = "Your reactions are dulling.",
		[2] = "Your hands are shaking.",
		[3] = "You can barely hold still."
	}
})

ix.addiction.Register({
	name = "Turpentine",
	label = "Turpentine",
	interval = 120,
	timedClear = true,
	effects = {
		[1] = {{stat = "INT", value = -1}, {stat = "PER", value = -1}},
		[2] = {{stat = "INT", value = -2}, {stat = "PER", value = -1}},
		[3] = {{stat = "INT", value = -2}, {stat = "PER", value = -2}, {stat = "HP", value = -10}}
	},
	screen = {
		[2] = {"nausea"},
		[3] = {"nausea", "blur", "sobel"}
	},
	messages = {
		[1] = "Your head is splitting.",
		[2] = "You cannot see straight.",
		[3] = "You are poisoning yourself and you know it."
	}
})

ix.addiction.Register({
	name = "XCell",
	label = "X-Cell",
	interval = 120,
	timedClear = false,
	effects = {
		[1] = {{stat = "STR", value = -1}, {stat = "END", value = -1}},
		[2] = {{stat = "PER", value = -1}, {stat = "AGL", value = -1}},
		[3] = {{stat = "INT", value = -1}, {stat = "LCK", value = -1}, {stat = "HP", value = -10}}
	},
	screen = {
		[2] = {"nausea"},
		[3] = {"nausea", "sobel", "blur"}
	},
	messages = {
		[1] = "Every part of you is complaining.",
		[2] = "You feel wrung out.",
		[3] = "Your whole body is failing you."
	}
})
