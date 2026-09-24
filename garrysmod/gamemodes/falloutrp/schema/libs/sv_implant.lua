--[[
	Implants, server side: putting one in, taking one out, and keeping them on.

	See `sh_implant.lua` for what an implant is.

	THE BONUSES ARE BUFFS WITH NO CLOCK. `ix.buff.Add(client, stat, value, 0,
	id)` is a buff that lasts until something removes it - which is exactly
	what an implant is - and it means the SPECIAL screen, the damage hook and
	the health cap all read implants without knowing they exist.

	They are re-applied on spawn rather than remembered on the player, because
	buffs live on the PLAYER and a player who has just respawned is a fresh
	one. That is also what makes them survive death: nothing removes them, so
	the next spawn puts them straight back.
]]

if (not SERVER) then return end

util.AddNetworkString("ixImplantList")
util.AddNetworkString("ixImplantExtract")

--- The buff id one implant uses, so re-applying cannot double it up.
local function BuffID(id, code)
	return string.format("implant_%s_%s", id, code)
end

--[[
	Put every implant's bonuses onto a player.

	Called on spawn and whenever the set changes. `ix.buff.Add` with the same
	id replaces rather than stacks, so calling this twice is not two implants.
]]
function ix.implants.Apply(client)
	if (not IsValid(client)) then return end

	local character = client:GetCharacter()

	if (not character) then return end

	for id in pairs(ix.implants.Of(character)) do
		local implant = ix.implants.Get(id)

		if (not implant) then continue end

		for code, amount in pairs(implant.buffs or {}) do
			ix.buff.Add(client, code, amount, 0, BuffID(id, code),
				implant.name)
		end
	end
end

--- Take one implant's bonuses off.
local function Strip(client, id)
	local implant = ix.implants.Get(id)

	if (not IsValid(client) or not implant) then return end

	for code in pairs(implant.buffs or {}) do
		ix.buff.Remove(client, BuffID(id, code))
	end
end

--[[
	Give a character an implant. Returns true, or false and a reason.
]]
function ix.implants.Add(character, id, client)
	local can, reason = ix.implants.CanTake(character, id)

	if (not can) then return false, reason end

	local stored = ix.implants.Of(character)

	stored[id] = true

	character:SetData("implants", stored)

	local owner = character:GetPlayer()

	if (IsValid(owner)) then ix.implants.Apply(owner) end

	local implant = ix.implants.Get(id)

	if (implant.OnImplanted) then
		implant.OnImplanted(character, client)
	end

	ix.log.Add(client, "implantAdd", character:GetName(), implant.name)

	return true
end

--- Take one out. Returns whether there was one.
function ix.implants.Take(character, id, client)
	local stored = ix.implants.Of(character)

	if (not stored[id]) then return false end

	stored[id] = nil

	character:SetData("implants", next(stored) and stored or nil)

	local owner = character:GetPlayer()

	if (IsValid(owner)) then Strip(owner, id) end

	local implant = ix.implants.Get(id)

	if (implant and implant.OnExtracted) then
		implant.OnExtracted(character, client)
	end

	ix.log.Add(client, "implantTake", character:GetName(),
		implant and implant.name or id)

	return true
end

--[[
	SPAWN PUTS THEM BACK, which is what makes them survive death.

	Nothing removes an implant when somebody dies - `sv_pk.lua` does it when a
	character is permanently killed, and the extractor does it when another
	character digs it out. Ordinary death is not either of those.
]]
hook.Add("PlayerSpawn", "ixImplants", function(client)
	timer.Simple(0.2, function()
		if (IsValid(client)) then ix.implants.Apply(client) end
	end)
end)

hook.Add("PlayerLoadedCharacter", "ixImplants", function(client)
	timer.Simple(1, function()
		if (IsValid(client)) then ix.implants.Apply(client) end
	end)
end)

--[[
	A PERMANENT KILL TAKES THEM WITH IT. The character is gone; what was inside
	them goes too, and the next character starts empty.
]]
hook.Add("OnPlayerPK", "ixImplants", function(client)
	if (not IsValid(client)) then return end

	local character = client:GetCharacter()

	if (not character) then return end

	for id in pairs(ix.implants.Of(character)) do
		Strip(client, id)
	end

	character:SetData("implants", nil)
end)

--------------------------------------------------------------------------------
-- The extractor
--------------------------------------------------------------------------------

--[[
	Show somebody the implants in the character they are looking at.

	The LIST is sent rather than shown, because the window is the client's -
	and the list is short and public to whoever is holding a surgical tool
	against you.
]]
function ix.implants.SendList(client, target)
	local character = target:GetCharacter()

	if (not character) then return false end

	local stored = ix.implants.Of(character)

	if (not next(stored)) then
		client:Notify("They have no implants.")

		return false
	end

	net.Start("ixImplantList")
		net.WriteEntity(target)
		net.WriteUInt(table.Count(stored), 8)

		for id in pairs(stored) do
			net.WriteString(id)
		end
	net.Send(client)

	return true
end

--[[
	"Take that one out."

	EVERYTHING IS CHECKED AGAIN. The window sent an id and a target, and both
	are claims: the distance is measured here, the implant is looked up here,
	and the five seconds of standing still are spent here.
]]
net.Receive("ixImplantExtract", function(length, client)
	local target = net.ReadEntity()
	local id = net.ReadString()

	if (not IsValid(target) or not target:IsPlayer()) then return end

	local range = ix.config.Get("implantRange", 96)

	if (client:GetPos():DistToSqr(target:GetPos()) > range * range) then
		client:Notify("They are too far away.")

		return
	end

	local character = target:GetCharacter()
	local implant = ix.implants.Get(id)

	if (not character or not implant) then return end
	if (not ix.implants.Has(character, id)) then return end

	--[[
		THE VOLATILE ONE. A C.I.T implant taken out by anybody but C.I.T kills
		the patient, which is Phoenix's rule and the reason a synth is careful
		about who they let operate.
	]]
	if (implant.volatile and implant.faction) then
		local mine = client:GetCharacter()
		local faction = mine and ix.faction.indices[mine:GetFaction()]

		if (not faction or faction.uniqueID ~= implant.faction) then
			client:Notify("The implant glows red hot as you cut into it.")
			target:Notify("Something inside you begins to shriek.")

			timer.Simple(8, function()
				if (not IsValid(target)) then return end

				local explosion = ents.Create("env_explosion")

				explosion:SetPos(target:GetPos())
				explosion:SetOwner(target)
				explosion:Spawn()
				explosion:SetKeyValue("iMagnitude", "100")
				explosion:Fire("Explode", 0, 0)

				target:Kill()
			end)

			ix.log.Add(client, "implantVolatile", target:Name())

			return
		end
	end

	local time = ix.config.Get("implantTime", 5)

	client:SetAction("@implanting", time)
	client:DoStaredAction(target, function()
		if (not IsValid(client) or not IsValid(target)) then return end

		local still = target:GetCharacter()

		if (not still or not ix.implants.Has(still, id)) then return end

		ix.implants.Take(still, id, client)

		--[[
			THE IMPLANT COMES OUT AS AN ITEM, so it can go back into somebody
			else. Extraction is surgery, not destruction - and an implant that
			vanished on removal would make the extractor a weapon rather than a
			tool.
		]]
		local unique = "implant_" .. id

		if (ix.item.list[unique]) then
			local inventory = client:GetCharacter():GetInventory()

			if (not inventory or not inventory:Add(unique)) then
				ix.item.Spawn(unique, client:GetItemDropPos())
			end
		end

		client:Notify(string.format("You extract the %s.", implant.name))
		target:Notify(string.format("The %s is removed.", implant.name))
	end, time, function()
		if (IsValid(client)) then client:SetAction() end
	end, ix.config.Get("implantRange", 96) * 2)
end)

--[[
	`/implantself <id>` - FOR TESTING, and it says so.

	The whole design of implants is that somebody else fits them, so this is a
	deliberate hole in that rule and it is admin-only for exactly that reason.
	Without it, testing what a Luck implant does means finding a second person.

	`/implantself` with nothing lists the ids, because nobody remembers
	`cit_implant`.
]]
ix.command.Add("ImplantSelf", {
	description = "Put an implant in yourself. Testing only - normally "
		.. "somebody else has to do it.",
	adminOnly = true,
	arguments = {bit.bor(ix.type.string, ix.type.optional)},

	OnRun = function(self, client, id)
		local character = client:GetCharacter()

		if (not character) then return "@noChar" end

		if (not id or id == "") then
			local names = {}

			for key in SortedPairs(ix.implants.list) do
				names[#names + 1] = key
			end

			return "Implants: " .. table.concat(names, ", ")
		end

		id = string.lower(id)

		--- A partial name works, since these are typed rather than clicked.
		if (not ix.implants.Get(id)) then
			for key, implant in pairs(ix.implants.list) do
				if (ix.util.StringMatches(key, id)
				or ix.util.StringMatches(implant.name, id)) then
					id = key

					break
				end
			end
		end

		local implant = ix.implants.Get(id)

		if (not implant) then return "No implant by that name." end

		local added, reason = ix.implants.Add(character, id, client)

		if (not added) then return reason end

		return string.format("Implanted yourself with %s.", implant.name)
	end
})

--[[
	And the way back out, because testing an implant means taking it out again
	and the extractor needs a second person as well.
]]
ix.command.Add("ImplantSelfRemove", {
	description = "Take one of your own implants out. Testing only.",
	adminOnly = true,
	arguments = {ix.type.string},

	OnRun = function(self, client, id)
		local character = client:GetCharacter()

		if (not character) then return "@noChar" end

		id = string.lower(id)

		if (not ix.implants.Has(character, id)) then
			for key in pairs(ix.implants.Of(character)) do
				if (ix.util.StringMatches(key, id)) then
					id = key

					break
				end
			end
		end

		if (not ix.implants.Take(character, id, client)) then
			return "You do not have that implant."
		end

		return "Removed."
	end
})

ix.log.AddType("implantAdd", function(client, who, implant)
	return string.format("%s implanted %s with %s.",
		IsValid(client) and client:Name() or "somebody", who, implant)
end, FLAG_WARNING)

ix.log.AddType("implantTake", function(client, who, implant)
	return string.format("%s extracted %s from %s.",
		IsValid(client) and client:Name() or "somebody", implant, who)
end, FLAG_WARNING)

ix.log.AddType("implantVolatile", function(client, who)
	return string.format("%s set off the C.I.T implant in %s.", client:Name(),
		who)
end, FLAG_DANGER)
