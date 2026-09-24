--[[
	Branding a weapon, server side.

	See `sh_brand.lua` for what a brand is and who may make one. This is the
	half that takes the caps and writes the mark, and it re-asks every question
	the menu asked: the action arrives as a net message and a menu entry that
	was not drawn is not a permission (gotcha 15).
]]

if (not SERVER) then return end

ix.brand = ix.brand or {}

--[[
	Brand it. Returns `true`, or `false, reason` - and tells the player either
	way, because every caller is a click somebody just made.

	THE MONEY COMES OUT LAST, after the mark is written. Nothing between the
	two can fail, but the order is free and the alternative - charge, then
	discover the weapon is gone - is the one that costs somebody 500 caps.
]]
function ix.brand.Apply(client, item)
	if (not IsValid(client) or not item) then return false end

	local allowed, reason = ix.brand.CanBrand(client, item)

	if (not allowed) then
		client:Notify(reason)

		return false, reason
	end

	local character = client:GetCharacter()
	local faction = ix.faction.indices[character:GetFaction()]
	local cost = ix.brand.Cost()

	--[[
		A serial nobody else has.

		Fifteen characters out of a thirty-one symbol alphabet is more
		combinations than this server will ever have items, so a collision is
		not a real risk - but the check is one walk of the loaded instances and
		it turns "astronomically unlikely" into "cannot happen", which is worth
		having for the one number people quote at each other in tickets.
	]]
	local id

	for _ = 1, 10 do
		id = ix.brand.Generate()

		local taken = false

		for _, other in pairs(ix.item.instances) do
			if (ix.brand.Get(other) == id) then
				taken = true

				break
			end
		end

		if (not taken) then break end
	end

	item:SetData("branded", true)
	item:SetData("brandedTo", faction.name)
	item:SetData("brandID", id)

	--[[
		WHO did it, kept on the item and never shown on it. The mark belongs to
		the faction; the name is for the log and for an admin reading a report
		about a rifle six weeks later.
	]]
	item:SetData("brandedBy", character:GetName())

	if (cost > 0) then
		character:SetMoney(math.max(character:GetMoney() - cost, 0))
	end

	client:Notify(string.format("Branded to %s. Serial %s.", faction.name, id))
	client:EmitSound("phoenix/ui/nv/itm_bottle_up_02.mp3", 60, 90, 0.5)

	ix.log.Add(client, "weaponBrand", item.name or item.uniqueID, faction.name,
		id, cost)

	return true
end

--[[
	LOGGED WITH THE SERIAL IN IT, which is the whole reason the serial exists.

	A report saying "somebody branded a rifle" is worth nothing; one naming the
	weapon, the faction, the serial and what it cost can be matched against the
	object somebody is holding.
]]
ix.log.AddType("weaponBrand", function(client, name, faction, id, cost)
	return string.format("%s branded a %s to %s - serial %s, %s.",
		client:Name(), name, faction, id, ix.currency.Get(cost or 0))
end, FLAG_NORMAL)
