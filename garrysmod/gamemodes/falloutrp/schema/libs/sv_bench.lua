--[[
	Workbenches: persistence, placing, and the production loop.

	See `sh_bench.lua` for what a type is, what a placed record is, and why
	those are two things rather than one.

	TWO SAVES, NOT ONE. The types are configuration and the placed benches are
	world state, and they change for completely different reasons - an admin
	editing the chem bench recipe should not rewrite where every bench in the
	world is standing, and a bench being put down should not rewrite the
	recipes. They are also read at different times: types have to exist before
	a placed record can be restored against one.
]]

if (not SERVER) then return end

util.AddNetworkString("ixBenchSync")
util.AddNetworkString("ixBenchConfig")
util.AddNetworkString("ixBenchConfigSet")
util.AddNetworkString("ixBenchConfigDelete")
util.AddNetworkString("ixBenchPanel")
util.AddNetworkString("ixBenchCraft")
util.AddNetworkString("ixBenchCancel")
util.AddNetworkString("ixBenchToggle")
util.AddNetworkString("ixBenchPlace")
util.AddNetworkString("ixBenchBeginPlacing")
util.AddNetworkString("ixBenchCounts")
util.AddNetworkString("ixBenchStorage")

local TYPE_KEY = "benchtypes"
local PLACED_KEY = "benches"

--[[
	Guarded like the loot library's and the faction storages'.

	`sv_loot.lua` has the long version: saving before the load has happened
	writes an empty table over everything, and a persistence bug that DELETES
	is worse than one that fails to write.
]]
local loaded = false

--------------------------------------------------------------------------------
-- Saving
--------------------------------------------------------------------------------

function ix.bench.SaveTypes()
	if (not loaded) then return end

	ix.data.Set(TYPE_KEY, ix.bench.types, false, true)
end

--[[
	Placed benches are saved on a DEBOUNCE, not on every change.

	`ix.data.Set` is a synchronous `file.Write` with a JSON encode inside it -
	every call, no batching of its own. A processing bench finishing a job every
	thirty seconds would write the whole table to disk that often, and six
	smelters would make it every few seconds, for state nobody would miss if the
	server died between two of them.

	So `Save` only says the table has changed, and `Flush` is what writes. World
	changes that would be confusing to lose - a bench placed, a bench removed -
	call `Flush` themselves; a job ticking over does not.
]]
local dirty = false

function ix.bench.Save()
	dirty = true
end

function ix.bench.Flush()
	if (not dirty) then return end

	--[[
		The flag is cleared AFTER the guard, not before. Clearing it first
		would mean a flush that refused to write had also forgotten there was
		anything to write, and the change would never be saved by any later
		one.
	]]
	if (not loaded) then
		ErrorNoHalt("[falloutrp] refusing to save benches before they have "
			.. "been loaded\n")

		return
	end

	dirty = false

	local out = {}

	for id, record in pairs(ix.bench.list) do
		local jobs = {}

		for _, job in ipairs(record.jobs or {}) do
			jobs[#jobs + 1] = {recipe = job.recipe, length = job.length,
				finish = job.finish, character = job.character,
				output = job.output, amount = job.amount, xp = job.xp,
				name = job.name}
		end

		--[[
			The entity is not saved, its POSITION is, and a job is saved as the
			WALL-CLOCK time it finishes rather than as seconds remaining.

			`os.time`, not `CurTime`, for exactly the reason the shop's restock
			timer uses it: `CurTime` restarts at zero with the map, so a craft
			with two minutes left would come back with two minutes left no
			matter how long the server was down. A processing bench left
			running overnight should have finished overnight.
		]]
		out[id] = {
			id = record.id,
			bench = record.bench,
			invID = record.invID,
			invW = record.invW,
			invH = record.invH,
			map = record.map,
			pos = record.pos,
			ang = record.ang,
			active = record.active,
			recipe = record.recipe,

			--[[
				WHO HOLDS IT IS SAVED, and then thrown away on the next load -
				see `ix.bench.Load`, which starts every capturable bench
				unheld. It stays in the file because it costs nothing and it is
				the only record of who had it when the server went down, which
				is worth having when somebody asks.
			]]
			owner = record.owner,

			--[[
				And whether the person who took it has shut their own faction
				out - see `/benchfactiontoggle`. Saved next to the owner and
				thrown away with it on the next load.
			]]
			lockedBy = record.lockedBy,

			--[[
				The whole queue, each job as its recipe and the wall-clock time
				it finishes. A job that has not started has no `finish` and is
				written without one, which is exactly how it comes back.
			]]
			jobs = jobs
		}
	end

	ix.data.Set(PLACED_KEY, out, false, true)
end

--------------------------------------------------------------------------------
-- Loading
--------------------------------------------------------------------------------

local function RestoreRecord(record)
	local invType, width, height =
		ix.bench.InventoryType(record.invW, record.invH)

	record.invW, record.invH = width, height

	local function Ready()
		if (record.map == game.GetMap() and record.pos) then
			ix.bench.Spawn(record)
		end
	end

	if (not record.invID or record.invID < 1) then
		--[[
			A record written before its inventory finished being made. Given a
			new empty one rather than dropped: an admin's bench with nothing in
			it is a smaller loss than an admin's bench gone.
		]]
		ix.inventory.New(0, invType, function(inventory)
			record.invID = inventory:GetID()

			inventory.vars.isBag = true
			inventory.vars.isContainer = true
			inventory.vars.bench = record.id

			ix.bench.Save()
			Ready()
		end)

		return
	end

	ix.inventory.Restore(record.invID, width, height, function(restored)
		if (restored) then
			restored.vars.isBag = true
			restored.vars.isContainer = true
			restored.vars.bench = record.id
		end

		Ready()
	end)
end

function ix.bench.Load()
	if (loaded) then return end

	--[[
		TYPES FIRST. A placed record names its type by uniqueID and is dropped
		when that type is gone, so reading them the other way round would drop
		every bench in the world on every restart.
	]]
	local types = ix.data.Get(TYPE_KEY, nil, false, true)

	ix.bench.types = {}

	if (istable(types)) then
		for uniqueID, definition in pairs(types) do
			if (isstring(uniqueID) and istable(definition)) then
				definition.uniqueID = uniqueID
				definition.recipes = definition.recipes or {}

				ix.bench.types[uniqueID] = definition
			end
		end
	end

	--[[
		NIL, NOT EMPTY. A server that has never been configured gets the four
		starter benches; one whose admin has deleted them all gets nothing,
		because those are different states and `ix.data.Get` tells them apart.
		See `sv_benchseed.lua`, which explains why that distinction is the
		whole design of the seeder.

		`loaded` is set before the seed so `SaveTypes` inside it is allowed to
		write - it would refuse otherwise, and the seed would be made again on
		every boot for ever.
	]]
	if (types == nil and ix.bench.Seed) then
		loaded = true

		ix.bench.Seed()
		ix.bench.SaveTypes()
	end

	local stored = ix.data.Get(PLACED_KEY, {}, false, true) or {}

	ix.bench.list = {}
	loaded = true

	local kept, dropped = 0, 0

	for _, record in pairs(stored) do
		if (not record.id or not ix.bench.types[record.bench]) then
			dropped = dropped + 1

			continue
		end

		--[[
			Records written before benches had a queue carry a single `job`.
			Migrated rather than dropped, because dropping it would silently
			eat whatever materials were spent on a craft that was running when
			the server went down.
		]]
		if (record.job and not record.jobs) then
			record.jobs = {record.job}
			record.job = nil
		end

		record.jobs = record.jobs or {}

		--[[
			EVERY CAPTURABLE BENCH STARTS THE SESSION UNHELD.

			The same rule the capture points follow, for the same reason - see
			`ix.points.Load`. A bench is held by whoever last stood at it long
			enough to take it, and carrying that across a restart means a
			faction that logged off at three in the morning still owns the
			workshop at noon. It is meant to be taken and re-taken, so it
			starts unclaimed daily.

			Anything not capturable has no owner to clear, so this needs no
			test against the type.
		]]
		record.owner = nil
		record.capture = nil
		record.lockedBy = nil

		ix.bench.list[record.id] = record
		kept = kept + 1

		RestoreRecord(record)
	end

	MsgC(Color(255, 200, 100), string.format(
		"[falloutrp] %d bench type(s), %d placed%s\n",
		table.Count(ix.bench.types), kept,
		dropped > 0 and string.format(", dropped %d whose type is gone",
			dropped) or ""))
end

hook.Add("LoadData", "ixBench", ix.bench.Load)
hook.Add("PostLoadData", "ixBench", ix.bench.Load)
timer.Simple(10, ix.bench.Load)

--[[
	FLUSHED here rather than marked. `SaveData` and `ShutDown` are the two
	moments where the next scheduled write might never happen, so the debounce
	has to be skipped past.
]]
hook.Add("SaveData", "ixBench", function()
	if (not loaded) then return end

	ix.bench.Save()
	ix.bench.Flush()
	ix.bench.SaveTypes()
end)

hook.Add("ShutDown", "ixBench", function()
	if (not loaded) then return end

	ix.bench.Save()
	ix.bench.Flush()
end)

--------------------------------------------------------------------------------
-- Types
--------------------------------------------------------------------------------

--[[
	Write a type, new or edited. Returns `true`, or `false, reason`.

	THE SIZE ONLY APPLIES TO BENCHES PLACED AFTER IT. A placed record carries
	the size it was made at, and shrinking a type would otherwise leave items
	sitting in slots that no longer exist - Helix has no concept of an item
	being outside its inventory, so those items would be unreachable rather
	than dropped, which is the worst of the three possible answers.
]]
function ix.bench.SetType(definition)
	local ok, reason = ix.bench.Validate(definition)

	if (not ok) then return false, reason end

	ix.bench.types[definition.uniqueID] = definition

	ix.bench.SaveTypes()
	ix.bench.SendAll()

	--- Placed benches of this type change model with it, so the world matches.
	for _, record in pairs(ix.bench.list) do
		if (record.bench == definition.uniqueID and IsValid(record.entity)
		and record.entity:GetModel() ~= definition.model) then
			record.entity:SetModel(definition.model)
			record.entity:PhysicsInit(SOLID_VPHYSICS)
		end
	end

	return true
end

--[[
	Delete a type, and every bench of it.

	The benches go WITH it rather than being left orphaned: a placed record
	whose type is gone is refused by `CanUse` and dropped by the next load, so
	leaving them standing would only mean a prop nobody can open until the map
	changes.
]]
function ix.bench.DeleteType(uniqueID)
	if (not ix.bench.types[uniqueID]) then return false, "No such bench." end

	local removed = 0

	for id, record in pairs(ix.bench.list) do
		if (record.bench == uniqueID) then
			ix.bench.Destroy(record)
			removed = removed + 1

			ix.bench.list[id] = nil
		end
	end

	ix.bench.types[uniqueID] = nil

	ix.bench.SaveTypes()
	ix.bench.Save()
	ix.bench.SendAll()

	return true, removed
end

--------------------------------------------------------------------------------
-- Placing
--------------------------------------------------------------------------------

--- The next free id. Never reused, so a stale reference stays stale.
local function NextID()
	local highest = 0

	for id in pairs(ix.bench.list) do
		highest = math.max(highest, id)
	end

	return highest + 1
end

--- Put the entity into the world for a record.
function ix.bench.Spawn(record)
	if (IsValid(record.entity)) then return record.entity end

	local definition = ix.bench.TypeOf(record)

	if (not definition) then return end

	local entity = ents.Create("ix_workbench")

	if (not IsValid(entity)) then return end

	entity:SetModel(definition.model)
	entity:SetPos(record.pos)
	entity:SetAngles(record.ang or angle_zero)
	entity:Spawn()

	--[[
		AFTER `Spawn`, not before. `SetupDataTables` runs as part of spawning,
		so a NetworkVar written before it is written into a table that does not
		exist yet and is silently lost - which is what made the first faction
		storage answer "this storage is still loading" for ever. See
		`07-gotchas.md`.
	]]
	entity:SetBenchID(record.id)

	record.entity = entity

	ix.bench.Refresh(record)

	return entity
end

--[[
	Place a new bench of a type. Returns the record, or `false, reason`.

	Admin-driven, like the faction storages: benches are world furniture rather
	than something a player carries around, so there is no item and no
	deployable - an admin puts one somewhere and it stays there.
]]
function ix.bench.Place(uniqueID, position, angles, callback)
	local definition = ix.bench.GetType(uniqueID)

	if (not definition) then return false, "No such bench." end

	local ok, reason = ix.bench.Validate(definition)

	if (not ok) then return false, reason end

	local invType, width, height =
		ix.bench.InventoryType(definition.invW, definition.invH)
	local id = NextID()

	local record = {
		id = id,
		bench = uniqueID,
		invW = width,
		invH = height,
		map = game.GetMap(),
		pos = position,
		ang = angles or angle_zero,
		active = true
	}

	ix.bench.list[id] = record

	ix.inventory.New(0, invType, function(inventory)
		record.invID = inventory:GetID()

		inventory.vars.isBag = true
		inventory.vars.isContainer = true
		inventory.vars.bench = id

		ix.bench.Spawn(record)
		ix.bench.Save()
		ix.bench.Flush()
		ix.bench.SendAll()

		if (callback) then callback(record) end
	end)

	return record
end

--[[
	Remove a bench and everything in it.

	Unlike a faction storage there is no stowing: a bench belongs to the map
	rather than to anybody, so the only two states are standing and gone. The
	inventory goes with it, which is why the command asks first.
]]
function ix.bench.Destroy(record)
	if (not record) then return end

	if (ix.bench.StopCapture) then
		ix.bench.StopCapture(record, "The workbench is gone.")
	end

	record.jobs = nil

	local inventory = ix.inventory.Get(record.invID)

	if (inventory) then
		if (ix.storage.InUse(inventory)) then
			ix.storage.Close(inventory)
		end

		--[[
			The items are destroyed with it rather than spilled on the floor.
			A 20x20 bench emptying itself onto the ground is a hundred props
			and a frozen server, and an admin removing a bench has been told
			what it costs.

			The inventory ROW is left behind: Helix has no
			`ix.inventory.Delete`, and an empty orphaned row costs nothing and
			is never looked up again. Same answer, and the same reason, as
			`ix.factionStorage.Destroy`.
		]]
		for item in ix.inventory.Each(inventory) do
			item:Remove()
		end

		ix.item.inventories[record.invID] = nil
	end

	if (IsValid(record.entity)) then
		record.entity:Remove()
	end

	ix.bench.list[record.id] = nil

	ix.bench.Save()
	ix.bench.Flush()
	ix.bench.SendAll()
end

--------------------------------------------------------------------------------
-- Materials
--------------------------------------------------------------------------------

--[[
	Take one run of a recipe out of the bench, then out of the crafter.

	COUNTED BEFORE ANYTHING IS TAKEN. Half-consuming a recipe and then failing
	is the one outcome that is worse than refusing, so this asks `CanCraft`'s
	question again over the whole list before it removes the first item.

	The bench is emptied before the crafter's pockets, which is the order
	somebody loading a bench would expect: what you put in is what gets used.
]]
function ix.bench.Consume(client, record, recipe)
	local needed = ix.bench.Needed(recipe)
	local benchInventory = ix.inventory.Get(record.invID)
	local character = client and client:GetCharacter()
	local own = character and character:GetInventory()

	if (own == benchInventory) then own = nil end

	for uniqueID, amount in pairs(needed) do
		if (ix.stack.Count(benchInventory, uniqueID)
		+ ix.stack.Count(own, uniqueID) < amount) then
			return false
		end
	end

	for uniqueID, amount in pairs(needed) do
		local fromBench = math.min(
			ix.stack.Count(benchInventory, uniqueID), amount)

		if (fromBench > 0) then
			ix.stack.Take(benchInventory, uniqueID, fromBench)
		end

		if (amount - fromBench > 0) then
			ix.stack.Take(own, uniqueID, amount - fromBench)
		end
	end

	return true
end

--[[
	Is there anywhere in the bench for this output to go?

	AN UNATTENDED BENCH MUST JAM, NOT SPILL. `Produce` falls back to the floor
	when nothing else will take the output, which is right for somebody
	standing there pressing Craft and catastrophic for an infinite bench left
	running overnight - it would put an item on the ground every few seconds
	for as long as the server was up, and nobody would be there to notice until
	the map was full of props.

	So automatic benches ask this FIRST and simply do not start a job there is
	no room for. Nothing is consumed, nothing is produced, and the bench
	carries on trying every tick - which is what a real machine with a full
	output bin does. A part-stack with room counts, because that is where
	`ix.stack.Give` would put it.
]]
function ix.bench.HasRoom(record, uniqueID, amount)
	local definition = ix.bench.TypeOf(record)
	local mode = definition and ix.bench.GetMode(definition.mode)

	--- Nothing to fill up, so nothing to jam. See `ix.bench.Produce`.
	if (mode and mode.direct) then return true end

	local inventory = ix.bench.GetInventory(record)

	if (not inventory) then return false end

	local itemTable = ix.item.list[uniqueID]

	if (not itemTable) then return false end

	if (itemTable.isStackable) then
		local maximum = math.max(
			math.floor(itemTable.maxQuantity or ix.stack.max), 1)
		local room = 0

		for item in ix.inventory.Each(inventory) do
			if (item.uniqueID == uniqueID) then
				room = room + maximum - ix.stack.Get(item)
			end
		end

		if (room >= amount) then return true end
	end

	return inventory:FindEmptySlot(itemTable.width or 1,
		itemTable.height or 1) and true or false
end

--[[
	Put the output somewhere. Bench, then crafter, then the floor.

	The floor is the last resort rather than a failure, because the alternative
	is a finished craft that produced nothing - and a processing bench filling
	up while nobody is watching is exactly the case where there is no one to
	tell.
]]
function ix.bench.Produce(client, record, uniqueID, amount, data)
	--[[
		AN INSTACRAFTORY HAS NO BIN. Its output goes to the person who asked
		for it and nowhere else, so the bench inventory is skipped rather than
		filled and then emptied - which is what makes it a workshop you use
		rather than a machine you come back to.
	]]
	local definition = ix.bench.TypeOf(record)
	local mode = definition and ix.bench.GetMode(definition.mode)
	local direct = mode and mode.direct

	local benchInventory = not direct and ix.inventory.Get(record.invID) or nil
	local given = ix.stack.Give(benchInventory, uniqueID, amount, data)

	if (given < amount) then
		local character = client and client:GetCharacter()
		local own = character and character:GetInventory()

		if (own and own ~= benchInventory) then
			given = given + ix.stack.Give(own, uniqueID, amount - given, data)
		end
	end

	if (given < amount and IsValid(record.entity)) then
		local position = record.entity:GetPos()
			+ record.entity:GetUp() * 20

		for _ = 1, amount - given do
			ix.item.Spawn(uniqueID, position + VectorRand() * 8, nil, nil,
				data)
		end
	end

	return amount
end

--------------------------------------------------------------------------------
-- Running
--------------------------------------------------------------------------------

--- Push a record's state onto its entity, where the client reads it.
function ix.bench.Refresh(record)
	local entity = record.entity

	if (not IsValid(entity)) then return end

	local definition = ix.bench.TypeOf(record)

	entity:SetBenchType(record.bench)
	entity:SetBenchName(definition and definition.name or "Workbench")
	entity:SetRunning(record.active ~= false)

	--[[
		Blank when nobody holds it, which is what the tooltip reads as
		"unclaimed". A networked string rather than the whole owner table: the
		client only ever needs to say WHO, and sending an id it would have to
		resolve is a lookup that can fail for a character who is not here.
	]]
	entity:SetOwnerName(record.owner and ix.bench.OwnerName(record) or "")

	local jobs = record.jobs or {}

	entity:SetQueued(#jobs)

	--[[
		THE FIRST JOB IS THE ONE THE BAR DRAWS, in both modes.

		Running in parallel, every job has its own finish and the first is
		simply the one that started first - a single bar cannot show ten at
		once, and the queue count beside it is what says there are ten. Running
		in a line, the first job is the only one with a finish at all.
	]]
	local job = jobs[1]

	entity:SetJobName(job and job.name or "")

	if (job and job.finish) then
		local remaining = math.max(job.finish - os.time(), 0)

		entity:SetRecipeIndex(job.recipe or 0)
		entity:SetJobLength(job.length or 1)
		entity:SetJobFinish(CurTime() + remaining)
	else
		entity:SetRecipeIndex(0)
		entity:SetJobLength(0)
		entity:SetJobFinish(0)
	end
end

--[[
	Start a job. Returns `true`, or `false, reason`.

	`length` is stored as well as `finish` because the progress bar needs to
	know how far through it is, and after a restart the difference between the
	two is all that is left of how long it was ever meant to take.
]]
function ix.bench.Queue(client, record, index)
	local definition = ix.bench.TypeOf(record)

	if (not definition) then return false, "This bench is not registered." end

	local recipe = ix.bench.Recipes(definition, client)[index]

	if (not recipe) then return false, "No such recipe." end

	local ok, reason = ix.bench.CanCraft(client, record, recipe)

	if (not ok) then return false, reason end

	--[[
		MATERIALS ARE SPENT WHEN THE JOB IS QUEUED, not when it starts.

		Charging at the front is what makes a queue honest: you can only line
		up what you can actually afford, and the fifth stimpak in the queue
		cannot quietly fail forty seconds from now because somebody took the
		steel out of your pocket in the meantime.
	]]
	if (definition.mode ~= "infinite"
	and not ix.bench.Consume(client, record, recipe)) then
		return false, "You do not have the materials."
	end

	record.jobs = record.jobs or {}

	local length = math.Clamp(math.floor(recipe.time or 10),
		ix.bench.minTime, ix.bench.maxTime)

	--[[
		THE JOB CARRIES ITS OWN OUTPUT, not just an index into a list.

		On a blueprint bench the list belongs to the CHARACTER, so an index is
		only meaningful next to the person who sent it - they can learn another
		blueprint, log off, or be replaced at the bench by somebody who knows a
		different set, and the same index would then finish as a different
		weapon. Snapshotting what was actually queued makes the job independent
		of the list it came from, which is also what lets one survive a
		restart.
	]]
	local job = {
		recipe = index,
		output = recipe.output,
		amount = math.max(math.floor(recipe.outputAmount or 1), 1),
		xp = math.max(math.floor(recipe.xp or 0), 0),
		name = ix.bench.RecipeName(recipe),
		length = length,
		--[[
			The CHARACTER id, not the player. A job outlives the person who
			started it - they can disconnect, die, or change character while a
			smelter runs - and an entity reference would be a handle to
			somebody who is no longer there.
		]]
		character = client and client:GetCharacter()
			and client:GetCharacter():GetID() or nil
	}

	--[[
		A job with no `finish` is one that has not started. In a line, only the
		front of the queue has one; running in parallel, everything does the
		moment it is queued. That single field is the whole difference between
		the two modes, which is why neither needs a branch anywhere else.
	]]
	if (definition.parallel or #record.jobs == 0) then
		job.finish = os.time() + length
	end

	record.jobs[#record.jobs + 1] = job

	ix.bench.Refresh(record)
	ix.bench.Save()

	if (IsValid(record.entity)) then
		record.entity:EmitSound(
			"physics/metal/metal_box_scrape_smooth_loop1.wav", 60, 100, 0.4)
	end

	return true, #record.jobs
end

--[[
	Who started a job, if they are still here as that character.

	TAKES THE JOB, NOT THE RECORD, and that is the whole point of the
	signature. It took the record first, and `Finish` clears `record.job`
	before it works out who to pay - so this read a nil job, answered nil every
	single time, and nobody ever got the experience, the notification, or the
	output in their own inventory when the bench was full. Nothing errored;
	crafting simply paid nothing.

	Handed the job table there is no way to ask it after it has been cleared,
	because the argument is the thing that would have been cleared.
]]
local function JobOwner(job)
	if (not job or not job.character) then return nil end

	for _, client in ipairs(player.GetAll()) do
		local character = client:GetCharacter()

		if (character and character:GetID() == job.character) then
			return client
		end
	end

	return nil
end

--- A job has run its time. Produce, pay, and clear.
function ix.bench.Finish(record, job)
	local definition = ix.bench.TypeOf(record)

	if (not definition or not job) then
		ix.bench.Refresh(record)

		return
	end

	--[[
		Read off the JOB, not looked up again - see the note in `Queue` on why
		the index alone cannot be trusted to still mean the same thing.
	]]
	local output = job.output

	if (not output or not ix.item.list[output]) then
		ix.bench.Refresh(record)

		return
	end

	local client = JobOwner(job)
	local character = client and client:GetCharacter()
	local amount = job.amount or 1

	--[[
		LUCK PAYS IN A BONUS ITEM - BUT NOT ON WEAPONS.

		`ix.special.GetCraftingLuck` is a multiplier a point above 1, so the
		fraction is the chance of one extra coming out. That is the right
		answer for materials and chems: Luck should not make a better stimpak,
		it should now and then make two.

		A WEAPON IS ALREADY PAID FOR IN QUALITY. `sh_rarity.lua` rolls its tier
		off the same Luck, so leaving this applying to weapons too was the same
		stat spent twice - a lucky character got a second rifle for free on top
		of a better one, which is where "why did it craft two?" came from.
	]]
	if (character and not ix.rarity.Applies(output)) then
		local luck = ix.special.GetCraftingLuck(character) - 1

		if (luck > 0 and math.random() < luck) then
			amount = amount + 1
		end
	end

	--[[
		THE EXPERIENCE IS OWED, NOT PAID.

		It used to be handed over the moment a job finished, which paid
		somebody standing somewhere else for a smelter they loaded an hour ago,
		and paid nobody at all when they had logged off. Marking it ON THE ITEM
		means the work is worth something when it is COLLECTED - by whoever
		walks up and takes it out - and a bench full of uncollected output is a
		bench holding wages rather than one that has already paid them into the
		air.

		`ix.bench.Collect` reads it back; see the `OnItemTransferred` listener.
	]]
	local owed = math.floor(job.xp or 0)

	--[[
		EXPERIENCE IS OWED ON A BENCH WITH A BIN, and PAID on one without.

		The whole point of marking it on the item is that somebody collects it
		later; an Instacraftory has nothing to collect from, so the item would
		carry a mark that is only redeemed by moving it out of your own pocket
		and back again. Paid on the spot instead.
	]]
	local mode = ix.bench.GetMode(definition.mode)
	local direct = mode and mode.direct

	if (direct and character and owed > 0) then
		character:AddXP(math.floor(owed
			* ix.special.GetExperienceMultiplier(character)))
	end

	local data = (not direct and owed > 0) and {benchXP = owed} or nil
	local rolled

	--[[
		WEAPONS ARE ROLLED ONE AT A TIME.

		`Produce` stamps the same data on everything it makes, which is right
		for the experience owed and wrong for quality - two rifles out of one
		job are two separate objects and deserve two separate rolls. So a
		weapon output goes through a unit at a time with its own tier, and
		everything else keeps the single call.

		`ix.rarity.Applies` is asked once rather than per item: the answer is a
		property of the item TYPE and cannot change between the first and the
		second.
	]]
	if (ix.rarity.Applies(output)) then
		for _ = 1, amount do
			local tier = ix.rarity.Roll(ix.rarity.LuckOf(character))
			local stamp = data and table.Copy(data) or {}

			stamp.rarity = tier
			rolled = tier

			ix.bench.Produce(client, record, output, 1, stamp)
		end
	else
		ix.bench.Produce(client, record, output, amount, data)
	end

	if (IsValid(client)) then
		local tier = rolled and ix.rarity.Tier(rolled)

		client:Notify(string.format("%s finished: %s%s x%d.",
			definition.name, tier and (tier.name .. " ") or "",
			job.name or output, amount))

		ix.log.Add(client, "benchCraft", job.name or output, definition.name)

		if (tier) then
			ix.log.Add(client, "rarityCraft", job.name or output, tier.name)
		end
	end

	if (IsValid(record.entity)) then
		record.entity:EmitSound("items/ammo_pickup.wav", 65, 110, 0.5)
	end

	ix.bench.Refresh(record)
	ix.bench.Save()
end

--[[
	The first recipe an automatic bench can actually run, out of its own
	inventory.

	IN ORDER, so the list in the configurer is a priority list - a smelter that
	can make both steel and lead makes whichever is higher up. That is a rule
	somebody can use, and picking at random is a rule nobody can.
]]
local function NextAutomatic(record, definition)
	if (definition.mode == "infinite") then
		local index = record.recipe or 1

		return definition.recipes[index] and index or 1
	end

	local function Fillable(recipe)
		--[[
			A recipe with no inputs would be fillable for ever, and a
			processing bench running one would produce without consuming until
			somebody noticed. That is what the infinite mode is FOR, and it is
			chosen deliberately rather than arrived at by leaving a recipe's
			inputs empty.
		]]
		if (#(recipe.input or {}) < 1) then return false end

		local inventory = ix.bench.GetInventory(record)

		for uniqueID, amount in pairs(ix.bench.Needed(recipe)) do
			if (ix.bench.Have(nil, inventory, uniqueID) < amount) then
				return false
			end
		end

		return true
	end

	--- The one somebody asked for, while it can still be filled.
	local preferred = record.recipe and definition.recipes[record.recipe]

	if (preferred and Fillable(preferred)) then return record.recipe end

	for index, recipe in ipairs(definition.recipes or {}) do
		if (Fillable(recipe)) then return index end
	end

	return nil
end

--[[
	One tick a second over every bench, rather than a timer per entity.

	Phoenix create a named timer per workbench and remove it from inside
	itself. That works until an entity goes away in a way the timer does not
	see, and then the timer runs for ever against a NULL - their own callback
	opens with a validity check and a `timer.Remove` because it happens. One
	loop over a table that the loading and the removing both already maintain
	cannot get out of step with itself.

	A second of granularity is plenty: the shortest allowed craft is a second,
	and the progress bar interpolates on the client from the finish time.
]]
timer.Create("ixBenchFlush", 20, 0, function()
	ix.bench.Flush()
end)

timer.Create("ixBenchTick", 1, 0, function()
	if (not loaded) then return end

	local now = os.time()

	for _, record in pairs(ix.bench.list) do
		local definition = ix.bench.TypeOf(record)

		if (not definition) then continue end

		record.jobs = record.jobs or {}

		--[[
			BACKWARDS, so removing a finished job cannot skip the one after it.

			Walking forwards and calling `table.remove` inside the loop is the
			classic way to miss every second element, and with jobs running in
			parallel several can come due on the same tick.
		]]
		for i = #record.jobs, 1, -1 do
			local job = record.jobs[i]

			if (job.finish and job.finish <= now) then
				table.remove(record.jobs, i)

				ix.bench.Finish(record, job)
			end
		end

		--[[
			Start the front of the line if nothing is running it yet. In
			parallel every job already has a finish, so this does nothing
			there; in a line it is what makes the next one begin the moment the
			one before it is done.
		]]
		local next = record.jobs[1]

		if (next and not next.finish) then
			next.finish = now + next.length

			ix.bench.Refresh(record)
			ix.bench.Save()
		end

		if (#record.jobs > 0) then continue end

		--[[
			Automatic benches only, and only while switched on and standing on
			this map. A record for a bench on another map has no entity and
			nothing to produce into that anybody could reach.
		]]
		local mode = ix.bench.GetMode(definition.mode)

		if (not mode or not mode.automatic) then continue end
		if (record.active == false) then continue end
		if (not IsValid(record.entity)) then continue end

		--[[
			A bench nobody may use does not quietly work anyway.

			The gate is on STARTING a job, not on finishing one - a smelter
			that was running when the last person left finishes what it had,
			because the materials were already spent on it. What it will not do
			is keep turning ore into bars on a dead server for somebody to
			collect in the morning, which is the thing the setting is for.
		]]
		if (not ix.bench.HasPopulation(definition)) then continue end

		local index = NextAutomatic(record, definition)

		if (not index) then continue end

		--[[
			Room before materials. See `ix.bench.HasRoom` - a bench that
			consumed and then had nowhere to put the result would either lose
			the batch or start spilling props on the floor for ever.
		]]
		local recipe = definition.recipes[index]

		if (not ix.bench.HasRoom(record, recipe.output,
		math.max(recipe.outputAmount or 1, 1))) then
			continue
		end

		ix.bench.Queue(nil, record, index)
	end
end)

--------------------------------------------------------------------------------
-- Talking to the client
--------------------------------------------------------------------------------

--[[
	Send every type.

	ONE MESSAGE PER BENCH, NOT ONE FOR ALL OF THEM. A net message is capped at
	64KB, and a definition is a table of recipes with no ceiling on how many -
	twenty kinds of bench with thirty recipes each would silently blow the cap
	and the client would be left with whatever arrived before it did. Split
	this way there is no total size that can overflow, only a single bench, and
	a single bench that big is not a thing anybody will make.

	The first message says how many follow, so the client knows when it has the
	whole set and can swap it in at once - a half-applied list is what would
	make a bench window draw a recipe the server has already deleted.

	`ixBenchConfig` is a separate, empty "now open the configurer" sent AFTER
	them. Net messages arrive in order, so the window opens on data that has
	already landed. The shop taught that lesson from the other side, where a
	command sent an open message to a netstring only the server listened for
	and nothing ever appeared.
]]
function ix.bench.SendAll(client, bConfig)
	local names = {}

	for uniqueID in pairs(ix.bench.types) do
		names[#names + 1] = uniqueID
	end

	local function Send()
		if (IsValid(client)) then
			net.Send(client)
		else
			net.Broadcast()
		end
	end

	--[[
		Always sent, even for none: it is what clears whatever the client had,
		so deleting the last bench actually empties their list rather than
		leaving it showing something that no longer exists.
	]]
	net.Start("ixBenchSync")
		net.WriteBool(true)
		net.WriteUInt(#names, 16)
	Send()

	for _, uniqueID in ipairs(names) do
		net.Start("ixBenchSync")
			net.WriteBool(false)
			net.WriteString(uniqueID)
			net.WriteTable(ix.bench.types[uniqueID])

			--- How many of it are standing on this map; see `CountPlaced`.
			net.WriteUInt(ix.bench.CountPlaced(uniqueID), 16)
		Send()
	end

	if (bConfig) then
		net.Start("ixBenchConfig")
		Send()
	end
end

hook.Add("PlayerLoadedCharacter", "ixBenchSync", function(client)
	timer.Simple(1, function()
		if (IsValid(client)) then ix.bench.SendAll(client) end
	end)
end)

--- Open the bench window for somebody standing at one.
function ix.bench.Open(client, record)
	local ok, reason = ix.bench.CanUse(client, record)

	if (not ok) then
		client:Notify(reason)

		return
	end

	--[[
		A record can exist without an entity - one placed on another map keeps
		its record and its inventory and simply has nothing standing anywhere.
		`net.WriteEntity` would send NULL and the window would open against
		nothing, so the refusal happens here where there is somebody to tell.
	]]
	if (not IsValid(record.entity)) then
		client:Notify("That bench is not standing on this map.")

		return
	end

	net.Start("ixBenchPanel")
		net.WriteEntity(record.entity)
	net.Send(client)
end

--[[
	Whether anything may be put INTO a bench is the bench's own setting.

	`allowInput` off makes it an output bin: things only ever come out, and it
	cannot be used as a locker that ignores every rule the faction storages
	enforce. On - the default - it is a workspace you load, which a PROCESSING
	bench has to be, since it draws its materials from its own inventory.

	`CanTransferItem` is the guard rather than the window: a transfer can start
	from anywhere Helix allows one, and the rule has to hold whether or not the
	thing enforcing it is on screen. Taking OUT is never blocked.
]]
hook.Add("CanTransferItem", "ixBench", function(item, from, to)
	if (from == to) then return end

	--[[
		OUT is checked too, and only for the population.

		The window was opened by somebody who passed `CanUse`, and nothing
		stops that stopping being true afterwards - the other four people log
		off and the one left standing there keeps emptying the bench through a
		window that is already on screen. Re-asking here is what closes that,
		and it is the same reasoning `sh_factionstorage.lua` gives for checking
		a demotion on every transfer rather than trusting the open window.
	]]
	if (from and from.vars and from.vars.bench) then
		local definition = ix.bench.TypeOf(ix.bench.Get(from.vars.bench))

		if (definition and not ix.bench.HasPopulation(definition)) then
			return false
		end
	end

	if (not to or not to.vars or not to.vars.bench) then return end

	local definition = ix.bench.TypeOf(ix.bench.Get(to.vars.bench))

	if (not definition) then return end

	if (definition.allowInput == false) then return false end

	if (not ix.bench.HasPopulation(definition)) then return false end
end)

--[[
	Collecting a finished craft is what pays for it.

	Anything a bench made carries `benchXP`; taking it OUT hands that to
	whoever took it and clears the mark, so it is paid exactly once and an item
	passed around afterwards is worth nothing extra.

	`OnItemTransferred` rather than `CanTransferItem`, because this has to run
	only when the move actually happened. `CanTransferItem` is asked BEFORE,
	and a transfer refused after it - no room, most likely - would otherwise
	have paid for work nobody collected.
]]
function ix.bench.Collect(client, item)
	local owed = math.floor(item:GetData("benchXP", 0) or 0)

	if (owed < 1) then return 0 end

	item:SetData("benchXP", nil)

	local character = client and client:GetCharacter()

	if (not character) then return 0 end

	--[[
		The COLLECTOR's Luck, not the crafter's, and multiplied by the size of
		the stack so taking five at once pays for five. The crafter is a
		character id that may have left the server a week ago; the only person
		the game can ask about is the one standing here.
	]]
	local gained = math.floor(owed
		* ix.special.GetExperienceMultiplier(character)
		* math.max(ix.stack.Get(item), 1))

	character:AddXP(gained)

	return gained
end

hook.Add("OnItemTransferred", "ixBench", function(item, from, to)
	if (not from or not from.vars or not from.vars.bench) then return end
	if (to and to.vars and to.vars.bench) then return end

	--[[
		`item.player` is only set while an item FUNCTION is running, so a plain
		drag out of the window does not set it. The owner of the destination
		inventory is what identifies the collector then; if neither answers,
		the experience stays on the item and is paid to whoever next moves it
		somewhere that does.
	]]
	local client = item.player

	if (not IsValid(client) and to) then
		for _, candidate in ipairs(player.GetAll()) do
			local character = candidate:GetCharacter()

			if (character and character:GetInventory() == to) then
				client = candidate

				break
			end
		end
	end

	if (not IsValid(client)) then return end

	local gained = ix.bench.Collect(client, item)

	if (gained > 0) then
		client:Notify(string.format("Collected. +%d XP.", gained))
	end
end)

--[[
	The bench's own inventory, as Helix's storage window.

	`bMultipleUsers`, because a bench is a shared workspace and Helix defaults
	that to false - which answered "someone else is using this" to the second
	person to walk up, and to the FIRST person again if their client never sent
	`ixStorageClose`. See `ix_factionstorage.lua`.
]]
net.Receive("ixBenchStorage", function(length, client)
	local entity = net.ReadEntity()

	if (not IsValid(entity) or entity:GetClass() ~= "ix_workbench") then
		return
	end

	if (client:GetPos():Distance(entity:GetPos()) > 250) then return end

	local record = ix.bench.Get(entity:GetBenchID())

	if (not record) then return end

	local ok, reason = ix.bench.CanUse(client, record)

	if (not ok) then
		client:Notify(reason)

		return
	end

	local definition = ix.bench.TypeOf(record)
	local mode = definition and ix.bench.GetMode(definition.mode)

	if (mode and mode.direct) then
		client:Notify("This bench has no storage - it works straight out of "
			.. "your pockets.")

		return
	end

	local inventory = ix.bench.GetInventory(record)

	if (not inventory) then
		client:Notify("This bench's inventory is not loaded. Tell an admin.")

		return
	end

	ix.storage.Open(client, inventory, {
		name = definition and definition.name or "Workbench",
		entity = entity,
		searchTime = 0,
		bMultipleUsers = true
	})
end)

net.Receive("ixBenchCraft", function(length, client)
	local entity = net.ReadEntity()
	local index = net.ReadUInt(8)

	if (not IsValid(entity) or entity:GetClass() ~= "ix_workbench") then
		return
	end

	if (client:GetPos():Distance(entity:GetPos()) > 200) then return end

	local record = ix.bench.Get(entity:GetBenchID())

	if (not record) then return end

	local definition = ix.bench.TypeOf(record)

	if (not definition) then return end

	--[[
		AN AUTOMATIC BENCH IS NOT DRIVEN FROM HERE. The click sets what it
		works on next; the tick is what starts jobs. Letting a click start one
		as well would race the tick trying to start its own, and both would
		consume.
	]]
	local mode = ix.bench.GetMode(definition.mode)

	if (mode and mode.automatic) then
		if (not (definition.recipes or {})[index]) then return end

		record.recipe = index

		ix.bench.Save()

		client:Notify(string.format(
			definition.mode == "infinite" and "Now making %s."
				or "Will make %s while it has the materials.",
			ix.bench.RecipeName(definition.recipes[index])))

		return
	end

	local ok, reason = ix.bench.Queue(client, record, index)

	if (not ok) then
		client:Notify(reason)

		return
	end

	--- `reason` is the queue position when it worked; see `ix.bench.Queue`.
	if (reason > 1) then
		client:Notify(string.format("Queued %s - number %d in line.",
			ix.bench.RecipeName(ix.bench.Recipes(definition, client)[index]),
			reason))
	end
end)

--[[
	Cancel a job. The materials do NOT come back.

	They were consumed at the start, and returning them would make a bench a
	way to hold materials somewhere nobody can steal them from for exactly as
	long as you like. Admins can cancel a stuck job; that is what it is for.
]]
net.Receive("ixBenchCancel", function(length, client)
	local entity = net.ReadEntity()

	if (not IsValid(entity) or entity:GetClass() ~= "ix_workbench") then
		return
	end

	local record = ix.bench.Get(entity:GetBenchID())

	if (not record or #(record.jobs or {}) < 1) then return end

	--[[
		THE BACK OF THE QUEUE GOES FIRST.

		Cancelling takes the LAST thing queued rather than the one running,
		which is what somebody who queued one too many actually wants - and it
		means pressing it repeatedly walks backwards through your own mistake
		instead of throwing away the craft that is nearly done.
	]]
	local index = #record.jobs
	local job = record.jobs[index]
	local owner = JobOwner(job)

	if (owner ~= client and not client:IsAdmin()) then
		client:Notify("That is not your craft.")

		return
	end

	table.remove(record.jobs, index)

	ix.bench.Refresh(record)
	ix.bench.Save()

	client:Notify(#record.jobs > 0
		and string.format("Cancelled. %d still queued; the materials are "
			.. "gone.", #record.jobs)
		or "Cancelled. The materials are gone.")
end)

--- Switch an automatic bench on or off.
net.Receive("ixBenchToggle", function(length, client)
	local entity = net.ReadEntity()

	if (not IsValid(entity) or entity:GetClass() ~= "ix_workbench") then
		return
	end

	if (client:GetPos():Distance(entity:GetPos()) > 200) then return end

	local record = ix.bench.Get(entity:GetBenchID())

	if (not record) then return end

	local ok, reason = ix.bench.CanUse(client, record)

	if (not ok) then
		client:Notify(reason)

		return
	end

	record.active = record.active == false

	ix.bench.Refresh(record)
	ix.bench.Save()
end)

--------------------------------------------------------------------------------
-- The configurer
--------------------------------------------------------------------------------

net.Receive("ixBenchConfigSet", function(length, client)
	if (not client:IsAdmin()) then return end

	local definition = net.ReadTable()

	--[[
		Re-checked here even though the window checks. Having the configurer
		open is not permission to write anything into the table - the message
		is reachable by anybody who can send a netstring.
	]]
	local ok, reason = ix.bench.SetType(definition)

	client:Notify(ok and string.format("Saved %s.", definition.name)
		or reason)

	ix.log.Add(client, "benchConfig", definition.uniqueID or "?")
end)

net.Receive("ixBenchConfigDelete", function(length, client)
	if (not client:IsSuperAdmin()) then return end

	local uniqueID = net.ReadString()
	local name = ix.bench.types[uniqueID]

	name = name and name.name or uniqueID

	local ok, removed = ix.bench.DeleteType(uniqueID)

	if (not ok) then
		client:Notify(removed)

		return
	end

	client:Notify(string.format("Deleted %s%s.", name,
		removed > 0 and string.format(" and %d placed", removed) or ""))

	ix.log.Add(client, "benchDelete", uniqueID)
end)

--- Placed from the deploy ghost, which sends where the player let go of it.
net.Receive("ixBenchPlace", function(length, client)
	if (not client:IsAdmin()) then return end

	local uniqueID = net.ReadString()
	local position = net.ReadVector()
	local angles = net.ReadAngle()

	local ok, reason = ix.deploy.CanPlace(client, position)

	if (not ok) then
		client:Notify(reason)

		return
	end

	local record, why = ix.bench.Place(uniqueID, position, angles)

	if (not record) then
		client:Notify(why)

		return
	end

	client:Notify(string.format("Placed %s (bench %d).",
		ix.bench.types[uniqueID].name, record.id))

	ix.log.Add(client, "benchPlace", uniqueID)
end)

--[[
	What is IN a bench, item by item, for the window standing at it.

	The counts have to come from the server because the record does not exist
	on the client, and the bench's inventory is not synced there until somebody
	opens the storage window. Without this the "3 / 5 steel" line under a
	recipe would count only what the player is carrying, and would tell
	somebody who had just loaded a smelter that it was empty.

	ASKED FOR, NOT PUSHED. The window polls once a second while it is open, so
	there is no list of viewers to keep and nothing to clean up when somebody
	disconnects with it open - which is the failure the storage receiver list
	already taught. One small message a second per open window.
]]
net.Receive("ixBenchCounts", function(length, client)
	local entity = net.ReadEntity()

	if (not IsValid(entity) or entity:GetClass() ~= "ix_workbench") then
		return
	end

	if (client:GetPos():Distance(entity:GetPos()) > 250) then return end

	local record = ix.bench.Get(entity:GetBenchID())
	local inventory = ix.bench.GetInventory(record)
	local items = {}

	if (inventory) then
		for item in ix.inventory.Each(inventory) do
			items[#items + 1] = item
		end
	end

	--[[
		The ITEMS, not a tally of them, because the window draws the output bin
		from this as well as the have-counts under a recipe. One message
		answering both cannot have the two disagree, and the grid needs the ids
		anyway to be able to take anything.
	]]
	net.Start("ixBenchCounts")
		net.WriteEntity(entity)
		net.WriteUInt(math.min(#items, 255), 8)

		for index = 1, math.min(#items, 255) do
			local item = items[index]

			net.WriteUInt(item.id, 32)
			net.WriteString(item.uniqueID)
			net.WriteUInt(math.min(ix.stack.Get(item), 65535), 16)
		end
	net.Send(client)
end)

ix.log.AddType("benchCraft", function(client, recipe, bench)
	return string.format("%s crafted %s at a %s.", client:Name(), recipe,
		bench)
end)

ix.log.AddType("benchConfig", function(client, uniqueID)
	return string.format("%s configured the '%s' bench.", client:Name(),
		uniqueID)
end)

ix.log.AddType("benchDelete", function(client, uniqueID)
	return string.format("%s deleted the '%s' bench.", client:Name(),
		uniqueID)
end)

ix.log.AddType("benchPlace", function(client, uniqueID)
	return string.format("%s placed a '%s' bench.", client:Name(), uniqueID)
end)
