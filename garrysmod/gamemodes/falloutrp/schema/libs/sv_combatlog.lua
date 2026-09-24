--[[
	Combat: every shot that lands, and every death.

	"Who shot first" is the single most common question an admin gets, and
	neither Helix nor this schema could answer it - Helix logs a death and
	nothing about how it happened.

	    every hit          attacker, victim, weapon, hitgroup, damage
	    every death        with the last thirty seconds of hits attached
	    every heal         because a fight nobody can win is worth seeing too

	DAMAGE IS SUMMARISED, NOT LOGGED PER BULLET. A minigun does twenty hits a
	second and an SMG fight between four people would write more lines in a
	minute than a whole evening of anything else - and a log nobody can read is
	the same as no log. Hits are accumulated per attacker-victim-weapon and
	flushed as ONE entry when the exchange stops, which is what somebody
	reading it actually wants: "Bob hit Alice 14 times for 210 with an AK47",
	not fourteen lines.

	THE RECENT-HITS TABLE IS THE POINT. A death entry carries who hit the
	victim in the last thirty seconds, in order, so "who shot first" is
	answered by the death line itself rather than by scrolling.
]]

if (not SERVER) then return end

ix.combatlog = ix.combatlog or {}

--- How long an exchange can pause before it is flushed as finished.
local FLUSH_AFTER = 6

--- How far back a death looks for who was involved.
local RECENT = 30

--[[
	`[victim steamID] = { {time, attacker, name, weapon, damage}, ... }`

	Kept per victim rather than per attacker, because the question is always
	asked from the body backwards.
]]
ix.combatlog.recent = ix.combatlog.recent or {}

--- `[key] = {attacker, victim, weapon, hits, damage, first, last}`
ix.combatlog.pending = ix.combatlog.pending or {}

local function HitgroupName(hitgroup)
	if (hitgroup == HITGROUP_HEAD) then return "head" end
	if (hitgroup == HITGROUP_CHEST) then return "chest" end
	if (hitgroup == HITGROUP_STOMACH) then return "stomach" end

	if (hitgroup == HITGROUP_LEFTARM or hitgroup == HITGROUP_RIGHTARM) then
		return "arm"
	end

	if (hitgroup == HITGROUP_LEFTLEG or hitgroup == HITGROUP_RIGHTLEG) then
		return "leg"
	end

	return "body"
end

--[[
	Write one accumulated exchange out and forget it.

	Named so the flush can be called from the timer, from a death, and from a
	disconnect - all three end an exchange, and only the first is a timeout.
]]
function ix.combatlog.Flush(key)
	local entry = ix.combatlog.pending[key]

	if (not entry) then return end

	ix.combatlog.pending[key] = nil

	ix.log.Add(entry.attacker, "combatHits", entry.attackerName,
		entry.victimName, entry.victimSteamID, entry.weapon, entry.hits,
		math.Round(entry.damage), table.concat(entry.groups, "/"),
		math.Round(entry.last - entry.first, 1))
end

ix.log.AddType("combatHits", function(client, attacker, victim, steamID,
	weapon, hits, damage, groups, seconds)
	return string.format(
		"%s hit %s (%s) %d time(s) for %d with %s [%s] over %ss", attacker,
		victim, steamID, hits, damage, weapon, groups, seconds)
end, FLAG_WARNING)

--------------------------------------------------------------------------------
-- Taking damage
--------------------------------------------------------------------------------

hook.Add("ScalePlayerDamage", "ixCombatLog", function(client, hitgroup, info)
	local attacker = info:GetAttacker()
	local damage = info:GetDamage()

	if (damage <= 0) then return end

	--[[
		Runs LAST, after everything that scales damage - `sv_armor.lua`, the
		rarity multiplier, the hitgroup profile - because the number worth
		recording is the one the victim actually loses, not the one the weapon
		started with. `hook.Add` listeners run before the gamemode's own
		method, and the base game's headshot doubling happens after this, so
		a head reads slightly low; that is noted rather than corrected,
		because correcting it would mean duplicating the base game's formula
		here and having two copies to keep in step.
	]]
	local name = IsValid(attacker) and attacker:IsPlayer()
		and attacker:Name() or (IsValid(attacker) and attacker:GetClass()
		or "the world")

	if (not IsValid(attacker) or not attacker:IsPlayer()) then
		--[[
			Falls, drowning, radiation and NPCs are not an "exchange" and
			would never be flushed by a second hit, so they are written
			straight out rather than accumulated.
		]]
		ix.log.Add(client, "combatEnvironment", name,
			math.Round(damage), HitgroupName(hitgroup))

		return
	end

	local weapon = attacker:GetActiveWeapon()
	local weaponName = IsValid(weapon) and weapon:GetClass() or "nothing"
	local key = attacker:SteamID() .. ">" .. client:SteamID() .. ">"
		.. weaponName

	local entry = ix.combatlog.pending[key]

	if (not entry) then
		entry = {
			attacker = attacker,
			attackerName = attacker:Name(),
			victimName = client:Name(),
			victimSteamID = client:SteamID(),
			weapon = weaponName,
			hits = 0, damage = 0, groups = {},
			first = CurTime()
		}

		ix.combatlog.pending[key] = entry
	end

	entry.hits = entry.hits + 1
	entry.damage = entry.damage + damage
	entry.last = CurTime()

	--[[
		Only the first eight hitgroups are kept. A forty-round burst would
		otherwise produce a line of forty slash-separated words, and the shape
		of a fight is clear from the first few.
	]]
	if (#entry.groups < 8) then
		entry.groups[#entry.groups + 1] = HitgroupName(hitgroup)
	end

	--- The victim's own recent list, for whatever kills them.
	local recent = ix.combatlog.recent[client:SteamID()] or {}

	recent[#recent + 1] = {
		time = CurTime(),
		name = attacker:Name(),
		steamID = attacker:SteamID(),
		weapon = weaponName,
		damage = damage
	}

	ix.combatlog.recent[client:SteamID()] = recent
end)

ix.log.AddType("combatEnvironment", function(client, source, damage, group)
	return string.format("%s took %d from %s (%s).", client:Name(), damage,
		source, group)
end)

--------------------------------------------------------------------------------
-- Dying
--------------------------------------------------------------------------------

--[[
	Who was hitting this player recently, newest last.

	Trimmed as it is read rather than on a timer: the list only matters at the
	moment somebody dies, and doing it here means no timer walking every
	player's history every second for the benefit of nobody.
]]
function ix.combatlog.Recent(steamID)
	local list = ix.combatlog.recent[steamID]

	if (not list) then return {} end

	local cutoff = CurTime() - RECENT
	local out = {}

	for _, hit in ipairs(list) do
		if (hit.time >= cutoff) then out[#out + 1] = hit end
	end

	ix.combatlog.recent[steamID] = out

	return out
end

hook.Add("PlayerDeath", "ixCombatLog", function(client, inflictor, attacker)
	--[[
		Every pending exchange involving this player is flushed first, so the
		hits that caused the death are written BEFORE the death rather than
		six seconds after it. A log where the death precedes the shots that
		caused it is a log that has to be read backwards.
	]]
	local steamID = client:SteamID()

	for key in pairs(ix.combatlog.pending) do
		if (string.find(key, steamID, 1, true)) then
			ix.combatlog.Flush(key)
		end
	end

	local involved = {}

	for _, hit in ipairs(ix.combatlog.Recent(steamID)) do
		involved[#involved + 1] = string.format("%s (%s) %d",
			hit.name, hit.weapon, math.Round(hit.damage))
	end

	ix.log.Add(client, "combatDeath",
		IsValid(attacker) and attacker:IsPlayer() and attacker:Name()
			or (IsValid(attacker) and attacker:GetClass() or "the world"),
		IsValid(attacker) and attacker:IsPlayer() and attacker:SteamID()
			or "",
		IsValid(inflictor) and inflictor:GetClass() or "",
		#involved > 0 and table.concat(involved, ", ") or "nobody recently",
		tostring(client:GetPos()))

	ix.combatlog.recent[steamID] = nil
end)

ix.log.AddType("combatDeath", function(client, killer, steamID, inflictor,
	involved, position)
	return string.format("%s was killed by %s%s%s at %s - recent: %s",
		client:Name(), killer,
		steamID ~= "" and (" (" .. steamID .. ")") or "",
		inflictor ~= "" and (" with " .. inflictor) or "", position, involved)
end, FLAG_DANGER)

--------------------------------------------------------------------------------
-- Healing
--------------------------------------------------------------------------------

--[[
	Health going UP, which nothing else records.

	A fight where somebody could not be killed reads as a bug until you can see
	that they drank nine stimpaks, and that is not visible from the damage log
	alone.
]]
hook.Add("PlayerPostThink", "ixCombatLog", function(client)
	local health = client:Health()
	local last = client.ixLastHealth or health

	if (health > last and client:Alive()) then
		local gained = health - last

		--[[
			Only a jump worth reading. Regeneration ticking one point at a time
			would write a line a second per player, which is the noise this
			whole file is arranged to avoid.
		]]
		if (gained >= 5) then
			ix.log.Add(client, "combatHeal", gained, health)
		end
	end

	client.ixLastHealth = health
end)

ix.log.AddType("combatHeal", function(client, gained, total)
	return string.format("%s healed %d to %d.", client:Name(), gained, total)
end, FLAG_SUCCESS)

--------------------------------------------------------------------------------
-- Flushing
--------------------------------------------------------------------------------

--[[
	One timer over the pending exchanges, rather than a timer per exchange.

	The same reasoning as the bench tick and the capture tick: a timer per
	thing has to be cancelled from everywhere the thing can end, and that list
	is never complete.
]]
timer.Create("ixCombatLogFlush", 2, 0, function()
	local now = CurTime()

	for key, entry in pairs(ix.combatlog.pending) do
		if (now - entry.last > FLUSH_AFTER) then
			ix.combatlog.Flush(key)
		end
	end
end)

hook.Add("PlayerDisconnected", "ixCombatLog", function(client)
	local steamID = client:SteamID()

	for key in pairs(ix.combatlog.pending) do
		if (string.find(key, steamID, 1, true)) then
			ix.combatlog.Flush(key)
		end
	end

	ix.combatlog.recent[steamID] = nil
end)
