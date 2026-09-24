--[[
	Workbenches, client side: the types, and which window to open.

	The definitions are sent to everybody rather than asked for per bench.
	They are not secret - the gating decides who may USE one, not who may know
	it exists - and a bench you are standing at has to be able to name what it
	makes without a round trip in the middle of drawing its window.

	`ixBenchSync` and `ixBenchConfig` carry the same payload and differ only in
	what happens afterwards. That is deliberate: the shop's first version sent
	a separate "please open" message to a netstring only the SERVER listened
	for, so `/shopconfig` sent a message into the void and no window ever
	appeared. A window opens when its DATA arrives.
]]

if (not CLIENT) then return end

ix.bench = ix.bench or {}
ix.bench.types = ix.bench.types or {}

--[[
	The types arrive one message per bench; see `ix.bench.SendAll`.

	COLLECTED, THEN SWAPPED IN. The definitions land in `pending` and only
	become `ix.bench.types` once the count promised by the first message has
	arrived. Applying them as they came would leave the list half old and half
	new for a frame or two, which is exactly long enough for a bench window
	rebuilding on the first one to draw a recipe that the rest of the message
	was about to delete.
]]
local pending, expected = nil, 0

local function Refresh()
	if (IsValid(ix.gui.benchConfig)) then
		ix.gui.benchConfig:Rebuild()
	end

	if (IsValid(ix.gui.bench)) then
		ix.gui.bench:Rebuild()
	end
end

net.Receive("ixBenchSync", function()
	if (net.ReadBool()) then
		pending, expected = {}, net.ReadUInt(16)

		--[[
			None following means the list is empty, and the swap happens here
			rather than never - deleting the last bench has to actually clear
			what the client is holding.
		]]
		if (expected == 0) then
			ix.bench.types = {}
			ix.bench.placed = {}
			pending = nil

			Refresh()
		end

		return
	end

	local uniqueID = net.ReadString()
	local definition = net.ReadTable()
	local placed = net.ReadUInt(16)

	definition.uniqueID = uniqueID
	definition.recipes = definition.recipes or {}

	--[[
		A definition arriving without its opening message is dropped rather
		than merged into whatever is there. It can only mean the first message
		was missed, and half a list is worse than the old one.
	]]
	if (not pending) then return end

	pending[uniqueID] = {definition = definition, placed = placed}

	if (table.Count(pending) < expected) then return end

	local types, counts = {}, {}

	for id, entry in pairs(pending) do
		types[id] = entry.definition
		counts[id] = entry.placed
	end

	ix.bench.types = types
	ix.bench.placed = counts
	pending = nil

	Refresh()
end)

--- Just "open the configurer"; the data is already here. See `SendAll`.
net.Receive("ixBenchConfig", function()
	if (IsValid(ix.gui.benchConfig)) then
		ix.gui.benchConfig:Rebuild()

		return
	end

	vgui.Create("ixFOBenchConfig")
end)

--[[
	Which window a bench opens.

	MOST BENCHES ARE A RECIPE LIST and get `ixFOBench`. A mode may name its own
	panel instead - see `panel` in `ix.bench.modes` - which is how the trade-up
	and modulate benches get a window whose subject is not a recipe at all. The
	panel only has to take `SetBench`.

	The mode is read from the DEFINITION rather than sent, because the
	definitions are already here: they are synced to everybody on join.
]]
net.Receive("ixBenchPanel", function()
	local entity = net.ReadEntity()

	if (not IsValid(entity)) then return end

	--[[
		EVERY BENCH WINDOW, not just the ordinary one. Walking from a modulate
		bench to a chem bench used to leave the first window open behind the
		second, because each panel only ever removed its own kind.
	]]
	for _, key in ipairs({"bench", "tradeup", "modulate"}) do
		if (IsValid(ix.gui[key])) then
			ix.gui[key]:Remove()
		end
	end

	local definition = ix.bench.types[entity:GetBenchType()]
	local mode = definition and ix.bench.GetMode(definition.mode)
	local class = mode and mode.panel

	--[[
		A named panel that does not exist falls back to the ordinary window
		rather than to nothing. That happens when a mode is added on the server
		and the client has an older schema, and an unusable bench is a better
		answer than a bench that silently does nothing when you press E.
	]]
	if (class and vgui.GetControlTable(class)) then
		vgui.Create(class):SetBench(entity)

		return
	end

	vgui.Create("ixFOBench"):SetBench(entity)
end)

--[[
	Place a bench with the deploy ghost.

	Called by `/benchplace`; the ghost, the rotation and the red-when-illegal
	preview are all `cl_deploy.lua`'s, which knows nothing about what it is
	placing - see the comment on `ix.deploy.Begin`.
]]
function ix.bench.BeginPlacing(uniqueID)
	local definition = ix.bench.types[uniqueID]

	if (not definition) then
		LocalPlayer():Notify("No bench called '" .. uniqueID .. "'.")

		return
	end

	if (not ix.deploy.Begin(definition.model, function(position, angles)
		net.Start("ixBenchPlace")
			net.WriteString(uniqueID)
			net.WriteVector(position)
			net.WriteAngle(angles)
		net.SendToServer()
	end)) then
		LocalPlayer():Notify("That bench's model could not be loaded.")

		return
	end

	LocalPlayer():Notify("Left click to place, J and K to turn, right click "
		.. "to cancel.")
end

net.Receive("ixBenchBeginPlacing", function()
	ix.bench.BeginPlacing(net.ReadString())
end)
