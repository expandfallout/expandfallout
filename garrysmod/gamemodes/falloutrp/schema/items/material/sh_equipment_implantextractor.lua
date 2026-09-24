--[[
	The Implant Extractor.

	A surgical tool that is used ON somebody: it asks the server what is inside
	the person you are looking at, and the server answers with a list you pick
	from. The taking-out is `sv_implant.lua`'s - five seconds of standing still,
	the same as putting one in.

	IT IS NOT CONSUMED. A tool is a thing you own; the implants are what change
	hands.
]]

ITEM.name = "Implant Extractor"
ITEM.description = "A surgical tool for removing cybernetic implants. Used on "
	.. "somebody else - point it at them and use it."
ITEM.model = "models/mosi/fallout4/props/junk/tritool.mdl"
ITEM.category = "Medical"
ITEM.width = 1
ITEM.height = 1
ITEM.price = 2500

--- Who you are looking at, if it is a person within arm's reach.
function ITEM:GetTarget(client)
	if (not IsValid(client) or not client:Alive()) then return nil end

	local range = ix.config.Get("implantRange", 96)

	local trace = util.TraceLine({
		start = client:GetShootPos(),
		endpos = client:GetShootPos() + client:GetAimVector() * range,
		filter = client
	})

	local entity = trace.Entity

	if (not IsValid(entity) or not entity:IsPlayer()) then return nil end

	return entity
end

ITEM.functions.Use = {
	name = "Extract",
	icon = "icon16/user_delete.png",

	OnCanRun = function(item)
		local client = item.player

		return IsValid(client) and item:GetTarget(client) ~= nil
	end,

	OnRun = function(item)
		local client = item.player
		local target = item:GetTarget(client)

		if (IsValid(target)) then
			ix.implants.SendList(client, target)
		end

		--- Never consumed. See the note at the top.
		return false
	end
}
