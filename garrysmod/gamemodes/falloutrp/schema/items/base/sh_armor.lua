--[[
	Armour base item.

	Every armour in `items/armor/` inherits this - `ix.item.LoadFromDir` gives
	items in `items/<folder>/` the base `base_<folder>`, so the folder name and
	this filename have to stay in step.

	The field contract is Phoenix's, kept deliberately close so their 685 item
	definitions convert mechanically. What changed, and why, is in
	`sh_armor.lua`; the short version is that equipped state lives on the item
	rather than the character, and `specialBonus` uses the same attribute keys
	as everything else in this schema instead of three-letter codes.

	The rules themselves are NOT here. This file describes an armour and hands
	the decisions to `ix.armor`, so that a command, a loadout or a vendor gets
	the same answer as a player clicking Equip.
]]

ITEM.name = "Armour"
ITEM.description = "A piece of armour."
ITEM.model = "models/fallout/apparel/casualwear.mdl"
ITEM.category = "Armor"

ITEM.width = 1
ITEM.height = 1

--[[
	The marker every other system keys off. `ix.armor.GetEquipped` looks for
	this rather than for a base name, so an armour defined outside
	`items/armor/` still counts as one.
]]
ITEM.isArmor = true

--- Which of the fourteen slots this occupies. See `ix.armor.slots`.
ITEM.bodyType = "body"

--[[
	The worn meshes, per gender. These are bone-merged onto the character's
	animation skeleton, not set as the player model - see `cl_bodyparts.lua`.
	`ITEM.model` above is the separate drop/inventory model.
]]
ITEM.maleModel = ""
ITEM.femaleModel = ""

--- `false` inherits the race's own skin rather than forcing one.
ITEM.skin = false
ITEM.bodyGroups = {}

--- Resistances, as percentages.
ITEM.resistance = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

--- Additive, and usually negative on anything heavy.
ITEM.speedBoost = 0
ITEM.jumpBoost = 0

--[[
	Keyed by the canonical attribute names - `strength`, `perception`, and so
	on. Phoenix used `STR`/`PER`/`END`/..., which did not match the keys their
	own attribute registry used, so a number of their armour bonuses silently
	did nothing.
]]
ITEM.specialBonus = {}

--[[
	Which races may wear this. An unlisted race is ALLOWED - see
	`ix.armor.CanRaceWear` for why that differs from their default.
]]
ITEM.armorRace = {}

--[[
	WHAT SHAPE OF BODY THIS IS CUT FOR: "human", "robot", "creature" or "any".

	Human by default, because almost the whole roster is. `ITEM.isNonHuman` is
	the short way of saying "creature" and exists because that is the thing
	somebody marking a batch of armours is actually thinking.

	Naming a race in `armorRace` overrides this - see `ix.armor.CanRaceWear`.
]]
ITEM.wearer = nil
ITEM.isNonHuman = false

--- Other slots this covers, and body parts it replaces.
ITEM.takesType = {}
ITEM.takesBody = {}

--- Power Armour: sealed against headshots, and needs a fusion core unless `noCore`.
ITEM.isPA = false
ITEM.noCore = false

--- Appended to the description when set.
ITEM.faction = false
ITEM.factionClass = false

ITEM.playerHeight = false
ITEM.textureReplace = {}

--[[
	The description, with the numbers that matter appended.

	Built rather than written so an armour's stats cannot drift from its text -
	the failure mode where a suit is buffed and its description still advertises
	the old figure.
]]
function ITEM:GetDescription()
	local description = self.description or ""
	local lines = {}

	local function Stat(label, value, suffix)
		if (value and value ~= 0) then
			lines[#lines + 1] = string.format(" - %s: %s%s%s", label,
				value > 0 and "+" or "", value, suffix or "")
		end
	end

	Stat("Damage Resistance", self.resistance, "%")
	Stat("Radiation Resistance", self.radResistance, "%")
	Stat("Fall Protection", self.fallProtection, "%")
	Stat("Speed", self.speedBoost)
	Stat("Jump", self.jumpBoost)

	local special = {}

	--[[
		Walked in SPECIAL order rather than with `pairs`, so two armours with
		the same bonuses always read the same way round.

		Written value-first with the short code - "+3 END", not
		"Endurance: +3". That is how a SPECIAL modifier is labelled everywhere
		else a player sees one, including the top-left list, and the two should
		not disagree about the same number.
	]]
	for _, key in ipairs(ix.special and ix.special.order or {}) do
		local value = self.specialBonus and self.specialBonus[key]

		if (value and value ~= 0) then
			special[#special + 1] = string.format(" - %s%d %s",
				value > 0 and "+" or "", value,
				(ix.armor and ix.armor.specialCodes[key]) or string.upper(key))
		end
	end

	if (#lines > 0) then
		description = description .. "\n\n" .. table.concat(lines, "\n")
	end

	if (#special > 0) then
		description = description .. "\n\n - SPECIAL:\n" .. table.concat(special, "\n")
	end

	if (self.isPA) then
		description = description .. "\n\n - Power Armour"

		--[[
			The charge belongs to this SUIT, not to the armour type, so it is
			read from instance data. Phoenix showed the same line, and it is
			the only way to tell a fuelled suit from a dead one before putting
			it on.

			BODY SLOT ONLY, and the slot test is what matters rather than
			`noCore` alone. Most Power Armour helmets are `noCore = true` and
			so excluded anyway, but ten of them in the source data are not -
			BoS T-45, Vault-Tec, Shi T-49 and others - and those advertised a
			core charge they can never hold, because a core only ever goes into
			the suit.
		]]
		if (not self.noCore and self.bodyType == "body") then
			local core = math.Round(self:GetData("core", 0), 1)

			description = description .. "\n - Core Charge: " ..
				(core > 0 and (core .. "%") or "Empty")
		end
	end

	--[[
		WHAT IS FITTED TO THIS SUIT, which is not a property of the armour
		type - two of the same armour carry different modulators, so this
		reads the INSTANCE. See `sh_modulator.lua`.

		Their numbers are already in the lines above, because `SumField` and
		`GetSpecialBonus` add them; this section says where those numbers came
		from, which is the difference between a suit that is better than the
		one in the shop and a suit that looks wrong.
	]]
	local modulators = ix.modulator and ix.modulator.Lines(self) or {}

	if (#modulators > 0) then
		description = description .. "\n\n - Modulators:\n"
			.. table.concat(modulators, "\n")
	end

	if (self.faction) then
		description = description .. "\n\n - " .. self.faction .. " Faction Armour"

		if (self.factionClass) then
			description = description .. "\n - " .. self.factionClass
		end
	end

	local slot = ix.armor and ix.armor.slotNames[self.bodyType]

	if (slot) then
		description = description .. "\n\n - Worn on: " .. slot
	end

	return description
end

if (CLIENT) then
	local powerBolt = Material("phoenix/gui_icons/451.png", "smooth")

	--[[
		The inventory overlay, ported from their `paintOver`.

		Two separate readouts:

		- a corner square for equipped state. GREEN when worn, RED when not -
		  Phoenix draw both, where Helix's outfit base draws only the green
		  one, so a stored armour has a marker here rather than nothing.

		- a CORE CHARGE BAR along the bottom of any Power Armour that takes a
		  core. Its colour runs green to red through HSV as the charge falls
		  (`hue = charge / 100 * 120`, where 120 is green and 0 is red), inside
		  a black outline showing the full width. At zero the bar is replaced
		  by a yellow lightning bolt, so a dead suit reads as "needs a core"
		  rather than as an empty bar you have to squint at.

		Live, because `core` is item data and item data is networked to its
		owner - the bar falls as you walk.
	]]
	function ITEM:PaintOver(item, width, height)
		local equipped = item:GetData("equip", false)

		surface.SetDrawColor(equipped and Color(110, 255, 110, 100)
			or Color(255, 110, 110, 100))
		surface.DrawRect(width - 16, height - 16, 12, 12)

		-- Body slot only, matching where a core can actually be fitted; a
		-- permanently empty bolt on a helmet would just be a lie.
		if (not item.isPA or item.noCore or item.bodyType ~= "body") then return end

		local charge = tonumber(item:GetData("core", 0)) or 0

		if (charge > 0) then
			surface.SetDrawColor(HSVToColor(math.Clamp(charge / 100 * 120, 0, 120), 1, 1))
			surface.DrawRect(4, height - 10,
				math.Clamp(math.floor((charge / 100) * (width / 2)), 0, width / 2), 5)

			surface.SetDrawColor(0, 0, 0, 255)
			surface.DrawOutlinedRect(4, height - 10, width / 2, 5)
		else
			surface.SetMaterial(powerBolt)
			surface.SetDrawColor(255, 255, 0, 255)
			surface.DrawTexturedRect(4, height - 16, 12, 12)
		end
	end
end

--[[
	Named `EquipUn` for the same reason Helix's outfit base does: item actions
	are listed in key order, and this puts Unequip under Equip rather than
	above it.
]]
ITEM.functions.EquipUn = {
	name = "unequip",
	tip = "unequipTip",
	icon = "icon16/cross.png",

	OnRun = function(item)
		local success, reason = ix.armor.Unequip(item.player, item)

		if (not success and reason) then
			item.player:NotifyLocalized(string.sub(reason, 2))
		end

		return false
	end,

	OnCanRun = function(item)
		local client = item.player

		return not IsValid(item.entity) and IsValid(client)
			and item:GetData("equip") == true
			and hook.Run("CanPlayerUnequipItem", client, item) ~= false
	end
}

ITEM.functions.Equip = {
	name = "equip",
	tip = "equipTip",
	icon = "icon16/tick.png",

	OnRun = function(item)
		--[[
			Every rule lives in `ix.armor.Equip`, including the ones that could
			have been checked here. A vendor, a command or a starting loadout
			must not be able to produce a differently-equipped character than a
			player clicking this button.
		]]
		local success, reason, extra = ix.armor.Equip(item.player, item)

		if (not success and reason) then
			item.player:NotifyLocalized(string.sub(reason, 2), extra)
		end

		return false
	end,

	OnCanRun = function(item)
		local client = item.player

		return not IsValid(item.entity) and IsValid(client)
			and item:GetData("equip") ~= true
			and hook.Run("CanPlayerEquipItem", client, item) ~= false
	end
}

--[[
	Reload the suit from a fusion core in your inventory.

	Shown only on Power Armour that actually takes a core, so the action does
	not appear on the 650 pieces it means nothing for.
]]
ITEM.functions.ReplaceCore = {
	name = "replaceCore",
	icon = "icon16/lightning_add.png",

	OnRun = function(item)
		local success, reason = ix.armor.EquipFusionCore(item.player, item)

		if (not success and reason) then
			item.player:NotifyLocalized(string.sub(reason, 2))
		end

		return false
	end,

	--[[
		Body slot only. Power Armour HELMETS are flagged `isPA` too - that is
		what seals them against headshots - so without this check the action
		appeared on the helmet as well and a player had two cores to feed.
		The core belongs to the suit.
	]]
	OnCanRun = function(item)
		return not IsValid(item.entity) and item.isPA and not item.noCore
			and item.bodyType == "body"
	end
}

--[[
	Equipped armour stays put.

	Otherwise it can be traded, dropped or stored while worn, and the render
	set - which is derived from the inventory it just left - would keep drawing
	it on someone who no longer owns it.
]]
function ITEM:CanTransfer(oldInventory, newInventory)
	if (newInventory and self:GetData("equip")) then
		return false
	end

	return true
end

--[[
	Removal is the one way equipped armour can leave an inventory, so the
	derived state has to be rebuilt here too - `Refresh` reads the inventory,
	and by this point the item is out of it.
]]
function ITEM:OnRemoved()
	if (not SERVER or not self:GetData("equip")) then return end

	local client = self:GetOwner()

	if (IsValid(client)) then
		ix.armor.Refresh(client)
	end
end
