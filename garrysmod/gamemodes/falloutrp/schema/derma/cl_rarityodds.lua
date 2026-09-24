--[[
	QUALITY - your current crafting odds, in the character menu.

	Seven bars, one per tier, showing what YOUR Luck right now would roll at a
	bench. Not a static table of the design's numbers: it reads
	`ix.rarity.Chances` against live Luck, so a chem or a piece of clothing
	that moves Luck moves these while the menu is open.

	THAT IS THE POINT OF IT. Luck is the one attribute whose effect is entirely
	invisible - Strength shows on the damage numbers and Agility on how fast
	you move, and Luck shows up only in the long run of things you did not get.
	A player deciding whether a +5 Luck hat is worth wearing to a crafting
	session cannot answer that without seeing the curve move.
]]

if (not CLIENT) then return end

local PANEL = {}

local function Scaled(value)
	return math.Round(value * ix.fallout.GetFontScale())
end

function PANEL:Init()
	ix.fallout.LoadMenuFonts()

	self:Dock(FILL)
	self:DockPadding(Scaled(16), Scaled(16), Scaled(16), Scaled(16))
end

function PANEL:Paint(width, height)
	local palette = ix.fallout.GetPalette()
	local character = LocalPlayer():GetCharacter()

	if (not character) then return end

	local luck = ix.rarity.LuckOf(character)
	local chances = ix.rarity.Chances(luck)

	local pad = Scaled(16)
	local y = pad

	draw.SimpleText("CRAFTING QUALITY", "ixLootTitle", pad, y,
		palette.color_primary, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	y = y + Scaled(30)

	--[[
		The Luck it is reading, said out loud. Somebody looking at these
		numbers and wondering why they are not the ones in the design document
		is somebody who wants to know what Luck the game thinks they have.
	]]
	draw.SimpleText(string.format(
		"Luck %d of %d - buffs count, and the curve tops out at %d.",
		luck, ix.rarity.maxLuck, ix.rarity.maxLuck), "ixLootSmall", pad, y,
		palette.text_primary, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	y = y + Scaled(26)

	local barX = pad + Scaled(150)
	local barW = width - barX - pad - Scaled(90)
	local rowH = Scaled(30)

	for _, tier in ipairs(ix.rarity.tiers) do
		local chance = chances[tier.id] or 0
		local colour = ix.rarity.GetColor(tier.id)

		--[[
			The swatch is the same colour the border round the weapon will be,
			so the table and the item in the bag are recognisably the same
			thing. Master Craft animates in both.
		]]
		surface.SetDrawColor(colour)
		surface.DrawRect(pad, y + Scaled(6), Scaled(12), Scaled(12))

		draw.SimpleText(tier.name, "ixLootRow", pad + Scaled(20),
			y + Scaled(12), palette.text_primary, TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)

		surface.SetDrawColor(20, 20, 24, 200)
		surface.DrawRect(barX, y + Scaled(7), barW, Scaled(10))

		--[[
			A MINIMUM WIDTH ON ANYTHING NON-ZERO. Pearlescent at 0.1% is a
			third of a pixel, and a bar that rounds to nothing is
			indistinguishable from a bar that is not there - which is exactly
			the tier somebody is squinting at this table to find.
		]]
		if (chance > 0) then
			surface.SetDrawColor(ColorAlpha(colour, 190))
			surface.DrawRect(barX, y + Scaled(7),
				math.max(barW * chance, Scaled(2)), Scaled(10))
		end

		draw.SimpleText(string.format("%.3g%%", chance * 100), "ixLootRow",
			width - pad, y + Scaled(12),
			chance > 0 and colour or ColorAlpha(palette.text_primary, 90),
			TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		draw.SimpleText(string.format("%.2gx", tier.damage), "ixLootSmall",
			barX - Scaled(10), y + Scaled(12),
			ColorAlpha(palette.text_primary, 160), TEXT_ALIGN_RIGHT,
			TEXT_ALIGN_CENTER)

		y = y + rowH
	end

	y = y + Scaled(10)

	draw.SimpleText("Every weapon you craft is rolled once, when it is made.",
		"ixLootSmall", pad, y, ColorAlpha(palette.text_primary, 170),
		TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	draw.SimpleText("Common stops at 25 Luck, Uncommon at 50.",
		"ixLootSmall", pad, y + Scaled(16),
		ColorAlpha(palette.text_primary, 170), TEXT_ALIGN_LEFT,
		TEXT_ALIGN_TOP)
end

vgui.Register("ixFORarityOdds", PANEL, "Panel")

hook.Add("CreateMenuButtons", "ixFalloutRarity", function(tabs)
	tabs["quality"] = function(container)
		local panel = container:Add("ixFORarityOdds")

		panel:Dock(FILL)
	end
end)
