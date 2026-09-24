--[[
	Modulators: permanent upgrades fitted to a suit of body armour.

	Phoenix's `modulators` plugin. Eight of them, one per SPECIAL attribute and
	one for radiation, each worth +3 (or +15% rads), fitted at a bench and never
	taken out again. What they really are is a way to spend the junk end of the
	economy on the equipment you already have.

	    one of each per suit    a suit can hold every kind, but only one of any
	                            kind - so the ceiling is fixed and known
	    body armour only        never a helmet, never a plate. Phoenix's rule,
	                            and it is what keeps the ceiling to one suit's
	                            worth rather than one per slot
	    the modulator is spent  the item is consumed; the armour keeps it
	    it belongs to the SUIT  stored in item data, so it survives being
	                            dropped, traded, stored and restarted, and a
	                            second suit of the same armour has its own

	WHAT IS DEFINED WHERE

	    the items          `items/modulator/`, one file each. The numbers live
	                       there, on the item, because that is the thing an
	                       admin opens when they want to change one
	    this file          reading those numbers back off a suit, and the
	                       arithmetic every other system asks for
	    `sh_armor.lua`     adds what this returns into the armour totals, so a
	                       fitted modulator is indistinguishable from an armour
	                       that always had the stat
	    the bench          mode `modulate`; see `sh_bench.lua` and
	                       `cl_modulate.lua`

	THERE IS NO REGISTRY TO KEEP IN STEP. Phoenix register each modulator in a
	table AND generate an item from it, so the two can disagree; here the item
	list IS the registry - anything flagged `isModulator` is one - and a new
	modulator is one file and no other edit.
]]

ix.modulator = ix.modulator or {}

--[[
	Every modulator item, sorted by name.

	Walked rather than cached: `ix.item.list` is complete by the time anything
	asks, and a cache would be one more thing to invalidate when an item is
	reloaded with `ix_reload`.
]]
function ix.modulator.Kinds()
	local out = {}

	for _, itemTable in pairs(ix.item.list) do
		if (itemTable.isModulator) then
			out[#out + 1] = itemTable
		end
	end

	table.sort(out, function(a, b)
		return (a.name or a.uniqueID) < (b.name or b.uniqueID)
	end)

	return out
end

--[[
	Which modulators are fitted to a suit, as `{[uniqueID] = true}`.

	ALWAYS A TABLE, never nil, and never the item's own storage - the caller
	gets a copy to read, so nothing can write a modulator onto a suit by
	mutating what it was handed.
]]
function ix.modulator.Installed(item)
	if (not item or not item.GetData) then return {} end

	local out = {}

	for uniqueID, value in pairs(item:GetData("mods", {}) or {}) do
		if (value and ix.item.list[uniqueID]
		and ix.item.list[uniqueID].isModulator) then
			out[uniqueID] = true
		end
	end

	return out
end

--[[
	Can this modulator go into this armour? `true`, or `false, reason`.

	The reasons are written to be shown to the player, because every caller -
	the window, the bench, and the server's own check - wants to say the same
	thing.
]]
function ix.modulator.CanFit(itemTable, armor)
	if (not itemTable or not itemTable.isModulator) then
		return false, "That is not a modulator."
	end

	if (not armor or not armor.isArmor) then
		return false, "That is not armour."
	end

	--[[
		BODY ONLY, and the test is the slot rather than a flag on the armour.
		Phoenix say the same thing in their item description - "will only work
		on Full Body Armor" - and enforce it by only ever offering the body
		slot in their window, which is a rule the window keeps rather than the
		system.
	]]
	if (armor.bodyType ~= "body") then
		return false, "Modulators only fit body armour."
	end

	if (ix.modulator.Installed(armor)[itemTable.uniqueID]) then
		return false, string.format("That suit already has a %s.",
			itemTable.name or "modulator")
	end

	return true
end

--------------------------------------------------------------------------------
-- What they are worth
--------------------------------------------------------------------------------

--[[
	The SPECIAL a suit's modulators add, keyed by attribute.

	Read by `ix.armor.GetSpecialBonus`, so a fitted modulator reaches the
	attribute system, the HUD's modifier list and everything that scales off
	SPECIAL by exactly the route an armour's own `specialBonus` does.
]]
function ix.modulator.Special(item)
	local out = {}

	for uniqueID in pairs(ix.modulator.Installed(item)) do
		for key, value in pairs(ix.item.list[uniqueID].modSpecial or {}) do
			if (value ~= 0) then out[key] = (out[key] or 0) + value end
		end
	end

	return out
end

--[[
	What a suit's modulators add to one armour FIELD - `radResistance` and the
	rest.

	Same shape as reading the field off the item table, so `ix.armor`'s own
	summing adds one term and keeps working.
]]
function ix.modulator.Field(item, field)
	local total = 0

	for uniqueID in pairs(ix.modulator.Installed(item)) do
		local fields = ix.item.list[uniqueID].modFields or {}
		local value = tonumber(fields[field]) or 0

		total = total + value
	end

	return total
end

--[[
	What one modulator does, in words.

	BUILT FROM THE NUMBERS rather than written next to them, which is the same
	rule the armour description follows: Phoenix keep an `armorDesc` string
	beside the bonus and the two can disagree - and in their data, two of them
	do.
]]
function ix.modulator.Line(itemTable)
	if (not itemTable) then return "" end

	local parts = {}

	for _, key in ipairs(ix.special and ix.special.order or {}) do
		local value = (itemTable.modSpecial or {})[key]

		if (value and value ~= 0) then
			parts[#parts + 1] = string.format("%s%d %s",
				value > 0 and "+" or "", value,
				(ix.armor and ix.armor.specialCodes[key])
					or string.upper(key))
		end
	end

	for _, field in ipairs({"resistance", "radResistance", "fallProtection"}) do
		local value = (itemTable.modFields or {})[field]

		if (value and value ~= 0) then
			parts[#parts + 1] = string.format("%s%d%% %s",
				value > 0 and "+" or "", value,
				field == "resistance" and "Damage Resistance"
					or field == "radResistance" and "Radiation Resistance"
					or "Fall Protection")
		end
	end

	return table.concat(parts, ", ")
end

--- The lines a suit's own description ends with, one per fitted modulator.
function ix.modulator.Lines(item)
	local out = {}

	for uniqueID in pairs(ix.modulator.Installed(item)) do
		local itemTable = ix.item.list[uniqueID]
		local line = ix.modulator.Line(itemTable)

		out[#out + 1] = string.format(" - %s%s",
			itemTable.name or uniqueID,
			line ~= "" and (": " .. line) or "")
	end

	table.sort(out)

	return out
end
