--[[
	A faction's own record of what its people did with its shop and its
	storage - so somebody doing something sus in their own faction can be
	found by their own faction, without a staff member reading the admin
	log for them.

	Two kinds, `shop` and `storage`, written from the places that already
	log to staff (`sv_shop.lua`, and the item-transfer hook below for
	faction storages), kept per faction in `ix.data` (key `factionlogs`, at
	most `KEEP` lines each), and read back through a search box by any
	member of that faction and nobody else. The window is
	`derma/cl_factionlogs.lua`, reached from a magnifier on the shop and on
	an open faction storage.
]]

if (not SERVER) then return end

ix.factionlog = ix.factionlog or {}
ix.factionlog.logs = ix.factionlog.logs or {}

util.AddNetworkString("ixFactionLogAsk")
util.AddNetworkString("ixFactionLog")

local KEY = "factionlogs"
local KEEP = 400
local loaded = false

function ix.factionlog.Load()
	if (loaded) then return end

	ix.factionlog.logs = ix.data.Get(KEY, {}, false, true) or {}
	loaded = true
end

hook.Add("LoadData", "ixFactionLog", ix.factionlog.Load)
hook.Add("PostLoadData", "ixFactionLog", ix.factionlog.Load)
timer.Simple(10, ix.factionlog.Load)

--- Written a few seconds after the last change, not on every line.
local function Save()
	if (not loaded) then return end

	timer.Create("ixFactionLogSave", 5, 1, function()
		ix.data.Set(KEY, ix.factionlog.logs, false, true)
	end)
end

--- One line for one faction. `faction` is the faction's uniqueID.
function ix.factionlog.Add(faction, kind, text)
	if (not isstring(faction) or not ix.faction.teams[faction]) then return end

	local list = ix.factionlog.logs[faction] or {}

	table.insert(list, 1, {time = os.time(), kind = kind, text = text})

	while (#list > KEEP) do table.remove(list) end

	ix.factionlog.logs[faction] = list

	Save()
end

--- The lines a member may read: their own faction's, of one kind, matching.
function ix.factionlog.Rows(client, kind, search, page)
	local character = client:GetCharacter()
	local faction = character and ix.faction.indices[character:GetFaction()]

	if (not faction) then return {} end

	search = string.lower(string.Trim(search or ""))

	local out = {}
	--- A page at a time, newest first; see `sv_adminlog.lua`.
	local skip = math.max(0, math.floor(tonumber(page) or 0)) * 200
	local matched = 0

	for _, entry in ipairs(ix.factionlog.logs[faction.uniqueID] or {}) do
		if (kind ~= "" and entry.kind ~= kind) then continue end

		if (search ~= "" and not string.find(string.lower(entry.text or ""), search,
			1, true)) then
			continue
		end

		matched = matched + 1

		if (matched <= skip) then continue end
		if (#out < 200) then out[#out + 1] = entry end
	end

	return out, matched > skip + 200, matched
end

net.Receive("ixFactionLogAsk", function(_, client)
	if ((client.ixFactionLogNext or 0) > CurTime()) then return end

	client.ixFactionLogNext = CurTime() + 0.3

	local kind = net.ReadString()
	local search = net.ReadString()
	local page = net.ReadUInt(8)
	local rows, more, total = ix.factionlog.Rows(client, kind, search, page)

	net.Start("ixFactionLog")
		net.WriteString(kind)
		net.WriteTable(rows)
		net.WriteBool(more)
		net.WriteUInt(page, 8)
		net.WriteUInt(math.min(total or 0, 4294967295), 32)
	net.Send(client)
end)

--------------------------------------------------------------------------------
-- Faction storage, in and out
--------------------------------------------------------------------------------

local function Storage(inventory)
	local id = inventory and inventory.vars and inventory.vars.factionStorage

	return id and ix.factionStorage and ix.factionStorage.Get(id) or nil
end

--[[
	Every item that crosses into or out of a faction storage. `OnItemTransferred`
	is the one hook that fires for a drag between two inventories; who did it
	is the item's `player` while the transfer runs.
]]
hook.Add("OnItemTransferred", "ixFactionLog", function(item, from, to)
	local before, after = Storage(from), Storage(to)

	if (not before and not after) then return end
	if (before == after) then return end

	local client = item.player or (item.GetOwner and item:GetOwner())
	local who = IsValid(client) and client:Name() or "Somebody"
	local name = item.GetName and item:GetName() or item.name or item.uniqueID

	if (after) then
		ix.factionlog.Add(after.faction, "storage", string.format(
			"%s put %s into %s", who, name, after.name or "a storage"))
	end

	if (before) then
		ix.factionlog.Add(before.faction, "storage", string.format(
			"%s took %s out of %s", who, name, before.name or "a storage"))
	end
end)
