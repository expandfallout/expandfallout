--[[
	Lockpicking, server side: the answer, and everything that spends it.

	See `sh_lockpick.lua` for what a lock is. This file owns three things:

	    the sweet spot        rolled per attempt, never sent
	    the bobby pins        one item per snapped pin
	    the unlock            and the timer that puts the lock back

	EVERY MESSAGE IS RE-CHECKED HERE. The window sends "I am at this angle" and
	"I would like to open this", and both are treated as claims: the distance
	is measured again, the lock is looked up again, and the pin is taken from
	the inventory rather than from a number the client was trusted to keep.
]]

if (not SERVER) then return end

util.AddNetworkString("ixLockpickOpen")
util.AddNetworkString("ixLockpickDifference")
util.AddNetworkString("ixLockpickTurn")
util.AddNetworkString("ixLockpickBroke")
util.AddNetworkString("ixLockpickUnlock")

--- How close you have to be, matching `ix.loot.Open`'s own reach.
local REACH = 160

--[[
	The attempt in progress, per player: `{entity, sweetSpot, level}`.

	Kept on the SERVER rather than on the entity, because two people picking
	the same crate are two different attempts at two different spots - which is
	right: they are each feeling for the pins themselves.
]]
local attempts = {}

--- How many bobby pins a character is carrying.
local function CountPins(client)
	local character = client:GetCharacter()
	local inventory = character and character:GetInventory()

	if (not inventory) then return 0 end

	--- `ix.stack.Count` knows what a stack is; this file should not.
	return ix.stack.Count(inventory, ix.lockpick.pinItem)
end

--- Take one pin, wherever it is. Returns whether one was there to take.
local function TakePin(client)
	local character = client:GetCharacter()
	local inventory = character and character:GetInventory()

	if (not inventory) then return false end

	return ix.stack.Take(inventory, ix.lockpick.pinItem, 1)
end

--[[
	Start an attempt. Called from the lootable's `Use` when it is locked.
]]
function ix.lockpick.Begin(client, entity)
	if (not IsValid(client) or not IsValid(entity)) then return false end

	if (not ix.lockpick.canPick[entity:GetClass()]) then return false end

	local level = entity.GetLockLevel and entity:GetLockLevel() or 0

	if (level <= 0) then return false end

	local pins = CountPins(client)

	if (pins <= 0) then
		client:Notify("You need a bobby pin to pick this lock.")

		return false
	end

	--[[
		A NEW SPOT EVERY TIME, including after a snapped pin - the lock has not
		changed, but a player who could learn the angle once would only ever
		have to pick a container once.
	]]
	attempts[client] = {
		entity = entity,
		sweetSpot = math.random(-85, 85),
		level = level
	}

	net.Start("ixLockpickOpen")
		net.WriteEntity(entity)
		net.WriteUInt(level, 4)
		net.WriteUInt(math.min(pins, 1023), 10)
	net.Send(client)

	return true
end

--[[
	Whether this player is genuinely picking this entity, from here.

	One function so every message asks the same question - the distance, the
	entity, and that an attempt was actually started.
]]
local function Attempt(client, entity)
	local attempt = attempts[client]

	if (not attempt or attempt.entity ~= entity) then return nil end
	if (not IsValid(entity)) then return nil end

	if (client:GetPos():DistToSqr(entity:GetPos()) > REACH * REACH) then
		return nil
	end

	return attempt
end

--[[
	"The pin is here - how far does it turn?"

	The only thing the client is told, and it is a consequence rather than a
	fact: knowing that the cylinder turns 0.4 of the way at 20 degrees narrows
	the answer down, which is exactly what feeling a lock out is supposed to
	do.
]]
net.Receive("ixLockpickTurn", function(length, client)
	local entity = net.ReadEntity()
	local angle = math.Clamp(net.ReadInt(9), -90, 90)

	local attempt = Attempt(client, entity)

	if (not attempt) then return end

	net.Start("ixLockpickDifference")
		net.WriteFloat(ix.lockpick.Difference(angle, attempt.sweetSpot,
			attempt.level))
	net.Send(client)
end)

--[[
	A snapped pin, which is the client's animation reporting a cost.

	Trusted because it can only ever cost the player something. The gain - the
	lock opening - is decided here and nowhere else.
]]
net.Receive("ixLockpickBroke", function(length, client)
	local entity = net.ReadEntity()
	local attempt = Attempt(client, entity)

	if (not attempt) then return end

	if (not TakePin(client)) then
		attempts[client] = nil

		return
	end

	--[[
		A NEW SPOT with the new pin, for the same reason as above.
	]]
	attempt.sweetSpot = math.random(-85, 85)

	ix.log.Add(client, "lockpickBreak",
		ix.lockpick.Name(attempt.level))
end)

--[[
	"It turned all the way."

	CHECKED AGAIN, WITH THE ANGLE. The client says which angle opened it and
	the server asks its own function whether that is true - so a client that
	simply sent this message would be answered with a lock that stays shut.
]]
net.Receive("ixLockpickUnlock", function(length, client)
	local entity = net.ReadEntity()
	local angle = math.Clamp(net.ReadInt(9), -90, 90)

	local attempt = Attempt(client, entity)

	if (not attempt) then return end

	if (ix.lockpick.Difference(angle, attempt.sweetSpot, attempt.level) < 1) then
		return
	end

	attempts[client] = nil

	ix.lockpick.Unlock(entity, client)
end)

--[[
	Open a lock, and set it to close again.

	The level is REMEMBERED rather than cleared, so the container relocks at
	the difficulty it was placed with - `ixLockOpenUntil` is the only thing
	that changes. A lock that had to be re-set by an admin after every
	successful pick would be a lock nobody used twice.
]]
function ix.lockpick.Unlock(entity, client)
	if (not IsValid(entity)) then return end

	local duration = ix.config.Get("lockpickOpenTime", 300)

	entity:SetLocked(false)
	entity.ixLockOpenUntil = duration > 0 and (CurTime() + duration) or nil

	if (not IsValid(client)) then return end

	entity:EmitSound("hrp/fx/lockpicking/ui_lockpicking_unlock.mp3", 70)

	local character = client:GetCharacter()
	local experience = ix.config.Get("lockpickXP", 5)

	if (character and experience > 0 and character.AddXP) then
		character:AddXP(experience)
	end

	ix.log.Add(client, "lockpick", ix.lockpick.Name(entity:GetLockLevel()))

	--[[
		Straight into the container, because picking it IS opening it. Making
		the player press E again after the cylinder turns is a second action
		for something they have already done.
	]]
	ix.loot.Open(client, entity)
end

--[[
	Relocking, and clearing an attempt somebody walked away from.

	One timer for every container rather than one per container: there are
	rarely more than a handful open at once and a two-second sweep is cheaper
	than a timer each. A container that has been removed simply falls out of
	the list.
]]
timer.Create("ixLockpickRelock", 2, 0, function()
	for _, entity in ipairs(ents.FindByClass("ix_lootable")) do
		if (not IsValid(entity) or not entity.ixLockOpenUntil) then continue end

		if (CurTime() < entity.ixLockOpenUntil) then continue end

		entity.ixLockOpenUntil = nil

		if ((entity:GetLockLevel() or 0) > 0) then
			entity:SetLocked(true)
		end
	end

	for client, attempt in pairs(attempts) do
		if (not IsValid(client) or not IsValid(attempt.entity)
		or not Attempt(client, attempt.entity)) then
			attempts[client] = nil
		end
	end
end)

hook.Add("PlayerDisconnected", "ixLockpick", function(client)
	attempts[client] = nil
end)

--[[
	Lock or unlock the container you are looking at.

	The tool and the configurer decide what a NEW container is placed with;
	this is the one for a container that is already there, which is most of
	them once a map has been dressed. Named for what it does to a lootable
	rather than for lockpicking, because that is where somebody will look.
]]
ix.command.Add("LootLock", {
	description = "Set the lock on the lootable you are looking at. "
		.. "0 is none, 1 to 5 are Very Easy to Very Hard.",
	arguments = {ix.type.number},

	OnCheckAccess = function(self, client)
		--- Superadmin, matching the tool: a lock is world content.
		return client:IsSuperAdmin()
	end,

	OnRun = function(self, client, level)
		local entity = client:GetEyeTrace().Entity

		if (not IsValid(entity) or entity:GetClass() ~= "ix_lootable") then
			return "@lockpickNotLootable"
		end

		level = math.Clamp(math.floor(level or 0), 0, #ix.lockpick.levels)

		entity:SetLockLevel(level)
		entity:SetLocked(level > 0)
		entity.ixLockOpenUntil = nil

		--[[
			WRITTEN TO THE RECORD AS WELL AS THE ENTITY. `ixLootData` is the
			same table the placed list holds, so setting it here is what makes
			the lock survive a restart - see `ix.loot.Spawn`.
		]]
		entity.ixLootData = entity.ixLootData or {}
		entity.ixLootData.lock = level

		ix.loot.SavePlaced()

		ix.log.Add(client, "lootLockSet", ix.lockpick.Name(level))

		return level > 0
			and string.format("Locked: %s.", ix.lockpick.Name(level))
			or "Unlocked, and it will stay that way."
	end
})

ix.log.AddType("lootLockSet", function(client, level)
	return string.format("%s set a lootable's lock to %s.", client:Name(),
		level)
end)

ix.log.AddType("lockpick", function(client, level)
	return string.format("%s picked a %s lock.", client:Name(), level)
end)

ix.log.AddType("lockpickBreak", function(client, level)
	return string.format("%s snapped a bobby pin on a %s lock.", client:Name(),
		level)
end)
