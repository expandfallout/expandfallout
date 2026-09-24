--[[
	S.P.E.C.I.A.L. - Strength

	Melee and unarmed damage.

	The per-attribute ceiling comes from `ix.config.Get("maxAttributes")`, which
	`libs/sh_special.lua` defaults to Phoenix's 25. It is deliberately NOT set as
	`ATTRIBUTE.maxValue` here: that is read once at load, so it would freeze the
	value and ignore any later config change.

	The STARTING budget is separate - `GetDefaultAttributePoints`, also in
	sh_special.lua.

	The key for this attribute is the FILENAME without the `sh_` prefix and
	`.lua` suffix - `strength`, lowercase. Phoenix stores attributes under the
	lowercase key but reads them with capitalised names in places, which
	silently returns the default. Use lowercase everywhere.
]]

ATTRIBUTE.name = "Strength"
ATTRIBUTE.description = "Raw physical power. Increases melee and unarmed damage."
