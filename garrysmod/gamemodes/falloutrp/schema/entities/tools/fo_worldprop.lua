--[[
	The permanent world entity remover.

	    left click    delete the map thing you are pointing at, for good
	    right click   list what has been deleted on this map
	    reload        put the last one back on the list of things that exist

	Doors, railings, lights, the ladder in the wrong place - anything the MAP
	made and nobody wants. The teleport remover is the same mechanism aimed at
	one class of entity; this is the general one.

	WHAT "PERMANENTLY" MEANS HERE. The engine recreates every map entity on
	every load; nothing Lua does can change the BSP. So a deleted thing is kept
	on a list, and `ix.doors.PurgeWorld` removes it again after the map loads
	and after every cleanup. It is deleted every time rather than deleted once,
	which comes to the same thing from inside the game and is the only thing
	that is actually possible.

	IT ONLY TOUCHES MAP ENTITIES. A prop somebody spawned has no
	`MapCreationID`; recording one would write an id that means a different
	entity after the next restart, and the wrong thing would go missing. Use
	the physgun for those - and the permaprop tool if they should stay.

	THE SAME LIST AS THE TELEPORT REMOVER. "Things taken out of this map" is
	one fact; two lists of it would be two lists to keep in step, and the tool
	panels filter it rather than owning it.
]]

TOOL.Category = "Fallout RP"
TOOL.Name = "#tool.fo_worldprop.name"

TOOL.ClientConVar = {}

--[[
	Called again after the convar table is declared: Helix runs
	`CreateConVars()` BEFORE including this file, so anything declared here
	would otherwise never be created. See `24-devtools.md`.
]]
TOOL:CreateConVars()

if (CLIENT) then
	language.Add("tool.fo_worldprop.name", "World Entity Remover")
	language.Add("tool.fo_worldprop.desc",
		"Delete the map's own doors and props for good.")
	language.Add("tool.fo_worldprop.0",
		"Left click something the map made to delete it permanently. Right "
		.. "click to list. Reload to undo the last one.")
end

function TOOL:Allowed()
	local client = self:GetOwner()

	if (not IsValid(client)) then return false end

	if (not ix.admin.Can(client, "door.worldtp")) then
		client:Notify("You cannot delete the map's entities.")

		return false
	end

	return true
end

function TOOL:LeftClick(trace)
	if (CLIENT) then return true end
	if (not self:Allowed()) then return false end

	local client = self:GetOwner()
	local entity = trace.Entity

	if (not IsValid(entity)) then
		client:Notify("Point at something.")

		return false
	end

	local id = ix.doors.MapID(entity)
	local ok, why = ix.doors.DeleteProp(client, entity)

	if (not ok) then
		client:Notify(why)

		return false
	end

	--- Remembered so reload can undo it, on the tool because it is per player.
	self.lastDeleted = id

	client:Notify("Deleted. It will stay deleted through restarts.")

	return true
end

function TOOL:RightClick(trace)
	if (CLIENT) then return true end
	if (not self:Allowed()) then return false end

	local client = self:GetOwner()
	local count = 0

	for id, record in pairs(ix.doors.deleted) do
		local entity = ents.GetMapCreatedEntity(id)

		client:ChatPrint(string.format("  %s (%s) - %s", tostring(id),
			istable(record) and record.class or "unknown",
			IsValid(entity) and "STILL PRESENT" or "gone"))

		count = count + 1
	end

	client:Notify(count == 0 and "Nothing has been deleted on this map."
		or string.format("%d deleted on this map.", count))

	return true
end

function TOOL:Reload(trace)
	if (CLIENT) then return true end
	if (not self:Allowed()) then return false end

	local client = self:GetOwner()

	if (not self.lastDeleted) then
		client:Notify("You have not deleted one this session - use the list "
			.. "in the tool panel.")

		return false
	end

	local ok, why = ix.doors.RestoreWorld(client, self.lastDeleted)

	if (not ok) then
		client:Notify(why)

		return false
	end

	self.lastDeleted = nil

	ix.doors.SendAll()

	--[[
		Said plainly, because it is not what somebody will expect. Lua cannot
		put a map entity back; only a map reload can.
	]]
	client:Notify("Taken off the list. It comes back when the map reloads.")

	return true
end

function TOOL.BuildCPanel(panel)
	panel:AddControl("Header", {
		Description = "Click anything the map made to delete it for good - a "
			.. "door, a railing, a light. Not props you spawned."
	})

	panel:Help("Left click deletes. Reload undoes the last one you deleted "
		.. "this session. Anything on the list below can be restored whenever "
		.. "it was deleted - it reappears on the next map load.")

	ix.doors.BuildDeletedList(panel, false)
end
