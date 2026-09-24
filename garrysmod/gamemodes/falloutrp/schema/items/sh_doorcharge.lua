--[[
	The Doorbuster charge.

	Phoenix's item, with their name and model. Theirs builds the entity
	inside the item's `onRun`; here that is `ix.breach.Plant`, so the rules
	about what may be blown live in one place and the item only has to find
	something to stick to.

	IT IS CONSUMED ON PLANTING, not on detonation. The charge has left your
	hands either way, and Phoenix's returns true - which takes the item - at
	exactly this point.
]]

ITEM.name = "Doorbuster Charge"
ITEM.description = "A breaching charge that can blow a door open. This item "
	.. "has rules of use."
ITEM.model = "models/props_c17/consolebox05a.mdl"
ITEM.category = "Junk"

ITEM.width = 1
ITEM.height = 1

ITEM.reach = 96

--[[
	What the item is looking at, or nothing.

	Shared, because `OnCanRun` runs on the client to decide whether the button
	is drawn and on the server to decide whether it does anything. The client's
	copy of the blacklist is sent by `sv_breach.lua`.
]]
function ITEM:Target()
	local client = self.player

	if (not IsValid(client)) then return end

	local trace = util.TraceLine({
		start = client:GetShootPos(),
		endpos = client:GetShootPos() + client:GetAimVector() * self.reach,
		filter = client
	})

	local entity = trace.Entity

	if (not IsValid(entity)) then return end
	if (not ix.breach.CanBreach(client, entity)) then return end

	return entity, trace
end

ITEM.functions.Charge = {
	name = "Charge",
	icon = "icon16/brick.png",

	OnRun = function(item)
		local client = item.player
		local entity, trace = item:Target()

		if (not entity) then
			client:Notify("There is nothing here to blow open.")

			return false
		end

		if (not ix.breach.Plant(client, entity, trace)) then
			client:Notify("The charge will not stick to that.")

			return false
		end

		ix.chat.Send(client, "me", "sticks a breaching charge to the door.")

		return true
	end,

	OnCanRun = function(item)
		local client = item.player

		if (IsValid(item.entity) or not IsValid(client)) then return false end
		if (not client:Alive() or client:IsRestricted()) then return false end

		return item:Target() ~= nil
	end
}
