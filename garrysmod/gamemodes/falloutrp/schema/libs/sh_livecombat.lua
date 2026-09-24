--[[
	Per-weapon combat settings: what a hit is worth, and how far quality can
	push it.

	The hitgroup profiles in `sh_hitgroup.lua` are shared - every rifle uses the
	rifle profile - which is right for a roster of two hundred weapons and wrong
	for the handful that are meant to be special. These are the exceptions, and
	they are edited in `/liveedit` alongside the damage.

	FOUR SETTINGS, and the difference between two of them is the whole point:

	    profile     which shared profile this weapon follows. The existing
	                override from `ix.hitgroup.overrides`
	    scaled      head/body/limb multipliers for THIS weapon, replacing the
	                profile's. Quality still multiplies on top, so a Legendary
	                one hits harder - this is a weapon that is simply better at
	                headshots
	    static      head/body/limb multipliers that quality does NOT touch. The
	                damage is what it says whatever the weapon rolled, which is
	                how you write a weapon whose whole identity is a fixed
	                number - a syringe, a called shot, a wrench
	    cap         the highest quality multiplier this weapon may reach. A
	                Pearlescent minigun is 2x on a weapon that fires nine
	                hundred rounds a minute; this is the dial that says no

	WHERE THEY ARE READ: `sv_rarity.lua`'s damage hook, which already had the
	profile and the quality multiplier in one place. Everything here narrows
	what that hook does rather than adding a second one - two hooks scaling the
	same damage is how a number ends up squared.
]]

ix.combat = ix.combat or {}

--- `[weapon uniqueID] = {scaled = {...}, static = {...}, cap = number}`.
ix.combat.settings = ix.combat.settings or {}

--- The three places a bullet can land, in the order they are shown.
ix.combat.groups = {"head", "body", "limb"}

--[[
	What is set for one weapon. Never nil, and never the stored table - a
	caller reading `.static.head` must not be able to write it back by
	accident.
]]
function ix.combat.Get(uniqueID)
	local stored = ix.combat.settings[uniqueID] or {}

	return {
		scaled = istable(stored.scaled) and stored.scaled or nil,
		static = istable(stored.static) and stored.static or nil,
		rarity = istable(stored.rarity) and stored.rarity or nil,
		cap = tonumber(stored.cap) or 0
	}
end

--[[
	What one QUALITY TIER is worth on this weapon.

	`ix.rarity.tiers` gives every weapon the same ladder - Legendary is always
	1.4x - and this is the per-weapon exception: a minigun whose Legendary is
	1.1 and a hunting rifle whose Pearlescent is 3 are both reasonable, and
	neither can be said with one shared table.

	Falls through to the tier's own number, so a weapon nobody has touched is
	exactly as it was.
]]
function ix.combat.TierDamage(uniqueID, tierID)
	local stored = ix.combat.Get(uniqueID).rarity
	local own = stored and tonumber(stored[tierID])

	if (own) then return own end

	return ix.rarity.Tier(tierID).damage or 1
end

--[[
	The multiplier for one hitgroup, and whether quality applies to it.

	Returns `multiplier, bStatic`. The caller needs both because a static
	multiplier is not "a multiplier that happens to ignore rarity" - it
	REPLACES the rarity scaling entirely, and the caller is the only thing that
	knows what rarity it was about to apply.
]]
function ix.combat.Multiplier(uniqueID, group)
	local settings = ix.combat.Get(uniqueID)

	if (settings.static and tonumber(settings.static[group])) then
		return tonumber(settings.static[group]), true
	end

	if (settings.scaled and tonumber(settings.scaled[group])) then
		return tonumber(settings.scaled[group]), false
	end

	local profile = ix.hitgroup.Profile(uniqueID)

	return profile[group] or 1, false
end

--[[
	The quality multiplier a weapon may reach, clamped to its own ceiling.

	0 means no ceiling, which is every weapon until somebody sets one - so this
	is the identity function on a server that has not touched it.
]]
function ix.combat.RarityDamage(item)
	if (not item or not item.uniqueID) then return ix.rarity.Damage(item) end

	--[[
		THE WEAPON'S OWN LADDER FIRST, then the shared one. `ix.rarity.Get`
		answers nil for anything never rolled, which is 1x either way.
	]]
	local tier = ix.rarity.Get(item)
	local multiplier = tier and ix.combat.TierDamage(item.uniqueID, tier) or 1

	local cap = ix.combat.Get(item.uniqueID).cap

	if (cap > 0) then return math.min(multiplier, cap) end

	return multiplier
end

--[[
	Which hitgroup a hit landed in, as one of the three words.

	`sh_hitgroup.lua` answers the same question for its own table; this exists
	so the damage hook can ask once and use the answer for both.
]]
function ix.combat.GroupOf(hitgroup)
	if (hitgroup == HITGROUP_HEAD) then return "head" end

	if (hitgroup == HITGROUP_CHEST or hitgroup == HITGROUP_STOMACH
	or hitgroup == HITGROUP_GENERIC) then
		return "body"
	end

	return "limb"
end
