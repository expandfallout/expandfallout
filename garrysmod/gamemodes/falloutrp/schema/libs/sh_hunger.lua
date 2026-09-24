--[[
	Hunger and thirst.

	Ported from Phoenix's `thirsthunger` plugin. Two independent 0-100 meters
	stored on the character, draining faster the harder you move, each with
	five tiers that hand out SPECIAL modifiers.

	THE TIERS GO BOTH WAYS, which is the part worth noticing. Radiation only
	ever hurts you; these do not. Below 40 you are penalised, above 60 you are
	REWARDED - a well fed character carries +1 Strength and +1 Intelligence and
	regenerates health. So this is not only an attrition timer, it is a reason
	to keep eating well, and a character who ignores it is giving up a bonus
	rather than merely avoiding a penalty.

	Naming is unified the same way it was for armour and radiation: Phoenix key
	these tables `STR`/`END`/`AGL`/`INT`, which do not match the keys their own
	attribute registry uses, so the modifiers silently did nothing. Here they
	are the lowercase names in `ix.special.order`.

	`applyHunger` and `applyThirst` were in `sv_plugin.lua` and so are not in
	any scrape - see `sv_hunger.lua` for what had to be reconstructed.
]]

ix.hunger = ix.hunger or {}

--[[
	Drain rates, per tick, matching their config names and defaults.

	Standing still still costs you, just slower. At the default 0.01 per second
	a motionless character takes about two and a half hours to go from full to
	empty, and a running one about fifty minutes.
]]
ix.config.Add("hungerDrainIdle", 0.01, "Hunger drained per tick while still.",
	nil, {form = "Float", data = {min = 0, max = 2, decimals = 2}, category = "Hunger and Thirst"})

ix.config.Add("thirstDrainIdle", 0.01, "Thirst drained per tick while still.",
	nil, {form = "Float", data = {min = 0, max = 2, decimals = 2}, category = "Hunger and Thirst"})

ix.config.Add("hungerDrainMoving", 0.02, "Hunger drained per tick while moving.",
	nil, {form = "Float", data = {min = 0, max = 2, decimals = 2}, category = "Hunger and Thirst"})

ix.config.Add("thirstDrainMoving", 0.02, "Thirst drained per tick while moving.",
	nil, {form = "Float", data = {min = 0, max = 2, decimals = 2}, category = "Hunger and Thirst"})

ix.config.Add("hungerDrainRunning", 0.03, "Hunger drained per tick while running.",
	nil, {form = "Float", data = {min = 0, max = 2, decimals = 2}, category = "Hunger and Thirst"})

ix.config.Add("thirstDrainRunning", 0.03, "Thirst drained per tick while running.",
	nil, {form = "Float", data = {min = 0, max = 2, decimals = 2}, category = "Hunger and Thirst"})

ix.config.Add("hungerTickRate", 1, "How often hunger and thirst update, in seconds.",
	nil, {form = "Float", data = {min = 0.1, max = 10, decimals = 1}, category = "Hunger and Thirst"})

--[[
	The tiers, keyed by the value at which each BEGINS.

	Note there is no 100 tier: 80 is the top one, so anything from 80 to full
	is "Well Fed". That is theirs, and it means the best tier is a broad band
	rather than something you only hold for a moment after eating.
]]
ix.hunger.hungerTiers = {
	[0] = {
		name = "Starving",
		description = "You are starving.",
		special = {strength = -1, intelligence = -1}
	},
	[20] = {
		name = "Hungry",
		description = "You need food immediately.",
		special = {strength = -1}
	},
	[40] = {
		name = "Peckish",
		description = "You could use some food.",
		special = {}
	},
	[60] = {
		name = "Fed",
		description = "You are fed and satisfied.",
		special = {strength = 1}
	},
	[80] = {
		name = "Well Fed",
		description = "Well fed and energised.",
		special = {strength = 1, intelligence = 1},
		hpRegen = 1
	}
}

ix.hunger.thirstTiers = {
	[0] = {
		name = "Dying of Thirst",
		description = "You are dying from lack of water.",
		special = {endurance = -1, agility = -1}
	},
	[20] = {
		name = "Dehydrated",
		description = "Severely dehydrated. Drink water.",
		special = {agility = -1}
	},
	[40] = {
		name = "Parched",
		description = "You are parched. Thirst is setting in.",
		special = {}
	},
	[60] = {
		name = "Hydrated",
		description = "You are properly hydrated.",
		special = {endurance = 1}
	},
	[80] = {
		name = "Well Hydrated",
		description = "Fully hydrated and refreshed.",
		special = {endurance = 1, agility = 1}
	}
}

--[[
	Ascending thresholds, walked rather than derived.

	Both tables are keyed by number starting at 0, so `ipairs` returns nothing
	at all and `pairs` gives no useful order - the same trap the radiation
	tiers have.
]]
ix.hunger.thresholds = {0, 20, 40, 60, 80}

local function GetTier(tiers, amount)
	local tier = tiers[0]

	for _, threshold in ipairs(ix.hunger.thresholds) do
		if ((amount or 0) >= threshold) then
			tier = tiers[threshold]
		end
	end

	return tier
end

function ix.hunger.GetHungerTier(amount)
	return GetTier(ix.hunger.hungerTiers, amount)
end

function ix.hunger.GetThirstTier(amount)
	return GetTier(ix.hunger.thirstTiers, amount)
end

--[[
	Does this character eat and drink at all?

	Phoenix gate the whole system, and the HUD readout, on
	`nut.races:hasHunger(char)` - robots and some others are exempt. Races here
	carry no such flag yet, so it is read when present and defaults to true.
]]
function ix.hunger.HasHunger(character)
	if (not character) then return false end

	local race = ix.races and ix.races.Get(character:GetRace())

	if (race and race.hasHunger == false) then return false end

	return true
end

local characterMeta = ix.meta.character

function characterMeta:GetHunger()
	return self:GetData("hunger", 100)
end

function characterMeta:GetThirst()
	return self:GetData("thirst", 100)
end

--[[
	The combined SPECIAL modifier from both meters.

	Summed rather than taking the worse of the two: they are separate needs and
	a character can plausibly be well fed and dying of thirst at once, so both
	should count.
]]
function ix.hunger.GetSpecialModifier(character, key)
	if (not character or not ix.hunger.HasHunger(character)) then return 0 end

	local total = 0
	local hunger = ix.hunger.GetHungerTier(character:GetHunger())
	local thirst = ix.hunger.GetThirstTier(character:GetThirst())

	total = total + (hunger.special and hunger.special[key] or 0)
	total = total + (thirst.special and thirst.special[key] or 0)

	return total
end
