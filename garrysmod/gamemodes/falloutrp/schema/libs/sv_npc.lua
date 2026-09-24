--[[
	NPCs - the half that keeps the presets and runs the spawners.

	See `sh_npc.lua` for what a preset and a spawner are. Kept here:

	    ix.npc.presets[id]       every preset, in ix.data "npcpresets" (global)
	    ix.npc.spawners[id]      this map's spawner records, "npcspawners"
	    ix.npc.pods[id]          the entity standing for each record

	A record is the truth and the pod is its shadow: the pod is made from
	the record on load and the record is written whenever the tool changes
	one, so a restart puts every spawner back where it was.
]]

if (not SERVER) then return end

ix.npc = ix.npc or {}
ix.npc.presets = ix.npc.presets or {}
ix.npc.spawners = ix.npc.spawners or {}
ix.npc.pods = ix.npc.pods or {}

local PRESETS, SPAWNERS = "npcpresets", "npcspawners"
local loaded = false
local nextID = 1

--------------------------------------------------------------------------------
-- Loading and saving
--------------------------------------------------------------------------------

function ix.npc.SavePresets()
	if (not loaded) then return end

	ix.data.Set(PRESETS, ix.npc.presets, false, true)
end

function ix.npc.SaveSpawners()
	if (not loaded) then return end

	ix.data.Set(SPAWNERS, {list = ix.npc.spawners, next = nextID}, false, false)
end

--- Something to start from on a server that has never had a preset.
local function Seed()
	local preset = ix.npc.Default()

	preset.id = "wastelander"
	preset.name = "Wastelander"

	for uniqueID in pairs(ix.npc.weapons) do
		local itemTable = ix.item.list[uniqueID]
		local swep = itemTable and weapons.Get(itemTable.class)

		if (swep and string.lower(swep.HoldType or "") == "pistol") then
			preset.weapons[uniqueID] = true

			break
		end
	end

	ix.npc.presets[preset.id] = preset
end

function ix.npc.Load()
	if (loaded) then return end

	local presets = ix.data.Get(PRESETS, nil, false, true)

	ix.npc.presets = {}

	for id, preset in pairs(presets or {}) do
		local clean = ix.npc.Clean(preset)

		if (clean and clean.id ~= "") then ix.npc.presets[clean.id] = clean end
	end

	local saved = ix.data.Get(SPAWNERS, nil, false, false)

	ix.npc.spawners = {}

	for key, record in pairs(saved and saved.list or {}) do
		local id = tonumber(key)

		if (id and istable(record)) then
			record.id = id
			record.pos = istable(record.pos) and Vector(record.pos.x or record.pos[1] or 0,
				record.pos.y or record.pos[2] or 0, record.pos.z or record.pos[3] or 0)
				or (isvector(record.pos) and record.pos or nil)

			if (record.pos) then ix.npc.spawners[id] = record end
		end
	end

	nextID = tonumber(saved and saved.next) or 1
	loaded = true

	if (table.IsEmpty(ix.npc.presets)) then
		Seed()
		ix.npc.SavePresets()
	end

	for _, record in pairs(ix.npc.spawners) do
		ix.npc.Materialise(record)
	end

	ix.npc.Sync()
end

hook.Add("LoadData", "ixNPC", ix.npc.Load)
hook.Add("PostLoadData", "ixNPC", ix.npc.Load)
timer.Simple(10, ix.npc.Load)

--------------------------------------------------------------------------------
-- Presets, to the clients and from them
--------------------------------------------------------------------------------

function ix.npc.Sync(client)
	net.Start("ixNPCPresets")
		net.WriteTable(ix.npc.presets)

	if (client) then net.Send(client) else net.Broadcast() end
end

hook.Add("PlayerInitialSpawn", "ixNPCPresets", function(client)
	timer.Simple(5, function()
		if (IsValid(client) and loaded) then ix.npc.Sync(client) end
	end)
end)

local function Manages(client)
	return IsValid(client) and ix.admin and ix.admin.Can(client, "npc.manage")
end

--- A stable id from a name: "NCR Trooper" -> "ncr_trooper", made unique.
local function Slug(name)
	local base = string.lower(string.gsub(string.gsub(name, "%s+", "_"), "[^%w_]", ""))

	if (base == "") then base = "preset" end

	local id, n = base, 2

	while (ix.npc.presets[id]) do
		id = base .. "_" .. n
		n = n + 1
	end

	return id
end

net.Receive("ixNPCPresetSave", function(_, client)
	if (not Manages(client)) then return end

	local preset = ix.npc.Clean(net.ReadTable())

	if (not preset) then return end

	if (preset.id == "" or not ix.npc.presets[preset.id]) then
		preset.id = Slug(preset.name)
	end

	ix.npc.presets[preset.id] = preset
	ix.npc.SavePresets()
	ix.npc.Sync()

	client:Notify(string.format("Preset '%s' saved.", preset.name))
	ix.log.Add(client, "npcPreset", "saved", preset.name)
end)

net.Receive("ixNPCPresetDelete", function(_, client)
	if (not Manages(client)) then return end

	local id = net.ReadString()
	local preset = ix.npc.presets[id]

	if (not preset) then return end

	ix.npc.presets[id] = nil
	ix.npc.SavePresets()
	ix.npc.Sync()

	client:Notify(string.format("Preset '%s' deleted.", preset.name))
	ix.log.Add(client, "npcPreset", "deleted", preset.name)
end)

--------------------------------------------------------------------------------
-- Spawner records and their pods
--------------------------------------------------------------------------------

--- The pod that stands for a record; made on load and by the tool.
function ix.npc.Materialise(record)
	local old = ix.npc.pods[record.id]

	if (IsValid(old)) then old:Remove() end

	local pod = ents.Create("ix_npcspawner")

	if (not IsValid(pod)) then return end

	pod:SetPos(record.pos)
	pod:Spawn()
	pod.ixRecord = record.id
	pod:SetNetVar("ixNPCSpawner", record.id)

	ix.npc.pods[record.id] = pod

	ix.npc.Describe(pod)

	return pod
end

--- A sanitised record from the tool's settings.
function ix.npc.CleanRecord(data)
	local out = {}

	out.preset = ix.npc.presets[tostring(data.preset or "")] and tostring(data.preset) or nil
	out.count = math.Clamp(math.Round(tonumber(data.count) or 2), 1, 12)
	out.respawn = math.Clamp(math.Round(tonumber(data.respawn) or 60), 5, 3600)
	out.wake = math.Clamp(math.Round(tonumber(data.wake) or ix.config.Get("npcWakeRadius", 3000)), 300, 15000)
	out.sleep = math.Clamp(math.Round(tonumber(data.sleep) or ix.config.Get("npcSleepRadius", 4500)), out.wake, 20000)
	out.sleepAfter = math.Clamp(math.Round(tonumber(data.sleepAfter) or ix.config.Get("npcSleepAfter", 45)), 5, 900)
	out.radius = math.Clamp(math.Round(tonumber(data.radius) or 128), 16, 1024)

	return out
end

function ix.npc.Create(position, data)
	local record = ix.npc.CleanRecord(data)

	record.id = nextID
	record.pos = position
	nextID = nextID + 1

	ix.npc.spawners[record.id] = record
	ix.npc.SaveSpawners()
	ix.npc.Materialise(record)

	return record
end

function ix.npc.Update(record, data)
	local clean = ix.npc.CleanRecord(data)

	for key, value in pairs(clean) do record[key] = value end

	ix.npc.SaveSpawners()

	local pod = ix.npc.pods[record.id]

	if (IsValid(pod)) then
		ix.npc.Sleep(pod)
		ix.npc.Describe(pod)
	end
end

function ix.npc.Remove(id)
	local pod = ix.npc.pods[id]

	if (IsValid(pod)) then
		ix.npc.Sleep(pod)
		pod:Remove()
	end

	ix.npc.pods[id] = nil
	ix.npc.spawners[id] = nil
	ix.npc.SaveSpawners()
end

--[[
	PUT DOWN BY SOMEBODY, SO UNDONE BY THEM.

	An NPC made with `ents.Create` belongs to nobody as far as GMod is
	concerned, so it never reached the Q menu's undo list and Z did nothing.
	Each one is registered to whoever placed it, under the preset's name so
	the list says what it is, and added to their NPC cleanup as well.

	A spawner is undone with `ix.npc.Remove`, not by deleting its pod. The
	pod is only the visible half: the record is saved to disk, and a pod
	removed on its own comes straight back on the next restart with its
	NPCs. Undoing a spawner that was already taken away some other way
	reports nothing undone rather than pretending.

	Not `SetCreator`: VJ reads the creator's `vj_npc_spawn_guard` setting
	when the NPC finishes spawning and turns it into a sentry that never
	chases, which would quietly undo every other fix to how they fight.
]]
function ix.npc.GiveUndo(client, npc, name)
	if (not IsValid(client) or not IsValid(npc) or not undo) then return end

	undo.Create(name or "NPC")
		undo.AddEntity(npc)
		undo.SetPlayer(client)
		undo.SetCustomUndoText("Undone " .. (name or "NPC"))
	undo.Finish()

	if (cleanup) then cleanup.Add(client, "npcs", npc) end

	--- Prop protection, where the server runs any: it is theirs.
	if (npc.CPPISetOwner) then npc:CPPISetOwner(client) end
end

function ix.npc.GiveSpawnerUndo(client, record, name)
	if (not IsValid(client) or not record or not undo) then return end

	local id = record.id
	local label = (name or "NPC") .. " spawner"

	undo.Create(label)
		undo.AddFunction(function()
			if (not ix.npc.spawners[id]) then return false end

			ix.npc.Remove(id)

			if (IsValid(client)) then ix.log.Add(client, "npcSpawner", "undid", name) end
		end)
		undo.SetPlayer(client)
		undo.SetCustomUndoText("Undone " .. label)
	undo.Finish()
end

--- The spawner nearest a point, within reach.
function ix.npc.Nearest(position, reach)
	local best, bestDistance

	for id, record in pairs(ix.npc.spawners) do
		local distance = record.pos:Distance(position)

		if (distance <= (reach or 128) and (not bestDistance or distance < bestDistance)) then
			best, bestDistance = record, distance
		end
	end

	return best
end

--- What the pod says about itself to the tool's overlay.
function ix.npc.Describe(pod)
	local record = ix.npc.spawners[pod.ixRecord]

	if (not record) then return end

	local preset = record.preset and ix.npc.presets[record.preset]
	local alive = 0

	for _, npc in ipairs(pod.ixNPCs or {}) do
		if (IsValid(npc)) then alive = alive + 1 end
	end

	pod:SetNetVar("ixNPCSpawnerInfo", string.format("%s | %d of %d | %s | wake %d sleep %d",
		preset and preset.name or "NO PRESET", alive, record.count,
		pod.ixAwake and "awake" or "asleep", record.wake, record.sleep))
	pod:SetNetVar("ixNPCSpawnerRadius", record.radius)
end

--------------------------------------------------------------------------------
-- Waking, sleeping, spawning
--------------------------------------------------------------------------------

local function Alive()
	local count = 0

	for _, npc in ipairs(ents.FindByClass("npc_fo_human")) do
		if (IsValid(npc) and npc:Health() > 0) then count = count + 1 end
	end

	return count
end

local function PlayerWithin(position, radius)
	local sq = radius * radius

	for _, client in player.Iterator() do
		if (client:Alive() and client:GetCharacter()
		and client:GetPos():DistToSqr(position) <= sq) then
			return true
		end
	end

	return false
end

--- Somewhere to stand within the pod's radius: on the ground, in the clear.
local function Spot(record)
	for _ = 1, 8 do
		local angle = math.Rand(0, math.pi * 2)
		local distance = math.Rand(0, record.radius)
		local at = record.pos + Vector(math.cos(angle) * distance,
			math.sin(angle) * distance, 32)
		local floor = util.TraceLine({start = at + Vector(0, 0, 64),
			endpos = at - Vector(0, 0, 320), mask = MASK_PLAYERSOLID})

		if (floor.Hit and not floor.StartSolid) then
			local stand = floor.HitPos + Vector(0, 0, 4)
			local room = util.TraceHull({start = stand, endpos = stand,
				mins = Vector(-16, -16, 0), maxs = Vector(16, 16, 72),
				mask = MASK_PLAYERSOLID})

			if (not room.Hit and not room.StartSolid) then return stand end
		end
	end

	return record.pos + Vector(0, 0, 8)
end

--- Everything a body needs: the race's parts and the preset's armour.
local function Spec(preset)
	local race, gender = preset.race, preset.gender
	local ethnicities = ix.races.GetEthnicities(race, gender)
	local hairs = ix.races.GetHairs(race, gender)
	local beards = ix.races.GetBeards(race, gender)
	local armour = {}

	for uniqueID in pairs(preset.armour or {}) do armour[#armour + 1] = uniqueID end

	table.sort(armour)

	local palette = {
		{r = 40, g = 30, b = 22}, {r = 90, g = 60, b = 35}, {r = 150, g = 110, b = 60},
		{r = 200, g = 170, b = 110}, {r = 20, g = 20, b = 20}, {r = 120, g = 120, b = 115}
	}

	return {
		race = race,
		gender = gender,
		ethnicity = ethnicities[math.random(math.max(#ethnicities, 1))] or ethnicities[1],
		hair = (#hairs > 0 and math.random() < 0.7) and math.random(#hairs) or 0,
		beard = (#beards > 0 and gender == "male" and math.random() < 0.35)
			and math.random(#beards) or 0,
		hairColor = palette[math.random(#palette)],
		armour = armour
	}
end

--- Model, health, side, clothes, gun.
function ix.npc.Dress(npc, preset)
	local spec = Spec(preset)
	local recipe = ix.fallout.RecipeFromSpec(spec, npc:GetModel())

	npc.ixPreset = preset
	npc.ixSpec = spec
	npc.ixRecipe = recipe
	npc.ixLabel = preset.name

	npc:SetNetVar("ixRecipe", recipe)
	npc:SetNetVar("ixNPCName", preset.name)
	npc:SetNetVar("ixNPCSide", preset.side)

	npc:SetMaxHealth(preset.health)
	npc:SetHealth(preset.health)

	npc.VJ_NPC_Class = ix.npc.ClassesFor(preset.side)
	npc.Weapon_Accuracy = preset.accuracy

	--- And who that makes it hate, in terms the ENGINE understands.
	for _, client in ipairs(player.GetAll()) do ix.npc.Relate(npc, client) end

	--- Sentry, or something that comes to find you; see `ix.npc.Behaviours`.
	npc.Weapon_MaxDistance, npc.IdleAlwaysWander = ix.npc.Behaviour(preset.behaviour)

	--[[
		And how far it will SHOOT, which is a different question - see
		`npcFireDistance`. Never less than the distance it closes to, or a
		sentry would stand inside its own engagement range holding its fire.
	]]
	npc.ixFireDistance = math.max(ix.config.Get("npcFireDistance", 2500),
		npc.Weapon_MaxDistance or 0)

	--- A sentry stays put even where the NPC would walk itself; see `WalkItself`.
	npc.ixHoldsGround = preset.behaviour == "hold"

	--- The same distance VJ closes to, so `ENT:Chase` and VJ never disagree.
	npc.ixChaseDistance = npc.Weapon_MaxDistance

	--[[
		Tactics, or a raider. See `npcTakeCover`; both of these stop the NPC
		chasing for seconds at a time whenever it is shot at or crowded.
	]]
	local cover = ix.config.Get("npcTakeCover", false)

	npc.CombatDamageResponse = cover
	npc.Weapon_RetreatDistance = cover and 150 or 0

	--[[
		Side-stepping while facing its target, or facing where it walks;
		see `npcShootOnTheMove`. The capability has to follow the flag,
		because VJ grants it at spawn from the same one.
	]]
	local onTheMove = ix.config.Get("npcShootOnTheMove", false)

	npc.Weapon_CanMoveFire = onTheMove
	npc.Weapon_Strafe = onTheMove

	if (onTheMove) then
		npc:CapabilitiesAdd(CAP_MOVE_SHOOT)
	else
		npc:CapabilitiesRemove(CAP_MOVE_SHOOT)
	end

	--[[
		WHAT ITS ARMOUR STOPS. The pieces were worn, drawn and dropped and
		stopped nothing: damage resistance lives in `ScalePlayerDamage`,
		which fires for players and nothing else, so a raider in metal
		armour died as fast as a naked one. These are the very numbers a
		player wearing the same pieces would have, summed once here rather
		than per bullet; the hook further down applies them.
	]]
	local set = {}

	for uniqueID in pairs(preset.armour or {}) do
		local itemTable = ix.item.list[uniqueID]

		if (itemTable and itemTable.bodyType) then set[itemTable.bodyType] = uniqueID end
	end

	npc.ixHeadDR, npc.ixBodyDR = 0, 0

	if (ix.armor and ix.armor.GetSetDR) then
		npc.ixHeadDR, npc.ixBodyDR = ix.armor.GetSetDR(set)
	end

	local choices = {}

	for uniqueID in pairs(preset.weapons or {}) do
		if (ix.npc.weapons[uniqueID]) then choices[#choices + 1] = uniqueID end
	end

	if (#choices > 0) then
		local uniqueID = choices[math.random(#choices)]

		npc.ixWeaponItem = uniqueID
		npc:Give(ix.npc.weapons[uniqueID])
		--- What the client draws in the hand; see `cl_npc.lua`.
		npc:SetNetVar("ixWeaponModel", ix.npc.weaponModels[uniqueID] or "")
	end
end

function ix.npc.Spawn(record, preset, pod)
	if (not ix.config.Get("npcEnabled", true)) then return end
	if (Alive() >= ix.config.Get("npcMaxAlive", 60)) then return end

	local race = ix.races.Get(preset.race)
	local model = race and race.animationModel or "models/phoenix/humans/animations.mdl"
	local npc = ents.Create("npc_fo_human")

	if (not IsValid(npc)) then return end

	npc.Model = {model}
	npc.ixSpawner = pod
	npc.ixRecord = record.id

	npc:SetPos(Spot(record))
	npc:SetAngles(Angle(0, math.random(0, 359), 0))
	npc:Spawn()
	npc:Activate()

	ix.npc.Dress(npc, preset)

	return npc
end

--- A one-off, from a command; no spawner, no respawn.
function ix.npc.SpawnAt(position, preset)
	local record = {id = 0, pos = position, radius = 16, count = 1}

	return ix.npc.Spawn(record, preset, nil)
end

function ix.npc.Sleep(pod)
	for _, npc in ipairs(pod.ixNPCs or {}) do
		if (IsValid(npc)) then npc:Remove() end
	end

	pod.ixNPCs = {}
	pod.ixQueue = {}
	pod.ixAwake = false
	pod.ixSleepAt = nil
end

--[[
	ONCE A SECOND PER POD. A player within the wake radius and the pod's
	NPCs exist; none within the sleep radius for the sleep delay and they
	do not. Dead ones come back after the respawn time, one at a time,
	never past the server's cap.
]]
function ix.npc.Tick(pod)
	local record = ix.npc.spawners[pod.ixRecord]

	if (not record) then return end

	local preset = record.preset and ix.npc.presets[record.preset]

	if (not preset or not ix.config.Get("npcEnabled", true)) then
		if (pod.ixAwake) then ix.npc.Sleep(pod) end

		return
	end

	pod.ixNPCs = pod.ixNPCs or {}
	pod.ixQueue = pod.ixQueue or {}

	if (PlayerWithin(record.pos, record.wake)) then
		if (not pod.ixAwake) then
			pod.ixAwake = true
			pod.ixQueue = {}

			--- Everybody at once on waking, a beat apart.
			for index = 1, record.count do
				pod.ixQueue[index] = CurTime() + (index - 1) * 0.2
			end
		end

		pod.ixSleepAt = nil
	elseif (pod.ixAwake) then
		if (PlayerWithin(record.pos, record.sleep)) then
			pod.ixSleepAt = nil
		else
			pod.ixSleepAt = pod.ixSleepAt or CurTime()

			if (CurTime() - pod.ixSleepAt >= record.sleepAfter) then
				ix.npc.Sleep(pod)
				ix.npc.Describe(pod)

				return
			end
		end
	end

	if (not pod.ixAwake) then return end

	for index = #pod.ixNPCs, 1, -1 do
		if (not IsValid(pod.ixNPCs[index])) then table.remove(pod.ixNPCs, index) end
	end

	--- More than the record wants (a count lowered): the extra go.
	while (#pod.ixNPCs > record.count) do
		local npc = table.remove(pod.ixNPCs)

		if (IsValid(npc)) then npc:Remove() end
	end

	local due = #pod.ixNPCs + #pod.ixQueue

	while (due < record.count) do
		pod.ixQueue[#pod.ixQueue + 1] = CurTime() + record.respawn
		due = due + 1
	end

	for index = #pod.ixQueue, 1, -1 do
		if (pod.ixQueue[index] <= CurTime()) then
			local npc = ix.npc.Spawn(record, preset, pod)

			if (npc) then
				pod.ixNPCs[#pod.ixNPCs + 1] = npc
				table.remove(pod.ixQueue, index)
			end

			break
		end
	end

	ix.npc.Describe(pod)
end

--- The pod is told; the timer starts from the death, not the sweep.
function ix.npc.OnDeath(npc)
	local pod = npc.ixSpawner
	local record = pod and IsValid(pod) and ix.npc.spawners[pod.ixRecord]

	if (record) then
		pod.ixQueue = pod.ixQueue or {}
		pod.ixQueue[#pod.ixQueue + 1] = CurTime() + record.respawn
	end

	--[[
		WHAT IT LEAVES. The gun it carried by one chance, each piece of
		armour by another, and anything else the preset lists by that
		thing's own - caps, ammo, a stimpak, whatever the loot list says.
	]]
	local preset = npc.ixPreset

	if (not preset) then return end

	local drops = {}

	if (npc.ixWeaponItem and math.random(100) <= (preset.dropWeapon or 0)) then
		drops[#drops + 1] = npc.ixWeaponItem
	end

	for _, uniqueID in ipairs(npc.ixSpec and npc.ixSpec.armour or {}) do
		if (math.random(100) <= (preset.dropArmour or 0)) then
			drops[#drops + 1] = uniqueID
		end
	end

	for uniqueID, chance in pairs(preset.loot or {}) do
		if (math.random(100) <= (tonumber(chance) or 0)) then
			drops[#drops + 1] = uniqueID
		end
	end

	for index, uniqueID in ipairs(drops) do
		if (ix.item.list[uniqueID]) then
			ix.item.Spawn(uniqueID, npc:GetPos() + Vector(math.random(-12, 12),
				math.random(-12, 12), 10 + index * 6))
		end
	end
end

--- The body, drawn as the NPC was.
function ix.npc.OnCorpse(npc, corpse)
	if (not IsValid(corpse) or not ix.corpse or not ix.corpse.Adopt) then return end

	ix.corpse.Adopt(corpse, npc.ixRecipe, npc.ixLabel or "Wastelander", false)
end

--- Every pod's NPCs go with the pod when the map cleans up.
hook.Add("PostCleanupMap", "ixNPC", function()
	for _, record in pairs(ix.npc.spawners) do ix.npc.Materialise(record) end
end)

--------------------------------------------------------------------------------
-- Players have a side too
--------------------------------------------------------------------------------

hook.Add("PlayerLoadedCharacter", "ixNPCClasses", function(client)
	client.VJ_NPC_Class = ix.npc.PlayerClasses(client)

	--[[
		A character change can change sides, so every NPC alive is told
		again. See `ix.npc.Relate` for why the engine needs telling at all.
	]]
	for _, npc in ipairs(ents.FindByClass("npc_fo_human")) do
		ix.npc.Relate(npc, client)
	end
end)

--[[
	EVERY NPC THAT MIGHT WALK ITSELF, stepped once a server frame.

	`WalkItself` used to be called from the NPC's own think, which VJ runs
	about fifteen times a second. A position that changes fifteen times a
	second looks exactly like that: the client draws between the positions
	the server sent it, and a server that holds still between steps gives it
	nothing to draw. Once a frame is four or five times as often and a
	quarter the distance each time, which is the difference between walking
	and stuttering. The work per NPC is a couple of traces and only while it
	is actually closing on somebody.

	The table fills itself from the NPC's think, so nothing has to be
	unregistered on death - an invalid entry is dropped the next time round.
]]
ix.npc.walkers = ix.npc.walkers or {}

hook.Add("Think", "ixNPCWalk", function()
	--- Off: nothing here has anything to do. The rest is judged per NPC.
	if (not ix.config.Get("npcWalkWhenStuck", true)) then return end

	for npc in pairs(ix.npc.walkers) do
		if (IsValid(npc)) then
			npc:WalkItself()
		else
			ix.npc.walkers[npc] = nil
		end
	end
end)

--- An NPC's armour resists damage; the numbers are summed in `Dress`.
hook.Add("EntityTakeDamage", "ixNPCArmor", function(target, dmginfo)
	if (not IsValid(target) or target:GetClass() ~= "npc_fo_human") then return end
	if (dmginfo:IsDamageType(DMG_FALL)) then return end

	--[[
		WHERE IT LANDED. An NPC has no `LastHitGroup`, so the hit is placed
		at the nearest known bone to where the damage says it was, exactly
		as a hit on a creature with no hitboxes is placed for a player.
	]]
	local placed = ix.dismember and ix.dismember.Hitgroup
		and ix.dismember.Hitgroup(target, HITGROUP_GENERIC, dmginfo:GetDamagePosition())
		or HITGROUP_GENERIC
	local resistance = (placed == HITGROUP_HEAD and target.ixHeadDR or target.ixBodyDR) or 0

	if (resistance > 0) then
		dmginfo:ScaleDamage(1 - math.Clamp(resistance, 0, 100) / 100)
	end
end)

--- Staff who have turned themselves invisible to NPCs keep it across a respawn.
hook.Add("PlayerSpawn", "ixNPCIgnore", function(client)
	if (client.ixNPCIgnored) then client:AddFlags(FL_NOTARGET) end
end)

--------------------------------------------------------------------------------
-- Commands
--------------------------------------------------------------------------------

--[[
	STAFF THE NPCS CANNOT SEE. Placing a spawner means standing in the
	middle of whatever it spawns, and a raider does not know a toolgun from
	a rifle. `FL_NOTARGET` is the engine's own flag for exactly this and
	every NPC checks it before anything else - VJ's `CheckRelationship`
	returns on it in its first line, and so does the engine's own targeting
	- so this works for NPCs this schema did not write, the Fallout SNPCs
	included. It lasts until it is turned off; a respawn re-applies it.
]]
ix.command.Add("NPCIgnore", {
	description = "Toggle whether NPCs can see you at all.",
	privilege = "Manage NPCs",

	OnCheckAccess = function(self, client)
		return ix.admin and ix.admin.Can(client, "npc.manage") or false
	end,

	OnRun = function(self, client)
		local ignored = not client.ixNPCIgnored

		client.ixNPCIgnored = ignored or nil

		if (ignored) then
			client:AddFlags(FL_NOTARGET)
		else
			client:RemoveFlags(FL_NOTARGET)
		end

		ix.log.Add(client, "npcIgnore", ignored)

		return ignored and "NPCs can no longer see you."
			or "NPCs can see you again."
	end
})

ix.log.AddType("npcIgnore", function(client, ignored)
	return string.format("%s made themselves %s to NPCs.", client:Name(),
		ignored and "invisible" or "visible again")
end, FLAG_WARNING)

--[[
	WHICH NODE GRAPH THE ENGINE CAN SEE, which is not always the one you
	put on the disk.

	A map's own `.ain` can be PACKED INSIDE ITS BSP, and the map's pak is
	added to the front of the filesystem's search path when the map loads -
	so the packed one is handed over first and a file in `maps/graphs/` is
	never read. That is the same precedence that makes Nodegraph Editor
	refuse to edit such a map in place, and it is invisible from in game:
	the file is where the instructions said to put it and nothing uses it.

	This opens the path the ENGINE would open, through the same search
	order, and prints what came back. Its size against the size of the file
	on the disk says which of the two won. The header says whether the
	engine will even accept it: the format number must be 37, and the map
	version it was built for must match the map running, or the engine
	throws it away and rebuilds from whatever `info_node` entities the map
	has, which for most maps is none.
]]
ix.command.Add("NPCNodes", {
	description = "What AI node graph the engine can actually see for this map.",
	privilege = "Manage NPCs",

	OnCheckAccess = function(self, client)
		return ix.admin and ix.admin.Can(client, "npc.manage") or false
	end,

	OnRun = function(self, client)
		local path = "maps/graphs/" .. game.GetMap() .. ".ain"
		local handle = file.Open(path, "rb", "GAME")

		if (not handle) then
			return "The engine cannot see " .. path .. " at all, so this map has "
				.. "no node graph and its NPCs cannot walk anywhere."
		end

		local size = handle:Size()
		local version = handle:ReadLong()
		local mapVersion = handle:ReadLong()

		handle:Close()

		return string.format("%s - %d bytes, format %d, built for map version %d. "
			.. "If that byte count is not the file you copied in, the map's own "
			.. "packed graph is being read instead of yours.",
			path, size, version, mapVersion)
	end
})

--[[
	A MOVEMENT TEST WITH NOTHING ELSE IN IT. "They do not move" can be the
	AI choosing not to, the map having no nodes, or the NPC being unable to
	travel at all, and those look identical from across a room. This asks
	one NPC to walk to where the asker stands, which removes the first of
	the three from the question.
]]
ix.command.Add("NPCWalk", {
	description = "Order the NPC you are looking at to walk to you.",
	privilege = "Manage NPCs",

	OnCheckAccess = function(self, client)
		return ix.admin and ix.admin.Can(client, "npc.manage") or false
	end,

	OnRun = function(self, client)
		local npc = client:GetEyeTrace().Entity

		if (not IsValid(npc) or npc:GetClass() ~= "npc_fo_human") then
			return "Look at one of the NPCs first."
		end

		local goal = client:GetPos()

		--[[
			THE ANSWER IS THE RETURN VALUE. `NavSetGoalPos` builds a route
			with the engine's own pathfinder and says whether it could.
			False means the map's AI nodes do not join this NPC to that
			spot, which is a map problem and not an AI one - and the two
			look identical from across a room, which is why three rounds of
			animation fixes did not move it.
		]]
		local reachable = npc:NavSetGoalPos(goal)

		npc:SetLastPosition(goal)
		npc:SCHEDULE_GOTO_POSITION("TASK_WALK_PATH")

		if (not reachable) then
			return "NO PATH. The engine cannot route from that NPC to where you "
				.. "are standing, so nothing will ever make it walk here. The map "
				.. "needs AI nodes it can use."
		end

		return "Path found, so it can reach you. Watch whether it sets off; if it "
			.. "does not, run fo_npc_report on it."
	end
})

--[[
	HOW FAR THIS MAP WILL ACTUALLY ROUTE, which is not what the `.ain` says.

	`/npcnodes` answers "is there a graph file and will the engine accept
	it". This answers the question that matters, which is whether the
	pathfinder can build a route between two real places - and at what
	distance it stops being able to. Short hops working while long ones fail
	is a graph in disconnected pieces. Nothing working at all is a graph the
	engine never loaded, whatever the file says.

	It moves the NPC, because asking the engine for a route is how you set
	its goal; that is the same bargain `/npcwalk` makes and the reason
	neither of them lives in the read-only report.
]]
ix.command.Add("NPCRoute", {
	description = "Test how far the map's AI nodes will actually route an NPC.",
	privilege = "Manage NPCs",

	OnCheckAccess = function(self, client)
		return ix.admin and ix.admin.Can(client, "npc.manage") or false
	end,

	OnRun = function(self, client)
		local npc = client:GetEyeTrace().Entity

		if (not IsValid(npc) or npc:GetClass() ~= "npc_fo_human") then
			return "Look at one of the NPCs first."
		end

		local from = npc:GetPos()
		local goal = client:GetPos()
		local along = goal - from
		local full = along:Length()

		along:Normalize()

		--[[
			EVERY STEP OF THE WAY, not powers of two. The first version tried
			64, 128, 256, 512 and then jumped straight to the player, so on a
			977-unit test it could not tell a gap at 600 from a player
			standing somewhere the graph does not reach - and it announced
			"disconnected pieces" when the data said neither.
		]]
		local stride = full <= 1024 and 64 or (full <= 3072 and 128 or 256)
		local lastWorked, firstFailed = 0, nil
		local count = 0

		for step = stride, full - 1, stride do
			count = count + 1

			if (count > 32) then break end

			if (npc:NavSetGoalPos(from + along * step)) then
				if (not firstFailed) then lastWorked = step end
			elseif (not firstFailed) then
				firstFailed = step
			end
		end

		local whole = npc:NavSetGoalPos(goal)

		--- What you are standing on, which the graph only knows about if it is the ground.
		local ground = client:GetGroundEntity()
		local standing = (IsValid(ground) and not ground:IsWorld()) and ground:GetClass()
			or (client:IsOnGround() and "the world" or "nothing - you are in the air")

		--- And the floor directly beneath you, in case what you stand on is the problem.
		local floor = util.TraceLine({
			start = goal + Vector(0, 0, 8),
			endpos = goal - Vector(0, 0, 512),
			mask = MASK_NPCSOLID_BRUSHONLY
		})
		local floorRoutes = floor.Hit and npc:NavSetGoalPos(floor.HitPos) or false

		print(string.format("[falloutrp] route probe: %d units to %s, a test every %d",
			math.floor(full), client:Name(), stride))
		print(string.format("  routes cleanly to %d  first refusal %s  your spot %s  the floor under you %s",
			lastWorked, firstFailed and tostring(firstFailed) or "none",
			tostring(whole), tostring(floorRoutes)))
		print(string.format("  you are standing on %s, %.0f units %s the NPC",
			standing, math.abs(goal.z - from.z), goal.z >= from.z and "above" or "below"))

		if (lastWorked == 0 and not whole) then
			return "NOTHING routes, not even the first step. The engine has no usable node "
				.. "graph for this map however good the file looks."
		end

		if (whole) then
			return "The whole route builds, so pathing to you works from there."
		end

		if (firstFailed) then
			return string.format("Routes cleanly to %d units, then refuses at %d. The graph has "
				.. "a gap there: a drop, a fence, a wall, or simply no nodes. See the console.",
				lastWorked, firstFailed)
		end

		if (floorRoutes) then
			return string.format("Every step toward you routes, and so does the floor under you, "
				.. "but not your exact spot. You are standing on %s, which the graph does not "
				.. "know about. NPCs now path to the nearest point they can reach.", standing)
		end

		return "Every step toward you routes, but not the last stretch to where you stand. "
			.. "The graph stops just short of you; NPCs now path as far as it goes and walk the rest."
	end
})

ix.command.Add("NPCPresets", {
	description = "Open the NPC preset editor.",
	privilege = "Manage NPCs",

	OnCheckAccess = function(self, client)
		return Manages(client)
	end,

	OnRun = function(self, client)
		ix.npc.Sync(client)

		net.Start("ixNPCEditor")
		net.Send(client)
	end
})

ix.command.Add("NPCSpawn", {
	description = "Spawn one NPC of a preset where you are looking, with no spawner.",
	privilege = "Manage NPCs",
	arguments = {ix.type.text},

	OnCheckAccess = function(self, client)
		return Manages(client)
	end,

	OnRun = function(self, client, name)
		local preset

		for _, candidate in pairs(ix.npc.presets) do
			if (candidate.id == name or string.lower(candidate.name) == string.lower(name)) then
				preset = candidate
			end
		end

		if (not preset) then return "No preset called '" .. name .. "'." end

		local trace = client:GetEyeTrace()

		if (not trace.Hit) then return "Look at the ground." end

		local npc = ix.npc.SpawnAt(trace.HitPos + Vector(0, 0, 8), preset)

		if (not npc) then return "Nothing spawned: the server is at its NPC cap, or NPCs are off." end

		ix.npc.GiveUndo(client, npc, preset.name)

		return string.format("Spawned a %s.", preset.name)
	end
})

ix.command.Add("NPCClear", {
	description = "Remove every spawner NPC; the spawners wake them again.",
	privilege = "Manage NPCs",

	OnCheckAccess = function(self, client)
		return Manages(client)
	end,

	OnRun = function(self, client)
		local count = 0

		for _, npc in ipairs(ents.FindByClass("npc_fo_human")) do
			npc:Remove()
			count = count + 1
		end

		for _, pod in pairs(ix.npc.pods) do
			if (IsValid(pod)) then ix.npc.Sleep(pod) end
		end

		return string.format("Removed %d NPC(s).", count)
	end
})

ix.log.AddType("npcPreset", function(client, what, name)
	return string.format("%s %s the NPC preset '%s'.", client:Name(), what, name)
end, FLAG_NORMAL)

ix.log.AddType("npcSpawner", function(client, what, preset)
	return string.format("%s %s an NPC spawner (%s).", client:Name(), what, preset or "no preset")
end, FLAG_WARNING)
