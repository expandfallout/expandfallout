--[[
	The world teleport remover.

	    left click    delete the map teleport you are pointing at, for good
	    right click   list what has been deleted on this map
	    reload        put the last one back on the list of things that exist

	WHAT "PERMANENTLY" MEANS HERE. The engine recreates every map entity on
	every load; nothing Lua does can change the BSP. So a deleted teleport is
	kept on a list, and `ix.doors.PurgeWorld` removes it again after the map
	loads and after every cleanup. It is deleted every time rather than deleted
	once, which comes to the same thing from inside the game and is the only
	thing that is actually possible.

	A TRIGGER HAS NO MODEL, so it cannot be pointed at in the ordinary way -
	`trace.Entity` on a trigger returns the world. The tool therefore finds the
	nearest trigger to where you clicked; `cl_doors.lua` draws every one of
	them as a wireframe box while this tool is out, so there is something to
	aim at.
]]

TOOL.Category = "Fallout RP"
TOOL.Name = "#tool.fo_worldtp.name"

TOOL.ClientConVar = {}

--[[
	Called again after the convar table is declared: Helix runs
	`CreateConVars()` BEFORE including this file, so anything declared here
	would otherwise never be created. See `24-devtools.md`.
]]
TOOL:CreateConVars()

if (CLIENT) then
	language.Add("tool.fo_worldtp.name", "World Teleport Remover")
	language.Add("tool.fo_worldtp.desc",
		"Delete the map's own teleports for good.")
	language.Add("tool.fo_worldtp.0",
		"Left click a highlighted trigger to delete it. Right click to list "
		.. "what has been deleted. Reload to undo the last one.")
end

function TOOL:Allowed()
	local client = self:GetOwner()

	if (not IsValid(client)) then return false end

	if (not ix.admin.Can(client, "door.worldtp")) then
		client:Notify("You cannot delete the map's teleports.")

		return false
	end

	return true
end

--[[
	The nearest teleport trigger to a point, within reach.

	A radius rather than a trace because triggers are not solid to traces. 128
	units is about the size of a doorway, which is what most of them are drawn
	around - big enough to hit by aiming at the box, small enough not to catch
	the one in the next room.
]]
local function NearestTrigger(position)
	local best, bestDistance

	for _, entity in ipairs(ents.FindInSphere(position, 128)) do
		if (not ix.doors.worldClasses[entity:GetClass()]) then continue end

		local distance = entity:GetPos():DistToSqr(position)

		if (not bestDistance or distance < bestDistance) then
			best, bestDistance = entity, distance
		end
	end

	return best
end

function TOOL:LeftClick(trace)
	if (CLIENT) then return true end
	if (not self:Allowed()) then return false end

	local client = self:GetOwner()

	--[[
		The entity under the crosshair first, in case it is one with a model -
		`point_teleport` is a point entity and can be hit directly. Only then
		the search, which is what catches the brush triggers.
	]]
	local entity = trace.Entity

	if (not IsValid(entity)
	or not ix.doors.worldClasses[entity:GetClass()]) then
		entity = NearestTrigger(trace.HitPos)
	end

	if (not IsValid(entity)) then
		client:Notify("No map teleport near there.")

		return false
	end

	local id = ix.doors.MapID(entity)
	local ok, why = ix.doors.DeleteWorld(client, entity)

	if (not ok) then
		client:Notify(why)

		return false
	end

	--[[
		Remembered so reload can undo it. On the TOOL rather than on the
		player, because a tool object is per player already and putting it on
		the player would be a second place to clear it from.
	]]
	self.lastDeleted = id

	client:Notify("Deleted. It will stay deleted through restarts.")

	return true
end

--[[
	Right click prints the list in chat.

	The tool panel has the same list with a button per row, which is the better
	way in - this stays because it works while you are standing in front of the
	hole rather than in a menu.
]]
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
		client:Notify("You have not deleted one this session.")

		return false
	end

	local ok, why = ix.doors.RestoreWorld(client, self.lastDeleted)

	if (not ok) then
		client:Notify(why)

		return false
	end

	self.lastDeleted = nil

	--[[
		Said plainly, because it is not what somebody will expect. Lua cannot
		put a map entity back; only a map reload can. Claiming otherwise would
		cost somebody an hour looking for a teleport that is not there yet.
	]]
	client:Notify("Taken off the list. It comes back when the map reloads.")

	return true
end

function TOOL.BuildCPanel(panel)
	panel:AddControl("Header", {
		Description = "Every map teleport is drawn as an orange box while "
			.. "this tool is out. Click one to delete it for good."
	})

	panel:Help("Left click deletes. Reload undoes the last one you deleted "
		.. "this session. Anything on the list below can be restored whenever "
		.. "it was deleted - it reappears on the next map load.")

	ix.doors.BuildDeletedList(panel, true)
end
