--[[
	Doors - storing the extra rules, honouring them, and the world teleports.

	See `sh_doors.lua` for why this is a layer over Helix's door plugin rather
	than a change to it.

	THREE LISTS, ALL PER MAP, ALL KEYED BY `MapCreationID`:

	    doorfactions   who else may use and lock a door
	    doorlinks      where a door sends you
	    doorworldtp    which of the map's own teleports have been deleted

	Loaded from `LoadData` with a save guard, for the reason written at length
	in `sv_points.lua`: `InitPostEntity` never fires in this schema, and a load
	that never ran leaves an empty table that the next save writes to disk.
]]

if (not SERVER) then return end

ix.doors = ix.doors or {}

util.AddNetworkString("ixDoorSync")
util.AddNetworkString("ixDoorPending")
util.AddNetworkString("ixDoorWorld")
util.AddNetworkString("ixDoorRestore")

local FACTION_KEY = "doorfactions"
local LINK_KEY = "doorlinks"
local PROP_KEY = "doorproplinks"
local WORLD_KEY = "doorworldtp"

--- `[mapID] = true` for a map teleport somebody has deleted for good.
ix.doors.deleted = ix.doors.deleted or {}

ix.doors.loaded = false

--------------------------------------------------------------------------------
-- Storage
--------------------------------------------------------------------------------

function ix.doors.Save()
	if (not ix.doors.loaded) then return end

	ix.data.Set(FACTION_KEY, ix.doors.factions)
	ix.data.Set(LINK_KEY, ix.doors.links)
	ix.data.Set(PROP_KEY, ix.doors.propLinks)
	ix.data.Set(WORLD_KEY, ix.doors.deleted)
end

--[[
	JSON has no integer keys, so everything comes back keyed by a string.

	`MapCreationID` is a number and every lookup here uses one, so the table is
	rebuilt with numeric keys on the way in rather than every call site being
	made to guess which it is holding. This is the same trap `sv_points.lua`
	solves the other way round - there the key is opaque and is left alone;
	here it is compared against a number and must be one.
]]
local function Renumber(source)
	local out = {}

	for key, value in pairs(source or {}) do
		out[tonumber(key) or key] = value
	end

	return out
end

function ix.doors.Load()
	if (ix.doors.loaded) then return end

	ix.doors.factions = Renumber(ix.data.Get(FACTION_KEY, {}))
	ix.doors.links = Renumber(ix.data.Get(LINK_KEY, {}))
	ix.doors.propLinks = Renumber(ix.data.Get(PROP_KEY, {}))
	ix.doors.deleted = Renumber(ix.data.Get(WORLD_KEY, {}))
	ix.doors.loaded = true

	for _, link in pairs(ix.doors.propLinks) do
		if (not isvector(link.origin)) then link.origin = Vector(link.origin) end
		if (not isvector(link.position)) then
			link.position = Vector(link.position)
		end

		if (not isangle(link.angles)) then link.angles = Angle(link.angles) end

		ix.doors.nextPropLink = math.max(ix.doors.nextPropLink or 1,
			(tonumber(link.id) or 0) + 1)
	end

	--[[
		The link positions come back as plain tables from JSON, not vectors.
		Converted once here rather than at every use - a `Vector` that is
		actually a table is a fault that only shows up on the first teleport
		after a restart.
	]]
	for _, link in pairs(ix.doors.links) do
		if (not isvector(link.position)) then
			link.position = Vector(link.position)
		end

		if (not isangle(link.angles)) then
			link.angles = Angle(link.angles)
		end
	end

	ix.doors.PurgeWorld()

	--[[
		The props those teleports were on are restored by `sv_permaprop.lua`,
		which loads from the same `LoadData` event - and two listeners on one
		event run in whatever order the table iterated. So the sweep is done
		LATER rather than now: once on `PostLoadData`, which runs after every
		plugin's `LoadData`, and again on a timer that depends on nothing.

		A link with no prop is a teleport on something that was never made
		permanent. It is dropped, which is the whole rule.
	]]
	timer.Simple(1, ix.doors.SweepPropLinks)
	timer.Simple(15, ix.doors.SweepPropLinks)

	MsgC(Color(255, 200, 100), string.format(
		"[falloutrp] %d door faction list(s), %d teleport(s), %d world "
		.. "teleport(s) kept deleted\n", table.Count(ix.doors.factions),
		table.Count(ix.doors.links), table.Count(ix.doors.deleted)))

	ix.doors.SendAll()
end

hook.Add("LoadData", "ixDoors", ix.doors.Load)
hook.Add("PostLoadData", "ixDoors", ix.doors.Load)
timer.Simple(10, ix.doors.Load)

--[[
	Attach every prop teleport to its prop, and drop the ones with no prop.

	Safe to run repeatedly: attaching is idempotent, and a link is only dropped
	once nothing on the map matches it - which after a `PostLoadData` and a
	fifteen second timer means the prop is genuinely not coming back.
]]
function ix.doors.SweepPropLinks()
	if (not ix.doors.loaded) then return end

	local found = ix.doors.AttachPropLinks()
	local dropped = 0

	for id in pairs(ix.doors.propLinks) do
		if (found[id]) then continue end

		ix.doors.propLinks[id] = nil
		dropped = dropped + 1
	end

	if (dropped > 0) then
		ix.doors.Save()
		ix.doors.SendAll()

		MsgC(Color(255, 200, 100), string.format(
			"[falloutrp] %d prop teleport(s) dropped - their props were not "
			.. "made permanent\n", dropped))
	end
end

hook.Add("PostLoadData", "ixDoorsProps", function()
	timer.Simple(1, ix.doors.SweepPropLinks)
end)

--------------------------------------------------------------------------------
-- Telling the clients
--------------------------------------------------------------------------------

--[[
	Both lists to everybody, compressed.

	Sent whole rather than as changes because there are tens of them, not
	thousands, and a client that joined during an edit would otherwise be the
	one client whose door signs are wrong.
]]
function ix.doors.SendAll(client)
	if (not ix.doors.loaded) then return end

	local data = util.Compress(util.TableToJSON({
		factions = ix.doors.factions,
		links = ix.doors.links,
		props = ix.doors.propLinks,
		deleted = ix.doors.deleted
	}))

	net.Start("ixDoorSync")
		net.WriteUInt(#data, 32)
		net.WriteData(data, #data)

	if (IsValid(client)) then net.Send(client) else net.Broadcast() end
end

--[[
	The map's own removable entities, described to the client.

	A TRIGGER IS SERVER-ONLY. `trigger_teleport` and its relatives have no
	model and are never transmitted, so `ents.GetAll()` on the client does not
	contain them and the tool was asking somebody to point at something their
	game had never heard of. That is why nothing highlighted.

	So the shape of each one is sent: where it is, how big it is, what it is
	called. Sent once per join and after each deletion, because a map's trigger
	list does not otherwise change.
]]
function ix.doors.SendWorld(client)
	local list = {}

	for _, entity in ipairs(ents.GetAll()) do
		if (not IsValid(entity)) then continue end
		if (not ix.doors.worldClasses[entity:GetClass()]) then continue end

		local id = ix.doors.MapID(entity)

		if (not id) then continue end

		list[#list + 1] = {
			id = id,
			class = entity:GetClass(),
			pos = entity:GetPos(),
			ang = entity:GetAngles(),
			mins = entity:OBBMins(),
			maxs = entity:OBBMaxs()
		}
	end

	local data = util.Compress(util.TableToJSON(list))

	net.Start("ixDoorWorld")
		net.WriteUInt(#data, 32)
		net.WriteData(data, #data)

	if (IsValid(client)) then net.Send(client) else net.Broadcast() end
end

net.Receive("ixDoorRestore", function(length, client)
	if (not ix.admin.Can(client, "door.worldtp")) then return end

	local id = net.ReadUInt(32)
	local ok, why = ix.doors.RestoreWorld(client, id)

	client:Notify(ok and "Taken off the list - it comes back on the next map "
		.. "load." or why)

	if (ok) then ix.doors.SendAll() end
end)

hook.Add("PlayerInitialSpawn", "ixDoors", function(client)
	timer.Simple(2, function()
		if (not IsValid(client)) then return end

		ix.doors.SendAll(client)
		ix.doors.SendWorld(client)
	end)
end)

--[[
	Tell one client which door the teleport tool is holding.

	The tool runs on the server only - the client's click is predicted and can
	fire twice - so this is how the preview line knows where to start. Same
	shape as `ix.zones.SendPending`, and for the same reason.
]]
function ix.doors.SendPending(client, entity)
	net.Start("ixDoorPending")
		net.WriteBool(IsValid(entity))

		if (IsValid(entity)) then net.WriteEntity(entity) end
	net.Send(client)
end

--------------------------------------------------------------------------------
-- Faction lists
--------------------------------------------------------------------------------

function ix.doors.SetFactions(client, entity, list)
	--- A prop teleport keeps its list in its own record; see `FactionIDs`.
	local prop = ix.doors.PropLink(entity)

	if (prop) then
		prop.factions = list

		ix.doors.Save()
		ix.doors.SendAll()

		ix.log.Add(client, "doorFactions", entity.ixTeleportLink,
			table.concat(list, ", "))

		return true
	end

	local id = ix.doors.MapID(entity)

	if (not id) then
		return false, "That is not one of the map's doors, and it is not a "
			.. "teleport."
	end

	if (#list == 0) then
		ix.doors.factions[id] = nil
	else
		ix.doors.factions[id] = list
	end

	ix.doors.Save()
	ix.doors.SendAll()

	ix.log.Add(client, "doorFactions", id, table.concat(list, ", "))

	return true
end

--[[
	HELIX IS ASKED FIRST AND THIS ONLY EVER SAYS YES.

	Returning `false` here would take access away from somebody Helix's own
	rules had already granted - the door's owner, its single faction, its
	class - and this list is meant to ADD to those. So a door with no list
	behaves exactly as it did before this file existed.
]]
hook.Add("CanPlayerAccessDoor", "ixDoors", function(client, door, access)
	if (ix.doors.Allowed(client, door)) then return true end
end)

--------------------------------------------------------------------------------
-- Teleport doors
--------------------------------------------------------------------------------

--[[
	Make something a teleport.

	Two kinds of thing, one function: a door the map made is keyed by its
	`MapCreationID`, and anything else gets a prop link keyed by a number of
	our own. Splitting this in two would mean two places that write a
	destination and two that forget to broadcast it.
]]
function ix.doors.SetLink(client, entity, position, angles, name, factions,
	price, colour)
	if (not IsValid(entity)) then return false, "Nothing there." end

	local id = ix.doors.MapID(entity)

	if (id) then
		--[[
			The owner is CARRIED OVER, not cleared. Re-pointing a teleport
			somebody has bought should not quietly take it off them - selling
			and breaching are what do that.
		]]
		local existing = ix.doors.links[id]

		ix.doors.links[id] = {
			position = position,
			angles = angles or angle_zero,
			name = name or "",
			price = math.max(tonumber(price) or 0, 0),

			--- Kept when this call does not name one; see `ix.doors.Colour`.
			colour = colour or (existing and existing.colour),

			owner = existing and existing.owner,
			pair = existing and existing.pair
		}

		if (factions) then ix.doors.factions[id] = #factions > 0 and factions or nil end

		ix.doors.Save()
		ix.doors.SendAll()

		ix.log.Add(client, "doorLink", id, tostring(position))

		return true
	end

	--[[
		A prop. Its own position is recorded as well as the destination,
		because that is how it is found again after a restart - see the note on
		`ix.doors.propLinks`.
	]]
	if (entity:IsPlayer() or entity:IsWeapon()) then
		return false, "Not that."
	end

	local model = entity:GetModel()

	if (not model or model == "") then
		return false, "That has no model to remember it by."
	end

	--- Replacing the one already on it rather than making a second.
	local linkID = entity.ixTeleportLink

	if (not linkID or not ix.doors.propLinks[linkID]) then
		linkID = ix.doors.nextPropLink or 1

		ix.doors.nextPropLink = linkID + 1
	end

	local existing = ix.doors.propLinks[linkID]

	ix.doors.propLinks[linkID] = {
		id = linkID,
		model = model,
		origin = entity:GetPos(),
		position = position,
		angles = angles or angle_zero,
		name = name or "",
		factions = factions or {},
		price = math.max(tonumber(price) or 0, 0),
		colour = colour or (existing and existing.colour),
		owner = existing and existing.owner,
		pair = existing and existing.pair,
		locked = existing and existing.locked
	}

	entity.ixTeleportLink = linkID

	ix.doors.Save()
	ix.doors.SendAll()

	ix.log.Add(client, "doorLink", linkID, tostring(position))

	--[[
		Said out loud, because it is the one rule about these that is not
		obvious from doing it. A teleport on a prop nobody made permanent is
		gone at the next restart, and finding that out the hard way is an
		evening's work lost.
	]]
	if (not entity.ixPerma) then
		client:ChatPrint("[Teleport] That prop is not permanent - make it "
			.. "permanent with the permaprop tool or this teleport is gone "
			.. "at the next restart.")
	end

	return true
end

function ix.doors.ClearLink(client, entity)
	if (not IsValid(entity)) then return false, "Nothing there." end

	local propID = entity.ixTeleportLink

	if (propID and ix.doors.propLinks[propID]) then
		ix.doors.propLinks[propID] = nil
		entity.ixTeleportLink = nil

		ix.doors.Save()
		ix.doors.SendAll()

		ix.log.Add(client, "doorUnlink", propID)

		return true
	end

	local id = ix.doors.MapID(entity)

	if (not id or not ix.doors.links[id]) then
		return false, "That is not a teleport."
	end

	ix.doors.links[id] = nil

	ix.doors.Save()
	ix.doors.SendAll()

	ix.log.Add(client, "doorUnlink", id)

	return true
end

--[[
	Walking through one.

	`PlayerUse` rather than the door's own output, because a teleport door
	should NOT open - opening it would show whatever is behind it on this side
	of the map, which is a wall. Returning false stops the use going any
	further, so the door stays shut and the player is simply elsewhere.

	A LOCKED TELEPORT IS A CLOSED TELEPORT. That is the whole of "lock it with
	keys like a door": `ix_keys` turns the door's own lock, Helix asks
	`CanPlayerAccessDoor` before letting anybody turn it, and this asks the
	engine whether it is locked now.
]]
hook.Add("PlayerUse", "ixDoorsTeleport", function(client, entity)
	local link = ix.doors.Link(entity)

	if (not link) then return end
	if (not client:Alive() or not client:GetCharacter()) then return false end

	if ((client.ixNextTeleport or 0) > CurTime()) then return false end

	client.ixNextTeleport = CurTime() + 1

	if (ix.doors.Locked(entity)) then
		client:Notify("It is locked.")

		return false
	end

	--[[
		An empty faction list means anybody. A door meant for one faction is a
		door with a list; a public shortcut is a door without one, and making
		the empty case mean "nobody" would break every teleport the moment
		somebody cleared its list to open it up.
	]]
	local factions = ix.doors.FactionIDs(entity)

	--[[
		`CheckDoorAccess` is added to the entity metatable by Helix's door
		plugin, so it is only there while that plugin is loaded. Called
		unguarded this would be a nil call on a server that had unloaded it -
		and the teleport would stop working for a reason nothing pointed at.
	]]
	local ownerAccess = entity.CheckDoorAccess
		and entity:CheckDoorAccess(client, DOOR_GUEST or 1)

	if (#factions > 0 and not ix.doors.Allowed(client, entity)
	and not ownerAccess) then
		client:Notify("You are not allowed through here.")

		return false
	end

	client:SetPos(link.position)
	client:SetEyeAngles(link.angles or client:EyeAngles())

	--[[
		A DOOR NOISE, NOT A TELEPORTER NOISE.

		The windup it used to play is four seconds of rising machinery at full
		volume, which is a set piece rather than a sound effect - somebody
		walking a corridor of these heard it over everything else. A door opens
		and it is done, which is also what the thing is pretending to be.
	]]
	client:EmitSound("phoenix/fx/drs/drs_bodygeneric_open.mp3", 55, 100, 0.5)

	ix.log.Add(client, "doorTeleport", ix.doors.MapID(entity) or 0,
		link.name ~= "" and link.name or tostring(link.position))

	return false
end)

--------------------------------------------------------------------------------
-- Locking, and two-way pairs
--------------------------------------------------------------------------------

--[[
	Tie two teleports together.

	A two-way pair is TWO ORDINARY LINKS THAT KNOW ABOUT EACH OTHER, not a
	third kind of record. Each side still has its own destination, its own
	name and its own faction list; `pair` is one extra field naming the far
	end. That means everything that already works on a one-way teleport - the
	sign, the faction check, deleting it - works on half of a pair without
	knowing pairs exist.
]]
function ix.doors.SetPair(first, second)
	local firstLink = ix.doors.Link(first)
	local secondLink = ix.doors.Link(second)

	if (not firstLink or not secondLink) then return false end

	firstLink.pair = ix.doors.KeyOf(second)
	secondLink.pair = ix.doors.KeyOf(first)

	ix.doors.Save()
	ix.doors.SendAll()

	return true
end

--[[
	Lock or unlock a teleport, whichever kind it is.

	`bNoMirror` stops the two halves of a pair calling each other for ever. It
	is the only reason this takes a fourth argument, and it is why the mirror
	is done here rather than in each caller - a caller that forgot would be an
	infinite loop rather than a missing feature.
]]
function ix.doors.SetLocked(client, entity, state, bNoMirror)
	local link = ix.doors.Link(entity)

	if (not link) then return false, "That is not a teleport." end

	if (IsValid(client) and not ix.doors.Allowed(client, entity)
	and not (entity.CheckDoorAccess
		and entity:CheckDoorAccess(client, DOOR_GUEST or 1))) then
		return false, "You do not have the key."
	end

	local prop = ix.doors.PropLink(entity)

	if (prop) then
		prop.locked = state and true or nil

		ix.doors.Save()
		ix.doors.SendAll()
	else
		entity:Fire(state and "lock" or "unlock")

		local partner = entity.GetDoorPartner and entity:GetDoorPartner()

		if (IsValid(partner)) then
			partner:Fire(state and "lock" or "unlock")
		end
	end

	if (IsValid(client)) then
		client:EmitSound(state and "doors/door_latch3.wav"
			or "doors/door_latch1.wav", 55)
	end

	if (not bNoMirror) then
		local partner = ix.doors.Partner(entity)

		if (IsValid(partner)) then
			ix.doors.SetLocked(client, partner, state, true)
		end
	end

	ix.log.Add(client, "doorLock", ix.doors.KeyOf(entity) or "?",
		state and "locked" or "unlocked")

	return true
end

--[[
	Turning the lock, with the time it takes.

	`SetAction` is Helix's own progress bar - the one a search or a bandage
	uses - so this looks like every other thing in the game that takes a
	moment, and is cancelled the same way. The check happens twice, before and
	after: three seconds is long enough for somebody to have lost the right to
	do this halfway through.
]]
function ix.doors.BeginLock(client, entity, state)
	local link = ix.doors.Link(entity)

	if (not link) then return false, "That is not a teleport." end

	local ok, why = ix.doors.CanLock(client, entity)

	if (not ok) then return false, why end

	local time = math.max(ix.config.Get("teleportLockTime", 3), 0)

	if (time <= 0) then return ix.doors.SetLocked(client, entity, state) end

	--[[
		LOOK AWAY AND IT STOPS.

		`SetAction` alone is a progress bar and a timer: it finishes wherever
		you are and whatever you are pointing at, so a lock started at a door
		turned three seconds later even if you had walked off round a corner.
		`DoStaredAction` is Helix\'s own answer and is what every other timed
		act in this schema uses - tying somebody up, searching them, defusing a
		collar - it re-traces every tenth of a second and cancels the moment the
		door leaves your crosshair.

		The bar is still `SetAction`, because that is the part people read; it
		is cleared by hand when the stare breaks, or it would sit there full
		and lying about what happened.
	]]
	client:SetAction(state and "@locking" or "@unlocking", time)

	client:DoStaredAction(entity, function()
		if (not IsValid(client) or not IsValid(entity)) then return end

		client:SetAction()

		if (not ix.doors.CanLock(client, entity)) then return end

		ix.doors.SetLocked(client, entity, state)
	end, time, function()
		if (not IsValid(client)) then return end

		client:SetAction()
		client:Notify("You stopped turning the lock.")
	end)

	return true
end

--- May this person turn this teleport's lock at all?
function ix.doors.CanLock(client, entity)
	if (not IsValid(client) or not IsValid(entity)) then return false end

	if (ix.doors.Allowed(client, entity)) then return true end

	if (entity.CheckDoorAccess
	and entity:CheckDoorAccess(client, DOOR_GUEST or 1)) then
		return true
	end

	--[[
		An unowned teleport with a price is nobody's, so nobody may lock it.
		Buying it is what makes it yours to shut.
	]]
	return false, ix.doors.Price(entity) > 0
		and "Buy it first - /buydoor." or "You do not have the key."
end

--------------------------------------------------------------------------------
-- Buying one
--------------------------------------------------------------------------------

function ix.doors.Buy(client, entity)
	local link = ix.doors.Link(entity)

	if (not link) then return false, "That is not a teleport." end

	local price = ix.doors.Price(entity)

	if (price <= 0) then return false, "That one is not for sale." end
	if (ix.doors.Owner(entity)) then return false, "Somebody already owns it." end

	local character = client:GetCharacter()

	if (not character) then return false, "You have no character." end

	if (character:GetMoney() < price) then
		return false, string.format("You need %s.",
			ix.points.FormatCaps(price))
	end

	character:SetMoney(character:GetMoney() - price)

	link.owner = string.format("character:%d|%s", character:GetID(),
		character:GetName())

	--[[
		The far half of a two-way pair changes hands with it. Buying one end of
		a corridor and finding the other end still open to everybody would make
		the purchase worth nothing.
	]]
	local partner = ix.doors.Partner(entity)
	local partnerLink = IsValid(partner) and ix.doors.Link(partner)

	if (partnerLink) then partnerLink.owner = link.owner end

	ix.doors.Save()
	ix.doors.SendAll()

	ix.log.Add(client, "doorBuy", ix.doors.KeyOf(entity) or "?", price)

	return true, price
end

function ix.doors.Sell(client, entity)
	local link = ix.doors.Link(entity)

	if (not link) then return false, "That is not a teleport." end
	if (not ix.doors.Owns(client, entity)) then
		return false, "You do not own it."
	end

	local character = client:GetCharacter()
	local price = ix.doors.Price(entity)

	--- Helix's own ratio, so a door and a teleport sell for the same fraction.
	local refund = math.floor(price * ix.config.Get("doorSellRatio", 0.5))

	ix.doors.Release(client, entity)

	character:SetMoney(character:GetMoney() + refund)

	ix.log.Add(client, "doorSell", ix.doors.KeyOf(entity) or "?", refund)

	return true, refund
end

--[[
	Take a teleport off whoever owns it, and unlock it.

	Shared by selling and by `ix.doors.Breach` below, so "it is nobody's again"
	is one piece of code - the two halves of a pair, the lock, the record.
]]
function ix.doors.Release(client, entity)
	local link = ix.doors.Link(entity)

	if (not link) then return false end

	link.owner = nil

	local partner = ix.doors.Partner(entity)
	local partnerLink = IsValid(partner) and ix.doors.Link(partner)

	if (partnerLink) then partnerLink.owner = nil end

	ix.doors.SetLocked(nil, entity, false, true)

	if (IsValid(partner)) then
		ix.doors.SetLocked(nil, partner, false, true)
	end

	ix.doors.Save()
	ix.doors.SendAll()

	return true
end

--[[
	Blowing the lock off.

	This is the half of a breach that belongs to the door system: what "it
	becomes unowned again" means. `ix_breachcharge` calls this and nothing
	else - the explosion, the radius and the blown hinges are its business, and
	the ownership record is this one.
]]
function ix.doors.Breach(client, entity)
	local owner = ix.doors.Owner(entity)

	if (not ix.doors.Link(entity)) then
		return false, "That is not a teleport."
	end

	ix.doors.Release(client, entity)

	ix.log.Add(client, "doorBreach", ix.doors.KeyOf(entity) or "?",
		owner and owner.name or "nobody")

	for _, other in ipairs(player.GetAll()) do
		if (other:GetPos():Distance(entity:GetPos()) > 1500) then continue end

		other:ChatPrint("[Teleport] The lock has been blown off.")
	end

	return true
end

--[[
	Helix's keys, taught about the two things they did not know.

	    a prop teleport   `ix_keys` gates on `entity:IsDoor()`, so a crate with
	                      a teleport on it was simply not a thing the keys
	                      could be pointed at
	    a two-way pair    locking one half left the other half open, which is
	                      not what "the tp doors lock together" means

	WRAPPED, NOT REPLACED. The original still handles every ordinary door,
	every vehicle, the timing and the animation; this only adds the case it
	returns nothing for.
]]
local function WrapKeys()
	local swep = weapons.GetStored("ix_keys")

	if (not swep) then return false end
	if (swep.ixTeleport) then return true end

	swep.ixTeleport = true

	for name, state in pairs({PrimaryAttack = true, SecondaryAttack = false}) do
		local original = swep[name]

		if (not original) then continue end

		swep[name] = function(self, ...)
			if (CLIENT or not IsFirstTimePredicted()) then
				return original(self, ...)
			end

			local owner = self:GetOwner()

			if (not IsValid(owner)) then return original(self, ...) end

			local trace = util.TraceLine({
				start = owner:GetShootPos(),
				endpos = owner:GetShootPos() + owner:GetAimVector() * 96,
				filter = owner
			})

			local entity = trace.Entity

			--[[
				Only the case the original cannot handle. A door goes to the
				original untouched, so nothing about ordinary doors changes -
				including the pair mirroring, which is done from the hooks
				below instead.
			]]
			if (not IsValid(entity) or entity:IsDoor()
			or not ix.doors.PropLink(entity)) then
				return original(self, ...)
			end

			local time = math.max(ix.config.Get("teleportLockTime", 3), 1)

			self:SetNextPrimaryFire(CurTime() + time)
			self:SetNextSecondaryFire(CurTime() + time)

			local ok, why = ix.doors.BeginLock(owner, entity, state)

			if (not ok) then owner:Notify(why) end
		end
	end

	return true
end

if (not WrapKeys()) then
	hook.Add("InitializedPlugins", "ixDoorsKeys", function()
		if (not WrapKeys()) then
			ErrorNoHalt("[falloutrp] ix_keys never appeared - teleports on "
				.. "props cannot be locked\n")
		end
	end)
end

--[[
	A door locked with the keys locks its two-way partner as well.

	Done from the hook rather than from the wrap above, because the original
	`ToggleLock` is what actually turns an ordinary door's lock and this is the
	event it announces when it has.
]]
local function Mirror(client, door, state)
	local partner = ix.doors.Partner(door)

	if (not IsValid(partner)) then return end

	ix.doors.SetLocked(client, partner, state, true)
end

hook.Add("PlayerLockedDoor", "ixDoors", function(client, door)
	Mirror(client, door, true)
end)

hook.Add("PlayerUnlockedDoor", "ixDoors", function(client, door)
	Mirror(client, door, false)
end)

--------------------------------------------------------------------------------
-- The map's own teleports
--------------------------------------------------------------------------------

--[[
	Remove everything on the deleted list, now.

	Called after the map loads and after a cleanup, because both put the map's
	own entities back. This is what "stays deleted" means - the entity is
	recreated by the engine every time and taken away again here.
]]
function ix.doors.PurgeWorld()
	local removed = 0

	for _, entity in ipairs(ents.GetAll()) do
		local id = ix.doors.MapID(entity)

		if (id and ix.doors.deleted[id] and IsValid(entity)) then
			entity:Remove()

			removed = removed + 1
		end
	end

	return removed
end

hook.Add("PostCleanupMap", "ixDoors", function()
	if (ix.doors.loaded) then ix.doors.PurgeWorld() end
end)

function ix.doors.DeleteWorld(client, entity)
	local id = ix.doors.MapID(entity)

	if (not id) then
		return false, "That was not made by the map, so it will not come back."
	end

	if (not ix.doors.worldClasses[entity:GetClass()]) then
		return false, entity:GetClass() .. " is not one of the map's teleports."
	end

	--[[
		WHAT it was, not just that it went.

		A list of bare ids is a list nobody can undo from: "map entity 412" is
		not something anybody recognises three weeks later. The class and the
		model are what make the list in the tool panel readable, and the
		position is what lets somebody go and look at the hole.
	]]
	ix.doors.deleted[id] = {
		class = entity:GetClass(),
		model = entity:GetModel() or "",
		position = entity:GetPos(),
		time = os.time()
	}

	ix.doors.Save()

	entity:Remove()

	ix.doors.SendAll()

	ix.log.Add(client, "doorWorldDelete", id, entity:GetClass())

	return true
end

--[[
	The same, for anything else the map made - a door, a prop, a light.

	A SEPARATE FUNCTION AND THE SAME LIST. The two tools ask different
	questions - "is this one of the map's teleports" against "is this anything
	at all" - and share the answer, because "things taken out of this map" is
	one fact and two lists of it would be two lists to keep in step.

	Players, weapons and anything the map did not make are refused: removing a
	runtime entity here would record an id that means something else entirely
	after a restart.
]]
function ix.doors.DeleteProp(client, entity)
	local id = ix.doors.MapID(entity)

	if (not id) then
		return false, "That was not made by the map, so it will not come back."
	end

	if (entity:IsPlayer() or entity:IsWeapon() or entity:IsNPC()) then
		return false, "Not that."
	end

	ix.doors.deleted[id] = {
		class = entity:GetClass(),
		model = entity:GetModel() or "",
		position = entity:GetPos(),
		time = os.time()
	}

	ix.doors.Save()

	entity:Remove()

	ix.doors.SendAll()

	ix.log.Add(client, "doorWorldDelete", id, entity:GetClass())

	return true
end

--[[
	Put one back.

	The engine will not recreate it until the map reloads, so this only removes
	it from the list and says so - claiming it had reappeared would be a lie
	somebody would spend an hour testing.
]]
function ix.doors.RestoreWorld(client, id)
	if (not ix.doors.deleted[id]) then
		return false, "That one is not on the list."
	end

	ix.doors.deleted[id] = nil

	ix.doors.Save()
	ix.doors.SendAll()

	ix.log.Add(client, "doorWorldRestore", id)

	return true
end

--------------------------------------------------------------------------------
-- Logs
--------------------------------------------------------------------------------

ix.log.AddType("doorFactions", function(client, id, list)
	return string.format("%s set door %d to: %s", client:Name(), id,
		list ~= "" and list or "nobody extra")
end, FLAG_WARNING)

ix.log.AddType("doorLink", function(client, id, position)
	return string.format("%s made door %d a teleport to %s.", client:Name(),
		id, position)
end, FLAG_WARNING)

ix.log.AddType("doorBuy", function(client, key, price)
	return string.format("%s bought teleport %s for %d.", client:Name(), key,
		price)
end, FLAG_WARNING)

ix.log.AddType("doorSell", function(client, key, refund)
	return string.format("%s sold teleport %s back for %d.", client:Name(),
		key, refund)
end, FLAG_WARNING)

ix.log.AddType("doorBreach", function(client, key, owner)
	return string.format("%s blew the lock off teleport %s, held by %s.",
		client and client:Name() or "something", key, owner)
end, FLAG_DANGER)

ix.log.AddType("doorLock", function(client, key, state)
	return string.format("%s %s teleport %s.",
		client and client:Name() or "the console", state, key)
end)

ix.log.AddType("doorUnlink", function(client, id)
	return string.format("%s stopped door %d being a teleport.",
		client:Name(), id)
end, FLAG_WARNING)

ix.log.AddType("doorTeleport", function(client, id, where)
	return string.format("%s went through teleport door %d to %s.",
		client:Name(), id, where)
end)

ix.log.AddType("doorWorldDelete", function(client, id, class)
	return string.format("%s permanently deleted the map's %s (%d).",
		client:Name(), class, id)
end, FLAG_DANGER)

ix.log.AddType("doorWorldRestore", function(client, id)
	return string.format("%s took map entity %d off the deleted list.",
		client:Name(), id)
end, FLAG_WARNING)
