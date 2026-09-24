--[[
	Developer terminal.

	Four sections down the left - ITEMS, BOTS, CHARACTER, WORLD - rather than
	the flat list of item categories this started as. That list was fine when
	the schema had 218 weapons and nothing else; with 1,100 items and five
	systems behind it, "every item, grouped by category" is a browser, not a
	tool.

	Built from `ix.item.list` and `ix.loot.tables` rather than hand-written
	lists, so it never goes stale: an item added tomorrow appears tomorrow.

	NOTHING HERE IS A PERMISSION. Every button sends a request the server
	re-checks - the give handler, the bot spawner and the quick actions each
	verify admin from scratch. This decides what to OFFER.

	Actions that already have an admin command RUN THAT COMMAND rather than
	reimplementing it, so there is one implementation of each rule and it is
	the one that is already validated and logged.
]]

local PANEL = {}

local function Scaled(value)
	return math.Round(value * ix.fallout.GetFontScale())
end

--[[
	Wide enough for the word inside it.

	EVERY WIDTH IN THIS FILE IS A GUESS somebody made by eye at their own
	resolution and font scale, and "CONFIGURE" came out as "CONFIGU..." - the
	label is ellipsised by Derma with no error and no clue as to which button
	it happened to. So the number written at the call site is a MINIMUM and the
	text is measured; whichever is larger wins.

	`UI_Bold` is what `ixFOButton` sets in its own `Init`. Measuring against a
	different font would be measuring the wrong thing, so if that ever changes
	this has to change with it - which is why it is one function rather than
	thirty call sites.
]]
local function ButtonWidth(text, minimum)
	surface.SetFont("UI_Bold")

	local width = surface.GetTextSize(tostring(text or ""))

	return math.max(Scaled(minimum or 60), width + Scaled(18))
end

--[[
	The sections, in order. `build` fills the content pane; `controls` fills
	the strip above it, which is where each section puts its own search or
	buttons.
]]
local SECTIONS = {
	{id = "items", name = "ITEMS", note = "spawn anything, at any quality"},
	{id = "bots", name = "TEST BOTS", note = "armoured dummies to shoot"},
	{id = "character", name = "CHARACTER", note = "yourself: health, rads, XP"},
	{id = "world", name = "WORLD", note = "lootables, plants, farms, mining"},
	{id = "orbital", name = "ORBITAL", note = "drops and their timing"},
	{id = "pk", name = "PK", note = "who is marked, and what it costs"},
	{id = "restraint", name = "RESTRAINTS", note = "ties, cuffs and searching"},
	{id = "rarity", name = "RARITY", note = "the curve, and trading up"},
	{id = "karma", name = "KARMA", note = "what each faction earns"},
	{id = "settings", name = "ALL SETTINGS", note = "every dial, in one list"}
}

function PANEL:Init()
	if (IsValid(ix.gui.devMenu)) then
		ix.gui.devMenu:Remove()
	end

	ix.gui.devMenu = self

	--[[
		AS BIG AS THE SCREEN ALLOWS, up to a point. It was a fixed 880x600,
		which on a tall list meant scrolling past four rows at a time - and the
		terminal is the one window in this schema that is nothing but rows.
	]]
	self:SetSize(math.min(ScrW() - Scaled(80), Scaled(1220)),
		math.min(ScrH() - Scaled(60), Scaled(820)))
	self:Center()
	self:MakePopup()
	self:SetTitle("DEVELOPER TERMINAL")

	self.section = "items"
	self.category = nil
	self.filter = ""

	self:BuildFooter()
	self:BuildNav()
	self:BuildContent()

	self:SetSection("items")
end

function PANEL:Notify(text)
	self.hint:SetText(text)
end

function PANEL:BuildFooter()
	local footer = self:Add("Panel")

	footer:Dock(BOTTOM)
	footer:SetTall(Scaled(32))
	footer:DockMargin(0, Scaled(8), 0, 0)

	local close = footer:Add("ixFOButton")

	close:Dock(RIGHT)
	close:SetWide(Scaled(100))
	close:SetText("CLOSE")
	close:SetContentAlignment(5)
	close.DoClick = function() self:Remove() end

	self.hint = footer:Add("ixFOLabel")
	self.hint:Dock(FILL)
	self.hint:SetContentAlignment(4)
	self.hint:SetText("Admin only. Everything is logged.")
end

function PANEL:BuildNav()
	local nav = self:Add("Panel")

	nav:Dock(LEFT)
	nav:SetWide(Scaled(210))

	self.navButtons = {}

	for _, section in ipairs(SECTIONS) do
		local button = nav:Add("ixFOButton")

		button:Dock(TOP)
		button:SetTall(Scaled(38))
		button:DockMargin(0, 0, 0, Scaled(4))
		button:SetText(section.name)
		button:SetContentAlignment(7)
		button:DockPadding(Scaled(6), Scaled(4), 0, 0)
		button.DoClick = function()
			self:SetSection(section.id)
			ix.fallout.PlayUISound("select")
		end

		--[[
			The subtitle is PAINTED rather than a second label, because the
			button's own text colour flips when it is hovered or active and a
			child label would not follow it - a grey line under white text on a
			green fill is the one thing that would look broken here.
		]]
		button.PaintOver = function(panel, width, height)
			local palette = ix.fallout.GetPalette()
			local colour = (panel:IsHovered() or panel:GetActive())
				and palette.text_hover or palette.color_active

			draw.SimpleText(section.note, "ixLootSmall", Scaled(7),
				height - Scaled(5), colour, TEXT_ALIGN_LEFT,
				TEXT_ALIGN_BOTTOM)
		end

		self.navButtons[section.id] = button
	end

	--[[
		The category list only belongs to the ITEMS section, so it lives under
		the nav and is hidden with it rather than being a permanent column
		taking width from every other section.
	]]
	self.categoryList = nav:Add("ixFOScrollPanel")
	self.categoryList:Dock(FILL)
	self.categoryList:DockMargin(0, Scaled(8), 0, 0)
end

function PANEL:BuildContent()
	local right = self:Add("Panel")

	right:Dock(FILL)
	right:DockMargin(Scaled(10), 0, 0, 0)

	self.controls = right:Add("Panel")
	self.controls:Dock(TOP)
	self.controls:SetTall(Scaled(28))

	self.search = self.controls:Add("ixFOTextEntry")
	self.search:Dock(FILL)
	self.search:SetUpdateOnType(true)
	self.search.OnValueChange = function(_, text)
		self.filter = string.lower(string.Trim(text or ""))
		self:Populate()
	end

	self.content = right:Add("ixFOScrollPanel")
	self.content:Dock(FILL)
	self.content:DockMargin(0, Scaled(8), 0, 0)
end

function PANEL:SetSection(id)
	self.section = id
	self.category = nil

	for sectionID, button in pairs(self.navButtons) do
		button:SetActive(sectionID == id)
	end

	--[[
		Search is only meaningful where there is a list to filter. Leaving an
		inert box above the CHARACTER buttons would invite typing into it.
	]]
	local searchable = id == "items" or id == "bots"
		or id == "settings" or id == "karma"

	self.controls:SetVisible(searchable)
	self.categoryList:SetVisible(id == "items")

	if (searchable) then
		self.search:SetValue("")
		self.filter = ""
	end

	if (id == "items") then
		self:PopulateCategories()
	end

	self:Populate()
end

function PANEL:Populate()
	self.content:Clear()

	if (self.section == "rarity") then
		self:PopulateRarity()

		return
	end

	if (self.section == "settings") then
		self:PopulateSettings()

		return
	end

	if (self.section == "karma") then
		self:PopulateKarma()

		return
	end

	if (self.section == "items") then
		self:PopulateItems()
	elseif (self.section == "bots") then
		self:PopulateBots()
	elseif (self.section == "character") then
		self:PopulateCharacter()
	elseif (self.section == "orbital") then
		self:PopulateOrbital()
	elseif (self.section == "pk") then
		self:PopulatePK()
	elseif (self.section == "restraint") then
		self:PopulateRestraint()
	else
		self:PopulateWorld()
	end
end

--[[
	A row with a label, a subtitle and any number of buttons on the right.
	Every section is built out of this, which is what keeps them consistent.
]]
function PANEL:AddRow(text, subtitle, buttons, height)
	--[[
		A row with no buttons is a perfectly ordinary row, and `#buttons` on
		nil is an error rather than a zero. Defaulted here rather than at every
		call site, because the call sites that pass nothing are the ones that
		read best.
	]]
	buttons = buttons or {}

	local row = self.content:Add("ixFOPanelBracketed")

	row:Dock(TOP)
	row:SetTall(Scaled(height or 40))
	row:DockMargin(0, 0, 0, Scaled(4))
	row:DockPadding(Scaled(6), Scaled(5), Scaled(6), Scaled(5))
	row:SetNoOverdraw(true)

	--[[
		Reversed, because docking RIGHT stacks right-to-left in child order -
		without this the buttons read backwards from how they are written.
	]]
	for i = #buttons, 1, -1 do
		local definition = buttons[i]
		local button = row:Add("ixFOButton")

		button:Dock(RIGHT)
		button:SetWide(ButtonWidth(definition.text, definition.width))
		button:DockMargin(Scaled(4), 0, 0, 0)
		button:SetText(definition.text)

		--[[
			CENTRED, and it was not.

			`ixFOButton` defaults to `SetContentAlignment(4)` - left - because
			that is right for the menu's own tall buttons, and every row button
			in this window inherited it. On a 60-pixel button with a bracket
			drawn round it, left-aligned text sits against the bracket and
			reads as an accident.
		]]
		button:SetContentAlignment(5)

		button.DoClick = function()
			definition.callback(self)
			ix.fallout.PlayUISound("select")
		end
	end

	local label = row:Add("ixFOLabel")

	label:Dock(FILL)
	label:SetContentAlignment(4)
	label:SetText(text)

	if (subtitle) then
		row.PaintOver = function(_, width, height2)
			draw.SimpleText(subtitle, "UI_Small", Scaled(8), height2 - Scaled(4),
				ix.fallout.GetPalette().color_active,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
		end
	end

	return row
end

function PANEL:AddHeading(text)
	local label = self.content:Add("ixFOLabel")

	label:Dock(TOP)
	label:SetTall(Scaled(26))
	label:DockMargin(0, Scaled(4), 0, Scaled(2))
	label:SetContentAlignment(4)
	label:SetText(text)
	label:SetFont("UI_Bold")

	return label
end

function PANEL:Action(name)
	net.Start("ixFODevAction")
		net.WriteString(name)
	net.SendToServer()
end

--[[
	Change one config value.

	The key is validated on the server against a closed list - see
	`sv_devmenu.lua` - so this end can be as simple as sending what was typed.
	The panel is rebuilt afterwards on a short delay, because the answer comes
	back as Helix's own `ixConfigSet` broadcast and redrawing before it arrives
	would show the old number and read as the button not working.
]]
function PANEL:SetConfig(key, value)
	net.Start("ixFODevConfig")
		net.WriteString(key)
		net.WriteType(value)
	net.SendToServer()

	timer.Simple(0.3, function()
		if (IsValid(self)) then self:Populate() end
	end)
end

--[[
	A row for a config value that has to be one of a known list.

	A MENU, NOT A TEXT BOX. The loot table is the only one of these so far and
	it is the one that most needed it: a typed name that does not match a table
	is a container that opens empty, and the misspelling is invisible until
	somebody flies out to a drop and finds nothing in it.

	The list is read at the moment the menu opens rather than when the row is
	built, so a table made in the loot configurer a minute ago is in it.
]]
function PANEL:AddConfigChoice(key, label, note, Options)
	local value = tostring(ix.config.Get(key))

	self:AddRow(label, string.format("%s   -   now %s", note or "", value), {
		{text = "CHOOSE", width = 92, callback = function()
			local options = Options()

			if (#options == 0) then
				self:Notify("There are no loot tables yet.")

				return
			end

			local menu = DermaMenu()

			for _, option in ipairs(options) do
				local entry = menu:AddOption(option, function()
					self:SetConfig(key, option)
				end)

				--[[
					The one already chosen is marked rather than left out. A
					list that silently omits the current value reads as the
					current value not being a real option.
				]]
				if (option == value) then entry:SetIcon("icon16/tick.png") end
			end

			menu:Open()
		end}
	})
end

--[[
	A row for one config value, with the right editor for its type.

	Three shapes rather than one, because a number, a name and a switch are
	three different questions and a text box that accepts "yes" for a boolean
	is a text box somebody will type "true" into.
]]
function PANEL:AddConfigRow(key, label, note)
	local value = ix.config.Get(key)
	local kind = type(value)

	if (kind == "boolean") then
		self:AddRow(label, note or "", {
			{text = value and "ON" or "OFF", width = 70, callback = function()
				self:SetConfig(key, not value)
			end}
		})

		return
	end

	local shown = tostring(value)

	self:AddRow(label, string.format("%s   -   now %s", note or "", shown), {
		{text = "SET", width = 66, callback = function()
			Derma_StringRequest(label, note or key, shown, function(text)
				text = string.Trim(text)

				if (text == "") then return end

				self:SetConfig(key, kind == "number" and (tonumber(text) or 0)
					or text)
			end, function() end, "Set", "Cancel")
		end}
	})
end

--[[
	Commands are run through chat rather than reimplemented, so the terminal
	and a typed command take exactly the same path.
]]
function PANEL:Command(text)
	RunConsoleCommand("say", "/" .. text)
end

--- Every category that actually has an item in it, sorted.
function PANEL:PopulateCategories()
	self.categoryList:Clear()

	local seen, list = {}, {}

	for _, item in pairs(ix.item.list) do
		if (item.isBase) then continue end

		local category = item.category or "Other"

		if (not seen[category]) then
			seen[category] = true
			list[#list + 1] = category
		end
	end

	table.sort(list)
	table.insert(list, 1, false)

	for _, category in ipairs(list) do
		local button = self.categoryList:Add("ixFOButton")

		button:Dock(TOP)
		button:SetTall(Scaled(24))
		button:DockMargin(0, 0, 0, Scaled(3))
		button:SetText(category and string.upper(category) or "ALL")
		button:SetContentAlignment(5)
		button:SetActive(self.category == (category or nil))
		button.DoClick = function()
			self.category = category or nil
			self:PopulateCategories()
			self:Populate()
		end
	end
end

--[[
	EVERY DIAL THE TERMINAL MAY TOUCH, IN ONE SEARCHABLE LIST.

	The other pages are arranged by subject and say what each number means in
	the context of the system it belongs to, which is what makes them worth
	reading. This one exists for the other question - "there is a setting for
	this somewhere, where is it" - and answers it in one keystroke.

	BUILT FROM `ix.devmenu.configurable`, the same table the server enforces
	(see `sh_devmenu.lua`). So this page cannot offer a row the server would
	ignore, and a setting added anywhere in the schema appears here with no edit
	to this file at all.
]]
function PANEL:PopulateSettings()
	local categories = {}
	local order = {}

	for key in pairs(ix.devmenu.configurable) do
		local config = ix.config.stored[key]

		if (not config) then continue end

		local name = string.lower(key)
		local description = string.lower(config.description or "")

		if (self.filter ~= "" and not string.find(name, self.filter, 1, true)
		and not string.find(description, self.filter, 1, true)) then
			continue
		end

		local category = config.data and config.data.category
			or config.category or "Other"

		if (not categories[category]) then
			categories[category] = {}
			order[#order + 1] = category
		end

		table.insert(categories[category], key)
	end

	table.sort(order)

	local shown = 0

	for _, category in ipairs(order) do
		local keys = categories[category]

		table.sort(keys)

		self:AddHeading(string.upper(category))

		for _, key in ipairs(keys) do
			local config = ix.config.stored[key]

			--[[
				The KEY is the subtitle rather than the description, because
				this page is the one somebody reads with the console open -
				`ix_setconfig` and every report print the key, and matching a
				row to a line of output matters more here than a sentence that
				is already on the subject's own page.
			]]
			self:AddConfigRow(key, config.description or key, key)

			shown = shown + 1
		end
	end

	if (shown == 0) then
		self:AddHeading(self.filter ~= "" and "Nothing matches that."
			or "No settings are registered.")
	end
end

--[[
	KARMA, PER FACTION.

	Two pairs each: what its members earn every tick simply for being in it,
	and what KILLING one of them is worth to whoever did it. Phoenix keep both
	in the faction file; ours are generated
	(`_docs/tools/genfactions.py`), so anything written into them by hand is
	lost the next time that runs - which is why these live in the save and are
	edited here. See `sh_karma.lua`.

	The faction's own total is shown beside its name because it is the thing
	the numbers are for: a faction paying +5 good a minute and sitting at 12%
	is a faction whose members are undoing it faster than the clock builds it.
]]
--[[
	A SCROLLABLE PICKER, because `DermaMenu` is not one.

	A Derma menu with four hundred armours in it runs off the bottom of the
	screen and has no scrollbar - the bot page's slot picker was capped at
	sixty entries for exactly that reason, which meant most of the roster could
	not be chosen at all. This is the same idea in a window that scrolls, with
	its own search box, so the cap can go.

	`options` is a list of `{text, note, callback}`.
]]
function PANEL:OpenPicker(title, options)
	if (IsValid(self.picker)) then self.picker:Remove() end

	local frame = vgui.Create("ixFOFrame")

	self.picker = frame

	frame:SetSize(Scaled(460), math.min(ScrH() - Scaled(120), Scaled(620)))
	frame:Center()
	frame:SetTitle(string.upper(title or "CHOOSE"))
	frame:MakePopup()

	local close = frame:Add("ixFOButton")

	close:Dock(BOTTOM)
	close:SetTall(Scaled(28))
	close:DockMargin(0, Scaled(6), 0, 0)
	close:SetText("CLOSE")
	close:SetContentAlignment(5)
	close.DoClick = function() frame:Remove() end

	local search = frame:Add("ixFOTextEntry")

	search:Dock(TOP)
	search:SetTall(Scaled(26))
	search:DockMargin(0, 0, 0, Scaled(6))
	search:SetUpdateOnType(true)

	local list = frame:Add("ixFOScrollPanel")

	list:Dock(FILL)

	local function Fill(filter)
		list:Clear()

		filter = string.lower(string.Trim(filter or ""))

		local shown = 0

		for _, option in ipairs(options) do
			local text = option.text or ""

			if (filter ~= "" and not string.find(string.lower(text), filter, 1,
				true)) then
				continue
			end

			shown = shown + 1

			local row = list:Add("ixFOButton")

			row:Dock(TOP)
			row:SetTall(Scaled(30))
			row:DockMargin(0, 0, Scaled(4), Scaled(3))
			row:SetText(option.note and (text .. "   -   " .. option.note)
				or text)
			row:SetContentAlignment(4)
			row.DoClick = function()
				frame:Remove()

				option.callback()
			end
		end

		if (shown == 0) then
			local empty = list:Add("ixFOLabel")

			empty:Dock(TOP)
			empty:SetTall(Scaled(40))
			empty:SetContentAlignment(5)
			empty:SetFont("ixLootSmall")
			empty:SetText("Nothing matches that.")
		end
	end

	search.OnValueChange = function(_, text) Fill(text) end

	Fill("")

	return frame
end

function PANEL:PopulateKarma()
	self:AddConfigRow("karmaEnabled", "Karma is earned",
		"off leaves every number where it is and stops handing more out")
	self:AddConfigRow("karmaTimer", "Seconds between passive karma",
		"60 is Phoenix's")
	self:AddConfigRow("karmaNeedsRecognition",
		"Only show a title for people you know",
		"on is Phoenix's - a reputation belongs to a name")
	self:AddConfigRow("karmaNotify", "Tell people when they earn it",
		"passive karma is always quiet; this is for kills")

	self:AddHeading("SCOREBOARD ICONS - percentage of good karma")

	self:AddConfigRow("karmaIconVeryGood", "Best icon at or above",
		"the colour shades between milestones, so a faction close to the next "
		.. "one plainly looks like it")
	self:AddConfigRow("karmaIconGood", "Good icon at or above", "percent")
	self:AddConfigRow("karmaIconBad", "Bad icon below", "percent")
	self:AddConfigRow("karmaIconVeryBad", "Worst icon below", "percent")

	self:AddHeading("PER FACTION - passive is per tick, kill is per body")

	local factions = {}

	for _, faction in ipairs(ix.faction.indices) do
		if (self.filter ~= "" and not string.find(
			string.lower(faction.name or ""), self.filter, 1, true)) then
			continue
		end

		factions[#factions + 1] = faction
	end

	table.sort(factions, function(a, b) return a.name < b.name end)

	for _, faction in ipairs(factions) do
		local settings = ix.karma.Settings(faction.uniqueID)
		local good, bad = ix.karma.FactionKarma(faction.uniqueID)
		local band = ix.karma.Band(good, bad)

		--[[
			FOUR NUMBERS, FOUR BUTTONS, and each says what it is worth rather
			than being labelled somewhere else - a row of four unlabelled
			boxes is a row nobody can read without counting across to a
			heading.
		]]
		local function Edit(label, get, apply)
			return {text = label, width = 62, callback = function()
				Derma_StringRequest(faction.name, label, tostring(get()),
					function(text)
					local value = math.Clamp(math.floor(tonumber(text) or 0),
						0, 1000)

					local now = ix.karma.Settings(faction.uniqueID)

					apply(now, value)

					net.Start("ixKarmaSet")
						net.WriteString(faction.uniqueID)
						net.WriteInt(now.passive[1], 16)
						net.WriteInt(now.passive[2], 16)
						net.WriteInt(now.kill[1], 16)
						net.WriteInt(now.kill[2], 16)
					net.SendToServer()
				end)
			end}
		end

		self:AddRow(string.format("%s   -   %s", faction.name,
			good + bad > 0 and string.format("%s, %d%%", band.name,
				math.Round(ix.karma.Ratio(good, bad) * 100))
				or "nothing earned yet"),
			string.format("passive +%d/+%d   kill +%d/+%d   (good/bad)",
				settings.passive[1], settings.passive[2],
				settings.kill[1], settings.kill[2]), {
			Edit("P+" .. settings.passive[1], function()
				return ix.karma.Settings(faction.uniqueID).passive[1]
			end, function(now, value) now.passive[1] = value end),

			Edit("P-" .. settings.passive[2], function()
				return ix.karma.Settings(faction.uniqueID).passive[2]
			end, function(now, value) now.passive[2] = value end),

			Edit("K+" .. settings.kill[1], function()
				return ix.karma.Settings(faction.uniqueID).kill[1]
			end, function(now, value) now.kill[1] = value end),

			Edit("K-" .. settings.kill[2], function()
				return ix.karma.Settings(faction.uniqueID).kill[2]
			end, function(now, value) now.kill[2] = value end)
		})
	end

	if (#factions == 0) then
		self:AddHeading("No faction matches that.")
	end
end

function PANEL:PopulateItems()
	local matches = {}

	for uniqueID, item in pairs(ix.item.list) do
		if (item.isBase) then continue end

		if (self.category and (item.category or "Other") ~= self.category) then
			continue
		end

		if (self.filter ~= ""
		and not string.find(string.lower(item.name or uniqueID), self.filter, 1, true)
		and not string.find(string.lower(uniqueID), self.filter, 1, true)) then
			continue
		end

		matches[#matches + 1] = {uniqueID = uniqueID, item = item}
	end

	table.sort(matches, function(a, b)
		return (a.item.name or a.uniqueID) < (b.item.name or b.uniqueID)
	end)

	--[[
		WHAT QUALITY A SPAWNED WEAPON COMES OUT AT.

		Nothing else can produce one on demand: quality is rolled when a weapon
		is CRAFTED (`sh_rarity.lua`), so testing what a Legendary rifle actually
		does meant crafting until the curve gave you one. This is the one place
		it can simply be asked for.

		It is a MODE rather than a per-row button - the row already carries
		three - and it sticks until it is changed, because the reason to set it
		is usually "give me these six things at this tier".

		Only weapons carry a quality; the setting is ignored for everything
		else rather than stamping a tier onto a stimpak, which `ix.rarity` would
		otherwise happily store and nothing would ever read.
	]]
	local tier = self.giveRarity and ix.rarity.byID[self.giveRarity]

	self:AddRow("Quality for weapons",
		tier and string.format("%s   -   %.2gx damage", tier.name, tier.damage)
			or "as it comes - crafted weapons roll, spawned ones have none", {
		{text = "CHOOSE", width = 92, callback = function()
			local menu = DermaMenu()

			local none = menu:AddOption("As it comes", function()
				self.giveRarity = nil

				self:Populate()
			end)

			if (not self.giveRarity) then none:SetIcon("icon16/tick.png") end

			for _, entry in ipairs(ix.rarity.tiers) do
				local option = menu:AddOption(entry.name, function()
					self.giveRarity = entry.id

					self:Populate()
				end)

				if (self.giveRarity == entry.id) then
					option:SetIcon("icon16/tick.png")
				end
			end

			menu:Open()
		end}
	})

	--[[
		Capped, because the list rebuilds on every keystroke. The count below
		reports the TRUE total, so a search finding 400 things says so rather
		than looking like it found 150.
	]]
	local limit = 150

	for i = 1, math.min(#matches, limit) do
		local match = matches[i]
		local uniqueID = match.uniqueID
		local buttons = {}

		for _, amount in ipairs({1, 5, 10}) do
			buttons[#buttons + 1] = {
				text = amount == 1 and "GIVE" or ("x" .. amount),
				width = amount == 1 and 60 or 44,
				callback = function()
					net.Start("ixFODevGive")
						net.WriteString(uniqueID)
						net.WriteUInt(amount, 8)

						--- Blank means "as it comes"; see the row above.
						net.WriteString(self.giveRarity or "")
					net.SendToServer()
				end
			}
		end

		self:AddRow(match.item.name or uniqueID, uniqueID, buttons)
	end

	if (#matches > limit) then
		self:AddHeading(string.format("Showing %d of %d. Search to narrow it down.",
			limit, #matches))
	elseif (#matches == 0) then
		self:AddHeading("No items match.")
	end
end

--[[
	Bots: a loadout you build slot by slot, DR presets, and every armour
	ordered by what it actually stops.
]]
function PANEL:PopulateBots()
	self:BuildLoadout()

	self:AddHeading("PRESETS - spawns the armour closest to that resistance")

	local presets = {}

	for _, target in ipairs({0, 25, 50, 75, 90}) do
		presets[#presets + 1] = {
			text = target .. "%",
			width = 54,
			callback = function()
				self:SpawnBot(target > 0 and self:FindArmourByDR(target) or nil)
			end
		}
	end

	self:AddRow("Damage resistance", "0% is a bare bot - the control", presets)

	self:AddRow("Session", "bots are frozen and respawn where placed", {
		{text = "BARE BOT", width = 96, callback = function() self:SpawnBot(nil) end},
		{text = "CLEAR", width = 76, callback = function()
			net.Start("ixFODevDummyClear")
			net.SendToServer()
		end}
	})

	self:AddHeading("ARMOUR - ordered by what it stops")

	local matches = {}

	for uniqueID, item in pairs(ix.item.list) do
		if (not item.isArmor or not item.bodyType) then continue end

		if (self.filter ~= ""
		and not string.find(string.lower(item.name or uniqueID), self.filter, 1, true)
		and not string.find(string.lower(uniqueID), self.filter, 1, true)) then
			continue
		end

		matches[#matches + 1] = {uniqueID = uniqueID, item = item}
	end

	table.sort(matches, function(a, b)
		local left, right = a.item.resistance or 0, b.item.resistance or 0

		if (left == right) then
			return (a.item.name or a.uniqueID) < (b.item.name or b.uniqueID)
		end

		return left > right
	end)

	local limit = 80

	for i = 1, math.min(#matches, limit) do
		local match = matches[i]
		local pool = ix.armor.headSlots[match.item.bodyType] and "head"
			or ix.armor.bodySlots[match.item.bodyType] and "body" or "neither"

		self:AddRow(match.item.name or match.uniqueID,
			string.format("%d%% %s - %s%s", match.item.resistance or 0, pool,
				ix.armor.slotNames[match.item.bodyType] or match.item.bodyType,
				match.item.isPA and " - POWER ARMOUR" or ""),
			{{text = "SPAWN", width = 76, callback = function()
				self:SpawnBot(match.uniqueID)
			end}})
	end

	if (#matches > limit) then
		self:AddHeading(string.format("Showing the %d highest of %d.", limit, #matches))
	end
end

--[[
	THE LOADOUT: one row per slot, and what is in it.

	The presets answer "what does 50% resistance feel like"; this answers "what
	does THIS set stop", which is the question that comes up once the numbers
	are being balanced against each other. It is kept on the panel rather than
	sent anywhere until SPAWN, so building one costs nothing.

	Only slots that something can be picked for are listed - a roster with no
	backpacks should not show an empty Backpack row for ever - and the list
	itself is `ix.armor.slots`, so it is in the schema's own order.
]]
function PANEL:BuildLoadout()
	self.loadout = self.loadout or {}

	local worn = 0
	local resistanceHead, resistanceBody = 0, 0

	for _, uniqueID in pairs(self.loadout) do
		local itemTable = ix.item.list[uniqueID]

		if (not itemTable) then continue end

		worn = worn + 1

		if (ix.armor.headSlots[itemTable.bodyType]) then
			resistanceHead = resistanceHead + (itemTable.resistance or 0)
		elseif (ix.armor.bodySlots[itemTable.bodyType]) then
			resistanceBody = resistanceBody + (itemTable.resistance or 0)
		end
	end

	--[[
		The two pools are shown SEPARATELY and clamped the way the armour
		system clamps them - `armorMaxResistance` is applied to each pool
		rather than to the total, so a set adding up to 140% is not what
		anybody will experience. See `ix.armor.GetHeadDR`.
	]]
	local ceiling = ix.config.Get("armorMaxResistance", 90)

	self:AddHeading("LOADOUT - build a set, then spawn a bot wearing it")

	self:AddRow(string.format("%d piece(s) - head %d%%, body %d%%", worn,
		math.min(resistanceHead, ceiling), math.min(resistanceBody, ceiling)),
		string.format("each pool is capped at %d%% by armorMaxResistance",
			ceiling), {
		{text = "SPAWN", width = 76, callback = function()
			local pieces = {}

			for _, slot in ipairs(ix.armor.slots) do
				if (self.loadout[slot]) then
					pieces[#pieces + 1] = self.loadout[slot]
				end
			end

			if (#pieces < 1) then
				self:Notify("Nothing picked. Use CHOOSE on a slot first.")

				return
			end

			self:SpawnBot(pieces)
		end},
		{text = "CLEAR SET", width = 96, callback = function()
			self.loadout = {}

			self:Populate()
		end}
	})

	--- What can go in each slot, worked out once for the whole page.
	local bySlot = {}

	for uniqueID, itemTable in pairs(ix.item.list) do
		if (not itemTable.isArmor or not itemTable.bodyType) then continue end

		bySlot[itemTable.bodyType] = bySlot[itemTable.bodyType] or {}

		table.insert(bySlot[itemTable.bodyType],
			{uniqueID = uniqueID, item = itemTable})
	end

	for _, slot in ipairs(ix.armor.slots) do
		local options = bySlot[slot]

		if (not options) then continue end

		table.sort(options, function(a, b)
			return (a.item.name or a.uniqueID) < (b.item.name or b.uniqueID)
		end)

		local chosen = self.loadout[slot]
		local itemTable = chosen and ix.item.list[chosen]
		local buttons = {
			{text = "CHOOSE", width = 92, callback = function()
				--[[
					A SCROLLING WINDOW, not a Derma menu - see `OpenPicker`.
					The whole slot is offered, however many that is, because a
					list you cannot reach the bottom of is a list that does not
					contain what you are looking for.
				]]
				local entries = {}

				for _, option in ipairs(options) do
					entries[#entries + 1] = {
						text = option.item.name or option.uniqueID,
						note = string.format("%d%%%s",
							option.item.resistance or 0,
							option.item.isPA and "  POWER ARMOUR" or ""),
						callback = function()
							self.loadout[slot] = option.uniqueID

							self:Populate()
						end
					}
				end

				self:OpenPicker(ix.armor.slotNames[slot] or slot, entries)
			end}
		}

		if (chosen) then
			table.insert(buttons, {text = "X", width = 40, callback = function()
				self.loadout[slot] = nil

				self:Populate()
			end})
		end

		self:AddRow(ix.armor.slotNames[slot] or slot,
			itemTable and string.format("%s - %d%%",
				itemTable.name or chosen, itemTable.resistance or 0)
				or string.format("empty - %d to choose from", #options),
			buttons)
	end
end

--[[
	`pieces` is a list of uniqueIDs, or nil for a bare bot. The presets and the
	armour list both send one item; the loadout above sends a whole set.
]]
function PANEL:SpawnBot(pieces)
	if (isstring(pieces)) then pieces = {pieces} end

	pieces = pieces or {}

	net.Start("ixFODevDummy")
		net.WriteUInt(#pieces, 8)

		for _, uniqueID in ipairs(pieces) do
			net.WriteString(uniqueID)
		end

		--- The power armour suit to force; the server picks one when blank.
		net.WriteString("")
	net.SendToServer()
end

--[[
	The armour closest to a target resistance.

	Power armour is skipped: it changes headshots, stamina and speed as well as
	resistance, so a "50% DR" preset that picked one would not be measuring
	what it says.
]]
function PANEL:FindArmourByDR(target)
	local best, bestDelta

	for uniqueID, item in pairs(ix.item.list) do
		if (not item.isArmor or item.bodyType ~= "body" or item.isPA) then continue end

		local delta = math.abs((item.resistance or 0) - target)

		if (not bestDelta or delta < bestDelta) then
			best, bestDelta = uniqueID, delta
		end
	end

	return best
end

--[[
	Character: the state a tester needs to move around quickly.

	The sliders write through the existing admin commands, which already
	validate and log, so this pane is a shortcut rather than a second
	implementation.
]]
function PANEL:PopulateCharacter()
	local client = LocalPlayer()
	local character = client:GetCharacter()

	if (not character) then
		self:AddHeading("No character loaded.")
		return
	end

	--[[
		QUOTED. Character names contain spaces far more often than not, and
		Helix splits command arguments on whitespace unless they are quoted -
		so `charsetrads Test Test 50` would read "Test" as the player and
		"Test" as the number.
	]]
	local name = string.format("%q", character:GetName())

	self:AddHeading("CONDITION")

	self:AddRow("Health", string.format("%d / %d", client:Health(), client:GetMaxHealth()), {
		{text = "FULL", width = 70, callback = function() self:Action("heal") end}
	})

	self:AddRow("Everything", "health, hunger, thirst and rads", {
		{text = "RESET", width = 76, callback = function() self:Action("refill") end}
	})

	if (character.GetHunger) then
		self:AddRow("Hunger / thirst",
			string.format("%d%% / %d%%", character:GetHunger(), character:GetThirst()), {
			{text = "STARVE", width = 80, callback = function()
				self:Command("charsethunger " .. name .. " 0")
				self:Command("charsetthirst " .. name .. " 0")
			end},
			{text = "FULL", width = 66, callback = function()
				self:Command("charsethunger " .. name .. " 100")
				self:Command("charsetthirst " .. name .. " 100")
			end}
		})
	end

	if (character.GetRadiation) then
		self:AddRow("Radiation",
			string.format("%d - %s", character:GetRadiation(),
				ix.radiation.GetTier(character:GetRadiation()).name), {
			{text = "0", width = 44, callback = function()
				self:Command("charsetrads " .. name .. " 0")
			end},
			{text = "50", width = 44, callback = function()
				self:Command("charsetrads " .. name .. " 50")
			end},
			{text = "100", width = 48, callback = function()
				self:Command("charsetrads " .. name .. " 100")
			end}
		})
	end

	if (character.GetLevel) then
		self:AddHeading("PROGRESSION")

		local earned, span = ix.leveling.GetProgress(character)

		self:AddRow("Level " .. character:GetLevel(),
			string.format("%d / %d XP - %d point(s) unspent", earned, span,
				character:GetSkillPoints()), {
			{text = "+1 LVL", width = 74, callback = function()
				self:Command("charsetlevel " .. name .. " " .. (character:GetLevel() + 1))
			end},
			{text = "+500 XP", width = 82, callback = function()
				self:Command("charaddxp " .. name .. " 500")
			end},
			{text = "LVL 50", width = 74, callback = function()
				self:Command("charsetlevel " .. name .. " 50")
			end}
		})
	end

	self:AddHeading("INVENTORY")

	self:AddRow("Everything you are carrying", "cannot be undone", {
		{text = "STRIP", width = 76, callback = function()
			Derma_Query("Remove every item in your inventory?", "Strip inventory",
				"Yes", function() self:Action("stripitems") end,
				"No", function() end)
		end}
	})
end

--[[
	World: the things that accumulate while testing.
]]
function PANEL:PopulateWorld()
	self:AddHeading("CLEANUP")

	self:AddRow("Dropped items", "every ix_item entity on the map", {
		{text = "CLEAR", width = 76, callback = function()
			Derma_Query("Remove every dropped item on the map?", "Clear ground",
				"Yes", function() self:Action("clearground") end,
				"No", function() end)
		end}
	})

	self:AddHeading("LOOTABLES")

	self:AddRow("Placed containers",
		string.format("%d on this map", #ents.FindByClass("ix_lootable")), {
		{text = "SAVE", width = 70, callback = function()
			self:Action("savelootables")
		end},
		{text = "CLEAR", width = 76, callback = function()
			Derma_Query("Remove every lootable on this map?", "Clear lootables",
				"Yes", function() self:Action("clearlootables") end,
				"No", function() end)
		end}
	})

	self:AddRow("Container contents",
		"forces every container to re-roll on next open", {
		{text = "RESET", width = 76, callback = function()
			self:Action("resetlootables")
		end}
	})

	self:AddRow("Loot tables",
		string.format("%d authored", #ix.loot.GetNames()), {
		{text = "CONFIGURE", width = 110, callback = function()
			self:Remove()
			self:Command("lootconfig")
		end},
		{text = "TOOL", width = 68, callback = function()
			RunConsoleCommand("gmod_tool", "lootable")
			self:Remove()
		end}
	})

	self:AddHeading("PLANTS")

	local plants = 0

	for _, entity in ipairs(ents.FindByClass("ix_plant")) do
		if (IsValid(entity)) then plants = plants + 1 end
	end

	self:AddRow("Plants on this map",
		plants > 0 and (plants .. " placed with the point tool")
			or "none - place some with the point tool", {
		{text = "TOOL", width = 68, callback = function()
			RunConsoleCommand("gmod_tool", "fo_point")
			RunConsoleCommand("fo_point_type", "plant")

			self:Remove()
		end}
	})

	self:AddConfigRow("plantXP", "Experience for picking one",
		"10 is Phoenix's. How many it gives and how long it takes to grow "
		.. "back are per plant, on the tool")

	self:AddHeading("FARMING")

	local plots = 0

	for _, entity in ipairs(ents.FindByClass("ix_cropplot")) do
		if (IsValid(entity)) then plots = plots + 1 end
	end

	self:AddRow("Crop plots on this map",
		plots > 0 and (plots .. " placed - they are saved with the map")
			or "none - the Crop Plot item places one", {})

	self:AddConfigRow("farmPersist", "Plots survive a restart",
		"off is Phoenix's - a plot is a thing you put down for an evening")
	self:AddConfigRow("farmGrowTime", "Seconds a watered crop takes",
		"200 is Phoenix's")
	self:AddConfigRow("farmYield", "Plants per ripe crop", "3 is Phoenix's")
	self:AddConfigRow("farmXP", "Experience per ripe crop", "1 is Phoenix's")
	self:AddConfigRow("farmWaterMax", "Water a plot holds", "100 is Phoenix's")
	self:AddConfigRow("farmWaterRefill", "Water one canister adds",
		"25 is Phoenix's")
	self:AddConfigRow("farmWaterDrain", "Water used per crop per second",
		"0.05 is Phoenix's, written per second rather than per tenth")

	self:AddRow("Nothing grows without water",
		"and seeds and canisters are used up", {})

	self:AddHeading("MINING")

	local nodes = 0

	for _, entity in ipairs(ents.FindByClass("ix_orenode")) do
		if (IsValid(entity)) then nodes = nodes + 1 end
	end

	self:AddRow("Ore nodes standing on this map",
		nodes > 0 and (nodes .. " - emptied ones are absent until they refill")
			or "none - place some with the ore node tool", {
		{text = "TOOL", width = 68, callback = function()
			RunConsoleCommand("gmod_tool", "fo_mining")

			self:Remove()
		end},
		{text = "ORES", width = 68, callback = function()
			self:Remove()
			self:Command("miningconfig")
		end}
	})

	self:AddConfigRow("miningKgPerHit", "Kilogrammes an ordinary hit takes",
		"before the ore's own hardness")
	self:AddConfigRow("miningSoftMultiplier", "What a soft spot hit is worth",
		"in ordinary hits - this is the Rust part")
	self:AddConfigRow("miningSoftRadius", "How close a soft spot hit counts",
		"units")
	self:AddConfigRow("miningKgPerOre", "Kilogrammes per drop",
		"how much has to come off before ore drops")
	self:AddConfigRow("miningOrePerDrop", "How many ore each drop gives",
		"an ore can override this with its own Per drop in /miningconfig")
	self:AddConfigRow("miningXP", "Experience per ore", "2 is Phoenix's")
	self:AddConfigRow("miningRespawn", "Seconds an empty node takes to return",
		"the tool can override this per node")
	self:AddConfigRow("miningStrength", "A multiplier on every swing",
		"the quickest dial for making mining faster or slower everywhere")
	self:AddConfigRow("miningTool", "Weapon that can mine",
		"blank means anything")

	--[[
		CONTAINER SIZES.

		Helix's container definitions are a fixed table in the framework, and
		"how much does a wooden crate hold" is an economy decision that belongs
		with the rest of them. Listed by MODEL because that is what a definition
		is keyed by and what the map is built out of - the display name is not
		unique across the set.
	]]
	self:AddHeading("ARMOUR")

	self:AddConfigRow("armorRaceKinds", "Armour is cut for one kind of body",
		"a suit made for a person will not go onto a deathclaw or a "
		.. "securitron. An armour naming a race in armorRace overrides it")

	self:AddHeading("RACE INJECTORS")

	self:AddConfigRow("injectorTransformTime", "Seconds a transformation takes",
		"9 is Phoenix's - frozen, pulsing, and watched by everybody nearby")
	self:AddConfigRow("injectorDuration", "Seconds a temporary one lasts",
		"an item may override this with its own")
	self:AddConfigRow("injectorNeedsRestrained",
		"Somebody else must be tied up first",
		"off lets anybody who will stand still for five seconds be changed")

	self:AddHeading("CHAT AND CHARACTERS")

	self:AddConfigRow("chatMax", "Characters allowed in one chat message",
		"256 is Helix's. The chatbox refuses anything longer as it is typed")
	self:AddConfigRow("maxCharacters", "Character slots per player",
		"the server default - a rank may be given more of its own in the "
		.. "admin menu's RANKS page")

	self:AddHeading("CAMERA")

	self:AddConfigRow("thirdperson", "Helix's own third person",
		"OFF, because the Simple Thirdperson addon provides it instead - "
		.. "/thirdperson toggles that one. Turning this on runs both, and "
		.. "two cameras fight over the same view")

	self:AddHeading("CONTAINERS - what a placed prop holds")

	local models = {}

	for model in pairs(ix.container and ix.container.stored or {}) do
		models[#models + 1] = model
	end

	table.sort(models)

	for _, model in ipairs(models) do
		local definition = ix.container.stored[model]
		local width, height = ix.containers.SizeOf(model)
		local name = definition.name or model

		self:AddRow(string.format("%s - %dx%d", name, width, height),
			string.gsub(model, "^models/", ""), {
			{text = "SET", width = 66, callback = function()
				Derma_StringRequest(name,
					"Grid size as WIDTHxHEIGHT, between "
					.. ix.containers.minSize .. " and "
					.. ix.containers.maxSize .. ".",
					string.format("%dx%d", width, height), function(text)
					local w, h = string.match(text or "", "(%d+)%s*[xX]%s*(%d+)")

					if (not w) then
						self:Notify("Write it as 5x5.")

						return
					end

					net.Start("ixContainerSizeSet")
						net.WriteString(model)
						net.WriteUInt(math.Clamp(tonumber(w),
							ix.containers.minSize, ix.containers.maxSize), 6)
						net.WriteUInt(math.Clamp(tonumber(h),
							ix.containers.minSize, ix.containers.maxSize), 6)
					net.SendToServer()

					--[[
						Redrawn on a delay rather than immediately: the answer
						is the server's sync, and painting the number typed
						here would show a size the server may have clamped.
					]]
					timer.Simple(0.3, function()
						if (IsValid(self)) then self:Populate() end
					end)
				end)
			end}
		})
	end

	self:AddRow("A change reaches placed containers on the next restart",
		"anything outside a smaller grid stops being drawn, not deleted", {})

	self:AddHeading("STASH")

	local boxes = 0

	for _, entity in ipairs(ents.FindByClass("ix_stash")) do
		if (IsValid(entity)) then boxes = boxes + 1 end
	end

	self:AddRow("Stash boxes on this map",
		boxes > 0 and (boxes .. " placed - every one opens the same storage")
			or "none - place some with the point tool", {
		{text = "TOOL", width = 68, callback = function()
			RunConsoleCommand("gmod_tool", "fo_point")
			RunConsoleCommand("fo_point_type", "stash")

			self:Remove()
		end}
	})

	self:AddConfigRow("stashWidth", "Columns of storage",
		"6x6 is Phoenix's. Bigger is safe; smaller hides anything already "
		.. "outside the new grid rather than deleting it")
	self:AddConfigRow("stashHeight", "Rows of storage", "6 is Phoenix's")
	self:AddConfigRow("stashOpenTime", "Seconds spent opening one",
		"0.25 is Phoenix's")

	self:AddHeading("REPORTS - printed to console")

	for _, report in ipairs({
		{name = "Armour", command = "fo_armor_report"},
		{name = "Loot tables", command = "fo_loot_report"},
		{name = "SPECIAL", command = "fo_special"}
	}) do
		self:AddRow(report.name, report.command, {
			{text = "RUN", width = 66, callback = function()
				RunConsoleCommand(report.command)
				self:Notify("Printed to console: " .. report.command)
			end}
		})
	end
end

--[[
	Orbital drops, and everything that decides when one happens.

	IN THE TERMINAL RATHER THAN HELIX'S CONFIG MENU because that is where
	somebody testing the event already is - the buttons that call one, cancel
	one and count the sites are here, and having the numbers three menus away
	from the button that uses them is how a countdown gets set to an hour and
	left there.

	Helix's own config menu still has all of these; this is a second way in,
	not a replacement, and both write the same values through `ix.config.Set`.
]]
function PANEL:PopulateOrbital()
	local sites = 0

	for _, entity in ipairs(ents.FindByClass("ix_orbitalpad")) do
		if (IsValid(entity)) then sites = sites + 1 end
	end

	self:AddHeading("THE EVENT")

	self:AddRow("Drop sites on this map",
		sites > 0 and (sites .. " placed with the point tool")
			or "none - place some with the point tool, or nothing can happen",
		{
			{text = "TOOL", width = 68, callback = function()
				RunConsoleCommand("gmod_tool", "fo_point")
				RunConsoleCommand("fo_point_type", "orbital")

				self:Remove()
			end}
		})

	self:AddRow("Call one now", "a beacon lands at a random site", {
		{text = "RANDOM", width = 88, callback = function()
			self:Remove()
			self:Command("orbital")
		end},
		{text = "NEAREST", width = 90, callback = function()
			self:Remove()
			self:Command("orbitalhere")
		end},
		{text = "CANCEL", width = 82, callback = function()
			self:Command("orbitalcancel")
		end}
	})

	self:AddHeading("TIMING")

	self:AddConfigRow("orbitalEnabled", "Drops happen on their own",
		"the timer below")
	self:AddConfigRow("orbitalInterval", "Seconds between drops",
		"3600 is Phoenix's")
	self:AddConfigRow("orbitalBeaconTime", "Countdown on the beacon",
		"seconds - 300 is Phoenix's")
	self:AddConfigRow("orbitalDespawn", "Container lasts for",
		"seconds - 300 is Phoenix's")
	self:AddConfigRow("orbitalMinPlayers", "Players needed",
		"30 is Phoenix's, so nothing fires below that on a quiet server")

	self:AddHeading("THE CONTAINER")

	--[[
		The container is an ORDINARY LOOTABLE with this table on it. There is
		nothing else to tune: what is in a drop is what the table says, and
		making it worth flying out for is a job for the loot configurer rather
		than for a multiplier here.
	]]
	self:AddConfigChoice("orbitalLootTable", "Loot table",
		"the container is an ordinary lootable using this", function()
			local names = ix.loot.GetNames()

			table.sort(names)

			return names
		end)

	self:AddRow("Loot tables",
		string.format("%d authored", #ix.loot.GetNames()), {
		{text = "CONFIGURE", width = 110, callback = function()
			self:Remove()
			self:Command("lootconfig")
		end}
	})

	self:AddHeading("CHAT")

	self:AddConfigRow("orbitalAnnounce", "Announce where a beacon lands",
		"off is exactly Phoenix - they announce nothing")
end

--[[
	Player killing, and what one costs.

	THE COSTS ARE A PAIR AND THEY ARE SHOWN AS A PAIR. Two levels and a
	thousand caps above 50, five levels and five hundred below it - four
	numbers that only make sense next to each other, and the reason they are
	together on one screen rather than four rows apart in Helix's config list.

	Everybody currently marked is listed with what it would cost them, because
	that is the question somebody asks before deciding whether to take a mark
	back off.
]]
function PANEL:PopulatePK()
	self:AddHeading("MARKED RIGHT NOW")

	local marked = 0

	for _, other in ipairs(player.GetAll()) do
		--[[
			`ix.pk.Remaining` reads character data, which Helix networks to its
			OWNER only - so this end can only answer for the local player. The
			list is built from the netvar instead, which is public, and the
			cost is worked out from the level the scoreboard already knows.
		]]
		local until_ = other:GetNetVar("pkUntil")

		if (not until_ or until_ <= CurTime()) then continue end

		marked = marked + 1

		self:AddRow(other:Name(), string.format("%d seconds left",
			math.ceil(until_ - CurTime())), {
			{text = "UNMARK", width = 90, callback = function()
				self:Command("pkoff \"" .. other:Name() .. "\"")
			end}
		})
	end

	if (marked == 0) then
		self:AddRow("Nobody is marked", "/pk <name> marks somebody", {})
	end

	self:AddRow("List them in chat", "with what each one would lose", {
		{text = "LIST", width = 70, callback = function()
			self:Command("pklist")
		end}
	})

	self:AddHeading("HOW LONG A MARK LASTS")

	self:AddConfigRow("pkDuration", "Seconds after /pk",
		"Phoenix have no timer at all - theirs is on until they die")
	self:AddConfigRow("pkMuggingDuration", "Seconds after a mugging",
		"the mugging system does not exist yet; the number is ready for it")

	self:AddHeading("WHAT A PK COSTS AT OR ABOVE LEVEL 50")

	self:AddConfigRow("pkLevelsAbove", "Levels lost", "2 is Phoenix's")
	self:AddConfigRow("pkCapsAbove", "Caps lost", "1000 is Phoenix's")

	self:AddHeading("AND BELOW IT")

	self:AddConfigRow("pkLevelsBelow", "Levels lost", "5 is Phoenix's")
	self:AddConfigRow("pkCapsBelow", "Caps lost", "500 is Phoenix's")

	self:AddHeading("EVERYTHING ELSE A PK DOES")

	self:AddRow("Recognition", "wiped both ways, and offline players too", {})
	self:AddRow("The head", "dropped where they fell, named after them", {})
	self:AddRow("Skill points",
		"taken back for the levels lost, so a PK is not a discount", {})

	self:AddConfigRow("pkNotifyRange", "How far the notice carries",
		"800 is Phoenix's")
end

--[[
	Escape closes it, because that is the first thing anyone tries. The button
	is the real answer; this is the convenience, and it only works while the
	frame has focus.
]]
--[[
	Restraints, breaching charges and slave collars.

	THREE SYSTEMS ON ONE SCREEN because they are one situation: somebody is
	tied up, somebody is coming through a door to get them, and somebody is
	wearing a collar over the argument. The numbers only make sense read
	against each other - a five second zip tie and a five second untie is a
	stalemate; a ten second defuse against a ten second fuse is a coin toss.

	Every one of these is in Helix's own config menu as well. This is the
	second way in, next to the buttons that use them.
]]
function PANEL:PopulateRestraint()
	self:AddHeading("ZIP TIES")

	self:AddConfigRow("ziptieTime", "Seconds to tie somebody",
		"5 is Phoenix's")
	self:AddConfigRow("ziptieReleaseTime", "Seconds to cut a tie off",
		"5 is Phoenix's - anybody may do it, which is what makes ties weak")

	self:AddHeading("CUFFS")

	self:AddConfigRow("cuffTime", "Seconds to cuff somebody",
		"longer than a tie, and the cuffs are not used up")
	self:AddConfigRow("cuffReleaseTime", "Seconds to unlock cuffs",
		"and you need a pair of your own to do it at all")

	self:AddHeading("ELASTIC RESTRAINTS - the cuffs addon")

	self:AddRow("They are a weapon, not a pocket item",
		"equip them and hold click on somebody. Everything below is a field on the addon's SWEP", {})

	self:AddConfigRow("restraintTime", "Seconds of holding click",
		"0.9 is the addon's own")
	self:AddConfigRow("restraintStrength", "How hard to break out of",
		"1.0 is the addon's own - higher is harder")
	self:AddConfigRow("restraintRegen", "How fast they recover",
		"1.6 is the addon's own - higher means struggling gets you nowhere")
	self:AddConfigRow("restraintRope", "How far they can be dragged",
		"units - zero means no dragging at all")
	self:AddConfigRow("restraintGag", "They can be gagged", "")
	self:AddConfigRow("restraintBlind", "They can be blindfolded", "")

	self:AddRow("Drag, gag and blindfold are in the hold-E menu",
		"exactly the four entries Phoenix have", {})

	self:AddHeading("BEING RESTRAINED")

	self:AddConfigRow("restrainSearchTime", "Seconds to search somebody",
		"you have to keep looking at them for all of it")
	self:AddConfigRow("restrainSpeed", "How fast a tied person moves",
		"percent of walking pace")

	self:AddRow("Caps are not in the search window",
		"searching is not mugging - that is its own system", {})

	self:AddHeading("BREACHING CHARGES")

	self:AddConfigRow("breachTime", "Seconds a charge beeps for",
		"5 is Phoenix's")
	self:AddConfigRow("breachDoorRestore", "Seconds a door stays blown off",
		"30 is Phoenix's")
	self:AddConfigRow("breachRadius", "How far the blast reaches",
		"units - anything closer than this is blown too")

	self:AddRow("Doors that cannot be blown",
		string.format("%d blocked - fo_breach_block names the one you are "
			.. "looking at", table.Count(ix.breach.blacklist)), {})

	self:AddHeading("MUGGING")

	self:AddRow("Somebody restrained can be robbed",
		"the Mug entry in the hold-E menu. The MUGGER is the one marked for "
		.. "death afterwards", {})

	self:AddConfigRow("mugTime", "Seconds it takes", "5 is Phoenix's")
	self:AddConfigRow("mugPKTime", "Seconds the mugger is marked for",
		"30 is Phoenix's - the victim is told they have a PK reason")
	self:AddConfigRow("mugCooldown", "Before the mugger can rob again",
		"seconds")
	self:AddConfigRow("muggedCooldown", "Before the victim can be robbed again",
		"seconds")

	self:AddHeading("WHAT A MUGGING TAKES, BY THE VICTIM'S LEVEL")

	self:AddConfigRow("mugCaps10", "Below level 20", "100 is Phoenix's")
	self:AddConfigRow("mugCaps20", "Level 20 and up", "200 is Phoenix's")
	self:AddConfigRow("mugCaps30", "Level 30 and up", "300 is Phoenix's")
	self:AddConfigRow("mugCaps40", "Level 40 and up", "400 is Phoenix's")
	self:AddConfigRow("mugCaps50", "Level 50 and up", "500 is Phoenix's")

	self:AddConfigRow("mugCharismaPercent",
		"Percent less per point of their Charisma",
		"ours, not Phoenix's - the SPECIAL contract says Charisma lowers "
		.. "mugging caps and this is the system that can honour it")

	self:AddHeading("SLAVE COLLARS")

	self:AddConfigRow("slaveCollarMaxTime", "Seconds a collar runs for",
		"1200 is Phoenix's - when it runs out the collar falls off")
	self:AddConfigRow("slaveCollarExplodeTime", "Fuse once triggered",
		"seconds - 10 is Phoenix's")
	self:AddConfigRow("slaveCollarDamage", "Damage when it goes off",
		"50 is Phoenix's, and it is dealt to the wearer alone")
	self:AddConfigRow("slaveCollarDisarmIntelligence",
		"Intelligence needed to defuse one", "15 is Phoenix's")
	self:AddConfigRow("slaveCollarDisarmTime", "Seconds to defuse one",
		"failing starts the fuse")
end

--[[
	Rarity rolls at a chosen Luck.

	Two things at once, and both are needed. The TABLE is the maths - what
	`ix.rarity.Chances` says the odds are - and the SAMPLE is what actually
	comes out of `ix.rarity.Roll` over thousands of tries. A curve that is
	right and a roll that is wrong look identical from either one alone; side
	by side, a disagreement is obvious at a glance.

	It runs entirely on the client. The roll is shared code with no server
	state behind it, so sampling it here tests the same function the bench
	calls - and ten thousand rolls that never leave the machine cost nobody
	anything.
]]
function PANEL:PopulateRarity()
	self.luck = self.luck or 25
	self.samples = self.samples or {}

	self:AddRow(string.format("LUCK %d", self.luck),
		"Skill points cap at 25; buffs take it to 50, which is where the "
		.. "curve is anchored.", {
			{text = "-5", width = 44, callback = function()
				self.luck = math.max(self.luck - 5, 0)
				self.samples = {}
				self:Populate()
			end},
			{text = "+5", width = 44, callback = function()
				self.luck = math.min(self.luck + 5, ix.rarity.maxLuck)
				self.samples = {}
				self:Populate()
			end},
			{text = "MINE", callback = function()
				local character = LocalPlayer():GetCharacter()

				self.luck = character and ix.rarity.LuckOf(character) or 0
				self.samples = {}
				self:Populate()
			end},
			{text = "ROLL 10K", width = 80, callback = function()
				local counts = {}

				for _ = 1, 10000 do
					local id = ix.rarity.Roll(self.luck)

					counts[id] = (counts[id] or 0) + 1
				end

				self.samples = counts
				self:Populate()
			end}
		}, 46)

	local chances = ix.rarity.Chances(self.luck)
	local total = 0

	for _, count in pairs(self.samples) do total = total + count end

	for _, tier in ipairs(ix.rarity.tiers) do
		local chance = chances[tier.id] or 0
		local rolled = self.samples[tier.id] or 0

		local row = self:AddRow(tier.name, string.format(
			"%.2gx damage%s", tier.damage,
			total > 0 and string.format("     rolled %d  (%.3f%%)", rolled,
				rolled / total * 100) or ""), nil, 34)

		--[[
			WRAPPED, not replaced. `AddRow` sets its own `PaintOver` to draw
			the subtitle, so assigning one here would silently erase every
			subtitle on the page - which is where the sampled percentages are.

			The bar is drawn rather than written because the shape of the curve
			across seven tiers is the thing being checked, and a column of
			numbers does not show it.
		]]
		local paint = row.PaintOver

		row.PaintOver = function(pnl, width, height)
			if (paint) then paint(pnl, width, height) end

			local colour = ix.rarity.GetColor(tier.id)

			surface.SetDrawColor(ColorAlpha(colour, 70))
			surface.DrawRect(0, height - 3, width * chance, 3)

			draw.SimpleText(string.format("%.3f%%", chance * 100),
				"ixLootRow", width - Scaled(10), height * 0.5, colour,
				TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end
	end

	if (total > 0) then
		self:AddHeading(string.format("%d rolls sampled", total))
	end

	--[[
		The trade-up bench lives on this page rather than with the benches,
		because what it does is entirely about the ladder above: it is the one
		way to move up a tier without rolling for it, and the ceiling is a
		statement about the curve.
	]]
	self:AddHeading("TRADE UP - the bench mode")

	self:AddConfigRow("tradeupAmount", "Weapons in, per one out",
		"5 is Phoenix's. They must be the same kind AND the same quality")

	self:AddConfigChoice("tradeupMaxRarity", "Trades up as far as",
		"Legendary by default, so Master Craft and Pearlescent stay things "
		.. "you roll", function()
		local out = {}

		--[[
			The bottom tier is not offered: a ceiling of Common means the
			bench can never produce anything, which is a way to switch it off
			by accident rather than a setting anybody wants.
		]]
		for index, tier in ipairs(ix.rarity.tiers) do
			if (index > 1) then out[#out + 1] = tier.id end
		end

		return out
	end)
end

function PANEL:OnRemove()
	if (IsValid(self.picker)) then self.picker:Remove() end
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Remove()
	end
end

vgui.Register("ixFODevMenu", PANEL, "ixFOFrame")

net.Receive("ixFODevOpen", function()
	vgui.Create("ixFODevMenu")
end)

concommand.Add("fo_devmenu", function()
	net.Start("ixFODevRequest")
	net.SendToServer()
end)
