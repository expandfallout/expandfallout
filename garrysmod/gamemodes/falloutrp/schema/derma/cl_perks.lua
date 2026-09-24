--[[
	The PERKS tab of the F1 menu - the place, not the perks.

	Phoenix's perks (`plugins/perks`) are bought with skill points at a
	level, in tiers, some gated on a SPECIAL attribute; each is a file that
	registers itself and hangs its effect off a hook. See `52-perks.md`
	for what was read of it. None are here yet; this is the tab they go in,
	so the menu has its shape before the system does.
]]

local PANEL = {}

local function Scaled(value)
	return math.max(math.Round(value * (ScrH() / 1080)), 1)
end

function PANEL:Init()
	if (ix.fallout and ix.fallout.LoadMenuFonts) then
		ix.fallout.LoadMenuFonts()
	end

	local title = self:Add("ixFOLabel")

	title:Dock(TOP)
	title:SetTall(Scaled(26))
	title:DockMargin(Scaled(12), Scaled(8), Scaled(12), 0)
	title:SetFont("ixLootHeader")
	title:SetTextColor(color_white)
	title:SetText("PERKS")

	local note = self:Add("ixFOLabel")

	note:Dock(TOP)
	note:SetTall(Scaled(20))
	note:DockMargin(Scaled(12), Scaled(4), Scaled(12), 0)
	note:SetFont("ixLootRow")
	note:SetTextColor(Color(190, 190, 180))
	note:SetText("Nothing to pick yet. Perks are bought here with skill "
		.. "points, in tiers, once they exist.")
end

vgui.Register("ixFOPerks", PANEL, "Panel")

hook.Add("CreateMenuButtons", "ixFalloutPerks", function(tabs)
	tabs["perks"] = function(container)
		local panel = container:Add("ixFOPerks")

		panel:Dock(FILL)
	end
end)
