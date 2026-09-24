--[[
	Looting.

	A GECK equivalent: admins author loot tables and place containers in game
	without writing Lua. The model starts from Phoenix's exported
	`itemtables.json` and their loot table editor, then goes past both.

	THEIR THREE FLAGS ARE ONE SETTING.

	The export carries `useAll`, `calcToLevel` and `calcAllInCount` as separate
	booleans, which reads like three independent options. Their editor gives it
	away - ticking any one of the three DISABLES the other two:

	    self.calcFromLevel.OnChange = function(s)
	        if s:GetChecked() then self.useAll:SetChecked(false) end
	        self.useAll:SetDisabled(self.calcForEach:GetChecked() or checked)
	                    -- geck/derma/cl_geck_loottableeditor.lua

	So it is one setting with four states, and it is stored that way here: a
	`mode`. Three booleans that cannot co-exist is a shape that lets you save
	nonsense; a mode cannot be in two states at once.

	    one     pick a single entry            (their default, no flag set)
	    all     use every entry                (useAll)
	    rolls   N independent picks            (calcAllInCount)
	    level   pick from entries you qualify for  (calcToLevel)

	WHAT THIS ADDS THAT THE GECK COULD NOT DO.

	Their entries carry a flat `count` and nothing else, so every entry in a
	table was equally likely and always gave the same amount. Here each entry
	also has:

	    weight    relative likelihood when one is picked - a common item can
	              be ten times as likely as a rare one inside one table,
	              instead of needing a nest of tables to express odds
	    chance    a per-entry percentage applied AFTER it is picked, so an
	              entry can be "usually nothing, sometimes this"
	    min/max   a count RANGE rather than a fixed number

	Old data still loads: an entry with a plain `count` is read as
	`min = max = count`, and a table with `useAll` is read as `mode = "all"`.
]]

ix.loot = ix.loot or {}

ix.loot.tables = ix.loot.tables or {}

--[[
	How deep a nested table reference may go. A cycle is trivially easy to
	author by accident in an editor like this and would otherwise recurse until
	the server died.
]]
ix.loot.maxDepth = 8

--[[
	The four modes, with the text the editor shows. Ordered, because a hash
	gives no useful order and the editor cycles through them.
]]
ix.loot.modes = {"one", "all", "rolls", "level"}

ix.loot.modeNames = {
	one = "PICK ONE",
	all = "USE ALL ENTRIES",
	rolls = "ROLL N TIMES",
	level = "BY LEVEL"
}

ix.loot.modeHelp = {
	one = "One entry, chosen by weight.",
	all = "Every entry is used.",
	rolls = "N independent picks, chosen by weight.",
	level = "One entry from those the looter's level allows."
}

ix.config.Add("lootRespawnTime", 600,
	"Seconds before a looted container refills.", nil, {
	data = {min = 0, max = 86400}, category = "Looting"
})

ix.config.Add("lootLuckBonus", true,
	"Whether Luck grants extra rolls from containers.", nil, {
	category = "Looting"
})

--- A blank table in the shape the editor expects.
function ix.loot.NewTable(name)
	return {
		name = name or "New Table",
		spawnChance = 100,
		mode = "one",
		rolls = 1,
		items = {}
	}
end

--- A blank entry. `class` or `table` is filled in by the caller.
function ix.loot.NewEntry()
	return {
		weight = 1,
		chance = 100,
		min = 1,
		max = 1,
		level = 1
	}
end

--[[
	Read old data into the current shape.

	Runs on load and on any table coming in from the editor, so a table saved
	before modes existed is upgraded the first time it is touched rather than
	needing a migration pass over the whole file.
]]
function ix.loot.Normalise(data)
	if (not istable(data)) then return end

	data.spawnChance = tonumber(data.spawnChance) or 100
	data.rolls = math.max(math.floor(tonumber(data.rolls) or 1), 1)
	data.items = data.items or {}

	if (not data.mode) then
		--[[
			Their three booleans, in the order their editor enforced: whichever
			was ticked won, and `useAll` was the one the others switched off.
		]]
		if (data.useAll) then
			data.mode = "all"
		elseif (data.calcAllInCount) then
			data.mode = "rolls"
		elseif (data.calcToLevel) then
			data.mode = "level"
		else
			data.mode = "one"
		end
	end

	data.useAll = nil
	data.calcAllInCount = nil
	data.calcToLevel = nil

	for _, entry in ipairs(data.items) do
		--[[
			A flat `count` becomes a range of itself. Their data only ever used
			1 and 2, so nothing is lost and everything gains a range.
		]]
		if (entry.count and not entry.min) then
			entry.min = entry.count
			entry.max = entry.count
		end

		entry.count = nil

		entry.weight = math.max(tonumber(entry.weight) or 1, 0)
		entry.chance = math.Clamp(tonumber(entry.chance) or 100, 0, 100)
		entry.min = math.max(math.floor(tonumber(entry.min) or 1), 0)
		entry.max = math.max(math.floor(tonumber(entry.max) or entry.min), entry.min)
		entry.level = math.max(math.floor(tonumber(entry.level) or 1), 1)
	end

	return data
end

function ix.loot.Get(name)
	return ix.loot.tables[name]
end

--- Every table name, sorted, for the editor's list.
function ix.loot.GetNames()
	local names = {}

	for name in pairs(ix.loot.tables) do
		names[#names + 1] = name
	end

	table.sort(names)

	return names
end

--- A one-line summary of an entry, shared by the editor and the report.
function ix.loot.DescribeEntry(entry)
	local amount = entry.min == entry.max and tostring(entry.min)
		or string.format("%d-%d", entry.min, entry.max)

	local parts = {"x" .. amount}

	if ((entry.weight or 1) ~= 1) then
		parts[#parts + 1] = "w" .. entry.weight
	end

	if ((entry.chance or 100) < 100) then
		parts[#parts + 1] = entry.chance .. "%"
	end

	if ((entry.level or 1) > 1) then
		parts[#parts + 1] = "lvl " .. entry.level
	end

	return table.concat(parts, "  ")
end

--[[
	Pick one entry by weight.

	Weight zero means "never by random pick" without deleting the entry, which
	is how you park something you are still authoring. If every candidate is
	weightless there is nothing to pick, and that is not an error.
]]
local function WeightedPick(entries)
	local total = 0

	for _, entry in ipairs(entries) do
		total = total + math.max(entry.weight or 1, 0)
	end

	if (total <= 0) then return nil end

	local roll = math.random() * total

	for _, entry in ipairs(entries) do
		roll = roll - math.max(entry.weight or 1, 0)

		if (roll <= 0) then return entry end
	end

	return entries[#entries]
end

--[[
	Roll a table into a flat list of `{uniqueID, count}`.

	`level` is the looter's level, used only by the `level` mode. Everything
	after it is internal: `depth` and `seen` guard recursion, `unresolved`
	collects anything that could not be resolved so the caller can report it -
	a table quietly producing nothing because it names a deleted item looks
	exactly like one that rolled badly.
]]
function ix.loot.Roll(name, level, depth, seen, unresolved)
	local results = {}

	level = level or 1
	depth = depth or 1
	seen = seen or {}
	unresolved = unresolved or {}

	if (depth > ix.loot.maxDepth) then return results, unresolved end

	local lootTable = ix.loot.tables[name]

	if (not lootTable) then
		unresolved[#unresolved + 1] = {table = name, reason = "no such table"}
		return results, unresolved
	end

	if (seen[name]) then
		unresolved[#unresolved + 1] = {table = name, reason = "cycle"}
		return results, unresolved
	end

	seen[name] = true

	local entries = lootTable.items or {}

	--[[
		The table's own chance gates the whole thing. A 5% table fires rarely;
		when it does, it produces normally. Per-entry chance is separate and
		applies after selection.
	]]
	if (#entries == 0
	or math.random() * 100 > (lootTable.spawnChance or 100)) then
		seen[name] = nil
		return results, unresolved
	end

	local mode = lootTable.mode or "one"
	local candidates = entries

	if (mode == "level") then
		--[[
			Only entries the looter qualifies for. Modelled as a floor rather
			than a band, so a high-level character can still find common loot -
			the alternative locks players out of the early tables entirely.
		]]
		candidates = {}

		for _, entry in ipairs(entries) do
			if ((entry.level or 1) <= level) then
				candidates[#candidates + 1] = entry
			end
		end
	end

	local chosen = {}

	if (mode == "all") then
		chosen = candidates
	elseif (mode == "rolls") then
		for _ = 1, math.max(lootTable.rolls or 1, 1) do
			local picked = WeightedPick(candidates)

			if (picked) then chosen[#chosen + 1] = picked end
		end
	else
		local picked = WeightedPick(candidates)

		if (picked) then chosen[1] = picked end
	end

	for _, entry in ipairs(chosen) do
		-- The per-entry gate, after selection.
		if (math.random() * 100 <= (entry.chance or 100)) then
			local count = math.random(entry.min or 1, entry.max or entry.min or 1)

			if (count > 0) then
				if (entry.table) then
					--[[
						A nested table is rolled `count` times rather than once
						for `count` items, so each draw gets that table's own
						spawn chance applied independently.
					]]
					for _ = 1, count do
						local nested = ix.loot.Roll(entry.table, level,
							depth + 1, seen, unresolved)

						for _, result in ipairs(nested) do
							results[#results + 1] = result
						end
					end
				elseif (entry.class) then
					if (ix.item.list[entry.class]) then
						results[#results + 1] = {uniqueID = entry.class, count = count}
					else
						unresolved[#unresolved + 1] =
							{class = entry.class, reason = "no such item"}
					end
				end
			end
		end
	end

	seen[name] = nil

	return results, unresolved
end

--[[
	Roll a table many times and total what came out.

	This is the editor's preview, and it is the feature that makes authoring
	odds possible at all - weights and chances multiply through nested tables
	in ways nobody can do in their head. Phoenix had a "Preview Results" button
	for the same reason.

	Returns `{[uniqueID] = {count, appearances}}` plus how many of the runs
	produced nothing at all, which is the number that tells you whether a
	container will usually be empty.
]]
function ix.loot.Simulate(name, runs, level)
	local totals = {}
	local empty = 0

	runs = math.Clamp(runs or 100, 1, 10000)

	for _ = 1, runs do
		local results = ix.loot.Roll(name, level)

		if (#results == 0) then
			empty = empty + 1
		end

		for _, result in ipairs(results) do
			local record = totals[result.uniqueID]

			if (not record) then
				record = {count = 0, appearances = 0}
				totals[result.uniqueID] = record
			end

			record.count = record.count + result.count
			record.appearances = record.appearances + 1
		end
	end

	return totals, empty, runs
end

--[[
	Validate before saving. Returns `true` or `false, reason`, so a mistake is
	refused where it is made rather than discovered when a container is empty.
]]
function ix.loot.Validate(data)
	if (not istable(data)) then return false, "not a table" end

	if (not isstring(data.name) or string.Trim(data.name) == "") then
		return false, "a table needs a name"
	end

	if (not isnumber(data.spawnChance)
	or data.spawnChance < 0 or data.spawnChance > 100) then
		return false, "spawn chance must be between 0 and 100"
	end

	if (not table.HasValue(ix.loot.modes, data.mode or "one")) then
		return false, "unknown mode: " .. tostring(data.mode)
	end

	if (not istable(data.items)) then return false, "items must be a list" end

	for index, entry in ipairs(data.items) do
		if (not entry.class and not entry.table) then
			return false, string.format("entry %d is neither an item nor a table", index)
		end

		if (entry.class and not ix.item.list[entry.class]) then
			return false, "no such item: " .. tostring(entry.class)
		end

		if (entry.table and entry.table == data.name) then
			return false, "a table cannot reference itself"
		end

		if ((entry.max or 1) < (entry.min or 1)) then
			return false, string.format("entry %d has a max below its min", index)
		end
	end

	return true
end

--[[
	A short badge for a table's mode, for the tree view.

	`rolls` carries its number because "ROLL N" without the N is the one badge
	that does not say what it does.
]]
function ix.loot.ModeBadge(lootTable)
	local mode = lootTable and lootTable.mode or "one"

	if (mode == "rolls") then
		return "ROLL " .. math.max(lootTable.rolls or 1, 1)
	end

	return ({one = "PICK 1", all = "ALL", level = "BY LEVEL"})[mode] or mode
end

--[[
	Percentages, written the way the numbers actually come out.

	Nesting multiplies, so a real answer in this system is anything from 100%
	to 0.000001%. A fixed number of decimal places is wrong at one end or the
	other - "0.00%" says nothing about a drop that is meant to be rare, and
	"60.000000%" is noise - so the format follows the value:

	    100%      certain
	    10.47%    two decimals down to a hundredth of a percent
	    5e-05%    scientific below that, because there is no readable
	              decimal form of 0.00005 in a column this narrow
]]
function ix.loot.FormatChance(value)
	value = tonumber(value) or 0

	if (value <= 0) then return "0%" end
	if (value >= 99.995) then return "100%" end

	if (value >= 0.01) then
		local text = string.format("%.2f", value)

		--[[
			Trailing zeros dropped so a whole number reads as one: 60, not
			60.00. The optional dot in the pattern is what lets the dot go too.
		]]
		if (string.find(text, "%.")) then
			text = string.gsub(text, "%.?0+$", "")
		end

		return text .. "%"
	end

	return string.format("%.0e%%", value)
end

--[[
	How likely each entry in a table is to be SELECTED, as a fraction of one.

	SELECTION ONLY. This answers "how often does this entry win a pick", which
	is what the editor's PICKED column shows. It is deliberately NOT the answer
	to "how often does this entry produce something" - that is
	`ix.loot.EntryChances`, and under ROLL N the two are not one multiplication
	apart.

	    all     every entry, always                        1
	    one     by weight                                  w / W
	    rolls   N independent draws, so the chance of
	            appearing AT ALL is one minus the chance
	            of being missed every time                 1 - (1 - w/W)^N
	    level   by weight, among entries the looter's
	            level allows                               w / W(qualifying)

	`rolls` is the one worth spelling out: N times the share would be the
	obvious formula and it is wrong - three rolls at 50% is not 150%.
]]
function ix.loot.SelectionChances(lootTable, level)
	local entries = lootTable.items or {}
	local mode = lootTable.mode or "one"
	local chances = {}

	if (mode == "all") then
		for index = 1, #entries do
			chances[index] = 1
		end

		return chances
	end

	local total = 0

	for index, entry in ipairs(entries) do
		local qualifies = mode ~= "level" or (entry.level or 1) <= (level or 1)

		chances[index] = qualifies and math.max(entry.weight or 1, 0) or 0
		total = total + chances[index]
	end

	-- Every candidate weightless, or none qualifying: nothing can be selected.
	if (total <= 0) then
		for index = 1, #entries do
			chances[index] = 0
		end

		return chances
	end

	local rolls = mode == "rolls" and math.max(lootTable.rolls or 1, 1) or 1

	for index = 1, #entries do
		local share = chances[index] / total

		chances[index] = rolls > 1 and 1 - (1 - share) ^ rolls or share
	end

	return chances
end

--[[
	How often each entry actually PRODUCES something, as a fraction of one.

	Selection and the entry's own chance are not independent steps that can be
	multiplied afterwards, and getting that wrong is not a rounding error. Under
	ROLL N the chance gate is rolled once per draw, so the entry's own chance
	has to be folded in BEFORE the repeated draws:

	    right    1 - (1 - share x chance)^N
	    wrong    (1 - (1 - share)^N) x chance

	With two rolls, a half share and a half chance those give 43.75% and 37.5%.
	Checked against four hundred thousand simulated openings: the first tracks
	to within a tenth of a percentage point, the second is six points low.

	For every other mode the two are the same thing, because N is one.
]]
function ix.loot.EntryChances(lootTable, level)
	local entries = lootTable.items or {}
	local mode = lootTable.mode or "one"
	local chances = {}

	if (mode == "all") then
		for index, entry in ipairs(entries) do
			chances[index] = math.Clamp(entry.chance or 100, 0, 100) / 100
		end

		return chances
	end

	local weights = {}
	local total = 0

	for index, entry in ipairs(entries) do
		local qualifies = mode ~= "level" or (entry.level or 1) <= (level or 1)

		weights[index] = qualifies and math.max(entry.weight or 1, 0) or 0
		total = total + weights[index]
	end

	if (total <= 0) then
		for index = 1, #entries do
			chances[index] = 0
		end

		return chances
	end

	local rolls = mode == "rolls" and math.max(lootTable.rolls or 1, 1) or 1

	for index, entry in ipairs(entries) do
		local perDraw = weights[index] / total
			* math.Clamp(entry.chance or 100, 0, 100) / 100

		chances[index] = rolls > 1 and 1 - (1 - perDraw) ^ rolls or perDraw
	end

	return chances
end

--[[
	Expand a table into a tree of nodes with a real percentage on each one.

	This is what the configurer draws. The GECK showed a flat list per table
	and left you to hold the nesting in your head; the numbers here are the
	whole reason the tree is worth having, because a chain of four tables at
	60%, 50%, 25% and 12% is a drop nobody would guess at from the individual
	figures.

	`reach` is the chance of getting this far BEFORE this table's own spawn
	chance is applied. The root is called with 100 and applies its own, so
	every node in the tree means the same thing: "how often a single roll of
	the container produces this".

	NOT AN ESTIMATE. The percentages are exact for one roll of each parent
	entry. The one thing they do not model is a nested table with a count
	above one, which is rolled that many times - the `xN` on the row says so,
	and the node's percentage is the chance of the FIRST of those rolls.

	Guarded twice: `seen` is the set of tables on the current branch, so a
	cycle stops at the point it closes rather than recursing forever, and
	`maxDepth` catches a chain that is merely absurd rather than circular.
]]
function ix.loot.BuildTree(name, level, reach, depth, seen)
	level = level or 1
	reach = reach or 100
	depth = depth or 1
	seen = seen or {}

	local lootTable = ix.loot.tables[name]

	local node = {
		kind = "table",
		name = name,
		label = name,
		depth = depth,
		chance = reach,
		children = {}
	}

	if (not lootTable) then
		node.kind = "missing"
		node.note = "there is no table with this name"

		return node
	end

	node.spawnChance = lootTable.spawnChance or 100
	node.mode = lootTable.mode or "one"
	node.rolls = lootTable.rolls or 1
	node.badge = ix.loot.ModeBadge(lootTable)
	node.entryCount = #(lootTable.items or {})
	node.chance = reach * node.spawnChance / 100

	if (seen[name]) then
		node.cycle = true
		node.note = "already open on this branch - stopped here"

		return node
	end

	if (depth > ix.loot.maxDepth) then
		node.note = "nested deeper than " .. ix.loot.maxDepth .. " - stopped here"

		return node
	end

	seen[name] = true

	local chances = ix.loot.EntryChances(lootTable, level)

	for index, entry in ipairs(lootTable.items or {}) do
		local reached = node.chance * (chances[index] or 0)
		local child

		if (entry.table) then
			child = ix.loot.BuildTree(entry.table, level, reached, depth + 1, seen)
		else
			local itemTable = ix.item.list[entry.class]

			child = {
				kind = itemTable and "item" or "missing",
				name = entry.class,
				label = itemTable and itemTable.name or entry.class,
				depth = depth + 1,
				chance = reached,
				note = not itemTable and "no item has this uniqueID" or nil
			}
		end

		child.entry = entry
		child.index = index
		child.parent = name
		--[[
			Whether this entry can be edited where it is shown. Only the table
			the editor has open owns its entries; deeper ones belong to another
			table and have to be opened there, or two people editing two tables
			would each be changing the other's.
		]]
		child.owned = depth == 1

		node.children[#node.children + 1] = child
	end

	seen[name] = nil

	return node
end
