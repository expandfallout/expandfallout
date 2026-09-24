--[[
	Buffs - the server half.

	Applying one is three things: record it, tell the owner so the HUD can show
	it, and poke whatever system reads that stat so the change takes effect
	now rather than on the player's next spawn.

	THE POKE IS THE PART THAT IS EASY TO FORGET. `ix.special.Apply` sets walk
	and run speed absolutely and only runs on spawn and on an attribute change;
	a +30 Speed buff that does not call it sits in the table doing nothing for
	up to a life. Max health is a real property that has to be written rather
	than read. So `Refresh` exists, it asks the functions that already own
	those two things to run again, and every path that changes a buff ends by
	calling it.

	Damage resistance, outgoing damage, radiation resistance and SPECIAL need
	no poke - each is read at the moment it is used, so a buff is in effect the
	instant it is in the table.
]]

if (not SERVER) then return end

util.AddNetworkString("ixBuffSync")

--[[
	How often expiry is checked.

	One timer for the whole server rather than one per buff: a hundred players
	each holding three chems is three hundred timers to create, name and clean
	up, against one loop that walks whoever is online. A second of overshoot on
	a two-minute buff is not worth the bookkeeping.
]]
local EXPIRY_INTERVAL = 1

function ix.buff.Refresh(client)
	if (not IsValid(client)) then return end

	--[[
		Speed goes through `ix.special.Apply`, the one function that sets
		movement - it reads `ix.buff.Get` itself, so calling it is how a Speed
		buff reaches the player's legs. `ApplyBodyState` below calls it too;
		this covers the case where there is no character to go through.
	]]
	if (ix.special and ix.special.Apply) then
		ix.special.Apply(client)
	end

	--[[
		Max health is NOT set here, deliberately.

		`characterMeta:ApplyBodyState` already owns it and computes it from the
		race base, the radiation tier and the `HP` buff together. Writing it
		here as well would give two absolute writers for one property, and
		which one won would depend on which ran last - a Buffout wearing off
		would restore a ceiling that ignored the player's rads.

		So this asks that function to run again, which also covers speed, and
		nothing here needs to know how health is worked out.
	]]
	local character = client:GetCharacter()

	if (character and character.ApplyBodyState) then
		character:ApplyBodyState()
	end

	--[[
		The STEALTH buff is the one whose effect is not a number.

		Every other buff is a value something else reads; this one means the
		stealth field is ON, so it has to be switched rather than summed. This
		runs after every add, remove and expiry, which is exactly when a
		Stealth Boy starts and stops.
	]]
	if (ix.armor and ix.armor.SyncStealth) then
		ix.armor.SyncStealth(client)
	end
end

--[[
	Send the whole list rather than a delta.

	Phoenix networks add, remove, remove-timed and clear as four separate
	messages, and their client keeps its own copy in step by replaying them.
	That is four chances for the two to drift - a missed message leaves a buff
	on the HUD that expired minutes ago. A full list is a few dozen bytes and
	cannot drift.
]]
function ix.buff.Sync(client)
	if (not IsValid(client)) then return end

	local list = ix.buff.GetAll(client)

	net.Start("ixBuffSync")
		net.WriteUInt(#list, 8)

		for _, buff in ipairs(list) do
			net.WriteString(buff.stat)
			net.WriteInt(buff.value, 16)
			--[[
				Sent as SECONDS REMAINING, not as an end time. `CurTime` is not
				the same number on both machines, and a client that subtracts
				its own clock from the server's shows a timer that is wrong by
				however long the two have been running.
			]]
			net.WriteUInt(buff.endTime == 0 and 0
				or math.ceil(buff.endTime - CurTime()), 16)
			net.WriteString(buff.label or "")
		end
	net.Send(client)
end

--[[
	Apply a buff.

	`id` is what makes a second dose of the same chem refuse rather than stack
	- pass the item's `aidID`. Without one, the buff gets a unique id and can
	stack with itself, which is what withdrawal penalties want.

	`duration` of 0 means it lasts until something removes it. That is for
	addiction; a chem always has a length.
]]
function ix.buff.Add(client, stat, value, duration, id, label)
	if (not IsValid(client) or not ix.buff.stats[stat]) then return false end

	client.ixBuffs = client.ixBuffs or {}

	duration = math.max(tonumber(duration) or 0, 0)

	--[[
		An anonymous buff gets a key nothing else will pick. `CurTime` alone
		collides when two land in the same tick, which two withdrawal tiers
		arriving together do.
	]]
	if (not id) then
		client.ixBuffCounter = (client.ixBuffCounter or 0) + 1
		id = string.format("%s_%d", stat, client.ixBuffCounter)
	end

	client.ixBuffs[id] = {
		stat = stat,
		value = math.Round(tonumber(value) or 0),
		endTime = duration > 0 and CurTime() + duration or 0,
		label = label
	}

	ix.buff.Refresh(client)
	ix.buff.Sync(client)

	return true
end

--- Take one off by id. Returns whether there was one.
function ix.buff.Remove(client, id)
	if (not IsValid(client) or not client.ixBuffs or not client.ixBuffs[id]) then
		return false
	end

	client.ixBuffs[id] = nil

	ix.buff.Refresh(client)
	ix.buff.Sync(client)

	return true
end

--[[
	Remove every buff, or every buff of one stat.

	Used by Addictol and by death. `stat` is optional because "clear my
	withdrawal" and "clear everything" are both things something wants.
]]
function ix.buff.Clear(client, stat)
	if (not IsValid(client) or not client.ixBuffs) then return 0 end

	local removed = 0

	for id, buff in pairs(client.ixBuffs) do
		if (not stat or buff.stat == stat) then
			client.ixBuffs[id] = nil
			removed = removed + 1
		end
	end

	ix.buff.Refresh(client)
	ix.buff.Sync(client)

	return removed
end

--[[
	Expire what has run out.

	Only touches players whose list actually changed, so the common case - a
	server full of people on no chems - costs one table lookup each.
]]
timer.Create("ixBuffExpiry", EXPIRY_INTERVAL, 0, function()
	local now = CurTime()

	for _, client in player.Iterator() do
		local list = client.ixBuffs

		if (not list) then continue end

		local expired = false

		for id, buff in pairs(list) do
			if (buff.endTime ~= 0 and buff.endTime <= now) then
				list[id] = nil
				expired = true
			end
		end

		if (expired) then
			ix.buff.Refresh(client)
			ix.buff.Sync(client)
		end
	end
end)

--[[
	Chems do not survive dying.

	Withdrawal does - it is held on the character by `ix.addiction` and put back
	on spawn - but the two minutes of +25 max health you were part way through
	are gone, which is the point of taking the risk in the first place.
]]
hook.Add("PlayerDeath", "ixBuff", function(client)
	if (not IsValid(client)) then return end

	client.ixBuffs = nil
	client.ixBuffCounter = nil
end)

--[[
	A fresh character starts clean.

	`PlayerLoadedCharacter` rather than `PlayerSpawn`: buffs belong to the
	person, and swapping characters should not carry a chem across. Respawning
	as the same character has already been handled by the death hook.
]]
hook.Add("PlayerLoadedCharacter", "ixBuff", function(client)
	client.ixBuffs = nil
	client.ixBuffCounter = nil

	ix.buff.Refresh(client)
	ix.buff.Sync(client)
end)

--[[
	Max health has to be re-asserted on spawn.

	The engine resets it, so a player who spawns while a Buffout is still
	running would otherwise have the buff in the table and the health of
	somebody who never took it.
]]
hook.Add("PlayerSpawn", "ixBuff", function(client)
	timer.Simple(0, function()
		if (IsValid(client)) then
			ix.buff.Refresh(client)
			ix.buff.Sync(client)
		end
	end)
end)

concommand.Add("fo_buffs", function(client)
	if (not IsValid(client)) then return end

	local list = ix.buff.GetAll(client)

	client:ChatPrint(string.format("You have %d buff(s).", #list))

	for _, buff in ipairs(list) do
		client:ChatPrint(string.format("  %-24s %s   %s",
			buff.label or buff.id,
			ix.buff.Describe(buff.stat, buff.value),
			buff.endTime == 0 and "no expiry"
				or string.format("%ds left",
					math.ceil(buff.endTime - CurTime()))))
	end
end)
