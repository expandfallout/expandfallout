--[[
	Where a weapon hurts, and how much.

	Every weapon follows a PROFILE - head, body and limb multipliers - and the
	profile is a named set rather than three numbers per weapon. A sniper rifle
	and a marksman rifle want the same shape, and naming it means changing that
	shape once instead of finding every rifle that shares it.

	    default    2 / 1 / 1      the base game's own headshot, unchanged
	    rifle      2 / 1.5 / 1
	    sniper     3 / 1.5 / 1
	    pistol     2 / 1 / 0.9
	    shotgun    1.5 / 1.25 / 1
	    energy     2 / 1.25 / 1
	    melee      1.5 / 1 / 1
	    explosive  1 / 1 / 1      blast does not care where it lands

	A weapon with no profile of its own gets one from its `SWEP.Type`, so the
	259 weapons are all covered without a line each - and an override is stored
	per weapon in `ix.data` for the ones that should not follow their type.

	THE BASE GAME ALREADY MULTIPLIES HEADSHOTS BY 2. `gamemodes/base` does
	`dmginfo:ScaleDamage(2)` in its own `ScalePlayerDamage`, which runs AFTER
	every `hook.Add` listener - so a profile's head number is reached by
	scaling by `head / 2` here and letting the base game supply the rest.
	`sv_armor.lua` had to work this out for power armour and says the same
	thing at more length; this is the second thing to need it.
]]

ix.hitgroup = ix.hitgroup or {}

--- What the base gamemode applies to a head on its own, after our hooks.
ix.hitgroup.baseHead = 2

--[[
	`dismember` IS THE CHANCE, IN PER CENT, THAT A KILLING BLOW TAKES THE LIMB.

	It lives on the profile rather than in the dismemberment library because it
	is a property of the CALIBRE, which is what a profile already is: a .308
	takes an arm off and a 10mm does not, and that is the same fact as a .308
	hitting harder on a head. Phoenix keep both on one table for the same
	reason - see `plugins/dismemberment/sh_plugin.lua`, whose `DismenberChance`
	these numbers are.

	`libs/sh_dismember.lua` reads it and nothing else writes it.
]]
ix.hitgroup.profiles = {
	default = {name = "Default", head = 2, body = 1, limb = 1, dismember = 25},
	rifle = {name = "Rifle", head = 2, body = 1.5, limb = 1, dismember = 80},
	sniper = {name = "Sniper", head = 3, body = 1.5, limb = 1, dismember = 100},
	pistol = {name = "Pistol", head = 2, body = 1, limb = 0.9, dismember = 25},

	--[[
		A REVOLVER IS NOT A PISTOL HERE, and it was until dismemberment made
		the difference visible.

		Phoenix grade one at x3 on a head and a certain dismemberment, next to
		a pistol's x1.5 and one-in-four - the widest gap between any two of
		their calibres. Both were mapped onto `pistol`, so a .44 behaved like a
		10mm, which was defensible while the only difference was a damage
		number and is not once a hand cannon is meant to take a head off.
	]]
	revolver = {name = "Revolver", head = 3, body = 1, limb = 1,
		dismember = 100},

	smg = {name = "SMG", head = 1.75, body = 1, limb = 1, dismember = 25},
	shotgun = {name = "Shotgun", head = 1.5, body = 1.25, limb = 1,
		dismember = 50},
	energy = {name = "Energy", head = 2, body = 1.25, limb = 1,
		dismember = 80},
	heavy = {name = "Heavy", head = 1.5, body = 1.25, limb = 1,
		dismember = 50},

	--[[
		MELEE IS PHOENIX'S ONE GAP. They have no melee calibre at all, so a
		machete falls through to their `Rifle` default and dismembers four
		times out of five - which is not a decision anybody made. Half, here:
		a blade takes limbs, and a sledgehammer taking one every other swing is
		enough to be a thing people talk about without being every fight.
	]]
	melee = {name = "Melee", head = 1.5, body = 1, limb = 1, dismember = 50},

	explosive = {name = "Explosive", head = 1, body = 1, limb = 1,
		dismember = 100}
}

--[[
	`SWEP.Type` to a profile, for everything with no override.

	The types are the addon's own words; see `_docs/tools/blueprints.py`, which
	reads the same field to choose an icon. Anything unlisted falls through to
	`default`, which is the base game's behaviour and therefore never a
	surprise.
]]
ix.hitgroup.byType = {
	Pistol = "pistol", Revolver = "revolver",
	SMG = "smg",
	Rifle = "rifle", Marksman = "sniper", Sniper = "sniper",
	Shotgun = "shotgun",
	Energy = "energy",
	Heavy = "heavy",
	Explosive = "explosive", Grenade = "explosive",
	Blade = "melee", Blunt = "melee", Blund = "melee",
	Spear = "melee", Unarmed = "melee", Classic = "melee"
}

--- `[weapon uniqueID] = profile id`. Admin overrides, from `ix.data`.
ix.hitgroup.overrides = ix.hitgroup.overrides or {}

--- Every profile id, sorted, for a menu.
function ix.hitgroup.All()
	local out = {}

	for id in pairs(ix.hitgroup.profiles) do out[#out + 1] = id end

	table.sort(out)

	return out
end

--[[
	Which profile a weapon item follows.

	The override first, then its weapon type, then the default. The type is
	read off the SWEP because that is where it is already written down - a copy
	on the item would be a second thing to keep in step.
]]
function ix.hitgroup.ProfileID(uniqueID)
	if (ix.hitgroup.overrides[uniqueID]) then
		local id = ix.hitgroup.overrides[uniqueID]

		if (ix.hitgroup.profiles[id]) then return id end
	end

	local itemTable = ix.item.list[uniqueID]

	if (not itemTable or not itemTable.class) then return "default" end

	local swep = weapons.GetStored(itemTable.class)
	local kind = swep and swep.Type

	--[[
		Melee weapons carry a NUMBER in `SWEP.Type` - the melee base grades
		them 1 to 4 - where the ranged ones carry a string. A number would
		index nothing here, so the class name is what identifies them instead.
	]]
	if (not isstring(kind)) then
		if (string.StartWith(itemTable.class, "meleearts")) then
			return "melee"
		end

		return "default"
	end

	return ix.hitgroup.byType[kind] or "default"
end

function ix.hitgroup.Profile(uniqueID)
	return ix.hitgroup.profiles[ix.hitgroup.ProfileID(uniqueID)]
		or ix.hitgroup.profiles.default
end

--[[
	The multiplier for one hitgroup under one profile.

	`HITGROUP_GEAR` is what Source reports for a lot of hits that are not
	really anywhere - it is the fallback the engine uses - so it counts as the
	body rather than as a limb, which is what the base game does with it too.
]]
function ix.hitgroup.Multiplier(profile, hitgroup)
	if (hitgroup == HITGROUP_HEAD) then return profile.head end

	if (hitgroup == HITGROUP_LEFTARM or hitgroup == HITGROUP_RIGHTARM
	or hitgroup == HITGROUP_LEFTLEG or hitgroup == HITGROUP_RIGHTLEG) then
		return profile.limb
	end

	return profile.body
end

--------------------------------------------------------------------------------
-- Saying it
--------------------------------------------------------------------------------

--[[
	Trim a multiplier to something readable.

	`%.2g` turns 1.5 into "1.5" and 2 into "2" without a trailing ".0", which
	is what makes a list of them read like a list rather than a table of
	decimals.
]]
function ix.hitgroup.Format(value)
	return string.format("%.4g", value)
end

--[[
	The three lines a weapon's description ends with.

	Written here rather than in the description code so the numbers a player
	reads and the numbers the damage hook applies come out of one function - a
	description that disagreed with the damage would be worse than none.
]]
function ix.hitgroup.Describe(uniqueID, rarityMultiplier)
	local profile = ix.hitgroup.Profile(uniqueID)
	local lines = {}

	for _, row in ipairs({
		{"Head", "head", profile.head}, {"Body", "body", profile.body},
		{"Legs", "limb", profile.limb}
	}) do
		local base, bStatic = row[3], false

		--[[
			THE WEAPON'S OWN MULTIPLIERS WIN, when it has been given any.

			`ix.combat.Multiplier` answers with the profile's number for every
			weapon nobody has edited, so this reads the same as it always did
			until somebody opens `/liveedit` - and once they have, the
			description says what the weapon actually does rather than what its
			profile would have done.

			Guarded because `sh_livecombat.lua` is a separate library and this
			one predates it.
		]]
		if (ix.combat and ix.combat.Multiplier) then
			base, bStatic = ix.combat.Multiplier(uniqueID, row[2])
		end

		--[[
			A STATIC MULTIPLIER SAYS SO, because the rarity column would
			otherwise be a promise the damage hook does not keep: static means
			quality is ignored entirely for that hitgroup, and a Legendary one
			hits exactly as hard there as a Common one.
		]]
		if (bStatic) then
			lines[#lines + 1] = string.format("* %s: %sx [fixed]", row[1],
				ix.hitgroup.Format(base))
		elseif (rarityMultiplier and rarityMultiplier ~= 1) then
			lines[#lines + 1] = string.format("* %s: %sx [%sx - Rarity]",
				row[1], ix.hitgroup.Format(base),
				ix.hitgroup.Format(base * rarityMultiplier))
		else
			lines[#lines + 1] = string.format("* %s: %sx", row[1],
				ix.hitgroup.Format(base))
		end
	end

	return table.concat(lines, "\n")
end

--------------------------------------------------------------------------------
-- What a weapon does on paper
--------------------------------------------------------------------------------

--[[
	Base damage and rate of fire, read from the SWEP.

	From `weapons.GetStored` rather than a live entity, because the description
	is drawn for a weapon sitting in a bag that has never been held. Returns
	nil for anything that is not a weapon or has no numbers to report - a
	grenade has no rate of fire and saying "RPM: 0" would be worse than saying
	nothing.

	Melee weapons carry `DmgMin`/`DmgMax` and a `Delay` instead of a `Primary`
	table, which is the same split `ix.special.GetWeaponDamage` already has to
	handle for the live entity.
]]
function ix.hitgroup.Stats(uniqueID)
	local itemTable = ix.item.list[uniqueID]

	if (not itemTable or not itemTable.class) then return nil end

	local swep = weapons.GetStored(itemTable.class)

	if (not swep) then return nil end

	local damage, delay

	if (swep.DmgMax or swep.DmgMin) then
		damage = swep.DmgMax or swep.DmgMin
		delay = swep.Delay
	elseif (swep.Primary) then
		damage = swep.Primary.Damage
		delay = swep.Primary.Delay
	end

	if (not damage or damage <= 0) then return nil end

	return damage, (delay and delay > 0) and math.Round(60 / delay) or nil
end
