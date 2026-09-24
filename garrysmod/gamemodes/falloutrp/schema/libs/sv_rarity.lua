--[[
	Rolling weapon quality, and making it mean something.

	See `sh_rarity.lua` for the tiers and the curve.

	ROLLED WHEN IT IS MADE, not when it is used. The tier is a fact about the
	object from the moment it exists, so it goes in item data next to the stack
	count and the bench experience - which means it survives being dropped,
	traded, stored and restarted, and cannot be re-rolled by putting the weapon
	down and picking it up again.
]]

if (not SERVER) then return end

--[[
	Give a crafted weapon a quality.

	Only WEAPONS get one. A tier on a stimpak is a damage multiplier on
	something that does no damage, and a coloured border on it would promise
	the player something the item cannot deliver.
]]
function ix.rarity.Apply(item, character)
	if (not item or not item.uniqueID) then return nil end

	local itemTable = ix.item.list[item.uniqueID]

	if (not itemTable or itemTable.base ~= "base_weapons") then return nil end

	local id = ix.rarity.Roll(ix.rarity.LuckOf(character))

	item:SetData("rarity", id)

	return id
end

--[[
	Does this item id get a quality if it is crafted?

	Asked BEFORE anything is made, because `ix.bench.Produce` may create
	several items and the answer is the same for all of them - and because the
	bench needs to know whether to bother telling anybody about the roll.
]]
function ix.rarity.Applies(uniqueID)
	local itemTable = ix.item.list[uniqueID]

	return itemTable ~= nil and itemTable.base == "base_weapons"
end

--------------------------------------------------------------------------------
-- Damage
--------------------------------------------------------------------------------

--[[
	The quality of the weapon that fired, applied to what it hits.

	`ScalePlayerDamage` would be the obvious hook and it is the wrong one: it
	only fires for players, so a Legendary rifle would do its extra damage to
	people and nothing extra to an NPC or a deathclaw. `EntityTakeDamage`
	covers everything that can be hurt.

	It reads the ITEM, not the weapon. `weapon.ixItem` is the link Helix's
	weapon base sets when one is equipped, and the item is where the rarity
	lives - so a weapon dropped and picked up by somebody else keeps its
	quality, and one spawned by an admin has none and scales by 1.
]]
hook.Add("EntityTakeDamage", "ixRarity", function(target, damageInfo)
	local attacker = damageInfo:GetAttacker()

	if (not IsValid(attacker) or not attacker:IsPlayer()) then return end

	local weapon = attacker:GetActiveWeapon()

	if (not IsValid(weapon)) then return end

	--- `ixItem` is set here, but the accessor keeps the two realms honest.
	local item = ix.rarity.HeldItem(attacker, weapon)

	if (not item) then return end

	--[[
		THE QUALITY MULTIPLIER, CAPPED BY THE WEAPON.

		`ix.combat.RarityDamage` is `ix.rarity.Damage` with the weapon's own
		ceiling applied - see `sh_livecombat.lua`. A weapon with no ceiling set
		gets exactly what it always did.

		It is applied BELOW rather than here, because a STATIC hit multiplier
		replaces it entirely and this hook must not have already scaled by it.
	]]
	local multiplier = ix.combat and ix.combat.RarityDamage(item)
		or ix.rarity.Damage(item)

	--[[
		The hitgroup profile, applied here too because it needs the same two
		things - the weapon that fired and the item behind it - and reading
		them twice in two hooks is two places for them to disagree.

		`LastHitGroup` rather than an argument, because `EntityTakeDamage` is
		not given one. It is set by the engine immediately before this fires
		for a player, and it is the same value `ScalePlayerDamage` would have
		been handed.
	]]
	if (not target.LastHitGroup) then
		--- Nothing to place the hit in, so quality is all there is.
		if (multiplier ~= 1) then damageInfo:ScaleDamage(multiplier) end

		return
	end

	--- Placed by bone where the model's hitboxes say nothing; see `Hitgroup`.
	local hitgroup = ix.dismember and ix.dismember.Hitgroup
		and ix.dismember.Hitgroup(target, target:LastHitGroup(),
			damageInfo:GetDamagePosition())
		or target:LastHitGroup()

	--[[
		THE WEAPON'S OWN MULTIPLIER, IF IT HAS ONE.

		`ix.combat.Multiplier` answers with the weapon's static number, then
		its scaled one, then the shared profile's - and says which it was. A
		STATIC multiplier is the whole of the scaling: quality is deliberately
		not applied at all, because "this weapon does exactly this on a head"
		is the thing it exists to express.
	]]
	local scale, static

	if (ix.combat) then
		scale, static = ix.combat.Multiplier(item.uniqueID,
			ix.combat.GroupOf(hitgroup))
	else
		scale = ix.hitgroup.Multiplier(ix.hitgroup.Profile(item.uniqueID),
			hitgroup)
	end

	if (not static and multiplier ~= 1) then
		damageInfo:ScaleDamage(multiplier)
	end

	--[[
		A HEAD IS ALREADY DOUBLED BY THE BASE GAMEMODE, whose own
		`ScalePlayerDamage` runs after every `hook.Add` listener. So the head
		is scaled by `head / 2` and the base game supplies the rest, landing on
		exactly the profile's number. Anything else is scaled as written,
		because nothing else is touched later.

		Only players get that treatment - `ScalePlayerDamage` is a player hook -
		so an NPC head takes the profile straight.
	]]
	if (hitgroup == HITGROUP_HEAD and target:IsPlayer()) then
		scale = scale / ix.hitgroup.baseHead
	end

	if (scale ~= 1) then
		damageInfo:ScaleDamage(scale)
	end
end)

--------------------------------------------------------------------------------
-- Telling people
--------------------------------------------------------------------------------

ix.log.AddType("rarityCraft", function(client, name, tier)
	return string.format("%s crafted a %s %s.", client:Name(), tier, name)
end)
