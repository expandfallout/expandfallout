--[[
	C.I.T Implant.

	The item is only how it gets there - the bonuses, the rules and the
	description all live in `ix.implants.list` under `cit_implant`, which is what
	makes them editable in `/liveedit`. See `items/base/sh_implant.lua`.

	NO `ITEM.base` LINE. Helix takes the base from the FOLDER - `LoadFromDir`
	loads `items/implant/*` with `base_implant` - so writing one here does not
	add a base, it REPLACES the right one with whatever was typed:

	    [Helix] Item 'implant_agility' has a non-existent base! (implant)
]]

ITEM.name = "C.I.T Implant"
ITEM.implant = "cit_implant"

--[[
	C.I.T ONLY, in both directions.

	Anybody else who tries to put one in is burned for it, and anybody else who
	tries to take one out sets it off - `sv_implant.lua` owns the second half,
	because a thing that kills the patient is not a decision an item file
	should be making on its own.

	`ix.implants.list.cit_implant` carries `faction` and `volatile`; this is
	the half that happens with the needle in somebody's hand.
]]
ITEM.price = 12000

local implant = ix.implants.Get("cit_implant")

if (implant) then
	function implant.CanImplant(client, target)
		local character = client:GetCharacter()
		local faction = character
			and ix.faction.indices[character:GetFaction()]

		if (faction and faction.uniqueID == implant.faction) then
			return true
		end

		--[[
			IT BURNS THEM AND IS LOST. Phoenix take 25 damage and destroy the
			implant, which is the part that makes it a rule rather than a
			refusal - trying costs you the implant.
		]]
		client:TakeDamage(25, client, client)

		return false, "The implant glows red hot and sears your hands."
	end

	--[[
		An access code, written onto the character. It is what the C.I.T
		terminals will ask for, and it is generated here so the code and the
		implant cannot exist without each other.
	]]
	function implant.OnImplanted(character, client)
		local code = ""

		for _ = 1, 8 do
			code = code .. string.format("%X", math.random(0, 15))
		end

		character:SetData("citAccessCode", code)

		local owner = character:GetPlayer()

		if (IsValid(owner)) then
			owner:Notify("You are now linked to C.I.T systems.")
		end

		if (IsValid(client)) then
			client:Notify("C.I.T access code: " .. code)
		end
	end

	function implant.OnExtracted(character)
		character:SetData("citAccessCode", nil)

		local owner = character:GetPlayer()

		if (IsValid(owner)) then
			owner:Notify("Your C.I.T access has been revoked.")
		end
	end
end
