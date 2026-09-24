--[[
	S.P.E.C.I.A.L.

	The seven attributes live in `schema/attributes/`; this wires them up.

	Helix already implements almost all of the machinery - the `attributes`
	character var builds the allocation UI at character creation, enforces a
	budget, and stores the result. Two hooks drive it:

	    GetDefaultAttributePoints(client, payload)  the starting budget
	    ix.config.Get("maxAttributes")              the per-attribute ceiling

	So this file mostly supplies numbers and effects rather than systems.

	Phoenix's values: 15 starting points, 25 hard ceiling per attribute.
]]

ix.special = ix.special or {}

--[[
	The seven, in canonical SPECIAL order. `ix.attributes.list` is a hash, so
	iterating it gives no useful ordering; anything presenting SPECIAL should
	walk this instead.
]]
ix.special.order = {
	"strength", "perception", "endurance", "charisma",
	"intelligence", "agility", "luck"
}

ix.special.isSpecial = {}

for _, key in ipairs(ix.special.order) do
	ix.special.isSpecial[key] = true
end

ix.config.Add("specialPoints", 15, "Attribute points to spend at character creation.", nil, {
	data = {min = 7, max = 70},
	category = "Characters"
})

-- Helix's own per-attribute ceiling. Its default is 100; Phoenix caps SPECIAL
-- at 25 and every attribute here inherits that.
ix.config.SetDefault("maxAttributes", 25)

--[[
	Helix's duplicate attributes.

	Helix ships `stamina` and `strength` plugins that register their own `end`,
	`stm` and `str` attributes. Those overlap SPECIAL and would show duplicate
	bars at character creation, so they are pruned from the list below.

	An earlier version also MIRRORED SPECIAL into those keys so the plugins
	would keep applying their effects. That was wrong: this file now implements
	those effects itself, so mirroring would apply each one TWICE. The pruned
	keys stay at 0 and the plugins contribute nothing.
]]
local LEGACY_ATTRIBUTES = {["end"] = true, ["stm"] = true, ["str"] = true}

--[[
	Energy weapons, by AMMO TYPE.

	`SWEP.Type` is not usable for this: the arsenal has tesla weapons typed
	"Heavy" and gauss typed "Sniper", while "Energy" itself spans several ammo
	types. Ammo is what actually separates laser/plasma/gauss/tesla from
	conventional firearms.
]]
ix.special.energyAmmo = {
	["electronchargepack"] = true,   -- laser, tesla
	["microfusioncell"] = true,      -- plasma, gauss
	["energycell"] = true
}

--- Remove non-SPECIAL attributes from the allocation UI and the YOU tab.
local function PruneAttributeList()
	if (not ix.attributes or not ix.attributes.list) then return end

	for key in pairs(ix.attributes.list) do
		if (not ix.special.isSpecial[key]) then
			ix.attributes.list[key] = nil
		end
	end

	-- Belt and braces: named explicitly so the intent survives if the SPECIAL
	-- list is ever widened.
	for key in pairs(LEGACY_ATTRIBUTES) do
		ix.attributes.list[key] = nil
	end
end

-- Plugins load after the schema, so the prune has to happen once everything is
-- registered rather than at file scope.
hook.Add("InitializedPlugins", "ixSpecialPrune", PruneAttributeList)
hook.Add("InitPostEntity", "ixSpecialPrune", PruneAttributeList)

--[[
	Everything below uses hook.Add rather than `function Schema:Name()`.

	A Schema method is a single slot - `sv_hooks.lua` already defines
	`Schema:PlayerSpawn` for race proportions, and defining it again here would
	silently replace it. hook.Add composes, and each listener gets its own
	identifier.
]]

--- The starting budget. Races and factions can adjust it through this hook.
hook.Add("GetDefaultAttributePoints", "ixSpecialPoints", function(client, payload)
	return ix.config.Get("specialPoints", 15)
end)

--[[
	Require the budget to be spent EXACTLY.

	Helix's own validator only rejects OVERspending, so a player can create a
	character with points left on the table and no way to recover them. Phoenix
	requires an exact spend, which is the right call for SPECIAL.
]]
hook.Add("CanPlayerCreateCharacter", "ixSpecialPointsSpent", function(client, payload)
	local budget = ix.config.Get("specialPoints", 15)
	local spent = 0

	for key, value in pairs(payload.attributes or {}) do
		if (ix.special.isSpecial[key]) then
			spent = spent + value
		end
	end

	if (spent ~= budget) then
		return false, "specialPointsRemaining", budget - spent
	end
end)

--[[
	Reading SPECIAL.

	Always go through this rather than `character:GetAttribute(key)` directly:
	it normalises the key to lowercase. Phoenix stores attributes lowercase but
	reads them capitalised in several places, which silently returns the default
	and is why some of their attributes appear to do nothing.
]]
function ix.special.Get(character, key, default)
	if (not character) then return default or 0 end

	key = string.lower(key)

	local value = character:GetAttribute(key, default or 0)

	--[[
		Radiation sickness is subtracted HERE rather than at the point it is
		inflicted, because this is the single function every consumer already
		goes through - damage multipliers, stamina, run speed and the F1 tab
		all read it. Applying the penalty anywhere else would mean finding and
		editing each of them, and missing one would leave a debuff that half
		works.

		Floored at zero. The tiers reach -5 Endurance and -3 Agility, and a
		negative Agility would feed a negative term into run speed.
	]]
	local modifier = 0

	if (ix.radiation and character.GetRadiation) then
		local tier = ix.radiation.GetTier(character:GetRadiation())

		modifier = modifier + (tier.special and tier.special[key] or 0)
	end

	--[[
		Hunger and thirst, which unlike radiation can push either way - a well
		fed character carries +1 Strength rather than merely avoiding a
		penalty.
	]]
	if (ix.hunger and character.GetHunger) then
		modifier = modifier + ix.hunger.GetSpecialModifier(character, key)
	end

	--[[
		Chems, through the buff library.

		Joins the same chain rather than being read anywhere else, for exactly
		the reason radiation gives above: this is the one function every
		consumer of SPECIAL already calls. Mentats granting +2 Intelligence has
		to reach damage multipliers, the F1 tab and everything else without any
		of them knowing chems exist.

		The buff names are the short ones a chem's description uses - INT, AGL -
		so `specialStats` turns the attribute key back into the buff's name.
	]]
	if (ix.buff and ix.buff.specialStats[key]) then
		local client = character:GetPlayer()

		if (IsValid(client)) then
			modifier = modifier + ix.buff.Get(client, ix.buff.specialStats[key])
		end
	end

	--[[
		Summed first and floored ONCE.

		Flooring each source separately would let a penalty be swallowed: -1
		from starvation against +1 from being well hydrated should cancel, but
		clamping the first to zero before adding the second turns a wash into a
		bonus.
	]]
	if (modifier ~= 0) then
		value = math.max(value + modifier, 0)
	end

	return value
end

--- Convenience: 0-1 fraction of the ceiling, for scaling effects.
function ix.special.GetFraction(character, key)
	local maximum = ix.config.Get("maxAttributes", 25)

	if (maximum <= 0) then return 0 end

	return math.Clamp(ix.special.Get(character, key) / maximum, 0, 1)
end

--[[
	Damage.

	Phoenix's numbers, taken from their `damageview` plugin, which computes the
	same bonus it displays over the crosshair:

	    if energyAmmo[primary.Ammo] then  modifier = 0.010 * intelligence
	    elseif isMelee then               modifier = 0.010 * strength
	    else                              modifier = 0.010 * perception
	    bonus = damage * modifier

	So **+1% per point**, additive on the weapon's base damage - +25% at the
	ceiling. Their server-side application is not in the scrape (glua-steal
	never captures `sv_*`), but the readout is authoritative for the numbers.

	Melee is detected exactly as they do it: the Melee Arts base.
]]
ix.special.damagePerPoint = 0.01

--[[
	ONE RATE PER ATTRIBUTE, not one rate.

	They all start at a percent a point, which is what Phoenix does and what
	the three of them being one number was expressing - but they are three
	different promises about three different kinds of weapon, and a server that
	wants Perception to matter more than Strength should not have to make
	Intelligence matter more as well.
]]
ix.config.Add("specialDamagePerStrength", 0.01,
	"Melee damage added per point of Strength, as a fraction.", nil, {
	form = "Float", data = {min = 0, max = 0.1}, category = "Characters"
})

ix.config.Add("specialDamagePerPerception", 0.01,
	"Ballistic damage added per point of Perception, as a fraction.", nil, {
	form = "Float", data = {min = 0, max = 0.1}, category = "Characters"
})

ix.config.Add("specialDamagePerIntelligence", 0.01,
	"Energy damage added per point of Intelligence, as a fraction.", nil, {
	form = "Float", data = {min = 0, max = 0.1}, category = "Characters"
})

local MELEE_BASE = "dangumeleebase"

--- "melee", "energy" or "ballistic" for a weapon, or nil if it is not a weapon.
function ix.special.ClassifyWeapon(weapon)
	if (not IsValid(weapon) or not weapon.GetClass) then return end

	if (weapon.Base == MELEE_BASE) then
		return "melee"
	end

	--[[
		Anything with no ammo type is not a firearm - fists (`ix_hands`),
		physgun, tools. Those count as melee so Strength governs them.

		Phoenix never had to handle this: their fists went through a separate
		`PlayerGetFistDamage` hook and never reached this classifier, so their
		version would call `ix_hands` ballistic and scale it with Perception.
	]]
	local primary = weapon.Primary
	local ammo = primary and primary.Ammo

	if (not ammo or ammo == "" or string.lower(ammo) == "none") then
		return "melee"
	end

	if (ix.special.energyAmmo[string.lower(ammo)]) then
		return "energy"
	end

	return "ballistic"
end

--[[
	The weapon's base damage, before SPECIAL.

	Melee bases store it as DmgMin; firearms use Primary.Damage. Returns nil for
	anything with neither, so callers can skip drawing.
]]
function ix.special.GetWeaponDamage(weapon)
	if (not IsValid(weapon)) then return end

	if (weapon.Base == MELEE_BASE) then
		return weapon.DmgMin
	end

	return weapon.Primary and weapon.Primary.Damage
end

local CLASS_ATTRIBUTE = {
	melee = "strength",
	energy = "intelligence",
	ballistic = "perception"
}

--- The rate each of those is paid at, editable in `/liveedit` under SPECIAL.
local CLASS_CONFIG = {
	melee = "specialDamagePerStrength",
	energy = "specialDamagePerIntelligence",
	ballistic = "specialDamagePerPerception"
}

--[[
	The multiplier a character's SPECIAL applies to a weapon's damage.

	Returns 1 when nothing applies, so callers can multiply unconditionally.
]]
function ix.special.GetDamageMultiplier(character, weapon)
	if (not character) then return 1 end

	local class = ix.special.ClassifyWeapon(weapon)

	if (not class) then return 1 end

	local key = CLASS_ATTRIBUTE[class]

	return 1 + ix.special.Get(character, key)
		* ix.config.Get(CLASS_CONFIG[class], ix.special.damagePerPoint)
end

--[[
	Getters for the systems that do not exist yet.

	Each is a single read, kept here so the intent is recorded and the system
	that lands later has an obvious place to call.
]]

--- Charisma: fraction by which a mugging demand should be reduced, 0-1.
function ix.special.GetMugReduction(character)
	return math.Clamp(ix.special.Get(character, "charisma")
		* ix.config.Get("specialMugReductionPerCharisma", 0.01), 0, 0.9)
end

--- Luck: multiplier on experience gained.
function ix.special.GetExperienceMultiplier(character)
	return 1 + ix.special.Get(character, "luck")
		* ix.config.Get("specialXPPerLuck", 0.02)
end

--[[
	Luck: extra ITEMS in a lootable container. Deliberately quantity, not
	quality - Luck should not improve rarity here.

	IN STEPS RATHER THAN PER POINT. A tenth of an item per point is a number
	nobody can feel: the difference between Luck 6 and Luck 7 was nothing at
	all, and the difference between 9 and 10 was a whole item that arrived
	without explanation. A step of five says "every five points of Luck is one
	more thing in the box", which is a sentence a player can hold in their head
	and check.

	Both halves are configurable - the size of the step and what a step is
	worth - so "one extra per 5 Luck" and "two extra per 10" are both sayable.
]]
function ix.special.GetBonusLootCount(character)
	local step = ix.config.Get("specialLootLuckStep", 5)

	if (step <= 0) then return 0 end

	return math.floor(ix.special.Get(character, "luck") / step)
		* ix.config.Get("specialLootPerStep", 1)
end

--- Luck: multiplier on a crafting success roll.
function ix.special.GetCraftingLuck(character)
	return 1 + ix.special.Get(character, "luck")
		* ix.config.Get("specialCraftPerLuck", 0.02)
end

if (SERVER) then
	--- Movement speed, from Agility.
	function ix.special.Apply(client)
		if (not IsValid(client)) then return end

		local character = client:GetCharacter()

		if (not character) then return end

		local agility = ix.special.Get(character, "agility")
		local perPoint = ix.config.Get("specialSpeedPerAgility", 4)

		--[[
			Armour is added HERE rather than where it is equipped.

			This function sets walk and run speed absolutely, and it runs again
			on every spawn and every attribute change - so a boost applied
			anywhere else would be silently wiped the next time a point was
			spent. One place decides how fast a player moves.

			Guarded because `ix.armor` is a separate library and this one must
			not require it to exist.
		]]
		local speedBoost = ix.armor and ix.armor.GetSpeedBoost(character) or 0
		local jumpBoost = ix.armor and ix.armor.GetJumpBoost(character) or 0

		--[[
			Chems add here for the same reason armour does: this function sets
			speed absolutely, so anything applied elsewhere is wiped the next
			time a point is spent. Jet's +30 and Jet withdrawal's -15 are the
			same term with different signs.

			It affects the run speed only, below - a chem that made you walk
			faster would be strange, and Phoenix's own Speed buffs are all
			about running.
		]]
		local chemSpeed = ix.buff and ix.buff.Get(client, "SPD") or 0

		--[[
			THE RACE'S OWN BASE SPEED, when it has one.

			`RACE.walkSpeed` and `RACE.runSpeed` are the floor a race moves at
			before agility, armour and chems - a radroach is not a super mutant
			with a smaller model. Absent, which is every race that has not been
			given one, falls back to the server's config exactly as before, so
			this changes nothing until somebody sets it in `/liveedit`.
		]]
		local race = ix.races.Get(character:GetRace())
		local baseWalk = tonumber(race and race.walkSpeed)
			or ix.config.Get("walkSpeed", 130)
		local baseRun = tonumber(race and race.runSpeed)
			or ix.config.Get("runSpeed", 235)

		--[[
			AGILITY MOVES YOU AT BOTH SPEEDS.

			It used to add to running only, which made it an attribute that did
			nothing at all in a settlement - and walking is what a character
			does for most of the time they are alive. The two rates are
			separate settings because they are not the same promise: a large
			run bonus is a chase, and a large walk bonus is somebody who is
			simply never where you left them.
		]]
		local walkPerPoint = ix.config.Get("specialWalkPerAgility", 2)

		local walk = math.max(
			baseWalk + math.Round(agility * walkPerPoint) + speedBoost, 1)
		local run = math.max(
			baseRun + math.Round(agility * perPoint)
			+ speedBoost + chemSpeed, 1)

		--[[
			A DEAD FUSION CORE MEANS YOU CANNOT RUN.

			Run speed is pinned to walk speed rather than reduced, so sprinting
			in an unpowered suit does nothing at all - you are dragging several
			hundred pounds of metal around by hand.

			Enforced here rather than where the core runs out, because this
			function sets speed absolutely and re-runs on every spawn, attribute
			change and armour refresh. Setting it anywhere else would hold until
			the next one of those and then silently give the player their sprint
			back.
		]]
		if (client.noCoreCharge) then
			run = walk
		end

		client:SetWalkSpeed(walk)
		client:SetRunSpeed(run)

		--[[
			Jump power has no config of its own, so the engine default (200) is
			the baseline. Floored at 1 for the same reason speed is: a heavy
			enough set would otherwise reach zero and pin you in place.

			THE RACE ADDS TOO. `RACE.jumpBoost` is +70 on a super mutant and 0
			on Liberty Prime, and it was being read by nothing - this function
			sets jump power absolutely and re-runs on every spawn, so applying
			it anywhere else would have been wiped the next time a point was
			spent.
		]]
		local raceJump = ix.races
			and ix.races.GetJumpBoost(character:GetRace()) or 0

		client:SetJumpPower(math.max(200 + jumpBoost + (raceJump or 0), 1))
	end

	local function ApplyNextFrame(client)
		timer.Simple(0, function()
			ix.special.Apply(client)
		end)
	end

	hook.Add("PlayerLoadedCharacter", "ixSpecialApply", ApplyNextFrame)
	hook.Add("PlayerSpawn", "ixSpecialApply", ApplyNextFrame)

	hook.Add("CharacterAttributeUpdated", "ixSpecialApply", function(client)
		ix.special.Apply(client)
	end)

	--[[
		Apply the damage bonus.

		The weapon comes from the attacker's active weapon rather than the
		inflictor: for a SWEP firing bullets the inflictor is usually the player,
		and for melee it varies by base.
	]]
	hook.Add("EntityTakeDamage", "ixSpecialDamage", function(target, dmginfo)
		local attacker = dmginfo:GetAttacker()

		if (not IsValid(attacker) or not attacker:IsPlayer()) then return end

		local character = attacker:GetCharacter()

		if (not character) then return end

		local multiplier = ix.special.GetDamageMultiplier(character, attacker:GetActiveWeapon())

		if (multiplier ~= 1) then
			dmginfo:ScaleDamage(multiplier)
		end
	end)

	--[[
		Endurance: how much stamina you have.

		The stamina plugin's pool is hardcoded 0-100 everywhere, so the size of
		the tank cannot be changed directly. Scaling the per-tick offset achieves
		the same thing: a bigger effective pool moves the same 0-100 bar more
		slowly in both directions, so it lasts proportionally longer.

		`AdjustStaminaOffset` is the plugin's own hook, so nothing there needs
		editing.
	]]
	hook.Add("AdjustStaminaOffset", "ixSpecialEndurance", function(client, offset)
		local character = client:GetCharacter()

		if (not character) then return end

		--[[
			POWER ARMOUR DOES NOT TIRE YOU.

			The suit carries its own weight and moves its own limbs - that is
			the whole conceit - so `isPA` removes stamina drain entirely, which
			is what `_docs/reference/03_armor_and_survival.md` records alongside
			the headshot exemption.

			Only DRAIN is cancelled, not regeneration: a negative offset is
			zeroed and a positive one is left alone, so a player who arrives at
			the suit already winded still recovers.
		]]
		if (offset < 0 and client:GetNW2Bool("WearingPA", false)) then
			return 0
		end

		--[[
			Hunger and thirst change how fast you get your breath back, from
			`reference/03_armor_and_survival.md`:

			    thirst > 50   ->  +0.5
			    thirst <= 10  ->  halved
			    hunger < 10   ->  halved

			REGENERATION ONLY. A negative offset is drain, and being hungry
			should not make running cheaper - which is exactly what halving a
			negative number would do.
		]]
		if (offset > 0 and ix.hunger and ix.hunger.HasHunger(character)) then
			local thirst = character:GetThirst()

			if (thirst > 50) then
				offset = offset + 0.5
			end

			if (thirst <= 10) then
				offset = offset * 0.5
			end

			if (character:GetHunger() < 10) then
				offset = offset * 0.5
			end
		end

		local maximum = ix.special.GetMaxStamina(character)

		if (maximum <= 0) then return end

		return offset * (100 / maximum)
	end)
end

--- The character's effective stamina pool. The networked value stays 0-100;
--- this is what that 100 represents.
function ix.special.GetMaxStamina(character)
	return ix.config.Get("specialBaseStamina", 100)
		+ ix.special.Get(character, "endurance")
		* ix.config.Get("specialStaminaPerEndurance", 6)
end

ix.config.Add("specialBaseStamina", 100, "Stamina pool before Endurance.", nil, {
	data = {min = 20, max = 500},
	category = "Characters"
})

ix.config.Add("specialStaminaPerEndurance", 6, "Stamina gained per point of Endurance.", nil, {
	data = {min = 0, max = 40},
	category = "Characters"
})

ix.config.Add("specialMugReductionPerCharisma", 0.01,
	"Fraction a mugging demand is reduced per point of Charisma.", nil, {
	form = "Float", data = {min = 0, max = 0.05}, category = "Characters"
})

ix.config.Add("specialXPPerLuck", 0.02, "Extra experience per point of Luck.", nil, {
	form = "Float", data = {min = 0, max = 0.1}, category = "Characters"
})

ix.config.Add("specialLootLuckStep", 5,
	"Points of Luck that earn one more step of container loot.", nil, {
	data = {min = 1, max = 25}, category = "Characters"
})

ix.config.Add("specialLootPerStep", 1,
	"Extra items in a container per step of Luck.", nil, {
	data = {min = 0, max = 10}, category = "Characters"
})

ix.config.Add("specialCraftPerLuck", 0.02, "Crafting luck per point of Luck.", nil, {
	form = "Float", data = {min = 0, max = 0.1}, category = "Characters"
})

ix.config.Add("specialSpeedPerAgility", 4, "Run speed gained per point of Agility.", nil, {
	data = {min = 0, max = 30},
	category = "Characters"
})

ix.config.Add("specialWalkPerAgility", 2, "Walk speed gained per point of Agility.", nil, {
	data = {min = 0, max = 30},
	category = "Characters"
})

--[[
	Diagnostic.

	"I don't think SPECIAL is doing anything" is hard to answer by reading code
	when the effects are multipliers on other systems. This prints the character's
	attributes and every derived value, so the question becomes checkable.
]]
if (CLIENT) then
	concommand.Add("fo_special", function()
		local client = LocalPlayer()
		local character = client:GetCharacter()

		if (not character) then
			MsgC(Color(255, 100, 100), "\nNo character loaded.\n\n")
			return
		end

		local accent = Color(255, 199, 44)
		local plain = Color(180, 180, 180)

		MsgC(accent, "\n[SPECIAL] budget " .. ix.config.Get("specialPoints", 15)
			.. ", ceiling " .. ix.config.Get("maxAttributes", 25) .. "\n")

		local total = 0

		for i = 1, #ix.special.order do
			local key = ix.special.order[i]
			local attribute = ix.attributes.list[key]
			local value = ix.special.Get(character, key)

			total = total + value

			MsgC(attribute and plain or Color(255, 100, 100), string.format(
				"  %-14s %3d  %s\n", key, value,
				attribute and "" or "** NOT REGISTERED **"))
		end

		MsgC(accent, string.format("  %-14s %3d\n", "spent", total))

		local weapon = client:GetActiveWeapon()
		local class = ix.special.ClassifyWeapon(weapon)

		MsgC(accent, "\n[SPECIAL] derived\n")
		MsgC(plain, string.format("  %-26s %s\n", "held weapon",
			IsValid(weapon) and weapon:GetClass() or "none"))
		MsgC(plain, string.format("  %-26s %s\n", "classified as", class or "n/a"))
		MsgC(plain, string.format("  %-26s x%.2f\n", "damage multiplier",
			ix.special.GetDamageMultiplier(character, weapon)))
		MsgC(plain, string.format("  %-26s %d\n", "max stamina",
			ix.special.GetMaxStamina(character)))
		MsgC(plain, string.format("  %-26s %d\n", "run speed",
			ix.config.Get("runSpeed", 235)
			+ math.Round(ix.special.Get(character, "agility")
			* ix.config.Get("specialSpeedPerAgility", 4))))
		MsgC(plain, string.format("  %-26s -%d%%\n", "mug reduction",
			math.Round(ix.special.GetMugReduction(character) * 100)))
		MsgC(plain, string.format("  %-26s x%.2f\n", "xp multiplier",
			ix.special.GetExperienceMultiplier(character)))
		MsgC(plain, string.format("  %-26s +%d\n", "bonus loot items",
			ix.special.GetBonusLootCount(character)))
		MsgC(accent, "\n")
	end)
end
