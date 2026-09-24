--[[
	Workbenches: chem benches, crafting benches, processing benches.

	Phoenix's `workbench` plugin, rewritten for Helix and split where theirs is
	not. Theirs configures each PLACED BENCH separately - the model, the size,
	the recipes and the timings all live on the entity, and two chem benches are
	two piles of configuration that have to be kept in step by hand.

	A TYPE IS NOT A BENCH. Here the recipes, the model, the size and the gating
	are a TYPE, and a bench standing in the world is a placed record pointing at
	one. Editing the chem bench edits every chem bench, placing a second one is
	one command, and there is exactly one place to look when a recipe is wrong.
	It is the same split as `sh_factionstorage.lua` makes between a record and
	the entity standing on it, for the same reason.

	SIX MODES. The first four are Phoenix's, under names that say what they do;
	the last two are benches whose window is not a recipe list at all - see
	`panel` on them:

	    craft     you pick a recipe and press Craft; it takes time. Their
	              "multicraft". Chem benches, crafting benches.
	    instacraftory  the same, with no storage at all - what it makes goes
	              straight into your pockets.
	    process   nobody presses anything. It looks for a recipe it can fill
	              out of its own inventory and runs it, over and over, while
	              there is anything to run. Their "singlecraft". Smelters,
	              purifiers, anything you load and walk away from.
	    infinite  produces on a timer and consumes nothing. Their
	              "infinitecraft". A water condenser, a generator.

	    tradeup   five weapons of a kind and quality make one of the next.
	              `sh_tradeup.lua`
	    modulate  fits modulators to worn body armour. `sh_modulator.lua`

	For the first four the difference is only WHEN a recipe fires; a recipe is
	the same shape in all of them, so a bench changed from one to another keeps
	its recipes and means something different by them. The last two ignore the
	recipe list entirely and keep it untouched, so a bench switched to one of
	them and back is exactly where it started.
]]

ix.bench = ix.bench or {}

--- `[uniqueID] = definition`. What kinds of bench exist.
ix.bench.types = ix.bench.types or {}

--- `[id] = record`. Benches standing in the world.
ix.bench.list = ix.bench.list or {}

--[[
	The modes, in the order they are offered.

	`automatic` is the one thing the rest of the system asks about, so the
	question "does this bench run on its own" is answered here rather than by a
	string comparison in four places that can disagree.
]]
ix.bench.modes = {
	{
		id = "craft",
		name = "Crafting",
		automatic = false,
		description = "You pick a recipe and press Craft. Takes time."
	},
	{
		--[[
			No inventory at all. What it makes goes straight into the hands of
			whoever pressed the button, which is the right shape for a bench
			that is a workshop rather than a machine - there is nothing to
			collect later, nothing to load, and nothing for anybody else to
			take out of it.
		]]
		id = "instacraftory",
		name = "Instacraftory",
		automatic = false,
		direct = true,
		description = "You pick a recipe and press Craft. It goes straight "
			.. "into your pockets - this bench has no storage at all."
	},
	{
		--[[
			Five weapons of one kind and quality in, one of the next out.

			`panel` is what makes this different from every mode above it: the
			bench window is a RECIPE list, and there are no recipes here - the
			list is whatever you happen to be carrying. `cl_bench.lua` opens
			the panel a mode names instead of the ordinary one.

			`direct`, because what it makes goes straight into your pockets and
			there is nothing to store. See `sh_tradeup.lua`.
		]]
		id = "tradeup",
		name = "Trade Up",
		automatic = false,
		direct = true,
		panel = "ixFOTradeUp",
		description = "Five weapons of the same kind and quality make one of "
			.. "the next quality, straight into your pockets."
	},
	{
		--[[
			One of each modulator, fitted to the body armour you are wearing.

			Also `panel`, and for the same reason: the choice is which
			modulator, not which recipe. See `sh_modulator.lua`.
		]]
		id = "modulate",
		name = "Modulate",
		automatic = false,
		direct = true,
		panel = "ixFOModulate",
		description = "Fits modulators to the body armour you are wearing. "
			.. "One of each kind per suit."
	},
	{
		id = "process",
		name = "Processing",
		automatic = true,
		description = "Runs any recipe it can fill from its own inventory, "
			.. "over and over, unattended."
	},
	{
		id = "infinite",
		name = "Infinite",
		automatic = true,
		description = "Produces on a timer and consumes nothing."
	}
}

function ix.bench.GetMode(id)
	for _, mode in ipairs(ix.bench.modes) do
		if (mode.id == id) then return mode end
	end

	return nil
end

--[[
	The bench models installed on this server, offered in the creator.

	CHECKED AGAINST DISK, not remembered from Phoenix. The first version of
	this defaulted to `craftingstation01.mdl`, which does not exist here - the
	station models are numbered `cookingstation01` through `04` and the rest
	are named, not numbered - and a bench with a missing model is an ERROR
	checkerboard with nothing in the console to say why.

	THE PROP PACK'S THREE BENCHES ARE DELIBERATELY NOT HERE. The two-wastelands
	pack has an anvil, an alien workbench and a grinder, and they sit on disk at
	`addons/<pack>/models/models/fallout/anvil.mdl` - a DOUBLED `models`
	directory, so the path the game would want is `models/models/fallout/...`
	and not the `models/fallout/...` the file tree reads like. Whether that
	holds depends on how the pack is mounted, an unverifiable path is an ERROR
	checkerboard with nothing in the console to explain it, and there are
	sixteen models here that need no guessing. Type one in by hand if you want
	it; the preview is the check.

	Free text is still accepted in the creator; this is the list you get for
	free, not the only thing allowed. Anything typed is previewed before it is
	saved, which is the check that matters.
]]
ix.bench.models = {
	"models/mosi/fallout4/furniture/workstations/workshopbench.mdl",
	"models/mosi/fallout4/furniture/workstations/chemistrystation01.mdl",
	"models/mosi/fallout4/furniture/workstations/chemistrystation02.mdl",
	"models/mosi/fallout4/furniture/workstations/cookingstation01.mdl",
	"models/mosi/fallout4/furniture/workstations/cookingstation02.mdl",
	"models/mosi/fallout4/furniture/workstations/cookingstation03.mdl",
	"models/mosi/fallout4/furniture/workstations/cookingstation04.mdl",
	"models/mosi/fallout4/furniture/workstations/weaponworkbench01.mdl",
	"models/mosi/fallout4/furniture/workstations/weaponworkbench02.mdl",
	"models/mosi/fallout4/furniture/workstations/armorworkbench.mdl",
	"models/mosi/fallout4/furniture/workstations/powerarmorstation01.mdl",
	"models/mosi/fallout4/furniture/workstations/powerarmorstation02.mdl",
	"models/mosi/fallout4/furniture/workstations/robotworkbench.mdl",
	"models/mosi/fallout76/furniture/workstations/tinkerstation.mdl",
	"models/roadkill/fallout/furniture/workbench.mdl",
	"models/roadkill/fallout/furniture/reloadingbench.mdl"
}

--- The model a type falls back to, and the one the creator starts on.
ix.bench.defaultModel = ix.bench.models[1]

--- Bounds. Twenty is Helix's own practical ceiling for an inventory grid.
ix.bench.minSize = 1
ix.bench.maxSize = 20

--- Nothing may take longer than an hour, or be instant.
ix.bench.minTime = 1
ix.bench.maxTime = 3600

--------------------------------------------------------------------------------
-- The shapes
--------------------------------------------------------------------------------

--[[
	A blank type.

	`faction` is `ix.shop.GLOBAL` for the same reason it is that: a faction
	uniqueID is a file name, so `*` is a key no faction can ever collide with.
	A bench nobody is locked out of is the common case, so it is the default.
]]
function ix.bench.NewType(uniqueID)
	return {
		uniqueID = uniqueID,
		name = "Workbench",
		description = "",
		model = ix.bench.defaultModel,
		mode = "craft",
		invW = 6,
		invH = 4,
		faction = ix.shop.GLOBAL,
		rank = 1,
		level = 1,

		--[[
			How many jobs may be waiting, and whether they run together.

			`parallel` is the difference between a bench and a workshop: off,
			the queue is a line and one thing is made at a time; on, everything
			queued counts down at once, so ten stimpaks take as long as one.
			Off is the default because a bench that made ten things in twenty
			seconds is a bench with no cost to using it.
		]]
		queueMax = 10,
		parallel = false,

		--[[
			How many loaded characters have to be on the server for this to
			work at all.

			1 by default, which reads as "somebody has to be playing" - the
			bench is dead only on a genuinely empty server. Raising it is how a
			bench stops being a thing one person farms alone at four in the
			morning: the output is meant to cost the risk of other people being
			around, and a bench that pays the same either way removes that.
		]]
		minPlayers = 1,

		--[[
			Whether it has to be TAKEN before it can be used, and how long
			that takes standing at it.

			A capturable bench belongs to whoever last held it long enough,
			and to nobody at all until somebody does. It is the difference
			between a bench that is furniture and a bench that is a reason to
			go somewhere and a reason to defend it.
		]]
		capturable = false,
		captureTime = 30,

		--[[
			A blueprint bench has no recipe list of its own.

			Every other bench is a fixed menu; this one offers what the person
			standing at it has LEARNED, so two people at the same bench see
			different things. See `sh_blueprint.lua`.
		]]
		blueprint = false,

		--[[
			Whether anything may be put IN.

			On, the bench is a workspace you load - which a processing bench
			has to be, since it draws its materials from its own inventory. Off,
			it is an output bin only, and cannot be used as a locker that
			ignores every rule the faction storages enforce.

			On by default, because the mode that needs it most is the one you
			would otherwise have to remember to switch it on for.
		]]
		allowInput = true,

		recipes = {}
	}
end

--[[
	A blank recipe.

	`input` is a LIST of `{item, amount}` rather than a map of item to amount,
	because the configurer shows it in an order somebody chose and a map has no
	order. Two entries naming the same item are added together by `Needed`, so
	nothing breaks if one is added twice.
]]
function ix.bench.NewRecipe(output)
	local itemTable = output and ix.item.list[output]

	return {
		name = itemTable and itemTable.name or "",
		output = output,
		outputAmount = 1,
		input = {},
		time = 10,
		xp = 0
	}
end

--[[
	Seconds to something readable.

	Written out rather than reached for, because Helix has no formatter:
	`ix.util.GetStringTime` is a PARSER going the other way, and handed 240 it
	answers 14400 because it reads the number as minutes. That mistake has
	shipped here twice - once in a chem description, once in this file - so it
	is worth the eight lines. `07-gotchas.md` has the general form of it.
]]
function ix.bench.FormatTime(seconds)
	seconds = math.max(math.ceil(seconds or 0), 0)

	if (seconds < 60) then return seconds .. "s" end

	if (seconds < 3600) then
		return string.format("%dm %ds", math.floor(seconds / 60), seconds % 60)
	end

	return string.format("%dh %dm", math.floor(seconds / 3600),
		math.floor(seconds % 3600 / 60))
end

--- What a recipe is called: its own name, else the item's, else the id.
function ix.bench.RecipeName(recipe)
	if (not recipe) then return "Nothing" end

	if (recipe.name and recipe.name ~= "") then return recipe.name end

	local itemTable = recipe.output and ix.item.list[recipe.output]

	return itemTable and itemTable.name or recipe.output or "Nothing"
end

--[[
	What one run of a recipe consumes, item by item, added up.

	Returns `{[uniqueID] = amount}`. Two input rows naming the same thing are
	one requirement of the total, which is what stops "3 steel and 2 steel"
	being satisfied by three.
]]
function ix.bench.Needed(recipe)
	local out = {}

	for _, entry in ipairs(recipe and recipe.input or {}) do
		if (not entry.item) then continue end

		out[entry.item] = (out[entry.item] or 0)
			+ math.max(math.floor(entry.amount or 1), 1)
	end

	return out
end

--[[
	What this bench offers THIS person.

	The one accessor, because a blueprint bench's list is per-character and
	every other one is fixed - and everything from the window to the production
	tick has to ask the same question the same way or an index will mean two
	different recipes on the two realms.
]]
function ix.bench.Recipes(definition, client)
	if (not definition) then return {} end

	if (definition.blueprint) then
		return ix.blueprint.RecipesFor(client)
	end

	return definition.recipes or {}
end

--------------------------------------------------------------------------------
-- Sizes
--------------------------------------------------------------------------------

--[[
	The inventory type for a size, registered on demand.

	Helix takes sizes from a registered TYPE rather than from arguments, so a
	6x4 bench needs a `bench:6x4` type to exist. Same trick, and the same
	reason, as `ix.factionStorage.InventoryType`.
]]
function ix.bench.InventoryType(width, height)
	width = math.Clamp(math.floor(width or 6),
		ix.bench.minSize, ix.bench.maxSize)
	height = math.Clamp(math.floor(height or 4),
		ix.bench.minSize, ix.bench.maxSize)

	local invType = string.format("bench:%dx%d", width, height)

	if (not ix.item.inventoryTypes[invType]) then
		ix.inventory.Register(invType, width, height, true)
	end

	return invType, width, height
end

--------------------------------------------------------------------------------
-- Reading
--------------------------------------------------------------------------------

function ix.bench.Get(id)
	return ix.bench.list[id]
end

function ix.bench.GetType(uniqueID)
	return ix.bench.types[uniqueID]
end

--- The type a placed bench is, or nil if the type was deleted under it.
function ix.bench.TypeOf(record)
	return record and ix.bench.types[record.bench]
end

--- Every type, sorted by name, for a menu.
function ix.bench.SortedTypes()
	local out = {}

	for _, definition in pairs(ix.bench.types) do
		out[#out + 1] = definition
	end

	table.sort(out, function(a, b)
		return (a.name or a.uniqueID) < (b.name or b.uniqueID)
	end)

	return out
end

--[[
	How many of a kind of bench are placed on this map.

	Counted from the records on the server and read from a synced table on the
	client, because `ix.bench.list` only exists on the server. The configurer
	asks this to warn what a DELETE is about to take with it, and a warning
	that always said "none are placed" would be worse than no warning at all.
]]
ix.bench.placed = ix.bench.placed or {}

function ix.bench.CountPlaced(uniqueID)
	if (CLIENT) then return ix.bench.placed[uniqueID] or 0 end

	local count = 0

	for _, record in pairs(ix.bench.list) do
		if (record.bench == uniqueID and record.map == game.GetMap()) then
			count = count + 1
		end
	end

	return count
end

--------------------------------------------------------------------------------
-- Who is actually here
--------------------------------------------------------------------------------

--[[
	How many people are on the server with a character loaded.

	LOADED CHARACTERS, NOT CONNECTIONS. Somebody sitting in the character menu,
	still downloading, or at the main menu is connected and is not playing -
	counting them would make an empty server look busy, which is the exact
	thing this number exists to detect.

	BOTS DO NOT COUNT. `sv_devbots.lua` can put dummies on the map, and a
	population gate that could be satisfied by spawning your own company would
	not be a gate. They have no character anyway on most paths; this is belt
	and braces, because the cost of being wrong here is a system that looks
	like it works and does not.

	Shared, because the window has to be able to say why a bench is refusing
	before the server says it again.
]]
function ix.bench.CountLoaded()
	local count = 0

	for _, client in ipairs(player.GetAll()) do
		if (IsValid(client) and not client:IsBot() and client:GetCharacter()) then
			count = count + 1
		end
	end

	return count
end

--- Enough people for this bench? Returns `true`, or `false, reason`.
function ix.bench.HasPopulation(definition)
	local needed = math.max(math.floor(definition and definition.minPlayers
		or 1), 1)
	local here = ix.bench.CountLoaded()

	if (here >= needed) then return true end

	return false, string.format(
		"This needs %d people playing. There %s %d.", needed,
		here == 1 and "is" or "are", here)
end

--------------------------------------------------------------------------------
-- Who holds it
--------------------------------------------------------------------------------

--[[
	Does capturing this take it for your FACTION, or only for you?

	A DEFAULT FACTION HOLDS NOTHING. `isDefault` marks the faction nobody joins
	deliberately - Wastelanders here - and "everyone who has not picked a side"
	is not an organisation that can own a workbench. Taking one as a
	Wastelander would otherwise hand it to every unaffiliated character on the
	server at once, which is the opposite of what capturing it meant.

	So they hold it personally. Everybody else holds it for the people they
	answer to, which is what makes losing one matter to somebody other than the
	person who was standing there.
]]
function ix.bench.CaptureFor(character)
	if (not character) then return nil end

	local faction = ix.faction.indices[character:GetFaction()]

	if (not faction or faction.isDefault) then
		return {character = character:GetID(), name = character:GetName()}
	end

	--[[
		`by` is WHO TOOK IT, kept alongside the faction that owns it.

		The bench belongs to the faction, and that is not changed by this - but
		"who stood here for thirty seconds" is a different question from "whose
		bench is it", and `/benchfactiontoggle` needs the first one: the person
		who took it is the one allowed to shut their own faction out of it
		again. See `ix.bench.Owns`.
	]]
	return {faction = faction.uniqueID, name = faction.name,
		by = character:GetID()}
end

--- Does this character hold this bench?
function ix.bench.Owns(client, record)
	local owner = record and record.owner
	local character = client and client:GetCharacter()

	if (not owner or not character) then return false end

	--[[
		A LOCKED BENCH IS THE CAPTURER'S ALONE, faction or not.

		`/benchfactiontoggle` sets this, and it exists for one situation: an
		officer takes a workshop for their faction and does not want every
		enlisted trooper emptying it while they are stood there. It is
		deliberately a toggle rather than a rank rule, because who is trusted
		is not something a rank number knows.
	]]
	if (record.lockedBy) then
		return character:GetID() == record.lockedBy
	end

	if (owner.character) then
		return character:GetID() == owner.character
	end

	if (owner.faction) then
		local faction = ix.faction.indices[character:GetFaction()]

		return faction ~= nil and faction.uniqueID == owner.faction
	end

	return false
end

--[[
	Who took this bench, as a character id - the person `/benchfactiontoggle`
	answers to. Nil for an uncaptured one, and for one held by a single
	wastelander, whose own id is already `owner.character`.
]]
function ix.bench.CapturedBy(record)
	local owner = record and record.owner

	if (not owner) then return nil end

	return owner.by or owner.character
end

--- Who holds it, for a message. "Nobody" when it is free.
function ix.bench.OwnerName(record)
	local owner = record and record.owner

	if (not owner) then return "Nobody" end

	--[[
		The name is stored ON the owner rather than looked up. A faction can be
		renamed and a character can be deleted, and a bench whose holder cannot
		be named reads as broken - where a slightly stale name reads as the
		name of whoever took it.
	]]
	if (owner.faction) then
		local faction = ix.faction.teams[owner.faction]

		return faction and faction.name or owner.name or "another faction"
	end

	return owner.name or "someone"
end

--------------------------------------------------------------------------------
-- The rules
--------------------------------------------------------------------------------

--[[
	Is this definition usable? Returns `true`, or `false, reason`.

	Run on the server before anything is saved AND in the configurer before the
	Save button does anything, so the window can say what is wrong instead of
	the server silently refusing.
]]
function ix.bench.Validate(definition)
	if (not definition) then return false, "Nothing to save." end

	if (not definition.uniqueID or definition.uniqueID == "") then
		return false, "The bench needs an id."
	end

	if (not definition.name or definition.name == "") then
		return false, "The bench needs a name."
	end

	if (not definition.model or definition.model == "") then
		return false, "The bench needs a model."
	end

	if (not ix.bench.GetMode(definition.mode)) then
		return false, "That is not a mode."
	end

	local width = definition.invW or 0
	local height = definition.invH or 0

	if (width < ix.bench.minSize or width > ix.bench.maxSize
	or height < ix.bench.minSize or height > ix.bench.maxSize) then
		return false, string.format("The inventory has to be between %d and "
			.. "%d in each direction.", ix.bench.minSize, ix.bench.maxSize)
	end

	if ((definition.queueMax or 10) < 1
	or (definition.queueMax or 10) > 50) then
		return false, "The queue has to be between 1 and 50."
	end

	if ((definition.minPlayers or 1) < 1
	or (definition.minPlayers or 1) > 64) then
		return false, "The player minimum has to be between 1 and 64."
	end

	if ((definition.captureTime or 30) < 5
	or (definition.captureTime or 30) > 600) then
		return false, "The capture time has to be between 5 and 600 seconds."
	end

	--[[
		A blueprint bench is exempt from needing recipes, because its list is
		not its own - and it has to be a CRAFT bench, since the other two modes
		run with nobody standing there and "what this person knows" has no
		answer then.
	]]
	if (definition.blueprint) then
		if (definition.mode ~= "craft"
		and definition.mode ~= "instacraftory") then
			return false, "A blueprint bench has to be a Crafting or "
				.. "Instacraftory bench - the automatic modes run with nobody "
				.. "standing at them."
		end

		return true
	end

	--[[
		A bench with its own window has no recipes to check.

		Trade-up and modulate benches decide what they offer from what the
		person standing at them is carrying, so the recipe list is empty on
		purpose - and "add a recipe" would be advice nobody could act on.

		Any recipes left on one from an earlier mode are checked below anyway
		when it is switched back, so nothing is lost by skipping them here.
	]]
	local mode = ix.bench.GetMode(definition.mode)

	if (mode and mode.panel) then return true end

	if (not definition.recipes or #definition.recipes < 1) then
		return false, "A bench with no recipes does nothing. Add one."
	end

	for index, recipe in ipairs(definition.recipes) do
		if (not recipe.output or not ix.item.list[recipe.output]) then
			return false, string.format("Recipe %d makes nothing.", index)
		end

		for _, entry in ipairs(recipe.input or {}) do
			if (not ix.item.list[entry.item]) then
				return false, string.format(
					"Recipe %d wants '%s', which is not an item.",
					index, tostring(entry.item))
			end
		end

		--[[
			An infinite bench consuming something is a contradiction rather
			than a mistake to correct quietly - the inputs are never read in
			that mode, and a recipe listing them would lie to whoever opened it
			next.
		]]
		if (definition.mode == "infinite" and #(recipe.input or {}) > 0) then
			return false, string.format("Recipe %d has inputs, and an "
				.. "infinite bench consumes nothing. Clear them, or change "
				.. "the mode.", index)
		end
	end

	return true
end

--[[
	May this player use this bench at all? Returns `true`, or `false, reason`.

	Faction, rank and level, which is the set the shop asks - somebody who may
	not buy the faction's weapons should not be able to build them either.
	Nothing here is about where they are standing: `Use` already means they are
	within arm's reach of it.
]]
function ix.bench.CanUse(client, record)
	local character = client and client:GetCharacter()

	if (not character) then return false, "No character." end

	local definition = ix.bench.TypeOf(record)

	if (not definition) then
		return false, "This bench is not registered. Tell an admin."
	end

	--[[
		Admins are let past all three, because they are the ones who have to
		stand at a bench nobody has built yet and find out whether it works.
	]]
	if (IsValid(client) and client:IsAdmin()) then return true end

	--[[
		Asked before the faction and the rank, because it is the only one of
		the three that is not about WHO you are - being told the server is too
		quiet is a more useful answer than being told your rank is too low when
		both are true.
	]]
	local enough, why = ix.bench.HasPopulation(definition)

	if (not enough) then return false, why end

	--[[
		A capturable bench answers to whoever holds it, and nothing else about
		this character matters until they do. Checked before faction and rank
		because holding it is what those are FOR here - a bench your faction
		took is one your faction's ranks then apply to.
	]]
	if (definition.capturable) then
		if (not record.owner) then
			return false, "Nobody holds this. Press E to take it."
		end

		if (not ix.bench.Owns(client, record)) then
			--[[
				A locked bench says so rather than naming the faction: being
				told "the NCR hold this" while wearing an NCR uniform is the
				most confusing possible answer, and the truth is that one
				person has shut the rest of them out.
			]]
			if (record.lockedBy) then
				return false, string.format("%s took this and has closed it "
					.. "to everyone else.", ix.bench.OwnerName(record))
			end

			return false, string.format("%s holds this.",
				ix.bench.OwnerName(record))
		end
	end

	if (definition.faction and definition.faction ~= ix.shop.GLOBAL) then
		local faction = ix.faction.indices[character:GetFaction()]

		if (not faction or faction.uniqueID ~= definition.faction) then
			local owner = ix.faction.teams[definition.faction]

			return false, string.format("Only %s use this.",
				owner and owner.name or "another faction")
		end

		local info = ix.class.list[character:GetClass()]
		local rank = info and (info.rank or 1) or 0

		if (rank < (definition.rank or 1)) then
			return false, string.format("You have to be %s or above.",
				ix.class.GetRankName(definition.faction, definition.rank or 1))
		end
	end

	if ((definition.level or 1) > 1
	and character:GetLevel() < definition.level) then
		return false, string.format("You have to be level %d to use this.",
			definition.level)
	end

	return true
end

--------------------------------------------------------------------------------
-- Materials
--------------------------------------------------------------------------------

--[[
	How many of something is within reach of a person standing at a bench.

	THE BENCH FIRST, THEN THEIR OWN POCKETS, and the two added together.

	A bench that could only see its own inventory would make every craft a
	drag-items-in chore, and one that could only see your pockets would make a
	loaded processing bench impossible. Reaching into somebody's inventory is
	worth being careful about, and this is the case where it is not surprising:
	they pressed Craft on a recipe with its inputs listed in front of them.

	`ix.stack.Count` rather than `GetItemCount`, so five steel in one stack
	counts as five - see `sh_stack.lua`.
]]
function ix.bench.Have(client, inventory, uniqueID)
	local character = client and client:GetCharacter()
	local own = character and character:GetInventory()

	return ix.stack.Count(inventory, uniqueID)
		+ (own ~= inventory and ix.stack.Count(own, uniqueID) or 0)
end

--[[
	A bench's own inventory, from its record.

	Takes an INVENTORY rather than a record above, and this is why: the record
	only exists on the server. The window has an entity and a networked
	inventory id, and asking the same question there has to work without one.
]]
function ix.bench.GetInventory(record)
	return record and record.invID and ix.inventory.Get(record.invID)
end

--[[
	Can this recipe be run right now? Returns `true`, or `false, reason`.

	Asked by the UI to grey the button out and by the server before anything is
	consumed, so the two cannot disagree about why.
]]
function ix.bench.CanCraft(client, record, recipe)
	--[[
		A NIL CLIENT IS THE BENCH RUNNING ITSELF.

		A processing bench starts its own jobs on a tick with nobody standing
		at it, and there is no faction, rank or level to check that against -
		asking anyway is how the first version of this refused every automatic
		bench for ever with "No character." The bench is already standing where
		an admin put it, which is where the permission was spent.
	]]
	if (client) then
		local ok, reason = ix.bench.CanUse(client, record)

		if (not ok) then return false, reason end
	end

	if (not recipe or not recipe.output
	or not ix.item.list[recipe.output]) then
		return false, "That recipe makes nothing."
	end

	--[[
		THE QUEUE IS THE LIMIT, NOT "IS IT BUSY".

		This used to refuse anything while a job was running, which is what
		made a bench a thing you had to stand at and re-press. A queue is the
		same bench with the waiting done once - and it is bounded, because an
		unbounded one is a way to spend every material you own in a single
		click and then have to watch it.
	]]
	local definition = ix.bench.TypeOf(record)

	--[[
		Checked here as well as by `CanUse`, because `CanUse` is SKIPPED for a
		bench running itself - so a type deleted out from under a placed bench
		would reach the line below and index a nil.
	]]
	if (not definition) then
		return false, "This bench is not registered."
	end

	local queued = #(record.jobs or {})

	if (queued >= math.max(definition.queueMax or 10, 1)) then
		return false, string.format("The queue is full (%d).", queued)
	end

	--- An infinite bench needs nothing, and asking would always refuse.
	if (definition.mode ~= "infinite") then
		local inventory = ix.bench.GetInventory(record)

		for uniqueID, amount in pairs(ix.bench.Needed(recipe)) do
			if (ix.bench.Have(client, inventory, uniqueID) < amount) then
				local itemTable = ix.item.list[uniqueID]

				return false, string.format("You need %d %s.", amount,
					itemTable and itemTable.name or uniqueID)
			end
		end
	end

	return true
end
