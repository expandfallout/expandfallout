--[[
	The black market window.

	Phoenix's, tab for tab: BUY with its filters and pages, SELL with the
	price, quantity, duration, anonymity and note of a listing and what the
	seller keeps shown before they commit, MY LISTINGS with unlist and
	claim, and LOGS for staff. Built from this schema's widgets rather than
	their `UI_*` set, which does not exist here.

	Nothing here decides anything. Every page is asked for
	(`ix.blackmarket.Ask`) and every button is a request; the server answers
	with `ixMarketPage` and `ixMarketRefresh`. See `sv_blackmarket.lua`.

	`derma/` loads before `sh_schema.lua`: nothing from `ix.fallout`,
	`ix.blackmarket` or `ix.rarity` is read at file scope here.
]]

local PANEL = {}

local function Scaled(value)
	return math.max(math.Round(value * (ScrH() / 1080)), 1)
end

local NOTE = Color(190, 190, 180)
local DIM = Color(140, 140, 140)
local GOOD = Color(120, 220, 120)
local BAD = Color(230, 100, 90)

local function Caps(amount)
	return string.Comma(math.floor(tonumber(amount) or 0)) .. " caps"
end

local function Label(parent, text, font, color)
	local label = parent:Add("ixFOLabel")

	label:SetText(text or "")
	label:SetFont(font or "ixLootRow")
	label:SetTextColor(color or color_white)
	label:SizeToContents()

	return label
end

local function Button(parent, text, callback, wide)
	local button = parent:Add("ixFOButton")

	button:SetWide(Scaled(wide or 110))
	button:SetText(text)
	button:SetFont("ixLootBadge")
	button:SetContentAlignment(5)
	button.DoClick = callback

	return button
end

local function Entry(parent, placeholder, value)
	local entry = parent:Add("DTextEntry")

	entry:Dock(TOP)
	entry:SetTall(Scaled(28))
	entry:DockMargin(0, 0, 0, Scaled(6))
	entry:SetFont("ixLootRow")
	entry:SetPlaceholderText(placeholder or "")

	if (value ~= nil) then entry:SetValue(tostring(value)) end

	return entry
end

local function Combo(parent, text)
	local combo = parent:Add("DComboBox")

	combo:Dock(TOP)
	combo:SetTall(Scaled(28))
	combo:DockMargin(0, 0, 0, Scaled(6))
	combo:SetFont("ixLootBadge")
	combo:SetTextColor(color_white)
	combo:SetValue(text)

	return combo
end

local function Ask(title, question, default, callback)
	Derma_StringRequest(title, question, tostring(default or ""), function(text)
		callback(tonumber(text) or 0)
	end)
end

--------------------------------------------------------------------------------
-- The frame
--------------------------------------------------------------------------------

function PANEL:Init()
	if (ix.fallout and ix.fallout.LoadMenuFonts) then
		ix.fallout.LoadMenuFonts()
	end

	self:SetSize(math.min(Scaled(1120), ScrW() - 40),
		math.min(Scaled(740), ScrH() - 40))
	self:Center()
	self:MakePopup()
	self:SetTitle("BLACK MARKET")

	self.filter = {orderBy = "new"}
	self.page = 1
	self.pages = 1
	self.tab = "buy"

	self.tabs = self:Add("Panel")
	self.tabs:Dock(TOP)
	self.tabs:SetTall(Scaled(34))
	self.tabs:DockMargin(Scaled(8), Scaled(28), Scaled(8), Scaled(4))

	self.tabButtons = {}

	local function Tab(id, text)
		local button = Button(self.tabs, text, function() self:Show(id) end,
			150)

		button:Dock(LEFT)
		button:DockMargin(0, 0, Scaled(6), 0)

		self.tabButtons[id] = button
	end

	Tab("buy", "BUY")
	Tab("sell", "SELL")
	Tab("mine", "MY LISTINGS")

	if (ix.admin and ix.admin.Can(LocalPlayer(), "market.logs")) then
		Tab("logs", "LOGS")
	end

	local close = self:Add("ixFOButton")

	close:Dock(BOTTOM)
	close:SetTall(Scaled(30))
	close:DockMargin(Scaled(8), Scaled(4), Scaled(8), Scaled(8))
	close:SetText("CLOSE")
	close:SetFont("ixLootHeader")
	close:SetContentAlignment(5)
	close.DoClick = function() self:Remove() end

	self.content = self:Add("Panel")
	self.content:Dock(FILL)
	self.content:DockMargin(Scaled(8), 0, Scaled(8), 0)

	self:Show("buy")

	ix.gui.blackmarket = self
end

function PANEL:Think()
	if (IsValid(self.terminal)
	and LocalPlayer():GetPos():DistToSqr(self.terminal:GetPos()) > 256 * 256) then
		self:Remove()
	end
end

function PANEL:Show(tab)
	self.tab = tab
	self.page = 1

	for id, button in pairs(self.tabButtons) do
		button:SetAlpha(id == tab and 255 or 170)
	end

	self.content:Clear()

	if (tab == "sell") then
		self:BuildSell()
	else
		self:BuildList(tab)
		self:Reload()
	end
end

--- Ask the server for the page this tab is on, or rebuild the sell tab.
function PANEL:Reload()
	if (self.tab == "sell") then
		self:BuildSell()
	else
		ix.blackmarket.Ask(self.tab, self.page, self.filter)
	end
end

--------------------------------------------------------------------------------
-- Lists: buy, mine, logs
--------------------------------------------------------------------------------

function PANEL:BuildList(tab)
	local content = self.content

	if (tab == "buy") then self:BuildFilters(content) end

	local footer = content:Add("Panel")

	footer:Dock(BOTTOM)
	footer:SetTall(Scaled(30))
	footer:DockMargin(0, Scaled(6), 0, Scaled(4))

	local previous = Button(footer, "<", function()
		if (self.page > 1) then
			self.page = self.page - 1
			self:Reload()
		end
	end, 40)

	previous:Dock(LEFT)

	self.pageLabel = Label(footer, "", "ixLootBadge", NOTE)
	self.pageLabel:Dock(LEFT)
	self.pageLabel:DockMargin(Scaled(12), 0, Scaled(12), 0)
	self.pageLabel:SetWide(Scaled(200))

	local following = Button(footer, ">", function()
		if (self.page < self.pages) then
			self.page = self.page + 1
			self:Reload()
		end
	end, 40)

	following:Dock(LEFT)

	self.list = content:Add("DScrollPanel")
	self.list:Dock(FILL)

	self.loading = Label(self.list, "Loading...", "ixLootRow", NOTE)
	self.loading:Dock(TOP)
	self.loading:DockMargin(Scaled(8), Scaled(8), 0, 0)
end

function PANEL:BuildFilters(content)
	local side = content:Add("Panel")

	side:Dock(LEFT)
	side:SetWide(Scaled(250))
	side:DockMargin(0, 0, Scaled(8), 0)
	side:DockPadding(Scaled(8), Scaled(8), Scaled(8), Scaled(8))

	side.Paint = function(_, w, h)
		surface.SetDrawColor(0, 0, 0, 110)
		surface.DrawRect(0, 0, w, h)
	end

	Label(side, "SEARCH", "ixLootHeader"):Dock(TOP)

	local name = Entry(side, "Item name", self.filter.name)

	name:DockMargin(0, Scaled(6), 0, Scaled(6))

	local categories = {}

	for _, itemTable in pairs(ix.item.list) do
		local category = itemTable.category

		if (isstring(category) and not categories[category]) then
			categories[category] = true
		end
	end

	local category = Combo(side, self.filter.category or "Any category")

	category:AddChoice("Any category", "")

	for text in SortedPairs(categories) do category:AddChoice(text, text) end

	local minimum = Entry(side, "Min price", self.filter.minPrice)
	local maximum = Entry(side, "Max price", self.filter.maxPrice)

	local order = Combo(side, "Newest first")

	order:AddChoice("Newest first", "new")
	order:AddChoice("Oldest first", "old")
	order:AddChoice("Cheapest first", "cheap")
	order:AddChoice("Dearest first", "dear")

	local rarity = Combo(side, "Any rarity")

	rarity:AddChoice("Any rarity", "")

	if (ix.rarity and istable(ix.rarity.tiers)) then
		for index, tier in ipairs(ix.rarity.tiers) do
			rarity:AddChoice(tier.name or ("Tier " .. index), tier.id or "")
		end
	end

	local apply = Button(side, "APPLY", function()
		local _, categoryValue = category:GetSelected()
		local _, orderValue = order:GetSelected()
		local _, rarityValue = rarity:GetSelected()

		self.filter = {
			name = name:GetValue(),
			category = categoryValue,
			minPrice = tonumber(minimum:GetValue()),
			maxPrice = tonumber(maximum:GetValue()),
			orderBy = orderValue or "new",
			rarity = isstring(rarityValue) and rarityValue or ""
		}

		self.page = 1
		self:Reload()
	end, 200)

	apply:Dock(TOP)
	apply:SetTall(Scaled(30))

	local clear = Button(side, "CLEAR", function()
		self.filter = {orderBy = "new"}
		self.page = 1
		self:Show("buy")
	end, 200)

	clear:Dock(TOP)
	clear:SetTall(Scaled(30))
	clear:DockMargin(0, Scaled(6), 0, 0)
end

local function Icon(parent, uniqueID, sample)
	local itemTable = ix.item.list[uniqueID]
	local icon = parent:Add("SpawnIcon")

	icon:Dock(LEFT)
	icon:SetSize(Scaled(56), Scaled(56))
	icon:DockMargin(Scaled(4), Scaled(4), Scaled(8), Scaled(4))
	icon:SetModel(itemTable and itemTable.model or "models/error.mdl",
		sample and tonumber(sample.skin) or 0)

	return icon
end

--- Tier ids are strings; the first tier draws plain.
local function RarityColor(id)
	if (id and ix.rarity and ix.rarity.Tier and ix.rarity.GetColor
	and (ix.rarity.Tier(id).index or 1) > 1) then
		return ix.rarity.GetColor(id)
	end

	return color_white
end

--- What the server sent for the tab that asked.
function PANEL:Receive(tab, page, pages, count, rows)
	if (tab ~= self.tab or not IsValid(self.list)) then return end

	self.page, self.pages = page, pages
	self.list:Clear()

	if (IsValid(self.pageLabel)) then
		self.pageLabel:SetText(string.format("Page %d of %d  ·  %d %s", page,
			pages, count, tab == "logs" and "entries" or "listings"))
	end

	if (#rows == 0) then
		local empty = Label(self.list, tab == "buy" and "Nothing for sale "
			.. "that matches." or tab == "mine" and "You have nothing up."
			or "Nothing logged.", "ixLootRow", NOTE)

		empty:Dock(TOP)
		empty:DockMargin(Scaled(8), Scaled(8), 0, 0)

		return
	end

	for _, row in ipairs(rows) do
		if (tab == "logs") then
			self:LogRow(row)
		else
			self:ListingRow(row, tab == "mine")
		end
	end
end

function PANEL:LogRow(entry)
	local row = self.list:Add("Panel")

	row:Dock(TOP)
	row:SetTall(Scaled(30))
	row:DockMargin(0, 0, 0, Scaled(3))

	row.Paint = function(_, w, h)
		surface.SetDrawColor(0, 0, 0, 100)
		surface.DrawRect(0, 0, w, h)
	end

	local when = Label(row, os.date("%d %b %H:%M", entry.time or 0),
		"ixLootBadge", NOTE)

	when:Dock(LEFT)
	when:SetWide(Scaled(120))
	when:DockMargin(Scaled(8), 0, 0, 0)

	local text = Label(row, entry.text or "", "ixLootBadge")

	text:Dock(FILL)
end

function PANEL:ListingRow(row, mine)
	local panel = self.list:Add("Panel")

	panel:Dock(TOP)
	panel:SetTall(Scaled(64))
	panel:DockMargin(0, 0, 0, Scaled(4))

	local tint = RarityColor(row.rarity)

	panel.Paint = function(_, w, h)
		surface.SetDrawColor(0, 0, 0, 110)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(tint.r, tint.g, tint.b, row.expired and 90 or 255)
		surface.DrawRect(0, 0, Scaled(4), h)
	end

	if (row.notes and row.notes ~= "") then
		panel:SetTooltip("Note: " .. row.notes)
	end

	Icon(panel, row.item, row.sample)

	local buttons = panel:Add("Panel")

	buttons:Dock(RIGHT)
	buttons:SetWide(Scaled(mine and 240 or 120))
	buttons:DockMargin(0, Scaled(14), Scaled(8), Scaled(14))

	if (mine) then
		if ((row.earned or 0) > 0) then
			local claim = Button(buttons, "CLAIM " .. Caps(row.earned),
				function() ix.blackmarket.SendClaim(row.id) end, 130)

			claim:Dock(RIGHT)
			claim:DockMargin(Scaled(4), 0, 0, 0)
		end

		if ((row.left or 0) > 0) then
			local unlist = Button(buttons, "UNLIST", function()
				Ask("Unlist", string.format("How many to take back? %d are up.",
					row.left), row.left, function(quantity)
					ix.blackmarket.SendUnlist(row.id, quantity)
				end)
			end, 100)

			unlist:Dock(RIGHT)
		end
	elseif (row.mine) then
		local yours = Label(buttons, "YOURS", "ixLootBadge", NOTE)

		yours:Dock(RIGHT)
		yours:SetContentAlignment(6)
	else
		local buy = Button(buttons, "BUY", function()
			Ask("Buy", string.format("How many? %d for sale at %s each.",
				row.left, Caps(row.price)), 1, function(quantity)
				if (quantity >= 1) then
					ix.blackmarket.SendBuy(row.id, quantity)
				end
			end)
		end, 110)

		buy:Dock(RIGHT)
	end

	local price = Label(panel, Caps(row.price) .. " each", "ixLootRow")

	price:Dock(RIGHT)
	price:SetWide(Scaled(150))
	price:SetContentAlignment(6)
	price:DockMargin(0, 0, Scaled(12), 0)

	local text = panel:Add("Panel")

	text:Dock(FILL)

	local name = Label(text, row.name or row.item, "ixLootRow", tint)

	name:Dock(TOP)
	name:DockMargin(0, Scaled(6), 0, 0)

	local status

	if (row.expired) then
		status = "Expired"
	elseif ((row.left or 0) == 0) then
		status = "Sold out"
	else
		status = "Expires in " .. ix.blackmarket.Left(row.expires - os.time())
	end

	local line = Label(text, string.format("%s  ·  %d of %d left  ·  %s%s",
		row.seller or "?", row.left or 0, row.total or 0, status,
		mine and string.format("  ·  sold %d  ·  %d%% tax", row.sold or 0,
			row.tax or 0) or ""), "ixLootBadge",
		row.expired and BAD or (row.left or 0) == 0 and GOOD or NOTE)

	line:Dock(TOP)
	line:DockMargin(0, Scaled(2), 0, 0)

	if (row.notes and row.notes ~= "") then
		local note = Label(text, row.notes, "ixLootBadge", DIM)

		note:Dock(TOP)
	end
end

--------------------------------------------------------------------------------
-- Selling
--------------------------------------------------------------------------------

--- The bag, one row per kind of item, with how many there are.
local function Kinds()
	local character = LocalPlayer():GetCharacter()
	local inventory = character and character:GetInventory()
	local kinds, order = {}, {}

	if (not inventory) then return order end

	for _, item in pairs(inventory:GetItems()) do
		if (item:GetData("equip")) then continue end

		local ok = ix.blackmarket.CanList(ix.item.list[item.uniqueID])

		if (not ok) then continue end

		local kind = kinds[item.uniqueID]

		if (not kind) then
			kind = {uniqueID = item.uniqueID, count = 0, id = item:GetID(),
				rarity = item:GetData("rarity"), skin = item:GetData("skin")}
			kinds[item.uniqueID] = kind
			order[#order + 1] = kind
		end

		kind.count = kind.count + 1
	end

	table.sort(order, function(a, b)
		return ix.blackmarket.Name(a.uniqueID, a.rarity)
			< ix.blackmarket.Name(b.uniqueID, b.rarity)
	end)

	return order
end

function PANEL:BuildSell()
	local content = self.content

	content:Clear()

	local side = content:Add("Panel")

	side:Dock(RIGHT)
	side:SetWide(Scaled(340))
	side:DockMargin(Scaled(8), 0, 0, 0)
	side:DockPadding(Scaled(10), Scaled(8), Scaled(10), Scaled(8))

	side.Paint = function(_, w, h)
		surface.SetDrawColor(0, 0, 0, 110)
		surface.DrawRect(0, 0, w, h)
	end

	Label(side, "LISTING", "ixLootHeader"):Dock(TOP)

	self.selectedLabel = Label(side, "Pick something from your bag.",
		"ixLootRow", NOTE)
	self.selectedLabel:Dock(TOP)
	self.selectedLabel:DockMargin(0, Scaled(4), 0, Scaled(8))

	Label(side, "Quantity", "ixLootBadge", NOTE):Dock(TOP)

	local quantity = Entry(side, "How many", 1)

	Label(side, "Price per unit", "ixLootBadge", NOTE):Dock(TOP)

	local price = Entry(side, "Caps each", ix.config.Get("marketMinPrice", 2))

	Label(side, "Duration", "ixLootBadge", NOTE):Dock(TOP)

	local days = Combo(side, "1 day  (" .. ix.blackmarket.Tax(1) .. "% tax)")

	for day = 1, ix.config.Get("marketMaxDays", 7) do
		days:AddChoice(string.format("%d day%s  (%d%% tax)", day,
			day == 1 and "" or "s", ix.blackmarket.Tax(day)), day)
	end

	days:ChooseOptionID(1)

	local anonymous = side:Add("DCheckBoxLabel")

	anonymous:Dock(TOP)
	anonymous:DockMargin(0, 0, 0, Scaled(6))
	anonymous:SetText("Anonymous listing")
	anonymous:SetFont("ixLootBadge")
	anonymous:SetTextColor(color_white)

	Label(side, "Note (optional, " .. ix.blackmarket.NOTE .. " characters)",
		"ixLootBadge", NOTE):Dock(TOP)

	local notes = side:Add("DTextEntry")

	notes:Dock(TOP)
	notes:SetTall(Scaled(64))
	notes:DockMargin(0, 0, 0, Scaled(6))
	notes:SetMultiline(true)
	notes:SetFont("ixLootBadge")

	self.taxLabel = Label(side, "", "ixLootBadge", NOTE)
	self.taxLabel:Dock(TOP)

	self.totalLabel = Label(side, "", "ixLootRow", GOOD)
	self.totalLabel:Dock(TOP)
	self.totalLabel:DockMargin(0, Scaled(2), 0, Scaled(8))

	local function Recount()
		local count = math.max(math.floor(tonumber(quantity:GetValue()) or 0), 0)
		local each = math.max(math.floor(tonumber(price:GetValue()) or 0), 0)
		local _, day = days:GetSelected()

		day = tonumber(day) or 1

		local keep = ix.blackmarket.Proceeds(each, day)

		self.taxLabel:SetText(string.format("Market takes %d%%: you keep %s "
			.. "a unit.", ix.blackmarket.Tax(day), Caps(keep)))
		self.totalLabel:SetText(string.format("You get %s if it all sells.",
			Caps(keep * count)))
	end

	quantity.OnChange = Recount
	price.OnChange = Recount
	days.OnSelect = Recount

	Recount()

	local list = Button(side, "LIST IT", function()
		local kind = self.selected

		if (not kind) then
			LocalPlayer():Notify("Pick something from your bag first.")

			return
		end

		local count = math.floor(tonumber(quantity:GetValue()) or 0)
		local each = math.floor(tonumber(price:GetValue()) or 0)
		local _, day = days:GetSelected()

		local ok, why = ix.blackmarket.Validate(ix.item.list[kind.uniqueID],
			count, each, tonumber(day) or 1, notes:GetValue())

		if (not ok) then
			LocalPlayer():Notify(why)

			return
		end

		if (count > kind.count) then
			LocalPlayer():Notify(string.format("You only have %d of those.",
				kind.count))

			return
		end

		ix.blackmarket.SendSell(kind.id, count, each, tonumber(day) or 1,
			anonymous:GetChecked(), notes:GetValue())

		self.selected = nil
	end, 300)

	list:Dock(TOP)
	list:SetTall(Scaled(34))

	--- The bag.
	local bag = content:Add("DScrollPanel")

	bag:Dock(FILL)

	local kinds = Kinds()

	if (#kinds == 0) then
		local empty = Label(bag, "Nothing in your bag can be listed.",
			"ixLootRow", NOTE)

		empty:Dock(TOP)
		empty:DockMargin(Scaled(8), Scaled(8), 0, 0)
	end

	for _, kind in ipairs(kinds) do
		local row = bag:Add("Panel")
		local tint = RarityColor(kind.rarity)

		row:Dock(TOP)
		row:SetTall(Scaled(64))
		row:DockMargin(0, 0, 0, Scaled(4))

		row.Paint = function(_, w, h)
			surface.SetDrawColor(0, 0, 0, self.selected == kind and 170 or 100)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(tint.r, tint.g, tint.b, 255)
			surface.DrawRect(0, 0, Scaled(4), h)
		end

		Icon(row, kind.uniqueID, {skin = kind.skin})

		local select = Button(row, "SELECT", function()
			self.selected = kind
			self.selectedLabel:SetText(string.format("%s  ·  you have %d",
				ix.blackmarket.Name(kind.uniqueID, kind.rarity), kind.count))
			quantity:SetValue(tostring(kind.count))
			Recount()
		end, 100)

		select:Dock(RIGHT)
		select:DockMargin(0, Scaled(16), Scaled(8), Scaled(16))

		local name = Label(row, ix.blackmarket.Name(kind.uniqueID, kind.rarity),
			"ixLootRow", tint)

		name:Dock(TOP)
		name:DockMargin(0, Scaled(10), 0, 0)

		local count = Label(row, string.format("%d in your bag", kind.count),
			"ixLootBadge", NOTE)

		count:Dock(TOP)
	end
end

vgui.Register("ixFOBlackMarket", PANEL, "ixFOFrame")
