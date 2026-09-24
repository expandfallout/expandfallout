--[[
	Race injectors, server side: the transformation and the way back.

	See `sh_raceinject.lua` for what an injector is. This is the sequence -
	freeze, effect, change - and the clock that undoes a temporary one.
]]

if (not SERVER) then return end

util.AddNetworkString("ixRaceTransform")

ix.raceinject = ix.raceinject or {}

--- Who is mid-transformation, so a second dose cannot start another.
ix.raceinject.busy = ix.raceinject.busy or {}

--[[
	Start one.

	`duration` of 0 or nil is permanent. Returns true when it started; the
	change itself happens when the effect finishes.
]]
function ix.raceinject.Begin(client, class, duration, itemTable, temporary)
	if (not IsValid(client) or not client:Alive()) then return false end

	local character = client:GetCharacter()

	if (not character) then return false end
	if (not ix.races.list[class]) then return false end

	if (ix.raceinject.busy[client]) then
		client:Notify("Something is already happening to you.")

		return false
	end

	--[[
		ALREADY THAT RACE IS A REFUSAL, not a nine-second no-op. It also
		protects the revert: a temporary injection into the race you already
		are would remember the same race as the one to go back to, and the
		character would be stuck as it for ever if a second one landed.
	]]
	if (character:GetRace() == class) then
		client:Notify("You are already one of those.")

		return false
	end

	local seconds = math.max(math.floor(
		ix.config.Get("injectorTransformTime", 9)), 1)

	ix.raceinject.busy[client] = true

	--[[
		FROZEN FOR IT, which is Phoenix's and is the point: the transformation
		is a thing that happens TO you, and being able to walk away mid-way
		through would make it a status effect rather than an event.
	]]
	client:Freeze(true)

	net.Start("ixRaceTransform")
		net.WriteEntity(client)
		net.WriteUInt(seconds, 8)
	net.Broadcast()

	--[[
		The scale is the visible half of it - Phoenix scale to 3 for a
		behemoth and let the model settle over the transformation. Ours scales
		toward whatever the NEW race's own scale is, so a deathclaw swells and
		a radroach shrinks, and the spawn at the end lands on the same number
		rather than snapping.
	]]
	local scale = ix.races.GetScale(class) or 1

	client:SetModelScale(scale, seconds * 0.9)

	local name = itemTable and itemTable.name or "an injector"

	timer.Create("ixRaceTransform" .. client:SteamID64(), seconds, 1,
		function()
		ix.raceinject.busy[client] = nil

		if (not IsValid(client)) then return end

		client:Freeze(false)
		client:SetModelScale(1)

		--[[
			The character is looked up AGAIN rather than captured: nine seconds
			is long enough to have died, disconnected and come back on another
			character, and applying a race to that one would be a serious
			mistake for something nobody could undo.
		]]
		local current = client:GetCharacter()

		if (not current or current ~= character) then return end

		local previous = current:GetRace()
		local ok, result = ix.races.Apply(client, class)

		if (not ok) then
			client:Notify(result)

			return
		end

		--[[
			WHAT TO GO BACK TO IS WRITTEN AFTER THE CHANGE, so a failed change
			cannot leave a revert pointing at nothing. A temporary injection on
			top of another keeps the ORIGINAL race - `previous` here is already
			the temporary one, so the existing pending revert is left alone.
		]]
		if (temporary) then
			local pending = ix.raceinject.Pending(current)

			--[[
				`at` of 0 is the one-life kind - see `ix.raceinject.Pending`.
				A deadline is only written when the item or the config asked
				for one.
			]]
			current:SetData("raceRevert", {
				race = pending or previous,
				at = (duration or 0) > 0 and (os.time() + duration) or 0
			})
		else
			--- A permanent one cancels any pending revert; this is the truth now.
			current:SetData("raceRevert", nil)
		end

		client:Notify(string.format("You are %s%s.", result.name,
			not temporary and " - permanently"
				or ((duration or 0) > 0
					and string.format(" for %s", ix.bench.FormatTime(duration))
					or " until you die")))

		ix.log.Add(client, "raceInject", name, previous, class,
			temporary and ((duration or 0) > 0 and duration or -1) or 0)
	end)

	return true
end

--[[
	Put somebody back, now.

	Used by the tick below and by `/RaceRevert`. Silent when there is nothing
	pending, so it is safe to call on anybody.
]]
function ix.raceinject.Revert(client)
	if (not IsValid(client)) then return false end

	local character = client:GetCharacter()
	local class = ix.raceinject.Pending(character)

	if (not class) then return false end

	--- Cleared FIRST, so a failed apply cannot leave it retrying every second.
	character:SetData("raceRevert", nil)

	local ok = ix.races.Apply(client, class)

	if (ok) then
		client:Notify("You feel yourself change back.")
		client:EmitSound("phoenix/ui/nv/ui_karma_up.mp3", 70, 90, 0.6)
	end

	return ok
end

--[[
	One second, over everybody who has something pending.

	ON A TIMER OVER PLAYERS rather than a timer per injection, for the reason
	the plants and the cap stashes both learned: a per-injection timer dies
	with the map, so a temporary race would outlive its deadline across a
	restart and become permanent by accident. This reads a wall clock.
]]
timer.Create("ixRaceInject", 1, 0, function()
	local now = os.time()

	for _, client in player.Iterator() do
		local character = client:GetCharacter()

		if (not character) then continue end

		local class, at, forLife = ix.raceinject.Pending(character)

		if (not class or forLife) then continue end
		if (at > now) then continue end

		ix.raceinject.Revert(client)
	end
end)

--[[
	And on the way in, because the deadline can pass while somebody is offline
	- which is the common case for a ten minute change and an evening away.

	Deferred, because the character is not finished being set up when this
	fires and a `Spawn` inside `ix.races.Apply` would race it.
]]
hook.Add("PlayerLoadedCharacter", "ixRaceInject", function(client, character)
	local class, at, forLife = ix.raceinject.Pending(character)

	--[[
		A LIFE-LONG ONE ENDS AT THE DISCONNECT, which is a death in every sense
		that matters here: they are not standing there any more, and coming back
		as whatever they had been injected with days later is the temporary
		version being permanent.
	]]
	if (not class) then return end
	if (not forLife and at > os.time()) then return end

	timer.Simple(2, function()
		if (IsValid(client) and client:GetCharacter() == character) then
			ix.raceinject.Revert(client)
		end
	end)
end)

--[[
	DYING ENDS A ONE-LIFE INJECTION.

	Deferred to the respawn rather than done in `PlayerDeath`, because
	`ix.races.Apply` respawns the player to rebuild the hull and doing that to a
	corpse mid-death is how a body ends up standing up again. `PlayerSpawn`
	runs once they are alive and about to be dressed, which is the moment the
	old race should already be back.
]]
hook.Add("PlayerDeath", "ixRaceInject", function(client)
	client.ixRaceDied = true
end)

hook.Add("PlayerSpawn", "ixRaceInject", function(client)
	--[[
		ONLY AFTER AN ACTUAL DEATH. `ix.races.Apply` respawns people to rebuild
		their hull, so every race change fires this hook - without the flag, a
		temporary injection would undo itself half a second after it landed,
		and an admin's `/charsetrace` would cancel somebody's transformation
		for them.
	]]
	if (not client.ixRaceDied) then return end

	client.ixRaceDied = nil

	local character = client:GetCharacter()
	local class, _, forLife = ix.raceinject.Pending(character)

	if (not class or not forLife) then return end

	timer.Simple(0.5, function()
		if (not IsValid(client) or client:GetCharacter() ~= character) then
			return
		end

		ix.raceinject.Revert(client)
	end)
end)

hook.Add("PlayerDisconnected", "ixRaceInject", function(client)
	ix.raceinject.busy[client] = nil

	timer.Remove("ixRaceTransform" .. client:SteamID64())
end)

ix.log.AddType("raceInject", function(client, item, from, to, duration)
	return string.format("%s used %s: %s -> %s%s.", client:Name(), item, from,
		to, (duration or 0) > 0
			and string.format(" for %ds", duration) or " permanently")
end, FLAG_WARNING)
