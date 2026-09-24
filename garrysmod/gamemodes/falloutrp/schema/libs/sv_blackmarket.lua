--[[
	The black market, server half: the listings, and every change to them.

	A LISTING:

	    {
	        id, item = uniqueID, category, rarity,
	        units = {data, data, ...},   -- what is still for sale, each
	                                     -- unit's own item data
	        total, sold, price, tax, days,
	        expires, created,
	        seller = characterID, sellerName, sellerSteam, anonymous, notes,
	        earned                       -- caps waiting to be claimed
	    }

	`units` holds the actual item data of every unit put up, so what a buyer
	gets is what the seller had - the rarity, the modulators, the durability
	- and not a fresh copy. The items themselves are DELETED from the
	seller's bag when listed and recreated in the buyer's when bought; a
	listing is not an inventory.

	See `sh_blackmarket.lua` for the rules.
]]

if (not SERVER) then return end

util.AddNetworkString("ixMarketOpen")
util.AddNetworkString("ixMarketAsk")
util.AddNetworkString("ixMarketPage")
util.AddNetworkString("ixMarketSell")
util.AddNetworkString("ixMarketBuy")
util.AddNetworkString("ixMarketUnlist")
util.AddNetworkString("ixMarketClaim")
util.AddNetworkString("ixMarketRefresh")

ix.blackmarket.listings = ix.blackmarket.listings or {}
ix.blackmarket.logs = ix.blackmarket.logs or {}

--------------------------------------------------------------------------------
-- Saving
--------------------------------------------------------------------------------

local KEY = "blackmarket"
local LOGS = 500
local loaded = false
local nextID = 1

local function Renumber(set)
	local out = {}

	for key, value in pairs(set or {}) do out[tonumber(key) or key] = value end

	return out
end

function ix.blackmarket.Save()
	if (not loaded) then return end

	ix.data.Set(KEY, {listings = ix.blackmarket.listings,
		logs = ix.blackmarket.logs, next = nextID}, false, true)
end

--- The way every persistent table here loads; `InitPostEntity` never fires.
function ix.blackmarket.Load()
	if (loaded) then return end

	local saved = ix.data.Get(KEY, nil, false, true)

	ix.blackmarket.listings = Renumber(saved and saved.listings)
	ix.blackmarket.logs = saved and saved.logs or {}
	nextID = tonumber(saved and saved.next) or 1

	for id, listing in pairs(ix.blackmarket.listings) do
		listing.id = id
		listing.units = listing.units or {}
		listing.earned = listing.earned or 0
		listing.sold = listing.sold or 0

		if (id >= nextID) then nextID = id + 1 end
	end

	loaded = true
end

hook.Add("LoadData", "ixBlackMarket", ix.blackmarket.Load)
hook.Add("PostLoadData", "ixBlackMarket", ix.blackmarket.Load)
timer.Simple(10, ix.blackmarket.Load)

--------------------------------------------------------------------------------
-- Reading
--------------------------------------------------------------------------------

function ix.blackmarket.Get(id)
	return ix.blackmarket.listings[id]
end

function ix.blackmarket.IsExpired(listing)
	return listing.expires <= os.time()
end

--- Listings with units still up, for one character.
function ix.blackmarket.Active(characterID)
	local count = 0

	for _, listing in pairs(ix.blackmarket.listings) do
		if (listing.seller == characterID and #listing.units > 0) then
			count = count + 1
		end
	end

	return count
end

--- Everybody with the window open, and which terminal they opened it at.
local open = {}

local function Near(client)
	local terminal = open[client]

	if (not IsValid(terminal)) then return false end

	return client:GetPos():DistToSqr(terminal:GetPos()) <= 256 * 256
end

local function Log(entry)
	entry.time = os.time()

	table.insert(ix.blackmarket.logs, 1, entry)

	while (#ix.blackmarket.logs > LOGS) do
		table.remove(ix.blackmarket.logs)
	end
end

local function Refresh(client)
	if (not IsValid(client)) then return end

	net.Start("ixMarketRefresh")
	net.Send(client)
end

--- The seller's character, if they are here.
local function Seller(listing)
	local character = ix.char.loaded[listing.seller]
	local client = character and character:GetPlayer()

	return IsValid(client) and client or nil
end

--------------------------------------------------------------------------------
-- Opening it
--------------------------------------------------------------------------------

function ix.blackmarket.Open(client, terminal)
	if (not IsValid(client) or not client:GetCharacter()) then return end

	open[client] = terminal

	net.Start("ixMarketOpen")
		net.WriteEntity(terminal)
	net.Send(client)
end

hook.Add("PlayerDisconnected", "ixBlackMarket", function(client)
	open[client] = nil
end)

--------------------------------------------------------------------------------
-- Pages
--------------------------------------------------------------------------------

--- What a client is shown of one listing. `units` stays here.
local function Row(listing, viewer)
	local mine = viewer and listing.seller == viewer

	return {
		id = listing.id,
		item = listing.item,
		name = ix.blackmarket.Name(listing.item, listing.rarity),
		category = listing.category,
		rarity = listing.rarity,
		left = #listing.units,
		total = listing.total,
		sold = listing.sold,
		price = listing.price,
		tax = listing.tax,
		days = listing.days,
		expires = listing.expires,
		expired = ix.blackmarket.IsExpired(listing),
		seller = (listing.anonymous and not mine) and "Anonymous"
			or listing.sellerName,
		anonymous = listing.anonymous,
		notes = listing.notes,
		earned = listing.earned,
		mine = mine,
		sample = listing.units[1]
	}
end

local function Matches(listing, filter)
	if (filter.name and filter.name ~= "") then
		local name = string.lower(ix.blackmarket.Name(listing.item,
			listing.rarity))

		if (not string.find(name, string.lower(filter.name), 1, true)) then
			return false
		end
	end

	if (filter.category and filter.category ~= ""
	and listing.category ~= filter.category) then
		return false
	end

	if (isstring(filter.rarity) and filter.rarity ~= ""
	and (listing.rarity or "common") ~= filter.rarity) then
		return false
	end

	if (filter.minPrice and listing.price < filter.minPrice) then return false end
	if (filter.maxPrice and listing.price > filter.maxPrice) then return false end

	return true
end

local ORDER = {
	new = function(a, b) return a.id > b.id end,
	old = function(a, b) return a.id < b.id end,
	cheap = function(a, b)
		if (a.price ~= b.price) then return a.price < b.price end

		return a.id > b.id
	end,
	dear = function(a, b)
		if (a.price ~= b.price) then return a.price > b.price end

		return a.id > b.id
	end
}

--- The rows a tab shows, before paging.
function ix.blackmarket.Rows(client, tab, filter)
	local character = client:GetCharacter()
	local me = character and character:GetID()
	local rows = {}

	filter = istable(filter) and filter or {}

	if (tab == "logs") then
		if (not ix.admin.Can(client, "market.logs")) then return rows end

		for _, entry in ipairs(ix.blackmarket.logs) do
			if (not filter.name or filter.name == ""
			or string.find(string.lower(entry.text or ""),
				string.lower(filter.name), 1, true)) then
				rows[#rows + 1] = entry
			end
		end

		return rows
	end

	--- Your own are on the board with everybody's; the window marks them.
	for _, listing in pairs(ix.blackmarket.listings) do
		if (tab == "mine") then
			if (listing.seller == me) then rows[#rows + 1] = listing end
		elseif (#listing.units > 0 and not ix.blackmarket.IsExpired(listing)
		and Matches(listing, filter)) then
			rows[#rows + 1] = listing
		end
	end

	table.sort(rows, ORDER[filter.orderBy or "new"] or ORDER.new)

	local out = {}

	for _, listing in ipairs(rows) do out[#out + 1] = Row(listing, me) end

	return out
end

--[[
	ITS OWN THROTTLE. A page is asked for right after every action - the
	window reloads on `ixMarketRefresh` - and an ask sharing the actions'
	throttle was dropped every time, which was "the window does not update
	when you unlist".
]]
net.Receive("ixMarketAsk", function(_, client)
	if ((client.ixMarketAskNext or 0) > CurTime()) then return end

	client.ixMarketAskNext = CurTime() + 0.05

	local tab = net.ReadString()
	local page = math.max(net.ReadUInt(16), 1)
	local filter = net.ReadTable()

	if (not Near(client)) then return end

	local rows = ix.blackmarket.Rows(client, tab, filter)
	local per = ix.blackmarket.PAGE
	local pages = math.max(math.ceil(#rows / per), 1)

	page = math.min(page, pages)

	local slice = {}

	for index = (page - 1) * per + 1, math.min(page * per, #rows) do
		slice[#slice + 1] = rows[index]
	end

	net.Start("ixMarketPage")
		net.WriteString(tab)
		net.WriteUInt(page, 16)
		net.WriteUInt(pages, 16)
		net.WriteUInt(#rows, 16)
		net.WriteTable(slice)
	net.Send(client)
end)

--------------------------------------------------------------------------------
-- Selling
--------------------------------------------------------------------------------

--[[
	`quantity` units of the kind of item `itemID` is, out of the seller's
	bag: that item first, then any other of the same kind. Each is deleted
	and its data kept on the listing.
]]
function ix.blackmarket.Sell(client, itemID, quantity, price, days,
	anonymous, notes)
	local character = client:GetCharacter()

	if (not character) then return false, "You are not anybody yet." end

	local first = ix.item.instances[itemID]
	local inventory = character:GetInventory()

	if (not first or not inventory or first.invID ~= inventory:GetID()) then
		return false, "That is not in your bag."
	end

	local itemTable = ix.item.list[first.uniqueID]
	local ok, why = ix.blackmarket.Validate(itemTable, quantity, price, days,
		notes)

	if (not ok) then return false, why end

	quantity = math.floor(quantity)
	price = math.floor(price)
	days = math.floor(days)

	if (ix.blackmarket.Active(character:GetID())
	>= ix.config.Get("marketSlots", 10)) then
		return false, "You have as many listings up as you may: "
			.. ix.config.Get("marketSlots", 10) .. "."
	end

	--- That one, then the rest of its kind.
	local taking = {first}

	for _, item in pairs(inventory:GetItems()) do
		if (#taking >= quantity) then break end

		if (item ~= first and item.uniqueID == first.uniqueID
		and not item:GetData("equip")) then
			taking[#taking + 1] = item
		end
	end

	if (first:GetData("equip")) then
		return false, "Take it off first."
	end

	if (#taking < quantity) then
		return false, string.format("You only have %d of those.", #taking)
	end

	local units = {}

	for _, item in ipairs(taking) do
		units[#units + 1] = table.Copy(item.data or {})
	end

	local id = nextID

	nextID = nextID + 1

	local listing = {
		id = id,
		item = first.uniqueID,
		category = itemTable.category or "Misc",
		rarity = units[1].rarity,
		units = units,
		total = quantity,
		sold = 0,
		price = price,
		tax = ix.blackmarket.Tax(days),
		days = days,
		expires = os.time() + days * 86400,
		created = os.time(),
		seller = character:GetID(),
		sellerName = character:GetName(),
		sellerSteam = client:SteamID64(),
		anonymous = anonymous == true,
		notes = string.sub(tostring(notes or ""), 1, ix.blackmarket.NOTE),
		earned = 0
	}

	--- The bag first, so a failure to delete leaves nothing half done.
	for _, item in ipairs(taking) do item:Remove() end

	ix.blackmarket.listings[id] = listing
	ix.blackmarket.Save()

	local name = ix.blackmarket.Name(listing.item, listing.rarity)

	Log({text = string.format("%s listed %dx %s at %d caps each for %d day(s)",
		character:GetName(), quantity, name, price, days)})
	ix.log.Add(client, "marketList", name, quantity, price, days)

	return true, string.format("Listed %dx %s. You keep %d caps a unit after "
		.. "the market's %d%%.", quantity, name,
		ix.blackmarket.Proceeds(price, days), listing.tax)
end

net.Receive("ixMarketSell", function(_, client)
	if ((client.ixMarketNext or 0) > CurTime()) then return end

	client.ixMarketNext = CurTime() + 0.2

	local itemID = net.ReadUInt(32)
	local quantity = net.ReadUInt(16)
	local price = net.ReadUInt(32)
	local days = net.ReadUInt(8)
	local anonymous = net.ReadBool()
	local notes = net.ReadString()

	if (not Near(client)) then
		client:Notify("You are not at a black market terminal.")

		return
	end

	local ok, said = ix.blackmarket.Sell(client, itemID, quantity, price, days,
		anonymous, notes)

	if (said) then client:Notify(said) end
	if (ok) then Refresh(client) end
end)

--------------------------------------------------------------------------------
-- Buying
--------------------------------------------------------------------------------

function ix.blackmarket.Buy(client, id, quantity)
	local character = client:GetCharacter()
	local listing = ix.blackmarket.Get(id)

	if (not character) then return false, "You are not anybody yet." end
	if (not listing or #listing.units == 0) then
		return false, "That is no longer for sale."
	end

	if (ix.blackmarket.IsExpired(listing)) then
		return false, "That listing has expired."
	end

	if (listing.seller == character:GetID()) then
		return false, "That is yours. Unlist it instead."
	end

	quantity = math.floor(tonumber(quantity) or 0)

	if (quantity < 1) then return false, "How many?" end

	quantity = math.min(quantity, #listing.units)

	local total = listing.price * quantity

	if (not character:HasMoney(total)) then
		return false, string.format("That is %d caps; you have %d.", total,
			character:GetMoney())
	end

	local inventory = character:GetInventory()

	if (not inventory) then return false, "You have no bag." end

	character:TakeMoney(total)

	local bought = 0

	for _ = 1, quantity do
		local data = listing.units[1]
		local ok = inventory:Add(listing.item, 1, data)

		if (not ok) then break end

		table.remove(listing.units, 1)

		bought = bought + 1
	end

	--- What did not fit is refunded; the units stay up.
	if (bought < quantity) then
		character:GiveMoney(listing.price * (quantity - bought))
	end

	if (bought == 0) then
		return false, "There is no room in your bag for that."
	end

	local proceeds = ix.blackmarket.Proceeds(listing.price, listing.days)
		* bought

	listing.sold = listing.sold + bought
	listing.earned = listing.earned + proceeds

	ix.blackmarket.Save()

	local name = ix.blackmarket.Name(listing.item, listing.rarity)
	local paid = listing.price * bought

	Log({text = string.format("%s bought %dx %s from %s for %d caps",
		character:GetName(), bought, name, listing.sellerName, paid)})
	ix.log.Add(client, "marketBuy", name, bought, paid, listing.sellerName)

	local seller = Seller(listing)

	if (IsValid(seller)) then
		seller:Notify(string.format("%dx %s sold on the black market. %d "
			.. "caps are waiting for you at a terminal.", bought, name,
			listing.earned))
		Refresh(seller)
	end

	return true, string.format("Bought %dx %s for %d caps.%s", bought, name,
		paid, bought < quantity and " The rest would not fit." or "")
end

net.Receive("ixMarketBuy", function(_, client)
	if ((client.ixMarketNext or 0) > CurTime()) then return end

	client.ixMarketNext = CurTime() + 0.2

	local id = net.ReadUInt(32)
	local quantity = net.ReadUInt(16)

	if (not Near(client)) then
		client:Notify("You are not at a black market terminal.")

		return
	end

	local ok, said = ix.blackmarket.Buy(client, id, quantity)

	if (said) then client:Notify(said) end
	if (ok) then Refresh(client) end
end)

--------------------------------------------------------------------------------
-- Taking it back, and taking the money
--------------------------------------------------------------------------------

function ix.blackmarket.Unlist(client, id, quantity)
	local character = client:GetCharacter()
	local listing = ix.blackmarket.Get(id)

	if (not character or not listing or listing.seller ~= character:GetID()) then
		return false, "That is not your listing."
	end

	if (#listing.units == 0) then return false, "Nothing is left to take back." end

	quantity = math.floor(tonumber(quantity) or 0)

	if (quantity < 1) then quantity = #listing.units end

	quantity = math.min(quantity, #listing.units)

	local inventory = character:GetInventory()

	if (not inventory) then return false, "You have no bag." end

	local returned = 0

	for _ = 1, quantity do
		local ok = inventory:Add(listing.item, 1, listing.units[1])

		if (not ok) then break end

		table.remove(listing.units, 1)

		returned = returned + 1
	end

	if (returned == 0) then
		return false, "There is no room in your bag for that."
	end

	listing.total = listing.total - returned

	if (#listing.units == 0 and listing.earned <= 0) then
		ix.blackmarket.listings[id] = nil
	end

	ix.blackmarket.Save()

	local name = ix.blackmarket.Name(listing.item, listing.rarity)

	ix.log.Add(client, "marketUnlist", name, returned)

	return true, string.format("Took %dx %s back.%s", returned, name,
		returned < quantity and " The rest would not fit." or "")
end

function ix.blackmarket.Claim(client, id)
	local character = client:GetCharacter()
	local listing = ix.blackmarket.Get(id)

	if (not character or not listing or listing.seller ~= character:GetID()) then
		return false, "That is not your listing."
	end

	if (listing.earned <= 0) then return false, "Nothing has sold yet." end

	local amount = listing.earned

	listing.earned = 0
	character:GiveMoney(amount)

	if (#listing.units == 0) then ix.blackmarket.listings[id] = nil end

	ix.blackmarket.Save()

	local name = ix.blackmarket.Name(listing.item, listing.rarity)

	ix.log.Add(client, "marketClaim", amount, name)

	return true, string.format("Claimed %d caps from the sale of %s.", amount,
		name)
end

net.Receive("ixMarketUnlist", function(_, client)
	if ((client.ixMarketNext or 0) > CurTime()) then return end

	client.ixMarketNext = CurTime() + 0.2

	local id = net.ReadUInt(32)
	local quantity = net.ReadUInt(16)

	if (not Near(client)) then return end

	local ok, said = ix.blackmarket.Unlist(client, id, quantity)

	if (said) then client:Notify(said) end
	if (ok) then Refresh(client) end
end)

net.Receive("ixMarketClaim", function(_, client)
	if ((client.ixMarketNext or 0) > CurTime()) then return end

	client.ixMarketNext = CurTime() + 0.2

	local id = net.ReadUInt(32)

	if (not Near(client)) then return end

	local ok, said = ix.blackmarket.Claim(client, id)

	if (said) then client:Notify(said) end
	if (ok) then Refresh(client) end
end)
