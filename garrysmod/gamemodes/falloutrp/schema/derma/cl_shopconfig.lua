--[[
	The faction shop configurer. `/shopconfig`.

	    LEFT     every faction, with how many things it sells
	    MIDDLE   that faction's entries
	    RIGHT    the entry you are editing

	Everything an entry has is on the right and nothing else is: price, the
	category it files under, the lowest rank that may buy it, current stock,
	maximum stock, how much a restock adds and how often one happens.

	ONE WINDOW, THREE COLUMNS, rather than Phoenix's five separate ones - they
	have an editor, a category editor, an item editor, an item list and a
	restock-timer editor, each its own frame, because their stock lives in
	pools with their own ids and their own lifecycle. Ours is on the entry (see
	`sh_shop.lua`), so there is nothing to edit apart from an entry, and the
	whole thing fits in one place where you can see what you are changing
	against the faction it belongs to.

	CATEGORIES ARE TYPED, NOT MANAGED. A category is whatever string its
	entries name, so creating one is typing it and deleting one is moving the
	last entry out - there is no list to keep, and none to garbage collect.
]]

if (not CLIENT) then return end

local PANEL = {}

local function Scaled(value)
	return math.Round(value * ix.fallout.GetFontScale())
end

--[[
	Seconds to something readable, and back.

	`ix.util.GetStringTime` is a PARSER, not a formatter - handed 240 it
	returns 14400, because it reads the number as minutes. That mistake shipped
	once already in a chem description; see `25-chems.md`.
]]
local function FormatTime(seconds)
	seconds = math.max(math.floor(seconds or 0), 0)

	if (seconds < 60) then return seconds .. "s" end
	if (seconds < 3600) then return math.floor(seconds / 60) .. "m" end
	if (seconds < 86400) then
		return string.format("%.4gh", seconds / 3600)
	end

	return string.format("%.4gd", seconds / 86400)
end

--- Rows paint themselves; `ixFOButton` inverts on hover and eats the text.
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

function PANEL:Init()
	if (IsValid(ix.gui.shopConfig)) then
		ix.gui.shopConfig:Remove()
	end

	ix.gui.shopConfig = self

	ix.fallout.LoadMenuFonts()

	self:SetSize(math.min(ScrW() - Scaled(60), Scaled(1100)),
		math.min(ScrH() - Scaled(60), Scaled(700)))
	self:Center()
	self:MakePopup()
	self:SetTitle("FACTION SHOPS")

	--- `[factionUniqueID] = { [itemUniqueID] = entry }`, from the server.
	self.data = {}
	self.faction = nil
	self.entry = nil

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

	self.hint = footer:Add("ixFOLabel")
	self.hint:Dock(FILL)
	self.hint:SetContentAlignment(4)
	self.hint:SetFont("ixLootSmall")
	self.hint:SetText("Pick a shop, then an entry. EVERYONE is sold to every "
		.. "faction; a faction's own entry for the same item wins.")

	-- right: the editor
	self.editor = self:Add("Panel")
	self.editor:Dock(RIGHT)
	self.editor:SetWide(Scaled(300))

	-- left: factions
	local left = self:Add("Panel")

	left:Dock(LEFT)
	left:SetWide(Scaled(230))
	left:DockMargin(0, 0, Scaled(10), 0)

	local leftTitle = left:Add("ixFOLabel")

	leftTitle:Dock(TOP)
	leftTitle:SetTall(Scaled(22))
	leftTitle:SetFont("ixLootHeader")
	leftTitle:SetText("FACTIONS")

	self.factions = left:Add("ixFOScrollPanel")
	self.factions:Dock(FILL)

	-- middle: that faction's entries
	local middle = self:Add("Panel")

	middle:Dock(FILL)
	middle:DockMargin(0, 0, Scaled(10), 0)

	local head = middle:Add("Panel")

	head:Dock(TOP)
	head:SetTall(Scaled(22))

	--[[
		Named rather than a static "SELLS", so the column says WHOSE shop is
		being edited. Adding an item to EVERYONE by mistake because the two
		looked identical is a change that affects all 45 factions at once.
	]]
	self.midTitle = head:Add("ixFOLabel")

	self.midTitle:Dock(FILL)
	self.midTitle:SetFont("ixLootHeader")
	self.midTitle:SetText("SELLS")

	local add = head:Add("ixFOButton")

	add:Dock(RIGHT)
	add:SetWide(Scaled(70))
	add:SetText("ADD")
	add:SetContentAlignment(5)
	add.DoClick = function() self:OpenItemPicker() end

	local copyAll = head:Add("ixFOButton")

	copyAll:Dock(RIGHT)
	copyAll:DockMargin(0, 0, Scaled(4), 0)
	copyAll:SetWide(Scaled(90))
	copyAll:SetText("COPY ALL")
	copyAll:SetContentAlignment(5)
	copyAll.DoClick = function() self:OpenFactionPicker(nil) end

	self.entries = middle:Add("ixFOScrollPanel")
	self.entries:Dock(FILL)

	self:BuildEditor()

	net.Start("ixShopConfigOpen")
	net.SendToServer()
end

function PANEL:Say(text)
	if (IsValid(self.hint)) then
		self.hint:SetText(text)
	end
end

function PANEL:SetData(data)
	self.data = data

	--[[
		The selected entry is re-fetched rather than kept. The server sends a
		whole fresh copy after every change, so the table this was editing is
		garbage the moment it arrives - holding it would show stale numbers and
		save them back over the real ones.
	]]
	if (self.entry and self.faction) then
		local list = self.data[self.faction]

		self.entry = list and list[self.entry.item]
	end

	self:RefreshFactions()
	self:RefreshEntries()
	self:BuildEditor()
end

--- The name to show for a shop key, global included.
local function ShopName(id)
	if (id == ix.shop.GLOBAL) then return "EVERYONE" end

	local faction = ix.faction.teams[id]

	return faction and faction.name or id
end

function PANEL:RefreshFactions()
	self.factions:Clear()

	--[[
		THE GLOBAL SHOP IS PINNED ABOVE THE LIST, not sorted into it.

		It is not a faction and does not compete with them for a place in the
		alphabet - it is the thing that applies to all of them, so it sits above
		them and is separated by its own row height rather than by a colour
		chip it has no right to.
	]]
	local everyone = Row(self.factions, Scaled(28))

	everyone.selected = self.faction == ix.shop.GLOBAL

	everyone.PaintRow = function(_, width, tall)
		local palette = ix.fallout.GetPalette()
		local count = table.Count(self.data[ix.shop.GLOBAL] or {})

		draw.SimpleText("EVERYONE", "ixLootRow", Scaled(12), Scaled(3),
			palette.text_primary, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		draw.SimpleText("sold to every faction", "ixLootSmall",
			Scaled(12), Scaled(16),
			ColorAlpha(palette.color_primary, 180),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		if (count > 0) then
			draw.SimpleText(count, "ixLootSmall", width - Scaled(8),
				tall * 0.5, ColorAlpha(palette.color_primary, 200),
				TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end
	end

	everyone.DoClick = function()
		self.faction = ix.shop.GLOBAL
		self.entry = nil

		self:RefreshFactions()
		self:RefreshEntries()
		self:BuildEditor()
	end

	local gap = self.factions:Add("Panel")

	gap:Dock(TOP)
	gap:SetTall(Scaled(6))

	local names = {}

	for id, faction in pairs(ix.faction.teams) do
		names[#names + 1] = {id = id, name = faction.name,
			colour = faction.color, count = table.Count(self.data[id] or {})}
	end

	--[[
		Factions that sell something first, then alphabetically. Forty-five
		names is a long list to scroll and the handful that are configured are
		the ones anybody opening this window is looking for.
	]]
	table.sort(names, function(a, b)
		if ((a.count > 0) ~= (b.count > 0)) then return a.count > 0 end

		return a.name < b.name
	end)

	for _, entry in ipairs(names) do
		local row = Row(self.factions, Scaled(24))

		row.selected = self.faction == entry.id

		row.PaintRow = function(_, width, tall)
			local palette = ix.fallout.GetPalette()

			surface.SetDrawColor(entry.colour or palette.color_primary)
			surface.DrawRect(Scaled(9), tall * 0.5 - Scaled(5),
				Scaled(10), Scaled(10))

			draw.SimpleText(entry.name, "ixLootRow", Scaled(26), tall * 0.5,
				palette.text_primary, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			if (entry.count > 0) then
				draw.SimpleText(entry.count, "ixLootSmall",
					width - Scaled(8), tall * 0.5,
					ColorAlpha(palette.color_primary, 200),
					TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end
		end

		row.DoClick = function()
			self.faction = entry.id
			self.entry = nil

			self:RefreshFactions()
			self:RefreshEntries()
			self:BuildEditor()
		end
	end
end

function PANEL:RefreshEntries()
	self.entries:Clear()

	if (IsValid(self.midTitle)) then
		self.midTitle:SetText(self.faction
			and (string.upper(ShopName(self.faction)) .. " SELLS") or "SELLS")
	end

	if (not self.faction) then return end

	local list = self.data[self.faction] or {}
	local sorted = {}

	for uniqueID, entry in pairs(list) do
		sorted[#sorted + 1] = entry
	end

	table.sort(sorted, function(a, b)
		if (a.category ~= b.category) then
			return (a.category or "") < (b.category or "")
		end

		return a.item < b.item
	end)

	for _, entry in ipairs(sorted) do
		local itemTable = ix.item.list[entry.item]
		local row = Row(self.entries, Scaled(30))

		row.selected = self.entry == entry

		row.PaintRow = function(_, width, tall)
			local palette = ix.fallout.GetPalette()

			draw.SimpleText(itemTable and itemTable.name or entry.item,
				"ixLootRow", Scaled(10), Scaled(3),
				palette.text_primary, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

			draw.SimpleText(string.format("%s  -  %s  -  %s  -  %s",
				entry.category or "Misc",
				ix.currency.Get(entry.price or 0),
				ix.class.GetRankName(self.faction, entry.rank or 1),
				entry.infinite and "unlimited"
					or string.format("%d/%d, +%d every %s",
						entry.stock or 0, entry.maxStock or 0,
						entry.restockAmount or 0,
						FormatTime(entry.restockTime))),
				"ixLootSmall", Scaled(10), Scaled(17),
				ColorAlpha(palette.color_primary, 200),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end

		row.DoClick = function()
			self.entry = entry

			self:RefreshEntries()
			self:BuildEditor()
		end
	end
end

--[[
	The editor column, rebuilt whole rather than updated in place.

	It is a dozen widgets and it changes only when the selection does, so
	rebuilding is simpler than keeping every field in step with a table that
	the server can replace under it.
]]
function PANEL:BuildEditor()
	self.editor:Clear()

	local title = self.editor:Add("ixFOLabel")

	title:Dock(TOP)
	title:SetTall(Scaled(22))
	title:SetFont("ixLootHeader")

	if (not self.entry) then
		title:SetText("NOTHING SELECTED")

		return
	end

	local itemTable = ix.item.list[self.entry.item]

	title:SetText(string.upper(itemTable and itemTable.name or self.entry.item))

	local fields = {}

	local function Field(label, value, numeric)
		local caption = self.editor:Add("ixFOLabel")

		caption:Dock(TOP)
		caption:SetTall(Scaled(18))
		caption:SetFont("ixLootSmall")
		caption:SetText(label)

		local entry = self.editor:Add("ixFOTextEntry")

		entry:Dock(TOP)
		entry:SetTall(Scaled(24))
		entry:DockMargin(0, 0, 0, Scaled(6))
		entry:SetText(tostring(value))
		entry:SetNumeric(numeric or false)

		return entry
	end

	fields.category = Field("Category (type a new one to create it)",
		self.entry.category or "Misc")
	fields.price = Field("Price, in caps", self.entry.price or 0, true)

	local rankCaption = self.editor:Add("ixFOLabel")

	rankCaption:Dock(TOP)
	rankCaption:SetTall(Scaled(18))
	rankCaption:SetFont("ixLootSmall")
	rankCaption:SetText("Lowest class rank that may buy it")

	local rank = self.editor:Add("DComboBox")

	rank:Dock(TOP)
	rank:SetTall(Scaled(24))
	rank:DockMargin(0, 0, 0, Scaled(6))
	rank:SetSortItems(false)

	--[[
		THE FACTION'S OWN RUNGS, not "Enlisted / NCO / Officer / Lead".

		Those are the shape of a ladder and the name of almost none of them:
		the Kings have a Sergeant-at-Arms where the NCR has an NCO, and the
		Deathclaws have no rung 2 at all. Offering all four to every faction
		asked somebody to translate in their head, and setting a rank the
		faction has no class for is silent - the row simply never appears for
		anybody.

		`ix.class.GetRanks` returns only the rungs this faction actually has
		classes for, so what cannot be reached cannot be chosen.
	]]
	local selected = self.entry.rank or 1

	--[[
		The global shop has no ladder of its own, so it offers all four rungs
		under their generic names. A rank set there is compared against
		whatever rank the BUYER holds in their own faction, so "3" means "an
		officer of wherever you are" - which is the only thing it can mean.
	]]
	local ranks = self.faction == ix.shop.GLOBAL
		and {1, 2, 3, 4} or ix.class.GetRanks(self.faction)

	for _, value in ipairs(ranks) do
		local label = string.format("%d - %s", value,
			ix.class.GetRankName(
				self.faction ~= ix.shop.GLOBAL and self.faction or nil, value))

		rank:AddChoice(label, value, value == selected)
	end

	--[[
		An entry whose rank the faction lost - its classes were regenerated
		without that rung - would otherwise show an empty box that saves as
		whatever is first. Naming it keeps the current value visible and
		selectable until somebody deliberately changes it.
	]]
	if (rank:GetSelectedID() == nil) then
		rank:AddChoice(string.format("%d - (no class at this rank)", selected),
			selected, true)
	end

	--[[
		Unlimited stock, as a flag rather than a magic count.

		0 would be the natural sentinel and is the one value that cannot be
		used: it already means "sold out", so a shop set to unlimited would be
		indistinguishable from one that had just run dry.
	]]
	local infinite = self.editor:Add("DCheckBoxLabel")

	infinite:Dock(TOP)
	infinite:DockMargin(0, Scaled(2), 0, Scaled(6))
	infinite:SetText("Unlimited - never runs out, never restocks")
	infinite:SetTextColor(ix.fallout.GetPalette().text_primary)
	infinite:SetValue(self.entry.infinite and 1 or 0)

	fields.stock = Field("Stock now", self.entry.stock or 0, true)
	fields.maxStock = Field("Maximum stock", self.entry.maxStock or 0, true)
	fields.restockAmount = Field("Restock adds",
		self.entry.restockAmount or 0, true)
	fields.restockTime = Field(
		string.format("Restock every, in seconds (%s)",
			FormatTime(self.entry.restockTime)),
		self.entry.restockTime or 0, true)

	--[[
		The stock fields grey out when unlimited is ticked, rather than
		disappearing. Hiding them would make the panel jump about; greying says
		"these are still here and they are not being used".
	]]
	local function UpdateStockFields()
		local on = infinite:GetChecked()

		for _, key in ipairs({"stock", "maxStock", "restockAmount",
		"restockTime"}) do
			fields[key]:SetEnabled(not on)
		end
	end

	infinite.OnChange = UpdateStockFields

	UpdateStockFields()

	--[[
		SHARED STOCK.

		A list of the other entries in this shop that a purchase of this one
		also takes a unit off - "we have thirty rifles" rather than thirty of
		each rifle. See `ix.shop.Linked`.

		The list is edited in its own window because it is a list of items in a
		panel that is otherwise a column of numbers, and because picking from
		three hundred entries needs a search box.
	]]
	self.links = table.Copy(self.entry.links or {})

	local links = self.editor:Add("ixFOButton")

	links:Dock(TOP)
	links:DockMargin(0, Scaled(2), 0, Scaled(6))
	links:SetContentAlignment(5)
	links:SetText(string.format("SHARED STOCK (%d)", #self.links))

	links.DoClick = function()
		self:OpenLinkPicker(function()
			links:SetText(string.format("SHARED STOCK (%d)", #self.links))
		end)
	end

	--[[
		Copying this one entry into another faction's shop. The bulk version is
		on the middle column's header; both go through the same message.
	]]
	local copy = self.editor:Add("ixFOButton")

	copy:Dock(BOTTOM)
	copy:DockMargin(0, 0, 0, Scaled(4))
	copy:SetText("COPY TO...")
	copy:SetContentAlignment(5)

	copy.DoClick = function()
		self:OpenFactionPicker(self.entry.item)
	end

	local remove = self.editor:Add("ixFOButton")

	remove:Dock(BOTTOM)
	remove:SetText("REMOVE FROM SHOP")
	remove:SetContentAlignment(5)

	remove.DoClick = function()
		net.Start("ixShopConfigSet")
			net.WriteString(self.faction)
			net.WriteString(self.entry.item)
			net.WriteBool(true)
		net.SendToServer()

		self.entry = nil

		self:Say("Removing...")
	end

	local save = self.editor:Add("ixFOButton")

	save:Dock(BOTTOM)
	save:DockMargin(0, 0, 0, Scaled(4))
	save:SetText("SAVE")
	save:SetContentAlignment(5)

	save.DoClick = function()
		local _, rankIndex = rank:GetSelected()

		--[[
			Clamped here as well as on the server. The server is the one that
			counts, but a field left blank reading as 0 would come back as 1
			and look like the window ignored what was typed - so the value sent
			is the value that will be stored.
		]]
		local maxStock = math.max(tonumber(fields.maxStock:GetValue()) or 0, 0)
		local stock = math.Clamp(tonumber(fields.stock:GetValue()) or 0,
			0, maxStock)

		net.Start("ixShopConfigSet")
			net.WriteString(self.faction)
			net.WriteString(self.entry.item)
			net.WriteBool(false)
			net.WriteString(string.Trim(fields.category:GetValue()) ~= ""
				and string.Trim(fields.category:GetValue()) or "Misc")
			net.WriteUInt(math.max(tonumber(fields.price:GetValue()) or 0, 0), 32)
			net.WriteUInt(math.Clamp(rankIndex or self.entry.rank or 1, 1, 4), 3)
			net.WriteBool(infinite:GetChecked())
			net.WriteUInt(maxStock, 16)
			net.WriteUInt(stock, 16)
			net.WriteUInt(math.max(
				tonumber(fields.restockTime:GetValue()) or 0, 0), 32)
			net.WriteUInt(math.max(
				tonumber(fields.restockAmount:GetValue()) or 0, 0), 16)

			--- The shared stock list, capped the same way the server reads it.
			net.WriteUInt(math.min(#self.links, 32), 8)

			for index = 1, math.min(#self.links, 32) do
				net.WriteString(self.links[index])
			end
		net.SendToServer()

		self:Say("Saved.")
	end
end

--[[
	Choosing which other entries share this one's stock.

	ONLY THINGS THIS SHOP ALREADY SELLS. A link to an item that is not for sale
	here could never fire - `ix.shop.Linked` looks the id up in this shop's own
	list - so offering the whole item roster would be offering hundreds of
	choices that quietly do nothing.

	Each row toggles, and the window stays open while several are picked. It is
	saved with the rest of the entry, not on its own, so a mistake is undone by
	not pressing SAVE.
]]
function PANEL:OpenLinkPicker(onChanged)
	if (not self.entry) then return end

	local frame = vgui.Create("ixFOFrame")

	frame:SetSize(Scaled(420), Scaled(520))
	frame:Center()
	frame:MakePopup()
	frame:SetTitle("SHARED STOCK")

	local close = frame:Add("ixFOButton")

	close:Dock(BOTTOM)
	close:SetTall(Scaled(28))
	close:DockMargin(0, Scaled(6), 0, 0)
	close:SetText("DONE")
	close:SetContentAlignment(5)
	close.DoClick = function() frame:Remove() end

	local note = frame:Add("ixFOLabel")

	note:Dock(TOP)
	note:SetFont("ixLootSmall")
	note:SetWrap(true)
	note:SetAutoStretchVertical(true)
	note:DockMargin(0, 0, 0, Scaled(4))
	note:SetText("Buying this also takes one off everything ticked here. "
		.. "Links are one-way: tick the same box on the other entry as well "
		.. "if it should work both ways.")

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

		local entries = {}

		--[[
			`self.data` is what `SetData` stored - the whole configuration as
			the server last sent it. There is no `ix.shop.config`; that was a
			name I invented and it indexed nil the moment the window opened.
		]]
		for uniqueID, entry in pairs((self.data or {})[self.faction] or {}) do
			if (uniqueID == self.entry.item) then continue end

			local itemTable = ix.item.list[uniqueID]

			if (not itemTable) then continue end

			local name = itemTable.name or uniqueID

			if (filter ~= "" and not string.find(string.lower(name), filter, 1,
				true)) then
				continue
			end

			entries[#entries + 1] = {uniqueID = uniqueID, name = name,
				entry = entry}
		end

		table.sort(entries, function(a, b) return a.name < b.name end)

		for _, option in ipairs(entries) do
			local row = list:Add("ixFOButton")
			local linked = table.HasValue(self.links, option.uniqueID)

			row:Dock(TOP)
			row:SetTall(Scaled(28))
			row:DockMargin(0, 0, Scaled(4), Scaled(3))
			row:SetContentAlignment(4)
			row:SetActive(linked)
			row:SetText(string.format("%s%s   -   %d in stock",
				linked and "* " or "  ", option.name,
				option.entry.stock or 0))

			row.DoClick = function()
				if (table.HasValue(self.links, option.uniqueID)) then
					table.RemoveByValue(self.links, option.uniqueID)
				else
					self.links[#self.links + 1] = option.uniqueID
				end

				if (onChanged) then onChanged() end

				Fill(search:GetValue())
			end
		end

		if (#entries == 0) then
			local empty = list:Add("ixFOLabel")

			empty:Dock(TOP)
			empty:SetTall(Scaled(40))
			empty:SetContentAlignment(5)
			empty:SetFont("ixLootSmall")
			empty:SetText("Nothing else is for sale here.")
		end
	end

	search.OnValueChange = function(_, text) Fill(text) end

	Fill("")
end

--[[
	Picking an item to add.

	Every item in the schema, searchable - there are over a thousand and no
	amount of categorising makes that a list you scroll.
]]
function PANEL:OpenItemPicker()
	if (not self.faction) then
		self:Say("Pick a faction first.")

		return
	end

	local frame = vgui.Create("ixFOFrame")

	frame:SetSize(Scaled(420), Scaled(520))
	frame:Center()
	frame:MakePopup()
	frame:SetTitle("ADD AN ITEM")

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

	local existing = self.data[self.faction] or {}

	local function Fill(filter)
		list:Clear()

		local sorted = {}

		for uniqueID, itemTable in pairs(ix.item.list) do
			--[[
				Bases are skipped. `base_ammo` and the rest are templates, not
				things - adding one to a shop makes a row that cannot be
				instanced.
			]]
			if (string.StartWith(uniqueID, "base_")) then continue end
			if (existing[uniqueID]) then continue end

			if (filter ~= "" and not string.find(
			string.lower(itemTable.name), filter, 1, true)
			and not string.find(uniqueID, filter, 1, true)) then
				continue
			end

			sorted[#sorted + 1] = {id = uniqueID, name = itemTable.name,
				category = itemTable.category}
		end

		table.sort(sorted, function(a, b) return a.name < b.name end)

		for index, item in ipairs(sorted) do
			if (index > 200) then
				local more = list:Add("ixFOLabel")

				more:Dock(TOP)
				more:SetTall(Scaled(22))
				more:SetContentAlignment(5)
				more:SetFont("ixLootSmall")
				more:SetText(string.format(
					"%d more - narrow the search", #sorted - 200))

				break
			end

			local row = Row(list, Scaled(24))

			row.PaintRow = function(_, width, tall)
				local palette = ix.fallout.GetPalette()

				draw.SimpleText(item.name, "ixLootRow", Scaled(10), tall * 0.5,
					palette.text_primary, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

				draw.SimpleText(item.category or "", "ixLootSmall",
					width - Scaled(8), tall * 0.5,
					ColorAlpha(palette.color_primary, 180),
					TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end

			row.DoClick = function()
				--[[
					Added with the defaults from `ix.shop.NewEntry` - the
					item's own price and category where it has them - so a new
					row is immediately sensible and the editor is for changing
					it, not for filling it in from nothing.
				]]
				local blank = ix.shop.NewEntry(item.id)

				net.Start("ixShopConfigSet")
					net.WriteString(self.faction)
					net.WriteString(item.id)
					net.WriteBool(false)
					net.WriteString(blank.category)
					net.WriteUInt(blank.price, 32)
					net.WriteUInt(blank.rank, 3)
					net.WriteBool(blank.infinite)
					net.WriteUInt(blank.maxStock, 16)
					net.WriteUInt(blank.stock, 16)
					net.WriteUInt(blank.restockTime, 32)
					net.WriteUInt(blank.restockAmount, 16)
				net.SendToServer()

				self:Say("Added " .. item.name .. ".")
				frame:Remove()
			end
		end
	end

	search.OnValueChange = function(_, text)
		Fill(string.lower(string.Trim(text or "")))
	end

	Fill("")
end

--[[
	Where to copy to.

	`uniqueID` nil means the whole shop. One picker for both, because they are
	the same question - the only difference is how much goes - and two windows
	that differ by one word is two windows to keep in step.
]]
function PANEL:OpenFactionPicker(uniqueID)
	if (not self.faction) then
		self:Say("Pick a faction first.")

		return
	end

	local count = uniqueID and 1 or table.Count(self.data[self.faction] or {})

	if (count == 0) then
		self:Say("There is nothing to copy.")

		return
	end

	local frame = vgui.Create("ixFOFrame")

	frame:SetSize(Scaled(360), Scaled(480))
	frame:Center()
	frame:MakePopup()
	frame:SetTitle("COPY TO WHICH FACTION")

	local close = frame:Add("ixFOButton")

	close:Dock(BOTTOM)
	close:SetText("CANCEL")
	close:SetContentAlignment(5)
	close.DoClick = function() frame:Remove() end

	local caption = frame:Add("ixFOLabel")

	caption:Dock(TOP)
	caption:SetTall(Scaled(34))
	caption:SetWrap(true)
	caption:SetFont("ixLootSmall")
	caption:SetText(string.format(
		"%d entr%s from %s. Anything the target already sells is left alone.",
		count, count == 1 and "y" or "ies", ShopName(self.faction)))

	local list = frame:Add("ixFOScrollPanel")

	list:Dock(FILL)

	local names = {}

	for id, faction in pairs(ix.faction.teams) do
		if (id == self.faction) then continue end

		names[#names + 1] = {id = id, name = faction.name,
			colour = faction.color, count = table.Count(self.data[id] or {})}
	end

	table.sort(names, function(a, b) return a.name < b.name end)

	--[[
		And the global shop, at the top - copying a faction's ammunition list
		into EVERYONE is the shortest way to say "actually, anybody can buy
		this", which is the whole reason the global shop exists.
	]]
	if (self.faction ~= ix.shop.GLOBAL) then
		table.insert(names, 1, {id = ix.shop.GLOBAL, name = "EVERYONE",
			count = table.Count(self.data[ix.shop.GLOBAL] or {})})
	end

	for _, entry in ipairs(names) do
		local row = Row(list, Scaled(24))

		row.PaintRow = function(_, width, tall)
			local palette = ix.fallout.GetPalette()

			surface.SetDrawColor(entry.colour or palette.color_primary)
			surface.DrawRect(Scaled(9), tall * 0.5 - Scaled(5),
				Scaled(10), Scaled(10))

			draw.SimpleText(entry.name, "ixLootRow", Scaled(26), tall * 0.5,
				palette.text_primary, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			if (entry.count > 0) then
				draw.SimpleText(entry.count .. " already", "ixLootSmall",
					width - Scaled(8), tall * 0.5,
					ColorAlpha(palette.color_primary, 180),
					TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end
		end

		row.DoClick = function()
			net.Start("ixShopConfigCopy")
				net.WriteString(self.faction)
				net.WriteString(entry.id)
				net.WriteString(uniqueID or "")
			net.SendToServer()

			self:Say("Copying to " .. entry.name .. "...")
			frame:Remove()
		end
	end
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Remove()
	end
end

vgui.Register("ixFOShopConfig", PANEL, "ixFOFrame")

net.Receive("ixShopConfigAll", function()
	local factions = net.ReadUInt(8)
	local data = {}

	for _ = 1, factions do
		local faction = net.ReadString()
		local count = net.ReadUInt(16)

		data[faction] = {}

		for _ = 1, count do
			local uniqueID = net.ReadString()

			data[faction][uniqueID] = {
				item = uniqueID,
				category = net.ReadString(),
				price = net.ReadUInt(32),
				rank = net.ReadUInt(3),
				infinite = net.ReadBool(),
				stock = net.ReadUInt(16),
				maxStock = net.ReadUInt(16),
				restockTime = net.ReadUInt(32),
				restockAmount = net.ReadUInt(16),
				links = {}
			}

			--- What else a purchase of this draws from; see `ix.shop.Linked`.
			for _ = 1, net.ReadUInt(8) do
				table.insert(data[faction][uniqueID].links, net.ReadString())
			end
		end
	end

	if (not IsValid(ix.gui.shopConfig)) then
		vgui.Create("ixFOShopConfig")
	end

	if (IsValid(ix.gui.shopConfig)) then
		ix.gui.shopConfig:SetData(data)
	end
end)
