--[[
	What a character is made of, as a list of meshes.

	SHARED, AND THAT IS THE POINT OF THE FILE. `cl_bodyparts.lua` builds the
	clientside models that make a person visible; this decides WHICH models,
	and it runs on both sides so the server can compose the same list for a
	body at the moment of death and send it with the ragdoll. A client drawing
	a corpse then needs nothing but the recipe - not the character, which a
	bot never has on a client and a player takes with them when they leave.

	Everything here reads shared state: the race tables, the character's
	appearance vars, the item list, and the armour render set the server
	already broadcasts per slot as NW2 strings on the player.

	`ix.fallout` IS DECLARED HERE TOO: `cl_` files load before `sh_` ones
	(gotcha 26), so `cl_bodyparts.lua` has already made the table by the time
	this runs, and on the server this is the first to.
]]

ix.fallout = ix.fallout or {}

--[[
	Kept for the character-select preview and creation screens, which need
	SOMETHING to show for a character that has no race yet - one created before
	races existed, or a creation payload mid-flight.
]]
ix.fallout.animationModel = "models/phoenix/humans/animations.mdl"

ix.fallout.bodyParts = {
	"models/roadkill/fallout/player/male/defaultbody.mdl",
	"models/roadkill/fallout/player/male/head.mdl"
}

--[[
	The armour a character is wearing, as parts, plus what it hides.

	Read from the PLAYER, not the character. Equipped state is authoritative on
	the item, but item data is networked to its owner alone - everyone has to
	see everyone else's armour, so the server derives a render set and
	broadcasts it per slot (`sv_armor.lua`). This is the consumer of that.

	Returns `parts, hidden`, where `hidden` names the body parts the armour
	replaces so the caller can leave them out rather than draw them underneath.

	Models are existence-checked for the same reason the race lists are: this
	schema ships 685 armour definitions and not every content pack they came
	from is installed. A missing model draws nothing here instead of an ERROR
	prop bone-merged to a player.
]]
function ix.fallout.GetArmorParts(character, gender)
	local parts, hidden = {}, {}

	if (not character or not ix.armor) then return parts, hidden end

	local client = character:GetPlayer()

	if (not IsValid(client)) then return parts, hidden end

	for _, slot in ipairs(ix.armor.slots) do
		local uniqueID = client:GetNW2String("ixArmor_" .. slot, "")

		if (uniqueID == "") then continue end

		local itemTable = ix.item.list[uniqueID]

		if (not itemTable) then continue end

		--[[
			Falls back to the male mesh when a female one was never made, which
			is common in the source data. Wrong-shaped armour reads better than
			a character who is suddenly naked from the waist up.
		]]
		local model = gender == "female" and itemTable.femaleModel or itemTable.maleModel

		if (not model or model == "") then
			model = itemTable.maleModel
		end

		if (model and model ~= "" and file.Exists(model, "GAME")) then
			parts[#parts + 1] = {
				model = model,
				-- `skin = false` in the contract means "inherit the race skin".
				skin = itemTable.skin or nil,
				bodyGroups = itemTable.bodyGroups
			}
		end

		--[[
			A body armour's mesh IS a clothed body, so the bare one underneath
			has to go. `takesBody` covers the head, hair and beard; the body
			itself is implied by the slot.
		]]
		if (slot == "body") then
			hidden.body = true
		end

		for part, taken in pairs(itemTable.takesBody or {}) do
			if (taken) then hidden[part] = true end
		end
	end

	return parts, hidden
end

--[[
	The parts a character is composed of, in draw order.

	Returns a list of {model = path, skin = index}. Hair and beard are indices
	into the race's lists, and both are filtered for missing content at load, so
	an index can outlive the option it pointed at - hence the bounds check
	rather than a bare lookup.
]]
function ix.fallout.GetBodyParts(character)
	if (not character) then return ix.fallout.bodyParts end

	local class = character:GetRace()
	local race = ix.races and ix.races.Get(class)

	-- No race data: fall back to the hardcoded pair rather than an empty body.
	if (not race) then return ix.fallout.bodyParts end

	local gender = character:GetGender()
	local ethnicity = character:GetEthnicity()
	local parts = {}

	--[[
		Armour first, because it decides what else gets drawn.

		A worn piece can replace the head, the hair or the beard
		(`ITEM.takesBody`), and anything in the `body` slot replaces the body
		mesh outright - its model is a fully clothed body, so leaving the bare
		one underneath would z-fight rather than hide.
	]]
	local armor, hidden = ix.fallout.GetArmorParts(character, gender)

	local body = ix.races.GetBody(class, gender)
	local skin = ix.races.GetSkin(class, gender, ethnicity)

	if (body and not hidden.body) then
		parts[#parts + 1] = {model = body, skin = skin}
	end

	local head = ix.races.GetHead(class, gender, ethnicity)

	if (head and not hidden.head) then
		parts[#parts + 1] = {model = head, skin = skin}
	end

	-- Per gender; see RACE.hairBoost on why one value cannot serve both.
	local boost = ix.races.GetHairBoost(class, gender)

	local hairs = ix.races.GetHairs(class, gender)
	local hair = character:GetHair()

	if (hair > 0 and hairs[hair] and not hidden.hair) then
		parts[#parts + 1] = {model = hairs[hair], hair = true, boost = boost}
	end

	local beards = ix.races.GetBeards(class, gender)
	local beard = character:GetBeard()

	if (beard > 0 and beards[beard] and not hidden.beard) then
		parts[#parts + 1] = {model = beards[beard], hair = true, boost = boost}
	end

	--[[
		Armour last so it draws over the body it sits on. Order matters here
		only for the parts that overlap; the bone merge does the rest.
	]]
	for _, part in ipairs(armor) do
		parts[#parts + 1] = part
	end

	return parts
end

--- The hair/beard tint for a character, as a Color.
function ix.fallout.GetHairColor(character)
	if (not character) then return color_white end

	return string.ToColor(character:GetHairColor()) or color_white
end


--[[
	A body's recipe: the parts and the hair tint, and nothing that needs the
	character to read back.

	`carrier` is the model the parts will be merged onto. A race whose body IS
	its animation model - a gecko, a securitron, anything with `defaultModels`
	naming the same file - would otherwise merge a second copy of that model
	onto a ragdoll that already draws it, and two identical meshes in one place
	flicker against each other. Dropped for a corpse; a living player is left
	as they were.
]]
function ix.fallout.Recipe(character, carrier)
	local color = ix.fallout.GetHairColor(character)
	local parts = {}

	carrier = carrier and string.lower(carrier) or nil

	for _, entry in ipairs(ix.fallout.GetBodyParts(character)) do
		local model = istable(entry) and entry.model or entry

		if (not carrier or not isstring(model)
		or string.lower(model) ~= carrier) then
			parts[#parts + 1] = entry
		end
	end

	return {
		parts = parts,
		hair = {r = color.r, g = color.g, b = color.b}
	}
end

--------------------------------------------------------------------------------
-- The same, for somebody who is not a character
--------------------------------------------------------------------------------

--[[
	AN NPC HAS NO CHARACTER. It has a preset: a race, a gender, and a list of
	armour item ids. These compose the same parts `GetBodyParts` composes for
	a character, from a SPEC instead - the fields a character would have
	answered from its vars - so the NPC is dressed by the code that dresses
	everybody else and nothing about armour is written twice.

	    spec = {race, gender, ethnicity, hair, beard, hairColor, armour = {ids}}

	Armour is resolved PER SLOT, the last id named for a slot winning, the
	same way `ix.armor.GetEquipped` yields one item per slot.
]]
function ix.fallout.SpecArmorParts(armour, gender)
	local parts, hidden = {}, {}
	local bySlot = {}

	for _, uniqueID in ipairs(armour or {}) do
		local itemTable = ix.item.list[uniqueID]

		if (itemTable and itemTable.isArmor and itemTable.bodyType) then
			bySlot[itemTable.bodyType] = itemTable
		end
	end

	for _, slot in ipairs(ix.armor and ix.armor.slots or {}) do
		local itemTable = bySlot[slot]

		if (not itemTable) then continue end

		local model = gender == "female" and itemTable.femaleModel or itemTable.maleModel

		if (not model or model == "") then model = itemTable.maleModel end

		if (model and model ~= "" and file.Exists(model, "GAME")) then
			parts[#parts + 1] = {
				model = model,
				skin = itemTable.skin or nil,
				bodyGroups = itemTable.bodyGroups
			}
		end

		if (slot == "body") then hidden.body = true end

		for part, taken in pairs(itemTable.takesBody or {}) do
			if (taken) then hidden[part] = true end
		end
	end

	return parts, hidden
end

function ix.fallout.SpecParts(spec)
	local race = spec and ix.races and ix.races.Get(spec.race)

	if (not race) then return ix.fallout.bodyParts end

	local class, gender, ethnicity = spec.race, spec.gender, spec.ethnicity
	local parts = {}
	local armor, hidden = ix.fallout.SpecArmorParts(spec.armour, gender)

	local body = ix.races.GetBody(class, gender)
	local skin = ix.races.GetSkin(class, gender, ethnicity)

	if (body and not hidden.body) then
		parts[#parts + 1] = {model = body, skin = skin}
	end

	local head = ix.races.GetHead(class, gender, ethnicity)

	if (head and not hidden.head) then
		parts[#parts + 1] = {model = head, skin = skin}
	end

	local boost = ix.races.GetHairBoost(class, gender)
	local hairs = ix.races.GetHairs(class, gender)
	local hair = tonumber(spec.hair) or 0

	if (hair > 0 and hairs[hair] and not hidden.hair) then
		parts[#parts + 1] = {model = hairs[hair], hair = true, boost = boost}
	end

	local beards = ix.races.GetBeards(class, gender)
	local beard = tonumber(spec.beard) or 0

	if (beard > 0 and beards[beard] and not hidden.beard) then
		parts[#parts + 1] = {model = beards[beard], hair = true, boost = boost}
	end

	for _, part in ipairs(armor) do
		parts[#parts + 1] = part
	end

	return parts
end

--- What `Recipe` returns, from a spec; the carrier's own mesh left out.
function ix.fallout.RecipeFromSpec(spec, carrier)
	local color = spec and spec.hairColor or {r = 60, g = 40, b = 25}
	local parts = {}

	carrier = carrier and string.lower(carrier) or nil

	for _, entry in ipairs(ix.fallout.SpecParts(spec)) do
		local model = istable(entry) and entry.model or entry

		if (not carrier or not isstring(model)
		or string.lower(model) ~= carrier) then
			parts[#parts + 1] = entry
		end
	end

	return {
		parts = parts,
		hair = {r = color.r or 60, g = color.g or 40, b = color.b or 25}
	}
end
