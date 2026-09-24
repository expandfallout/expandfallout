--[[
	The blueprint editor. BLUEPRINTS, in `/benchconfig`.

	    LEFT    every weapon that has a blueprint, searchable
	    RIGHT   what it costs to build, and how big its frame is

	A SEPARATE WINDOW FROM THE BENCH CONFIGURER, deliberately. Blueprint
	recipes are not a property of any bench - one list is shared by every
	blueprint bench on the server, because the knowledge is on the character
	and the bench is only a place to work. Editing them inside a particular
	bench's page would say the opposite.

	FRAME SIZE LIVES HERE TOO. A rifle frame that takes the same two slots as a
	pistol frame is a bag that tells you nothing about what is in it, and the
	right size per weapon is a balance question rather than a fact - so it is a
	setting rather than a number in a generated file that the next run of the
	generator would overwrite.
]]

if (not CLIENT) then return end

local PANEL = {}

local function Scaled(value)
	return math.Round(value * ix.fallout.GetFontScale())
end

local function Row(parent, height)
	local row = parent:Add("DButton")

	row:Dock(TOP)
	row:SetTall(height)
	row:DockMargin(0, 0, 0, Scaled(2))
	row:SetText("")

	row.selected = false

	row.Paint = function(pnl, width, tall)
		local palette = ix.fallout.GetPalette()
		local colour = Color(30, 30, 36, 200)

		if (pnl.selected) then
			colour = Color(70, 58, 32, 255)
		elseif (pnl:IsHovered()) then
			colour = Color(56, 52, 40, 255)
		end

		surface.SetDrawColor(colour)
		surface.DrawRect(0, 0, width, tall)

		if (pnl.selected or pnl:IsHovered()) then
			surface.SetDrawColor(palette.color_primary)
			surface.DrawRect(0, 0, Scaled(3), tall)
		end

		if (pnl.PaintRow) then
			pnl:PaintRow(width, tall)
		end
	end

	return row
end

local function Field(parent, text)
	local label = parent:Add("ixFOLabel")

	label:Dock(TOP)
	label:SetTall(Scaled(18))
	label:SetFont("ixLootSmall")
	label:SetText(text)

	return label
end

function PANEL:Init()
	if (IsValid(ix.gui.blueprintConfig)) then
		ix.gui.blueprintConfig:Remove()
	end

	ix.gui.blueprintConfig = self

	ix.fallout.LoadMenuFonts()

	self:SetSize(math.min(ScrW() - Scaled(80), Scaled(980)),
		math.min(ScrH() - Scaled(80), Scaled(700)))
	self:Center()
	self:MakePopup()
	self:SetTitle("BLUEPRINTS")

	--- The weapon being edited, and a working copy of its recipe.
	self.weapon = nil
	self.editing = nil

	local footer = self:Add("Panel")

	footer:Dock(BOTTOM)
	footer:SetTall(Scaled(30))
	footer:DockMargin(0, Scaled(8), 0, 0)

	local close = footer:Add("ixFOButton")

	close:Dock(RIGHT)
	close:SetWide(Scaled(90))
	close:SetText("CLOSE")
	close:SetContentAlignment(5)
	close.DoClick = function() self:Remove() end

	local save = footer:Add("ixFOButton")

	save:Dock(RIGHT)
	save:SetWide(Scaled(90))
	save:DockMargin(0, 0, Scaled(6), 0)
	save:SetText("SAVE")
	save:SetContentAlignment(5)
	save.DoClick = function() self:Commit() end

	self.hint = footer:Add("ixFOLabel")
	self.hint:Dock(FILL)
	self.hint:SetContentAlignment(4)
	self.hint:SetFont("ixLootSmall")
	self.hint:SetText("One list, shared by every blueprint bench. Frame size "
		.. "saves the moment you change it.")

	self.editor = self:Add("ixFOScrollPanel")
	self.editor:Dock(RIGHT)
	self.editor:SetWide(Scaled(320))
	self.editor:DockMargin(Scaled(10), 0, 0, 0)

	local left = self:Add("Panel")

	left:Dock(FILL)

	self.search = left:Add("ixFOTextEntry")
	self.search:Dock(TOP)
	self.search:SetTall(Scaled(26))
	self.search:DockMargin(0, 0, 0, Scaled(6))
	self.search:SetUpdateOnType(true)
	self.search:SetPlaceholderText("Search weapons")

	self.search.OnValueChange = function(_, text)
		self.filter = string.lower(string.Trim(text or ""))

		self:Rebuild()
	end

	self.list = left:Add("ixFOScrollPanel")
	self.list:Dock(FILL)

	self.filter = ""

	self:Rebuild()
end

function PANEL:Say(text)
	self.hint:SetText(text)
end

function PANEL:Rebuild()
	self.list:Clear()

	local shown = 0

	for _, weapon in ipairs(ix.blueprint.All()) do
		local itemTable = ix.item.list[weapon]

		if (not itemTable) then continue end

		if (self.filter ~= ""
		and not string.find(string.lower(itemTable.name), self.filter, 1, true)
		and not string.find(weapon, self.filter, 1, true)) then
			continue
		end

		shown = shown + 1

		if (shown > 250) then
			local more = self.list:Add("ixFOLabel")

			more:Dock(TOP)
			more:SetTall(Scaled(22))
			more:SetContentAlignment(5)
			more:SetFont("ixLootSmall")
			more:SetText("More - narrow the search.")

			break
		end

		local row = Row(self.list, Scaled(32))

		row.selected = self.weapon == weapon

		row.PaintRow = function(_, width, tall)
			local palette = ix.fallout.GetPalette()
			local edited = ix.blueprint.recipes[weapon] ~= nil
			local w, h = ix.blueprint.FrameSize(weapon)

			draw.SimpleText(itemTable.name, "ixLootRow", Scaled(10),
				tall * 0.5, palette.text_primary, TEXT_ALIGN_LEFT,
				TEXT_ALIGN_CENTER)

			draw.SimpleText(string.format("%s%dx%d frame",
				edited and "edited - " or "", w, h), "ixLootSmall",
				width - Scaled(8), tall * 0.5,
				ColorAlpha(palette.color_primary, edited and 220 or 130),
				TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end

		row.DoClick = function() self:Edit(weapon) end
	end

	if (shown == 0) then
		local empty = self.list:Add("ixFOLabel")

		empty:Dock(TOP)
		empty:SetTall(Scaled(30))
		empty:SetContentAlignment(5)
		empty:SetFont("ixLootSmall")
		empty:SetText("Nothing matches.")
	end
end

--- Take a working copy. Nothing is sent until SAVE; see the bench configurer.
function PANEL:Edit(weapon)
	self.weapon = weapon
	self.editing = ix.blueprint.Recipe(weapon)

	self:Rebuild()
	self:BuildEditor()
end

function PANEL:BuildEditor()
	self.editor:Clear()

	local recipe = self.editing
	local weapon = self.weapon

	if (not recipe or not weapon) then
		local empty = self.editor:Add("ixFOLabel")

		empty:Dock(TOP)
		empty:SetTall(Scaled(40))
		empty:SetContentAlignment(5)
		empty:SetWrap(true)
		empty:SetFont("ixLootSmall")
		empty:SetText("Pick a weapon on the left.")

		return
	end

	local itemTable = ix.item.list[weapon]

	local header = self.editor:Add("ixFOLabel")

	header:Dock(TOP)
	header:SetTall(Scaled(26))
	header:SetFont("ixLootHeader")
	header:SetText(string.upper(itemTable.name))

	--- The frame's size. Saved on change, not on SAVE - see the note below.
	Field(self.editor, "Frame size")

	local sizes = self.editor:Add("Panel")

	sizes:Dock(TOP)
	sizes:SetTall(Scaled(30))
	sizes:DockMargin(0, 0, 0, Scaled(2))

	local width, height = ix.blueprint.FrameSize(weapon)

	local function SendSize(w, h)
		net.Start("ixBlueprintFrame")
			net.WriteString(weapon)
			net.WriteUInt(math.Clamp(w, 1, 8), 4)
			net.WriteUInt(math.Clamp(h, 1, 8), 4)
		net.SendToServer()
	end

	local wide = sizes:Add("ixFONumberEntry")

	wide:Dock(LEFT)
	wide:SetWide(Scaled(120))
	wide:SetMin(1)
	wide:SetMax(8)
	wide:SetSuffix("wide")
	wide:SetValue(width)

	local tall = sizes:Add("ixFONumberEntry")

	tall:Dock(LEFT)
	tall:SetWide(Scaled(120))
	tall:DockMargin(Scaled(6), 0, 0, 0)
	tall:SetMin(1)
	tall:SetMax(8)
	tall:SetSuffix("tall")
	tall:SetValue(height)

	--[[
		SENT ON CHANGE, not held for SAVE, because a frame's size is not part
		of the recipe - it is a property of an item, and the server has to
		write it onto the item table for both realms before anything is placed
		in a grid. Batching it behind the same button as the recipe would make
		one button mean two unrelated things.
	]]
	wide.OnChanged = function(_, value)
		SendSize(value or 2, tall:GetValue() or 1)
	end

	tall.OnChanged = function(_, value)
		SendSize(wide:GetValue() or 2, value or 1)
	end

	local frameHint = self.editor:Add("ixFOLabel")

	frameHint:Dock(TOP)
	frameHint:SetFont("ixLootSmall")
	frameHint:SetWrap(true)
	frameHint:SetAutoStretchVertical(true)
	frameHint:DockMargin(0, 0, 0, Scaled(10))
	frameHint:SetText("How much room the frame takes in a bag. Saved as soon "
		.. "as you change it - it is a property of the item, not of this "
		.. "recipe.")

	--- Time and experience.
	Field(self.editor, "Time")

	local time = self.editor:Add("ixFONumberEntry")

	time:Dock(TOP)
	time:SetTall(Scaled(30))
	time:DockMargin(0, 0, 0, Scaled(2))
	time:SetMin(1)
	time:SetMax(3600)
	time:SetSuffix("seconds")
	time:SetValue(recipe.time or 60)

	local timeHint = self.editor:Add("ixFOLabel")

	timeHint:Dock(TOP)
	timeHint:SetTall(Scaled(18))
	timeHint:SetFont("ixLootSmall")
	timeHint:DockMargin(0, 0, 0, Scaled(6))
	timeHint:SetText(ix.bench.FormatTime(recipe.time or 60))

	time.OnChanged = function(_, value)
		recipe.time = value or 60

		timeHint:SetText(ix.bench.FormatTime(recipe.time))
	end

	Field(self.editor, "Experience")

	local xp = self.editor:Add("ixFONumberEntry")

	xp:Dock(TOP)
	xp:SetTall(Scaled(30))
	xp:DockMargin(0, 0, 0, Scaled(10))
	xp:SetMin(0)
	xp:SetMax(1000)
	xp:SetSuffix("XP")
	xp:SetValue(recipe.xp or 0)
	xp.OnChanged = function(_, value) recipe.xp = value or 0 end

	--- Inputs.
	local inputHeader = self.editor:Add("ixFOLabel")

	inputHeader:Dock(TOP)
	inputHeader:SetTall(Scaled(26))
	inputHeader:SetFont("ixLootHeader")
	inputHeader:SetText("COSTS")

	recipe.input = recipe.input or {}

	for index, entry in ipairs(recipe.input) do
		local row = self.editor:Add("Panel")

		row:Dock(TOP)
		row:SetTall(Scaled(30))
		row:DockMargin(0, 0, 0, Scaled(4))

		local remove = row:Add("ixFOButton")

		remove:Dock(RIGHT)
		remove:SetWide(Scaled(30))
		remove:SetText("X")
		remove:SetContentAlignment(5)

		remove.DoClick = function()
			table.remove(recipe.input, index)

			self:BuildEditor()
		end

		local quantity = row:Add("ixFONumberEntry")

		quantity:Dock(RIGHT)
		quantity:SetWide(Scaled(90))
		quantity:DockMargin(0, 0, Scaled(4), 0)
		quantity:SetMin(1)
		quantity:SetMax(999)
		quantity:SetValue(entry.amount or 1)
		quantity.OnChanged = function(_, value) entry.amount = value or 1 end

		local label = row:Add("ixFOLabel")

		label:Dock(FILL)
		label:SetFont("ixLootSmall")
		label:SetContentAlignment(4)

		local input = ix.item.list[entry.item]

		label:SetText(input and input.name
			or (entry.item or "?") .. " (missing)")
	end

	local add = self.editor:Add("ixFOButton")

	add:Dock(TOP)
	add:SetTall(Scaled(28))
	add:DockMargin(0, Scaled(4), 0, 0)
	add:SetText("ADD A COST")
	add:SetContentAlignment(5)

	add.DoClick = function()
		--[[
			The bench configurer already owns an item picker and it is the same
			question, so it is borrowed rather than written twice. Opening the
			bench configurer is not required - the picker is a method on it,
			and a hidden instance would be a window nobody asked for - so a
			small local copy is used when it is not open.
		]]
		self:OpenItemPicker(function(uniqueID)
			recipe.input[#recipe.input + 1] = {item = uniqueID, amount = 1}

			self:BuildEditor()
		end)
	end

	local reset = self.editor:Add("ixFOButton")

	reset:Dock(TOP)
	reset:SetTall(Scaled(28))
	reset:DockMargin(0, Scaled(10), 0, 0)
	reset:SetText("BACK TO THE DEFAULT")
	reset:SetContentAlignment(5)

	reset.DoClick = function()
		local default = (ix.blueprint.defaults or {})[weapon]

		if (not default) then
			self:Say("That weapon has no generated default.")

			return
		end

		--[[
			The stored override is cleared by SAVING the default back over it
			rather than by a delete message. One write path is one thing that
			can be wrong, and an admin who resets and then edits again is doing
			the same thing they were before.
		]]
		self.editing = nil
		ix.blueprint.recipes[weapon] = nil
		self.editing = ix.blueprint.Recipe(weapon)

		self:BuildEditor()
		self:Say("Back to the generated default - press SAVE to keep it.")
	end
end

function PANEL:OpenItemPicker(callback)
	local frame = vgui.Create("ixFOFrame")

	frame:SetSize(Scaled(420), Scaled(520))
	frame:Center()
	frame:MakePopup()
	frame:SetTitle("WHAT DOES IT COST?")

	local close = frame:Add("ixFOButton")

	close:Dock(BOTTOM)
	close:SetText("CANCEL")
	close:SetContentAlignment(5)
	close.DoClick = function() frame:Remove() end

	local search = frame:Add("ixFOTextEntry")

	search:Dock(TOP)
	search:SetTall(Scaled(26))
	search:DockMargin(0, 0, 0, Scaled(6))
	search:SetUpdateOnType(true)
	search:SetPlaceholderText("Search items")

	local list = frame:Add("ixFOScrollPanel")

	list:Dock(FILL)

	local function Fill(filter)
		list:Clear()

		local sorted = {}

		for uniqueID, itemTable in pairs(ix.item.list) do
			if (string.StartWith(uniqueID, "base_")) then continue end

			if (filter ~= "" and not string.find(
			string.lower(itemTable.name or ""), filter, 1, true)
			and not string.find(uniqueID, filter, 1, true)) then
				continue
			end

			sorted[#sorted + 1] = {id = uniqueID, name = itemTable.name}
		end

		table.sort(sorted, function(a, b)
			return (a.name or a.id) < (b.name or b.id)
		end)

		for index, item in ipairs(sorted) do
			if (index > 200) then break end

			local row = Row(list, Scaled(24))

			row.PaintRow = function(_, width, tall)
				draw.SimpleText(item.name or item.id, "ixLootRow", Scaled(10),
					tall * 0.5, ix.fallout.GetPalette().text_primary,
					TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end

			row.DoClick = function()
				callback(item.id)
				frame:Remove()
			end
		end
	end

	search.OnValueChange = function(_, text)
		Fill(string.lower(string.Trim(text or "")))
	end

	Fill("")
end

function PANEL:Commit()
	if (not self.weapon or not self.editing) then
		self:Say("Pick a weapon first.")

		return
	end

	if (#self.editing.input < 1) then
		self:Say("A blueprint that costs nothing is a free weapon. Add a "
			.. "cost.")

		return
	end

	net.Start("ixBlueprintSet")
		net.WriteString(self.weapon)
		net.WriteTable(self.editing)
	net.SendToServer()

	self:Say("Saved.")
end

function PANEL:OnRemove()
	if (ix.gui.blueprintConfig == self) then
		ix.gui.blueprintConfig = nil
	end
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Remove()
	end
end

vgui.Register("ixFOBlueprintConfig", PANEL, "ixFOFrame")
