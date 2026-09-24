--[[
	The scoreboard: names you have been given, and what each faction is known
	for.

	TWO CHANGES, both wrapped onto Helix's own panels rather than replacing
	them - `vgui.GetControlTable` hands back the table `vgui.Register` stored,
	and writing to it affects every panel built afterwards.

	    the name       hidden until you recognise somebody. Helix hides the
	                   model icon and leaves the NAME in plain sight, which
	                   makes the icon pointless: a stranger's name is on the
	                   tab menu whether or not you have ever met them
	    the faction    a karma icon and the band it has earned, in the colour
	                   of its own ratio. Phoenix's five icons, at milestones
	                   this schema lets you move

	See `42-karma.md`.
]]

if (not CLIENT) then return end

ix.karma = ix.karma or {}

--[[
	The five icons, worst to best, and the config that puts each one's
	threshold where a server wants it.

	PERCENTAGES, not raw karma - a faction with ten thousand of each is still
	dead centre, and a new faction with three good deeds is not "Wasteland
	Angels" for having no bad ones. `ix.karma.Ratio` already answers in the
	right units.

	The thresholds are also what the GRADIENT is measured against: the icon
	steps at these points, and the colour behind it slides between them, so
	a faction two points from the next milestone plainly looks like it.
]]
ix.karma.icons = {
	{key = "karmaIconVeryGood", default = 60, path = "verygood"},
	{key = "karmaIconGood", default = 20, path = "good"},
	{key = "karmaIconBad", default = -20, path = "bad"},
	{key = "karmaIconVeryBad", default = -60, path = "verybad"}
}

--- Cached, because `Material` is a lookup and this is drawn every frame.
local materials = {}

local function Icon(name)
	if (not materials[name]) then
		materials[name] = Material("phoenix/hud/karma_" .. name .. ".png",
			"smooth")
	end

	return materials[name]
end

--[[
	Which icon a percentage earns, and how far it is through that band.

	Returns the material and a fraction from 0 to 1 - 0 at the bottom of the
	band it is in and 1 at the top - which is what the shading uses. A faction
	sitting just under the next milestone is drawn nearly the colour of the one
	above, which is the point: the icon is a step and the colour is not.
]]
function ix.karma.IconFor(percent)
	local previous = 100

	for index, entry in ipairs(ix.karma.icons) do
		local at = ix.config.Get(entry.key, entry.default)

		if (percent >= at) then
			--[[
				The top of this band is the milestone ABOVE it, or 100 for the
				first. Guarded against a server that has set two milestones the
				same way round, which would divide by zero.
			]]
			local span = math.max(previous - at, 1)

			return Icon(index == 1 and "verygood" or entry.path),
				math.Clamp((percent - at) / span, 0, 1), entry
		end

		previous = at
	end

	--- Below every milestone: the worst icon, and how far off the bottom.
	local last = ix.config.Get(ix.karma.icons[#ix.karma.icons].key,
		ix.karma.icons[#ix.karma.icons].default)

	return Icon("verybad"),
		math.Clamp((percent + 100) / math.max(last + 100, 1), 0, 1)
end

--[[
	The colour for a percentage: red through yellow to green, with the
	SHADE inside the band coming from how close it is to the next one.

	`ix.karma.Band` already gives the hue across the whole range. This darkens
	it toward the bottom of its own band and brightens it toward the top, which
	is the "inner shade as you progress" - the hue says what you are, the
	brightness says how nearly you are the next thing.
]]
function ix.karma.IconColour(percent, fraction)
	local hue = 120 * ((math.Clamp(percent, -100, 100) + 100) / 200)

	return HSVToColor(hue, 1, 0.55 + 0.45 * math.Clamp(fraction, 0, 1))
end

--------------------------------------------------------------------------------
-- Wrapping the two panels
--------------------------------------------------------------------------------

local function WrapRow()
	local PANEL = vgui.GetControlTable("ixScoreboardRow")

	if (not PANEL) then return false end
	if (PANEL.ixKarma) then return true end

	PANEL.ixKarma = true

	local original = PANEL.Update

	function PANEL:Update()
		original(self)

		local client = self.player

		if (not IsValid(client) or not IsValid(self.name)) then return end

		--[[
			`GetCharacterName` is the recognition hook, and it answers with a
			name ONLY when you do not know somebody - nil means "use their real
			one". So this is the whole test, and it is the same one the chat
			uses, which is what keeps the two from disagreeing.
		]]
		local unknown = hook.Run("GetCharacterName", client)

		if (client ~= LocalPlayer() and isstring(unknown)) then
			if (self.name:GetText() ~= unknown) then
				self.name:SetText(unknown)
				self.name:SizeToContents()
			end

			return
		end

		--[[
			THEIR TITLE, after their name, for people you do know. It is the
			same rule as the look-at box - see `cl_karma.lua` - so the tab menu
			cannot tell you something looking at them would not.
		]]
		if (not ix.config.Get("karmaEnabled", true)) then return end

		local good, bad = ix.karma.OfPlayer(client)

		if (good + bad <= 0) then return end

		local title, level = ix.karma.Describe(good, bad)
		local text = string.format("%s  -  %s (%d)", client:GetName(), title,
			level)

		if (self.name:GetText() ~= text) then
			self.name:SetText(text)
			self.name:SizeToContents()
		end
	end

	return true
end

local function WrapFaction()
	local PANEL = vgui.GetControlTable("ixScoreboardFaction")

	if (not PANEL) then return false end
	if (PANEL.ixKarma) then return true end

	PANEL.ixKarma = true

	local original = PANEL.Update

	function PANEL:Update()
		original(self)

		local faction = self.faction

		if (not faction or not ix.config.Get("karmaEnabled", true)) then
			return
		end

		local good, bad = ix.karma.FactionKarma(faction.uniqueID)

		--- A faction that has never earned anything says nothing.
		if (good + bad <= 0) then
			self.ixKarmaBand = nil

			return
		end

		local percent = ix.karma.Ratio(good, bad) * 100
		local band = ix.karma.Band(good, bad)
		local icon, fraction = ix.karma.IconFor(percent)

		self.ixKarmaBand = band
		self.ixKarmaIcon = icon
		self.ixKarmaColour = ix.karma.IconColour(percent, fraction)
		self.ixKarmaText = string.format("%s  (%d%%)", band.name,
			math.Round(percent))
	end

	--[[
		Drawn OVER the header rather than through `SetText`, because the header
		text is the faction's name in the faction's own colour and this is a
		second thing about it - painting it in would mean the two could not be
		coloured differently, and the colour is half of what this says.
	]]
	local paint = PANEL.Paint

	function PANEL:Paint(width, height)
		if (paint) then paint(self, width, height) end

		if (not self.ixKarmaBand) then return end

		--[[
			The menu fonts are LOADED ON DEMAND (`cl_menufonts.lua`), and
			`surface.SetFont` on a font that has not been created is an error
			rather than a fallback. Every other always-on drawing in this
			schema asks the same way - see `cl_pk.lua`.
		]]
		if (not ix.fallout.LoadMenuFonts or not ix.fallout.LoadMenuFonts()) then
			return
		end

		local scale = ix.fallout.GetFontScale()
		local size = math.Round(18 * scale)
		local top = math.Round(4 * scale)

		surface.SetFont("ixLootSmall")

		local textWidth = surface.GetTextSize(self.ixKarmaText)
		local x = width - textWidth - size - math.Round(12 * scale)

		--[[
			HOW MUCH ROOM THIS TAKES, for anything else that draws on the same
			header - the raid buttons in `cl_raid.lua` sit to the left of it,
			and they had no way of knowing where "the left of it" was, so they
			were drawn straight through the karma icon and its band name.

			Recorded during the paint because that is where the text is
			measured, and the font is only measurable once it has been loaded.
		]]
		local room = width - x + math.Round(6 * scale)

		--[[
			AND THE LAYOUT IS RUN AGAIN WHEN IT CHANGES.

			Anything that positions itself against this - the raid buttons -
			does so in `PerformLayout`, which had already run by the time the
			first paint measured the text. So the buttons were placed against a
			width of nil, drew straight through the karma, and stayed there:
			nothing else was going to ask for a layout.
		]]
		if (self.ixKarmaWidth ~= room) then
			self.ixKarmaWidth = room

			self:InvalidateLayout()
		end

		surface.SetDrawColor(self.ixKarmaColour)
		surface.SetMaterial(self.ixKarmaIcon)
		surface.DrawTexturedRect(x, top, size, size)

		draw.SimpleText(self.ixKarmaText, "ixLootSmall",
			width - math.Round(6 * scale), top + size * 0.5,
			self.ixKarmaColour, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end

	return true
end

--[[
	A retry rather than a hook, for the reason `cl_quickmove.lua` gives: there
	is no hook that reliably means "Helix's derma is registered", and
	`InitPostEntity` does not fire in this schema at all. Helix registers both
	panels in its core, which loads first, so this normally succeeds outright.
]]
local function Wrap()
	return WrapRow() and WrapFaction()
end

if (not Wrap()) then
	local attempts = 0

	timer.Create("ixKarmaScoreboardWrap", 1, 10, function()
		attempts = attempts + 1

		if (Wrap()) then
			timer.Remove("ixKarmaScoreboardWrap")
		elseif (attempts >= 10) then
			ErrorNoHalt("[falloutrp] scoreboard panels never appeared - "
				.. "karma icons and name hiding are not active\n")
		end
	end)
end
