--[[
	Cuffs.

	The permanent restraint. Phoenix's cuffs are a separate paid addon and
	none of its code is here; what their hold-E menu shows of it is uncuff,
	drag, gag and blind, and what it does to the person is the same restraint a
	zip tie does. So this is the zip tie with three differences, all of them in
	`ix.restrain.kinds.cuffs`:

	    they take longer to put on
	    they are NOT consumed - a cuff is a thing, not a supply
	    only somebody holding a pair can take a pair off

	The last one is what makes them worth carrying. A zip tie can be cut off by
	the first person who walks past; cuffs need somebody who came prepared.
]]

ITEM.name = "Cuffs"
ITEM.description = "A pair of steel cuffs. They will not come off "
	.. "without another pair. This item has rules of use."
ITEM.model = "models/mosi/fallout4/props/junk/handcuffs.mdl"
ITEM.category = "Junk"

ITEM.width = 1
ITEM.height = 1

ITEM.reach = 96

ITEM.functions.Use = {
	name = "Use",
	icon = "icon16/lock.png",

	OnRun = function(item)
		local client = item.player

		if (not IsValid(client)) then return false end

		local trace = util.TraceLine({
			start = client:GetShootPos(),
			endpos = client:GetShootPos() + client:GetAimVector() * item.reach,
			filter = client
		})

		local target = trace.Entity

		if (not IsValid(target) or not target:IsPlayer()) then
			client:Notify("You need to be looking at somebody.")

			return false
		end

		local allowed, reason = ix.interact.CanReach(client, target)

		if (not allowed) then
			if (reason) then client:Notify(reason) end

			return false
		end

		if (ix.restrain.Is(target)) then
			client:Notify("They are already restrained.")

			return false
		end

		if (ix.restrain.Is(client)) then
			client:Notify("Your own hands are tied.")

			return false
		end

		ix.restrain.Begin(client, target, "cuffs")

		return false
	end,

	OnCanRun = function(item)
		local client = item.player

		if (IsValid(item.entity) or not IsValid(client)) then return false end
		if (not client:Alive() or ix.restrain.Is(client)) then return false end

		return true
	end
}

function ITEM:CanTransfer(oldInventory, newInventory)
	local client = self:GetOwner()

	if (IsValid(client) and client.ixRestrainBusy) then return false end

	return true
end
