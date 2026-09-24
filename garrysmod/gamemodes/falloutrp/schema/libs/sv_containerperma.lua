--[[
	Helix storage containers are not permanent unless somebody says so.

	Out of the box, every `ix_container` an admin spawns comes back after a
	restart, forever. That is the wrong default for a server where containers
	get put down to test things: the map fills with crates nobody remembers
	placing, and the only way to be rid of one is to find it again.

	So a container survives a restart only if it has been marked with the
	permaprop tool, which is the same gesture that makes anything else
	permanent.

	WHY THIS SWEEPS AT BOOT RATHER THAN REFUSING TO SAVE.

	The obvious lever is Helix's own hook:

	    function PLUGIN:CanSaveContainer(entity, inventory)
	        return ix.config.Get("containerSave", true)
	    end

	and it is a trap. Returning false does not mean "skip this one" - look at
	what the else branch of `SaveContainer` actually does:

	    else
	        local query = mysql:Delete("ix_items")
	            query:Where("inventory_id", index)
	        query:Execute()
	        ...                     -- helix/plugins/containers/sh_plugin.lua:78

	It DELETES the container's items and inventory. And `SaveContainer` is
	reached from `SaveData`, which Helix runs on a timer:

	    timer.Create("ixSaveData", 600, 0, ...)   -- core/sh_data.lua:116

	so returning false there would empty every unmarked container on the map,
	every ten minutes, while people were using them. That is not persistence
	being switched off, it is a live data loss bug.

	Nor is replacing `PLUGIN.SaveContainer` outright much better: it means
	copying Helix's seven-field save tuple into this file, where it silently
	stops matching the day they add an eighth.

	So Helix saves and restores exactly as it always did, untouched, and this
	removes the containers that should not have come back - shortly after boot,
	before anybody has finished loading the map. Removing one goes through
	`ENT:OnRemove`, which deletes its items and inventory rows and fires
	`ContainerRemoved`, which makes Helix rewrite its own save file without
	them. The cleanup is Helix's, triggered rather than reimplemented.

	TIMING IS LOAD-BEARING, in two ways, and both bite.

	First, `ENT:OnRemove` does nothing at all unless `ix.entityDataLoaded` is
	true, and that is set two seconds after `InitPostEntity`:

	    timer.Simple(2, function() ix.entityDataLoaded = true end)
	                                        -- core/hooks/sv_hooks.lua:770

	Sweeping before then would remove the entities and leave their inventories
	in the database and their rows in Helix's save file - so they would come
	back on the next restart, looking like the sweep had never run.

	Second, and worse, a restored container does not know its own ID yet:

	    ix.inventory.Restore(inventoryID, w, h, function(inventory)
	        entity:SetInventory(inventory)      -- this is what calls SetID
	    end)               -- helix/plugins/containers/sh_plugin.lua:151

	That callback is a database round trip. `GetID()` reads 0 until it lands,
	and Helix's own `RunLoadData` is itself called from the database connect
	callback rather than from `InitPostEntity`, so there is no fixed delay that
	is reliably "after". A single timed sweep that treated an unresolved ID as
	"not marked" would delete permanent containers, which is the one outcome
	this must never have.

	So the sweep RUNS REPEATEDLY over the first half minute, and:

	  * a container whose ID has not resolved is left alone, every time. Not
	    knowing yet is never grounds for deleting somebody's storage.
	  * a container created after the sweep has finished is tagged and never
	    considered, so an admin putting one down cannot have it swept out from
	    under them.

	The first version identified restorable containers by reading Helix's own
	saved rows and matching inventory IDs. That worked on paper and did not
	work in practice, and it was not debuggable from in front of the screen -
	it depended on the field layout of somebody else's save file, and when
	nothing got removed there was no way to see which of five assumptions had
	failed. Tagging depends on nothing outside this file, and `fo_containers`
	prints the decision for every container on the map.

	MARKED BY INVENTORY ID, because that is the one thing about a container
	that survives a restart. Helix restores each one with the inventory ID it
	was saved with, so the ID names the same container next boot; a position
	would not, since a permanent container can be dragged somewhere else.
]]

if (not SERVER) then return end

ix.permaprop = ix.permaprop or {}

--- `[inventoryID] = true`, per map, for containers that should come back.
ix.permaprop.containers = ix.permaprop.containers or {}

--[[
	The first pass waits for `ix.entityDataLoaded`, with a second in hand.
	Later passes catch containers whose inventory arrived after it.
]]
local SWEEP_DELAY = 3.5
local SWEEP_INTERVAL = 2
local SWEEP_PASSES = 14

--[[
	Whether the boot sweep has finished. Anything created after it is a live
	spawn and is never touched.
]]
ix.permaprop.sweepDone = ix.permaprop.sweepDone or false
ix.permaprop.sweepStarted = ix.permaprop.sweepStarted or false

function ix.permaprop.IsContainer(entity)
	return IsValid(entity) and entity:GetClass() == "ix_container"
end

--[[
	A container's identity across restarts.

	`GetID` is the inventory ID - the same value `ENT:OnRemove` uses to find
	what to delete, and the same one Helix writes into its save tuple.
]]
local function ContainerID(entity)
	local id = entity.GetID and entity:GetID()

	return isnumber(id) and id > 0 and id or nil
end

function ix.permaprop.SaveContainers()
	local saved = {}

	for id in pairs(ix.permaprop.containers) do
		saved[#saved + 1] = id
	end

	--[[
		Written as a LIST of ids rather than the set itself: JSON has no
		integer keys, so a set round-trips as a table keyed by the strings
		"41", "42" and then never matches a numeric lookup again.
	]]
	ix.data.Set("permacontainers", saved)

	return #saved
end

function ix.permaprop.LoadContainers()
	ix.permaprop.containers = {}

	for _, id in ipairs(ix.data.Get("permacontainers", {}) or {}) do
		id = tonumber(id)

		if (id) then
			ix.permaprop.containers[id] = true
		end
	end
end

--[[
	Mark or unmark a container.

	Helix is asked to save immediately afterwards, so the container's row is in
	its file from the moment it is marked rather than at whatever point the ten
	minute timer next comes round - which matters, because a mark that is lost
	to a crash is a container that quietly disappears.
]]
function ix.permaprop.SetContainerPermanent(entity, bValue)
	local id = ContainerID(entity)

	if (not id) then
		return false, "that container has no inventory yet - try again in a moment"
	end

	if (bValue and ix.permaprop.containers[id]) then
		return false, "already permanent"
	end

	if (not bValue and not ix.permaprop.containers[id]) then
		return false, "that is not permanent"
	end

	ix.permaprop.containers[id] = bValue or nil
	ix.permaprop.SaveContainers()

	local plugin = ix.plugin.list and ix.plugin.list.containers

	if (plugin and isfunction(plugin.SaveContainer)) then
		plugin:SaveContainer()
	end

	return true
end

--[[
	Remove the containers that should not have come back.

	`ixIsSafe` is Helix's own flag for a container whose removal must not
	delete its contents - respected rather than overridden, because a plugin
	that sets it has a reason to.

	Returns the three counts the report and the loop both need: kept, removed,
	and still waiting on the database.
]]
function ix.permaprop.SweepContainers()
	local kept, removed, waiting = 0, 0, 0

	for _, entity in ipairs(ents.FindByClass("ix_container")) do
		local id = ContainerID(entity)

		if (entity.ixLiveSpawn) then
			kept = kept + 1
		elseif (not id) then
			-- Its inventory has not come back from the database yet.
			waiting = waiting + 1
		elseif (ix.permaprop.containers[id]) then
			kept = kept + 1
		elseif (not entity.ixIsSafe) then
			entity:Remove()
			removed = removed + 1
		else
			kept = kept + 1
		end
	end

	return kept, removed, waiting
end

--[[
	Tag containers created after the sweep, and give one an owner.

	OWNERSHIP. Helix creates the container itself, inside its own
	`PlayerSpawnedProp`, and never tells anyone whose it is - so prop
	protection sees an unowned entity and the person who spawned it cannot
	remove their own crate. `CanPlayerSpawnContainer` runs immediately before
	the creation, in the same tick, which is the only place the player and the
	container are both knowable.

	Matched on the TICK rather than by clearing a flag on a zero timer, because
	two zero timers have no defined order between them and this would then work
	most of the time.
]]
local pendingOwner
local pendingTick = -1

hook.Add("CanPlayerSpawnContainer", "ixContainerOwner", function(client)
	pendingOwner = client
	pendingTick = engine.TickCount()
end)

hook.Add("OnEntityCreated", "ixContainerOwner", function(entity)
	if (not IsValid(entity)) then return end

	local tick = engine.TickCount()
	local owner = pendingOwner

	--[[
		Deferred a frame: a scripted entity's class is not dependable inside
		`OnEntityCreated` itself.
	]]
	timer.Simple(0, function()
		if (not IsValid(entity) or entity:GetClass() ~= "ix_container") then return end

		entity.ixLiveSpawn = ix.permaprop.sweepDone or nil

		if (tick ~= pendingTick or not IsValid(owner)) then return end

		--[[
			HELIX OWNERSHIP IS A NETVAR HOLDING A CHARACTER ID.

			Not `SetCreator`, and not CPPI - the first version set both of those
			and neither did anything, because Helix's own prop protection asks a
			different question entirely:

			    if (entity:GetNetVar("owner", 0) != characterID
			                        -- helix/plugins/propprotect.lua:82

			and Helix stamps ordinary props as

			    entity:SetNetVar("owner", client:GetCharacter():GetID())
			                        -- core/hooks/sv_hooks.lua:413

			The container misses that because it is a SECOND entity: Helix stamps
			the prop the player spawned, then the containers plugin creates a
			container and removes the prop, and the stamp goes with the prop.

			The CHARACTER rather than the player, because that is what the check
			compares against - which also means the same player's other characters
			cannot move it, the intended behaviour of a character-scoped ownership
			model rather than an accident of it.
		]]
		local character = owner:GetCharacter()

		if (character) then
			entity:SetNetVar("owner", character:GetID())
		end

		-- Set as well, for admin tools and prop protection addons that read them.
		entity:SetCreator(owner)

		if (isfunction(entity.CPPISetOwner)) then
			entity:CPPISetOwner(owner)
		end

		--[[
			AND AN UNDO ENTRY, WHICH IS THE OTHER HALF OF "I CANNOT REMOVE MY
			OWN CRATE".

			Ownership answers the toolgun and prop protection. Undo is a
			separate list, and Helix's containers plugin never adds to it: it
			lets Sandbox register an undo for the PROP the player spawned, then
			removes that prop and creates a container in its place. So the undo
			entry names an entity that no longer exists and Z does nothing,
			whoever owns what is standing there.

			Registered against the container instead. Phoenix do the same for
			their deployables, for the same reason.
		]]
		undo.Create("Container")
			undo.AddEntity(entity)
			undo.SetPlayer(owner)
			undo.SetCustomUndoText("Undone container")
		undo.Finish()

		--[[
			And counted against the player's prop limit, so a container is not
			a way around it. `PlayerSpawnedSENT` is the hook the limit and the
			admin logs both read.
		]]
		gamemode.Call("PlayerSpawnedSENT", owner, entity)
	end)
end)

--[[
	Say what the sweep decided, for every container on the map.

	Written because the first version of this silently did nothing and there
	was no way to tell whether the sweep had not run, had found no containers,
	had not resolved their IDs, or had decided they were all permanent.
]]
concommand.Add("fo_containers", function(client)
	if (IsValid(client) and not client:IsSuperAdmin()) then return end

	local function Line(colour, text)
		if (IsValid(client)) then client:ChatPrint(text) end

		MsgC(colour, text .. "\n")
	end

	local marked = 0

	for _ in pairs(ix.permaprop.containers) do
		marked = marked + 1
	end

	Line(Color(255, 200, 100), string.format(
		"[falloutrp] %d container(s) on %s, %d marked permanent, sweep %s",
		#ents.FindByClass("ix_container"), game.GetMap(), marked,
		ix.permaprop.sweepDone and "finished" or "not finished"))

	for _, entity in ipairs(ents.FindByClass("ix_container")) do
		local id = ContainerID(entity)
		local verdict, colour

		if (entity.ixLiveSpawn) then
			verdict, colour = "spawned this session - never swept", Color(200, 200, 200)
		elseif (not id) then
			verdict, colour = "NO INVENTORY YET - left alone", Color(255, 200, 120)
		elseif (ix.permaprop.containers[id]) then
			verdict, colour = "permanent", Color(140, 230, 150)
		elseif (entity.ixIsSafe) then
			verdict, colour = "flagged safe by another plugin", Color(200, 200, 200)
		else
			verdict, colour = "temporary - should have been removed", Color(255, 160, 160)
		end

		Line(colour, string.format("  inv %-6s %-46s %s",
			id and tostring(id) or "-",
			string.sub(entity:GetModel() or "?", -46), verdict))
	end
end)

--[[
	`PostLoadData`, not `InitPostEntity`.

	`InitPostEntity` does not reach this schema at all - see the note in
	`sv_loot.lua` - which is why the sweep never ran and every container came
	back. `PostLoadData` is better than `LoadData` here specifically: Helix
	runs it after EVERY plugin's `LoadData`, so the containers plugin has
	already spawned whatever it is going to spawn.
]]
local function StartSweep()
	if (ix.permaprop.sweepStarted) then return end

	ix.permaprop.sweepStarted = true

	ix.permaprop.LoadContainers()

	local pass = 0
	local total = 0

	--[[
		One pass. Answers whether there is any point running another.
	]]
	local function Pass()
		pass = pass + 1

		local kept, removed, waiting = ix.permaprop.SweepContainers()

		total = total + removed

		--[[
			Keep going only while something is still waiting on the database.
			Once every container knows its own inventory, another twenty seconds
			of passes would find the same answer.
		]]
		if (waiting > 0 and pass < SWEEP_PASSES) then return false end

		ix.permaprop.sweepDone = true

		if (kept > 0 or total > 0 or waiting > 0) then
			MsgC(Color(255, 200, 100), string.format(
				"[falloutrp] containers: %d permanent, %d temporary removed%s\n",
				kept, total, waiting > 0 and string.format(
					", %d left alone - no inventory after %d seconds",
					waiting, SWEEP_PASSES * SWEEP_INTERVAL) or ""))
		end

		return true
	end

	--[[
		Started late rather than immediately: before `ix.entityDataLoaded`,
		removing a container is a no-op that leaves its rows behind and its entry
		in Helix's save file, so it would simply return next restart.

		The repeating timer is only created if the first pass did not settle it,
		which on a server with no containers is every time.
	]]
	timer.Simple(SWEEP_DELAY, function()
		if (Pass()) then return end

		timer.Create("ixContainerSweep", SWEEP_INTERVAL, 0, function()
			if (Pass()) then
				timer.Remove("ixContainerSweep")
			end
		end)
	end)
end

hook.Add("PostLoadData", "ixContainerPerma", StartSweep)

hook.Add("InitPostEntity", "ixContainerPerma", function()
	timer.Simple(2, StartSweep)
end)

--[[
	LAST RESORT.

	Two triggers is not belt and braces when both are hooks and this has now
	silently destroyed data twice by not running. A plain timer depends on
	nothing but the server ticking, and it is a no-op in every case where
	either hook did fire, because the load is guarded.

	Ten seconds is late enough that the database has certainly answered and
	early enough that nobody has finished connecting.
]]
timer.Simple(10, StartSweep)

--------------------------------------------------------------------------------
-- Containers whose inventory is not in memory
--------------------------------------------------------------------------------

--[[
	`ix_container:Use` is `if (inventory and ...)` and nothing else - no
	message, no sound, no notification. So a container whose inventory is not
	in `ix.item.inventories` is indistinguishable from a container that is not
	an entity at all: you press E and the game does not react.

	That is the same symptom the faction storage had, and the same repair
	works, because everything needed is already known: the container carries
	its inventory id in a networked var, and `ix.container.stored` knows the
	size for its model.

	`PlayerUse` rather than overriding `ENT:Use`: the entity belongs to Helix's
	plugin and replacing a method on it would be a copy of their function that
	has to be kept in step with theirs. This runs before it, fixes the one
	thing that stops it working, and lets theirs run.
]]
local restoring = {}

hook.Add("PlayerUse", "ixContainerRestore", function(client, entity)
	if (not IsValid(entity) or entity:GetClass() ~= "ix_container") then return end

	local id = entity.GetID and entity:GetID()

	--[[
		The first link in the chain, so "E did nothing" can be told apart from
		"E was never seen". `PlayerUse` fires before the entity's own `Use`.
	]]
	if (ix.storageTrace) then
		client:ChatPrint(string.format(
			"[storage] USE container ent=%d invID=%s resolves=%s",
			entity:EntIndex(), tostring(id),
			tostring(isnumber(id) and id > 0
				and ix.inventory.Get(id) ~= nil)))
	end

	if (not isnumber(id) or id < 1) then return end
	if (ix.inventory.Get(id)) then return end

	--[[
		Once at a time per container. `PlayerUse` fires repeatedly while the
		key is held, and a restore is a database query.
	]]
	if (restoring[id]) then return end

	local definition = ix.container.stored[(entity:GetModel() or ""):lower()]

	if (not definition or not definition.width) then
		client:Notify("This container has no definition for its model.")

		return
	end

	restoring[id] = true

	MsgC(Color(255, 200, 100), string.format(
		"[falloutrp] container inventory %d was not in memory - restoring\n", id))

	ix.inventory.Restore(id, definition.width, definition.height,
		function(inventory)
			restoring[id] = nil

			if (not inventory) then return end

			inventory.vars.isBag = true
			inventory.vars.isContainer = true

			if (IsValid(client)) then
				client:Notify("Loaded it - press E again.")
			end
		end)
end)

--------------------------------------------------------------------------------

--[[
	Everything `ix_container:Use` checks, for every container on the map.

	It refuses silently - `if (inventory and ...)` with no else - so when
	pressing E does nothing there is no way to tell which of its four
	conditions failed. This prints all of them.
]]
concommand.Add("fo_container_report", function(client)
	if (IsValid(client) and not client:IsSuperAdmin()) then return end

	local function Line(text)
		if (IsValid(client)) then client:ChatPrint(text) end

		MsgC(Color(200, 200, 200), text .. "\n")
	end

	local containers = ents.FindByClass("ix_container")

	Line(string.format("[falloutrp] %d container(s), %d inventory table entries",
		#containers, table.Count(ix.item.inventories or {})))

	for _, entity in ipairs(containers) do
		local id = entity.GetID and entity:GetID()
		local inventory = isnumber(id) and id > 0 and ix.inventory.Get(id)
		local definition = ix.container.stored[(entity:GetModel() or ""):lower()]

		Line(string.format("  ent %d  %s", entity:EntIndex(),
			tostring(entity:GetModel())))

		Line(string.format("    invID=%s (%s)  inventory=%s  size=%s",
			tostring(id), type(id),
			inventory and "LOADED" or "MISSING",
			inventory and (inventory:GetSize() .. "x"
				.. select(2, inventory:GetSize())) or "-"))

		Line(string.format("    definition=%s  locked=%s  displayName='%s'",
			definition and "found" or "MISSING",
			tostring(entity:GetLocked()),
			tostring(entity:GetDisplayName())))

		if (inventory) then
			Line(string.format("    inUse=%s  receivers=%d",
				tostring(ix.storage.InUse(inventory)),
				#(inventory:GetReceivers() or {})))
		end
	end

	--[[
		And the keys the inventory table actually holds, because "the id is
		right and the lookup misses" is a type mismatch until proven otherwise
		- a string key and a number key look identical in every message above.
	]]
	local keys = {}

	for key in pairs(ix.item.inventories or {}) do
		keys[#keys + 1] = string.format("%s(%s)", tostring(key), type(key))
	end

	table.sort(keys)

	Line("  inventory keys: " .. table.concat(keys, " "))
end)
