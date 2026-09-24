--[[
	Faction storage: persistence, deploying, stowing.

	See `sh_factionstorage.lua` for what a record is and why it is not an
	entity.
]]

if (not SERVER) then return end

--[[
	No net strings of our own for opening. `ix.storage` owns that, and its
	messages are the ones the inventory UI already listens for.
]]
util.AddNetworkString("ixFactionStorageDeploy")

local SAVE_KEY = "factionstorages"

--- Guarded like the loot library's; see `sv_loot.lua` on why saving early is
--- worse than not saving at all.
local loaded = false

function ix.factionStorage.Save()
	if (not loaded) then
		ErrorNoHalt("[falloutrp] refusing to save faction storages before "
			.. "they have been loaded\n")

		return
	end

	--[[
		The entity is not saved, its POSITION is. Everything else about a
		deployed storage is derivable, and an entity index would be meaningless
		by the time it was read back.
	]]
	local out = {}

	for id, record in pairs(ix.factionStorage.list) do
		out[id] = {
			id = record.id,
			faction = record.faction,
			name = record.name,
			width = record.width,
			height = record.height,
			invID = record.invID,
			minRank = record.minRank,
			map = record.map,
			placed = record.placed,
			pos = record.pos,
			ang = record.ang
		}
	end

	ix.data.Set(SAVE_KEY, out, false, true)
end

--[[
	Restore one record's inventory, then its entity if it belongs on this map.

	The inventory comes back first and unconditionally: a stowed storage still
	has its contents, and something has to hold them.
]]
local function RestoreRecord(record)
	local invType, width, height =
		ix.factionStorage.InventoryType(record.width, record.height)

	record.width, record.height = width, height

	if (not record.invID or record.invID < 1) then
		--[[
			A record with no inventory is one that was written before its
			creation finished. Rather than dropping it - which would lose a
			storage an admin made - it is given a new one, empty.
		]]
		ix.inventory.New(0, invType, function(inventory)
			record.invID = inventory:GetID()

			inventory.vars.isBag = true
			inventory.vars.isContainer = true

			ix.factionStorage.Save()
		end)

		return
	end

	ix.factionStorage.ResolveInventory(record, function()
		if (record.placed and record.map == game.GetMap() and record.pos) then
			ix.factionStorage.Spawn(record)
		end
	end)
end

function ix.factionStorage.Load()
	if (loaded) then return end

	local stored = ix.data.Get(SAVE_KEY, {}, false, true) or {}

	ix.factionStorage.list = {}
	loaded = true

	local kept, dropped = 0, 0

	for _, record in pairs(stored) do
		--[[
			A storage whose faction no longer exists is dropped, and its
			inventory with it. Nobody could ever open it: `CanAccess` compares
			against a faction that is not in the roster.
		]]
		if (not record.id or not ix.faction.teams[record.faction]) then
			dropped = dropped + 1

			continue
		end

		ix.factionStorage.list[record.id] = record
		kept = kept + 1

		RestoreRecord(record)
	end

	MsgC(Color(255, 200, 100), string.format(
		"[falloutrp] loaded %d faction storage(s)%s\n", kept,
		dropped > 0 and string.format(", dropped %d whose faction is gone",
			dropped) or ""))
end

hook.Add("LoadData", "ixFactionStorage", ix.factionStorage.Load)
hook.Add("PostLoadData", "ixFactionStorage", ix.factionStorage.Load)
timer.Simple(10, ix.factionStorage.Load)

--------------------------------------------------------------------------------
-- Making, deploying, stowing
--------------------------------------------------------------------------------

--- The next free id. Ids are never reused, so a stale reference stays stale.
local function NextID()
	local highest = 0

	for id in pairs(ix.factionStorage.list) do
		highest = math.max(highest, id)
	end

	return highest + 1
end

--[[
	Create a storage for a faction. Admin-driven; the faction cannot make its
	own, which is what "admins make them for you" means.

	It arrives STOWED. An admin making one in a menu is not standing where the
	faction wants it, and the faction's lead putting it down is the same
	gesture as moving it later.
]]
function ix.factionStorage.Create(faction, name, width, height, minRank, callback)
	if (not ix.faction.teams[faction]) then return false end

	local invType, w, h = ix.factionStorage.InventoryType(width, height)
	local id = NextID()

	local record = {
		id = id,
		faction = faction,
		name = name and name ~= "" and name or "Faction Storage",
		width = w,
		height = h,
		minRank = math.Clamp(math.floor(minRank or 1), 1, 4),
		map = game.GetMap(),
		placed = false
	}

	ix.factionStorage.list[id] = record

	ix.inventory.New(0, invType, function(inventory)
		record.invID = inventory:GetID()

		inventory.vars.isBag = true
		inventory.vars.isContainer = true
		inventory.vars.factionStorage = id

		ix.factionStorage.Save()

		if (callback) then
			callback(record)
		end
	end)

	return record
end

--- Put the entity into the world for a record that says it is placed.
function ix.factionStorage.Spawn(record)
	if (IsValid(record.entity)) then return record.entity end

	local entity = ents.Create("ix_factionstorage")

	if (not IsValid(entity)) then return end

	entity:SetModel(ix.factionStorage.model)
	entity:SetPos(record.pos)
	entity:SetAngles(record.ang or angle_zero)
	entity:Spawn()

	--[[
		AFTER `Spawn`, NOT BEFORE, AND THIS IS WHAT SAID "STILL LOADING".

		`SetStorageID` is a `NetworkVar`, and network vars do not exist until
		`SetupDataTables` has run - which the engine does as part of `Spawn`.
		Setting one before that writes into nothing and is silently lost, so
		every deployed storage carried id 0, `ix.factionStorage.Get(0)` found
		no record, and `ENT:GetInventory` answered nil for ever.

		It looked like a loading problem because that is what the message said,
		and the admin route worked throughout - it reads `record.invID` from
		the record it already has, and never asks the entity anything.
	]]
	entity:SetStorageID(record.id)

	local inventory = ix.inventory.Get(record.invID)

	if (inventory) then
		entity:SetInventory(inventory)
	end

	record.entity = entity

	return entity
end

--[[
	Put it down. Returns `true`, or `false, reason`.

	The position is checked again here even though the ghost checked it: the
	ghost is a courtesy on a machine we do not control.
]]
function ix.factionStorage.Deploy(client, record, position, angles, bAdmin)
	if (record.placed and IsValid(record.entity)) then
		return false, "That is already deployed."
	end

	local ok, reason = ix.factionStorage.CanManage(client, record.faction,
		bAdmin)

	if (not ok) then return false, reason end

	ok, reason = ix.deploy.CanPlace(client, position)

	if (not ok) then return false, reason end

	record.map = game.GetMap()
	record.pos = position
	record.ang = angles or angle_zero
	record.placed = true

	if (not ix.factionStorage.Spawn(record)) then
		record.placed = false

		return false, "That could not be placed."
	end

	ix.factionStorage.Save()
	ix.log.Add(client, "factionStorageDeploy", record.name or record.id)

	return true
end

--[[
	Pick it up. The inventory is untouched, which is the whole point.
]]
function ix.factionStorage.Stow(client, record, bAdmin)
	local ok, reason = ix.factionStorage.CanManage(client, record.faction,
		bAdmin)

	if (not ok) then return false, reason end

	if (IsValid(record.entity)) then
		record.entity:Remove()
	end

	record.entity = nil
	record.placed = false
	record.pos = nil

	ix.factionStorage.Save()
	ix.log.Add(client, "factionStorageStow", record.name or record.id)

	return true
end

--- Destroy it and everything in it. Admin only, and irreversible.
function ix.factionStorage.Destroy(record)
	if (IsValid(record.entity)) then
		record.entity:Remove()
	end

	local inventory = ix.inventory.Get(record.invID)

	if (inventory) then
		if (ix.storage.InUse(inventory)) then
			ix.storage.Close(inventory)
		end

		--[[
			The items go; the inventory ROW is left behind.

			Helix has no `ix.inventory.Delete` - character deletion writes the
			SQL by hand - and an empty orphaned inventory row costs nothing and
			is never looked up again, while a hand-written DELETE here would be
			a second place that has to know the schema's table names.
		]]
		for item in ix.inventory.Each(inventory) do
			item:Remove()
		end

		ix.item.inventories[record.invID] = nil
	end

	ix.factionStorage.list[record.id] = nil

	ix.factionStorage.Save()
end

--------------------------------------------------------------------------------
-- Keeping the inventory honest
--------------------------------------------------------------------------------

--[[
	Anything moved in or out is checked against the same access rule.

	`CanTransferItem` rather than trusting the open window: the window was
	opened by somebody who passed the check, and nothing stops the check
	failing afterwards - a demotion, a faction change, or walking away and
	leaving it open.
]]
hook.Add("CanTransferItem", "ixFactionStorage", function(item, from, to)
	for _, inventory in ipairs({from, to}) do
		if (not inventory or not inventory.vars) then continue end

		local id = inventory.vars.factionStorage

		if (not id) then continue end

		local record = ix.factionStorage.Get(id)

		if (not record) then return false end

		local client = item.player or (item.GetOwner and item:GetOwner())

		if (not IsValid(client)) then continue end

		if (not ix.factionStorage.CanAccess(client, record)) then
			return false
		end

		--[[
			Distance is NOT checked here. `ix.storage` closes the window when
			the player leaves the entity behind, and duplicating that check
			would mean two different answers to "how far is too far" the first
			time either changed.
		]]
	end
end)

ix.log.AddType("factionStorageOpen", function(client, name)
	return string.format("%s opened %s.", client:Name(), name)
end, FLAG_NORMAL)

ix.log.AddType("factionStorageDeploy", function(client, name)
	return string.format("%s deployed %s.", client:Name(), name)
end, FLAG_WARNING)

ix.log.AddType("factionStorageStow", function(client, name)
	return string.format("%s stowed %s.", client:Name(), name)
end, FLAG_WARNING)

ix.log.AddType("factionStorageClose", function(client, name)
	return string.format("%s closed %s.", client:Name(), name)
end, FLAG_NORMAL)

--------------------------------------------------------------------------------
-- Deploying from the faction menu
--------------------------------------------------------------------------------

net.Receive("ixFactionStorageDeploy", function(length, client)
	local id = net.ReadUInt(16)
	local position = net.ReadVector()
	local angles = net.ReadAngle()

	--[[
		Whether this came from the admin window. Checked against
		`IsSuperAdmin` in `CanManage`, so a client setting it gains nothing.
	]]
	local bAdmin = net.ReadBool()

	local record = ix.factionStorage.Get(id)

	if (not record) then
		client:Notify("No such storage.")

		return
	end

	local ok, reason = ix.factionStorage.Deploy(client, record, position,
		angles, bAdmin)

	if (not ok) then
		client:Notify(reason)

		return
	end

	client:Notify("Deployed " .. (record.name or "the storage") .. ".")
end)

--[[
	Every storage record, and whether each part of it resolves.

	The chain from a player pressing E to an open window is: entity ->
	`GetStorageID` -> record -> `invID` -> a live inventory. Any link can be the
	broken one and the player only ever sees the last message, so this prints
	all of them at once.
]]
concommand.Add("fo_storage_report", function(client)
	local function Say(text)
		if (IsValid(client)) then
			client:ChatPrint(text)
		else
			print(text)
		end
	end

	if (IsValid(client) and not client:IsAdmin()) then return end

	Say(string.format("[falloutrp] map=%s  loaded=%s  %d record(s)",
		game.GetMap(), tostring(loaded),
		table.Count(ix.factionStorage.list)))

	for id, record in SortedPairs(ix.factionStorage.list) do
		local inventory = record.invID and ix.inventory.Get(record.invID)
		local entity = record.entity

		Say(string.format("  id=%s  faction=%s  size=%sx%s",
			tostring(id), tostring(record.faction),
			tostring(record.width), tostring(record.height)))

		Say(string.format("    invID=%s  inventory=%s  items=%s",
			tostring(record.invID),
			inventory and "LOADED" or "MISSING",
			inventory and tostring(table.Count(inventory:GetItems() or {}))
				or "-"))

		Say(string.format("    placed=%s  map=%s  entity=%s  entityID=%s",
			tostring(record.placed), tostring(record.map),
			IsValid(entity) and tostring(entity:EntIndex()) or "none",
			IsValid(entity) and tostring(entity:GetStorageID()) or "-"))
	end

	--[[
		And every storage entity in the world, whether or not a record claims
		it. An entity nothing points at is the shape of a spawn that half
		worked, and it would not appear in the list above.
	]]
	for _, entity in ipairs(ents.FindByClass("ix_factionstorage")) do
		local storageID = entity:GetStorageID()
		local record = ix.factionStorage.Get(storageID)

		Say(string.format("  world entity %d: storageID=%d  record=%s",
			entity:EntIndex(), storageID, record and "found" or "NONE"))
	end
end)
