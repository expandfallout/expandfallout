--[[
	Healing over time, interrupted by damage.

	A stimpak does not put health back instantly. It runs for a few seconds and
	STOPS THE MOMENT YOU ARE HIT, which is the whole reason it is a system
	rather than a number: healing becomes something you have to break contact
	to do, and using one mid-firefight is a waste of a stimpak rather than a
	free reset.

	ONE HEAL AT A TIME, and a second one replaces the first rather than
	stacking. Two stimpaks at once would otherwise heal twice as fast for the
	same total, which makes the interruption meaningless - you would simply use
	three and outrun the damage.

	Whatever is left when it is interrupted is LOST. That is the cost of being
	shot while patching yourself up, and it is what makes the timing a
	decision.
]]

if (not SERVER) then return end

util.AddNetworkString("ixHealTick")

--[[
	How often a heal ticks.

	Four times a second: fine enough that the health bar moves smoothly and
	coarse enough that a hundred players healing at once is four hundred
	arithmetic operations a second rather than six thousand.
]]
local TICK = 0.25

ix.healing = ix.healing or {}

--[[
	Begin healing somebody over time.

	`amount` is the TOTAL, and `duration` is how long it takes to deliver -
	so a stimpak's numbers read the same as an instant one and only the
	delivery changes.
]]
function ix.healing.Begin(client, amount, duration, label)
	if (not IsValid(client) or not client:Alive()) then return false end

	amount = math.max(tonumber(amount) or 0, 0)
	duration = math.max(tonumber(duration) or 0, TICK)

	if (amount <= 0) then return false end

	client.ixHeal = {
		remaining = amount,
		perTick = amount / (duration / TICK),
		label = label,
		--[[
			The health the player had when this started, so a heal can be
			told apart from any other reason health went down. See the damage
			hook below.
		]]
		lastHealth = client:Health()
	}

	return true
end

function ix.healing.Stop(client, reason)
	if (not IsValid(client) or not client.ixHeal) then return end

	local lost = math.Round(client.ixHeal.remaining)

	client.ixHeal = nil

	if (reason and lost > 0) then
		client:Notify(string.format(
			"Your treatment was interrupted - %d health lost.", lost))
	end
end

function ix.healing.IsHealing(client)
	return IsValid(client) and client.ixHeal ~= nil
end

timer.Create("ixHealing", TICK, 0, function()
	for _, client in player.Iterator() do
		local heal = client.ixHeal

		if (not heal) then continue end

		if (not client:Alive()) then
			client.ixHeal = nil
			continue
		end

		local maximum = client:GetMaxHealth()
		local current = client:Health()

		if (current >= maximum) then
			--[[
				Already full. The heal ENDS rather than pausing: a stimpak used
				at full health is a wasted stimpak, which is the same answer
				the games give.
			]]
			client.ixHeal = nil
			continue
		end

		local step = math.min(heal.perTick, heal.remaining, maximum - current)

		client:SetHealth(math.min(current + step, maximum))

		heal.remaining = heal.remaining - step
		--[[
			Recorded AFTER the heal, so the damage hook below compares against
			what this system last set rather than against a stale number.
		]]
		heal.lastHealth = client:Health()

		if (heal.remaining <= 0.01) then
			client.ixHeal = nil
		end
	end
end)

--[[
	Being hit stops it.

	`PlayerHurt` rather than `EntityTakeDamage`, because this only cares that
	damage actually landed - a shot that armour absorbed entirely did not
	interrupt anything, and neither did a hit on somebody else.

	Fall damage counts. Walking off a ledge while patching yourself up is
	being hit.
]]
hook.Add("PlayerHurt", "ixHealing", function(client, attacker, remaining, taken)
	if (not client.ixHeal or taken <= 0) then return end

	ix.healing.Stop(client, "hurt")
end)

hook.Add("PlayerDeath", "ixHealing", function(client)
	client.ixHeal = nil
end)

hook.Add("PlayerSpawn", "ixHealing", function(client)
	client.ixHeal = nil
end)
