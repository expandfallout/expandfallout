--[[
	Faction shops.

	Phoenix's `factionshop` plugin: a Shop tab in the F1 menu that sells your
	own faction's stock, at your own faction's prices, to whoever is senior
	enough to be trusted with it. An enlisted trooper buys ammunition; the
	rifles are an officer's signature.

	This replaces Helix's Business tab, which sells `ITEM.business` items to
	anybody with the caps and has no idea what a faction is.

	    ENTRY   one thing a faction sells: an item, a price, a category, the
	            lowest class rank that may buy it, and its own stock.

	Everything is per faction. Two factions selling 5.56 have two entries, two
	prices and two stocks, and neither can see the other's.

	RANK, NOT A LIST OF CLASSES. Phoenix attach a set of permitted classes to
	each entry, which is 222 checkboxes per item on this roster and has to be
	revisited every time a class is added. `CLASS.rank` already orders every
	class 1-4, and "officers and above" is the rule people actually describe -
	so an entry names a minimum rank and a new class is covered the moment it
	is written.

	STOCK IS ON THE ENTRY. Phoenix keep a separate table of stock pools that
	entries reference by id, so several items can draw from one supply. Nothing
	anybody has asked for needs that, and it costs an id to manage, a second
	editor to manage it in, and a garbage collector for the pools that end up
	pointing at nothing. One entry, one stock.
]]

ix.shop = ix.shop or {}

--[[
	`[factionUniqueID] = { [itemUniqueID] = entry }`.

	Keyed by faction UNIQUEID rather than index, like the spawn points and the
	sub-faction tree: an index is a load-order artefact and this is written to
	disk, so adding one faction file would silently re-point every shop.
]]
ix.shop.stock = ix.shop.stock or {}

--[[
	A blank entry, and the record of what an entry is.

	Times are in seconds. `lastRestock` is `os.time()`, not `CurTime()` - a
	restock has to keep counting while the server is down, or a shop set to
	restock daily would restock only as often as the server stayed up.
]]
function ix.shop.NewEntry(uniqueID)
	local itemTable = ix.item.list[uniqueID]

	return {
		item = uniqueID,
		category = itemTable and itemTable.category or "Misc",
		price = itemTable and itemTable.price or 100,
		rank = 1,
		infinite = false,
		stock = 10,
		maxStock = 10,
		restockAmount = 5,
		restockTime = 3600,
		lastRestock = os.time(),

		--[[
			OTHER ENTRIES THAT COME OUT OF THE SAME PILE.

			A list of item uniqueIDs in the same shop. Buying this takes one
			off each of them as well, which is how "we have thirty rifles"
			stops meaning thirty of EACH rifle - a faction with one armoury
			can sell a service rifle, a marksman carbine and a battle rifle
			from a single stock of thirty guns.

			Phoenix do this with stock POOLS: a separate table of pools that
			entries reference by id. That needs an id to manage, an editor to
			manage it in and a sweep for pools nothing points at any more.
			Links are the same idea with none of that - the relationship is
			written on the entry that has it.

			THEY ARE NOT AUTOMATICALLY MUTUAL. Linking the rifle to the pistol
			does not link the pistol back, because "buying a rifle uses a gun
			from the rack" and "buying a pistol does too" are two decisions and
			an admin may want only one of them. The configurer offers to make
			it mutual; see `ix.shop.Linked`.
		]]
		links = {}
	}
end

--[[
	Every entry a purchase of this one also draws from.

	Returns a list of `{uniqueID, entry}`, skipping anything that no longer
	exists, is infinite, or is the entry itself - a link to yourself would take
	two off one stock.
]]
function ix.shop.Linked(faction, entry)
	local out = {}

	if (not entry or not istable(entry.links)) then return out end

	local list = ix.shop.GetFor(faction)

	for _, uniqueID in ipairs(entry.links) do
		local other = list[uniqueID]

		if (other and other ~= entry and not other.infinite) then
			out[#out + 1] = {uniqueID = uniqueID, entry = other}
		end
	end

	return out
end

--[[
	The shop everybody has, whatever faction they are in.

	`*` because a faction uniqueID is a FILE NAME with `sh_` and `.lua` taken
	off, so it can never be this - which makes it a key that cannot collide
	with a real faction no matter what anybody adds later. A readable word like
	"global" could.
]]
ix.shop.GLOBAL = "*"

--- Every entry stored against one key, or an empty table.
function ix.shop.Get(faction)
	return ix.shop.stock[faction] or {}
end

--[[
	What a member of this faction can actually see: the global shop, plus their
	own faction's on top.

	THE FACTION WINS ON A CONFLICT. Both selling 5.56 means the faction has
	deliberately set its own price for it, and a global entry overriding that
	would make the faction's own configuration silently do nothing.

	A new table each call rather than a cached merge. This runs on a sync and
	on a purchase, not per frame, and a cache would need invalidating from
	every place either shop can change - which is exactly the kind of thing
	that goes stale and sells at last week's price.
]]
function ix.shop.GetFor(faction)
	local out = {}

	for uniqueID, entry in pairs(ix.shop.Get(ix.shop.GLOBAL)) do
		out[uniqueID] = entry
	end

	for uniqueID, entry in pairs(ix.shop.Get(faction)) do
		out[uniqueID] = entry
	end

	return out
end

--[[
	The categories a faction's shop actually has something in.

	Derived rather than configured, which is what makes "a tab does not exist
	if there is nothing in it" true by construction: a category is the set of
	entries that name it, so removing the last one removes the tab, and there
	is no list of category names to garbage collect afterwards.
]]
function ix.shop.GetCategories(faction, rank)
	local seen, out = {}, {}

	for _, entry in pairs(ix.shop.GetFor(faction)) do
		--[[
			Filtered by rank as well as by emptiness. A category holding
			nothing this character may buy is a tab that opens on an empty
			list, which reads as a broken shop rather than as a locked one.
		]]
		if (rank and (entry.rank or 1) > rank) then continue end
		if (not ix.item.list[entry.item]) then continue end

		local name = entry.category or "Misc"

		if (not seen[name]) then
			seen[name] = true
			out[#out + 1] = name
		end
	end

	table.sort(out)

	return out
end

--[[
	Is this restock due, and how much for?

	Returns the number of items to add, which is 0 when nothing is owed. Whole
	periods only: a shop that has been up for three restock intervals owes
	three restocks, not a fraction of a fourth, so a server that was down for a
	week comes back stocked rather than owing an unbounded amount.
]]
function ix.shop.GetRestockDue(entry, now)
	-- Nothing to restock when there is no count being kept.
	if (entry.infinite) then return 0 end

	if (not entry.restockTime or entry.restockTime <= 0) then return 0 end
	if (not entry.restockAmount or entry.restockAmount <= 0) then return 0 end

	now = now or os.time()

	local periods = math.floor((now - (entry.lastRestock or now))
		/ entry.restockTime)

	if (periods < 1) then return 0 end

	local room = (entry.maxStock or 0) - (entry.stock or 0)

	return math.max(math.min(periods * entry.restockAmount, room), 0), periods
end

--[[
	How long until the next restock, in seconds. 0 means "never".

	The countdown the shop tab shows. `lastRestock` only ever moves in whole
	periods - see `ix.shop.Restock` - so the remainder of the division IS the
	time already served in the current period, and what is left of it is what
	somebody waiting for the last rifle wants to know.

	IT KEEPS RUNNING ON A FULL SHELF. The restock happens either way; all that
	changes is that the stock is already at its ceiling and the delivery adds
	nothing. Hiding the clock there made the shop look like it had stopped
	restocking whenever it was full, which is the opposite of what is true -
	and it meant the one number a player wants ("how often does this come in")
	was only visible at the moment it was too late to matter.

	Zero for an infinite entry and for one with no restock configured, because
	in both of those there really is nothing on its way.
]]
function ix.shop.RestockIn(entry, now)
	if (not entry or entry.infinite) then return 0 end

	local period = entry.restockTime or 0

	if (period <= 0) then return 0 end
	if ((entry.restockAmount or 0) <= 0) then return 0 end

	now = now or os.time()

	local elapsed = now - (entry.lastRestock or now)

	--[[
		A clock that has gone BACKWARDS - a restock timestamp in the future,
		which a hand-edited save or a system clock change can produce - would
		otherwise give a negative remainder and a countdown that counts up.
	]]
	if (elapsed < 0) then return period end

	return math.ceil(period - (elapsed % period))
end

--[[
	May this character buy this entry? Returns `true`, or `false, reason`.

	The one place that decides, so the shop panel can grey a row out for the
	same reason the server refuses it - and the panel is only ever a
	convenience: this runs again on the server for every purchase.
]]
function ix.shop.CanBuy(client, entry)
	local character = client and client:GetCharacter()

	if (not character or not entry) then return false, "No character." end

	local itemTable = ix.item.list[entry.item]

	if (not itemTable) then
		return false, "That item no longer exists."
	end

	--[[
		Through `ix.shop.GetFor`, not `ix.shop.stock` directly. The client is
		only ever sent the one merged list it can see, so it overrides that
		accessor - reading the table here would make this function server-only,
		and it is meant to be the one place that decides for both.
	]]
	local faction = ix.faction.indices[character:GetFaction()]
	local list = faction and ix.shop.GetFor(faction.uniqueID)

	if (not list or list[entry.item] ~= entry) then
		return false, "That is not for sale to you."
	end

	local info = ix.class.list[character:GetClass()]
	local rank = info and (info.rank or 1) or 0

	if (rank < (entry.rank or 1)) then
		return false, string.format("You have to be rank %d or above.",
			entry.rank or 1)
	end

	--[[
		`infinite` is a separate flag rather than a stock of -1 or 0.

		Both of those overload a count with a meaning, and the one that would
		read most naturally - 0 for unlimited - is the exact value that already
		means "none left". A shop set to unlimited would be indistinguishable
		from a shop that had just sold out.
	]]
	if (not entry.infinite and (entry.stock or 0) < 1) then
		return false, "Out of stock."
	end

	if (character:GetMoney() < (entry.price or 0)) then
		return false, "You cannot afford it."
	end

	--[[
		Asked last, because it is the only check whose answer can change
		between the panel drawing the row and the player clicking it - and the
		only one whose message is about them rather than about the shop.
	]]
	local inventory = character:GetInventory()

	if (not inventory or not inventory:FindEmptySlot(
	itemTable.width, itemTable.height)) then
		return false, "No room in your inventory."
	end

	return true
end
