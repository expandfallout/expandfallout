--[[
	Radiation.

	Ported from Phoenix's radiation plugin. The six tiers, their thresholds,
	their penalties and the 10%-of-max-health tick at 100 rads are theirs
	exactly; what changed is the naming, for the same reason it changed in
	`sh_armor.lua` - their `END`/`AGL` keys do not match the keys their own
	attribute registry uses, so those penalties silently did nothing.

	Radiation is stored on the character as plain data, `radiation`, 0-100.
	That is `isLocal` in Helix and so reaches the owning client only, which is
	all the HUD needs - nobody else has to see your rad count.

	THE ORDER OF OPERATIONS MATTERS AND IS THEIRS:

	    takesRadiation gate  ->  resistance  ->  ceil  ->  clamp 0-100

	Resistance is applied before the clamp, and `math.ceil` means any positive
	amount that survives resistance is at least 1 rad. A 90% resistant suit
	still lets 1 rad through per 10 - it slows exposure, it does not stop it.
]]

ix.radiation = ix.radiation or {}

--[[
	The six tiers, keyed by the rad level at which each begins.

	`special` penalties use this schema's attribute keys. `health` is a flat
	reduction to maximum health, not a percentage.
]]
ix.radiation.debuffs = {
	[0] = {
		name = "None",
		description = "No radiation detected.",
		special = {}
	},
	[20] = {
		name = "Minor Radiation Sickness",
		description = "Low radiation exposure.",
		special = {endurance = -1}
	},
	[40] = {
		name = "Advanced Radiation Sickness",
		description = "Radiation is affecting your body.",
		special = {endurance = -2}
	},
	[60] = {
		name = "Critical Radiation Sickness",
		description = "Radiation is causing weakness.",
		special = {endurance = -3, agility = -1}
	},
	[80] = {
		name = "Severe Radiation Poisoning",
		description = "Severe damage from radiation.",
		health = -5,
		special = {endurance = -4, agility = -2}
	},
	[100] = {
		name = "Fatal Radiation Poisoning",
		description = "Fatal radiation levels.",
		health = -10,
		special = {endurance = -5, agility = -3}
	}
}

--[[
	Thresholds in ascending order.

	`ix.radiation.debuffs` is keyed by number, so `pairs` gives no useful
	order and `ipairs` stops at the first gap - it starts at 0 and steps by
	20, so `ipairs` returns nothing at all. Walked through this instead.
]]
ix.radiation.thresholds = {0, 20, 40, 60, 80, 100}

--- The tier a given rad level falls into. Always returns a table.
function ix.radiation.GetTier(amount)
	amount = amount or 0

	local tier = ix.radiation.debuffs[0]

	for _, threshold in ipairs(ix.radiation.thresholds) do
		if (amount >= threshold) then
			tier = ix.radiation.debuffs[threshold]
		end
	end

	return tier
end

local characterMeta = ix.meta.character

function characterMeta:GetRadiation()
	return self:GetData("radiation", 0)
end

--[[
	Radiation resistance, 0-100.

	Three sources stack, exactly as theirs did: the `radman` perk, every worn
	armour's `radResistance`, and a `RAD-RES` buff. Perks and buffs do not
	exist here yet, so both are guarded rather than assumed - the armour term
	is the only one that currently contributes.
]]
function characterMeta:GetRadiationResistance()
	local percentage = 0

	--[[
		Perks are not built. When they are, `radman` is tier 1 = 50%,
		tier 2 = 90%, and this is where it goes.
	]]
	if (self.GetPerk) then
		local radman = self:GetPerk("radman")

		if (radman == 1) then
			percentage = 50
		elseif (radman == 2) then
			percentage = 90
		end
	end

	if (ix.armor) then
		percentage = percentage + ix.armor.GetRadResistance(self)
	end

	local client = self:GetPlayer()

	if (IsValid(client) and client.buffs and client.buffs["RAD-RES"]) then
		percentage = percentage + client.buffs["RAD-RES"]
	end

	return math.Clamp(percentage, 0, 100)
end

--[[
	Does this character take radiation at all?

	Phoenix gate this on `nut.races:takesRadiation(char)` - ghouls and robots
	are immune. Races here carry no such flag yet, so it is read from the race
	table when present and defaults to taking rads, which is the right default
	for a roster that is currently one human.
]]
function characterMeta:TakesRadiation()
	local race = ix.races and ix.races.Get(self:GetRace())

	if (race and race.takesRadiation == false) then return false end

	return true
end
