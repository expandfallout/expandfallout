--[[
	The NPC preset editor.

	Presets on the left, the chosen one's fields on the right, SAVE at the
	bottom. A preset is what a spawner spawns - see `libs/sh_npc.lua` - and
	every field of one is here: name, race and gender, health, accuracy,
	side, the chances it drops its gun and its armour, three searchable tick
	lists - the guns it may carry (one is picked per NPC), the armour it
	wears (one piece per slot), and loot, anything at all with a chance of
	its own.

	Built the way the live editor builds its rows, and for the same reason:
	the value is a table on the client until SAVE sends the whole thing,
	and the server cleans it, keeps it, and sends every client the list.
	`/npcpresets`, `fo_npcpresets`, or the button in the spawner tool.

	THE SEARCH BOXES ARE PLAIN `DTextEntry`, like the faction log's, and
	refill their list a quarter of a second after the last keystroke rather
	than on every one - a list of six hundred buttons rebuilt per key was
	what "the search bar breaks" was.
]]

local PANEL = {}

local function Scaled(value)
	return math.Round(value * (ix.fallout and ix.fallout.GetFontScale
		and ix.fallout.GetFontScale() or 1))
end

local function Palette()
	return ix.fallout and ix.fallout.GetPalette and ix.fallout.GetPalette() or {
		color_active = Color(255, 200, 100), text_primary = Color(230, 230, 220)
	}
end

function PANEL:Init()
	if (ix.fallout and ix.fallout.LoadMenuFonts) then ix.fallout.LoadMenuFonts() end

	self:SetSize(math.min(ScrW() - Scaled(60), Scaled(1100)),
		math.min(ScrH() - Scaled(60), Scaled(700)))
	self:Center()
	self:MakePopup()
	self:SetTitle("NPC PRESETS")

	self.content = self:Add("Panel")
	self.content:Dock(FILL)
	self.content:DockMargin(Scaled(8), Scaled(28), Scaled(8), Scaled(8))

	--- The left column: the list, and what to do to it.
	local left = self.content:Add("Panel")

	left:Dock(LEFT)
	left:SetWide(Scaled(230))
	left:DockMargin(0, 0, Scaled(8), 0)

	local actions = left:Add("Panel")

	actions:Dock(BOTTOM)
	actions:SetTall(Scaled(30) * 3 + Scaled(8))

	local function Action(text, callback)
		local button = actions:Add("ixFOButton")

		button:Dock(TOP)
		button:SetTall(Scaled(28))
		button:DockMargin(0, Scaled(2), 0, 0)
		button:SetText(text)
		button:SetFont("ixLootBadge")
		button:SetContentAlignment(5)
		button.DoClick = callback

		return button
	end

	Action("NEW", function() self:Edit(ix.npc.Default()) end)
	Action("DUPLICATE", function()
		if (not self.preset) then return end

		local copy = table.Copy(self.preset)

		copy.id = ""
		copy.name = string.sub(copy.name .. " copy", 1, 32)

		self:Edit(copy)
	end)
	Action("DELETE", function()
		if (not self.preset or self.preset.id == "" or not ix.npc.presets[self.preset.id]) then
			return
		end

		local id, name = self.preset.id, self.preset.name

		Derma_Query("Delete the preset '" .. name .. "'?", "NPC presets",
			"Delete", function()
				net.Start("ixNPCPresetDelete")
					net.WriteString(id)
				net.SendToServer()
			end, "Keep it")
	end)

	self.list = left:Add("ixFOScrollPanel")
	self.list:Dock(FILL)

	--- The right column: the fields, and SAVE.
	local right = self.content:Add("Panel")

	right:Dock(FILL)

	local bar = right:Add("Panel")

	bar:Dock(BOTTOM)
	bar:SetTall(Scaled(34))
	bar:DockMargin(0, Scaled(6), 0, 0)

	local save = bar:Add("ixFOButton")

	save:Dock(RIGHT)
	save:SetWide(Scaled(140))
	save:SetText("SAVE")
	save:SetFont("ixLootHeader")
	save:SetContentAlignment(5)
	save.DoClick = function() self:Save() end

	local close = bar:Add("ixFOButton")

	close:Dock(RIGHT)
	close:SetWide(Scaled(100))
	close:DockMargin(0, 0, Scaled(6), 0)
	close:SetText("CLOSE")
	close:SetFont("ixLootHeader")
	close:SetContentAlignment(5)
	close.DoClick = function() self:Remove() end

	self.note = bar:Add("ixFOLabel")
	self.note:Dock(FILL)
	self.note:SetFont("ixLootSmall")
	self.note:SetTextColor(Color(160, 160, 150))
	self.note:SetText("Type in a search box to find things to tick. SAVE sends the whole preset.")

	self.fields = right:Add("ixFOScrollPanel")
	self.fields:Dock(FILL)

	self.searches = {}

	self:BuildList()

	local first = ix.npc.PresetList()[1]

	self:Edit(first and table.Copy(first) or ix.npc.Default())

	hook.Add("NPCPresetsChanged", self, function()
		if (not IsValid(self)) then return end

		self:BuildList()

		if (self.preset and self.preset.id ~= "" and ix.npc.presets[self.preset.id]) then
			self:Edit(table.Copy(ix.npc.presets[self.preset.id]))
		end
	end)
end

function PANEL:OnRemove()
	hook.Remove("NPCPresetsChanged", self)
end

--------------------------------------------------------------------------------
-- The list
--------------------------------------------------------------------------------

function PANEL:BuildList()
	self.list:Clear()

	local header = self.list:Add("ixFOLabel")

	header:Dock(TOP)
	header:SetTall(Scaled(22))
	header:SetFont("ixLootRow")
	header:SetText("PRESETS")

	for _, preset in ipairs(ix.npc.PresetList()) do
		local button = self.list:Add("ixFOButton")

		button:Dock(TOP)
		button:SetTall(Scaled(30))
		button:DockMargin(0, 0, Scaled(4), Scaled(3))
		button:SetText(preset.name)
		button:SetFont("ixLootRow")
		button:SetContentAlignment(4)
		button:SetActive(self.preset ~= nil and self.preset.id == preset.id)
		button.DoClick = function() self:Edit(table.Copy(preset)) end
	end
end

--------------------------------------------------------------------------------
-- The fields
--------------------------------------------------------------------------------

--- One bracketed row with a title and a note; the control goes in after.
function PANEL:Row(title, note, tall)
	local row = self.fields:Add("ixFOPanelBracketed")

	row:Dock(TOP)
	row:SetTall(Scaled(tall or (note and 60 or 44)))
	row:DockMargin(0, 0, Scaled(4), Scaled(4))
	row:DockPadding(Scaled(8), Scaled(5), Scaled(8), Scaled(5))
	row:SetNoOverdraw(true)

	local label = row:Add("ixFOLabel")

	label:Dock(TOP)
	label:SetTall(Scaled(18))
	label:SetFont("ixLootRow")
	label:SetText(title)
	label:SetTextColor(Palette().text_primary)

	if (note) then
		local text = row:Add("ixFOLabel")

		text:Dock(TOP)
		text:SetTall(Scaled(16))
		text:SetFont("ixLootSmall")
		text:SetTextColor(Color(160, 160, 150))
		text:SetText(note)
	end

	return row
end

--- A grid that makes its row as tall as it needs.
local function Grid(row)
	local grid = row:Add("DIconLayout")

	grid:Dock(TOP)
	grid:DockMargin(0, Scaled(4), 0, 0)
	grid:SetSpaceX(Scaled(4))
	grid:SetSpaceY(Scaled(4))

	row.Think = function(this)
		local _, top = grid:GetPos()
		local want = top + grid:GetTall() + Scaled(8)

		if (math.abs(this:GetTall() - want) > 1) then
			this:SetTall(want)
			this:InvalidateParent(true)
		end
	end

	return grid
end

local function Toggle(grid, text, active, width, callback)
	local button = grid:Add("ixFOButton")

	button:SetSize(Scaled(width or 150), Scaled(24))
	button:SetText(text)
	button:SetFont("ixLootSmall")
	button:SetContentAlignment(5)
	button:SetActive(active)
	button.DoClick = callback

	return button
end

--- A search box in the faction log's style.
local function Search(row, value)
	local entry = row:Add("DTextEntry")

	entry:Dock(TOP)
	entry:SetTall(Scaled(24))
	entry:DockMargin(0, Scaled(4), 0, 0)
	entry:SetFont("ixLootRow")
	entry:SetPlaceholderText("search")
	entry:SetValue(value or "")
	entry:SetUpdateOnType(true)

	return entry
end

function PANEL:Choice(title, note, choices, current, callback)
	local row = self:Row(title, note)
	local grid = Grid(row)

	for _, choice in ipairs(choices) do
		Toggle(grid, choice.name, current == choice.id, 150, function()
			callback(choice.id)
			self:Refresh()
		end)
	end
end

function PANEL:Text(title, note, value, callback)
	local row = self:Row(title, note)
	local entry = row:Add("ixFOTextEntry")

	entry:Dock(TOP)
	entry:SetTall(Scaled(24))
	entry:DockMargin(0, Scaled(4), 0, 0)
	entry:SetValue(tostring(value or ""))
	entry.OnChange = function() callback(entry:GetValue()) end
	entry.OnEnter = function() callback(entry:GetValue()) end

	row:SetTall(row:GetTall() + Scaled(28))
end

function PANEL:Number(title, note, value, callback)
	self:Text(title, note, value, function(text)
		callback(tonumber(text) or value)
	end)
end

--[[
	A SEARCHABLE TICK LIST. Hundreds of armour items, so only what the
	search matches is shown, plus whatever is already ticked; a click ticks
	or unticks and the whole set stays on the preset. With `withChance`,
	each ticked thing gets a box for its own percentage.
]]
function PANEL:Items(key, title, note, items, chosen, withChance)
	local row = self:Row(title, note)
	local search = Search(row, self.searches[key])

	--[[
		A LIST OF FIXED HEIGHT THAT SCROLLS, not a row that grows: a row
		sized from its grid every frame was what crunched the window when
		the grid was rebuilt under it. The row is as tall as it will ever
		be from the start, and the grid scrolls inside it.
	]]
	local list = row:Add("ixFOScrollPanel")

	list:Dock(TOP)
	list:SetTall(Scaled(150))
	list:DockMargin(0, Scaled(4), 0, 0)

	local grid = list:Add("DIconLayout")

	grid:Dock(TOP)
	grid:SetSpaceX(Scaled(4))
	grid:SetSpaceY(Scaled(4))

	row:SetTall(row:GetTall() + Scaled(28 + 154))

	local function Fill()
		if (not IsValid(grid)) then return end

		grid:Clear()

		local needle = string.lower(string.Trim(search:GetValue() or ""))
		local shown = 0

		self.searches[key] = search:GetValue()

		for _, entry in ipairs(items) do
			local ticked = chosen[entry.id] ~= nil and chosen[entry.id] ~= false
			local name = tostring(entry.name or entry.id)
			local matches = needle ~= "" and (string.find(string.lower(name), needle, 1, true)
				or string.find(string.lower(entry.id), needle, 1, true))

			if (ticked or (matches and shown < 60)) then
				local text = entry.slot and string.format("%s (%s)", name, entry.slot) or name

				Toggle(grid, text, ticked, 200, function()
					if (chosen[entry.id]) then
						chosen[entry.id] = nil
					else
						chosen[entry.id] = withChance and 25 or true
					end

					Fill()
				end)

				if (ticked and withChance) then
					local chance = grid:Add("ixFOTextEntry")

					chance:SetSize(Scaled(56), Scaled(24))
					chance:SetValue(tostring(chosen[entry.id]))
					chance.OnChange = function()
						chosen[entry.id] = math.Clamp(tonumber(chance:GetValue()) or 0, 0, 100)
					end
				end

				if (not ticked) then shown = shown + 1 end
			end
		end
	end

	--- A quarter of a second after the last keystroke, not on every one.
	search.OnValueChange = function()
		timer.Create("ixNPCPresetSearch_" .. key, 0.25, 1, function()
			if (IsValid(search)) then Fill() end
		end)
	end

	Fill()
end

function PANEL:Refresh()
	self:Edit(self.preset)
end

function PANEL:Edit(preset)
	self.preset = preset
	self.fields:Clear()

	local header = self.fields:Add("ixFOLabel")

	header:Dock(TOP)
	header:SetTall(Scaled(24))
	header:SetFont("ixLootHeader")
	header:SetText(preset.id ~= "" and ("EDITING: " .. string.upper(preset.name)) or "NEW PRESET")

	self:Text("Name", nil, preset.name, function(v) preset.name = v end)

	self:Choice("Race", "the body it is drawn on; only races on the human skeleton",
		ix.npc.Races(), preset.race, function(v)
			preset.race = v
			preset.gender = ix.npc.Genders(v)[1]
		end)

	local genders = {}

	for _, gender in ipairs(ix.npc.Genders(preset.race)) do
		genders[#genders + 1] = {id = gender, name = string.upper(gender)}
	end

	self:Choice("Gender", nil, genders, preset.gender, function(v) preset.gender = v end)

	self:Choice("Side", "hostile and friendly are to everybody; a faction is allied "
		.. "with that faction's NPCs and its characters and fights the rest",
		ix.npc.Sides(), preset.side, function(v) preset.side = v end)

	self:Choice("Behaviour", "what it does about an enemy it can see; all three "
		.. "still take cover and chase somebody who breaks line of sight",
		ix.npc.Behaviours(), preset.behaviour,
		function(v) preset.behaviour = v end)

	self:Number("Health", nil, preset.health, function(v) preset.health = v end)
	self:Number("Accuracy", "1 is VJ's normal; below 1 shoots straighter, above 1 sprays",
		preset.accuracy, function(v) preset.accuracy = v end)
	self:Number("Chance it drops its gun (%)", nil, preset.dropWeapon or 0,
		function(v) preset.dropWeapon = v end)
	self:Number("Chance it drops each piece of armour (%)", nil, preset.dropArmour or 0,
		function(v) preset.dropArmour = v end)

	preset.weapons = preset.weapons or {}
	preset.armour = preset.armour or {}
	preset.loot = preset.loot or {}

	self:Items("weapons", "Guns", "one of these per NPC, at random",
		ix.npc.WeaponItems(), preset.weapons)
	self:Items("armour", "Armour", "worn over the race's body; one per slot",
		ix.npc.ArmourItems(), preset.armour)
	self:Items("loot", "Loot", "anything else left on the body, each with its own "
		.. "chance in percent", ix.npc.AllItems(), preset.loot, true)

	self:BuildList()
end

function PANEL:Save()
	if (not self.preset) then return end

	net.Start("ixNPCPresetSave")
		net.WriteTable(self.preset)
	net.SendToServer()
end

vgui.Register("ixFONPCPresets", PANEL, "ixFOFrame")
