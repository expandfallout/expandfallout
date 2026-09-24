--[[
	The Shop tab.

	Your own faction's stock, in categories, with what you may buy and what you
	may not and why. Replaces Helix's Business tab, which sells to anybody with
	the caps and has no idea what a faction is.

	CATEGORIES ARE DERIVED, NOT CONFIGURED, which is what makes "a tab does not
	exist if there is nothing in it" true by construction rather than by a
	sweep - see `ix.shop.GetCategories`. It filters by rank too: a category
	holding nothing you may buy is a tab that opens on an empty list, which
	reads as a broken shop rather than a locked one.

	Rows you cannot buy are still SHOWN, greyed, with the reason on them.
	Hiding them would answer "what is there to work towards" with nothing at
	all, and the rank requirement is the most interesting thing about a faction
	shop.
]]

if (not CLIENT) then return end

ix.shop = ix.shop or {}

--- What the server last sent us, as `[uniqueID] = entry`.
ix.shop.mine = ix.shop.mine or {}

net.Receive("ixShopSync", function()
	local count = net.ReadUInt(16)
	local list = {}

	for _ = 1, count do
		local uniqueID = net.ReadString()

		list[uniqueID] = {
			item = uniqueID,
			category = net.ReadString(),
			price = net.ReadUInt(32),
			rank = net.ReadUInt(3),
			infinite = net.ReadBool(),
			stock = net.ReadUInt(16),
			maxStock = net.ReadUInt(16),
			restockTime = net.ReadUInt(32),
			restockAmount = net.ReadUInt(16)
		}

		--- Everything else this purchase would also take a unit off.
		local linkCount = net.ReadUInt(8)

		list[uniqueID].links = {}

		for _ = 1, linkCount do
			table.insert(list[uniqueID].links, net.ReadString())
		end

		list[uniqueID].restockIn = net.ReadUInt(32)
	end

	ix.shop.mine = list

	--[[
		WHEN THIS ARRIVED, in the client's own clock.

		`restockIn` is a number of seconds measured at the moment the server
		sent it - see the note in `ix.shop.Sync` - so the countdown on screen is
		that number minus however long the message has been sitting here. Kept
		once for the whole list rather than per entry: they all came in the same
		message.
	]]
	ix.shop.syncedAt = CurTime()

	if (IsValid(ix.gui.shop)) then
		ix.gui.shop:Rebuild()
	end
end)

--- The rank of the local player's class, or 0.
local function MyRank()
	local character = LocalPlayer():GetCharacter()

	if (not character) then return 0 end

	local info = ix.class.list[character:GetClass()]

	return info and (info.rank or 1) or 0
end

--[[
	What MY faction calls a rank, for the "requires X or above" line.

	`ix.class.GetRankName` reads it off the faction's own classes, so a Kings
	member is told they need to be a Lieutenant rather than an "Officer" - a
	rung their faction does not have and nobody could look up.
]]
local function MyRankName(rank)
	local character = LocalPlayer():GetCharacter()

	return ix.class.GetRankName(character and character:GetFaction(), rank)
end

local PANEL = {}

local function Scaled(value)
	return math.Round(value * ix.fallout.GetFontScale())
end

--[[
	"+5 in 12m 30s", or nil when there is nothing to wait for.

	`ix.bench.FormatTime` rather than a second formatter: seconds into
	something readable is the same problem the benches solved, and Helix's own
	`ix.util.GetStringTime` is a PARSER going the other way - handed 240 it
	answers 14400, because it reads the number as minutes. See gotcha in
	`sh_bench.lua`.
]]
local function RestockLine(entry)
	if (not entry or entry.infinite) then return nil end
	if ((entry.restockAmount or 0) <= 0) then return nil end

	local sent = entry.restockIn or 0
	local period = entry.restockTime or 0

	if (sent <= 0 or period <= 0) then return nil end

	local since = CurTime() - (ix.shop.syncedAt or CurTime())
	local left = sent - since

	--[[
		IT ROLLS OVER RATHER THAN STOPPING AT ZERO.

		The restock tick only syncs when the stock actually CHANGED, so a shelf
		that is already full restocks on time, quietly, and sends nothing - and
		a countdown sitting on "0s" until somebody bought something would look
		like the shop had stalled. The period is known here, so the next one is
		arithmetic rather than a message.
	]]
	if (left < 1) then
		left = period - ((-left) % period)
	end

	--[[
		A FULL SHELF STILL SHOWS ITS CLOCK, and says why the delivery will not
		change anything. It is the stock that is capped, not the schedule.
	]]
	if ((entry.stock or 0) >= (entry.maxStock or 0)) then
		return string.format("full - +%d in %s", entry.restockAmount,
			ix.bench.FormatTime(left))
	end

	return string.format("+%d in %s", entry.restockAmount,
		ix.bench.FormatTime(left))
end

function PANEL:Init()
	ix.gui.shop = self

	ix.fallout.LoadMenuFonts()

	self.category = nil

	self.tabs = self:Add("Panel")
	self.tabs:Dock(TOP)
	self.tabs:SetTall(Scaled(30))
	self.tabs:DockMargin(0, 0, 0, Scaled(6))

	self.canvas = self:Add("ixFOScrollPanel")
	self.canvas:Dock(FILL)

	self:Rebuild()

	--[[
		Asked for on open rather than waited for. The server syncs on character
		load and after every change, but a tab opened before that first sync
		landed would sit empty with no way to make it try again.
	]]
	net.Start("ixShopOpen")
	net.SendToServer()
end

function PANEL:Rebuild()
	local rank = MyRank()
	local categories = ix.shop.GetCategories(nil, rank)

	--[[
		`GetCategories` takes a faction id and this passes nil, because the
		client only ever holds its own faction's list - `ix.shop.mine` IS the
		answer, so the shared function reads it through `ix.shop.Get`, which is
		overridden below for exactly this.
	]]
	self.tabs:Clear()

	--- The faction's own shop log, behind a magnifier at the end of the tabs.
	local logs = self.tabs:Add("DImageButton")

	logs:Dock(RIGHT)
	logs:SetWide(Scaled(28))
	logs:SetImage("icon16/magnifier.png")
	logs:SetStretchToFit(false)
	logs:SetTooltip("Your faction's shop log")
	logs.DoClick = function() ix.factionlog.Open("shop") end

	if (#categories == 0) then
		self.canvas:Clear()

		local empty = self.canvas:Add("ixFOLabel")

		empty:Dock(TOP)
		empty:SetTall(Scaled(60))
		empty:SetContentAlignment(5)
		empty:SetText("There is nothing for sale to you.")

		return
	end

	if (not self.category or not table.HasValue(categories, self.category)) then
		self.category = categories[1]
	end

	for _, name in ipairs(categories) do
		local tab = self.tabs:Add("ixFOButton")

		tab:Dock(LEFT)
		tab:SetText(string.upper(name))
		tab:SizeToContentsX(Scaled(20))
		tab:DockMargin(0, 0, Scaled(4), 0)
		tab:SetContentAlignment(5)
		tab.bActive = self.category == name

		tab.DoClick = function()
			self.category = name
			self:Rebuild()
		end
	end

	self:BuildRows(rank)
end

function PANEL:BuildRows(rank)
	self.canvas:Clear()

	local rows = {}

	for uniqueID, entry in pairs(ix.shop.mine) do
		if ((entry.category or "Misc") ~= self.category) then continue end

		local itemTable = ix.item.list[uniqueID]

		if (not itemTable) then continue end

		rows[#rows + 1] = {entry = entry, item = itemTable}
	end

	table.sort(rows, function(a, b)
		--[[
			Cheapest first within a category, then by name. Price is the thing
			somebody scanning a shop is actually comparing, and it keeps the
			rank-locked expensive things at the bottom where they read as
			aspirational rather than as a wall.
		]]
		if (a.entry.price ~= b.entry.price) then
			return a.entry.price < b.entry.price
		end

		return a.item.name < b.item.name
	end)

	for _, row in ipairs(rows) do
		self:AddRow(row.entry, row.item, rank)
	end
end

function PANEL:AddRow(entry, itemTable, rank)
	local locked = rank < (entry.rank or 1)
	local out = not entry.infinite and (entry.stock or 0) < 1

	local row = self.canvas:Add("Panel")

	row:Dock(TOP)
	row:SetTall(Scaled(52))
	row:DockMargin(0, 0, 0, Scaled(4))

	row.Paint = function(_, width, height)
		local palette = ix.fallout.GetPalette()

		surface.SetDrawColor(30, 30, 36, 200)
		surface.DrawRect(0, 0, width, height)

		surface.SetDrawColor(locked and Color(120, 60, 60)
			or out and Color(110, 100, 60) or palette.color_primary)
		surface.DrawRect(0, 0, Scaled(3), height)

		local text = locked and ColorAlpha(palette.text_primary, 120)
			or palette.text_primary

		draw.SimpleText(itemTable.name, "ixLootRow", Scaled(58), Scaled(9),
			text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		--[[
			The reason, on the row, in the place the description would be.

			A greyed row with no explanation is the thing people ask about, and
			"you have to be an Officer" is the whole point of the shop - so it
			replaces the flavour text rather than sitting next to it.
		]]
		local note

		if (locked) then
			note = "Requires " .. MyRankName(entry.rank) .. " or above"
		elseif (entry.infinite) then
			note = "Always in stock"
		else
			note = string.format("%d of %d in stock", entry.stock or 0,
				entry.maxStock or 0)
		end

		draw.SimpleText(note, "ixLootSmall", Scaled(58), Scaled(30),
			locked and Color(200, 120, 120)
			or out and Color(200, 180, 120)
			or ColorAlpha(palette.color_primary, 200),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		--[[
			THE RESTOCK, ON THE SAME LINE AND ON THE RIGHT OF IT.

			"Out of stock" on its own answers half the question somebody
			standing at an empty shelf is asking; the other half is when it
			will not be empty, and that number exists on the server and was
			simply never sent. Now it is - see `ix.shop.RestockIn`.

			It counts down live rather than only on a sync: the shop syncs when
			something changes, and a stall that says "in 12m" for twelve
			minutes reads as a broken clock.
		]]
		local restock = RestockLine(entry)

		draw.SimpleText(restock or "", "ixLootSmall", width - Scaled(96),
			height * 0.72, ColorAlpha(palette.text_primary, 150),
			TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		--[[
			The price sits ABOVE the middle rather than on it, because the
			restock line goes underneath it - a countdown drawn through the
			price is how the first version of this looked.
		]]
		draw.SimpleText(ix.currency.Get(entry.price or 0), "ixLootHeader",
			width - Scaled(96), height * (restock and 0.34 or 0.5), text,
			TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end

	local icon = row:Add("SpawnIcon")

	icon:SetPos(Scaled(8), Scaled(6))
	icon:SetSize(Scaled(40), Scaled(40))
	icon:SetModel(itemTable.model or "models/error.mdl",
		itemTable.skin or 0)
	icon:SetTooltip(itemTable.GetDescription
		and itemTable:GetDescription() or itemTable.description)

	local buy = row:Add("ixFOButton")

	buy:Dock(RIGHT)
	buy:DockMargin(0, Scaled(10), Scaled(8), Scaled(10))
	buy:SetWide(Scaled(80))
	buy:SetText("BUY")
	buy:SetContentAlignment(5)
	buy:SetEnabled(not locked and not out)

	buy.DoClick = function()
		net.Start("ixShopBuy")
			net.WriteString(entry.item)
		net.SendToServer()

		--[[
			Not decremented locally. The server answers with a fresh sync a
			frame later, and guessing here would show a stock count that is
			wrong for anybody who lost the race for the last one.
		]]
		surface.PlaySound("buttons/button14.wav")
	end
end

vgui.Register("ixFOShop", PANEL, "Panel")

--[[
	`ix.shop.Get` on the client answers with the one list we hold.

	The shared functions in `sh_shop.lua` are written against
	`ix.shop.stock[faction]`, which the client never receives - it is sent only
	its own faction's entries, unkeyed. Overriding the accessor rather than
	forking the functions means `GetCategories` and `CanBuy` are the same code
	on both realms, which is the point of them being shared.
]]
function ix.shop.Get()
	return ix.shop.mine
end

--[[
	And so does `GetFor`. The server has already merged the global shop into
	what it sent, so merging again here would be merging a list with itself.
]]
function ix.shop.GetFor()
	return ix.shop.mine
end

--[[
	The tab, replacing Helix's Business.

	`hook.Remove` rather than nilling `tabs["business"]` from a later listener:
	string-identified hooks run in `pairs` order, which is not registration
	order, so a removal that depends on running second is a coin flip. That was
	the Classes tab bug - see `cl_special.lua`.
]]
hook.Remove("CreateMenuButtons", "ixBusiness")

hook.Add("CreateMenuButtons", "ixFOShop", function(tabs)
	tabs["business"] = nil

	--[[
		No tab at all when there is nothing in it, at any rank. A shop tab that
		opens on "your faction has nothing for sale" is a worse answer than not
		offering the tab, and most factions will have an empty shop until
		somebody configures one.
	]]
	if (table.IsEmpty(ix.shop.mine)) then return end

	tabs["shop"] = function(container)
		container:Add("ixFOShop"):Dock(FILL)
	end
end)
