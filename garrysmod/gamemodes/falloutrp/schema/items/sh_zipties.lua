--[[
	Zip ties.

	Phoenix's, down to the model. Theirs traces 96 units from the
	Use button and does the whole tying sequence inside the item; here the item
	traces and `ix.restrain.Begin` does the sequence, because the hold-E menu
	reaches the same act from the other side and only one of the two should own
	the rules.

	In `items/` root rather than a folder, for the reason the fusion core gives:
	`ix.item.LoadFromDir` gives anything in `items/<folder>/` the base
	`base_<folder>`, so a folder would demand a base that does not exist. The
	filename is the uniqueID, and `ix.restrain.kinds.ziptie.item` is that
	string.
]]

ITEM.name = "Zip Tie"
ITEM.description = "An orange zip tie, used to restrain somebody so they can "
	.. "be searched. This item has rules of use."
ITEM.model = "models/items/crossbowrounds.mdl"
ITEM.category = "Junk"

ITEM.width = 1
ITEM.height = 1

--- Who it can be used on, in units. Helix traces 96 for E; this matches.
ITEM.reach = 96

ITEM.functions.Use = {
	name = "Use",
	icon = "icon16/link.png",

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

		ix.restrain.Begin(client, target, "ziptie")

		--[[
			FALSE, ALWAYS. The tie is consumed by `ix.restrain.Begin` when the
			progress bar FINISHES, not when the button is pressed - returning
			true here would take it whether or not the tying worked, which is a
			free unbreakable escape for anybody who walks away halfway.
		]]
		return false
	end,

	OnCanRun = function(item)
		local client = item.player

		if (IsValid(item.entity) or not IsValid(client)) then return false end
		if (not client:Alive() or ix.restrain.Is(client)) then return false end

		return true
	end
}

--[[
	A tie being used cannot be handed away mid-sequence, which is how Phoenix's
	`beingUsed` flag read. Ours is on the PLAYER rather than the item - the
	sequence belongs to the person, and one person can only be tying one thing
	at a time - so the question here is about them.
]]
function ITEM:CanTransfer(oldInventory, newInventory)
	local client = self:GetOwner()

	if (IsValid(client) and client.ixRestrainBusy) then return false end

	return true
end
