--[[
	The crosshair, and the hit marker on it.

	Phoenix's `adv_crosshair`: their own crosshair drawn over the world, with
	every part of it editable, and four ticks that flash when you hit somebody.
	Theirs has three shapes, an outline or a shadow, and a spread that opens up
	with the weapon's recoil - all of that is here, plus the parts of it that
	were hard-coded in theirs.

	WHAT IS DEFINED HERE and what lives elsewhere:

	    this file      the settings, their defaults, their bounds and their
	                   types - one table that the drawing, the menu and the
	                   file all read, so a new setting is one entry rather
	                   than three edits
	    cl_crosshair   the drawing, the hit marker, and the file it saves to
	    cl_crosshairconfig   the window, built from the table below

	THE HIT MARKER MAKES NO SOUND. Phoenix's does not either; theirs is four
	diagonal ticks that fade, and that is what this is.

	IT REPLACES EVERY OTHER CROSSHAIR. `CHudCrosshair` is hidden and every
	weapon's own `DrawCrosshair` is turned off while ours is on - see
	`cl_crosshair.lua`, which is careful to put them back when it is not.
]]

ix.crosshair = ix.crosshair or {}

--[[
	The shapes. `dot` may be drawn on top of either of the other two, which is
	Phoenix's `drawDot` and is why it is a separate setting rather than a
	fourth shape.
]]
ix.crosshair.shapes = {
	{id = "cross", name = "Cross"},
	{id = "circle", name = "Circle"},
	{id = "dot", name = "Dot only"}
}

--[[
	EVERY SETTING, IN ONE PLACE.

	    key        what it is called in the saved file
	    name       what the window calls it
	    kind       "bool", "number", "colour" or "choice"
	    default    what a fresh install gets
	    min/max    for numbers, and the window's slider bounds
	    note       the line under it in the window

	The order here is the order in the window.
]]
ix.crosshair.settings = {
	{key = "enabled", name = "Crosshair on", kind = "bool", default = true,
		note = "off leaves you with whatever the weapon draws"},

	{key = "shape", name = "Shape", kind = "choice", default = "cross",
		choices = ix.crosshair.shapes},

	{key = "colour", name = "Colour", kind = "colour",
		default = {255, 255, 255, 255}},

	{key = "size", name = "Arm length", kind = "number", default = 8,
		min = 1, max = 60, note = "how long each arm is, in pixels"},

	{key = "thickness", name = "Thickness", kind = "number", default = 2,
		min = 1, max = 10},

	{key = "gap", name = "Gap", kind = "number", default = 8,
		min = 0, max = 60, note = "the hole in the middle"},

	{key = "dot", name = "Centre dot", kind = "bool", default = false,
		note = "drawn on top of whichever shape is chosen"},

	{key = "dotSize", name = "Dot size", kind = "number", default = 2,
		min = 1, max = 10},

	{key = "tShape", name = "T shape", kind = "bool", default = false,
		note = "leaves the top arm off, so the crosshair does not cover what "
			.. "you are aiming at"},

	{key = "outline", name = "Outline", kind = "bool", default = true,
		note = "a dark edge, so it is readable against a bright wall"},

	{key = "outlineSize", name = "Outline thickness", kind = "number",
		default = 1, min = 1, max = 6},

	{key = "outlineColour", name = "Outline colour", kind = "colour",
		default = {0, 0, 0, 220}},

	{key = "spread", name = "Opens with recoil", kind = "bool", default = true,
		note = "the gap grows with the weapon's spread, so the crosshair "
			.. "tells you when it is worth firing"},

	{key = "follow", name = "Follow the aim", kind = "bool", default = true,
		note = "drawn where the shot would land rather than at the centre of "
			.. "the screen - they differ when a weapon is held off-centre"},

	--[[
		BOTH OF THESE ARE OFF BY DEFAULT, and that is the fix for "the
		crosshair only shows when I pull out a gun".

		`hideLowered` was on, and empty hands are never RAISED - `IsWepRaised`
		is false for `ix_hands`, so the crosshair was hidden every moment
		somebody was not holding a drawn weapon. The default now is what was
		asked for: it shows everywhere except in a menu, and either of these
		is how somebody turns that off for themselves.
	]]
	{key = "weaponsOnly", name = "Only with a weapon", kind = "bool",
		default = false, note = "no crosshair with empty hands, keys, or "
			.. "anything else that is not a weapon"},

	{key = "hideLowered", name = "Hide when lowered", kind = "bool",
		default = false, note = "no crosshair while a drawn weapon is down"},

	{key = "hitMarker", name = "Hit marker", kind = "bool", default = true,
		note = "four ticks when you hit somebody. It makes no sound"},

	{key = "hitColour", name = "Hit marker colour", kind = "colour",
		default = {255, 80, 80, 255}},

	{key = "hitSize", name = "Hit marker size", kind = "number", default = 10,
		min = 2, max = 40},

	{key = "hitTime", name = "Hit marker time", kind = "number", default = 4,
		min = 1, max = 20, note = "tenths of a second it stays up for"}
}

--- `[key] = setting`, built once.
ix.crosshair.byKey = {}

for _, setting in ipairs(ix.crosshair.settings) do
	ix.crosshair.byKey[setting.key] = setting
end

--- A fresh set of settings, as a table of plain values.
function ix.crosshair.Defaults()
	local out = {}

	for _, setting in ipairs(ix.crosshair.settings) do
		if (setting.kind == "colour") then
			out[setting.key] = {unpack(setting.default)}
		else
			out[setting.key] = setting.default
		end
	end

	return out
end

--[[
	One setting, corrected.

	Everything that reads a setting goes through here, so a file somebody has
	edited by hand - or one written by an older version with a setting since
	renamed - cannot put a string where a number belongs or a slider past its
	own bounds.
]]
function ix.crosshair.Clean(key, value)
	local setting = ix.crosshair.byKey[key]

	if (not setting) then return nil end

	if (setting.kind == "bool") then
		return value and true or false
	elseif (setting.kind == "number") then
		return math.Clamp(tonumber(value) or setting.default,
			setting.min or 0, setting.max or 100)
	elseif (setting.kind == "colour") then
		if (not istable(value)) then return {unpack(setting.default)} end

		return {
			math.Clamp(math.floor(tonumber(value[1]) or 255), 0, 255),
			math.Clamp(math.floor(tonumber(value[2]) or 255), 0, 255),
			math.Clamp(math.floor(tonumber(value[3]) or 255), 0, 255),
			math.Clamp(math.floor(tonumber(value[4]) or 255), 0, 255)
		}
	end

	--- A choice, checked against the list rather than trusted.
	for _, choice in ipairs(setting.choices or {}) do
		if (choice.id == value) then return value end
	end

	return setting.default
end

function ix.crosshair.ToColor(value)
	if (not istable(value)) then return Color(255, 255, 255) end

	return Color(value[1] or 255, value[2] or 255, value[3] or 255,
		value[4] or 255)
end
