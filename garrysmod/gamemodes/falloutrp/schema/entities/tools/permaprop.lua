--[[
	The permanent prop tool.

	Point at a prop and left-click to make it survive restarts; right-click to
	stop it. The same two actions the familiar PermaProps addon offers, because
	that is what people already expect from a tool called this.

	    left click    make it persistent
	    right click   stop it being persistent
	    reload        remove it, and its saved copy with it

	Reload exists because removing a permanent prop is otherwise awkward: the
	physgun deletes the entity but not the saved record, so it returns on the
	next restart looking like the delete failed.

	SUPERADMIN ONLY, checked server-side in all three actions. This writes
	world content that outlives the session.

	Helix's tool base is missing most of what the toolgun calls. It is completed
	once, on the metatable, in `libs/sh_toolfix.lua` - so nothing is needed
	here and every tool benefits, not just this one.
]]

TOOL.Category = "Fallout RP"
TOOL.Name = "#tool.permaprop.name"

TOOL.ClientConVar = {}

--[[
	Called again after the convar table is declared: Helix runs
	`CreateConVars()` BEFORE including this file, so anything declared here
	would otherwise never be created. See `24-devtools.md`.
]]
TOOL:CreateConVars()

if (CLIENT) then
	language.Add("tool.permaprop.name", "Permanent Props")
	language.Add("tool.permaprop.desc", "Make props survive restarts.")
	language.Add("tool.permaprop.0",
		"Left: make permanent   Right: make temporary   Reload: remove it")
end

local function CanUse(client)
	return IsValid(client) and client:IsSuperAdmin()
end

function TOOL:LeftClick(trace)
	if (CLIENT) then return true end

	local client = self:GetOwner()

	if (not CanUse(client)) then return false end

	local entity = trace.Entity

	if (not IsValid(entity)) then return false end

	local ok, reason = ix.permaprop.Add(entity)

	if (not ok) then
		client:Notify(reason)
		return false
	end

	client:Notify("Made permanent: " .. entity:GetClass())
	ix.log.Add(client, "permaPropAdd", entity:GetClass())

	return true
end

function TOOL:RightClick(trace)
	if (CLIENT) then return true end

	local client = self:GetOwner()

	if (not CanUse(client)) then return false end

	local entity = trace.Entity

	if (not IsValid(entity)) then return false end

	local ok, reason = ix.permaprop.Remove(entity)

	if (not ok) then
		client:Notify(reason)
		return false
	end

	client:Notify("No longer permanent: " .. entity:GetClass())
	ix.log.Add(client, "permaPropRemove", entity:GetClass())

	return true
end

--[[
	Remove the prop AND its record.

	Order matters: unmarked first, so the save that follows no longer lists it,
	and only then removed. Removing first would leave `ixPerma` on a dead
	entity that the save loop skips anyway - the same result, but it relies on
	the loop's validity check rather than saying what is meant.
]]
function TOOL:Reload(trace)
	if (CLIENT) then return true end

	local client = self:GetOwner()

	if (not CanUse(client)) then return false end

	local entity = trace.Entity

	if (not IsValid(entity) or entity:IsPlayer()) then return false end

	local class = entity:GetClass()

	--[[
		A storage container is somebody's stored items. Reload deletes what it
		is pointed at, and doing that to a container - silently, from across
		the room, with the same key that tidies up a crate - is not a mistake
		worth making possible. Unmark it and leave it standing; Helix's own
		removal is the way to delete one.
	]]
	if (ix.permaprop.IsContainer(entity)) then
		local ok, reason = ix.permaprop.Remove(entity)

		client:Notify(ok and ("No longer permanent: " .. class)
			or ("Containers are not removed by this tool. " .. (reason or "")))

		return ok
	end

	if (entity.ixPerma) then
		ix.permaprop.Remove(entity)
	end

	entity:Remove()

	client:Notify("Removed: " .. class)
	ix.log.Add(client, "permaPropRemove", class)

	return true
end

function TOOL.BuildCPanel(panel)
	panel:Help("Make props survive server restarts. Superadmin only.")
	panel:Help("Left: make permanent.  Right: make temporary.  " ..
		"Reload: remove it and its saved copy.")
	panel:Help("Lootables are excluded - they persist through their own system.")
	panel:Help("Helix storage containers ARE supported: they are temporary " ..
		"until marked here, and reload only unmarks one rather than deleting " ..
		"what is inside it.")
	panel:Button("List permanent props in console", "fo_permaprops")
end

if (SERVER) then
	ix.log.AddType("permaPropAdd", function(client, class)
		return string.format("%s made a %s permanent.", client:Name(), class)
	end, FLAG_NORMAL)

	ix.log.AddType("permaPropRemove", function(client, class)
		return string.format("%s removed a permanent %s.", client:Name(), class)
	end, FLAG_DANGER)
end
