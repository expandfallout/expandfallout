--[[
	A severed head.

	Two things make one, and they name it differently:

	    a body                 "NCR - Trooper Head"   - unmarked
	    a PERMANENTLY KILLED   "Vault Dweller's Head"     - named

	Both come off a corpse, through `ix.corpse.TakeHead`. The difference is
	what the body says about itself: a permanent kill leaves one carrying a
	name.

	ONE ITEM, MANY HEADS. The uniqueID is `playerhead` for every one of them
	and the name comes from the INSTANCE's data - so each head is a distinct
	thing carrying a distinct name without needing an item registered per
	character, which is not something Helix can do anyway: items are registered
	once at load and characters are made afterwards.

	IN `items/` ROOT rather than a folder, for the reason the fusion core
	gives: `ix.item.LoadFromDir` gives anything in `items/<folder>/` the base
	`base_<folder>`, so a folder would demand a base that does not exist.
]]

ITEM.name = "Head"
ITEM.description = "Somebody's head. It is not going back on."
ITEM.model = "models/headspack/zombiehead.mdl"
ITEM.category = "Junk"

ITEM.width = 1
ITEM.height = 1

--[[
	Worth nothing at a vendor. A head is evidence, a trophy or a message, and
	putting a number on it would make it a farm - somebody would work out that
	killing marked players pays better than looting.
]]
ITEM.price = 0

--- The marker other systems key off, rather than a base name.
ITEM.isPlayerHead = true

--[[
	ANY CHARACTER MAY HANDLE ONE.

	Helix stamps the first character to touch an item as its owner and then
	refuses to let another character on the SAME ACCOUNT pick it up -
	`itemOwned`, in `ITEM:Transfer` and again in `Inventory:Add`. That rule
	exists to stop somebody moving their own gear between their own
	characters, and it is exactly wrong for a head: a trophy is meant to change
	hands, and the one person guaranteed to want to pick this one up is
	somebody who is not its owner.
]]
ITEM.bAllowMultiCharacterInteraction = true

--[[
	TWO KINDS OF HEAD, and they are named differently on purpose.

	The name and the description are read off the INSTANCE. `GetData` is shared
	and works wherever the item is known, so the inventory, the tooltip and the
	thing lying on the ground all say the same words without being told
	separately.

	    label   "NCR - Trooper Head"    cut off a body, and UNMARKED
	    owner   "Vault Dweller's Head"      taken from a permanent kill

	A head cut off a corpse says what the body WAS and never who it was: it is
	a message, and a message that names its subject is evidence instead. A
	permanent kill is the opposite - the whole point of that head is that it is
	somebody's, and the body it came off carried that name for exactly this.

	`label` wins where both are somehow present, because the unmarked reading
	is the safe one to be wrong in.
]]
function ITEM:GetName()
	local label = self:GetData("label", "")

	if (label ~= "") then return label .. " Head" end

	local owner = self:GetData("owner", "")

	if (owner == "") then return self.name end

	return owner .. "'s Head"
end

function ITEM:GetDescription()
	local taken = self:GetData("taken", 0)
	local label = self:GetData("label", "")

	if (label ~= "") then
		--[[
			NO NAME AND NO DATE. A date narrows a severed head down to one
			person as surely as a name does, once somebody remembers who died
			that afternoon.
		]]
		return string.format("The head of a %s. Whoever it was, they are not "
			.. "using it.", label)
	end

	local owner = self:GetData("owner", "")

	if (owner == "") then return self.description end

	if (taken > 0) then
		return string.format("The head of %s, taken on %s.", owner,
			os.date("%d/%m/%Y", taken))
	end

	return string.format("The head of %s.", owner)
end

--[[
	Plant it.

	Phoenix's `Deploy`: the head goes into the ground in front of you, on a
	pike, with the name still on it. That is the whole point of carrying one
	home - a head in a bag is loot, and a head outside your gate is a sentence.

	`OnRun` IS SERVER-SIDE ALREADY and `OnCanRun` is not, which is the trap in
	this shape of item. Helix runs an item's action from its `ixItemAction`
	receiver, so `ents.Create` here is never reached on a client - but the
	BUTTON is decided by `OnCanRun` in the inventory, on the client, and an
	`OnCanRun` that answered "server only" would hide the button from the only
	realm that can see it. `items/sh_cropplot.lua` is the same shape.
]]
ITEM.functions.Deploy = {
	name = "Plant on a Spike",
	icon = "icon16/flag_red.png",

	OnRun = function(item)
		local client = item.player

		if (not IsValid(client)) then return false end

		local spike = ents.Create("ix_headspike")

		if (not IsValid(spike)) then return false end

		--[[
			IN FRONT OF THEM, ON THE FLOOR. `DropToFloor` after the position
			rather than a trace: a pike is a thing you push into the ground,
			and the ground is wherever it lands.
		]]
		local angles = client:EyeAngles()

		angles.p = 0
		angles.r = 0

		spike:SetPos(client:GetPos() + client:GetForward() * 60)
		spike:SetAngles(angles)
		spike:Spawn()
		spike:DropToFloor()
		--[[
			WHATEVER THIS HEAD SAYS IT IS. A pike carries the same words the
			item does - "NCR - Trooper" or "Vault Dweller" - because the two are
			the same statement made in two places, and a spike that quietly
			named somebody an unmarked head does not would undo the point of
			the head being unmarked.
		]]
		spike:SetHeadOwner(item:GetData("label", "")
			~= "" and item:GetData("label", "")
			or item:GetData("owner", ""))

		--[[
			Registered with the sandbox undo/cleanup the way a spawned prop is,
			so a map full of pikes can be cleared without hunting them, and so
			the anti-spam that watches player spawns sees this one.
		]]
		hook.Run("PlayerSpawnedSENT", client, spike)

		return true
	end,

	OnCanRun = function(item)
		return not IsValid(item.entity) and IsValid(item.player)
	end
}
