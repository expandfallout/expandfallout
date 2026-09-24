--[[
	The faction management menu, server side.

	`/fm` for your own faction, `/afm` for any of them. Phoenix's
	`factionmanagement`, which is the window their whole class ladder exists to
	serve: members, and the faction's deployables.

	OFFLINE MEMBERS ARE THE POINT. A lead who can only manage whoever happens
	to be standing in front of them cannot run a faction - somebody joins,
	plays once, and their rank is frozen the moment they log off. So the roster
	is read from the database, and the people who are online are matched onto
	it rather than being the whole of it.

	That is possible only because class is stored in character DATA - see
	`sh_classrank.lua`. Helix does not save class at all, so before that fix
	there was nothing to read.
]]

if (not SERVER) then return end

ix.factionManage = ix.factionManage or {}

util.AddNetworkString("ixFMOpen")
util.AddNetworkString("ixFMMembers")
util.AddNetworkString("ixFMStorages")
util.AddNetworkString("ixFMAction")

--[[
	Everything the menu needs about one character, online or not.

	`class` is a uniqueID rather than an index for the same reason it is stored
	that way: the index means nothing to a client that loaded its class list in
	a different order, and nothing at all for a character who is not here.
]]
local function ClassRank(uniqueID)
	for _, info in ipairs(ix.class.list) do
		if (info.uniqueID == uniqueID) then
			return info.rank or 1, info.name
		end
	end

	return 0, "None"
end

--[[
	Read a faction's whole roster out of the database.

	`data` is a text column holding the character's data table, and the class
	lives in it. Helix stores it as JSON, so it is decoded here rather than
	guessed at - a character with no class in their data has never been given
	one and reads as the faction default, which is what they are.
]]
local function ReadRoster(faction, callback)
	local query = mysql:Select("ix_characters")
		query:Select("id")
		query:Select("name")
		query:Select("steamid")
		query:Select("data")
		query:Where("schema", Schema.folder)
		query:Where("faction", faction)

		query:Callback(function(result)
			local out, seen = {}, {}
			local index = ix.faction.teams[faction]
			index = index and index.index

			local function Add(id, name, class, live, data)
				if (seen[id]) then return end

				seen[id] = true

				local rank, className = ClassRank(class)

				--[[
					KARMA COMES FROM WHEREVER THE CHARACTER DID.

					A loaded character has it in memory and an unloaded one has
					it in the `data` column that was read for the class - both
					are the same table, so this is free either way and the
					roster shows everybody rather than only whoever happens to
					be online.
				]]
				local karma = live and {ix.karma.Of(live)}
					or (istable(data) and data.karma) or {0, 0}

				out[#out + 1] = {
					id = id,
					name = name,
					class = class,
					className = className,
					rank = rank,
					good = math.max(math.floor(tonumber(karma[1]) or 0), 0),
					bad = math.max(math.floor(tonumber(karma[2]) or 0), 0),
					online = live ~= nil and IsValid(live:GetPlayer())
				}
			end

			--[[
				LOADED CHARACTERS FIRST, AND FROM MEMORY.

				The database row is what was last SAVED, and a character is
				saved on disconnect, on the autosave interval, and when
				something explicitly asks. Somebody who joined the faction two
				minutes ago and is still standing there may not have been
				written yet - so a roster read only from the database showed
				whoever had been saved and nobody else, which in practice was
				the person who had been playing longest.

				Memory is authoritative for anybody loaded. The query below
				fills in everyone who is not.
			]]
			for id, character in pairs(ix.char.loaded) do
				if (character:GetFaction() ~= index) then continue end

				local info = ix.class.list[character:GetClass()]

				Add(id, character:GetName(), info and info.uniqueID, character)
			end

			for _, row in ipairs(result or {}) do
				local id = tonumber(row.id)

				if (not id) then continue end

				local data = row.data and util.JSONToTable(row.data) or {}

				Add(id, row.name, data and data.class, nil, data)
			end

			--[[
				Highest rank first, then by name. A roster is read to find
				somebody to promote or to check who is in charge, and both
				questions are answered by rank order.
			]]
			table.sort(out, function(a, b)
				if (a.rank ~= b.rank) then return a.rank > b.rank end

				return a.name < b.name
			end)

			callback(out)
		end)
	query:Execute()
end

--[[
	The faction this player is allowed to be looking at.

	SUPERADMIN, NOT ADMIN. `/afm` is every roster on the server, every rank in
	them and every faction's property, and it bypasses the rank rule that
	governs everyone else - so it sits at the same level of trust as destroying
	a faction storage, not at the level of spawning a prop.

	The answer is computed here rather than taken from the message, so a client
	asking about somebody else's faction simply cannot get one.
]]
local function ResolveFaction(client, requested, bWantAdmin)
	--[[
		WHICH FACTION AND WHICH POWERS ARE TWO QUESTIONS.

		The first version answered both from one thing - "did they name a
		faction" - so `/afm` with no argument fell back to your own faction
		WITHOUT admin rights, which is just `/fm` with a different name. And
		`/fm` while standing in your own faction would have been indisplace-
		able from `/afm` on it.

		So the window says which one it is, and this verifies it. `bWantAdmin`
		grants nothing on its own; `IsSuperAdmin` is what decides.
	]]
	local admin = bWantAdmin == true and client:IsSuperAdmin()

	if (requested and requested ~= "" and admin
	and ix.faction.teams[requested]) then
		return requested, true
	end

	local character = client:GetCharacter()
	local faction = character and ix.faction.indices[character:GetFaction()]

	if (faction) then
		return faction.uniqueID, admin
	end

	--[[
		A superadmin with no character faction still gets a window: the first
		faction alphabetically, and the column to move off it. Refusing them
		would mean `/afm` only worked while you happened to have a character.
	]]
	if (admin) then
		local names = {}

		for uniqueID in pairs(ix.faction.teams) do
			names[#names + 1] = uniqueID
		end

		table.sort(names)

		return names[1], true
	end

	return nil, false
end

local function SendMembers(client, faction, bAdmin)
	ReadRoster(faction, function(members)
		if (not IsValid(client)) then return end

		net.Start("ixFMMembers")
			net.WriteString(faction)
			net.WriteBool(bAdmin)
			net.WriteUInt(#members, 16)

			for _, member in ipairs(members) do
				net.WriteUInt(member.id, 32)
				net.WriteString(member.name or "")
				net.WriteString(member.class or "")
				net.WriteUInt(math.Clamp(member.rank, 0, 4), 3)
				net.WriteBool(member.online)

				--- Their karma, so the roster can say what each of them is.
				net.WriteUInt(math.Clamp(member.good or 0, 0, 2000000000), 32)
				net.WriteUInt(math.Clamp(member.bad or 0, 0, 2000000000), 32)
			end
		net.Send(client)
	end)
end

function ix.factionManage.SendStorages(client, faction)
	local records = ix.factionStorage.GetFaction(faction)

	net.Start("ixFMStorages")
		net.WriteString(faction)
		net.WriteUInt(#records, 8)

		for _, record in ipairs(records) do
			net.WriteUInt(record.id, 16)
			net.WriteString(record.name or "Faction Storage")
			net.WriteUInt(record.width or 4, 6)
			net.WriteUInt(record.height or 4, 6)
			net.WriteUInt(math.Clamp(record.minRank or 1, 1, 4), 3)
			net.WriteBool(record.placed == true)
			net.WriteBool(record.map == game.GetMap())
		end
	net.Send(client)
end

function ix.factionManage.Send(client, requested, bWantAdmin)
	local faction, bAdmin = ResolveFaction(client, requested, bWantAdmin)

	if (not faction) then
		client:Notify("You are not in a faction.")

		return
	end

	net.Start("ixFMOpen")
		net.WriteString(faction)
		net.WriteBool(bAdmin)
	net.Send(client)

	SendMembers(client, faction, bAdmin)
	ix.factionManage.SendStorages(client, faction)
end

net.Receive("ixFMOpen", function(length, client)
	--[[
		Sent by the faction column when a superadmin picks a different one, so
		it carries the admin flag the command opened with. Verified again, as
		everything from a client is.
	]]
	ix.factionManage.Send(client, net.ReadString(), net.ReadBool())
end)

--------------------------------------------------------------------------------
-- Acting on somebody
--------------------------------------------------------------------------------

--[[
	Whether this player may act on that character.

	THE SAME RULE AS THE CONTEXT MENU, and it is deliberately strict: you may
	act on somebody of a LOWER rank than your own. Not equal - two officers
	cannot demote each other - and never yourself, which falls out of the same
	comparison rather than needing to be said.

	A superadmin using `/afm` is exempt: they are not in the faction and have
	no rank in it to compare against.
]]
local function CanAct(client, faction, targetRank, bAdmin)
	if (bAdmin and client:IsSuperAdmin()) then return true end

	local character = client:GetCharacter()
	local own = character and ix.faction.indices[character:GetFaction()]

	if (not own or own.uniqueID ~= faction) then
		return false, "That is not your faction."
	end

	local info = ix.class.list[character:GetClass()]
	local rank = info and (info.rank or 1) or 0

	if (rank <= targetRank) then
		return false, "You can only manage people below your own rank."
	end

	return true, nil, rank
end

--[[
	One handler for rename, kick and setclass.

	They differ only in what they do at the end - every check before that is
	identical, and three copies of it is three places for the rule to drift.
]]
net.Receive("ixFMAction", function(length, client)
	local action = net.ReadString()
	local faction = net.ReadString()
	local charID = net.ReadUInt(32)
	local value = net.ReadString()
	local bWantAdmin = net.ReadBool()

	local resolved, bAdmin = ResolveFaction(client, faction, bWantAdmin)

	if (not resolved or resolved ~= faction) then
		client:Notify("That is not your faction.")

		return
	end

	--[[
		The target is loaded from the database if they are not online.
		`ix.char.loaded` holds everybody with a live character; anybody else
		has to be read, changed and written back.
	]]
	local target = ix.char.loaded[charID]

	if (not target) then
		client:Notify("That character is not loaded. They have to log in once "
			.. "since the last restart to be managed.")

		return
	end

	if (target:GetFaction() ~= (ix.faction.teams[faction]
	and ix.faction.teams[faction].index)) then
		client:Notify("They are not in that faction any more.")

		return
	end

	local info = ix.class.list[target:GetClass()]
	local targetRank = info and (info.rank or 1) or 0

	local ok, reason, myRank = CanAct(client, faction, targetRank, bAdmin)

	if (not ok) then
		client:Notify(reason)

		return
	end

	local targetPlayer = target:GetPlayer()

	if (action == "rename") then
		value = string.Trim(value)

		if (#value < 2 or #value > 70) then
			client:Notify("A name has to be between 2 and 70 characters.")

			return
		end

		local old = target:GetName()

		target:SetName(value)
		target:Save()

		client:Notify(old .. " is now " .. value .. ".")

		if (IsValid(targetPlayer)) then
			targetPlayer:Notify("Your name is now " .. value .. ".")
		end

		ix.log.Add(client, "fmRename", old, value)
	elseif (action == "kick") then
		local home = ix.factionmgmt.GetHomeFaction(target)

		if (not home) then return end

		--[[
			The same transfer the context menu uses, so a kick from here and a
			kick from there leave a character in exactly the same state.
		]]
		if (IsValid(targetPlayer)) then
			ix.factionmgmt.Transfer(targetPlayer, home)
		else
			target:SetFaction(home.index)
			target:SetClass(0)
			target:Save()
		end

		client:Notify(target:GetName() .. " has been removed.")

		if (IsValid(targetPlayer)) then
			targetPlayer:Notify("You have been removed from your faction.")
		end

		ix.log.Add(client, "fmKick", target:GetName(), faction)
	elseif (action == "setclass") then
		local chosen

		for _, class in ipairs(ix.class.list) do
			if (class.uniqueID == value) then
				chosen = class

				break
			end
		end

		if (not chosen or chosen.faction ~= target:GetFaction()) then
			client:Notify("That class is not theirs to have.")

			return
		end

		--[[
			You cannot hand out your own rank or above. An admin may, because
			somebody has to be able to appoint the first lead of a faction and
			nobody inside it can.
		]]
		if (not (bAdmin and client:IsSuperAdmin())
		and (chosen.rank or 1) >= (myRank or 0)) then
			client:Notify("You can only hand out ranks below your own.")

			return
		end

		if (not ix.class.CanCharacterTake(target, chosen)) then
			client:Notify(select(2,
				ix.class.CanCharacterTake(target, chosen)) or "They cannot be that.")

			return
		end

		target:SetClass(chosen.index)
		ix.class.Remember(target)
		target:Save()

		client:Notify(target:GetName() .. " is now " .. chosen.name .. ".")

		if (IsValid(targetPlayer)) then
			targetPlayer:Notify("You are now " .. chosen.name .. ".")
		end

		ix.log.Add(client, "fmSetClass", target:GetName(), chosen.name)
	end

	SendMembers(client, faction, bAdmin)
end)

--------------------------------------------------------------------------------
-- Deployables
--------------------------------------------------------------------------------

net.Receive("ixFMStorages", function(length, client)
	local faction = net.ReadString()
	local action = net.ReadString()
	local id = net.ReadUInt(16)
	local bWantAdmin = net.ReadBool()

	local resolved, bAdmin = ResolveFaction(client, faction, bWantAdmin)

	if (not resolved or resolved ~= faction) then return end

	--[[
		`create` is handled before the record lookup, because it is the one
		action with no record to look up yet - and it carries four more fields,
		which have to be read off the message whether or not it is allowed.
	]]
	if (action == "create") then
		local name = net.ReadString()
		local width = net.ReadUInt(6)
		local height = net.ReadUInt(6)
		local minRank = net.ReadUInt(3)

		if (not client:IsSuperAdmin()) then return end

		local record = ix.factionStorage.Create(faction, name, width, height,
			minRank, function()
				if (IsValid(client)) then
					ix.factionManage.SendStorages(client, faction)
				end
			end)

		if (not record) then
			client:Notify("That could not be created.")

			return
		end

		client:Notify(string.format("Created %s, %dx%d. It arrives stowed.",
			record.name, record.width, record.height))

		return
	end

	local record = ix.factionStorage.Get(id)

	if (not record or record.faction ~= faction) then
		client:Notify("No such storage.")

		return
	end

	if (action == "stow") then
		--[[
			`bAdmin` is passed through so a superadmin can move a faction's
			property for them. `CanManage` otherwise asks for Lead OF THAT
			FACTION, which nobody running `/afm` is.
		]]
		local ok, reason = ix.factionStorage.Stow(client, record, bAdmin)

		client:Notify(ok and ("Stowed " .. (record.name or "it") .. ".")
			or reason)
	elseif (action == "destroy") then
		if (not client:IsSuperAdmin()) then return end

		local name = record.name

		ix.factionStorage.Destroy(record)

		client:Notify("Destroyed " .. name .. " and everything in it.")
	elseif (action == "view") then
		--[[
			OPENING ONE WITHOUT DEPLOYING IT.

			A stowed storage's contents exist and nothing in the world points
			at them, so without this the only way to see inside is to make the
			faction put it down first. Admin only, and logged.

			`entity = client` because `ix.storage.CreateContext` ASSERTS a
			valid entity - it uses it for the distance close and the money
			panel, and a player is a shape it already handles. Attaching it to
			the admin means the window closes when they do rather than when
			they walk away from a locker that is not there.
		]]
		if (not client:IsSuperAdmin()) then return end

		--[[
			Through `ResolveInventory`, the same one the entity uses, so
			a storage whose inventory is not in memory is restored rather than
			refused here too.
		]]
		local inventory = ix.inventory.Get(record.invID)

		if (not inventory) then
			ix.factionStorage.ResolveInventory(record, function(restored)
				if (IsValid(client) and restored) then
					client:Notify("Loaded it - open it again.")
				elseif (IsValid(client)) then
					client:Notify("That storage has no inventory.")
				end
			end)

			return
		end

		--[[
			NOT `entity = client`, WHICH IS WHAT PUT A MONEY BAR ON IT.

			`ix.storage.CreateContext` asserts a valid entity, so the first
			version passed the admin - and `ix.storage.Sync` then reads
			`entity:IsPlayer() and entity:GetCharacter()` and sends
			`data.money`, which is what makes the client draw the transfer
			row. So peeking at a storage offered to move the ADMIN'S OWN caps
			into it.

			A deployed storage already has an entity with no `GetMoney`, so it
			is used as it is. A stowed one gets a hidden marker of the same
			class, which has no `GetMoney` either - so no money row, and the
			window still closes properly because it closes on the entity.
		]]
		local entity = record.entity
		local peek

		if (not IsValid(entity)) then
			peek = ents.Create("ix_factionstorage")

			if (not IsValid(peek)) then
				client:Notify("That could not be opened.")

				return
			end

			peek:SetModel(ix.factionStorage.model)
			peek:SetPos(client:GetPos())
			peek:Spawn()

			--- After `Spawn`; see `ix.factionStorage.Spawn` on why.
			peek:SetStorageID(record.id)

			peek:SetNoDraw(true)
			peek:SetNotSolid(true)
			peek:SetMoveType(MOVETYPE_NONE)

			entity = peek
		end

		ix.storage.Open(client, inventory, {
			name = record.name or "Faction Storage",
			entity = entity,
			searchTime = 0,
			bMultipleUsers = true,

			OnPlayerClose = function()
				--[[
					The marker goes with the window. Its `OnRemove` closes the
					storage for anybody still in it, which for a marker is
					only ever the admin who opened it.
				]]
				if (IsValid(peek)) then
					peek:Remove()
				end
			end
		})

		ix.log.Add(client, "factionStorageOpen",
			(record.name or "a storage") .. " (admin, stowed)")

		return
	end

	ix.factionManage.SendStorages(client, faction)
end)

ix.log.AddType("fmRename", function(client, old, new)
	return string.format("%s renamed %s to %s.", client:Name(), old, new)
end, FLAG_WARNING)

ix.log.AddType("fmKick", function(client, name, faction)
	return string.format("%s removed %s from %s.", client:Name(), name, faction)
end, FLAG_WARNING)

ix.log.AddType("fmSetClass", function(client, name, class)
	return string.format("%s set %s to %s.", client:Name(), name, class)
end, FLAG_WARNING)

--[[
	The faction's storages are sent on character load, not only when the menu
	opens.

	The entity's tooltip names the storage and its faction, and it reads the
	same records - so without this, walking up to your own faction's locker
	before ever opening `/fm` shows an unnamed prop.
]]
hook.Add("PlayerLoadedCharacter", "ixFactionStorage", function(client)
	timer.Simple(1, function()
		if (not IsValid(client)) then return end

		local character = client:GetCharacter()
		local faction = character and ix.faction.indices[character:GetFaction()]

		if (faction) then
			ix.factionManage.SendStorages(client, faction.uniqueID)
		end
	end)
end)

--[[
	Every faction, with how many characters and storages each has.

	Only for `/afm`, and only so the window can offer a list instead of asking
	somebody to remember forty-five uniqueIDs. One query and one message rather
	than forty-five of each.
]]
util.AddNetworkString("ixFMFactions")

net.Receive("ixFMFactions", function(length, client)
	if (not client:IsSuperAdmin()) then return end

	local query = mysql:Select("ix_characters")
		query:Select("faction")
		query:Where("schema", Schema.folder)

		query:Callback(function(result)
			if (not IsValid(client)) then return end

			local counts = {}

			for _, row in ipairs(result or {}) do
				counts[row.faction] = (counts[row.faction] or 0) + 1
			end

			local out = {}

			for uniqueID in pairs(ix.faction.teams) do
				out[#out + 1] = {
					id = uniqueID,
					members = counts[uniqueID] or 0,
					storages = #ix.factionStorage.GetFaction(uniqueID)
				}
			end

			net.Start("ixFMFactions")
				net.WriteUInt(#out, 8)

				for _, entry in ipairs(out) do
					net.WriteString(entry.id)
					net.WriteUInt(math.min(entry.members, 65535), 16)
					net.WriteUInt(math.min(entry.storages, 255), 8)
				end
			net.Send(client)
		end)
	query:Execute()
end)

--[[
	What the roster query found, against what is loaded.

	The members list disagreeing with the world is a disagreement between the
	database and memory, and printing one of them cannot show it - the same
	shape of bug as the stealth field, and the same answer: print both.
]]
concommand.Add("fo_faction_roster", function(client, _, arguments)
	if (not IsValid(client) or not client:IsAdmin()) then return end

	local faction = string.lower(arguments[1] or "")

	if (faction == "") then
		local character = client:GetCharacter()
		local own = character and ix.faction.indices[character:GetFaction()]

		faction = own and own.uniqueID or ""
	end

	local team = ix.faction.teams[faction]

	if (not team) then
		client:ChatPrint("No such faction: '" .. faction .. "'")

		return
	end

	client:ChatPrint("[loaded in memory]")

	local loaded = 0

	for id, character in pairs(ix.char.loaded) do
		if (character:GetFaction() ~= team.index) then continue end

		loaded = loaded + 1

		client:ChatPrint(string.format("  %d  %s  online=%s", id,
			character:GetName(), tostring(IsValid(character:GetPlayer()))))
	end

	if (loaded == 0) then client:ChatPrint("  none") end

	local query = mysql:Select("ix_characters")
		query:Select("id")
		query:Select("name")
		query:Select("faction")
		query:Where("schema", Schema.folder)

		query:Callback(function(result)
			if (not IsValid(client)) then return end

			client:ChatPrint(string.format(
				"[database] schema='%s', %d character(s) total",
				Schema.folder, #(result or {})))

			local matched = 0

			for _, row in ipairs(result or {}) do
				if (row.faction == faction) then
					matched = matched + 1

					client:ChatPrint(string.format("  %s  %s", row.id, row.name))
				end
			end

			client:ChatPrint(string.format(
				"  %d row(s) with faction='%s'", matched, faction))
		end)
	query:Execute()
end)

--[[
	Moving somebody between factions, by hand.

	REGISTERED HERE BECAUSE `sh_commands.lua` CANNOT. `ix.log.AddType` lives
	inside `if (SERVER)` in Helix's `sh_log.lua`, so calling it from a shared
	file is a nil call on the client that takes the whole schema down with it -
	which is exactly what happened the first time, and is why every schema log
	type is registered from a `sv_` file next to the system it belongs to.

	`/setfaction` has been writing this entry since it was added and nothing
	had registered the type, so every use printed

	    attempted to add entry to non-existent log type "charSetFaction"

	and the entry went in as Helix's untyped fallback - the arguments run
	together with no sentence around them.
]]
ix.log.AddType("charSetFaction", function(client, name, before, after)
	return string.format("%s moved %s from %s to %s.",
		client and client:Name() or "the console", name, before, after)
end, FLAG_WARNING)
