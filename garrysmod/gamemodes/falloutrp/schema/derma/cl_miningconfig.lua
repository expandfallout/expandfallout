--[[
	The mining configurer - `/MiningConfig`.

	The ore list is DATA, not a table in a source file, and this is where it is
	edited: what each ore is called, which item it gives, how hard it is, which
	skin of the node model it uses and what colour its soft spot glows.

	NOTHING IS SAVED UNTIL SAVE IS PRESSED. The window holds a copy; the server
	only ever receives the whole list at once, so a half-finished edit cannot
	reach it and a connection that drops mid-edit costs nothing but the edit.

	The numbers that are the same for every ore - how much a swing takes off,
	what the soft spot is worth, how long a node takes to come back - are
	configs, and live in the dev terminal next to everything else. This window
	says so rather than duplicating them.
]]

if (not CLIENT) then return end

local PANEL = {}

local function Scaled(value)
	return math.Round(value * ix.fallout.GetFontScale())
end

function PANEL:Init()
	if (IsValid(ix.gui.miningConfig)) then
		ix.gui.miningConfig:Remove()
	end

	ix.gui.miningConfig = self

	ix.fallout.LoadMenuFonts()

	--[[
		Wide, because a row is nine things across and the fields have to hold
		a name at one end and a colour swatch at the other. Clamped to the
		screen, so a small resolution gets a smaller window rather than one
		with its right hand side over the edge.
	]]
	self:SetSize(math.min(ScrW() - Scaled(60), Scaled(1020)),
		math.min(ScrH() - Scaled(80), Scaled(640)))
	self:Center()
	self:MakePopup()
	self:SetTitle("MINING")

	--- A copy. The live list is not touched until the server sends it back.
	self.ores = table.Copy(ix.mining.ores or {})

	local footer = self:Add("Panel")

	footer:Dock(BOTTOM)
	footer:SetTall(Scaled(30))
	footer:DockMargin(0, Scaled(8), 0, 0)

	local close = footer:Add("ixFOButton")

	close:Dock(RIGHT)
	close:SetWide(Scaled(100))
	close:SetText("CLOSE")
	close:SetContentAlignment(5)
	close.DoClick = function() self:Remove() end

	local save = footer:Add("ixFOButton")

	save:Dock(RIGHT)
	save:SetWide(Scaled(100))
	save:DockMargin(0, 0, Scaled(6), 0)
	save:SetText("SAVE")
	save:SetContentAlignment(5)
	save.DoClick = function() self:Send() end

	local add = footer:Add("ixFOButton")

	add:Dock(LEFT)
	add:SetWide(Scaled(120))
	add:SetText("ADD ORE")
	add:SetContentAlignment(5)
	add.DoClick = function()
		Derma_StringRequest("New ore", "A short id, lowercase - 'copper'.",
			"", function(text)
				text = string.lower(string.Trim(text or ""))

				if (text == "") then return end

				for _, ore in ipairs(self.ores) do
					if (ore.id == text) then
						self:Notify("There is already an ore called that.")

						return
					end
				end

				self.ores[#self.ores + 1] = {
					id = text,
					name = text:upper():sub(1, 1) .. text:sub(2) .. " Ore",
					item = "",
					strength = 1,
					skin = 0,
					yield = 0,
					soft = 0,
					colour = {220, 220, 0}
				}

				self:Refresh()
			end, function() end, "Add", "Cancel")
	end

	self.hint = footer:Add("ixFOLabel")
	self.hint:Dock(FILL)
	self.hint:DockMargin(Scaled(8), 0, 0, 0)
	self.hint:SetContentAlignment(4)
	self.hint:SetFont("ixLootSmall")
	self.hint:SetText("Hits are for a 25kg node. A zero in Per drop or Sweet "
		.. "spot means \"use the config\". Swing size and respawn are in the "
		.. "dev terminal under MINING.")

	self.list = self:Add("ixFOScrollPanel")
	self.list:Dock(FILL)

	self:Refresh()
end

function PANEL:Notify(text)
	self.hint:SetText(text)
end

function PANEL:Refresh()
	self.list:Clear()

	if (#self.ores == 0) then
		local row = self.list:Add("ixFOPanelBracketed")

		row:Dock(TOP)
		row:SetTall(Scaled(36))
		row:DockPadding(Scaled(8), Scaled(6), Scaled(8), Scaled(6))

		local label = row:Add("ixFOLabel")
		label:Dock(FILL)
		label:SetFont("ixLootRow")
		label:SetText("No ores. Nodes need at least one.")

		return
	end

	for index, ore in ipairs(self.ores) do
		self:AddRow(index, ore)
	end
end

--[[
	One ore, as a row of fields.

	Everything is edited in place rather than behind an edit dialogue: seven
	ores with six fields each is a table, and a table is quicker to read and
	quicker to change than seven dialogues.
]]
function PANEL:AddRow(index, ore)
	local row = self.list:Add("ixFOPanelBracketed")

	row:Dock(TOP)
	row:SetTall(Scaled(72))
	row:DockMargin(0, 0, 0, Scaled(4))
	row:DockPadding(Scaled(8), Scaled(6), Scaled(8), Scaled(6))
	row:SetNoOverdraw(true)

	local remove = row:Add("ixFOButton")

	remove:Dock(RIGHT)
	remove:SetWide(Scaled(80))
	remove:DockMargin(Scaled(6), 0, 0, 0)
	remove:SetText("REMOVE")
	remove:SetContentAlignment(5)
	remove.DoClick = function()
		table.remove(self.ores, index)

		self:Refresh()
	end

	--[[
		The colour swatch doubles as the button that changes it - a square of
		the colour is the only label a colour needs.
	]]
	local swatch = row:Add("DButton")

	swatch:Dock(RIGHT)
	swatch:SetWide(Scaled(48))
	swatch:DockMargin(Scaled(6), 0, 0, 0)
	swatch:SetText("")
	swatch.Paint = function(_, width, height)
		surface.SetDrawColor(ix.mining.Colour(ore))
		surface.DrawRect(0, 0, width, height)

		surface.SetDrawColor(0, 0, 0, 220)
		surface.DrawOutlinedRect(0, 0, width, height, 1)
	end

	swatch.DoClick = function()
		local frame = vgui.Create("DFrame")

		frame:SetSize(Scaled(260), Scaled(280))
		frame:Center()
		frame:SetTitle(ore.name)
		frame:MakePopup()

		local mixer = frame:Add("DColorMixer")

		mixer:Dock(FILL)
		mixer:SetAlphaBar(false)
		mixer:SetPalette(true)
		mixer:SetColor(ix.mining.Colour(ore))
		mixer.ValueChanged = function(_, colour)
			ore.colour = {colour.r, colour.g, colour.b}
		end
	end

	--- Name, then the three numbers, then the item on the line below.
	local top = row:Add("Panel")

	top:Dock(TOP)
	top:SetTall(Scaled(26))
	top:DockMargin(0, 0, 0, Scaled(4))

	--[[
		A caption and a box, with the caption MEASURED rather than guessed.

		It was `#label * 7` scaled pixels - seven pixels a character - which is
		fine for "Skin" and cuts "Name" in half at any font scale where the
		characters are wider than that. `surface.GetTextSize` knows how wide the
		word actually is in the font it will be drawn in, and asking costs
		nothing at build time.

		`width` is what the whole field gets; the box takes whatever the caption
		leaves, and is never allowed to disappear entirely.
	]]
	local function Field(parent, label, width, value, onChange)
		surface.SetFont("ixLootSmall")

		local captionWidth = surface.GetTextSize(label) + Scaled(8)
		local total = math.max(Scaled(width), captionWidth + Scaled(46))

		local holder = parent:Add("Panel")

		holder:Dock(LEFT)
		holder:SetWide(total)
		holder:DockMargin(0, 0, Scaled(8), 0)

		local caption = holder:Add("ixFOLabel")

		caption:Dock(LEFT)
		caption:SetWide(captionWidth)
		caption:SetFont("ixLootSmall")
		caption:SetText(label)

		local entry = holder:Add("ixFOTextEntry")

		entry:Dock(FILL)
		entry:SetText(tostring(value))
		entry.OnValueChange = function(_, text) onChange(text) end

		return entry
	end

	Field(top, "Name", 250, ore.name, function(text)
		ore.name = string.Trim(text)
	end)

	--[[
		HARDNESS AND HITS ARE THE SAME NUMBER, and both are here because nobody
		tunes a rock by thinking "times one point two five" - they think "how
		many swings is this". Editing either one rewrites the other, against a
		reference node of 25kg, which is the tool's own default size.

		The conversion is in `sh_mining.lua` so the window and anything else
		that wants to say it agree.
	]]
	local hardness, hits

	local REFERENCE = 25

	hardness = Field(top, "Hardness", 150, ore.strength, function(text)
		ore.strength = math.Clamp(tonumber(text) or 1, 0.05, 20)

		if (IsValid(hits)) then
			hits:SetText(tostring(ix.mining.HitsFor(ore.strength, REFERENCE)))
		end
	end)

	hits = Field(top, "Hits/25kg", 160,
		ix.mining.HitsFor(ore.strength, REFERENCE), function(text)
			ore.strength = ix.mining.StrengthFor(text, REFERENCE)

			if (IsValid(hardness)) then
				hardness:SetText(tostring(ore.strength))
			end
		end)

	Field(top, "Skin", 100, ore.skin, function(text)
		ore.skin = math.Clamp(math.floor(tonumber(text) or 0), 0, 32)
	end)

	local bottom = row:Add("Panel")

	bottom:Dock(FILL)
	bottom:DockMargin(0, Scaled(4), 0, 0)

	local entry = Field(bottom, "Gives item", 310, ore.item, function(text)
		ore.item = string.lower(string.Trim(text))
	end)

	--[[
		How many of that item one milestone pays, and what a soft spot hit on
		this ore is worth. Zero in either means "whatever the config says",
		which is what an ore with no opinion writes.
	]]
	Field(bottom, "Per drop", 140, ore.yield or 0, function(text)
		ore.yield = math.Clamp(math.floor(tonumber(text) or 0), 0, 100)
	end)

	Field(bottom, "Sweet spot x", 170, ore.soft or 0, function(text)
		ore.soft = math.Clamp(tonumber(text) or 0, 0, 50)
	end)

	--[[
		THE ITEM IS CHECKED AS IT IS TYPED, because an ore pointing at an item
		that does not exist is a node that swallows every swing and gives
		nothing - and there is no way to notice that from in game except by
		mining one dry.
	]]
	local status = bottom:Add("ixFOLabel")

	status:Dock(FILL)
	status:SetFont("ixLootSmall")

	local function Check()
		local item = ix.item.list[ore.item or ""]

		if (ore.item == "") then
			status:SetTextColor(Color(255, 160, 90))
			status:SetText("  no item - this ore gives nothing")
		elseif (item) then
			status:SetTextColor(Color(150, 220, 150))
			status:SetText("  " .. item.name)
		else
			status:SetTextColor(Color(235, 90, 80))
			status:SetText("  no item called that")
		end
	end

	entry.OnValueChange = function(_, text)
		ore.item = string.lower(string.Trim(text))

		Check()
	end

	Check()

	local id = bottom:Add("ixFOLabel")

	id:Dock(RIGHT)
	id:SetWide(Scaled(110))
	id:SetContentAlignment(6)
	id:SetFont("ixLootSmall")
	id:SetText(ore.id .. "  ")
end

function PANEL:Send()
	net.Start("ixMiningSave")
		net.WriteUInt(#self.ores, 8)

		for _, ore in ipairs(self.ores) do
			net.WriteString(ore.id)
			net.WriteString(ore.name)
			net.WriteString(ore.item)
			net.WriteFloat(ore.strength)
			net.WriteUInt(math.floor(ore.skin), 8)
			net.WriteUInt(math.floor(ore.yield or 0), 8)
			net.WriteFloat(ore.soft or 0)
			net.WriteUInt(math.floor(ore.colour[1]), 8)
			net.WriteUInt(math.floor(ore.colour[2]), 8)
			net.WriteUInt(math.floor(ore.colour[3]), 8)
		end
	net.SendToServer()

	ix.fallout.PlayUISound("select")

	self:Notify("Saved.")
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then self:Remove() end
end

vgui.Register("ixFOMiningConfig", PANEL, "ixFOFrame")
