--[[
	What the live editor can edit.

	Five kinds, each a `List`, a `Target`, a table of fields and an `OnApply`.
	See `sh_live.lua` for what those mean; nothing here knows anything about
	the window, and the window knows nothing about weapons.

	THE FIELD LISTS ARE THE INTERESTING PART and they are deliberately short.
	Every number a schema has is not worth putting on a screen: what is here is
	what somebody balancing a server actually reaches for, and anything missing
	is one line away.
]]

--------------------------------------------------------------------------------
-- Weapons
--------------------------------------------------------------------------------

--[[
	The SWEP table, not the item.

	Damage, spread and the rest belong to the weapon; the ITEM is the thing in
	your pocket that spawns one. `weapons.GetStored` hands back the table every
	instance is built from, so writing to it changes every weapon of that class
	made from then on - and `OnApply` walks the ones already in the world, which
	is what makes it live rather than "live after you drop it".
]]
ix.live.Register({
	id = "weapon",
	name = "WEAPONS",
	note = "damage, spread, ironsights, hit multipliers",

	List = function()
		local out = {}

		for class, swep in pairs(weapons.GetList()) do
			class = swep.ClassName or class

			--[[
				Only the ones this schema has an ITEM for. The weapon list also
				holds bases, tool guns and everything any addon registered, and
				a list of four hundred entries nobody can put in an inventory
				is a list nobody can find a rifle in.
			]]
			local itemTable

			for _, item in pairs(ix.item.list) do
				if (item.class == class) then itemTable = item break end
			end

			if (not itemTable) then continue end

			out[#out + 1] = {
				id = class,
				name = itemTable.name or swep.PrintName or class,
				note = string.format("%s   %s dmg",
					tostring(swep.Type or "?"),
					tostring((swep.Primary or {}).Damage or "?"))
			}
		end

		table.sort(out, function(a, b) return a.name < b.name end)

		return out
	end,

	Target = function(id)
		return weapons.GetStored(id)
	end,

	fields = {
		{key = "Primary.Damage", name = "Damage", kind = "number",
			min = 0, max = 1000, decimals = 1,
			note = "before rarity, armour and the hit multipliers below"},

		{key = "Primary.Cone", name = "Spread cone", kind = "number",
			min = 0, max = 1, decimals = 3, default = 0.03,
			note = "radians of inaccuracy per shot - 0.03 is a pistol"},

		{key = "Primary.Delay", name = "Seconds between shots",
			kind = "number", min = 0.01, max = 5, decimals = 3, default = 0.13,
			note = "0.13 is a pistol. See 03-weapons.md before 'fixing' a "
				.. "fire rate"},

		{key = "Primary.Recoil", name = "Recoil", kind = "number",
			min = 0, max = 20, decimals = 2, default = 0.8,
			note = "how far the view is kicked up per shot. It "
				.. "also feeds the spread - see Spread - from "
				.. "recoil below"},

		{key = "Primary.AmmoPerShot", name = "Ammo used per shot",
			kind = "number", min = 0, max = 40, decimals = 0, default = 1,
			note = "rounds taken out of the magazine each time it fires. This "
				.. "is NOT the pellet count below - a shotgun spends one shell "
				.. "and throws eight pellets, and a gauss rifle can spend five "
				.. "cells for one shot. Almost no weapon writes this down, so "
				.. "the 1 is the base's own value rather than this gun's. "
				.. "0 makes a shot free"},

		{key = "Primary.NumShots", name = "Pellets per shot",
			kind = "number", min = 1, max = 40, decimals = 0, default = 1,
			note = "more than one is a shotgun - every pellet is a "
				.. "separate bullet doing the full damage above, so six "
				.. "pellets of 20 is 120 into somebody standing close"},

		{key = "Primary.ClipSize", name = "Magazine", kind = "number",
			min = 1, max = 500, decimals = 0, default = 12,
			note = "rounds before a reload. Weapons already in the "
				.. "world keep what is in them until they are next "
				.. "reloaded"},

		--[[
			SHOOTING WHILE SPRINTING, which the base checks live rather than
			from the cache (`self.runAndGun`, in three places) - so this takes
			effect on the weapon in somebody's hands the moment it is set.

			Off is the base's own default and what most weapons say. The SMGs
			and pistols in this arsenal turn it on; the heavy and precision
			weapons deliberately do not.
		]]
		{key = "runAndGun", name = "Run and gun", kind = "bool",
			default = false,
			note = "whether it can be fired while sprinting. Off makes "
				.. "sprinting a decision - you cannot shoot until you stop"},

		{key = "Primary.Automatic", name = "Automatic", kind = "bool",
			note = "held down rather than clicked. The rate is "
				.. "Seconds between shots above, not this"},

		--[[
			THE FIVE SPREADS, which is how the weapon base actually works.

			`Spread.Min` and `Spread.Max` are the range the cone moves between
			as somebody fires, moves and settles; the four modifiers below
			multiply it for the state they name. Standing still and hip-firing
			is the plain number - everything else is that number times one or
			more of these, so aiming while crouched is `IronSightsMod` times
			`CrouchMod`.
		]]
		{key = "Spread.Min", name = "Spread - best", kind = "number",
			min = 0, max = 5, decimals = 3, default = 0,
			note = "standing still, settled, hip-fired. The floor it returns "
				.. "to between shots"},

		{key = "Spread.Max", name = "Spread - worst", kind = "number",
			min = 0, max = 5, decimals = 3, default = 0.5,
			note = "the ceiling firing and moving can push it to"},

		{key = "Spread.IronSightsMod", name = "Spread - aiming", kind = "number",
			min = 0, max = 2, decimals = 2, default = 0.1,
			note = "multiplier while scoped. 0.1 is a tenth of the hip-fire "
				.. "cone; 1 is no improvement at all"},

		{key = "Spread.CrouchMod", name = "Spread - crouched",
			kind = "number", min = 0, max = 2, decimals = 2, default = 0.6,
			note = "multiplier while ducked. Multiplies WITH the aiming one, "
				.. "so crouched and scoped is both"},

		{key = "Spread.AirMod", name = "Spread - in the air", kind = "number",
			min = 0, max = 5, decimals = 2, default = 1.2,
			note = "multiplier while off the ground. Above 1 is a penalty"},

		{key = "Spread.VelocityMod", name = "Spread - moving",
			kind = "number", min = 0, max = 5, decimals = 2, default = 0.5,
			note = "how much running opens the cone"},

		{key = "Spread.RecoilMod", name = "Spread - from recoil",
			kind = "number", min = 0, max = 5, decimals = 2, default = 1,
			note = "how much of the recoil BUILT UP so far becomes spread. "
				.. "Each shot adds 40 percent of Recoil to a pool capped at "
				.. "MaxRecoil (1) that bleeds off at 1.4 a second, and this "
				.. "multiplies that pool into the cone. It is ADDED rather "
				.. "than multiplied like crouching and jumping - so 0 means a "
				.. "held trigger never opens the group, though the gun still "
				.. "kicks your view"},

		{key = "IronSightsPos", name = "Ironsight position", kind = "vector",
			note = "where the sights sit, as x y z. The WASD editor below "
				.. "writes these"},

		{key = "IronSightsAng", name = "Ironsight angle", kind = "angle",
			note = "pitch yaw roll of the sighted view, in degrees. An ANGLE "
				.. "rather than a position - the base adds to it with an "
				.. "Angle, and a Vector here errors every frame the gun is "
				.. "out"}
	},

	--[[
		Every one of these already in the world, updated too.

		`weapons.GetStored` is what a NEW weapon is built from; a weapon
		somebody is holding was built from it a minute ago and kept its own
		copy of the fields. Without this, a damage change would only reach
		people who drop their rifle and pick it up again.
	]]
	OnApply = function(id, key, value)
		for _, weapon in ipairs(ents.FindByClass(id)) do
			if (not IsValid(weapon)) then continue end

			ix.live.Write(weapon, key, value)

			--[[
				AND THE CACHE, WHICH IS WHAT THE WEAPON ACTUALLY FIRES FROM.

				The longsword base builds a `CachedData` table once per weapon
				and reads THAT at fire time - damage, cone, recoil and the
				pellet count all come out of it:

				    NumShots = primary.NumShots or 1,   -- BuildBaseCachedData

				so writing `Primary.NumShots` on a weapon somebody is holding
				changed a field nothing reads again. That is why setting a
				rifle to fire six pellets did nothing until it was dropped and
				picked up. Rebuilding the cache is the whole fix, and it is
				also what makes every other number here take effect mid-fight.
			]]
			if (weapon.RebuildCachedData) then
				weapon:RebuildCachedData()
			end
		end
	end
})

--------------------------------------------------------------------------------
-- Armour
--------------------------------------------------------------------------------

--[[
	The item table, which is where every armour number lives.

	A change reaches everybody wearing one immediately: the resistance pools are
	recomputed from the item tables by `ix.armor.Refresh`, and `OnApply` asks
	for that rather than waiting for somebody to take their coat off.
]]
ix.live.Register({
	id = "armor",
	name = "ARMOUR",
	note = "resistance, speed, SPECIAL, and who may wear it",

	List = function()
		local out = {}

		for uniqueID, itemTable in pairs(ix.item.list) do
			if (not itemTable.isArmor) then continue end

			out[#out + 1] = {
				id = uniqueID,
				name = itemTable.name or uniqueID,
				note = string.format("%s   %d%% DR",
					ix.armor.slotNames[itemTable.bodyType]
						or tostring(itemTable.bodyType),
					itemTable.resistance or 0)
			}
		end

		table.sort(out, function(a, b) return a.name < b.name end)

		return out
	end,

	Target = function(id)
		return ix.item.list[id]
	end,

	fields = {
		{key = "resistance", name = "Damage resistance", kind = "number",
			min = 0, max = 100, decimals = 0,
			note = "percent of damage stopped. The head and body pools are "
				.. "each capped by armorMaxResistance"},

		{key = "radResistance", name = "Radiation resistance",
			kind = "number", min = 0, max = 100, decimals = 0,
			note = "percent of incoming rads stopped. One pool with Rad-X and "
				.. "the rest, capped at 100 in total"},

		{key = "fallProtection", name = "Fall protection", kind = "number",
			min = 0, max = 100, decimals = 0,
			note = "percent of fall damage stopped"},

		{key = "speedBoost", name = "Speed", kind = "number",
			min = -200, max = 200, decimals = 0,
			note = "added to the race's own walk and run speed"},

		{key = "jumpBoost", name = "Jump", kind = "number",
			min = -200, max = 200, decimals = 0,
			note = "added to jump power. Negative on anything heavy"},

		{key = "specialBonus.strength", name = "+STR", kind = "number",
			min = -10, max = 10, decimals = 0,
			note = "SPECIAL points this adds while worn. Strength is melee "
				.. "damage and carry weight"},

		{key = "specialBonus.perception", name = "+PER", kind = "number",
			min = -10, max = 10, decimals = 0,
			note = "SPECIAL points this adds while worn. PER is "
				.. "ballistic weapon damage"},

		{key = "specialBonus.endurance", name = "+END", kind = "number",
			min = -10, max = 10, decimals = 0,
			note = "SPECIAL points this adds while worn. END is "
				.. "the size of the stamina pool, and so how many "
				.. "jumps it is worth"},

		{key = "specialBonus.charisma", name = "+CHR", kind = "number",
			min = -10, max = 10, decimals = 0,
			note = "SPECIAL points this adds while worn. CHR talks "
				.. "a mugger down"},

		{key = "specialBonus.intelligence", name = "+INT", kind = "number",
			min = -10, max = 10, decimals = 0,
			note = "SPECIAL points this adds while worn. INT is "
				.. "laser, plasma, gauss and tesla damage"},

		{key = "specialBonus.agility", name = "+AGL", kind = "number",
			min = -10, max = 10, decimals = 0,
			note = "SPECIAL points this adds while worn. AGL is "
				.. "walking and running speed"},

		{key = "specialBonus.luck", name = "+LCK", kind = "number",
			min = -10, max = 10, decimals = 0,
			note = "SPECIAL points this adds while worn. LCK is "
				.. "what turns up in a container, and rolls that "
				.. "go your way"},

		{key = "isPA", name = "Power armour", kind = "bool",
			default = false,
			note = "on, this piece is part of a powered suit: it takes a "
				.. "fusion core, counts as sealed, needs Power Armor Training "
				.. "unless salvaged, and a helmet of it needs the suit on "
				.. "first"},

		{key = "isSalvagedPA", name = "Salvaged power armour", kind = "bool",
			default = false,
			note = "only matters on a power armour piece. On, it is a "
				.. "stripped frame worn like heavy armour and needs no Power "
				.. "Armor Training to put on; off, the suit needs the manual "
				.. "read and a permanent kill takes that away"},

		{key = "wearer", name = "Body shape it fits", kind = "choice",
			default = "human",
			choices = function() return {"human", "robot", "creature", "any"} end,
			note = "WHO CAN WEAR IT. human is people and ghouls, robot is the "
				.. "chassis races, creature is deathclaws and the rest, any "
				.. "fits everything. A race whose shape does not match cannot "
				.. "equip it at all - and an armour that names specific races "
				.. "in armorRace overrides this"}
	},

	--[[
		TAKEN OFF AND PUT BACK ON, for anybody wearing this exact armour.

		`Refresh` recomputes the resistance pools, which is most of it - but an
		armour does more than resist damage when it is equipped: bodygroups,
		render state, stealth capability and the SPECIAL bonuses are all
		applied by `ix.armor.Equip`. A live edit that only refreshed the pools
		would leave the rest of it describing the armour as it was.

		Only the people actually wearing the edited item, and only on the
		server - `Equip` is authoritative and networks the result itself.
	]]
	OnApply = function(id)
		if (not SERVER or not ix.armor.Refresh) then return end

		for _, client in player.Iterator() do
			local character = client:GetCharacter()
			local inventory = character and character:GetInventory()

			if (not inventory) then continue end

			--[[
				EVERYTHING THAT WAS ON, not just the piece being edited.

				`Unequip` on a Power Armour BODY deliberately takes its helmet
				and plates off with it - that is the rule that stops somebody
				keeping a sealed helmet by removing the suit - so cycling the
				body alone would have quietly stripped the rest of the suit
				off everybody wearing one. The list is what goes back on.
			]]
			local wasEquipped = {}
			local edited

			for item in ix.inventory.Each(inventory) do
				if (not item:GetData("equip") or not item.isArmor) then
					continue
				end

				wasEquipped[#wasEquipped + 1] = item

				if (item.uniqueID == id) then edited = item end
			end

			if (not edited) then continue end

			ix.armor.Unequip(client, edited)

			--[[
				A FRAME LATER. `Unequip` writes item data and rebuilds the
				render set, and equipping again in the same tick races that -
				the second half would be undone by the first finishing.

				THE BODY FIRST, because a helmet refuses to go on without one.
				`Equip` answers false rather than throwing for anything that
				cannot go back, so a piece the edit has made unwearable simply
				stays off.
			]]
			timer.Simple(0, function()
				if (not IsValid(client)) then return end

				table.sort(wasEquipped, function(a, b)
					return (a.bodyType == "body" and 1 or 2)
						< (b.bodyType == "body" and 1 or 2)
				end)

				for _, item in ipairs(wasEquipped) do
					if (ix.item.instances[item.id] and not item:GetData("equip")) then
						ix.armor.Equip(client, item)
					end
				end

				ix.armor.Refresh(client)
			end)
		end
	end
})

--------------------------------------------------------------------------------
-- Chems
--------------------------------------------------------------------------------

ix.live.Register({
	id = "aid",
	name = "CHEMS",
	note = "healing, rads, addiction",

	List = function()
		local out = {}

		for uniqueID, itemTable in pairs(ix.item.list) do
			if (not itemTable.isAid) then continue end

			out[#out + 1] = {
				id = uniqueID,
				name = itemTable.name or uniqueID,
				note = string.format("%s%s",
					(itemTable.heal or 0) > 0
						and (itemTable.heal .. " HP   ") or "",
					itemTable.addictionName or "")
			}
		end

		table.sort(out, function(a, b) return a.name < b.name end)

		return out
	end,

	Target = function(id)
		return ix.item.list[id]
	end,

	fields = {
		{key = "heal", name = "Health restored", kind = "number",
			min = 0, max = 1000, decimals = 0,
			note = "instantly, or over the time below"},

		{key = "healTime", name = "Seconds it heals over", kind = "number",
			min = 0, max = 300, decimals = 1,
			note = "0 is instant. Anything else is interrupted by damage, "
				.. "which is what makes a stimpak a bad idea mid-fight"},

		{key = "radiation", name = "Radiation", kind = "number",
			min = -1000, max = 1000, decimals = 0,
			note = "rads added. NEGATIVE removes them - that is what RadAway "
				.. "is, and removal ignores rad resistance on purpose"},

		{key = "addictionChance", name = "Addiction chance", kind = "number",
			min = 0, max = 100, decimals = 0,
			note = "percent, rolled once per dose on somebody not already "
				.. "hooked on it"},

		{key = "price", name = "Price", kind = "number",
			min = 0, max = 100000, decimals = 0,
			note = "what a NEW shop entry for it starts at. Changing this does "
				.. "not reprice a shop that already sells it"},

		--[[
			THE BUFFS, WHICH ARE A LIST RATHER THAN A FIELD.

			`ITEM.buffs` is `{{stat = "STR", value = 3, duration = 60}, ...}`,
			so a SPECIAL bonus is not one value at one path and cannot be
			edited by the generic reader. Each of these provides its own `Read`
			and `Write`, which is exactly what that escape hatch is for - see
			`ix.live.Value`.

			The DURATION is shared: a chem that grants three stats grants them
			for the same time, which is true of every chem in the roster and of
			every chem in the games.
		]]
		unpack(ix.live.BuffFields())
	}
})

--------------------------------------------------------------------------------
-- Races
--------------------------------------------------------------------------------

--[[
	`ix.races.list` is the registry, and its entries are the RACE tables from
	`schema/races/`.

	Health, hull and speed are all read on spawn, so a change reaches people
	when they next spawn - except that `OnApply` refreshes the two that can be
	applied to somebody standing there.
]]
ix.live.Register({
	id = "race",
	name = "RACES",
	note = "health, speed, scale and resistance",

	List = function()
		local out = {}

		for class, race in pairs(ix.races.list) do
			out[#out + 1] = {
				id = class,
				name = race.name or class,
				note = string.format("%d HP   %s",
					race.baseHealth or 100, class)
			}
		end

		table.sort(out, function(a, b) return a.name < b.name end)

		return out
	end,

	Target = function(id)
		return ix.races.list[id]
	end,

	fields = {
		{key = "baseHealth", name = "Health", kind = "number",
			min = 1, max = 10000, decimals = 0,
			note = "what somebody of this race spawns with"},

		{key = "naturalResistance", name = "Natural damage resistance",
			kind = "number", min = 0, max = 95, decimals = 0,
			default = 0,
			note = "percent stopped before any armour - a deathclaw's hide. "
				.. "It goes into the same pool as armour and chems and is "
				.. "capped with them"},

		{key = "walkSpeed", name = "Walk speed", kind = "number",
			min = 10, max = 1000, decimals = 0,
			note = "units per second before Agility and armour. 0 uses the "
				.. "server's walkSpeed config (130)"},

		{key = "runSpeed", name = "Run speed", kind = "number",
			min = 10, max = 1000, decimals = 0,
			note = "0 uses the server's runSpeed config (235)"},

		{key = "jumpBoost", name = "Jump power", kind = "number",
			min = 0, max = 1000, decimals = 0, default = 0,
			note = "added to the engine's 200. A super mutant has +70"},

		{key = "scale", name = "Model scale", kind = "number",
			min = 0.1, max = 5, decimals = 2, default = 1,
			note = "1 is the model's own size and 0.85 is a human, because "
				.. "these player models are built slightly large. THE HULL "
				.. "DOES NOT FOLLOW IT - a race scaled up still collides with "
				.. "the world at the size in its hull field"},

		{key = "hasRadiation", name = "Takes radiation", kind = "bool",
			default = true,
			note = "off makes them immune. Ghouls, robots and anything that "
				.. "was never alive"},

		{key = "hasHunger", name = "Needs food and water", kind = "bool",
			default = true,
			note = "off stops hunger and thirst draining at all, which is what "
				.. "a robot or a ghoul wants"},

		{key = "canUseChems", name = "Can use chems", kind = "bool",
			default = true,
			note = "off refuses every aid item EXCEPT those marked mechanical "
				.. "- which is how a robot takes a repair kit and nothing "
				.. "else. See ITEM.mechanical"},

		--[[
			WHICH CHEMS, per race. Phoenix gated on a whitelist and a
			blacklist (`getRaceChemWhitelist`, `getRaceChemBlacklist`) and
			the aid base here has read both since the start; these are the
			switches. Each is a set of item ids, drawn as ticks.
		]]
		{key = "chemWhitelist", name = "Chems it can take", kind = "items",
			filter = function(itemTable) return itemTable.isAid == true end,
			note = "tick any, and this race can take ONLY what is ticked. "
				.. "Nothing ticked means no list. Repair kits (ITEM.mechanical) "
				.. "ignore it"},

		{key = "chemBlacklist", name = "Chems it cannot take", kind = "items",
			filter = function(itemTable) return itemTable.isAid == true end,
			note = "refused to this race whatever the list above says"}
	},

	OnApply = function(id, key)
		if (not SERVER) then return end

		--[[
			Speed and health are applied per player and can be re-applied to
			somebody standing there; the hull, the model and the animation set
			are applied on spawn and are deliberately NOT forced here - a race
			edit that respawned everybody wearing it mid-fight would be a worse
			tool than one that waits.
		]]
		for _, client in player.Iterator() do
			local character = client:GetCharacter()

			if (not character or character:GetRace() ~= id) then continue end

			if (key == "walkSpeed" or key == "runSpeed") then
				if (client.UpdateSpeed) then client:UpdateSpeed() end
			elseif (key == "baseHealth") then
				client:SetMaxHealth(ix.races.GetBaseHealth(id))
			end
		end
	end
})

--------------------------------------------------------------------------------
-- Factions
--------------------------------------------------------------------------------

ix.live.Register({
	id = "faction",
	name = "FACTIONS",
	note = "name, colour, pay and whether it is default",

	List = function()
		local out = {}

		for _, faction in ipairs(ix.faction.indices) do
			out[#out + 1] = {
				id = faction.uniqueID,
				name = faction.name or faction.uniqueID,
				note = string.format("%d member(s)",
					#team.GetPlayers(faction.index))
			}
		end

		table.sort(out, function(a, b) return a.name < b.name end)

		return out
	end,

	Target = function(id)
		return ix.faction.teams[id]
	end,

	fields = {
		{key = "name", name = "Name", kind = "string",
			note = "what it is called everywhere - the shop, the scoreboard, "
				.. "the door list"},

		{key = "description", name = "Description", kind = "string",
			note = "what a player reads when choosing a faction at "
				.. "character creation"},

		{key = "color", name = "Colour", kind = "colour",
			note = "the scoreboard band, the chat name and the door plates"},

		{key = "pay", name = "Pay", kind = "number",
			min = 0, max = 100000, decimals = 0,
			note = "caps every payTime seconds. 0 is no salary"},

		{key = "payTime", name = "Seconds between pay", kind = "number",
			min = 10, max = 86400, decimals = 0,
			note = "how often the pay above arrives - ten seconds "
				.. "at the fastest. Set the pay itself to 0 to stop "
				.. "paying"},

		{key = "isDefault", name = "Anyone may join", kind = "bool",
			note = "the wastelander rule - a default faction needs no "
				.. "whitelist, and cannot brand weapons"},

		--[[
			THE TWO FIGHTING FLAGS, both off by default.

			They are the exception rather than the rule, which is why neither
			is written into any faction file: a faction that has never been
			touched raids, is raided, and is on the tab menu.
		]]
		{key = "raidImmune", name = "Immune to raids", kind = "bool",
			default = false,
			note = "off is normal. On, this faction cannot be raided or "
				.. "declared on - AND CANNOT RAID ANYBODY EITHER, which is "
				.. "the half people forget: immunity is being out of the "
				.. "fighting, not being safe while in it"},

		{key = "encryptedComms", name = "Encrypted comms",
			kind = "bool", default = false,
			note = "off is normal: anybody stood near a member hears what "
				.. "/f and /o say. On, they hear static - every character "
				.. "scrambled on the server - and only the faction reads it"},

		{key = "hiddenFromTab", name = "Hidden from the tab menu",
			kind = "bool", default = false,
			note = "off is normal. On, this faction does not appear on the "
				.. "scoreboard at all - for an event or an NPC faction that "
				.. "is not meant to be part of the visible server. It also "
				.. "loses its raid buttons: you cannot call a raid on a "
				.. "faction you cannot see"}
	},

	--[[
		A faction's colour is also a TEAM colour, which is a separate registry
		- the scoreboard, the chat and `team.GetColor` all read that one.
	]]
	OnApply = function(id, key)
		local faction = ix.faction.teams[id]

		if (not faction) then return end

		if (key == "color" or key == "name") then
			team.SetUp(faction.index, faction.name or id,
				faction.color or Color(200, 200, 200))
		end
	end
})

--------------------------------------------------------------------------------
-- S.P.E.C.I.A.L.
--------------------------------------------------------------------------------

--[[
	WHAT EACH ATTRIBUTE IS WORTH.

	Every other kind here edits a table - a SWEP, an item, a race - and this one
	edits `ix.config`, because that is where the seven attributes' rates have
	always lived and duplicating them into a table of our own would mean two
	places that disagree the moment somebody uses the config menu.

	It gets there through `Read` and `Write`, the escape hatch a field has for
	exactly this: the editor asks the field for its value and hands the field a
	new one, and what happens in between is the field's business. `ix.config.Set`
	networks and saves itself, so a change made here is a change made everywhere,
	immediately, and it survives a restart without the live store's help.

	THE SUBJECTS ARE THE SEVEN ATTRIBUTES rather than one list of thirteen
	numbers, which is why `ix.live.Fields` takes an id: Endurance's settings and
	Luck's have nothing to do with each other, and a screen that admits that is a
	screen somebody can read.
]]

--[[
	One config, as a field. `data` carries what the box should allow and what to
	say about it; the reader and writer are the same two lines every time.
]]
local function ConfigField(key, name, data)
	return {
		key = key,
		name = name,
		kind = "number",
		min = data.min,
		max = data.max,
		decimals = data.decimals or 0,
		note = data.note,

		Read = function() return ix.config.Get(key, data.fallback) end,

		Write = function(_, value)
			ix.config.Set(key, tonumber(value) or data.fallback)
		end,

		--[[
			WHAT RESET PUTS BACK: the value the code was written with, not the
			value the config happens to hold.

			`ix.config` saves itself, so an edit made last week is what
			`ix.config.Get` answers today - and a RESET that read the current
			value would put back the very thing it was undoing. Helix keeps the
			registered default beside the value for exactly this.
		]]
		Base = function()
			local stored = ix.config.stored and ix.config.stored[key]

			if (stored and stored.default ~= nil) then return stored.default end

			return data.fallback
		end
	}
end

--[[
	A fraction written as a fraction, with the percentage spelled out in words.

	0.01 is a percent, and every one of these is a percent-a-point by default -
	but the code multiplies by the fraction, and a box that showed 1 while the
	config held 0.01 would be lying about which of the two somebody is typing.
	So the box holds the real number and the note does the translation.
]]
local function RateField(key, name, what)
	return ConfigField(key, name, {
		min = 0, max = 0.1, decimals = 3, fallback = 0.01,
		note = "added to " .. what .. " per point, as a fraction of the "
			.. "damage - 0.01 is one percent a point, so ten points is ten "
			.. "percent"
	})
end

local SPECIAL_FIELDS = {
	general = {
		ConfigField("specialPoints", "Points at character creation", {
			min = 7, max = 70, fallback = 15,
			note = "the budget, which must be spent EXACTLY - Helix only "
				.. "refuses overspending, and this schema refuses both"
		}),

		ConfigField("maxAttributes", "Ceiling on one attribute", {
			min = 1, max = 100, fallback = 25,
			note = "the highest any single attribute may reach. Phoenix caps "
				.. "SPECIAL at 25"
		})
	},

	strength = {
		RateField("specialDamagePerStrength", "Melee damage", "melee damage")
	},

	perception = {
		RateField("specialDamagePerPerception", "Ballistic damage",
			"the damage of any weapon firing conventional ammunition")
	},

	endurance = {
		ConfigField("specialBaseStamina", "Stamina before Endurance", {
			min = 20, max = 500, fallback = 100,
			note = "the pool a character with no Endurance has. THE BAR IS "
				.. "ALWAYS 0-100 on screen; this is what that 100 represents, "
				.. "and a bigger pool moves the same bar more slowly"
		}),

		ConfigField("specialStaminaPerEndurance", "Stamina per point", {
			min = 0, max = 40, fallback = 6,
			note = "added to the pool per point of Endurance, which is both "
				.. "how long a sprint lasts and how fast it comes back - the "
				.. "rates below are a share of the pool, so a bigger pool "
				.. "spends and refills it proportionally more slowly"
		}),

		--[[
			THE THREE RATES, WHICH ARE HELIX'S OWN CONFIGS.

			They are per TICK, and the tick is a quarter of a second - so 1.75
			regeneration is seven a second, and a bar emptied by a long sprint
			is back in about fourteen. Stated here because "per tick" is
			meaningless without knowing how long a tick is, and the number
			looks four times bigger than it behaves.

			Endurance is applied on top of these by `AdjustStaminaOffset`
			(`sh_special.lua`), so these are the rates for somebody with none.
		]]
		ConfigField("staminaDrain", "Sprint drain per tick", {
			min = 0, max = 10, decimals = 2, fallback = 1,
			note = "taken every quarter second while sprinting, so 1 is four a "
				.. "second. Power Armour drains nothing at all"
		}),

		ConfigField("staminaRegeneration", "Regeneration per tick", {
			min = 0, max = 10, decimals = 2, fallback = 1.75,
			note = "regained every quarter second while not sprinting, so 1.75 "
				.. "is seven a second. Thirst above 50 adds a little and being "
				.. "hungry or parched halves it"
		}),

		ConfigField("staminaCrouchRegeneration", "Regeneration crouched", {
			min = 0, max = 10, decimals = 2, fallback = 2,
			note = "the same, while ducked - the rate somebody gets their "
				.. "breath back at behind cover"
		}),

		ConfigField("punchStamina", "Punch cost", {
			min = 0, max = 100, decimals = 0, fallback = 10,
			note = "stamina one bare-handed punch takes. Melee weapons have "
				.. "their own costs on the weapon"
		}),

		--[[
			JUMPS, NOT STAMINA PER JUMP.

			The config underneath is `jumpStaminaCost` - the number of stamina
			one jump takes out of a hundred - and that is the wrong way round
			for the person deciding it. "Four and a half jumps" is a rule
			somebody can test in the spawn room; "22.2 a jump" is the same rule
			with the interesting part hidden behind a division.

			So the box holds jumps and the two lines below turn it back. This
			is what a field's own `Read` and `Write` are for, and the config
			keeps its own meaning for everything that reads it.
		]]
		{
			key = "jumpStaminaCost",
			name = "Jumps from a full bar",
			kind = "number",
			min = 1, max = 30, decimals = 1,

			note = "how many times somebody with NO Endurance can jump before "
				.. "the bar is empty. A jump they cannot afford is refused, and "
				.. "once it IS empty they walk until it is half full again. "
				.. "Endurance buys more of them - at 10 the same 4.5 is a "
				.. "little over 7. Power Armour jumps for free",

			Read = function()
				local cost = ix.config.Get("jumpStaminaCost", 22.22)

				if (cost <= 0) then return 0 end

				return math.Round(100 / cost, 1)
			end,

			Write = function(_, value)
				local jumps = tonumber(value) or 4.5

				if (jumps <= 0) then return false end

				ix.config.Set("jumpStaminaCost", math.Round(100 / jumps, 2))
			end
		}
	},

	charisma = {
		ConfigField("specialMugReductionPerCharisma", "Mugging reduction", {
			min = 0, max = 0.05, decimals = 3, fallback = 0.01,
			note = "the share of a mugging demand talked down per point, as a "
				.. "fraction - 0.01 is one percent a point. Capped at 90 "
				.. "percent however high Charisma goes"
		})
	},

	intelligence = {
		RateField("specialDamagePerIntelligence", "Energy damage",
			"laser, plasma, gauss and tesla damage")
	},

	agility = {
		ConfigField("specialWalkPerAgility", "Walk speed per point", {
			min = 0, max = 30, fallback = 2,
			note = "units per second added to WALKING, which is what a "
				.. "character does for most of the time they are alive"
		}),

		ConfigField("specialSpeedPerAgility", "Run speed per point", {
			min = 0, max = 30, fallback = 4,
			note = "units per second added to RUNNING. Armour, chems and the "
				.. "race's own base speed are all added on top of this"
		})
	},

	luck = {
		ConfigField("specialLootLuckStep", "Luck per extra drop", {
			min = 1, max = 25, fallback = 5,
			note = "how many points of Luck earn one more step of container "
				.. "loot. 5 means the 5th, 10th and 15th points each add "
				.. "something and the ones between them do not"
		}),

		ConfigField("specialLootPerStep", "Items per step", {
			min = 0, max = 10, fallback = 1,
			note = "how many extra items each of those steps is worth. "
				.. "Quantity only - Luck never improves the QUALITY of what is "
				.. "in a container, which is the rarity roll's job"
		}),

		ConfigField("specialXPPerLuck", "Experience per point", {
			min = 0, max = 0.1, decimals = 3, fallback = 0.02,
			note = "as a fraction - 0.02 is two percent more experience a point"
		}),

		ConfigField("specialCraftPerLuck", "Crafting luck per point", {
			min = 0, max = 0.1, decimals = 3, fallback = 0.02,
			note = "as a fraction, on a crafting success roll"
		})
	}
}

--- What each attribute is for, in the subject list, so the seven read as a set.
local SPECIAL_NOTES = {
	general = "the budget and the ceiling",
	strength = "melee damage and carry weight",
	perception = "ballistic damage",
	endurance = "stamina, and how many jumps it is worth",
	charisma = "talking a mugger down",
	intelligence = "energy weapon damage",
	agility = "how fast you move, walking and running",
	luck = "what is in a container, and rolls that go your way"
}

ix.live.Register({
	id = "special",
	name = "SPECIAL",
	note = "what each attribute is worth",

	List = function()
		local out = {
			{id = "general", name = "General", note = SPECIAL_NOTES.general}
		}

		--[[
			IN SPECIAL ORDER, not alphabetically. It is an acronym: sorting it
			by name is sorting the letters of a word.
		]]
		for _, key in ipairs(ix.special.order) do
			out[#out + 1] = {
				id = key,
				name = string.upper(string.sub(key, 1, 1)) .. string.sub(key, 2),
				note = SPECIAL_NOTES[key]
			}
		end

		return out
	end,

	--[[
		A TARGET THAT IS NOT A TABLE OF SETTINGS.

		Every field here reads and writes `ix.config` and ignores what it is
		handed - but `ix.live.Apply` refuses a subject with no target at all,
		which is the guard that stops an edit to a weapon that no longer exists.
		`ix.special` is a real table and a truthful answer to "what does this
		subject belong to".
	]]
	Target = function(id)
		if (not SPECIAL_FIELDS[id]) then return nil end

		return ix.special
	end,

	fields = function(id)
		return SPECIAL_FIELDS[id] or {}
	end,

	--[[
		Speed is the one that is not read fresh when it is needed - it is SET on
		the player and stays set - so everybody's is recalculated here. The rest
		(damage, stamina, mugging, loot) is read at the moment it matters and
		needs nothing.
	]]
	OnApply = function()
		if (not SERVER or not ix.special.Apply) then return end

		for _, client in player.Iterator() do
			ix.special.Apply(client)
		end
	end
})

--------------------------------------------------------------------------------
-- Implants
--------------------------------------------------------------------------------

--[[
	WHAT EACH IMPLANT IS WORTH, and how many a body can hold.

	Nine implants, one subject each, and every bonus editable - which is why
	`ix.implants.list` holds the numbers rather than the nine item files: an
	item that carried its own +5 would need a schema edit and a restart to
	become a +3.

	The fields are built rather than written out, because "one row per stat an
	implant grants" is a shape, not a list - see `ix.live.ImplantFields`.
]]

--[[
	The stats an implant may grant. `ix.buff.stats` is every buff code in the
	schema; these are the ones an implant has any business touching - the
	SPECIAL seven plus health, which is what the two synth implants add.
]]
local IMPLANT_STATS = {
	{code = "STR", name = "Strength"},
	{code = "PER", name = "Perception"},
	{code = "END", name = "Endurance"},
	{code = "CHR", name = "Charisma"},
	{code = "INT", name = "Intelligence"},
	{code = "AGL", name = "Agility"},
	{code = "LCK", name = "Luck"},
	{code = "HP", name = "Maximum health"},
	{code = "DR", name = "Damage resistance"},
	{code = "RADRES", name = "Radiation resistance"}
}

--[[
	One field per stat, reading and writing `implant.buffs[code]`.

	The same escape hatch a chem's buffs use - `field.Read` and `field.Write` -
	because a bonus is an entry in a table that may or may not be there rather
	than a value at a fixed path. 0 removes it.
]]
local function ImplantFields(id)
	local out = {}

	for _, stat in ipairs(IMPLANT_STATS) do
		out[#out + 1] = {
			key = "buff." .. stat.code,
			name = stat.name,
			kind = "number",
			min = -20, max = 200, decimals = 0, default = 0,

			note = stat.code == "STR"
				and "SPECIAL points this implant grants while it is in. 0 "
					.. "takes the bonus off entirely"
				or nil,

			Read = function(target)
				return (target.buffs or {})[stat.code] or 0
			end,

			Write = function(target, value)
				target.buffs = target.buffs or {}

				value = math.Round(tonumber(value) or 0)

				target.buffs[stat.code] = value ~= 0 and value or nil
			end
		}
	end

	--[[
		WHAT IT IS CALLED AND WHAT IT SAYS, which are as much a part of an
		implant as its numbers - a server that rebalances one usually wants to
		rename it too, and the tooltip reads both from here.
	]]
	out[#out + 1] = {
		key = "name",
		name = "Name",
		kind = "string",
		note = "shown on the item, in the extractor's list and in the editor"
	}

	out[#out + 1] = {
		key = "description",
		name = "Description",
		kind = "string",
		note = "what it IS. Do not write the numbers in here - the bonuses "
			.. "above are listed under it automatically, and a description "
			.. "that repeats them is a second copy that goes stale the moment "
			.. "you change one"
	}

	--[[
		AND THE ONE SETTING THAT IS NOT A BONUS. A locked implant is the C.I.T
		one and the rule around it is real - who may fit it, and what happens
		to the patient when somebody else digs it out.
	]]
	out[#out + 1] = {
		key = "faction",
		name = "Faction that may handle it",
		kind = "string",
		note = "a faction's id, or blank for anybody. Only that faction may "
			.. "fit or remove it - and a VOLATILE one kills the patient when "
			.. "anybody else tries"
	}

	out[#out + 1] = {
		key = "volatile",
		name = "Detonates on the wrong hands",
		kind = "bool",
		default = false,
		note = "with a faction set above, extracting it as anybody else kills "
			.. "the patient. This is the C.I.T rule and nothing else uses it"
	}

	return out
end

ix.live.Register({
	id = "implant",
	name = "IMPLANTS",
	note = "what each one grants, and who may fit it",

	List = function()
		local out = {}

		for id, implant in pairs(ix.implants.list) do
			local bonuses = {}

			for code, amount in SortedPairs(implant.buffs or {}) do
				bonuses[#bonuses + 1] = string.format("%s%d %s",
					amount >= 0 and "+" or "", amount, code)
			end

			out[#out + 1] = {
				id = id,
				name = implant.name or id,
				note = table.concat(bonuses, "  ")
			}
		end

		table.sort(out, function(a, b) return a.name < b.name end)

		return out
	end,

	Target = function(id)
		return ix.implants.list[id]
	end,

	fields = function(id)
		return ImplantFields(id)
	end,

	--[[
		Everybody carrying one gets it again, because the bonuses are buffs and
		a buff already applied does not know its number changed.
	]]
	OnApply = function()
		if (not SERVER or not ix.implants.Apply) then return end

		for _, client in player.Iterator() do
			ix.implants.Apply(client)
		end
	end
})

--------------------------------------------------------------------------------
-- Survival: food, water and radiation
--------------------------------------------------------------------------------

--[[
	THE THREE THINGS THAT WEAR A CHARACTER DOWN, in one section.

	Hunger, thirst and rads are the same shape - a bar that moves on its own and
	a ladder of tiers that take SPECIAL off you as it empties or fills - so they
	are three subjects of one kind rather than three sections.

	The RATES are `ix.config`, edited through the same `ConfigField` the SPECIAL
	section uses. The TIERS are tables in `sh_hunger.lua` and `sh_radiation.lua`,
	edited through `Read`/`Write` fields that reach into them - which is what
	makes "how bad is starving" a thing an admin can answer.
]]

--- One tier's SPECIAL penalty, as a field. `where` is the tier table.
local function TierField(where, threshold, attribute, name)
	return {
		key = string.format("%s.%d.%s", where, threshold, attribute),
		name = name,
		kind = "number",
		min = -10, max = 10, decimals = 0, default = 0,

		Read = function(target)
			local tier = target[threshold]

			return tier and (tier.special or {})[attribute] or 0
		end,

		Write = function(target, value)
			local tier = target[threshold]

			if (not tier) then return false end

			tier.special = tier.special or {}

			value = math.Round(tonumber(value) or 0)

			tier.special[attribute] = value ~= 0 and value or nil
		end
	}
end

--[[
	Every tier of one ladder, as fields.

	`ix.special.order` is walked rather than a hand-written list, so a schema
	that gains an eighth attribute gains a row here without this being touched.
]]
local function LadderFields(where, tiers, thresholds)
	local out = {}

	for index, threshold in ipairs(thresholds) do
		local tier = tiers[threshold]

		if (not tier) then continue end

		--[[
			THE BAND IS IN THE NAME, because a penalty that applies between 20
			and 39 is a different thing from one that applies at 20 - and
			somebody editing "Hungry" and then standing there at 45 wondering
			why nothing changed has not made a mistake, they have been told
			nothing.
		]]
		local upper = thresholds[index + 1]
		local band = upper and string.format("%d-%d", threshold, upper - 1)
			or string.format("%d+", threshold)

		for _, attribute in ipairs(ix.special.order) do
			out[#out + 1] = TierField(where, threshold, attribute,
				string.format("%s (%s): %s", tier.name, band,
					string.upper(string.sub(attribute, 1, 3))))
		end
	end

	return out
end

local SURVIVAL_FIELDS

local function Survival(id)
	SURVIVAL_FIELDS = SURVIVAL_FIELDS or {
		hunger = {
			ConfigField("hungerDrainIdle", "Drain standing still", {
				min = 0, max = 2, decimals = 2, fallback = 0.01,
				note = "per tick, and a tick is hungerTickRate seconds. At "
					.. "0.01 a second a motionless character takes about two "
					.. "and a half hours to go from full to starving"
			}),

			ConfigField("hungerDrainMoving", "Drain walking", {
				min = 0, max = 2, decimals = 2, fallback = 0.02,
				note = "per tick, while moving at any speed below a run"
			}),

			ConfigField("hungerDrainRunning", "Drain running", {
				min = 0, max = 2, decimals = 2, fallback = 0.03,
				note = "per tick, while sprinting - about fifty minutes from "
					.. "full to starving at the default"
			}),

			ConfigField("hungerTickRate", "Seconds a tick lasts", {
				min = 0.1, max = 10, decimals = 1, fallback = 1,
				note = "how often all six drains above are applied. This is "
					.. "SHARED with thirst - they are one clock"
			})
		},

		thirst = {
			ConfigField("thirstDrainIdle", "Drain standing still", {
				min = 0, max = 2, decimals = 2, fallback = 0.01,
				note = "per tick. Thirst runs on the same clock as hunger"
			}),

			ConfigField("thirstDrainMoving", "Drain walking", {
				min = 0, max = 2, decimals = 2, fallback = 0.02,
				note = "per tick, while moving at any speed below a run"
			}),

			ConfigField("thirstDrainRunning", "Drain running", {
				min = 0, max = 2, decimals = 2, fallback = 0.03,
				note = "per tick, while sprinting"
			})
		}
	}

	if (id == "hunger") then
		local out = {}

		for _, field in ipairs(SURVIVAL_FIELDS.hunger) do
			out[#out + 1] = field
		end

		for _, field in ipairs(LadderFields("hunger",
			ix.hunger.hungerTiers, {0, 20, 40, 60, 80})) do
			out[#out + 1] = field
		end

		return out
	end

	if (id == "thirst") then
		local out = {}

		for _, field in ipairs(SURVIVAL_FIELDS.thirst) do
			out[#out + 1] = field
		end

		for _, field in ipairs(LadderFields("thirst",
			ix.hunger.thirstTiers, {0, 20, 40, 60, 80})) do
			out[#out + 1] = field
		end

		return out
	end

	if (id == "radiation") then
		local out = {}

		for _, threshold in ipairs(ix.radiation.thresholds) do
			local tier = ix.radiation.debuffs[threshold]

			if (not tier) then continue end

			--[[
				HEALTH FIRST, because it is the one thing rads take that
				hunger does not - a flat cut to the maximum, which is what
				makes the top two tiers frightening rather than annoying.
			]]
			out[#out + 1] = {
				key = string.format("radiation.%d.health", threshold),
				name = string.format("%s (%d+ rads): max health", tier.name,
					threshold),
				kind = "number",
				min = -200, max = 0, decimals = 0, default = 0,

				Read = function(target)
					return (target[threshold] or {}).health or 0
				end,

				Write = function(target, value)
					local entry = target[threshold]

					if (not entry) then return false end

					value = math.Round(tonumber(value) or 0)

					entry.health = value ~= 0 and value or nil
				end
			}

			for _, attribute in ipairs(ix.special.order) do
				out[#out + 1] = TierField("radiation", threshold, attribute,
					string.format("%s (%d+ rads): %s", tier.name, threshold,
						string.upper(string.sub(attribute, 1, 3))))
			end
		end

		return out
	end

	return {}
end

ix.live.Register({
	id = "survival",
	name = "SURVIVAL",
	note = "food, water and radiation - the rates and what each tier costs",

	List = function()
		return {
			{id = "hunger", name = "Food",
				note = "drain rates, and what each band of hunger costs"},
			{id = "thirst", name = "Water",
				note = "drain rates, and what each band of thirst costs"},
			{id = "radiation", name = "Radiation",
				note = "what each level of poisoning costs"}
		}
	end,

	--[[
		The TIER TABLE is the target, because that is what the fields reach
		into - the rates are `ix.config` and reach it themselves.
	]]
	Target = function(id)
		if (id == "hunger") then return ix.hunger.hungerTiers end
		if (id == "thirst") then return ix.hunger.thirstTiers end
		if (id == "radiation") then return ix.radiation.debuffs end

		return nil
	end,

	fields = function(id)
		return Survival(id)
	end,

	--[[
		Everybody is re-evaluated, because a tier's penalty is applied when the
		tier is ENTERED - somebody who has been starving for an hour would keep
		yesterday's numbers until they ate something and got hungry again.
	]]
	--[[
		NOTHING TO PUSH. Both ladders are READ when they are needed -
		`ix.hunger.GetSpecialModifier` and `ix.radiation.GetTier` are called
		from the SPECIAL and health paths every time those are recalculated -
		so an edited tier is in effect the moment it is written.

		`ix.special.Apply` is called anyway, because speed is the one thing
		that is SET on a player rather than read: a race or an implant that
		changes it needs saying, and so does a tier that changes Agility.
	]]
	OnApply = function()
		if (not SERVER or not ix.special.Apply) then return end

		for _, client in player.Iterator() do
			ix.special.Apply(client)
		end
	end
})

--------------------------------------------------------------------------------
-- The F1 menu
--------------------------------------------------------------------------------

--[[
	A kind with no subjects and no fields: the whole section is one list, and
	the window draws it itself - see `PANEL:BuildTabs`.

	It is registered as a kind anyway so it appears in the same column as
	everything else. A settings screen where one of the settings lives
	somewhere different is a settings screen people do not find.
]]
ix.live.Register({
	id = "menu",
	name = "MENU",
	note = "the order of the tabs everybody sees",

	List = function() return {} end,
	Target = function() return nil end,
	fields = {}
})
