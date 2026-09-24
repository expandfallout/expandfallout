--[[
	Planting a charge, and the list of what may not be blown.

	The blacklist is per-map data rather than a table in the source, because it
	IS per-map: Phoenix's is four brush model indices (`*289`, `*105`...) and a
	brush index is a different door on a different map. `fo_breach_block` names
	the door you are looking at, and `ix.data` keeps it with everything else.
]]

if (not SERVER) then return end

util.AddNetworkString("ixBreachList")

local KEY = "breachblacklist"

function ix.breach.Save()
	--[[
		Saved as a LIST rather than as the lookup it is used as. `ix.data` goes
		through JSON, which has no idea what to do with `["*289"] = true` as a
		key when it comes back - see the doors, which learned this the hard way.
	]]
	local list = {}

	for model in pairs(ix.breach.blacklist) do
		list[#list + 1] = model
	end

	ix.data.Set(KEY, list)
end

function ix.breach.Load()
	ix.breach.blacklist = {}

	for _, model in ipairs(ix.data.Get(KEY, {}) or {}) do
		if (isstring(model)) then ix.breach.blacklist[model] = true end
	end
end

hook.Add("LoadData", "ixBreach", ix.breach.Load)
hook.Add("SaveData", "ixBreach", ix.breach.Save)

--[[
	Tell a client what may not be blown.

	Only so that the charge's Use button can be greyed out honestly; the server
	checks the same list again when the charge is actually planted, and that is
	the check that decides.
]]
function ix.breach.Send(client)
	local list = {}

	for model in pairs(ix.breach.blacklist) do
		list[#list + 1] = model
	end

	net.Start("ixBreachList")
		net.WriteUInt(#list, 16)

		for _, model in ipairs(list) do
			net.WriteString(model)
		end
	net.Send(client)
end

hook.Add("PlayerInitialSpawn", "ixBreach", function(client)
	timer.Simple(5, function()
		if (IsValid(client)) then ix.breach.Send(client) end
	end)
end)

--[[
	Stick a charge to something.

	The angle maths is Phoenix's: take the surface normal as an angle, rotate
	it ninety degrees about its own right axis, and the box lies flat against
	the door rather than sticking out of it edge-first.
]]
function ix.breach.Plant(client, entity, trace)
	if (not ix.breach.CanBreach(client, entity)) then return false end

	local angles = trace.HitNormal:Angle()

	angles:RotateAroundAxis(Angle(angles[1], angles[2], angles[3]):Right(), 90)

	local charge = ents.Create("ix_breachcharge")

	if (not IsValid(charge)) then return false end

	charge:SetPos(trace.HitPos + trace.HitNormal * 3)
	charge:SetAngles(angles)
	charge:Spawn()
	charge:Activate()

	--[[
		PARENTED, so that a charge on a door that opens goes with it. A charge
		left hanging in the air where the door used to be is the sort of thing
		people build a whole exploit around.
	]]
	charge:SetParent(entity)

	--[[
		`SetBreachTarget`, NOT `SetTarget`.

		This was written as `SetTarget` and threw "attempt to call method
		'SetTarget' (a nil value)" on every charge planted. It looked harmless
		because the charge still spawned and still went off - `Explode` finds
		doors by sphere and the two fields this sets are only the fallback and
		the log - but the throw aborted the rest of this function, so `Plant`
		returned nothing, the ITEM saw a failure and DID NOT CONSUME ITSELF.
		One charge, blown as many times as you like.

		The name is deliberate: `Entity:SetTarget` is an engine method on NPCs,
		so a scripted entity that defines its own is one refactor away from a
		collision nobody would look for.
	]]
	charge:SetBreachTarget(entity, client)

	ix.log.Add(client, "breachPlant", entity:GetClass())

	return true
end

concommand.Add("fo_breach_block", function(client)
	if (IsValid(client) and not ix.admin.Can(client, "dev.terminal")) then
		return
	end

	local entity = client:GetEyeTrace().Entity

	if (not IsValid(entity)) then
		client:ChatPrint("[Breach] Look at a door.")

		return
	end

	local model = entity:GetModel()

	if (not model or model == "") then
		client:ChatPrint("[Breach] That has no model to remember it by.")

		return
	end

	if (ix.breach.blacklist[model]) then
		ix.breach.blacklist[model] = nil

		client:ChatPrint("[Breach] " .. model .. " can be blown again.")
	else
		ix.breach.blacklist[model] = true

		client:ChatPrint("[Breach] " .. model .. " can no longer be blown.")
	end

	ix.breach.Save()

	for _, other in ipairs(player.GetAll()) do
		ix.breach.Send(other)
	end
end)

ix.log.AddType("breachPlant", function(client, class)
	return string.format("%s planted a breaching charge on a %s.",
		client:Name(), class)
end, FLAG_WARNING)

ix.log.AddType("breachDoor", function(client, class)
	return string.format("%s blew open a %s.", client:Name(), class)
end, FLAG_DANGER)
