--[[
	The SPECIAL tab.

	Registered through `CreateMenuButtons`, the same hook Helix's own tabs use,
	so it appears in the Fallout menu without that menu needing to know about it.

	NO LONGER READ-ONLY. It was, deliberately, until levelling existed - a tab
	that looks interactive but is not is worse than one that plainly is not.
	Levelling now awards skill points, so this is where they are spent, and
	where a level 50 character respecs.

	Drawn rather than built from child panels, which is how it started and is
	worth keeping: the rows come from `ix.fallout.DrawSpecialRow`, the same
	renderer the creation screen uses, so the two views of SPECIAL are the same
	drawing rather than two that merely resemble each other.

	Because it is drawn, the clickable areas are recorded during `Paint` and
	tested in `OnMousePressed`. That is the trade for sharing the renderer: hit
	areas have to be remembered rather than being panels that know their own
	bounds.
]]

local PANEL = {}

local function Scaled(value)
	return math.Round(value * ix.fallout.GetFontScale())
end

function PANEL:Init()
	self.rows = {}
	self.hitAreas = {}

	--[[
		REQUIRED, and easy to miss. This panel is registered on the bare
		`Panel` base, which has mouse input DISABLED by default - so
		`OnMousePressed` never fires and every hit area below is dead.

		The hover highlighting worked without it, which is what makes this
		trap: `CursorPos` reports a position regardless, so the tab looks
		responsive right up until you click something.
	]]
	self:SetMouseInputEnabled(true)
end

function PANEL:SetCharacter(character)
	self.character = character
end

--[[
	Ask the server to spend a point. It re-checks everything - see
	`sv_leveling.lua` - so this is a request, not an instruction.
]]
function PANEL:Spend(key)
	net.Start("ixLevelingSpend")
		net.WriteString(key)
	net.SendToServer()

	ix.fallout.PlayUISound("select")
end

function PANEL:Respec()
	net.Start("ixLevelingRespec")
	net.SendToServer()

	ix.fallout.PlayUISound("select")
end

function PANEL:OnMousePressed()
	local x, y = self:CursorPos()

	for _, area in ipairs(self.hitAreas) do
		if (x >= area.x and x <= area.x + area.w
		and y >= area.y and y <= area.y + area.h) then
			area.callback(self)
			return
		end
	end
end

function PANEL:Paint(width, height)
	local character = self.character or LocalPlayer():GetCharacter()

	if (not character) then return end

	local palette = ix.fallout.GetPalette()
	local pad = Scaled(14)

	self.hitAreas = {}

	surface.SetFont("UI_Bold")

	local _, titleH = surface.GetTextSize("W")
	local rowH = ix.fallout.GetSpecialRowHeight()
	local gap = Scaled(8)
	local y = pad

	draw.SimpleText("S.P.E.C.I.A.L.", "UI_Bold", pad, y,
		palette.color_primary, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	--[[
		Level only, no bar. The XP bar lives under the whole menu, where
		Phoenix put it - a second one here would be the same number drawn
		twice on one screen.
	]]
	if (ix.leveling and character.GetLevel) then
		draw.SimpleText("LEVEL " .. character:GetLevel(), "UI_Bold", width - pad, y,
			palette.color_primary, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
	end

	y = y + titleH + Scaled(12)

	local top = y
	local mouseX, mouseY = self:CursorPos()
	local inside = mouseX > 0 and mouseX < width

	local points = (character.GetSkillPoints and character:GetSkillPoints()) or 0
	local maximum = ix.config.Get("maxAttributes", 25)

	--[[
		The plus box is only drawn where a point could actually go: there has
		to be one to spend, and the attribute has to have room. Drawing a
		button that refuses when clicked would be the interactive-but-not
		problem this tab was avoiding in the first place.
	]]
	local plusSize = Scaled(20)
	local rowWidth = width - pad * 2 - (points > 0 and (plusSize + Scaled(6)) or 0)

	for i = 1, #ix.special.order do
		local key = ix.special.order[i]
		local attribute = ix.attributes.list[key]

		if (attribute) then
			local hovered = inside and mouseY >= y and mouseY < y + rowH

			ix.fallout.DrawSpecialRow(pad, y, rowWidth, rowH, {
				letter = string.upper(key:sub(1, 1)),
				name = attribute.name,
				value = ix.special.Get(character, key),
				hovered = hovered
			})

			if (points > 0 and character:GetAttribute(key, 0) < maximum) then
				local plusX = pad + rowWidth + Scaled(6)
				local plusY = y + (rowH - plusSize) * 0.5
				local over = inside and mouseX >= plusX and mouseX <= plusX + plusSize
					and mouseY >= plusY and mouseY <= plusY + plusSize

				surface.SetDrawColor(over and palette.color_primary or palette.color_faint)
				surface.DrawRect(plusX, plusY, plusSize, plusSize)

				draw.SimpleText("+", "UI_Bold", plusX + plusSize * 0.5,
					plusY + plusSize * 0.5,
					over and palette.color_faint or palette.color_primary,
					TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

				self.hitAreas[#self.hitAreas + 1] = {
					x = plusX, y = plusY, w = plusSize, h = plusSize,
					callback = function(panel) panel:Spend(key) end
				}
			end

			y = y + rowH + gap
		end
	end

	--[[
		Points remaining, stated plainly. A player who has just levelled needs
		to know there is something to do here without counting the plus boxes.
	]]
	if (points > 0) then
		draw.SimpleText(string.format("%d point%s to spend", points,
			points == 1 and "" or "s"), "UI_Bold", pad, y + Scaled(4),
			palette.color_primary, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end

	--[[
		RESPEC, bottom right, and only when it is actually available. The
		reason it is not is shown instead - "you must be level 50" is more use
		than a greyed-out button with no explanation.
	]]
	if (ix.leveling) then
		local allowed, result = ix.leveling.CanRespec(LocalPlayer())
		local buttonW, buttonH = Scaled(110), Scaled(26)
		local buttonX = width - pad - buttonW
		local buttonY = height - pad - buttonH

		if (allowed) then
			local over = inside and mouseX >= buttonX and mouseX <= buttonX + buttonW
				and mouseY >= buttonY and mouseY <= buttonY + buttonH

			surface.SetDrawColor(over and palette.color_primary or palette.color_faint)
			surface.DrawRect(buttonX, buttonY, buttonW, buttonH)

			draw.SimpleText(result > 0 and ix.currency.Get(result) or "RESPEC",
				"UI_Small", buttonX + buttonW * 0.5, buttonY + buttonH * 0.5,
				over and palette.color_faint or palette.color_primary,
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			self.hitAreas[#self.hitAreas + 1] = {
				x = buttonX, y = buttonY, w = buttonW, h = buttonH,
				callback = function(panel) panel:Respec() end
			}
		else
			draw.SimpleText(result, "UI_Small", width - pad, height - pad,
				palette.color_faint, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
		end
	end

	-- Description of whichever row the cursor is over.
	if (inside and mouseY >= top) then
		local index = math.floor((mouseY - top) / (rowH + gap)) + 1
		local attribute = index >= 1 and index <= #ix.special.order
			and ix.attributes.list[ix.special.order[index]]

		if (attribute) then
			draw.SimpleText(attribute.description, "UI_Small", pad, height - pad,
				palette.color_active, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
		end
	end
end

vgui.Register("ixFOSpecial", PANEL, "Panel")

hook.Add("CreateMenuButtons", "ixFalloutSpecial", function(tabs)
	if (table.IsEmpty(ix.attributes.list)) then return end

	tabs["special"] = function(container)
		local panel = container:Add("ixFOSpecial")

		panel:Dock(FILL)
	end
end)

--[[
	Remove Helix's "YOU" tab.

	Its content is the framework's generic character panel - attributes, a date
	readout and placeholder labels. SPECIAL replaces the useful half and the
	Meta Info side panel replaces the rest.

	This runs after Helix's own listener because the schema loads after the
	framework, and hook.Add listeners run in registration order.
]]
hook.Add("CreateMenuButtons", "ixFalloutRemoveYouTab", function(tabs)
	tabs["you"] = nil

	--[[
		CLASSES GOES TOO, and for a different reason.

		Helix's tab is a list of every class in your faction that you are
		allowed to switch to, and switching is a button press. That is not how
		a class is meant to be got here: `sh_factionmgmt.lua` puts it in the
		hands of the people above you in the faction, and `sh_classrank.lua`
		puts the top of every ladder behind an admin grant. Leaving the tab
		would have been a second, self-service route to the same thing, which
		is the one people would use.

		The tab is not disabled, it is not shown - `ix.class.CanSwitchTo` still
		answers the same way for the commands and the context menu that do the
		work now.
	]]
	tabs["classes"] = nil
end)

--[[
	AND HELIX'S LISTENER IS REMOVED OUTRIGHT, because nilling the tab was not
	enough and the reason is worth writing down.

	`hook.Add` listeners with STRING identifiers are stored in a hash table and
	run in `pairs` order, which is not registration order and not stable. The
	comment above says this runs after Helix's "because the schema loads after
	the framework" - that is simply not true, and the removal above was a coin
	flip that happened to land right for `you` and wrong for `classes`: Helix's
	`ixClasses` listener ran afterwards and put the tab straight back.

	Removing the listener cannot lose that race. Safe at file scope because
	`core/derma/cl_classes.lua` is included with the framework, long before any
	schema file.
]]
hook.Remove("CreateMenuButtons", "ixClasses")
