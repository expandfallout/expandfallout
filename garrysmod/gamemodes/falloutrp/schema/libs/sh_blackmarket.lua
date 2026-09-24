--[[
	The black market.

	Phoenix's `plugins/blackmarket`: a terminal you press E on, four tabs -
	BUY, SELL, MY LISTINGS and, for staff, LOGS - and listings that live
	somewhere else: theirs were kept on a WEB SERVICE
	(`falloutphoenix.com/marketplace`), fetched over HTTP a page at a time,
	which is why only the window and the validation are in the scrape. This
	keeps the window, the rules and the numbers, and keeps the listings on the
	server (`ix.data`, key `blackmarket`) where nothing outside it can lose
	them.

	THE RULES, WHICH ARE THEIRS:

	    a listing      one kind of item, N units of it, at a price per unit,
	                   for 1 to `marketMaxDays` days, optionally anonymous,
	                   with a note of up to a hundred characters
	    the fee        `marketTax` per cent of every sale, plus `marketDayTax`
	                   per cent for every day past the first - the longer it
	                   is up, the more the market takes. Charged when a unit
	                   SELLS, out of the seller's proceeds; the buyer pays the
	                   list price. What the seller gets is shown before they
	                   list
	    the limits     `marketMinPrice`, `marketMaxPrice`, `marketSlots`
	                   listings with units left per character; no negatives,
	                   no zero quantities, no bags
	    buying         any number of units at once, paid up front, delivered
	                   into the bag; what does not fit is refunded
	    the money      sales accrue on the listing and the seller CLAIMS them
	                   from the terminal, which is how Phoenix did it and why
	                   somebody offline still gets paid
	    expiry         an expired listing sells nothing, and waits for its
	                   owner to unlist it and take the units back

	This file is the shared half - settings, the fee, what may be listed.
	`sv_blackmarket.lua` owns the listings; `cl_blackmarket.lua` and
	`derma/cl_blackmarket.lua` are the window; `entities/ix_blackmarket` is
	the terminal.
]]

ix.blackmarket = ix.blackmarket or {}

ix.config.Add("marketTax", 10,
	"Per cent of every black market sale the market keeps.", nil,
	{data = {min = 0, max = 90}, category = "Black market"})

ix.config.Add("marketDayTax", 2,
	"Extra per cent of tax for every day a listing runs past the first.", nil,
	{data = {min = 0, max = 20}, category = "Black market"})

ix.config.Add("marketSlots", 10,
	"How many listings with units left one character may have up at once.",
	nil, {data = {min = 1, max = 100}, category = "Black market"})

ix.config.Add("marketMinPrice", 2,
	"The least a unit may be listed for.", nil,
	{data = {min = 1, max = 100000}, category = "Black market"})

ix.config.Add("marketMaxPrice", 1000000,
	"The most a unit may be listed for.", nil,
	{data = {min = 1, max = 100000000}, category = "Black market"})

ix.config.Add("marketMaxDays", 7,
	"The longest a listing may run, in days.", nil,
	{data = {min = 1, max = 30}, category = "Black market"})

if (ix.admin and ix.admin.RegisterPermission) then
	ix.admin.RegisterPermission("market.logs",
		"Read the black market's sale logs", "Staff")
end

--- Rows a page holds, in every tab.
ix.blackmarket.PAGE = 10

--- The longest a note may be.
ix.blackmarket.NOTE = 100

--- The whole fee for a listing that runs `days`, in per cent.
function ix.blackmarket.Tax(days)
	days = math.max(math.floor(tonumber(days) or 1), 1)

	return math.min(ix.config.Get("marketTax", 10)
		+ ix.config.Get("marketDayTax", 2) * (days - 1), 95)
end

--- What a seller keeps of one unit at `price` on a listing of `days`.
function ix.blackmarket.Proceeds(price, days)
	price = math.max(math.floor(tonumber(price) or 0), 0)

	return price - math.floor(price * ix.blackmarket.Tax(days) / 100)
end

--[[
	Whether an item may be put up at all. Phoenix blacklisted their three
	bags by name; here anything that IS a bag is refused, because a bag is an
	inventory and an inventory in a listing is a listing that owns other
	people's things.
]]
function ix.blackmarket.CanList(itemTable)
	if (not itemTable) then return false, "That is not an item." end

	if (itemTable.isBag or itemTable.noMarket) then
		return false, "That cannot be sold on the black market."
	end

	return true
end

--- The checks a listing has to pass, shared so the window can say no early.
function ix.blackmarket.Validate(itemTable, quantity, price, days, notes)
	local ok, why = ix.blackmarket.CanList(itemTable)

	if (not ok) then return false, why end

	quantity = tonumber(quantity)
	price = tonumber(price)
	days = tonumber(days)

	if (not quantity or quantity < 1 or quantity ~= math.floor(quantity)) then
		return false, "Quantity has to be a whole number of at least one."
	end

	if (not price or price ~= math.floor(price)) then
		return false, "Price has to be a whole number of caps."
	end

	if (price < ix.config.Get("marketMinPrice", 2)) then
		return false, "The price per unit is below the minimum: "
			.. ix.config.Get("marketMinPrice", 2) .. " caps."
	end

	if (price > ix.config.Get("marketMaxPrice", 1000000)) then
		return false, "The price per unit is above the maximum: "
			.. ix.config.Get("marketMaxPrice", 1000000) .. " caps."
	end

	if (not days or days < 1 or days > ix.config.Get("marketMaxDays", 7)
	or days ~= math.floor(days)) then
		return false, "A listing runs for 1 to "
			.. ix.config.Get("marketMaxDays", 7) .. " days."
	end

	if (notes and #notes > ix.blackmarket.NOTE) then
		return false, "Notes can be " .. ix.blackmarket.NOTE
			.. " characters at most."
	end

	return true
end

--- The item's name with its rarity tier in front, the way the bag shows it.
function ix.blackmarket.Name(uniqueID, rarity)
	local itemTable = ix.item.list[uniqueID]
	local name = itemTable and (istable(itemTable.name) and itemTable.name[1]
		or itemTable.name) or uniqueID

	--- Tier ids are strings; the first tier is the plain one and adds nothing.
	if (rarity and ix.rarity and ix.rarity.Tier) then
		local tier = ix.rarity.Tier(rarity)

		if (tier and (tier.index or 1) > 1 and tier.name and tier.name ~= "") then
			name = tier.name .. " " .. name
		end
	end

	return name
end

--- Seconds as "3d 4h" / "2h 10m" / "5m".
function ix.blackmarket.Left(seconds)
	seconds = math.floor(math.max(seconds or 0, 0))

	if (seconds >= 86400) then
		return string.format("%dd %dh", math.floor(seconds / 86400),
			math.floor(seconds % 86400 / 3600))
	end

	if (seconds >= 3600) then
		return string.format("%dh %dm", math.floor(seconds / 3600),
			math.floor(seconds % 3600 / 60))
	end

	return string.format("%dm", math.max(math.floor(seconds / 60), 1))
end

--- `ix.log.AddType` exists on the server alone (Helix's `sh_log.lua`).
if (SERVER) then
	ix.log.AddType("marketList", function(client, name, quantity, price, days)
		return string.format("%s listed %dx %s at %d caps each for %d day(s).",
			client:Name(), quantity, name, price, days)
	end, FLAG_NORMAL)

	ix.log.AddType("marketBuy", function(client, name, quantity, total, seller)
		return string.format("%s bought %dx %s for %d caps from %s.",
			client:Name(), quantity, name, total, seller)
	end, FLAG_NORMAL)

	ix.log.AddType("marketUnlist", function(client, name, quantity)
		return string.format("%s took %dx %s back off the black market.",
			client:Name(), quantity, name)
	end, FLAG_NORMAL)

	ix.log.AddType("marketClaim", function(client, amount, name)
		return string.format("%s claimed %d caps from the sale of %s.",
			client:Name(), amount, name)
	end, FLAG_NORMAL)
end
