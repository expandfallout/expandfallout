--[[
	Nodes: keeping them, refilling them, and letting somebody edit the ores.

	TWO THINGS ARE SAVED, and they are saved separately on purpose:

	    the nodes     per map, because a position means nothing on another one
	    the ores      GLOBALLY, because "gold is worth 0.75 and uses skin 4" is
	                  a decision about the server rather than about a map

	The node list follows the same pattern as the points: `LoadData`, a
	`PostLoadData` and a timer as belt and braces, and a SAVE GUARD so a load
	that never ran cannot write an empty table over the file. `InitPostEntity`
	never fires in this schema - see the header of `sv_points.lua`.
]]

if (not SERVER) then return end

util.AddNetworkString("ixMiningOres")
util.AddNetworkString("ixMiningSave")
util.AddNetworkString("ixMiningEffect")
util.AddNetworkString("ixMiningOpen")

--- `[id] = {ore, amount, remaining, position, angles, refillAt, entity}`.
ix.mining.nodes = ix.mining.nodes or {}
ix.mining.nextID = ix.mining.nextID or 1
ix.mining.loaded = false

local NODE_KEY = "orenodes"
local ORE_KEY = "miningores"

--------------------------------------------------------------------------------
-- The ore list
--------------------------------------------------------------------------------

--[[
	Sanity, applied to whatever comes back from the file or from the config
	window. A saved list is data somebody typed, and an ore with no item or a
	strength of zero is a node nobody can ever empty.
]]
local function Clean(list)
	local out = {}
	local seen = {}

	for _, entry in ipairs(list or {}) do
		local id = string.lower(string.Trim(tostring(entry.id or "")))

		if (id == "" or seen[id]) then continue end

		local colour = istable(entry.colour) and entry.colour or {220, 220, 0}

		seen[id] = true

		out[#out + 1] = {
			id = id,
			name = tostring(entry.name or id),
			item = tostring(entry.item or ""),
			strength = math.Clamp(tonumber(entry.strength) or 1, 0.05, 20),
			skin = math.Clamp(math.floor(tonumber(entry.skin) or 0), 0, 32),

			--[[
				Zero means "use the config", which is how the window writes an
				ore that has nothing to say about its own yield. Every read goes
				through `ix.mining.Yield`, so nothing else has to know that.
			]]
			yield = math.Clamp(math.floor(tonumber(entry.yield) or 0), 0, 100),

			--- Zero is "use the config"; see `ix.mining.SoftMultiplier`.
			soft = math.Clamp(tonumber(entry.soft) or 0, 0, 50),
			colour = {
				math.Clamp(math.floor(tonumber(colour[1]) or 220), 0, 255),
				math.Clamp(math.floor(tonumber(colour[2]) or 220), 0, 255),
				math.Clamp(math.floor(tonumber(colour[3]) or 0), 0, 255)
			}
		}
	end

	--- Never empty: a node with no ore to be is a node that cannot exist.
	if (#out == 0) then return table.Copy(ix.mining.defaults) end

	return out
end

function ix.mining.SendOres(client)
	net.Start("ixMiningOres")
		net.WriteUInt(#ix.mining.ores, 8)

		for _, ore in ipairs(ix.mining.ores) do
			net.WriteString(ore.id)
			net.WriteString(ore.name)
			net.WriteString(ore.item)
			net.WriteFloat(ore.strength)
			net.WriteUInt(ore.skin, 8)
			net.WriteUInt(ore.yield or 0, 8)
			net.WriteFloat(ore.soft or 0)
			net.WriteUInt(ore.colour[1], 8)
			net.WriteUInt(ore.colour[2], 8)
			net.WriteUInt(ore.colour[3], 8)
		end

	if (IsValid(client)) then net.Send(client) else net.Broadcast() end
end

function ix.mining.SaveOres()
	ix.data.Set(ORE_KEY, ix.mining.ores, true)
end

--[[
	Somebody saved the config window.

	The whole list arrives at once rather than as edits, because that is what
	the window holds - and a list that is replaced wholesale cannot end up half
	applied if the connection drops between two messages.
]]
net.Receive("ixMiningSave", function(length, client)
	if (not ix.admin.Can(client, "mining.edit")) then return end

	local count = net.ReadUInt(8)
	local list = {}

	for _ = 1, count do
		list[#list + 1] = {
			id = net.ReadString(),
			name = net.ReadString(),
			item = net.ReadString(),
			strength = net.ReadFloat(),
			skin = net.ReadUInt(8),
			yield = net.ReadUInt(8),
			soft = net.ReadFloat(),
			colour = {net.ReadUInt(8), net.ReadUInt(8), net.ReadUInt(8)}
		}
	end

	ix.mining.ores = Clean(list)

	ix.mining.SaveOres()
	ix.mining.SendOres()

	--[[
		EVERY NODE IS RE-READ. An ore that changed skin or vanished entirely
		would otherwise leave rocks showing the old one until a restart.
	]]
	for _, record in pairs(ix.mining.nodes) do
		if (IsValid(record.entity)) then record.entity:ApplyRecord(record) end
	end

	client:Notify(string.format("%d ore(s) saved.", #ix.mining.ores))

	ix.log.Add(client, "miningConfig", #ix.mining.ores)
end)

--------------------------------------------------------------------------------
-- The nodes
--------------------------------------------------------------------------------

function ix.mining.Save()
	if (not ix.mining.loaded) then return end

	local out = {}

	for id, record in pairs(ix.mining.nodes) do
		out[id] = {
			ore = record.ore,
			amount = record.amount,
			remaining = IsValid(record.entity)
				and math.Round(record.entity:GetAmount(), 2)
				or record.remaining,
			respawn = record.respawn,
			refillAt = record.refillAt,
			position = record.position,
			angles = record.angles
		}
	end

	ix.data.Set(NODE_KEY, out)
end

function ix.mining.Spawn(record)
	if (IsValid(record.entity)) then return record.entity end

	local node = ents.Create("ix_orenode")

	if (not IsValid(node)) then return end

	node:SetPos(record.position)
	node:SetAngles(record.angles or angle_zero)
	node:Spawn()
	node:Activate()

	node.ixRecord = record
	node.ixNodeID = record.id

	record.entity = node

	node:ApplyRecord(record)

	return node
end

function ix.mining.Load()
	if (ix.mining.loaded) then return end

	ix.mining.ores = Clean(ix.data.Get(ORE_KEY, nil, true)
		or table.Copy(ix.mining.defaults))

	ix.mining.nodes = ix.data.Get(NODE_KEY, {}) or {}
	ix.mining.loaded = true

	local highest, spawned = 0, 0

	for id, record in pairs(ix.mining.nodes) do
		--[[
			The key is kept as it came back - JSON has no integer keys, so a
			table saved with `[3]` returns with `["3"]`. Same rule as the
			points, and for the same reason: the record's id has to index the
			table it is in.
		]]
		record.id = id

		--- Vectors come back from JSON as plain tables with no metatable.
		record.position = Vector(record.position)
		record.angles = Angle(record.angles or angle_zero)

		highest = math.max(highest, tonumber(id) or 0)

		--- An emptied node stays empty until its clock says otherwise.
		if ((tonumber(record.remaining) or 0) > 0
		or (tonumber(record.refillAt) or 0) <= os.time()) then
			if (ix.mining.Spawn(record)) then spawned = spawned + 1 end
		end
	end

	ix.mining.nextID = highest + 1

	MsgC(Color(255, 200, 100), string.format(
		"[falloutrp] %d ore node(s) restored, %d ore(s) configured\n",
		spawned, #ix.mining.ores))

	ix.mining.SendOres()
end

hook.Add("LoadData", "ixMining", ix.mining.Load)
hook.Add("PostLoadData", "ixMining", ix.mining.Load)
timer.Simple(10, ix.mining.Load)

hook.Add("PlayerInitialSpawn", "ixMining", function(client)
	timer.Simple(5, function()
		if (IsValid(client)) then ix.mining.SendOres(client) end
	end)
end)

--------------------------------------------------------------------------------
-- Placing, editing, removing
--------------------------------------------------------------------------------

function ix.mining.Add(client, position, angles, ore, amount, respawn)
	if (not ix.mining.loaded) then
		return false, "The node list has not loaded yet."
	end

	local id = ix.mining.nextID

	ix.mining.nextID = id + 1

	local record = {
		id = id,
		ore = ore,
		amount = math.max(tonumber(amount) or 25, 1),
		respawn = math.max(tonumber(respawn)
			or ix.config.Get("miningRespawn", 600), 10),
		position = position,
		angles = angles or angle_zero,
		refillAt = 0
	}

	record.remaining = record.amount

	ix.mining.nodes[id] = record

	ix.mining.Spawn(record)
	ix.mining.Save()

	ix.log.Add(client, "miningPlace", ore, record.amount)

	return true, id
end

--- Point the tool at one that exists and it takes the tool's settings instead.
function ix.mining.Update(client, node, ore, amount, respawn)
	local record = node.ixRecord

	if (not record) then return false, "That node is not in the list." end

	record.ore = ore
	record.amount = math.max(tonumber(amount) or record.amount, 1)
	record.respawn = math.max(tonumber(respawn) or record.respawn, 10)
	record.remaining = record.amount
	record.refillAt = 0

	node:ApplyRecord(record)

	ix.mining.Save()

	ix.log.Add(client, "miningEdit", ore, record.amount)

	return true
end

--[[
	Remove one by its id, WITH OR WITHOUT AN ENTITY.

	A mined-out node is a record with nothing standing on it - which is exactly
	the one somebody wants to delete, and exactly the one the tool cannot be
	pointed at. `/pointdelete ore:3` reaches it; the tool reaches the rest.
]]
function ix.mining.RemoveByID(client, id)
	id = string.Trim(tostring(id or ""))

	--- The string first: JSON keys come back as strings. See the points.
	local key = ix.mining.nodes[id] and id or nil

	if (not key) then
		local number = tonumber(id)

		if (number and ix.mining.nodes[number]) then key = number end
	end

	if (not key) then return false, "There is no ore node " .. id .. "." end

	local record = ix.mining.nodes[key]

	ix.mining.nodes[key] = nil

	if (IsValid(record.entity)) then record.entity:Remove() end

	ix.mining.Save()

	ix.log.Add(client, "miningRemove", tostring(record.position))

	return true
end

--- The tool's way in: an entity, which knows its own id.
function ix.mining.Remove(client, node)
	if (not IsValid(node) or not node.ixNodeID) then
		return false, "That node is not in the list."
	end

	return ix.mining.RemoveByID(client, node.ixNodeID)
end

--[[
	Emptied. The entity goes and the record keeps the clock.

	The same decision the cap stash made and for the same reason: a node
	waiting to come back has no entity to run a think, so the wait belongs to
	the record - and `os.time`, because `CurTime` restarts at zero on every map
	load (gotcha 11).
]]
function ix.mining.Deplete(node)
	local record = node.ixRecord

	if (record) then
		local respawn = tonumber(record.respawn)
			or ix.config.Get("miningRespawn", 600)
		local now = os.time()

		record.remaining = 0
		record.refillAt = now + respawn
		record.entity = nil

		ix.mining.Save()
	end

	node:EmitSound("zrms/machine_crush.wav", 75, 90)
	node:Remove()
end

--[[
	One second over the records, putting back anything whose clock has run out.
	Identical in shape to `ix.points.Tick`, deliberately.
]]
timer.Create("ixMiningTick", 1, 0, function()
	if (not ix.mining.loaded) then return end

	local now = os.time()
	local changed = false

	for _, record in pairs(ix.mining.nodes) do
		if (IsValid(record.entity)) then continue end
		if ((tonumber(record.refillAt) or 0) > now) then continue end

		record.remaining = record.amount
		record.refillAt = 0
		changed = true

		local node = ix.mining.Spawn(record)

		if (IsValid(node)) then
			node:EmitSound("phoenix/ui/nv/ui_items_generic_down.mp3", 60)
		end
	end

	if (changed) then ix.mining.Save() end
end)

--------------------------------------------------------------------------------
-- Noise and particles
--------------------------------------------------------------------------------

--[[
	Told to everybody nearby rather than played on the server, because the
	particle systems live in the mining content addon and are a client thing -
	the server only says where and whether it was a good hit.
]]
function ix.mining.EffectAt(node, position, soft)
	local receivers = {}

	for _, other in ipairs(player.GetAll()) do
		if (other:GetPos():DistToSqr(position) > 4000000) then continue end

		receivers[#receivers + 1] = other
	end

	if (#receivers == 0) then return end

	net.Start("ixMiningEffect")
		net.WriteEntity(node)
		net.WriteVector(position)
		net.WriteBool(soft and true or false)
	net.Send(receivers)
end

ix.log.AddType("mine", function(client, ore, count)
	return string.format("%s mined %d %s.", client:Name(), count, ore)
end)

ix.log.AddType("miningPlace", function(client, ore, amount)
	return string.format("%s placed a %s node with %skg in it.", client:Name(),
		ore, amount)
end)

ix.log.AddType("miningEdit", function(client, ore, amount)
	return string.format("%s set a node to %s with %skg.", client:Name(), ore,
		amount)
end)

ix.log.AddType("miningRemove", function(client, position)
	return string.format("%s removed an ore node at %s.", client:Name(),
		position)
end)

ix.log.AddType("miningConfig", function(client, count)
	return string.format("%s saved the mining config - %d ore(s).",
		client:Name(), count)
end, FLAG_WARNING)
