--[[
	The audit: everything one person owns, from a SteamID.

	`/audit <steamid>` or `/audit <name>` answers with every character that
	account has ever made - loaded or not, online or not - and lets somebody
	with the permission read and change them, and open their inventory and
	stash side by side with their own.

	WHY IT READS THE DATABASE RATHER THAN THE LOADED CHARACTERS: because the
	question is nearly always about somebody who is not here. A player reports
	that their caps are gone, or somebody logs off with a stolen suit, and the
	character that matters is a row in `ix_characters` that no `ix.char.loaded`
	entry exists for.

	    ix.char.loaded          what is in memory now
	    the characters table    what exists at all

	so the list comes from the table and everything else works on whichever of
	the two the character happens to be in - `ix.audit.WithCharacter` is the
	one function that hides the difference.

	SUPERADMIN, through `ix.admin.Can(client, "audit")` so a server can hand it
	to a head admin without handing over everything else.
]]

if (not SERVER) then return end

util.AddNetworkString("ixAuditOpen")
util.AddNetworkString("ixAuditRefresh")
util.AddNetworkString("ixAuditSet")
util.AddNetworkString("ixAuditInventory")
util.AddNetworkString("ixAuditShow")
util.AddNetworkString("ixAuditDelete")

ix.audit = ix.audit or {}

if (ix.admin and ix.admin.RegisterPermission) then
	ix.admin.RegisterPermission("audit",
		"Read and change any character, and open their storage", "People")
end

--[[
	Which inventories an auditor has open, so they can be detached again.

	`[client] = {[inventory id] = true}`. An inventory an auditor is receiving
	stays in memory and keeps sending them changes, which is exactly what is
	wanted while the window is open and a leak afterwards.
]]
local watching = {}

--[[
	The items an auditor has been allowed to move, so the permission can be
	taken back. `[client] = {[item id] = true}` - see the note where it is set.
]]
ix.audit.exempt = ix.audit.exempt or {}

--- Give the exemption back. Called when a window closes and on disconnect.
local function Unexempt(client)
	for id in pairs(ix.audit.exempt[client] or {}) do
		local item = ix.item.instances[id]

		if (item) then item.bAllowMultiCharacterInteraction = nil end
	end

	ix.audit.exempt[client] = nil
end

--------------------------------------------------------------------------------
-- Finding
--------------------------------------------------------------------------------

--[[
	Turn what somebody typed into a SteamID64.

	Three things are accepted because all three are what people have to hand: a
	SteamID64 pasted from a ban, a STEAM_0 one out of the console, and the name
	of somebody standing in front of them.
]]
function ix.audit.Resolve(text)
	text = string.Trim(text or "")

	if (text == "") then return nil end

	--- A 17-digit number is already what the database keys on.
	if (string.match(text, "^%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d$")) then
		return text
	end

	if (string.match(text, "^STEAM_%d:%d:%d+$")) then
		return util.SteamIDTo64(text)
	end

	--- A name: their character's, or their Steam one.
	for _, client in player.Iterator() do
		local character = client:GetCharacter()

		if ((character and ix.util.StringMatches(character:GetName(), text))
		or ix.util.StringMatches(client:SteamName(), text)) then
			return client:SteamID64()
		end
	end

	return nil
end

--[[
	A timestamp as something a person reads.

	The column is whatever the database driver hands back - SQLite stores these
	as a string and MySQL as a datetime - so a number is treated as a UNIX time
	and anything else is trimmed and passed through. Both come out as
	`2026-09-08 14:22`, which is the only part anybody reads.
]]
function ix.audit.Time(value)
	if (not value or value == "") then return "never" end

	local number = tonumber(value)

	if (number and number > 100000) then
		return os.date("%Y-%m-%d %H:%M", number)
	end

	--- `2026-09-08 14:22:31.000` and its cousins lose everything after minutes.
	local text = tostring(value)

	return string.sub(text, 1, 16)
end

--[[
	Every character on one account, as rows for the window.

	The query is the same one Helix's own character loading uses, minus the
	character it was looking for - `ix_characters` keyed by `steamid`.
]]
function ix.audit.Characters(steamID64, callback)
	local query = mysql:Select("ix_characters")
		query:Select("id")
		query:Select("name")
		query:Select("description")
		query:Select("faction")
		query:Select("money")
		query:Select("data")
		query:Select("create_time")
		query:Select("last_join_time")
		query:Where("steamid", steamID64)

		--[[
			THIS SCHEMA'S CHARACTERS, and only those.

			`ix_characters` is shared by every schema on a database, and Helix
			DELETES a character by moving it out of the schema rather than
			removing the row - so without this the audit listed characters from
			other gamemodes and, more confusingly, ones the player had deleted.
		]]
		query:Where("schema", Schema.folder)
		query:Callback(function(result)
			local out = {}

			for _, row in ipairs(result or {}) do
				local id = tonumber(row.id)
				local data = util.JSONToTable(row.data or "") or {}
				local loaded = ix.char.loaded[id]

				--[[
					THE LOADED COPY WINS where there is one. A character
					somebody is playing has unsaved changes - the caps they
					picked up a minute ago are in memory and not in the row -
					and an audit that reported the row would be reporting the
					state at their last save.
				]]
				--[[
					A ROW WITH A FACTION THIS SCHEMA NO LONGER HAS CANNOT BE
					LOADED, and that is not a bug in the audit.

					The faction character var carries `FilterValues`, so Helix's
					character query does `WHERE faction IN (...the real ones)`
					and a row naming a faction that has since been removed - or
					one left over from another schema's `citizen` - is skipped
					entirely. The player sees no such character; the table still
					holds it, with whatever it was carrying.

					So the audit shows it and SAYS SO. Hiding it would leave an
					orphan nobody can find, holding an inventory of items, for
					ever - and the audit is the one screen whose whole job is to
					show what the database actually contains.
				]]
				local faction = ix.faction.teams[row.faction]

				out[#out + 1] = {
					id = id,
					name = loaded and loaded:GetName() or row.name,
					description = loaded and loaded:GetDescription()
						or row.description,
					faction = loaded and loaded:GetFaction()
						or (faction and faction.index) or 0,
					factionName = faction and faction.name or row.faction,
					loadable = faction ~= nil,
					money = loaded and loaded:GetMoney()
						or tonumber(row.money) or 0,
					level = loaded and loaded:GetLevel()
						or tonumber(data.level) or 1,
					xp = loaded and loaded:GetXP() or tonumber(data.xp) or 0,
					race = loaded and loaded:GetRace() or data.race or "",
					created = ix.audit.Time(row.create_time),
					seen = ix.audit.Time(row.last_join_time),
					online = loaded ~= nil and IsValid(loaded:GetPlayer()),
					stash = tonumber(data.stash) or 0,

					--[[
						FROM THE LOADED CHARACTER WHERE THERE IS ONE. Implants
						are in the `data` blob, and the blob in the table is
						only as fresh as the last save - so a character who was
						PK'd a minute ago still had one according to the row,
						which is the whole reason the loaded copy wins
						everywhere else in this list.
					]]
					implants = loaded and ix.implants.Count(loaded)
						or table.Count(data.implants or {}),
					banned = data.banned and true or false
				}
			end

			table.sort(out, function(a, b) return a.id < b.id end)

			callback(out, steamID64)
		end)
	query:Execute()
end

--[[
	AN OFFLINE CHARACTER IS A ROW, and this schema does not pretend otherwise.

	`ix.char.Restore` needs a player - it reads `client:SteamID64()` on its
	first line - so there is no supported way to load somebody else's character
	into `ix.char.loaded` and use the ordinary setters on it. Building one by
	hand would mean owning a copy of Helix's character construction, its
	inventory restore and its save, for the sake of writing one number.

	So the audit has two paths and says which is which:

	    loaded    the real character object, every setter, `character:Save()`
	    a row     one `UPDATE`, and the JSON blob read and written whole

	Both are the same to the caller. The window never knows.
]]
function ix.audit.WithCharacter(id, callback)
	local loaded = ix.char.loaded[id]

	if (loaded) then
		callback(loaded, true)

		return
	end

	callback(nil, false)
end

--[[
	Read one character's `data` blob straight out of the table.

	The blob is where a schema keeps everything Helix does not have a column
	for - level, experience, the stash id, implants - so an offline edit to any
	of those is a read, a change and a write of the whole thing.
]]
function ix.audit.ReadData(id, callback)
	local query = mysql:Select("ix_characters")
		query:Select("data")
		query:Where("id", id)
		query:Limit(1)
		query:Callback(function(result)
			local row = istable(result) and result[1]

			callback(row and util.JSONToTable(row.data or "") or nil)
		end)
	query:Execute()
end

function ix.audit.WriteData(id, data)
	local query = mysql:Update("ix_characters")
		query:Update("data", util.TableToJSON(data))
		query:Where("id", id)
	query:Execute()
end

--- Set one plain column on an offline character.
function ix.audit.WriteColumn(id, column, value)
	local query = mysql:Update("ix_characters")
		query:Update(column, value)
		query:Where("id", id)
	query:Execute()
end

--------------------------------------------------------------------------------
-- The window
--------------------------------------------------------------------------------

local function Send(client, steamID64)
	ix.audit.Characters(steamID64, function(characters)
		net.Start("ixAuditOpen")
			net.WriteString(steamID64)
			net.WriteTable(characters)
		net.Send(client)
	end)
end

ix.command.Add("Audit", {
	description = "Read and change every character on one account. Takes a "
		.. "SteamID or the name of somebody online.",
	arguments = {ix.type.text},

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "audit")
	end,

	OnRun = function(self, client, text)
		local steamID64 = ix.audit.Resolve(text)

		if (not steamID64) then
			return "Nobody by that name, and that is not a SteamID."
		end

		ix.log.Add(client, "audit", steamID64)

		Send(client, steamID64)
	end
})

net.Receive("ixAuditRefresh", function(length, client)
	if (not ix.admin.Can(client, "audit")) then return end

	Send(client, net.ReadString())
end)

--------------------------------------------------------------------------------
-- Changing one
--------------------------------------------------------------------------------

--[[
	What may be set, and how to set it.

	A table rather than a chain of ifs, because every one of these is the same
	shape - clean the value, put it on the character, say what happened - and
	the differences are worth being able to read side by side.
]]
--[[
	What may be set.

	Each entry knows how to clean a value and how to apply it to a LOADED
	character and to a ROW - the two halves of `WithCharacter` - because the
	honest difference between them is a `SetMoney` call and an `UPDATE`, and
	hiding that behind one function would mean inventing a character object for
	somebody who is offline.

	`column` is the plain column where there is one; `blob` is a key inside the
	`data` JSON where there is not.
]]
local SETTERS = {
	name = {
		label = "name",
		column = "name",
		Clean = function(value) return string.sub(tostring(value), 1, 70) end,
		Set = function(character, value) character:SetName(value) end
	},

	description = {
		label = "description",
		column = "description",
		Clean = function(value) return string.sub(tostring(value), 1, 500) end,
		Set = function(character, value) character:SetDescription(value) end
	},

	money = {
		label = "caps",
		column = "money",
		Clean = function(value)
			return math.Clamp(math.floor(tonumber(value) or 0), 0, 1000000000)
		end,
		Set = function(character, value) character:SetMoney(value) end
	},

	level = {
		label = "level",
		blob = "level",
		Clean = function(value)
			return math.Clamp(math.floor(tonumber(value) or 1), 1, 1000)
		end,
		Set = function(character, value)
			character:SetLevel(value)

			--[[
				THE XP FLOOR COMES WITH IT, the same rule `sv_pk.lua` states:
				`CheckLevel` walks upwards while the total is enough, so a
				level set without its XP is a level that jumps back on the next
				kill.
			]]
			character:SetXP(ix.leveling.RequiredXP(value))
		end,

		--- The offline half has to write both halves of that rule as well.
		Blob = function(data, value)
			data.level = value
			data.xp = ix.leveling.RequiredXP(value)
		end
	},

	xp = {
		label = "experience",
		blob = "xp",
		Clean = function(value)
			return math.max(math.floor(tonumber(value) or 0), 0)
		end,
		Set = function(character, value) character:SetXP(value) end
	},

	faction = {
		label = "faction",
		column = "faction",
		Clean = function(value)
			local faction = ix.faction.indices[math.floor(tonumber(value) or 0)]

			return faction and faction.uniqueID or nil
		end,

		Set = function(character, uniqueID)
			local faction = ix.faction.teams[uniqueID]

			if (not faction) then return false end

			character:SetFaction(faction.index)

			local owner = character:GetPlayer()

			if (IsValid(owner)) then
				owner:SetTeam(faction.index)

				if (owner:Alive()) then owner:Spawn() end
			end
		end
	}
}

net.Receive("ixAuditSet", function(length, client)
	if (not ix.admin.Can(client, "audit")) then
		ix.log.Add(client, "devTerminalDenied")

		return
	end

	local id = net.ReadUInt(32)
	local key = net.ReadString()
	local value = net.ReadType()

	local setter = SETTERS[key]

	if (not setter) then return end

	local steamID64 = net.ReadString()
	local cleaned = setter.Clean(value)

	if (cleaned == nil) then
		client:Notify("That is not a value that field can take.")

		return
	end

	local function Done(who)
		client:Notify(string.format("%s: %s is now %s.", who, setter.label,
			tostring(cleaned)))

		ix.log.Add(client, "auditSet", who, setter.label, tostring(cleaned))

		Send(client, steamID64)
	end

	ix.audit.WithCharacter(id, function(character)
		--- Loaded: the real setters, and the character saves itself.
		if (character) then
			if (setter.Set(character, cleaned) == false) then
				client:Notify("That is not a value that field can take.")

				return
			end

			character:Save()
			Done(character:GetName())

			return
		end

		--[[
			OFFLINE: the row. A plain column is one UPDATE; anything in the
			`data` blob is read, changed and written whole, because that is
			what a JSON column is.
		]]
		if (setter.column) then
			ix.audit.WriteColumn(id, setter.column, cleaned)
			Done("character " .. id)

			return
		end

		ix.audit.ReadData(id, function(data)
			if (not data) then
				client:Notify("That character is not in the database.")

				return
			end

			if (setter.Blob) then
				setter.Blob(data, cleaned)
			else
				data[setter.blob] = cleaned
			end

			ix.audit.WriteData(id, data)
			Done("character " .. id)
		end)
	end)
end)

--------------------------------------------------------------------------------
-- Their things
--------------------------------------------------------------------------------

--[[
	Open somebody's inventory or stash next to your own.

	THE AUDITOR IS ADDED AS A RECEIVER, which is what makes the panel work at
	all: an inventory only networks its contents to the people it is expecting,
	and the owner is usually not even here.

	Items move between the two panels through Helix's own inventory transfer,
	so nothing here has to know what moving an item means - which is also why
	the auditor's own inventory is opened alongside rather than a list of
	buttons being invented.
]]
--[[
	DELETE A CHARACTER, ROW AND ALL.

	The audit is where an unloadable orphan is found, so it is where one should
	be got rid of - otherwise the only way is a database client.

	Helix's own delete is copied rather than called: its `ixCharacterDelete`
	receiver requires the character to be in `ix.char.loaded` AND to belong to
	the player who sent it, which an orphan is not and does not. The three
	queries are the same three, in the same order, and they are the reason this
	is worth reading twice - an inventory deleted before its items leaves the
	items behind with nothing pointing at them.
]]
net.Receive("ixAuditDelete", function(length, client)
	if (not ix.admin.Can(client, "audit")) then
		ix.log.Add(client, "devTerminalDenied")

		return
	end

	local id = net.ReadUInt(32)
	local steamID64 = net.ReadString()

	--[[
		A LOADED CHARACTER IS SOMEBODY'S. Deleting the row out from under a
		player who is standing in the world with it would leave them holding a
		character that no longer exists - Helix's own delete kicks them back to
		the menu, and reproducing that is more than this needs to do.
	]]
	if (ix.char.loaded[id]) then
		client:Notify("That character is loaded. It can only be deleted while "
			.. "nobody is on it.")

		return
	end

	--- The items first, then their inventories, then the character.
	local query = mysql:Select("ix_inventories")
		query:Select("inventory_id")
		query:Where("character_id", id)
		query:Callback(function(result)
			for _, row in ipairs(result or {}) do
				local itemQuery = mysql:Delete("ix_items")
					itemQuery:Where("inventory_id", row.inventory_id)
				itemQuery:Execute()

				ix.item.inventories[tonumber(row.inventory_id)] = nil
			end

			local invQuery = mysql:Delete("ix_inventories")
				invQuery:Where("character_id", id)
			invQuery:Execute()

			local charQuery = mysql:Delete("ix_characters")
				charQuery:Where("id", id)
			charQuery:Execute()

			client:Notify("Character " .. id .. " and everything it held are "
				.. "gone.")

			ix.log.Add(client, "auditDelete", id)

			timer.Simple(0.5, function()
				if (IsValid(client)) then Send(client, steamID64) end
			end)
		end)
	query:Execute()
end)

net.Receive("ixAuditInventory", function(length, client)
	if (not ix.admin.Can(client, "audit")) then return end

	local id = net.ReadUInt(32)
	local bStash = net.ReadBool()

	local function Show(inventory, who)
		if (not inventory) then
			client:Notify("They have no storage of that kind.")

			return
		end

		inventory:AddReceiver(client)
		inventory:Sync(client)

		watching[client] = watching[client] or {}
		watching[client][inventory:GetID()] = true

		--[[
			HELIX REFUSES TO MOVE ONE CHARACTER'S ITEMS WITH ANOTHER, and that
			rule is right for everybody except an auditor.

			`Inventory:Add` checks, on every transfer:

			    item:GetPlayerID() == client:SteamID64()
			    and item:GetCharacterID() != client:GetCharacter():GetID()
			        -> "itemOwned"

			which is what stops somebody shuttling gear between their own
			characters. Auditing your own account trips it on every item, and
			auditing anybody else's trips it on nothing - so the symptom is a
			refusal that looks random until you notice whose account it was.

			`bAllowMultiCharacterInteraction` is the flag that rule already
			respects. It is set on the INSTANCES in this inventory, remembered,
			and taken off again when the window closes - so the exemption lasts
			exactly as long as the audit.
		]]
		ix.audit.exempt[client] = ix.audit.exempt[client] or {}

		for item in ix.inventory.Each(inventory) do
			item.bAllowMultiCharacterInteraction = true
			ix.audit.exempt[client][item:GetID()] = true
		end

		net.Start("ixAuditShow")
			net.WriteUInt(inventory:GetID(), 32)
			net.WriteBool(bStash)
			net.WriteString(who)
		net.Send(client)

		ix.log.Add(client, "auditOpen", who,
			bStash and "stash" or "inventory")
	end

	ix.audit.WithCharacter(id, function(character)
		if (character) then
			if (bStash) then
				ix.stash.For(character, function(inventory)
					Show(inventory, character:GetName())
				end)

				return
			end

			Show(character:GetInventory(), character:GetName())

			return
		end

		--[[
			OFFLINE, and this is the part that makes the audit worth having.

			An inventory is a row in `ix_inventories` keyed by character, and
			`ix.inventory.Restore` loads one by id with no player anywhere near
			it - so somebody's bag can be opened, emptied and refilled while
			they are asleep. The STASH id is in the character's data blob; the
			main inventory is whichever row belongs to them.
		]]
		local function Restore(invID, width, height)
			local existing = ix.inventory.Get(invID)

			if (existing) then
				Show(existing, "character " .. id)

				return
			end

			ix.inventory.Restore(invID, width, height, function(inventory)
				Show(inventory, "character " .. id)
			end)
		end

		if (bStash) then
			ix.audit.ReadData(id, function(data)
				local invID = tonumber((data or {}).stash) or 0

				if (invID <= 0) then
					client:Notify("They have never opened a stash.")

					return
				end

				local width, height = ix.stash.Size()

				Restore(invID, width, height)
			end)

			return
		end

		local query = mysql:Select("ix_inventories")
			query:Select("inventory_id")
			query:Select("inventory_type")
			query:Where("character_id", id)
			query:Limit(1)
			query:Callback(function(result)
				local row = istable(result) and result[1]

				if (not row) then
					client:Notify("That character has no inventory row.")

					return
				end

				local width = ix.config.Get("inventoryWidth", 6)
				local height = ix.config.Get("inventoryHeight", 4)
				local kind = row.inventory_type
					and ix.item.inventoryTypes[row.inventory_type]

				if (kind) then
					width, height = kind.w, kind.h
				end

				Restore(tonumber(row.inventory_id), width, height)
			end)
		query:Execute()
	end)
end)

--[[
	Stop receiving one. Sent when the window closes.

	Left out, an auditor keeps getting every change to a stash on the other
	side of the map for the rest of the session - and the inventory stays in
	memory holding the whole thing open.
]]
net.Receive("ixAuditShow", function(length, client)
	local id = net.ReadUInt(32)
	local inventory = ix.inventory.Get(id)

	if (not inventory or not watching[client] or not watching[client][id]) then
		return
	end

	inventory:RemoveReceiver(client)
	watching[client][id] = nil

	Unexempt(client)
end)

hook.Add("PlayerDisconnected", "ixAudit", function(client)
	for id in pairs(watching[client] or {}) do
		local inventory = ix.inventory.Get(id)

		if (inventory) then inventory:RemoveReceiver(client) end
	end

	watching[client] = nil

	Unexempt(client)
end)

ix.log.AddType("audit", function(client, steamID)
	return string.format("%s audited %s.", client:Name(), steamID)
end, FLAG_WARNING)

ix.log.AddType("auditSet", function(client, who, field, value)
	return string.format("%s set %s's %s to %s.", client:Name(), who, field,
		value)
end, FLAG_DANGER)

ix.log.AddType("auditDelete", function(client, id)
	return string.format("%s DELETED character %s and everything it held.",
		client:Name(), id)
end, FLAG_DANGER)

ix.log.AddType("auditOpen", function(client, who, what)
	return string.format("%s opened %s's %s.", client:Name(), who, what)
end, FLAG_DANGER)
