--[[
	Weapon quality.

	Every weapon that comes off a bench is rolled for a tier, and the tier is
	a damage multiplier and a coloured border. It is what makes crafting the
	same weapon twice worth doing, and what makes Luck worth spending points
	on after the loot tables have had their say.

	    Common        1.0x   white
	    Uncommon      1.1x   lime
	    Rare          1.2x   lapis
	    Superior      1.3x   eggplant
	    Legendary     1.4x   orange
	    Master Craft  1.5x   rainbow
	    Pearlescent   2.0x   neon cyan

	THE CURVE IS ANCHORED AT 50 LUCK, which is where the numbers were given:

	    Superior 20%, Legendary 5%, Master Craft 1%, Pearlescent 0.1%,
	    Rare the rest, and no Common or Uncommon at all.

	Everything below that is derived from the same three rules rather than
	written as a table of breakpoints - a table would have to be kept
	consistent with itself, and this cannot be inconsistent:

	  1. the four top tiers scale LINEARLY with luck to those percentages
	  2. Common fades out by 25 luck, Uncommon by 50
	  3. Rare takes whatever is left

	At 50 that lands exactly on the numbers above, because Common and Uncommon
	have both reached zero and Rare is the only thing left holding the
	remainder. See `ix.rarity.Chances`.
]]

ix.rarity = ix.rarity or {}

--[[
	The Luck the curve is written against.

	NOT THE SAME AS THE SKILL POINT CAP, which stays at 25
	(`ix.config.Get("maxAttributes")`) and is deliberately untouched. 25 is
	what a character can BUY; 50 is what they can reach wearing and taking the
	right things, because `ix.special.Get` adds buff modifiers on top without
	clamping to the buyable ceiling.

	So the top of this curve is a place you get to by kitting out for it rather
	than by spending points, which is the difference between a build and a
	preparation - and it is why raising `maxAttributes` to 50 would have been
	the wrong fix: it would have moved stamina, damage and run speed with it
	and made the top of the curve free.
]]
ix.rarity.maxLuck = 50

--[[
	In order, worst to best. The index is the rank and the id is what is
	stored on the item - never the index, which would re-point every stored
	rarity if a tier were ever inserted in the middle.
]]
ix.rarity.tiers = {
	{
		id = "common", name = "Common", damage = 1.0,
		color = Color(230, 230, 230)
	},
	{
		id = "uncommon", name = "Uncommon", damage = 1.1,
		color = Color(130, 225, 70)
	},
	{
		id = "rare", name = "Rare", damage = 1.2,
		color = Color(60, 120, 225)
	},
	{
		id = "superior", name = "Superior", damage = 1.3,
		color = Color(140, 70, 175)
	},
	{
		id = "legendary", name = "Legendary", damage = 1.4,
		color = Color(255, 150, 40)
	},
	{
		--[[
			Rainbow is drawn rather than stored - see `ix.rarity.GetColor`.
			The flat colour here is what anything that cannot animate falls
			back to, and what the chat and the logs print.
		]]
		id = "master", name = "Master Craft", damage = 1.5,
		color = Color(255, 120, 200), rainbow = true
	},
	{
		id = "pearlescent", name = "Pearlescent", damage = 2.0,
		color = Color(40, 255, 240)
	}
}

--- `[id] = tier`, built once.
ix.rarity.byID = {}

for index, tier in ipairs(ix.rarity.tiers) do
	tier.index = index

	ix.rarity.byID[tier.id] = tier
end

--- The tier something is, or Common. Never nil, so callers need no guard.
function ix.rarity.Tier(id)
	return ix.rarity.byID[id] or ix.rarity.tiers[1]
end

--------------------------------------------------------------------------------
-- The curve
--------------------------------------------------------------------------------

--[[
	The chance of each tier at a given Luck, as fractions summing to 1.

	Written as weights rather than percentages for the bottom three, because
	they have to absorb exactly what the top four leave behind and any set of
	fixed percentages would have to be kept adding up by hand.
]]
function ix.rarity.Chances(luck)
	luck = math.Clamp(tonumber(luck) or 0, 0, ix.rarity.maxLuck)

	local scale = luck / ix.rarity.maxLuck

	--- Straight lines to the numbers the design names at full Luck.
	local out = {
		superior = 0.20 * scale,
		legendary = 0.05 * scale,
		master = 0.01 * scale,
		pearlescent = 0.001 * scale
	}

	local remainder = 1 - (out.superior + out.legendary + out.master
		+ out.pearlescent)

	--[[
		Common is gone by 25 and Uncommon by 50, which is the rule as given.
		Rare's weight RISES so that the three shift towards it rather than the
		remainder simply piling onto whatever is left - at full Luck the other
		two are zero and Rare has all of it, which is what makes the numbers
		land exactly.

		The starting weights - 6, 3, 1 - are the shape at zero Luck: mostly
		Common, some Uncommon, a little Rare.
	]]
	local weights = {
		common = 6 * math.max(1 - luck / 25, 0),
		uncommon = 3 * math.max(1 - luck / ix.rarity.maxLuck, 0),
		rare = 1 + 2 * scale
	}

	local total = weights.common + weights.uncommon + weights.rare

	for id, weight in pairs(weights) do
		out[id] = total > 0 and remainder * (weight / total) or 0
	end

	return out
end

--[[
	Roll one. Returns a tier id.

	Walks the tiers in order and subtracts, so the same random number always
	picks the same tier for the same chances - which is what makes the dev
	menu's sampling mean anything.
]]
function ix.rarity.Roll(luck)
	local chances = ix.rarity.Chances(luck)
	local roll = math.random()

	for _, tier in ipairs(ix.rarity.tiers) do
		local chance = chances[tier.id] or 0

		if (roll < chance) then return tier.id end

		roll = roll - chance
	end

	--[[
		Floating point can leave a sliver unaccounted for. The best tier is a
		worse answer to give away than the worst, so the fallback is Common.
	]]
	return ix.rarity.tiers[1].id
end

--- What Luck a character rolls with, capped at the curve's ceiling.
function ix.rarity.LuckOf(character)
	if (not character) then return 0 end

	return math.Clamp(ix.special.Get(character, "luck"), 0,
		ix.rarity.maxLuck)
end

--------------------------------------------------------------------------------
-- Reading it off an item
--------------------------------------------------------------------------------

--[[
	The rarity stored on an item, or nil.

	NIL RATHER THAN COMMON, deliberately: a weapon that was never rolled - one
	spawned by an admin, or from loot - is not a Common weapon, it is a weapon
	with no quality at all, and it should draw no border and claim no
	multiplier. Only crafted weapons carry one.
]]
function ix.rarity.Get(item)
	if (not item or not item.GetData) then return nil end

	local id = item:GetData("rarity")

	return id and ix.rarity.byID[id] and id or nil
end

--[[
	The item behind a weapon somebody is holding.

	`weapon.ixItem` IS SERVER-ONLY. Helix sets it in `ITEM:Equip`, which calls
	`client:Give` and therefore only ever runs on the server - so the client's
	copy of the same weapon entity has no `ixItem` at all. Reading it on the
	client returns nil, silently, and anything relying on it just quietly does
	nothing. That is exactly what made the damage readout show base damage on a
	weapon that had a rarity.

	So the client finds the item the other way round: the character's own
	inventory is synced to them, item data included, and exactly one item of
	that class is flagged `equip`. Matching on the class is what a player would
	do looking at the two lists side by side.

	The server still takes `ixItem` when it has it, because it is free and
	authoritative there.
]]
function ix.rarity.HeldItem(client, weapon)
	if (not IsValid(weapon)) then return nil end
	if (weapon.ixItem) then return weapon.ixItem end

	local character = IsValid(client) and client:GetCharacter()
	local inventory = character and character:GetInventory()

	if (not inventory) then return nil end

	local class = weapon:GetClass()

	for item in ix.inventory.Each(inventory) do
		if (item.class == class and item:GetData("equip")) then
			return item
		end
	end

	return nil
end

--- The damage multiplier of an item, 1 when it has no rarity.
function ix.rarity.Damage(item)
	local id = ix.rarity.Get(item)

	return id and ix.rarity.Tier(id).damage or 1
end

--[[
	The colour to draw, animated for Master Craft.

	`RealTime` rather than `CurTime`, so it keeps moving while the game is
	paused in a menu - which is exactly when somebody is looking at it.
]]
function ix.rarity.GetColor(id)
	local tier = ix.rarity.Tier(id)

	if (not tier.rainbow) then return tier.color end

	return HSVToColor((RealTime() * 90) % 360, 0.65, 1)
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------

if (CLIENT) then
	--[[
		The border every rarity-bearing thing draws.

		ONE FUNCTION, used by weapons, frames and blueprints alike. The
		blueprints and frames share a handful of models between hundreds of
		items, and a coloured edge is what tells them apart - the same job the
		corner tint used to do, done in a way that also reads at a glance
		across a full inventory.
	]]
	function ix.rarity.PaintBorder(colour, width, height, thickness)
		if (not colour) then return end

		thickness = thickness or 2

		surface.SetDrawColor(colour)
		surface.DrawOutlinedRect(0, 0, width, height, thickness)

		--[[
			A soft inner line, because a single hard rectangle on a busy icon
			reads as part of the model rather than as a frame around it.
		]]
		surface.SetDrawColor(ColorAlpha(colour, 60))
		surface.DrawOutlinedRect(thickness, thickness, width - thickness * 2,
			height - thickness * 2, 1)
	end

	--- The border for an item, if it has a rarity. Nothing if it does not.
	function ix.rarity.PaintItem(item, width, height)
		local id = ix.rarity.Get(item)

		if (not id) then return end

		ix.rarity.PaintBorder(ix.rarity.GetColor(id), width, height, 2)
	end
end
