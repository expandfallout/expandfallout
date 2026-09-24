--[[
	The faction shop, server side: storage, restocking, buying, configuring.

	See `sh_shop.lua` for what an entry is and why it is shaped that way.
]]

if (not SERVER) then return end

util.AddNetworkString("ixShopSync")
util.AddNetworkString("ixShopBuy")
util.AddNetworkString("ixShopOpen")
util.AddNetworkString("ixShopConfigOpen")
util.AddNetworkString("ixShopConfigSet")
util.AddNetworkString("ixShopConfigAll")
util.AddNetworkString("ixShopConfigCopy")

--[[
	Stored in `ix.data` per schema, NOT per map.

	A faction's supply line does not change because the map did, and the shop
	is configured by hand - losing it on a map change would be losing work
	somebody did rather than state the map owns.
]]
local SAVE_KEY = "factionshop"

--- Guards the save the way the loot library does; see `sv_loot.lua`.
local loaded = false

function ix.shop.Save()
	if (not loaded) then
		--[[
			REFUSING TO SAVE IS THE POINT. If loading failed, `ix.shop.stock`
			is empty and writing it would turn a transient failure into a
			permanent one - every shop on the server erased because one read
			went wrong. `sv_loot.lua` learned this the hard way.
		]]
		ErrorNoHalt("[falloutrp] refusing to save faction shops before they "
			.. "have been loaded\n")

		return
	end

	ix.data.Set(SAVE_KEY, ix.shop.stock, false, true)
end

function ix.shop.Load()
	if (loaded) then return end

	ix.shop.stock = ix.data.Get(SAVE_KEY, {}, false, true) or {}
	loaded = true

	--[[
		Entries naming an item or a faction that no longer exists are dropped
		on load rather than kept. Both happen - an item is renamed, a faction
		is cut - and an entry pointing at nothing is a row in the shop that
		cannot be bought and cannot be explained.
	]]
	local factions, entries, dropped = 0, 0, 0

	for faction, list in pairs(ix.shop.stock) do
		--[[
			The global shop is not a faction and must survive this sweep. Every
			other key has to name one, or it is a shop nobody can ever reach.
		]]
		if (faction ~= ix.shop.GLOBAL and not ix.faction.teams[faction]) then
			ix.shop.stock[faction] = nil
			dropped = dropped + table.Count(list)

			continue
		end

		for uniqueID, entry in pairs(list) do
			if (not ix.item.list[uniqueID]) then
				list[uniqueID] = nil
				dropped = dropped + 1
			else
				--[[
					The item's own uniqueID wins over whatever the entry
					recorded. They are the same thing and the table key is the
					one lookups use, so a mismatch is a row that can be listed
					and not bought.
				]]
				entry.item = uniqueID
				entries = entries + 1
			end
		end

		factions = factions + 1
	end

	MsgC(Color(255, 200, 100), string.format(
		"[falloutrp] loaded %d shop entr%s across %d faction(s)%s\n",
		entries, entries == 1 and "y" or "ies", factions,
		dropped > 0 and string.format(", dropped %d naming something that no "
			.. "longer exists", dropped) or ""))

	ix.shop.Restock()
end

--[[
	The three triggers everything that loads data in this schema uses.

	`InitPostEntity` does not reach this schema - see `24-devtools.md` - so the
	plain timer is the one that cannot fail, and the others are there to make
	it fast when they do fire.
]]
hook.Add("LoadData", "ixShop", ix.shop.Load)
hook.Add("PostLoadData", "ixShop", ix.shop.Load)
timer.Simple(10, ix.shop.Load)

--------------------------------------------------------------------------------
-- Restocking
--------------------------------------------------------------------------------

--[[
	Catches every entry up to now.

	Driven by `os.time()` and whole elapsed periods rather than by a timer that
	adds one lot per tick, so a shop restocks correctly across a restart: come
	back after a day and a daily shop owes exactly one restock, not none
	(a `CurTime` timer would have been reset) and not a day's worth of ticks.
]]
function ix.shop.Restock()
	if (not loaded) then return end

	local now = os.time()
	local changed = false

	for _, list in pairs(ix.shop.stock) do
		for _, entry in pairs(list) do
			local due, periods = ix.shop.GetRestockDue(entry, now)

			if (periods and periods > 0) then
				--[[
					`lastRestock` moves whether or not anything was added. A
					full shop that skipped a restock has still had that restock
					- leaving the clock behind would make it restock the
					instant somebody bought something, which is not a restock
					interval at all.
				]]
				entry.lastRestock = (entry.lastRestock or now)
					+ periods * entry.restockTime

				if (due > 0) then
					entry.stock = math.min((entry.stock or 0) + due,
						entry.maxStock or 0)
					changed = true
				end
			end
		end
	end

	if (changed) then
		ix.shop.Save()
		ix.shop.SyncAll()
	end
end

--[[
	Once a minute. The interval is not the restock time - entries each have
	their own, and this only asks whether any of them are due, which is a walk
	over a few dozen tables.
]]
timer.Create("ixShopRestock", 60, 0, ix.shop.Restock)

--------------------------------------------------------------------------------
-- Networking
--------------------------------------------------------------------------------

--[[
	A player is sent their OWN faction's shop and nothing else.

	Not secrecy for its own sake: what the NCR charges for a rifle is the NCR's
	business, and sending all 45 shops to every client to display one of them
	is work nobody needs.

	Admins configuring the thing get everything, through `ixShopConfigAll`.
]]
function ix.shop.Sync(client)
	if (not IsValid(client)) then return end

	local character = client:GetCharacter()

	if (not character) then return end

	--[[
		The global shop is included for everybody, including a character whose
		faction has no shop of its own.
	]]
	local faction = ix.faction.indices[character:GetFaction()]
	local list = ix.shop.GetFor(faction and faction.uniqueID)

	local now = os.time()

	net.Start("ixShopSync")
		net.WriteUInt(table.Count(list), 16)

		for uniqueID, entry in pairs(list) do
			net.WriteString(uniqueID)
			net.WriteString(entry.category or "Misc")
			net.WriteUInt(math.max(entry.price or 0, 0), 32)
			net.WriteUInt(math.Clamp(entry.rank or 1, 1, 4), 3)
			net.WriteBool(entry.infinite == true)
			net.WriteUInt(math.max(entry.stock or 0, 0), 16)
			net.WriteUInt(math.max(entry.maxStock or 0, 0), 16)
			net.WriteUInt(math.max(entry.restockTime or 0, 0), 32)
			net.WriteUInt(math.max(entry.restockAmount or 0, 0), 16)

			--[[
				The links, so the shop tab can say what a purchase will draw
				from. A player looking at three rifles that share one stock of
				thirty should be able to see that before they buy the third
				one and wonder where the other two went.
			]]
			net.WriteUInt(math.min(#(entry.links or {}), 32), 8)

			for index = 1, math.min(#(entry.links or {}), 32) do
				net.WriteString(entry.links[index])
			end

			--[[
				SECONDS LEFT, not the timestamp it is counted from.

				`lastRestock` is `os.time()`, and sending it would make the
				countdown depend on the CLIENT's clock agreeing with the
				server's - which it does not have to, and a machine an hour out
				would show an hour of nonsense. A remaining count is measured
				against the moment the message arrives, and the client counts
				down from there with `CurTime`.
			]]
			net.WriteUInt(ix.shop.RestockIn(entry, now), 32)
		end
	net.Send(client)
end

--- Everyone. Called after a restock or a configuration change.
function ix.shop.SyncAll()
	for _, client in player.Iterator() do
		ix.shop.Sync(client)
	end
end

hook.Add("PlayerLoadedCharacter", "ixShop", function(client)
	timer.Simple(1, function()
		if (IsValid(client)) then
			ix.shop.Sync(client)
		end
	end)
end)

--- A faction change is a different shop.
hook.Add("CharacterVarChanged", "ixShop", function(character, key)
	if (key ~= "faction") then return end

	local client = character:GetPlayer()

	if (IsValid(client)) then
		timer.Simple(0, function()
			if (IsValid(client)) then
				ix.shop.Sync(client)
			end
		end)
	end
end)

--[[
	The panel asking for a fresh copy when it opens.

	The sync on character load covers the ordinary case, but a tab opened
	before that landed - or after a reconnect that raced it - would sit empty
	with no way to make it try again. Costs one small message per tab open.
]]
net.Receive("ixShopOpen", function(length, client)
	ix.shop.Sync(client)
end)

--------------------------------------------------------------------------------
-- Buying
--------------------------------------------------------------------------------

local nextBuy = {}

net.Receive("ixShopBuy", function(length, client)
	local uniqueID = net.ReadString()

	if (not IsValid(client) or not client:GetCharacter()) then return end

	--[[
		Rate limited. A buy walks the inventory for a free slot and writes to
		the database; a held mouse button should not do that sixty times a
		second, and the stock check alone would not stop it - one purchase per
		frame is still a purchase per frame.
	]]
	if ((nextBuy[client] or 0) > RealTime()) then return end

	nextBuy[client] = RealTime() + 0.3

	local character = client:GetCharacter()
	local faction = ix.faction.indices[character:GetFaction()]

	--[[
		No `return` on a missing faction any more. The global shop sells to
		everyone, so a character somehow without one can still buy from it -
		and `GetFor(nil)` is exactly the global list.
	]]
	local entry = ix.shop.GetFor(faction and faction.uniqueID)[uniqueID]

	if (not entry) then
		client:Notify("Your faction does not sell that.")

		return
	end

	--[[
		EVERY CHECK RUNS AGAIN HERE. The panel asked the same questions to
		decide what to draw; that was a convenience. This is the answer that
		counts, and the client sending the message proves nothing about stock,
		rank or caps.
	]]
	local ok, reason = ix.shop.CanBuy(client, entry)

	if (not ok) then
		client:Notify(reason)

		return
	end

	local inventory = character:GetInventory()

	--[[
		STOCK AND MONEY COME OFF ONLY IF THE ITEM WENT IN.

		`inventory:Add` can still fail after `FindEmptySlot` said there was
		room - another item can land in that slot in between, and a bag can be
		removed. Taking payment first and adding second is how a player pays
		for nothing, so the order is: add, then charge.

		IT IS SYNCHRONOUS AND RETURNS A POSITION, NOT A BOOLEAN. On success it
		hands back `x, y, inventoryID` (and the item itself is created in a
		callback of its own, inside); on failure, `false` and a reason. So the
		test is "did it give me a slot", not "is it true" - `if (added)` alone
		would treat a returned x of 0 as failure, and passing a callback where
		`noReplication` goes would have silently suppressed the networking.
	]]
	local added, reason = inventory:Add(uniqueID)

	if (added == false or added == nil) then
		client:Notify(reason == "noFit" and "No room in your inventory."
			or "That could not be added to your inventory.")

		return
	end

	if (not entry.infinite) then
		entry.stock = math.max((entry.stock or 1) - 1, 0)
	end

	--[[
		AND EVERY ENTRY LINKED TO IT.

		One rifle off the rack is one fewer rifle, whichever rifle it was - see
		`ix.shop.Linked`. Linked entries are taken down even when the one bought
		is infinite, because "this one never runs out" is a statement about
		THIS entry rather than about the pile behind it.
	]]
	local factionID = faction and faction.uniqueID or ix.shop.GLOBAL

	for _, link in ipairs(ix.shop.Linked(factionID, entry)) do
		link.entry.stock = math.max((link.entry.stock or 1) - 1, 0)
	end

	character:SetMoney(character:GetMoney() - (entry.price or 0))

	client:Notify(string.format("Bought %s for %s.",
		ix.item.list[uniqueID].name, ix.currency.Get(entry.price or 0)))

	ix.log.Add(client, "shopBuy", ix.item.list[uniqueID].name,
		entry.price or 0, faction and faction.name or "global")

	--- And the faction's own log, which its members can read.
	if (faction and ix.factionlog and ix.factionlog.Add) then
		ix.factionlog.Add(faction.uniqueID, "shop", string.format(
			"%s bought %s for %s", client:Name(), ix.item.list[uniqueID].name,
			ix.currency.Get(entry.price or 0)))
	end

	ix.shop.Save()
	ix.shop.SyncAll()
end)

ix.log.AddType("shopBuy", function(client, name, price, faction)
	return string.format("%s bought %s from the %s shop for %d.",
		client:Name(), name, faction, price)
end, FLAG_NORMAL)

--------------------------------------------------------------------------------
-- Configuring
--------------------------------------------------------------------------------

--[[
	The whole thing, for the configurator. Admin only, and re-checked here
	rather than trusted from whoever opened the window.
]]
local function SendAll(client)
	if (not client:IsAdmin()) then return end

	net.Start("ixShopConfigAll")
		net.WriteUInt(table.Count(ix.shop.stock), 8)

		for faction, list in pairs(ix.shop.stock) do
			net.WriteString(faction)
			net.WriteUInt(table.Count(list), 16)

			for uniqueID, entry in pairs(list) do
				net.WriteString(uniqueID)
				net.WriteString(entry.category or "Misc")
				net.WriteUInt(math.max(entry.price or 0, 0), 32)
				net.WriteUInt(math.Clamp(entry.rank or 1, 1, 4), 3)
				net.WriteBool(entry.infinite == true)
				net.WriteUInt(math.max(entry.stock or 0, 0), 16)
				net.WriteUInt(math.max(entry.maxStock or 0, 0), 16)
				net.WriteUInt(math.max(entry.restockTime or 0, 0), 32)
				net.WriteUInt(math.max(entry.restockAmount or 0, 0), 16)

				--- The same links the player sync carries; see `ix.shop.Sync`.
				net.WriteUInt(math.min(#(entry.links or {}), 32), 8)

				for index = 1, math.min(#(entry.links or {}), 32) do
					net.WriteString(entry.links[index])
				end
			end
		end
	net.Send(client)
end

ix.shop.SendAll = SendAll

net.Receive("ixShopConfigOpen", function(length, client)
	if (not client:IsAdmin()) then return end

	SendAll(client)
end)

--[[
	One entry written, or removed.

	`remove` rather than a separate message, because the two are the same
	decision made in the same window and splitting them means two paths that
	have to agree about what an entry is.
]]
net.Receive("ixShopConfigSet", function(length, client)
	if (not client:IsAdmin()) then return end

	local faction = net.ReadString()
	local uniqueID = net.ReadString()
	local remove = net.ReadBool()

	if (faction ~= ix.shop.GLOBAL and not ix.faction.teams[faction]) then
		client:Notify("No faction with the uniqueID '" .. faction .. "'.")

		return
	end

	if (not ix.item.list[uniqueID]) then
		client:Notify("No item with the uniqueID '" .. uniqueID .. "'.")

		return
	end

	if (remove) then
		if (ix.shop.stock[faction]) then
			ix.shop.stock[faction][uniqueID] = nil
		end

		ix.shop.Save()
		ix.shop.SyncAll()
		SendAll(client)

		return
	end

	local entry = ix.shop.stock[faction] and ix.shop.stock[faction][uniqueID]
		or ix.shop.NewEntry(uniqueID)

	entry.category = net.ReadString()
	entry.price = net.ReadUInt(32)
	entry.rank = math.Clamp(net.ReadUInt(3), 1, 4)
	entry.infinite = net.ReadBool()
	entry.maxStock = net.ReadUInt(16)
	entry.stock = math.min(net.ReadUInt(16), entry.maxStock)
	entry.restockTime = net.ReadUInt(32)
	entry.restockAmount = net.ReadUInt(16)

	--[[
		THE LINKED ENTRIES, checked against the item list on the way in.

		A link naming something that is not an item could never be found by
		`ix.shop.Linked` anyway, but it would sit in the save for ever and show
		in the configurer as a row nobody can explain. Anything unknown is
		dropped here, silently, which is the same thing the loader does to a
		whole entry naming a missing item.
	]]
	local linkCount = net.ReadUInt(8)
	local links = {}

	for _ = 1, linkCount do
		local linked = net.ReadString()

		if (ix.item.list[linked] and linked ~= uniqueID) then
			links[#links + 1] = linked
		end
	end

	entry.links = links

	--[[
		The clock starts now on a change. Otherwise editing an entry whose
		restock was overdue would immediately restock it, which makes the
		amount you just typed look wrong.
	]]
	entry.lastRestock = os.time()

	ix.shop.stock[faction] = ix.shop.stock[faction] or {}
	ix.shop.stock[faction][uniqueID] = entry

	ix.shop.Save()
	ix.shop.SyncAll()
	SendAll(client)
end)

--------------------------------------------------------------------------------
-- Copying between factions
--------------------------------------------------------------------------------

--[[
	Copy one entry, or a whole shop, from one faction to another.

	Setting up the second, third and fifteenth faction to sell the same
	ammunition at the same prices is the bulk of the work in configuring this,
	and doing it by hand is where the mistakes are - a price typed differently
	in two places is a difference nobody notices until somebody compares.

	A COPY IS A SNAPSHOT, not a link. The target gets its own entry with its own
	stock, and changing one afterwards does not change the other; two factions
	sharing one supply would be a fundamentally different thing and not one
	anybody has asked for.
]]
net.Receive("ixShopConfigCopy", function(length, client)
	if (not client:IsAdmin()) then return end

	local from = net.ReadString()
	local to = net.ReadString()
	local one = net.ReadString()

	local function Known(id)
		return id == ix.shop.GLOBAL or ix.faction.teams[id] ~= nil
	end

	if (not Known(from) or not Known(to)) then
		client:Notify("No such faction.")

		return
	end

	if (from == to) then
		client:Notify("That is the same faction.")

		return
	end

	local source = ix.shop.Get(from)

	ix.shop.stock[to] = ix.shop.stock[to] or {}

	local copied, skipped = 0, 0

	for uniqueID, entry in pairs(source) do
		if (one ~= "" and uniqueID ~= one) then continue end

		--[[
			An entry the target already has is left alone rather than
			overwritten. A bulk copy is usually "give them the rest of what we
			sell", and silently resetting the prices and stock of everything
			they already had would be a destructive answer to that.
		]]
		if (ix.shop.stock[to][uniqueID]) then
			skipped = skipped + 1

			continue
		end

		local copy = table.Copy(entry)

		--[[
			The clock starts now, and the rank is clamped to something the
			TARGET faction actually has. Copying a rank-4 entry into a faction
			whose ladder stops at 1 would price it out of reach of every member
			for ever, and that is silent - the row simply never appears for
			anyone.
		]]
		copy.lastRestock = os.time()

		--[[
			The global shop has no ladder of its own, so a rank copied INTO it
			is left alone: it will be compared against whatever rank the buyer
			happens to hold in their own faction.
		]]
		if (to ~= ix.shop.GLOBAL) then
			local ranks = ix.class.GetRanks(to)
			local highest = ranks[#ranks] or 1

			copy.rank = math.min(copy.rank or 1, highest)
		end

		ix.shop.stock[to][uniqueID] = copy
		copied = copied + 1
	end

	ix.shop.Save()
	ix.shop.SyncAll()
	SendAll(client)

	client:Notify(string.format("Copied %d entr%s to %s%s.", copied,
		copied == 1 and "y" or "ies",
		to == ix.shop.GLOBAL and "everyone" or ix.faction.teams[to].name,
		skipped > 0 and string.format(", %d already there", skipped) or ""))
end)
