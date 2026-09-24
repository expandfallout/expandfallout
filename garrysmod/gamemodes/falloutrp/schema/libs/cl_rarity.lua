--[[
	Rarity on weapon icons and in weapon descriptions.

	INJECTED INTO EVERY WEAPON ITEM, not written into 259 files. The weapons
	inherit Helix's own `base_weapons`, which is in the framework rather than
	the schema - editing it would mean carrying a patched copy of a Helix file
	for ever, and editing the 259 generated items would mean the generator
	overwriting all of it on its next run.

	So `PaintOver` and `GetDescription` are WRAPPED on each weapon's item table
	once, after everything has loaded. Wrapping rather than replacing, because
	several weapons already define their own and this must add to them rather
	than throw them away.

	`InitializedPlugins` is the hook: it fires after `ix.item.list` is
	populated, and it fires on the client, which `InitPostEntity` does not do
	reliably in this schema at all. See `07-gotchas.md`.
]]

if (not CLIENT) then return end

--[[
	The description, in the shape asked for:

	    Rare R-700

	    A awesome sniper rifle.

	    * Head: 2x [3x - Rarity]
	    * Body: 1.5x [2x - Rarity]
	    * Legs: 1x [1.5x - Rarity]

	The hitgroup numbers come from `ix.hitgroup.Describe`, which is the same
	function the damage hook reads its profile from - a description that
	disagreed with what the weapon actually does would be worse than none at
	all.

	The bracketed column only appears when there is a rarity to multiply by.
	On an uncrafted weapon it is three plain lines, because "[1x - Rarity]"
	beside every number is noise that says nothing.
]]
local function Describe(item)
	local rarity = ix.rarity.Get(item)
	local lines = {}

	--[[
		THE WEAPON'S OWN QUALITY LADDER AND ITS CEILING.

		`ix.rarity.Tier(x).damage` is the server-wide ladder, and a weapon whose
		Legendary has been set to 1.1 - or whose ceiling refuses anything above
		1.2 - would have had a description promising the shared 1.4. Same
		function the damage hook calls, so the number here is the number fired.
	]]
	local multiplier

	if (rarity) then
		multiplier = ix.combat and ix.combat.RarityDamage
			and ix.combat.RarityDamage(item)
			or ix.rarity.Tier(rarity).damage
	end

	--[[
		BASE DAMAGE IS THE WEAPON'S OWN, before rarity and before SPECIAL.

		Stated as the base rather than the final number because the final
		number depends on who is holding it - a rifle is worth more in the
		hands of somebody with the Perception for it, and an item description
		that changed depending on who opened it would be lying to one of them.
		The rarity multiplier below says what this particular one adds.
	]]
	local damage, rpm = ix.hitgroup.Stats(item.uniqueID)

	if (damage) then
		lines[#lines + 1] = string.format("Base DMG: %s",
			ix.hitgroup.Format(damage))

		if (multiplier) then
			lines[#lines] = lines[#lines] .. string.format(" [%s - Rarity]",
				ix.hitgroup.Format(damage * multiplier))
		end
	end

	if (rpm) then
		lines[#lines + 1] = string.format("RPM: %d", rpm)
	end

	if (#lines > 0) then
		lines[#lines + 1] = ""
	end

	lines[#lines + 1] = ix.hitgroup.Describe(item.uniqueID, multiplier)

	return table.concat(lines, "\n")
end

local function Wrap(itemTable)
	if (itemTable.ixRarityWrapped) then return end

	--- Marked so a `lua_refresh` cannot wrap the wrapper around itself.
	itemTable.ixRarityWrapped = true

	local paint = itemTable.PaintOver

	--[[
		Called by Helix as `itemTable.PaintOver(panel, itemTable, w, h)` - the
		panel first, the table second. Getting that order wrong draws nothing
		and errors nowhere.
	]]
	itemTable.PaintOver = function(panel, item, width, height)
		if (paint) then paint(panel, item, width, height) end

		ix.rarity.PaintItem(item, width, height)
	end

	local describe = itemTable.GetDescription

	itemTable.GetDescription = function(self)
		local base = describe and describe(self) or self.description
		local extra = Describe(self)

		return extra and (base .. "\n\n" .. extra) or base
	end

	--[[
		THE RARITY IS PART OF THE NAME, not a line under it. "Rare R-700" is
		what the thing is called, and putting it in the name puts it everywhere
		the name already appears - the inventory label, the pickup
		notification, chat, and anything else that asks an item what it is
		called.

		The tooltip sets it again for itself; see the `PopulateItemTooltip`
		hook below. That is not redundant - the tooltip also has to repaint the
		row, and it re-checks the prefix rather than assuming this ran.
	]]
	local getName = itemTable.GetName

	itemTable.GetName = function(self)
		local name = getName and getName(self) or self.name
		local rarity = ix.rarity.Get(self)

		if (not rarity) then return name end

		return ix.rarity.Tier(rarity).name .. " " .. name
	end
end

hook.Add("InitializedPlugins", "ixRarityWeapons", function()
	local count = 0

	for _, itemTable in pairs(ix.item.list) do
		if (itemTable.base == "base_weapons") then
			Wrap(itemTable)

			count = count + 1
		end
	end

	if (ix.fallout and ix.fallout.CreateTrace) then
		ix.fallout.CreateTrace("rarity: wrapped " .. count .. " weapons")
	end
end)

--[[
	The tooltip: the rarity in the name, and in the colour of the name.

	DONE HERE AS WELL AS IN `GetName`, and the two are not redundant. The wrap
	covers everywhere a name is printed - chat, notifications, the inventory
	label - and this covers the tooltip specifically, because the tooltip is
	also where the COLOUR has to change and the colour is not part of a name.

	`SetImportant` has already painted the row `ix.config.Get("color")` by the
	time this runs, which is the base yellow every item gets. Repainting it the
	rarity's colour is the whole point: a Legendary rifle should be recognisable
	before the text is read.
]]
hook.Add("PopulateItemTooltip", "ixRarity", function(tooltip, item)
	local id = ix.rarity.Get(item)

	if (not id) then return end

	local row = tooltip:GetRow("name")

	if (not IsValid(row)) then return end

	local tier = ix.rarity.Tier(id)

	--[[
		The flat colour, not `GetColor` - a tooltip row is painted once when it
		is built rather than every frame, so Master Craft cannot cycle here and
		would simply freeze on whatever hue it was born with.
	]]
	row:SetBackgroundColor(tier.color)

	--[[
		Re-set rather than assumed. If the `GetName` wrap did not take - a
		weapon whose item table was registered after the wrapping pass, say -
		this is what still puts the tier in front of the name, and if it did
		take then the text already starts with the tier and nothing changes.
	]]
	local name = item.GetName and item:GetName() or item.name

	if (not string.StartWith(name, tier.name)) then
		name = tier.name .. " " .. name
	end

	row:SetText(name)
	row:SizeToContents()
end)

--[[
	The damage readout beside the crosshair, scaled by rarity.

	`cl_damageview.lua` was written with this hook in it and a comment saying a
	rarity system would plug in here - so it does, and that file needed no
	edit.

	IT RETURNS THE NEW BASE, not a bonus. The readout computes the SPECIAL
	bonus as `damage * (multiplier - 1)` AFTER calling this, so handing it the
	rarity-adjusted damage is what makes the buffs apply to the weapon this
	actually is rather than to the one it would have been unrolled.
]]
hook.Add("GetWeaponDisplayDamage", "ixRarity", function(client, weapon, damage)
	--[[
		NOT `weapon.ixItem` - that is server-only and this file is not. See
		`ix.rarity.HeldItem`, which is where the whole reason lives.
	]]
	local item = ix.rarity.HeldItem(client, weapon)

	if (not item) then return end

	local multiplier = ix.rarity.Damage(item)

	if (multiplier == 1) then return end

	return math.Round(damage * multiplier, 2)
end)
