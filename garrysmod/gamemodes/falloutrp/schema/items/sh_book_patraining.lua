--[[
	The Power Armor Training Manual.

	Phoenix's rule, to the letter: power armour has to be LEARNED, from this,
	and a permanent kill takes the knowledge with the life - `sv_pk.lua`
	clears `paTraining` and takes the suit off the body. Salvaged frames
	(`ITEM.isSalvagedPA`) are the exception; see `ix.armor.Equip`.

	READ ONCE, GONE. The manual is consumed by reading it, so a faction that
	wants its people in suits hands out manuals, which is a thing to trade
	and a thing to lose.

	IN `items/` ROOT rather than a folder, for the reason `sh_playerhead.lua`
	gives: `ix.item.LoadFromDir` gives anything in `items/<folder>/` the base
	`base_<folder>`, and there is no base for a book.
]]

ITEM.name = "Power Armor Training Manual"
ITEM.description = "A manual that teaches the reader how to move in, power "
	.. "up and fight from a suit of power armour. Read once, remembered "
	.. "until you die for good."
ITEM.model = "models/models/fallout/bookpugilism01.mdl"
ITEM.category = "Junk"
ITEM.width = 1
ITEM.height = 1
ITEM.price = 10

--- The marker other systems key off.
ITEM.isPATraining = true

ITEM.functions.Read = {
	name = "Read",
	icon = "icon16/book_open.png",

	OnRun = function(item)
		local client = item.player
		local character = IsValid(client) and client:GetCharacter()

		if (not character) then return false end

		if (character:GetData("paTraining", false)) then
			client:Notify("You already know how to use power armour.")

			return false
		end

		character:SetData("paTraining", true)

		client:Notify("You have learned how to use power armour.")
		client:EmitSound("phoenix/ui/nv/ui_items_generic_up_01.mp3", 60)

		ix.log.Add(client, "paTraining")

		--- Consumed.
		return true
	end,

	OnCanRun = function(item)
		return not IsValid(item.entity)
	end
}

if (ix.log and ix.log.AddType) then
	ix.log.AddType("paTraining", function(client)
		return string.format("%s read a Power Armor Training Manual.",
			client:Name())
	end, FLAG_NORMAL)
end
