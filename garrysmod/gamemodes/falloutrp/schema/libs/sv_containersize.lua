--[[
	Container sizes an admin has changed, stored and shared.

	See `sh_containers.lua` for what a size is and when a change takes effect.
	This is the storage, the net message the developer terminal sends, and the
	sync that keeps the client's copy of `ix.container.stored` honest - the
	terminal reads its rows from that table, so a client with the framework's
	numbers would show the wrong size for every crate on the server.

	NOT PER MAP. A crate's size is a decision about the item economy, not about
	a map, and re-deciding it for every map would be work nobody asked for.
]]

if (not SERVER) then return end

util.AddNetworkString("ixContainerSizes")
util.AddNetworkString("ixContainerSizeSet")

local KEY = "containersizes"
local loaded = false

function ix.containers.Save()
	if (not loaded) then return end

	ix.data.Set(KEY, ix.containers.sizes, false, true)
end

function ix.containers.Load()
	if (loaded) then return end

	ix.containers.sizes = ix.data.Get(KEY, {}, false, true) or {}
	loaded = true

	--[[
		Applied AFTER loading rather than trusting the file to match what is
		registered: a model that has since been removed from the container
		definitions is simply skipped by `Apply`, and its stored size sits
		harmlessly in the file until somebody adds it back.
	]]
	ix.containers.ApplyAll()
end

hook.Add("LoadData", "ixContainerSizes", ix.containers.Load)
hook.Add("PostLoadData", "ixContainerSizes", ix.containers.Load)
timer.Simple(10, ix.containers.Load)

--------------------------------------------------------------------------------
-- Telling the clients
--------------------------------------------------------------------------------

function ix.containers.Sync(client)
	local list = {}

	for model in pairs(ix.container and ix.container.stored or {}) do
		local width, height = ix.containers.SizeOf(model)

		list[#list + 1] = {model = model, width = width, height = height}
	end

	net.Start("ixContainerSizes")
		net.WriteUInt(#list, 8)

		for _, entry in ipairs(list) do
			net.WriteString(entry.model)
			net.WriteUInt(entry.width, 6)
			net.WriteUInt(entry.height, 6)
		end

	if (IsValid(client)) then
		net.Send(client)
	else
		net.Broadcast()
	end
end

hook.Add("PlayerLoadedCharacter", "ixContainerSizes", function(client)
	timer.Simple(1, function()
		if (IsValid(client)) then ix.containers.Sync(client) end
	end)
end)

--------------------------------------------------------------------------------
-- Changing one
--------------------------------------------------------------------------------

net.Receive("ixContainerSizeSet", function(length, client)
	if (not ix.admin.Can(client, "dev.terminal")) then
		ix.log.Add(client, "devTerminalDenied")

		return
	end

	local model = string.lower(net.ReadString())
	local width = math.Clamp(net.ReadUInt(6), ix.containers.minSize,
		ix.containers.maxSize)
	local height = math.Clamp(net.ReadUInt(6), ix.containers.minSize,
		ix.containers.maxSize)

	--[[
		A MODEL HELIX KNOWS ABOUT, and nothing else. `ix.container.stored` is
		the list of things that can be a container at all; a size stored for
		anything else would never be read and would sit in the save for ever.
	]]
	if (not ix.container or not ix.container.stored[model]) then return end
	if (not loaded) then return end

	ix.containers.sizes[model] = {width, height}

	ix.containers.Apply(model, width, height)
	ix.containers.Save()
	ix.containers.Sync()

	client:Notify(string.format("%s is now %dx%d. Anything already placed "
		.. "keeps its grid until the next restart.", model, width, height))

	ix.log.Add(client, "containerSize", model, width, height)
end)

ix.log.AddType("containerSize", function(client, model, width, height)
	return string.format("%s set %s containers to %dx%d.", client:Name(),
		model, width, height)
end, FLAG_NORMAL)
