--[[
	The four benches that exist on a server nobody has configured yet.

	WRITTEN ONCE, ON THE FIRST BOOT THAT HAS NO SAVED TYPES AT ALL - not on
	every boot, and not when the saved list is merely EMPTY. Those two are
	different states and telling them apart is the whole point: an admin who
	deletes the chem bench has decided something, and a seeder that could not
	tell "never configured" from "configured to nothing" would put it back
	every restart and there would be no way to be rid of it.

	`ix.data.Get` returning nil is the first state; returning a table, even an
	empty one, is the second. `sv_bench.lua` reads the same value, which is why
	this runs from inside its load rather than from a hook of its own.

	They are ORDINARY BENCHES. Nothing here is special-cased anywhere else -
	each one is exactly what `/benchconfig` would have produced, so all four
	can be edited, renamed, re-modelled or deleted like any other. They are a
	starting point and an example of each mode, not a fixture.
]]

if (not SERVER) then return end

--[[
	Every item named below is one that exists in `items/`, and a seed naming
	one that does not would be rejected by `ix.bench.Validate` and leave the
	server with no benches at all - so `ix.bench.Seed` drops recipes whose
	items are missing rather than losing the whole bench with them.
]]
local SEEDS = {
	{
		uniqueID = "chembench",
		name = "Chem Bench",
		description = "Mixing chems. Slow, and worth it.",
		model = "models/mosi/fallout4/furniture/workstations/"
			.. "chemistrystation01.mdl",
		mode = "craft",
		invW = 6,
		invH = 4,
		recipes = {
			{
				output = "stimpak", outputAmount = 1, time = 20, xp = 6,
				input = {
					{item = "mat_antiseptic", amount = 2},
					{item = "mat_steel", amount = 1},
					{item = "mat_cloth", amount = 1}
				}
			},
			{
				output = "radaway", outputAmount = 1, time = 25, xp = 6,
				input = {
					{item = "mat_antiseptic", amount = 2},
					{item = "mat_plastic", amount = 1},
					{item = "mat_acid", amount = 1}
				}
			},
			{
				output = "medx", outputAmount = 1, time = 20, xp = 6,
				input = {
					{item = "mat_antiseptic", amount = 1},
					{item = "mat_acid", amount = 1},
					{item = "mat_steel", amount = 1}
				}
			},
			{
				output = "healingpowder", outputAmount = 2, time = 12, xp = 3,
				input = {
					{item = "mat_antiseptic", amount = 1},
					{item = "mat_hide", amount = 1}
				}
			}
		}
	},
	{
		uniqueID = "craftbench",
		name = "Crafting Bench",
		description = "Components, out of scrap.",
		model = "models/mosi/fallout4/furniture/workstations/"
			.. "workshopbench.mdl",
		mode = "craft",
		invW = 8,
		invH = 5,
		recipes = {
			{
				output = "mat_screws", outputAmount = 2, time = 10, xp = 2,
				input = {{item = "mat_steel", amount = 1}}
			},
			{
				output = "mat_duct_tape", outputAmount = 1, time = 12, xp = 2,
				input = {
					{item = "mat_adhesive", amount = 1},
					{item = "mat_cloth", amount = 1}
				}
			},
			{
				output = "mat_gears", outputAmount = 1, time = 15, xp = 3,
				input = {
					{item = "mat_steel", amount = 2},
					{item = "mat_oil", amount = 1}
				}
			},
			{
				output = "mat_springs", outputAmount = 2, time = 15, xp = 3,
				input = {{item = "mat_steel", amount = 2}}
			},
			{
				output = "mat_ballistic_fiber", outputAmount = 1, time = 45,
				xp = 10,
				input = {
					{item = "mat_cottonyarn", amount = 2},
					{item = "mat_adhesive", amount = 1},
					{item = "mat_fiberglass", amount = 1}
				}
			}
		}
	},
	{
		--[[
			The processing one. You load it and walk away, which is the mode
			that has no equivalent anywhere else in the schema and the reason
			`process` exists at all.
		]]
		uniqueID = "smelter",
		name = "Smelter",
		description = "Load it with ore. It works on its own.",
		model = "models/mosi/fallout4/furniture/workstations/"
			.. "cookingstation04.mdl",
		mode = "process",
		invW = 8,
		invH = 5,
		recipes = {
			{
				output = "mat_bariron", outputAmount = 1, time = 30, xp = 4,
				input = {{item = "mat_oreiron", amount = 2}}
			},
			{
				output = "mat_barbronze", outputAmount = 1, time = 35, xp = 4,
				input = {{item = "mat_orebronze", amount = 2}}
			},
			{
				output = "mat_barsilver", outputAmount = 1, time = 45, xp = 6,
				input = {{item = "mat_oresilver", amount = 2}}
			},
			{
				output = "mat_bargold", outputAmount = 1, time = 60, xp = 8,
				input = {{item = "mat_oregold", amount = 2}}
			},
			{
				output = "mat_baruranium", outputAmount = 1, time = 90,
				xp = 12,
				input = {{item = "mat_oreuranium", amount = 2}}
			},
			{
				output = "mat_barsaturnite", outputAmount = 1, time = 120,
				xp = 16,
				input = {{item = "mat_oresaturnite", amount = 2}}
			}
		}
	},
	{
		--[[
			The infinite one: no inputs, and it fills its own inventory until
			there is no room, at which point it jams rather than spilling. See
			`ix.bench.HasRoom`.
		]]
		uniqueID = "condenser",
		name = "Water Condenser",
		description = "Pulls clean water out of the air. Slowly.",
		model = "models/mosi/fallout4/furniture/workstations/"
			.. "powerarmorstation01.mdl",
		mode = "infinite",
		invW = 5,
		invH = 4,

		--[[
			The one seed that refuses input. It consumes nothing, so anything
			put in could only ever be stored - which is a locker, not a bench.
		]]
		allowInput = false,
		recipes = {
			{
				output = "drink_purified_water", outputAmount = 1, time = 180,
				xp = 0, input = {}
			}
		}
	}
}

--[[
	Fill in the fields a seed does not bother to write, and drop what is not
	installed.

	The seeds above say only what makes them different from a blank type, so
	`ix.bench.NewType` is what decides the defaults - one place, and a new
	field added there appears in all four without touching this list.
]]
function ix.bench.Seed()
	local made, skipped = 0, 0

	for _, seed in ipairs(SEEDS) do
		local definition = ix.bench.NewType(seed.uniqueID)

		for key, value in pairs(seed) do
			if (key ~= "recipes") then definition[key] = value end
		end

		definition.recipes = {}

		for _, entry in ipairs(seed.recipes) do
			if (not ix.item.list[entry.output]) then
				skipped = skipped + 1

				continue
			end

			local recipe = ix.bench.NewRecipe(entry.output)

			recipe.outputAmount = entry.outputAmount or 1
			recipe.time = entry.time or 10
			recipe.xp = entry.xp or 0
			recipe.input = {}

			local complete = true

			for _, input in ipairs(entry.input or {}) do
				if (not ix.item.list[input.item]) then
					complete = false

					break
				end

				recipe.input[#recipe.input + 1] = {
					item = input.item,
					amount = input.amount or 1
				}
			end

			--[[
				A recipe missing ONE of its inputs is dropped whole rather than
				written without it. A stimpak that costs two antiseptic instead
				of two antiseptic and a steel is not the recipe anybody meant,
				and it would be a silently cheaper one.
			]]
			if (complete) then
				definition.recipes[#definition.recipes + 1] = recipe
			else
				skipped = skipped + 1
			end
		end

		local ok, reason = ix.bench.Validate(definition)

		if (not ok) then
			ErrorNoHalt(string.format(
				"[falloutrp] not seeding the '%s' bench: %s\n",
				seed.uniqueID, reason))

			continue
		end

		ix.bench.types[seed.uniqueID] = definition
		made = made + 1
	end

	MsgC(Color(255, 200, 100), string.format(
		"[falloutrp] seeded %d starter bench(es)%s\n", made,
		skipped > 0 and string.format(", skipped %d recipe(s) whose items are "
			.. "not installed", skipped) or ""))

	return made
end
