--[[
	Races.

	Phoenix's `nut.races` in Helix form. A race is the appearance and physical
	contract for a character: which body and head meshes compose it, which
	hairstyles and beards are offered, how much health it has, how it scales,
	whether it takes radiation.

	WHY THIS EXISTS SEPARATELY FROM FACTIONS
	----------------------------------------
	Helix has factions, and a faction carries a list of whole player models.
	That is the wrong shape for this schema: Fallout characters are COMPOSED at
	render time from a meshless animation skeleton plus separate body, head,
	hair and beard meshes (see `cl_bodyparts.lua`), because that is what lets
	armour replace body parts without needing a model per combination.

	A faction says which side you are on; a race says what you are made of. A
	Wastelander and an NCR Trooper are both `human`.

	CONTENT AVAILABILITY
	--------------------
	Every model path is checked at load and dropped if the file is not
	installed, so the customiser can never offer an option that would render as
	an error model. `fo_races_report` prints exactly what was dropped, because a
	silently shortened list is indistinguishable from a race that never had
	those options.

	This is not hypothetical. Of the human race's 53 appearance models, the 14
	beards are not in any installed content pack, and neither are the 112
	facemap materials - so beards and face skins are unavailable until that
	content is added, while bodies, heads and all 32 hairstyles work.
]]

ix.races = ix.races or {}
ix.races.list = ix.races.list or {}

-- What load-time filtering removed, for `fo_races_report`.
ix.races.missing = ix.races.missing or {}

--[[
	Model availability.

	`file.Exists(path, "GAME")` searches the mounted content the same way the
	engine does, so this answers the question the engine would answer. Results
	are cached because the customiser asks repeatedly while the player clicks
	through options.
]]
local modelExists = {}

function ix.races.ModelExists(path)
	if (not isstring(path) or path == "") then return false end

	local cached = modelExists[path]

	if (cached == nil) then
		cached = file.Exists(path, "GAME")
		modelExists[path] = cached
	end

	return cached
end

--[[
	Filter a list of model paths down to those actually installed.

	Returns the filtered list and records the drops. A list that ends up empty
	is returned as nil rather than `{}`: the difference matters to the UI, which
	should skip a category entirely rather than show an empty picker.
]]
local function FilterModels(class, category, models)
	if (not istable(models)) then return models end

	local kept = {}

	for i = 1, #models do
		local path = models[i]

		if (ix.races.ModelExists(path)) then
			kept[#kept + 1] = path
		else
			ix.races.missing[#ix.races.missing + 1] = {
				race = class,
				category = category,
				path = path
			}
		end
	end

	return #kept > 0 and kept or nil
end

--- Filter a gender-keyed table of model lists, e.g. RACE.hairs.
local function FilterByGender(class, category, data)
	if (not istable(data)) then return data end

	local result = {}
	local any = false

	for gender, models in pairs(data) do
		local filtered = FilterModels(class, category .. "." .. gender, models)

		if (filtered) then
			result[gender] = filtered
			any = true
		end
	end

	return any and result or nil
end

--- Filter a gender/ethnicity-keyed table of single models, e.g. RACE.heads.
local function FilterHeads(class, data)
	if (not istable(data)) then return data end

	local result = {}
	local any = false

	for gender, byEthnicity in pairs(data) do
		if (istable(byEthnicity)) then
			local kept = {}
			local keptAny = false

			for ethnicity, path in pairs(byEthnicity) do
				--[[
					`false` IS A DECLARATION, NOT A MISSING MODEL.

					Phoenix write `heads = {male = {default = false}}` on every
					race whose body is the whole thing - a radroach has no
					separate head to bolt on. Treating that as a path and asking
					whether it exists reported seventy "missing models" that were
					never meant to exist, and buried the one race whose body
					genuinely is not installed.

					Kept as `false` so the ethnicity still exists and whatever
					draws the character knows there is nothing to attach.
				]]
				if (path == false or path == nil) then
					kept[ethnicity] = false
					keptAny = true
				elseif (ix.races.ModelExists(path)) then
					kept[ethnicity] = path
					keptAny = true
				else
					ix.races.missing[#ix.races.missing + 1] = {
						race = class,
						category = "heads." .. gender .. "." .. ethnicity,
						path = path
					}
				end
			end

			if (keptAny) then
				result[gender] = kept
				any = true
			end
		end
	end

	return any and result or nil
end

--------------------------------------------------------------------------------
-- Registration
--------------------------------------------------------------------------------

function ix.races.Register(race)
	if (not istable(race) or not race.class) then
		ErrorNoHalt("[falloutrp] ix.races.Register called without a RACE.class\n")
		return
	end

	race.name = race.name or "Unknown"
	race.description = race.description or "No description available."
	race.baseHealth = race.baseHealth or 100
	race.scale = race.scale or 1
	race.genders = race.genders or {male = true}

	--[[
		Filtered in place. The race keeps the shape it declared; only unavailable
		entries disappear, so a content pack arriving later needs no code change -
		just a restart.
	]]
	race.defaultModels = FilterByGender(race.class, "defaultModels",
		race.defaultModels and {
			male = race.defaultModels.male and {race.defaultModels.male},
			female = race.defaultModels.female and {race.defaultModels.female}
		})

	-- FilterByGender wraps singles in a list; unwrap them back.
	if (istable(race.defaultModels)) then
		for gender, list in pairs(race.defaultModels) do
			race.defaultModels[gender] = list[1]
		end
	end

	race.heads = FilterHeads(race.class, race.heads)
	race.hairs = FilterByGender(race.class, "hairs", race.hairs)
	race.beards = FilterByGender(race.class, "beards", race.beards)

	--[[
		PRECACHED, because the player is going to wear it.

		`FACTION.models` is precached by Helix's faction loader, and every
		faction here declares the human carrier - so the model a super mutant
		actually spawns in is one nothing has told the engine about. An
		unprecached model set on a player is a stall at best and an error model
		at worst, and it happens the first time somebody picks the race rather
		than at load, which is the hardest moment to diagnose it.

		Server only: the client precaches on receiving the entity.
	]]
	if (SERVER and race.animationModel
	and ix.races.ModelExists(race.animationModel)) then
		util.PrecacheModel(race.animationModel)
	end

	ix.races.list[race.class] = race

	return race
end

--[[
	Load every race in a directory.

	Mirrors `ix.attributes.LoadFromDir`: a `RACE` global for the file to fill,
	included, then registered. The filename is not the key - `RACE.class` is,
	because race classes are referenced by name from faction and item data and
	must not change if a file is renamed.
]]
function ix.races.LoadFromDir(directory)
	for _, name in ipairs(file.Find(directory .. "/*.lua", "LUA")) do
		RACE = {}
			ix.util.Include(directory .. "/" .. name)
			ix.races.Register(RACE)
		RACE = nil
	end
end

--------------------------------------------------------------------------------
-- Accessors
--------------------------------------------------------------------------------

function ix.races.Get(class)
	return ix.races.list[class]
end

--- The race of a character, or nil. Every getter below tolerates a nil race,
--- because a character created before races existed has none.
function ix.races.GetCharacterRace(character)
	return character and ix.races.list[character:GetRace()]
end

function ix.races.GetGenders(class)
	local race = ix.races.Get(class)

	return race and race.genders or {}
end

--- Ethnicities available to a gender, e.g. caucasian / african / ghoul.
function ix.races.GetEthnicities(class, gender)
	local race = ix.races.Get(class)

	if (not race or not istable(race.races)) then return {} end

	return race.races[gender] or {}
end

--- The BODY mesh for a gender.
function ix.races.GetBody(class, gender)
	local race = ix.races.Get(class)

	return race and istable(race.defaultModels) and race.defaultModels[gender]
end

--- The HEAD mesh for a gender and ethnicity.
function ix.races.GetHead(class, gender, ethnicity)
	local race = ix.races.Get(class)

	if (not race or not istable(race.heads)) then return end

	local byGender = race.heads[gender]

	return byGender and byGender[ethnicity]
end

--[[
	The body model's SKIN index for an ethnicity.

	Ethnicity is a skin on the shared body mesh, not a separate model - which is
	why five ethnicities need only one body file.
]]
function ix.races.GetSkin(class, gender, ethnicity)
	local race = ix.races.Get(class)

	if (not race or not istable(race.skins)) then return 0 end

	local byGender = race.skins[gender]

	return byGender and byGender[ethnicity] or 0
end

function ix.races.GetHairs(class, gender)
	local race = ix.races.Get(class)

	return race and istable(race.hairs) and race.hairs[gender] or {}
end

function ix.races.GetBeards(class, gender)
	local race = ix.races.Get(class)

	return race and istable(race.beards) and race.beards[gender] or {}
end

--[[
	How far past unity to modulate this race's hair tint, per gender.

	The hair textures are dark and not equally dark between genders, so a tint
	multiplied straight against them lands short of the colour that was picked.
	Declared per race because it describes the ASSETS, not the interface.
]]
function ix.races.GetHairBoost(class, gender)
	local race = ix.races.Get(class)

	if (not race or not istable(race.hairBoost)) then return 1 end

	return race.hairBoost[gender] or 1
end

--- Whether hair colour may be chosen. Ghoul heads have no hair to tint.
function ix.races.CanColorHair(class, gender)
	local race = ix.races.Get(class)

	if (not race or not istable(race.genderCanColorHair)) then return true end

	return race.genderCanColorHair[gender] ~= false
end

function ix.races.GetAnimationModel(class)
	local race = ix.races.Get(class)

	return race and race.animationModel
end

--[[
	Whether the animation model's own mesh should be hidden.

	True for anything composed from parts - which for these models is academic,
	THE ANIMATION MODEL DOES HAVE A MESH. This said it did not, and that was
	wrong: `animations.vvd` is 385 KB of vertex data - a whole human body. It
	is invisible in practice because the meshes bone-merged onto it are the
	same body in the same place, so it is hidden inside them rather than
	absent. The moment anything moves its bones - a dismemberment scaling a
	limb away - it smears out from underneath and draws.

	Phoenix answer this question for every entity they compose a body onto and
	skip `DrawModel` when it is true. `cl_corpse.lua` does the same for a
	corpse. A living player is still drawn underneath their own body, which
	costs a draw call and is invisible; it is only worth changing alongside
	something that moves a living player's bones.
]]
function ix.races.HidesBody(class)
	local race = ix.races.Get(class)

	return race and race.hideBody == true
end

function ix.races.GetBaseHealth(class)
	local race = ix.races.Get(class)

	return race and race.baseHealth or 100
end

function ix.races.GetScale(class)
	local race = ix.races.Get(class)

	return race and race.scale or 1
end

--[[
	The collision hull, as `{normal = Vector, ducked = Vector}`.

	These are HALF-WIDTHS and a full height - `Vector(16, 16, 72)` is a hull 32
	wide and 72 tall - which is the shape Phoenix store and the shape
	`SetHull` wants mirrored into a min/max pair. The default is Half-Life 2's
	standing player, so a race that declares none still gets something the
	engine can move.
]]
local DEFAULT_HULL = {
	normal = Vector(16, 16, 72),
	ducked = Vector(16, 16, 36)
}

local DEFAULT_VIEW = {
	normal = Vector(0, 0, 64),
	ducked = Vector(0, 0, 28)
}

function ix.races.GetHull(class)
	local race = ix.races.Get(class)

	return race and race.hull or DEFAULT_HULL
end

function ix.races.GetViewOffsets(class)
	local race = ix.races.Get(class)

	return race and race.viewOffset or DEFAULT_VIEW
end

function ix.races.GetJumpBoost(class)
	local race = ix.races.Get(class)

	return race and race.jumpBoost
end

function ix.races.TakesRadiation(class)
	local race = ix.races.Get(class)

	return not race or race.hasRadiation ~= false
end

function ix.races.HasHunger(class)
	local race = ix.races.Get(class)

	return not race or race.hasHunger ~= false
end

function ix.races.GetColor(class)
	local race = ix.races.Get(class)

	return race and race.raceColor
end

function ix.races.GetStartingGear(class)
	local race = ix.races.Get(class)

	return race and race.startingGear or {}
end

--[[
	The first available option in each category.

	Character creation needs somewhere to start, and "the first one" has to be
	computed rather than assumed: filtering may have removed what would
	otherwise have been the obvious default.
]]
function ix.races.GetFirstGender(class)
	local genders = ix.races.GetGenders(class)

	-- Deterministic: pairs() over a hash would pick a different default per
	-- session, so male is preferred and the sorted remainder is the fallback.
	if (genders.male) then return "male" end

	local names = {}

	for gender, enabled in pairs(genders) do
		if (enabled) then
			names[#names + 1] = gender
		end
	end

	table.sort(names)

	return names[1]
end

function ix.races.GetFirstEthnicity(class, gender)
	local list = ix.races.GetEthnicities(class, gender)

	return list[1]
end

--- The default race for new characters, and the fallback for old ones.
function ix.races.GetDefault()
	if (ix.races.list.human) then return "human" end

	local names = {}

	for class in pairs(ix.races.list) do
		names[#names + 1] = class
	end

	table.sort(names)

	return names[1]
end

--------------------------------------------------------------------------------
-- Character vars
--------------------------------------------------------------------------------

--[[
	Appearance is stored on the character, not derived from its model, because
	the model IS the animation skeleton - identical for every human - and
	carries none of this.

	EVERY ONE OF THESE NEEDS AN `OnValidate`, AND NOT ONLY FOR SAFETY.

	Helix strips unknown and undisplayed vars out of a creation payload:

	    for k, _ in pairs(payload) do
	        local info = ix.char.vars[k]
	        if (!info or (!info.OnValidate and info.bNoDisplay)) then
	            payload[k] = nil
	        end
	    end
	                          -- core/libs/sh_character.lua, ixCharacterCreate

	These are all `bNoDisplay`, because the customiser sets them rather than
	Helix's generic character-var UI (which would render a raw text box for
	each). So without an `OnValidate` they are DISCARDED at creation, with no
	error - every new character would come out as the default appearance and
	the customiser would look broken for no visible reason.

	The return value also REPLACES the payload entry, so these coerce as well as
	check: an out-of-range index becomes a valid one rather than a rejection the
	player cannot act on.

	Validation order follows registration order, since Helix walks the vars with
	`SortedPairsByMemberValue(ix.char.vars, "index")` and `index` is assigned on
	registration. Race is registered first because everything else is validated
	against it.
]]

--- The race a payload is describing, falling back to the default.
local function PayloadRace(payload)
	local class = payload and payload.race

	if (class and ix.races.list[class]) then return class end

	return ix.races.GetDefault()
end

ix.char.RegisterVar("race", {
	field = "race",
	fieldType = ix.type.string,
	default = "human",
	bNoDisplay = true,

	OnValidate = function(self, value, payload, client)
		if (value and ix.races.list[value]) then return value end

		-- Not a rejection: a character created before races existed, or a
		-- payload from an older client, should get the default rather than a
		-- creation failure it cannot fix.
		return ix.races.GetDefault()
	end
})

ix.char.RegisterVar("gender", {
	field = "gender",
	fieldType = ix.type.string,
	default = "male",
	bNoDisplay = true,

	OnValidate = function(self, value, payload, client)
		local class = PayloadRace(payload)

		if (value and ix.races.GetGenders(class)[value]) then return value end

		return ix.races.GetFirstGender(class) or "male"
	end
})

ix.char.RegisterVar("ethnicity", {
	field = "ethnicity",
	fieldType = ix.type.string,
	default = "caucasian",
	bNoDisplay = true,

	OnValidate = function(self, value, payload, client)
		local class = PayloadRace(payload)
		local gender = payload and payload.gender or ix.races.GetFirstGender(class)

		for _, ethnicity in ipairs(ix.races.GetEthnicities(class, gender)) do
			if (ethnicity == value) then return value end
		end

		return ix.races.GetFirstEthnicity(class, gender) or "caucasian"
	end
})

--[[
	Hair and beard are INDICES into the race's lists for that gender, with 0
	meaning none.

	Clamped rather than rejected, because those lists are filtered for missing
	content at load - so a perfectly reasonable index can point past the end on
	a server whose content differs from the one the player last joined.
]]
local function ValidateIndex(value, count)
	value = tonumber(value) or 0

	if (value < 1 or value > count) then return 0 end

	return math.floor(value)
end

ix.char.RegisterVar("hair", {
	field = "hair",
	fieldType = ix.type.number,
	default = 0,
	bNoDisplay = true,

	OnValidate = function(self, value, payload, client)
		local class = PayloadRace(payload)
		local gender = payload and payload.gender or ix.races.GetFirstGender(class)

		return ValidateIndex(value, #ix.races.GetHairs(class, gender))
	end
})

ix.char.RegisterVar("beard", {
	field = "beard",
	fieldType = ix.type.number,
	default = 0,
	bNoDisplay = true,

	OnValidate = function(self, value, payload, client)
		local class = PayloadRace(payload)
		local gender = payload and payload.gender or ix.races.GetFirstGender(class)

		return ValidateIndex(value, #ix.races.GetBeards(class, gender))
	end
})

--[[
	Stored as a string rather than ix.type.color.

	Helix's colour type exists, but the character field would then need colour
	handling in the database layer for one value. Phoenix stores it as
	"r g b a" and reads it back with `string.ToColor`, which is the same trick
	and needs no schema support.
]]
ix.char.RegisterVar("hairColor", {
	field = "hair_color",
	fieldType = ix.type.string,
	default = "82 56 16 255",
	bNoDisplay = true,

	OnValidate = function(self, value, payload, client)
		-- string.ToColor returns nil on anything malformed, which is the whole
		-- check: a stored value that will not parse renders as no tint at all.
		if (isstring(value) and string.ToColor(value)) then return value end

		return "82 56 16 255"
	end
})

--------------------------------------------------------------------------------
-- Report
--------------------------------------------------------------------------------

--[[
	Races are data, and data that silently failed to load looks exactly like
	data that was never written. This prints what registered and, more usefully,
	what got dropped for missing content.
]]
concommand.Add("fo_races_report", function()
	local accent = Color(255, 199, 44)
	local plain = Color(180, 180, 180)
	local bad = Color(255, 100, 100)

	MsgC(accent, "\n[Fallout] Races\n")

	local classes = {}

	for class in pairs(ix.races.list) do
		classes[#classes + 1] = class
	end

	table.sort(classes)

	if (#classes == 0) then
		MsgC(bad, "  no races registered\n\n")
		return
	end

	for _, class in ipairs(classes) do
		local race = ix.races.list[class]
		local genders = {}

		for gender, enabled in pairs(race.genders or {}) do
			if (enabled) then
				genders[#genders + 1] = gender
			end
		end

		table.sort(genders)

		MsgC(accent, string.format("  %s (%s)\n", race.name, class))
		MsgC(plain, string.format("    %-18s %s\n", "genders", table.concat(genders, ", ")))

		for _, gender in ipairs(genders) do
			local ethnicities = ix.races.GetEthnicities(class, gender)
			local hairs = ix.races.GetHairs(class, gender)
			local beards = ix.races.GetBeards(class, gender)
			local body = ix.races.GetBody(class, gender)

			MsgC(plain, string.format("    %-18s %s\n", gender .. " ethnicities",
				#ethnicities > 0 and table.concat(ethnicities, ", ") or "none"))
			--[[
				A race with `hideBody = false` has no separate body to bone-merge
				on: its animation model IS the body. Liberty Prime is the only one
				that declares it, and calling that "MISSING" reads as a fault
				rather than as the deliberate choice it is.
			]]
			local raceData = ix.races.Get(class)
			local bodyless = raceData and raceData.hideBody == false

			MsgC((body or bodyless) and plain or bad,
				string.format("    %-18s %s\n", gender .. " body",
					body or (bodyless
						and "none - the animation model is the body"
						or "MISSING")))
			MsgC(plain, string.format("    %-18s %d hair, %d beard\n", gender .. " options",
				#hairs, #beards))
		end
	end

	--[[
		The dropped list is the point of this command. Grouped by category
		rather than listed path by path, because 112 missing facemaps as 112
		lines buries everything else.
	]]
	if (#ix.races.missing > 0) then
		local groups = {}
		local order = {}

		for _, entry in ipairs(ix.races.missing) do
			local key = entry.race .. "  " .. entry.category

			if (not groups[key]) then
				groups[key] = {}
				order[#order + 1] = key
			end

			local list = groups[key]
			list[#list + 1] = entry.path
		end

		table.sort(order)

		MsgC(bad, string.format("\n  %d model(s) dropped - content not installed\n",
			#ix.races.missing))

		for _, key in ipairs(order) do
			local list = groups[key]

			MsgC(bad, string.format("    %-34s %d missing\n", key, #list))
			MsgC(plain, string.format("      e.g. %s\n", list[1]))
		end
	else
		MsgC(plain, "\n  all declared models present\n")
	end

	MsgC(accent, "\n")
end)

--[[
	Which chems a race can take.

	Phoenix gate on both, with `getRaceChemWhitelist` and
	`getRaceChemBlacklist`, because a ghoul and a super mutant do not have the
	same chemistry. No race here defines either yet, so both answer nil and the
	aid base's gate is inert - which is the point of having them: the hook
	exists, so adding `chemWhitelist = {...}` to a race is the whole change,
	rather than editing the item base to teach it about races.

	A WHITELIST, where a race has one, is exclusive: anything not named is
	refused. A blacklist only refuses what it names. A race can have either;
	having both would be a way of writing a contradiction.
]]
function ix.races.GetChemWhitelist(character)
	local race = ix.races.Get(character and character:GetRace())

	return race and race.chemWhitelist
end

function ix.races.GetChemBlacklist(character)
	local race = ix.races.Get(character and character:GetRace())

	return race and race.chemBlacklist
end
