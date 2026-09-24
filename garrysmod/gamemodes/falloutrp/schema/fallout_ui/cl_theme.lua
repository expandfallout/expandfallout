--[[
	Fallout UI - theme foundation.

	Ported from Phoenix's `fallout_ui/cl_fallout.lua`. Everything visual in the
	schema reads from here: palette, fonts, and the two draw primitives that
	give the Pip-Boy look (an angled-corner box and a rounded outline).

	Differences from Phoenix, deliberate:

	  * The palette is a per-client OPTION, not the hardcoded global
	    `nut.fallout.targetTheme`. Pip-Boy colour is a personal preference and
	    Helix already has an options menu to hang it on.
	  * Fonts SCALE with resolution. Phoenix's are fixed pixel sizes, so the
	    whole HUD shrinks to nothing on a 1440p or 4K monitor.
	  * Fonts are rebuilt on resolution change, and defined through a function
	    that is re-run on InitPostEntity. That also means we reliably win over
	    longsword_base's fallback UI_Regular/UI_Bold regardless of load order.
	  * Phoenix's palettes carry `BannerIcon` pointing at imgur URLs. Remote
	    images in a HUD are a liability - they 404, they stall, and they leak a
	    request per client. Dropped.
	  * Colours are cached rather than rebuilt every frame.
]]

ix.fallout = ix.fallout or {}
ix.fallout.gui = ix.fallout.gui or {}

--[[
	Palettes.

	The first three are Phoenix's, values unchanged. `blue` and `white` are
	additions - both are canonical Pip-Boy colours in the games, and the extra
	choice costs nothing.
]]
ix.fallout.palettes = {
	["orange"] = {
		name = "Amber",
		TextColor = Color(255, 199, 44),
		IconColor = Color(255, 199, 44),
		PrimaryColor = Color(255, 199, 44),
		SecondaryColor = Color(125, 100, 30),
		BackgroundColor = Color(98, 76, 16, 102),
		OutlineColor = Color(255, 199, 44),
		SelectedColor = Color(3, 132, 252, 255),
		HoverColor = Color(0, 0, 0)
	},
	["green"] = {
		name = "Pip-Boy Green",
		TextColor = Color(21, 255, 18),
		IconColor = Color(10, 255, 9),
		PrimaryColor = Color(21, 255, 18),
		SecondaryColor = Color(21, 63, 18),
		BackgroundColor = Color(21, 63, 18, 150),
		OutlineColor = Color(50, 255, 44, 255),
		SelectedColor = Color(3, 132, 252, 255),
		HoverColor = Color(0, 0, 0)
	},
	["pink"] = {
		name = "Magenta",
		TextColor = Color(255, 102, 255),
		IconColor = Color(255, 102, 255),
		PrimaryColor = Color(255, 102, 255),
		SecondaryColor = Color(153, 51, 255),
		BackgroundColor = Color(102, 0, 204, 150),
		OutlineColor = Color(255, 102, 255),
		SelectedColor = Color(204, 153, 255, 255),
		HoverColor = Color(0, 0, 0)
	},
	["blue"] = {
		name = "Vault Blue",
		TextColor = Color(96, 205, 255),
		IconColor = Color(96, 205, 255),
		PrimaryColor = Color(96, 205, 255),
		SecondaryColor = Color(34, 88, 120),
		BackgroundColor = Color(16, 58, 98, 120),
		OutlineColor = Color(96, 205, 255),
		SelectedColor = Color(255, 199, 44, 255),
		HoverColor = Color(0, 0, 0)
	},
	["white"] = {
		name = "Monochrome",
		TextColor = Color(228, 232, 235),
		IconColor = Color(228, 232, 235),
		PrimaryColor = Color(228, 232, 235),
		SecondaryColor = Color(110, 116, 120),
		BackgroundColor = Color(40, 44, 48, 140),
		OutlineColor = Color(228, 232, 235),
		SelectedColor = Color(255, 199, 44, 255),
		HoverColor = Color(0, 0, 0)
	}
}

ix.fallout.defaultTheme = "orange"

-- Resolved palette plus the derived shades the HUD and skin want. Rebuilt only
-- when the option changes, so nothing allocates a Color per frame.
ix.fallout.palette = ix.fallout.palette or {}

local function BuildPalette()
	local key = ix.fallout.defaultTheme

	if (ix.option and ix.option.Get) then
		key = ix.option.Get("falloutTheme", ix.fallout.defaultTheme)
	end

	local ui = ix.fallout.palettes[key] or ix.fallout.palettes[ix.fallout.defaultTheme]
	local primary = ui.PrimaryColor
	local p = ix.fallout.palette

	p.key = key
	p.color_primary = primary
	p.color_background = ui.BackgroundColor
	p.color_active = ui.SecondaryColor
	p.color_hover = ui.HoverColor
	p.color_outline = ui.OutlineColor
	p.color_selected = ui.SelectedColor

	p.text_primary = primary
	p.text_red = Color(255, 100, 100)
	p.text_disabled = ui.SecondaryColor
	p.text_hover = ui.HoverColor

	-- Derived shades. Phoenix recomputes these inline every frame; caching
	-- keeps the HUD off the garbage collector.
	p.color_bright = Color(
		math.min(primary.r + 24, 255),
		math.min(primary.g + 24, 255),
		math.min(primary.b + 24, 255)
	)
	p.color_dark = Color(primary.r * 0.8, primary.g * 0.8, primary.b * 0.8, 255)
	p.color_faint = Color(primary.r * 0.2, primary.g * 0.2, primary.b * 0.2, 200)
	p.color_shadow = Color(0, 0, 0, 200)

	hook.Run("FalloutPaletteChanged", p)

	return p
end

--- Returns the active palette table. Cheap - it is cached.
function ix.fallout.GetPalette()
	if (not ix.fallout.palette.color_primary) then
		BuildPalette()
	end

	return ix.fallout.palette
end

function ix.fallout.RebuildPalette()
	return BuildPalette()
end

--[[
	Resolution scaling. Kept under Phoenix's global names because the ported
	panels call them directly.
]]
function sW(width)
	return width and width * (ScrW() / 1920) or 1920
end

function sH(height)
	return height and height * (ScrH() / 1080) or 1080
end

local PANEL = FindMetaTable("Panel")

function PANEL:ScaleToRes(origX, origY)
	origX, origY = origX or 1920, origY or 1080

	local scrW, scrH = ScrW(), ScrH()
	local xMod, yMod = math.Clamp(scrW / origX, 0, 1), math.Clamp(scrH / origY, 0, 1)
	local curW, curH = self:GetSize()

	self:SetSize(curW * xMod, curH * yMod)
end

--[[
	Fonts.

	Phoenix's sizes at 1080p, scaled by screen height. The clamp keeps things
	legible in a small window without letting a 4K display blow the HUD up past
	twice its intended size.

	Note `weight = 10000` in the original: the engine caps weight at 1000, so
	those were silently identical to 1000. Written as 1000 here so it reads true.
]]
local FONT_FAMILY = "Roboto"

local baseFonts = {
	["UI_Small"] = {size = 12, weight = 400},
	["UI_InvRarityLabel"] = {size = 12, weight = 400},
	["UI_InvLabel"] = {size = 18, weight = 400},
	["UI_Regular"] = {size = 20, weight = 400},
	["UI_RADS"] = {size = 20, weight = 1000},
	["UI_Bold"] = {size = 25, weight = 500},
	["UI_Medium"] = {size = 30, weight = 600},
	["UI_Big"] = {size = 35, weight = 600},
	["UI_Huge"] = {size = 50, weight = 1000},
	["UI_Intro"] = {size = 125, weight = 1000}
}

function ix.fallout.GetFontScale()
	return math.Clamp(ScrH() / 1080, 0.75, 2)
end

function ix.fallout.LoadFonts()
	local scale = ix.fallout.GetFontScale()

	for name, data in pairs(baseFonts) do
		local size = math.max(math.Round(data.size * scale), 8)

		surface.CreateFont(name, {
			font = FONT_FAMILY,
			size = size,
			weight = data.weight,
			antialias = true,
			extended = true
		})

		-- Blurred twin, same convention Helix uses for its menu backdrop.
		surface.CreateFont(name .. "_Blur", {
			font = FONT_FAMILY,
			size = size,
			weight = data.weight,
			antialias = true,
			extended = true,
			blursize = 4
		})
	end
end

ix.fallout.LoadFonts()

-- Re-run after load so we win over longsword_base's fallback UI_Regular and
-- UI_Bold whichever loaded first, and again on any resolution change.
hook.Add("InitPostEntity", "ixFalloutFonts", ix.fallout.LoadFonts)
hook.Add("OnScreenSizeChanged", "ixFalloutFonts", function()
	ix.fallout.LoadFonts()
	BuildPalette()
end)

--[[
	Draw primitives.

	Phoenix's, unchanged in behaviour - the angled corner box is what makes a
	panel read as Fallout rather than as generic derma.
]]
function surface.RoundedOutlineBox(x, y, w, h, col, thickness, roundedness)
	thickness = math.max(math.floor(thickness or 1), 1)
	roundedness = math.max(math.floor(roundedness or 0), 0)

	if (w <= 0 or h <= 0) then return end

	local r = math.min(roundedness, math.floor(math.min(w, h) * 0.5))
	local t = math.min(thickness, math.floor(math.min(w, h) * 0.5))

	surface.SetDrawColor(col.r, col.g, col.b, col.a or 255)
	draw.NoTexture()

	if (r <= 0) then
		for i = 0, t - 1 do
			surface.DrawOutlinedRect(x + i, y + i, w - i * 2, h - i * 2)
		end

		return
	end

	local innerR = math.max(r - t, 0)
	local segs = math.max(math.ceil(r * 0.35), 8)

	surface.DrawRect(x + r, y, w - r * 2, t)
	surface.DrawRect(x + r, y + h - t, w - r * 2, t)
	surface.DrawRect(x, y + r, t, h - r * 2)
	surface.DrawRect(x + w - t, y + r, t, h - r * 2)

	local function Corner(cx, cy, startAng, endAng)
		local step = (endAng - startAng) / segs

		for i = 0, segs - 1 do
			local a1 = math.rad(startAng + step * i)
			local a2 = math.rad(startAng + step * (i + 1))

			surface.DrawPoly({
				{x = cx + math.cos(a1) * r, y = cy + math.sin(a1) * r},
				{x = cx + math.cos(a2) * r, y = cy + math.sin(a2) * r},
				{x = cx + math.cos(a2) * innerR, y = cy + math.sin(a2) * innerR},
				{x = cx + math.cos(a1) * innerR, y = cy + math.sin(a1) * innerR}
			})
		end
	end

	Corner(x + r, y + r, 180, 270)
	Corner(x + w - r, y + r, 270, 360)
	Corner(x + w - r, y + h - r, 0, 90)
	Corner(x + r, y + h - r, 90, 180)
end

function surface.DrawEdgedBox(x, y, w, h, thickness, edge1, edge2, edge3, edge4, outlineColor, insideColor)
	thickness = math.max(math.floor(tonumber(thickness) or 1), 0)

	edge1 = math.max(tonumber(edge1) or 0, 0) -- top-left
	edge2 = math.max(tonumber(edge2) or 0, 0) -- top-right
	edge3 = math.max(tonumber(edge3) or 0, 0) -- bottom-right
	edge4 = math.max(tonumber(edge4) or 0, 0) -- bottom-left

	local maxEdge = math.max(math.min(w, h) * 0.5, 0)

	edge1 = math.min(edge1, maxEdge)
	edge2 = math.min(edge2, maxEdge)
	edge3 = math.min(edge3, maxEdge)
	edge4 = math.min(edge4, maxEdge)

	local function buildPoints(px, py, pw, ph, e1, e2, e3, e4)
		local r = px + pw - 1
		local b = py + ph - 1

		local points = {
			{x = px + e1, y = py},
			{x = r - e2, y = py}
		}

		if (e2 > 0) then
			points[#points + 1] = {x = r, y = py + e2}
		end

		points[#points + 1] = {x = r, y = b - e3}

		if (e3 > 0) then
			points[#points + 1] = {x = r - e3, y = b}
		end

		points[#points + 1] = {x = px + e4, y = b}

		if (e4 > 0) then
			points[#points + 1] = {x = px, y = b - e4}
		end

		points[#points + 1] = {x = px, y = py + e1}

		return points
	end

	if (insideColor) then
		draw.NoTexture()
		surface.SetDrawColor(insideColor)
		surface.DrawPoly(buildPoints(x, y, w, h, edge1, edge2, edge3, edge4))
	end

	if (not outlineColor or thickness <= 0) then return end

	surface.SetDrawColor(outlineColor)

	for i = 0, thickness - 1 do
		local px, py = x + i, y + i
		local pw, ph = w - i * 2, h - i * 2

		if (pw <= 1 or ph <= 1) then break end

		local points = buildPoints(px, py, pw, ph,
			math.max(edge1 - i, 0), math.max(edge2 - i, 0),
			math.max(edge3 - i, 0), math.max(edge4 - i, 0))

		for k = 1, #points do
			local a = points[k]
			local b = points[k + 1] or points[1]

			surface.DrawLine(a.x, a.y, b.x, b.y)
		end
	end
end

--[[
	Screen fades. Phoenix defines these as bare globals; namespaced here, with
	thin globals kept so ported panels still work.
]]
function ix.fallout.FadeOut(callback)
	local fade = ix.fallout.fadePanel

	if (not IsValid(fade)) then
		fade = vgui.Create("DPanel")
		fade:SetZPos(9999)
		fade:SetAlpha(0)
		fade:SetSize(ScrW(), ScrH())
		fade.Paint = function(_, w, h)
			surface.SetDrawColor(0, 0, 0)
			surface.DrawRect(0, 0, w, h)
		end
		fade.Think = function(panel) panel:MakePopup() end

		ix.fallout.fadePanel = fade
	end

	fade:AlphaTo(255, 1, 0, function()
		if (callback) then callback() end
	end)
end

function ix.fallout.FadeIn(callback)
	local fade = ix.fallout.fadePanel

	if (not IsValid(fade)) then
		if (callback) then callback() end
		return
	end

	fade:AlphaTo(0, 1, 0.5, function()
		if (IsValid(fade)) then fade:Remove() end
		ix.fallout.fadePanel = nil

		if (callback) then callback() end
	end)
end

fadeIn = ix.fallout.FadeIn
fadeOut = ix.fallout.FadeOut

--[[
	Options. Both are cosmetic and per-client, so neither is networked.
]]
ix.option.Add("falloutTheme", ix.type.array, ix.fallout.defaultTheme, {
	category = "appearance",
	populate = function()
		local entries = {}

		for key, data in pairs(ix.fallout.palettes) do
			entries[key] = data.name
		end

		return entries
	end,
	OnChanged = function()
		BuildPalette()
	end
})

ix.option.Add("falloutHud", ix.type.array, "nv", {
	category = "appearance",
	populate = function()
		return {
			["nv"] = "New Vegas",
			["f4"] = "Fallout 4",
			["none"] = "Disabled"
		}
	end
})

ix.option.Add("falloutCompass", ix.type.bool, true, {
	category = "appearance"
})

BuildPalette()

--[[
	Crash and load breadcrumbs.

	Lives in the FIRST fallout_ui file so every later one can mark its own load.
	That matters as much as the crash trace: a schema file that throws partway
	through still leaves everything above the throw in place, so the symptom is
	a patch that silently never registered - not an obvious failure.

	`file.Write` commits immediately, which is the whole point. A hard crash
	takes the console buffer with it: the client's `console.log` in both crash
	sessions ended at "Redownloading all lightmaps", with the menu opening, the
	click and the crash all lost. This file survives.
]]
local traceLines = {}

local cvarTrace = CreateClientConVar("fo_create_trace", "1", false, false,
	"Write creation/load breadcrumbs to data/fo_create_trace.txt.")

function ix.fallout.CreateTrace(step)
	if (not cvarTrace:GetBool()) then return end

	traceLines[#traceLines + 1] = string.format("%7.2f  %s", RealTime(), tostring(step))

	-- Rewritten whole rather than appended: file.Append can buffer, and the
	-- point of this is to be on disk before the next line runs.
	file.Write("fo_create_trace.txt", table.concat(traceLines, "\n"))
end

concommand.Add("fo_create_trace_clear", function()
	traceLines = {}
	file.Write("fo_create_trace.txt", "")
end)

ix.fallout.CreateTrace("load: cl_theme.lua")
