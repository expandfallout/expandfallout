--[[
	The fonts the admin menus use.

	These were created by a local function inside `derma/cl_lootconfig.lua` and
	called from that panel's `Init`, which worked exactly as long as the loot
	configurer was the only thing using them. The class name viewer uses the
	same fonts, and opening it without having opened the configurer first gave

	    [ERROR] 'ixLootRow' isn't a valid font
	    attempt to perform arithmetic on local 'h' (a nil value)

	once per row per frame, because `draw.SimpleText` with an unknown font
	returns nothing for its height.

	SHARED, AND STILL LAZY. `libs/` is included before `fallout_ui/`, so
	`ix.fallout.GetFontScale` does not exist while this file is being read -
	the same trap `cl_buff.lua` sits in. So the fonts are not built here; the
	function is published and every window calls it in its own `Init`, which
	runs long after everything has loaded.

	Calling it repeatedly is free: `surface.CreateFont` with the same arguments
	is a no-op, and it has to run again on a resolution change anyway.
]]

if (not CLIENT) then return end

ix.fallout = ix.fallout or {}

--[[
	Sizes at 1080p, scaled like the rest of the UI.

	The schema's `UI_*` fonts are the HUD's - 12px for anything small, which is
	fine over a health bar and too small for a table of class names.
]]
local FONTS = {
	ixLootTitle = {size = 22, weight = 800},
	ixLootHeader = {size = 16, weight = 700},
	ixLootRow = {size = 15, weight = 500},
	ixLootSmall = {size = 13, weight = 400},
	ixLootBadge = {size = 11, weight = 800},

	--- The zone banner. Big, because it is read at a glance and then gone.
	ixZoneName = {size = 30, weight = 800},
	ixZoneNote = {size = 15, weight = 500}
}

--- Whether the fonts have been built at this scale already.
local builtAt

function ix.fallout.LoadMenuFonts(bForce)
	if (not ix.fallout.GetFontScale) then return false end

	local scale = ix.fallout.GetFontScale()

	if (not bForce and builtAt == scale) then return true end

	builtAt = scale

	for name, data in pairs(FONTS) do
		surface.CreateFont(name, {
			font = "Roboto",
			size = math.max(math.Round(data.size * scale), 9),
			weight = data.weight,
			antialias = true,
			extended = true
		})
	end

	return true
end

--[[
	Rebuilt on a resolution change, and the cached scale cleared so a window
	opening afterwards does not think they are still current.
]]
hook.Add("OnScreenSizeChanged", "ixMenuFonts", function()
	builtAt = nil

	ix.fallout.LoadMenuFonts(true)
end)
