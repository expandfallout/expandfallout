--[[
	Blueprints: what a character has learned, and what it costs to build.

	A BLUEPRINT BENCH HAS NO RECIPE LIST OF ITS OWN. Every other bench is a
	fixed menu; this one shows what the person standing at it knows, and two
	people at the same bench see different things. That is the whole idea -
	the bench is a place to work and the knowledge is the property.

	    ix.blueprint.defaults   the generated starting recipe per weapon
	    ix.blueprint.recipes    what an admin has changed since, from `ix.data`
	    ix.blueprint.frames     frame sizes an admin has changed
	    character blueprints    what one character has learned

	THE DEFAULTS ARE GENERATED, NOT DERIVED HERE. `sh_blueprintdefaults.lua` is
	written by the same tool that writes the frames, so the number the server
	charges and the number the client displays come from one file. Working the
	formula out again in Lua would be a second implementation to keep in step
	with the Python one, and the one that drifts quietly is the client - which
	would offer crafts the server then refuses.
]]

ix.blueprint = ix.blueprint or {}

--- `[weapon] = {input = {{item, amount}, ...}, time, xp}`. Admin overrides.
ix.blueprint.recipes = ix.blueprint.recipes or {}

--- `[weapon] = {width, height}`. Admin overrides for frame sizes.
ix.blueprint.frames = ix.blueprint.frames or {}

--- Where a character's learned list lives.
ix.blueprint.KEY = "blueprints"

--------------------------------------------------------------------------------
-- Reading
--------------------------------------------------------------------------------

--- Every weapon that has a blueprint, sorted, so both realms agree on order.
function ix.blueprint.All()
	local out = {}

	for weapon in pairs(ix.blueprint.defaults or {}) do
		if (ix.item.list[weapon]) then out[#out + 1] = weapon end
	end

	table.sort(out)

	return out
end

--[[
	What this weapon costs to build.

	The admin's override if there is one, else the generated default. Returned
	as a COPY, because the bench window hands recipes around and a caller
	writing to one would edit the stored table for everybody.
]]
function ix.blueprint.Recipe(weapon)
	local stored = ix.blueprint.recipes[weapon]
		or (ix.blueprint.defaults or {})[weapon]

	if (not stored) then return nil end

	local out = {
		output = weapon,
		outputAmount = 1,
		time = math.Clamp(math.floor(stored.time or 60), 1, 3600),
		xp = math.max(math.floor(stored.xp or 0), 0),
		input = {}
	}

	for _, entry in ipairs(stored.input or {}) do
		--[[
			Stored as `{item, amount}` pairs and read out as the `{item =,
			amount =}` shape every bench recipe uses. The pair form is what the
			generator writes because it is a third the size across 259 entries;
			the named form is what the rest of the system already speaks.
		]]
		local uniqueID = entry.item or entry[1]
		local amount = entry.amount or entry[2] or 1

		if (ix.item.list[uniqueID]) then
			out.input[#out.input + 1] = {item = uniqueID, amount = amount}
		end
	end

	return out
end

--- The frame item for a weapon, if one was generated for it.
function ix.blueprint.Frame(weapon)
	return ix.item.list["frame_" .. tostring(weapon)]
end

--------------------------------------------------------------------------------
-- What a character knows
--------------------------------------------------------------------------------

--[[
	Stored on the CHARACTER rather than in a table of its own.

	`character:GetData` is the `data` field on `ix_characters`, so a learned
	blueprint survives a restart with everything else about the character and
	nothing had to be added to the database to make that true. Same reasoning
	as the item stacks in `sh_stack.lua`.
]]
function ix.blueprint.Known(client)
	local character = client and client:GetCharacter()

	if (not character) then return {} end

	local stored = character:GetData(ix.blueprint.KEY)

	return istable(stored) and stored or {}
end

function ix.blueprint.Knows(client, weapon)
	if (not weapon) then return false end

	return ix.blueprint.Known(client)[weapon] == true
end

--- How many a character has learned, for the menu and the tooltip.
function ix.blueprint.CountKnown(client)
	return table.Count(ix.blueprint.Known(client))
end

--[[
	The recipes a blueprint bench offers THIS character.

	Sorted by weapon id, which is what makes an index sent from the client mean
	the same thing on the server. Anything else - name order, learn order -
	would differ between the two the moment a weapon was renamed or a second
	blueprint learned, and the index is how a craft says which recipe it wants.
]]
function ix.blueprint.RecipesFor(client)
	local known = ix.blueprint.Known(client)
	local names = {}

	for weapon in pairs(known) do
		if (ix.item.list[weapon]) then names[#names + 1] = weapon end
	end

	table.sort(names)

	local out = {}

	for _, weapon in ipairs(names) do
		local recipe = ix.blueprint.Recipe(weapon)

		if (recipe) then out[#out + 1] = recipe end
	end

	return out
end

--------------------------------------------------------------------------------
-- Frame sizes
--------------------------------------------------------------------------------

--[[
	Apply the stored frame sizes to the item tables.

	FRAMES ARE THE ONE THING WHOSE SIZE IS WORTH TUNING IN GAME. A rifle frame
	that takes two slots and a minigun frame that takes two slots is a bag that
	says nothing about what is in it, and the right answer per weapon is a
	balance question rather than a fact - so it is a setting rather than a
	number in a generated file that an edit would overwrite.

	Written onto `ix.item.list` directly because Helix reads width and height
	off the item table when it places anything, and there is no per-instance
	size. Applied on both realms: the server places into the grid, the client
	draws the icon, and a disagreement about the size is an item that cannot be
	picked up where it appears to be.
]]
function ix.blueprint.ApplySizes()
	for weapon, size in pairs(ix.blueprint.frames) do
		local itemTable = ix.blueprint.Frame(weapon)

		if (itemTable and istable(size)) then
			itemTable.width = math.Clamp(math.floor(size[1] or 2), 1, 8)
			itemTable.height = math.Clamp(math.floor(size[2] or 1), 1, 8)
		end
	end
end

--- The size a frame is currently, override or the item's own.
function ix.blueprint.FrameSize(weapon)
	local itemTable = ix.blueprint.Frame(weapon)

	if (not itemTable) then return 2, 1 end

	return itemTable.width or 2, itemTable.height or 1
end
