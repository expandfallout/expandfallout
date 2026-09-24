--[[
	Looting - the server half.

	Owns the data, the container state and the editor's net handlers.

	TWO SEPARATE STORES, and the split matters:

	    lootTables   ix.data, schema-wide, NOT per map
	                 tables are reusable content and should survive a map change

	    lootables    ix.data, PER MAP
	                 a placed container is a position on one map and means
	                 nothing on another

	Both go through `ix.data`, which writes JSON under `data/helix/falloutrp/`.
	Phoenix fetched all of this over HTTP from a hardcoded address, and had the
	CLIENT make the calls - see the header of `sh_loot.lua` for why that is not
	repeated here.

	CONTAINER CONTENTS ARE NOT ITEM INSTANCES. A container holds a plain list
	of `{uniqueID, count}` until something is taken out of it, and only then is
	a real item created in the taker's inventory. Phoenix reached the same
	conclusion with their `FakeInventory`: a hundred placed containers should
	not mean a hundred inventories of database rows sitting unlooked-at.
]]

if (not SERVER) then return end

util.AddNetworkString("ixLootOpen")
util.AddNetworkString("ixLootTake")
util.AddNetworkString("ixLootClose")
util.AddNetworkString("ixLootSync")
util.AddNetworkString("ixLootSaveTable")
util.AddNetworkString("ixLootDeleteTable")
util.AddNetworkString("ixLootPlace")
util.AddNetworkString("ixLootConfigure")

--[[
	Loading is deferred to InitPostEntity because placing a container spawns an
	entity, which needs a world to spawn into.
]]
--[[
	A LOAD MUST HAPPEN BEFORE ANY SAVE.

	This pair used to have no relationship, and the failure that produces is
	total and silent: if the load does not run - a hook that never fires, an
	error earlier in the file, a timer that is cancelled - then `ix.loot.tables`
	is still the empty table it was initialised as, and the next save writes
	that empty table over a file full of work.

	It is the same fault as the one that made a cleanup erase every placed
	container, and the same fix: a save is refused until the thing it would
	overwrite has actually been read. Losing a session's edits is recoverable.
	Overwriting the file is not.
]]
ix.loot.loadedTables = ix.loot.loadedTables or false
ix.loot.loadedPlaced = ix.loot.loadedPlaced or false

function ix.loot.Load()
	ix.loot.tables = ix.data.Get("lootTables", {}, false, true) or {}

	--[[
		Normalised on the way in, so a table saved before modes existed is
		upgraded the first time it is loaded rather than needing a migration
		pass over the file.
	]]
	for _, data in pairs(ix.loot.tables) do
		ix.loot.Normalise(data)
	end

	ix.loot.loadedTables = true

	--[[
		Printed every boot, including zero. "No message" and "no tables" have
		to be distinguishable, or a load that never ran looks exactly like a
		server that has none.
	]]
	MsgC(Color(255, 200, 100), string.format(
		"[falloutrp] loaded %d loot table(s)\n", table.Count(ix.loot.tables)))

	return table.Count(ix.loot.tables)
end

function ix.loot.Save()
	if (not ix.loot.loadedTables) then
		ErrorNoHalt("[falloutrp] refusing to save loot tables - they were " ..
			"never loaded, and saving now would erase the file\n")

		return false
	end

	ix.data.Set("lootTables", ix.loot.tables, false, true)

	return true
end

--- Push the table list to one admin, or to every admin when something changes.
function ix.loot.Sync(client)
	local receivers = {}

	if (IsValid(client)) then
		receivers[1] = client
	else
		for _, target in ipairs(player.GetAll()) do
			if (target:IsAdmin()) then receivers[#receivers + 1] = target end
		end
	end

	if (#receivers == 0) then return end

	net.Start("ixLootSync")
		net.WriteTable(ix.loot.tables)
	net.Send(receivers)
end

--[[
	PLACED CONTAINERS.

	Saved as data rather than as map entities, so they survive a restart and
	can be edited without touching the map. Each is
	`{position, angles, model, lootTable, respawn, width, height}`.
]]
--[[
	THE RECORD LIST IS AUTHORITATIVE, NOT THE ENTITIES.

	`SavePlaced` used to walk `ents.FindByClass("ix_lootable")` and write
	whatever it found. That is wrong in one specific and destructive way: a
	sandbox cleanup, or anything else that mass-removes entities, empties the
	map - and the next save then writes an empty list and deletes every
	container permanently.

	So the list is kept here and the entities are a consequence of it. A
	container disappears from the save only when somebody DELETES it, which is
	what "persistent unless you delete it" has to mean.
]]
ix.loot.placed = ix.loot.placed or {}

function ix.loot.LoadPlaced()
	ix.loot.placed = ix.data.Get("lootables", {}) or {}
	ix.loot.loadedPlaced = true

	local failed = 0

	for _, entry in ipairs(ix.loot.placed) do
		--[[
			Guarded individually. One bad record - a model that no longer
			exists, a position that came back as something other than a vector
			- must not stop the other forty from being restored, and it must
			not leave the list half-applied.
		]]
		local ok = pcall(ix.loot.Spawn, entry, true)

		if (not ok) then failed = failed + 1 end
	end

	MsgC(Color(255, 200, 100), string.format(
		"[falloutrp] restored %d lootable(s)%s\n", #ix.loot.placed,
		failed > 0 and string.format(", %d could not be spawned", failed) or ""))

	return #ix.loot.placed, failed
end

--[[
	Write the list, refreshing the transform of anything still alive.

	A container nudged with the physgun saves where it actually is; one that a
	cleanup removed keeps its last known position and comes back there.
]]
function ix.loot.SavePlaced()
	for _, entry in ipairs(ix.loot.placed) do
		if (IsValid(entry.entity)) then
			entry.position = entry.entity:GetPos()
			entry.angles = entry.entity:GetAngles()
		end
	end

	--[[
		The live entity reference is stripped from the copy that is written -
		it is a runtime link, and `util.TableToJSON` cannot encode an entity.
	]]
	local saved = {}

	for _, entry in ipairs(ix.loot.placed) do
		local copy = table.Copy(entry)

		copy.entity = nil
		saved[#saved + 1] = copy
	end

	if (not ix.loot.loadedPlaced) then
		ErrorNoHalt("[falloutrp] refusing to save lootables - they were never " ..
			"loaded, and saving now would erase every placed container\n")

		return 0
	end

	ix.data.Set("lootables", saved)

	return #saved
end

--[[
	Delete one for good: the entity AND its record.

	The only path that shrinks the list. Everything else - a cleanup, a crash,
	a map change - leaves the record alone so the container comes back.
]]
function ix.loot.RemovePlaced(entity)
	if (not IsValid(entity)) then return false end

	for index, entry in ipairs(ix.loot.placed) do
		if (entry.entity == entity) then
			table.remove(ix.loot.placed, index)
			break
		end
	end

	entity:Remove()
	ix.loot.SavePlaced()

	return true
end

--- Create one container from a data entry.
function ix.loot.Spawn(entry, bNoSave)
	local entity = ents.Create("ix_lootable")

	if (not IsValid(entity)) then return end

	entity:SetPos(entry.position or vector_origin)
	entity:SetAngles(entry.angles or angle_zero)
	entity:SetModel(entry.model or "models/props_junk/wood_crate001a.mdl")
	entity:Spawn()
	entity:Activate()

	entity.ixLootData = entry
	entity:SetLootTable(entry.lootTable or "")

	--[[
		PLACED LOCKED, and locked again after every respawn - which is what
		makes a lock worth putting on a container at all. `lock` is the
		difficulty, 0 for none; see `sh_lockpick.lua`.
	]]
	entity:SetLockLevel(math.Clamp(tonumber(entry.lock) or 0, 0, 5))
	entity:SetLocked((tonumber(entry.lock) or 0) > 0)

	--[[
		The entry IS the record - the same table the list holds - so editing a
		container through `ixLootData` updates what will be saved, with no
		copying back and forth.
	]]
	entry.entity = entity

	if (not bNoSave) then
		ix.loot.placed[#ix.loot.placed + 1] = entry
		ix.loot.SavePlaced()
	end

	return entity
end

--[[
	Fill a container.

	The Luck bonus is extra ROLLS of the same table, not extra copies of one
	item - so a lucky character finds a fuller container rather than three of
	whatever the first draw happened to be. This is the first consumer of
	`ix.special.GetBonusLootCount`, which has had its maths and no caller since
	the SPECIAL work.
]]
function ix.loot.Fill(entity, client)
	local name = entity:GetLootTable()

	if (name == "") then return {} end

	--[[
		The looter's level feeds the `level` mode. Read from the character
		rather than defaulted, so a table gated on level actually gates.
	]]
	local character = IsValid(client) and client:GetCharacter()
	local level = (character and character.GetLevel) and character:GetLevel() or 1

	local contents, unresolved = ix.loot.Roll(name, level)

	if (character and ix.config.Get("lootLuckBonus", true)) then
		local bonus = ix.special.GetBonusLootCount(character)
		local before = #contents

		for _ = 1, bonus do
			for _, result in ipairs(ix.loot.Roll(name, level)) do
				contents[#contents + 1] = result
			end
		end

		--[[
			The sound fires only when the bonus actually PRODUCED something.

			`bonus > 0` alone would ring on every container a lucky character
			opens, including the ones where the extra rolls came up empty -
			which is most of them, since an extra roll is subject to the same
			spawn chance as the first. A cue that fires whether or not anything
			happened teaches players to ignore it.
		]]
		if (#contents > before and IsValid(client)) then
			client:EmitSound(ix.loot.luckSound, 60, 100, 0.7)
		end
	end

	if (#unresolved > 0) then
		--[[
			Reported once per fill rather than swallowed. A container that
			produces nothing because its table names a deleted item looks
			exactly like a container that rolled badly.
		]]
		for _, problem in ipairs(unresolved) do
			ErrorNoHalt(string.format("[falloutrp] loot '%s': %s '%s'\n", name,
				problem.reason, problem.class or problem.table))
		end
	end

	return contents
end

--[[
	Open a container.

	Contents are rolled ONCE and then kept until the respawn timer expires, so
	two players opening the same crate see the same crate. Re-rolling per
	viewer would let one player empty it and the next find it full.
]]
function ix.loot.Open(client, entity)
	if (not IsValid(client) or not IsValid(entity)) then return end

	if (client:GetPos():DistToSqr(entity:GetPos()) > 160 * 160) then return end

	if (not entity.ixContents or entity.ixNextFill and CurTime() > entity.ixNextFill) then
		entity.ixContents = ix.loot.Fill(entity, client)
		entity.ixNextFill = nil

		--[[
			A RESPAWN RELOCKS IT. The loot came back, so whatever was holding
			the lid shut came back with it - otherwise a locked container is a
			lock exactly once, on the day it was placed.

			Not while somebody is standing in it: this runs from `Open`, so the
			relock is left to the sweep in `sv_lockpick.lua` if the container
			is currently picked open.
		]]
		if ((entity:GetLockLevel() or 0) > 0 and not entity.ixLockOpenUntil) then
			entity:SetLocked(true)
		end
		--[[
			A refill makes it new again. Without this a container that respawned
			its loot would still be treated as picked over for the rest of the
			map, which is the opposite of what a respawn means.
		]]
		entity.ixOpened = nil
	end

	--[[
		FRESH OR PICKED OVER - two different sounds.

		Opening something nobody has been through is a find; opening one that
		has already been emptied is just a lid. Freshness belongs to the
		CONTAINER rather than to the player, because the contents are shared -
		the second person to reach a crate is not discovering anything.
	]]
	local fresh = not entity.ixOpened

	entity.ixOpened = true

	entity.ixViewers = entity.ixViewers or {}
	entity.ixViewers[client] = true

	--[[
		XP FOR THE FIND, NOT FOR THE CARRYING.

		This was per item taken, which is the wrong shape twice over: it paid a
		player for clicking rather than for searching, and it paid nothing at
		all for opening a full crate you had no room for. The discovery is the
		thing that happened; what you choose to carry out of it is inventory
		management.

		Once per container, because `fresh` is only true once - and it is the
		container's state, so the second person to reach a crate is not paid
		for somebody else's find.
	]]
	local character = client:GetCharacter()
	local reward = ix.config.Get("xpPerContainer", 5)

	if (fresh and character and reward > 0) then
		--[[
			THE XP CHIME IS THE SOUND OF A FRESH CONTAINER. There is no second
			one, and there was: this used to emit its own `lootFreshSound` here
			and then award the XP muted, which produced two notes and the wrong
			one first.

			The order was the part I had backwards. The XP panel plays its
			sound CLIENT-SIDE the moment the message arrives; a server
			`EmitSound` has to travel. So the panel's chime always landed
			first and the added sound arrived a beat later as a thud - and
			muting "the second sound" silenced the chime and kept the thud.

			So: one sound, played the way Phoenix plays it, from the panel.
		]]
		character:AddXP(reward)
	else
		--[[
			Emitted from the ENTITY so the people near you hear the crate move.
			That is what makes it a world sound rather than a UI one.
		]]
		local sound = ix.loot.GetContainerSound(entity:GetModel(),
			entity.ixLootData and entity.ixLootData.sound)

		if (sound) then
			entity:EmitSound(sound, 65, 100, 0.8)
		end
	end

	net.Start("ixLootOpen")
		net.WriteEntity(entity)
		net.WriteUInt(#entity.ixContents, 8)

		for _, entry in ipairs(entity.ixContents) do
			net.WriteString(entry.uniqueID)
			net.WriteUInt(entry.count or 1, 8)
		end
	net.Send(client)
end

--[[
	Take one thing out.

	The index is re-validated because the client is naming a slot in a list it
	was sent, and that list may have changed since - another player may have
	taken the same item a tick earlier.
]]
net.Receive("ixLootTake", function(length, client)
	local entity = net.ReadEntity()
	local index = net.ReadUInt(8)

	if (not IsValid(entity) or entity:GetClass() ~= "ix_lootable") then return end
	if (not IsValid(client) or not client:Alive()) then return end

	if (client:GetPos():DistToSqr(entity:GetPos()) > 160 * 160) then return end

	local contents = entity.ixContents

	if (not contents or not contents[index]) then return end

	local character = client:GetCharacter()
	local inventory = character and character:GetInventory()

	if (not inventory) then return end

	local entry = contents[index]

	if (not inventory:Add(entry.uniqueID)) then
		client:NotifyLocalized("lootNoRoom")
		return
	end

	--[[
		AFTER the add succeeds, and to the taker alone.

		Which sound depends on what it was - a rifle, a stimpak and a handful
		of caps are three different noises in the games, and Phoenix already
		does this for ammunition in `items/base/sh_clip.lua`. Emitted on the
		player rather than the container so it reads as "this went into my
		pack" rather than as another noise from the crate.
	]]
	local pickup = ix.loot.GetPickupSound(entry.uniqueID)

	if (pickup) then
		client:EmitSound(pickup, 55, 100, 0.75)
	end

	--[[
		Decremented, then removed at zero. `table.remove` would renumber every
		later slot and invalidate the indices every other viewer is holding.
	]]
	entry.count = (entry.count or 1) - 1

	if (entry.count <= 0) then
		contents[index] = {uniqueID = entry.uniqueID, count = 0, taken = true}
	end

	--[[
		The respawn timer starts when a container is first emptied, not when it
		is first opened - a crate somebody looked at and left alone should stay
		as it is.
	]]
	local empty = true

	for _, remaining in ipairs(contents) do
		if ((remaining.count or 0) > 0) then empty = false break end
	end

	if (empty) then
		local respawn = entity.ixLootData and entity.ixLootData.respawn
			or ix.config.Get("lootRespawnTime", 600)

		entity.ixNextFill = respawn > 0 and (CurTime() + respawn) or nil
	end

	--[[
		Every viewer is updated, not just the taker. Two people looting one
		crate is the normal case and each needs to see the other's takings.
	]]
	for viewer in pairs(entity.ixViewers or {}) do
		if (IsValid(viewer)) then
			net.Start("ixLootOpen")
				net.WriteEntity(entity)
				net.WriteUInt(#contents, 8)

				for _, remaining in ipairs(contents) do
					net.WriteString(remaining.uniqueID)
					net.WriteUInt(remaining.count or 0, 8)
				end
			net.Send(viewer)
		end
	end

	ix.log.Add(client, "lootTake", entry.uniqueID)
end)

net.Receive("ixLootClose", function(length, client)
	local entity = net.ReadEntity()

	if (not IsValid(entity) or entity:GetClass() ~= "ix_lootable") then return end

	if (entity.ixViewers) then
		entity.ixViewers[client] = nil
	end

	--[[
		Only when the LAST viewer leaves. Two players at one crate should not
		close it twice, and the lid is shut once whoever was in it has gone.
	]]
	for viewer in pairs(entity.ixViewers or {}) do
		if (IsValid(viewer)) then return end
	end

	local sound = ix.loot.GetContainerSound(entity:GetModel(),
		entity.ixLootData and entity.ixLootData.sound, true)

	if (sound) then
		entity:EmitSound(sound, 65, 100, 0.8)
	end
end)

--[[
	EDITOR HANDLERS.

	Every one re-checks admin. The configurer decides what to offer; these
	decide what happens, and a net message can arrive without the configurer
	ever being opened.
]]
net.Receive("ixLootSaveTable", function(length, client)
	if (not IsValid(client) or not client:IsAdmin()) then return end

	local data = net.ReadTable()
	local original = net.ReadString()

	--[[
		Normalised BEFORE validation, so a table sent from an older client - or
		hand-edited into the data file - is upgraded rather than rejected.
	]]
	ix.loot.Normalise(data)

	local ok, reason = ix.loot.Validate(data)

	if (not ok) then
		client:Notify("Loot table rejected: " .. reason)
		return
	end

	--[[
		A rename is a delete plus an add. Without this, renaming a table would
		leave the old name behind as a duplicate.
	]]
	if (original ~= "" and original ~= data.name) then
		ix.loot.tables[original] = nil
	end

	ix.loot.tables[data.name] = data
	ix.loot.Save()
	ix.loot.Sync()

	client:Notify("Saved loot table: " .. data.name)
	ix.log.Add(client, "lootTableSave", data.name)
end)

net.Receive("ixLootDeleteTable", function(length, client)
	if (not IsValid(client) or not client:IsAdmin()) then return end

	local name = net.ReadString()

	if (not ix.loot.tables[name]) then return end

	ix.loot.tables[name] = nil
	ix.loot.Save()
	ix.loot.Sync()

	client:Notify("Deleted loot table: " .. name)
	ix.log.Add(client, "lootTableDelete", name)
end)

--[[
	Place a container where the admin is looking.
]]
net.Receive("ixLootPlace", function(length, client)
	if (not IsValid(client) or not client:IsAdmin()) then return end

	local name = net.ReadString()
	local model = net.ReadString()

	local trace = client:GetEyeTrace()

	if (not trace.Hit) then return end

	if (model == "" or not util.IsValidModel(model)) then
		model = "models/props_junk/wood_crate001a.mdl"
	end

	--- 0 is no lock. Clamped here rather than trusted - see gotcha 15.
	local lock = math.Clamp(net.ReadUInt(4), 0, 5)

	local entity = ix.loot.Spawn({
		position = trace.HitPos + trace.HitNormal * 8,
		angles = Angle(0, (client:GetPos() - trace.HitPos):Angle().y, 0),
		model = model,
		lootTable = name,
		lock = lock,
		respawn = ix.config.Get("lootRespawnTime", 600)
	})

	if (IsValid(entity)) then
		client:Notify("Placed a lootable.")
		ix.log.Add(client, "lootPlace", name)
	end
end)

--[[
	Re-point an existing container at a different table.
]]
net.Receive("ixLootConfigure", function(length, client)
	if (not IsValid(client) or not client:IsAdmin()) then return end

	local entity = net.ReadEntity()
	local name = net.ReadString()
	local respawn = net.ReadUInt(32)
	local lock = math.Clamp(net.ReadUInt(4), 0, 5)

	if (not IsValid(entity) or entity:GetClass() ~= "ix_lootable") then return end

	entity:SetLootTable(name)

	entity.ixLootData = entity.ixLootData or {}
	entity.ixLootData.lootTable = name
	entity.ixLootData.respawn = respawn
	entity.ixLootData.lock = lock

	--[[
		Setting a lock SHUTS it, and clearing one opens it - the two are the
		same action from the placer's point of view, and an admin who has just
		set a lock expects the container to be locked rather than locked at
		some point in the future.
	]]
	entity:SetLockLevel(lock)
	entity:SetLocked(lock > 0)
	entity.ixLockOpenUntil = nil

	--[[
		Contents are dropped so the next open rolls against the NEW table. A
		container that keeps its old contents after being re-pointed looks like
		the change did not take.
	]]
	entity.ixContents = nil
	entity.ixNextFill = nil

	ix.loot.SavePlaced()

	client:Notify("Lootable set to: " .. (name ~= "" and name or "nothing"))
end)

--[[
	Tables are loaded HERE, at file scope, not from a hook.

	Reading them touches nothing but `ix.data` - no entities, no players, no
	database - so there is no reason to wait, and waiting is what made this
	fragile: a table list that depends on a hook firing is a table list that
	silently empties when it does not.

	The placed containers genuinely do have to wait, because restoring one
	spawns an entity and that needs a world.
]]
ix.loot.Load()

--[[
	`LoadData`, NOT `InitPostEntity`.

	`InitPostEntity` does not reach this schema - the hooks registered
	correctly and never ran, which is why every placed container disappeared
	and the save guard then refused to write over the file. It is the third
	time this session that a listener has been registered after its event, and
	the lesson is the same each time: pick the event the framework promises to
	run, not the one that looks like it happens at the right moment.

	Helix runs `LoadData` itself, from `ix.plugin.RunLoadData`, after the
	database connects and again after a map cleanup - which is precisely when
	persistence should load. `hook.SafeRun("LoadData")` dispatches plain
	listeners, so no plugin table is needed.

	`InitPostEntity` is kept as a second trigger, guarded, for the case where
	it does fire. Whichever arrives first wins and the other does nothing.
]]
local function LoadEverything()
	if (not ix.loot.loadedTables) then
		ix.loot.Load()
	end

	if (ix.loot.loadedPlaced) then return end

	ix.loot.LoadPlaced()
end

hook.Add("LoadData", "ixLoot", LoadEverything)

hook.Add("InitPostEntity", "ixLoot", function()
	timer.Simple(2, LoadEverything)
end)

--[[
	LAST RESORT.

	Two triggers is not belt and braces when both are hooks and this has now
	silently destroyed data twice by not running. A plain timer depends on
	nothing but the server ticking, and it is a no-op in every case where
	either hook did fire, because the load is guarded.

	Ten seconds is late enough that the database has certainly answered and
	early enough that nobody has finished connecting.
]]
timer.Simple(10, LoadEverything)

--[[
	Put back whatever a cleanup removed.

	The records are authoritative and survive a cleanup by design; without this
	they would survive it invisibly, with the map empty until the next restart.
	Only entries whose entity is actually gone are respawned, so this is safe
	to run at any time.
]]
hook.Add("PostCleanupMap", "ixLoot", function()
	if (not ix.loot.loadedPlaced) then return end

	local restored = 0

	for _, entry in ipairs(ix.loot.placed) do
		if (not IsValid(entry.entity)) then
			if (pcall(ix.loot.Spawn, entry, true)) then
				restored = restored + 1
			end
		end
	end

	if (restored > 0) then
		MsgC(Color(255, 200, 100), string.format(
			"[falloutrp] put %d lootable(s) back after a cleanup\n", restored))
	end
end)

hook.Add("PlayerInitialSpawn", "ixLoot", function(client)
	timer.Simple(2, function()
		if (IsValid(client) and client:IsAdmin()) then
			ix.loot.Sync(client)
		end
	end)
end)

hook.Add("PlayerDisconnected", "ixLoot", function(client)
	for _, entity in ipairs(ents.FindByClass("ix_lootable")) do
		if (entity.ixViewers) then entity.ixViewers[client] = nil end
	end
end)

ix.log.AddType("lootTake", function(client, uniqueID)
	return string.format("%s looted %s.", client:Name(), uniqueID)
end, FLAG_NORMAL)

ix.log.AddType("lootTableSave", function(client, name)
	return string.format("%s saved loot table '%s'.", client:Name(), name)
end, FLAG_NORMAL)

ix.log.AddType("lootTableDelete", function(client, name)
	return string.format("%s deleted loot table '%s'.", client:Name(), name)
end, FLAG_DANGER)

ix.log.AddType("lootPlace", function(client, name)
	return string.format("%s placed a lootable using '%s'.", client:Name(), name)
end, FLAG_NORMAL)

--[[
	Opening the configurer.

	A Helix command as well as the concommand, so it appears in `/help` - a
	console command nobody was told about is a tool nobody uses.
]]
util.AddNetworkString("ixLootConfigOpen")

--[[
	What exists and whether it would actually produce anything.

	A loot table that silently yields nothing - because every item it names has
	been renamed or deleted - looks exactly like one that rolled badly, so this
	resolves every entry rather than only counting them.
]]
concommand.Add("fo_loot_report", function(client)
	if (IsValid(client) and not client:IsAdmin()) then return end

	local names = ix.loot.GetNames()

	MsgC(Color(255, 200, 100), string.format(
		"[falloutrp] %d loot table(s)\n", #names))

	local broken = 0

	for _, name in ipairs(names) do
		local lootTable = ix.loot.Get(name)
		local items, refs, missing = 0, 0, 0

		for _, entry in ipairs(lootTable.items or {}) do
			if (entry.table) then
				refs = refs + 1

				if (not ix.loot.Get(entry.table)) then missing = missing + 1 end
			elseif (entry.class) then
				items = items + 1

				if (not ix.item.list[entry.class]) then missing = missing + 1 end
			end
		end

		if (missing > 0) then broken = broken + 1 end

		MsgC(missing > 0 and Color(255, 140, 140) or Color(200, 200, 200),
			string.format("  %-34s %3d%%  %-18s %d item(s), %d ref(s)%s\n",
				string.sub(name, 1, 34), lootTable.spawnChance or 100,
				lootTable.useAll and "all entries" or "one at random",
				items, refs,
				missing > 0 and string.format("  %d MISSING", missing) or ""))
	end

	MsgC(Color(255, 200, 100), string.format(
		"  %d placed lootable(s) on this map, %d table(s) with missing entries\n",
		#ents.FindByClass("ix_lootable"), broken))
end)

--[[
	Written on shutdown as well as on change, because MOVING a container does
	not save on its own and a permanent fixture should come back where it was
	left. A hard crash still loses whatever moved since the last explicit save,
	which is the honest limit of doing this without a periodic write.
]]
hook.Add("ShutDown", "ixLoot", function()
	ix.loot.SavePlaced()
end)

--[[
	The commands for this library live in `sh_commands.lua`.
	They have to be declared on both realms or the chatbox cannot
	see them - see the header there.
]]
