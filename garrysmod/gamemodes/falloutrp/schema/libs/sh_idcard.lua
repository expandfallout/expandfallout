--[[
	Worn identification: which cards a player has on, and the icons over
	their head.

	The items are `items/base/sh_idcard.lua` and `items/idcard/`. This is the
	part that is not an item: the rule that one citizenship and one religion
	may be worn, the net var that carries the worn set to every client, and
	the drawing.

	THE WORN SET IS REBUILT FROM THE INVENTORY, never edited in place. A card
	is worn when its `equipped` data is true and it is in the character's
	bag; `Refresh` reads that and writes the net var. Dropping, giving away
	or losing a card therefore takes it off through the same path as
	unequipping it, and a character loading gets exactly what they had.
]]

ix.idcard = ix.idcard or {}

--- The cards a character has on, `[uniqueID] = item`.
function ix.idcard.Worn(character)
	local worn = {}
	local inventory = character and character:GetInventory()

	if (not inventory) then return worn end

	for _, item in pairs(inventory:GetItems()) do
		if (item.isIDCard and item:GetData("equipped", false)) then
			worn[item.uniqueID] = item
		end
	end

	return worn
end

if (SERVER) then
	--- Write the worn set onto the player, for the icons.
	function ix.idcard.Refresh(client)
		if (not IsValid(client)) then return end

		local character = client:GetCharacter()
		local set = {}

		for uniqueID in pairs(ix.idcard.Worn(character)) do
			set[uniqueID] = true
		end

		client:SetNetVar("idCards", set)
	end

	--[[
		One of each kind. A second citizenship, or a second religion, is
		refused with a reason rather than swapped in, so putting one on is
		never silently taking another off.
	]]
	function ix.idcard.Equip(client, item)
		local character = IsValid(client) and client:GetCharacter()

		if (not character or not item or not item.isIDCard) then
			return false, "That is not something you can wear."
		end

		if (item:GetData("equipped", false)) then
			return false, "You are already wearing that."
		end

		for _, worn in pairs(ix.idcard.Worn(character)) do
			if (worn.cardType == item.cardType) then
				return false, string.format("You already wear %s. Take it off first.",
					item.cardType == "religion" and "a religious token"
					or "a citizenship")
			end
		end

		item:SetData("equipped", true)
		ix.idcard.Refresh(client)

		return true
	end

	hook.Add("PlayerLoadedCharacter", "ixIDCard", function(client)
		ix.idcard.Refresh(client)
	end)

	return
end

--------------------------------------------------------------------------------
-- Over their head
--------------------------------------------------------------------------------

--[[
	Phoenix drew the icons in their character-info overlay, 64 pixels a
	piece, a little above the name. This does the same over the head of
	anybody in sight: within `RANGE`, on screen, with nothing solid between
	you and them. A citizenship is drawn before a religion.
]]
local RANGE = 1200
local SIZE = 44
local cache = {}

local function Icon(uniqueID)
	local item = ix.item.list[uniqueID]

	if (not item or not item.idIcon) then return nil end

	local material = cache[uniqueID]

	if (material == nil) then
		material = Material(item.idIcon, "smooth")
		cache[uniqueID] = material:IsError() and false or material
	end

	return material or nil
end

local function Icons(worn)
	local ids = {}

	for uniqueID in pairs(worn) do ids[#ids + 1] = uniqueID end

	table.sort(ids, function(a, b)
		local ta = ix.item.list[a] and ix.item.list[a].cardType or ""
		local tb = ix.item.list[b] and ix.item.list[b].cardType or ""

		if (ta ~= tb) then return ta < tb end

		return a < b
	end)

	local out = {}

	for _, uniqueID in ipairs(ids) do
		local material = Icon(uniqueID)

		if (material) then out[#out + 1] = material end
	end

	return out
end

hook.Add("HUDPaint", "ixIDCard", function()
	local me = LocalPlayer()

	if (not IsValid(me)) then return end

	local eye = me:EyePos()
	local scale = ScrH() / 1080

	for _, client in player.Iterator() do
		if (client == me or client:IsDormant() or not client:Alive()) then
			continue
		end

		local worn = client:GetNetVar("idCards")

		if (not istable(worn) or next(worn) == nil) then continue end

		local head = client:GetPos() + Vector(0, 0, client:OBBMaxs().z + 8)
		local distance = eye:Distance(head)

		if (distance > RANGE) then continue end

		local screen = head:ToScreen()

		if (not screen.visible) then continue end

		local trace = util.TraceLine({
			start = eye,
			endpos = head,
			filter = {me, client},
			mask = MASK_SOLID_BRUSHONLY
		})

		if (trace.Hit) then continue end

		local materials = Icons(worn)

		if (#materials == 0) then continue end

		local size = math.Round(SIZE * scale
			* math.Clamp(1.15 - distance / RANGE, 0.5, 1))
		local gap = math.Round(size * 0.1)
		local total = #materials * size + (#materials - 1) * gap
		local x = screen.x - total / 2
		local y = screen.y - size - math.Round(40 * scale)
		local alpha = math.Clamp(255 * (1.3 - distance / RANGE), 90, 255)

		surface.SetDrawColor(255, 255, 255, alpha)

		for _, material in ipairs(materials) do
			surface.SetMaterial(material)
			surface.DrawTexturedRect(x, y, size, size)

			x = x + size + gap
		end
	end
end)
