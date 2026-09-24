--[[
	Faction storage.

	Phoenix's `factionstorage`: containers that belong to a faction rather than
	to a person. An admin makes one at whatever size the faction is owed, the
	faction deploys it wherever they want it, and it survives restarts with
	everything in it.

	A RECORD IS NOT AN ENTITY. The record is the storage - its faction, its
	size, its inventory, its name - and the entity is only that record standing
	somewhere. Stowing one removes the entity and keeps the record, which is
	what makes "pick it up and put it down over there" keep the items: nothing
	about the inventory changes, because the inventory belongs to the record.

	    id           what the entity carries and everything refers to
	    faction      uniqueID, not an index - see `sh_shop.lua` on why
	    invID        the Helix inventory, restored on load
	    map          which map it was placed on
	    placed       whether it is out, as opposed to stowed
	    minRank      the lowest class rank that may open it

	PER SCHEMA, NOT PER MAP, even though the position is a map's business. A
	faction keeps its storages across a map change; they simply come back
	stowed, because `pos` on one map means nothing on another. Storing the whole
	record per map would lose the faction's property every time the map changed,
	which is not a thing a storage system is allowed to do.
]]

ix.factionStorage = ix.factionStorage or {}

--- `[id] = record`.
ix.factionStorage.list = ix.factionStorage.list or {}

--[[
	The model every storage uses.

	One model rather than a choice: the point of a faction storage is that
	people recognise it on sight, and Phoenix use this same locker for theirs.
]]
ix.factionStorage.model =
	"models/roadkill/fallout/containers/lockercabinet01.mdl"

function ix.factionStorage.Get(id)
	return ix.factionStorage.list[id]
end

--- Every storage belonging to a faction, sorted by id.
function ix.factionStorage.GetFaction(faction)
	local out = {}

	for _, record in pairs(ix.factionStorage.list) do
		if (record.faction == faction) then
			out[#out + 1] = record
		end
	end

	table.sort(out, function(a, b) return a.id < b.id end)

	return out
end

--[[
	May this player open it? Returns `true`, or `false, reason`.

	Their faction and their rank, and nothing about where they are standing -
	the entity's `Use` already means they are within arm's reach of it.
]]
function ix.factionStorage.CanAccess(client, record)
	local character = client and client:GetCharacter()

	if (not character or not record) then return false, "No character." end

	local faction = ix.faction.indices[character:GetFaction()]

	if (not faction or faction.uniqueID ~= record.faction) then
		local owner = ix.faction.teams[record.faction]

		return false, string.format("This belongs to %s.",
			owner and owner.name or "another faction")
	end

	local info = ix.class.list[character:GetClass()]
	local rank = info and (info.rank or 1) or 0

	if (rank < (record.minRank or 1)) then
		return false, string.format("You have to be %s or above.",
			ix.class.GetRankName(record.faction, record.minRank or 1))
	end

	return true
end

--[[
	May this player deploy or stow the faction's storages?

	LEAD ONLY, which is the rule asked for: a faction's property is moved by
	the person who answers for the faction. `CanAccess` is the separate,
	looser question of who may take things out of one.
]]
function ix.factionStorage.CanManage(client, faction, bAdmin)
	--[[
		A superadmin on `/afm` may move a faction's property for them. They are
		not in the faction and have no rank in it, so the check below would
		refuse them - and somebody has to be able to place a storage for a
		faction whose Lead has not logged in for a week.

		`bAdmin` grants nothing on its own: it says which window the request
		came from, and `IsSuperAdmin` is what decides.
	]]
	if (bAdmin and IsValid(client) and client:IsSuperAdmin()) then
		return true
	end

	local character = client and client:GetCharacter()

	if (not character) then return false, "No character." end

	local own = ix.faction.indices[character:GetFaction()]

	if (not own or (faction and own.uniqueID ~= faction)) then
		return false, "That is not your faction."
	end

	local info = ix.class.list[character:GetClass()]

	if (not info or (info.rank or 1) < 4) then
		return false, string.format("Only %s may move the faction's property.",
			ix.class.GetRankName(own.uniqueID, 4))
	end

	return true
end

--[[
	The record's inventory, restoring it if it is not in memory.

	NOT called `Load`: `sv_factionstorage.lua` already has an
	`ix.factionStorage.Load` for reading the records off disk, it loads after
	this file, and one would have silently replaced the other - a callback
	that never fires, which opens nothing and says nothing.

	`callback(inventory)` runs either immediately or after the restore. Nil is
	only ever passed when the record has no id at all, which is a record that
	was written before its creation finished.

	THIS EXISTS BECAUSE A MISSING INVENTORY IS RECOVERABLE, AND WAS FATAL. The
	entity used to answer "not loaded" and stop - a dead end for a container
	whose id and size are both written down right there. Everything needed to
	bring it back is in the record, so it is brought back.

	`ix.inventory.Restore` registers the inventory in `ix.item.inventories`
	SYNCHRONOUSLY and fills in the items when its query returns, so a second
	caller a moment later finds it already present and takes the fast path.
]]
function ix.factionStorage.ResolveInventory(record, callback)
	if (not record or not record.invID or record.invID < 1) then
		callback(nil)

		return
	end

	local inventory = ix.inventory.Get(record.invID)

	if (inventory) then
		callback(inventory)

		return
	end

	if (not SERVER) then
		callback(nil)

		return
	end

	local _, width, height =
		ix.factionStorage.InventoryType(record.width, record.height)

	ix.inventory.Restore(record.invID, width, height, function(restored)
		if (restored) then
			restored.vars.isBag = true
			restored.vars.isContainer = true
			restored.vars.factionStorage = record.id
		end

		callback(restored or ix.inventory.Get(record.invID))
	end)
end

--[[
	The inventory type for a size, registered on demand.

	Helix takes inventory sizes from a REGISTERED TYPE rather than from
	arguments, so an admin making a 10x6 storage needs a `factionstorage:10x6`
	type to exist. Registering per size as they are asked for keeps "any size
	you like" true without a table of every size anybody might ever want.
]]
function ix.factionStorage.InventoryType(width, height)
	width = math.Clamp(math.floor(width or 4), 1, 20)
	height = math.Clamp(math.floor(height or 4), 1, 20)

	local invType = string.format("factionstorage:%dx%d", width, height)

	if (not ix.item.inventoryTypes[invType]) then
		ix.inventory.Register(invType, width, height, true)
	end

	return invType, width, height
end
