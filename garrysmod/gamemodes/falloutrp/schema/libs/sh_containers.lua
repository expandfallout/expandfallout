--[[
	Container sizes, and no caps in any of them.

	Helix's `plugins/containers/sh_definitions.lua` is the framework's file and
	is left alone; re-registering here overrides it, and a framework update
	does not silently take our sizes back.

	`ix.container.Register` is a plain write into `ix.container.stored`, and the
	containers plugin turns that table into inventory types in its own
	`InitializedPlugins`. So this runs at file scope AND again on that hook:
	whichever order the two end up in, the last write is 5x5 either way.
]]

ix.containers = ix.containers or {}

--[[
	Only what differs from Helix's own. Twelve of their sixteen definitions are
	fine as they are, and listing them all would mean re-checking every one of
	them against theirs on every framework update.

	These are DEFAULTS. Anything set in the developer terminal is stored
	separately and applied on top - see `ix.containers.sizes` below.
]]
local SIZES = {
	["models/props_junk/wood_crate001a.mdl"] = {5, 5}
}

--[[
	What an admin has changed, by model. `[model] = {width, height}`.

	Kept apart from `SIZES` on purpose: the defaults are a statement about
	Helix's numbers and belong in the code, and an override is a decision
	somebody made at runtime and belongs in the save. Mixing them would mean a
	later change to a default silently doing nothing because the file still
	held the old value.
]]
ix.containers.sizes = ix.containers.sizes or {}

--- Bounds. Twenty is Helix's own practical ceiling for an inventory grid.
ix.containers.minSize = 1
ix.containers.maxSize = 20

--- The size a model should be, override first, then default, then Helix's.
function ix.containers.SizeOf(model)
	local override = ix.containers.sizes[model]

	if (override) then return override[1], override[2] end

	local default = SIZES[model]

	if (default) then return default[1], default[2] end

	local data = ix.container and ix.container.stored
		and ix.container.stored[model]

	return data and data.width or 1, data and data.height or 1
end

--[[
	Write one size into Helix's definition AND its inventory type.

	The plugin builds the types from `ix.container.stored` in its own
	`InitializedPlugins`, so doing it here as well is insurance against running
	after it - registering the same type twice is a plain overwrite.

	EXISTING CONTAINERS CATCH UP ON THE NEXT RESTART, not immediately. Helix
	restores a placed container's inventory with `Restore(id, width, height)`
	read from the definition, so the grid follows this - but only when it is
	next restored. Anything already standing keeps the grid it was made with
	for the rest of the session, and anything already outside a SMALLER new
	grid stops being drawn rather than being deleted.
]]
function ix.containers.Apply(model, width, height)
	if (not ix.container or not ix.container.stored) then return false end

	local data = ix.container.stored[model]

	if (not data) then return false end

	data.width, data.height = width, height

	if (ix.inventory and ix.inventory.Register) then
		ix.inventory.Register("container:" .. model, width, height)
	end

	return true
end

local function ApplySizes()
	if (not ix.container or not ix.container.stored) then return end

	for model in pairs(ix.container.stored) do
		local width, height = ix.containers.SizeOf(model)

		ix.containers.Apply(model, width, height)
	end
end

ix.containers.ApplyAll = ApplySizes

ApplySizes()

hook.Add("InitializedPlugins", "ixContainerSizes", ApplySizes)

--[[
	NO CAPS IN CONTAINERS.

	Caps change hands by `/givecaps` (or `/givemoney`, its alias) and by
	nothing else. A container that holds money is a dead drop nobody has to be
	present for, which is a different thing from handing somebody caps.

	Helix draws that panel whenever `ix.storage.Sync` finds money to report:

	    if (info.entity.GetMoney) then
	        info.data.money = info.entity:GetMoney()

	and the client draws the transfer row on `if (data.money)`. `ix_container`
	has `GetMoney`, so every container had one.

	`GetMoney` RETURNS NIL RATHER THAN BEING REMOVED. `ENT:OpenInventory` calls
	it unconditionally - `data = {money = self:GetMoney()}` - so deleting the
	method would error on every open. Returning nil makes that `{}`, which is
	exactly what a container with nothing to report should send.
]]
if (SERVER) then
	timer.Simple(0, function()
		local stored = scripted_ents.GetStored("ix_container")

		if (not stored or not stored.t) then return end

		stored.t.GetMoney = function() return nil end

		--- Anything trying to put caps in is dropped rather than stored.
		stored.t.SetMoney = function() end
	end)

	--[[
		AND THE MESSAGES THEMSELVES, because hiding a button is not a rule.

		Re-registering a net receiver replaces the one before it, so these two
		take Helix's handlers out entirely - a crafted client cannot move caps
		through a storage even with the panel gone.

		Both directions: `Take` is caps out of a container, `Give` is caps in.
	]]
	net.Receive("ixStorageMoneyTake", function() end)
	net.Receive("ixStorageMoneyGive", function() end)
end
