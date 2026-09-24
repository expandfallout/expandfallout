--[[
	The implant base.

	One item per implant, and all any of them declares is `ITEM.implant` - the
	id of an entry in `ix.implants.list`, which is where the name, the bonuses
	and the rules live. That is what makes them editable in `/liveedit`: the
	numbers are in one table rather than in nine item files.

	USE POINTS AT SOMEBODY ELSE. There is no path through this item that
	implants the person holding it, and that is the whole design: an implant in
	the wasteland means another character stood still for five seconds and put
	it there.
]]

ITEM.name = "Implant"
ITEM.description = "A cybernetic implant."
ITEM.model = "models/mosi/fallout4/props/junk/injector.mdl"
ITEM.category = "Implants"
ITEM.width = 1
ITEM.height = 1
ITEM.price = 4000

--- The id in `ix.implants.list`. An item without one is a base, not an implant.
ITEM.implant = nil

--[[
	THE NAME AND THE DESCRIPTION BOTH COME FROM THE LIBRARY, not from the item.

	`ITEM.name` is what an item file says it is called, and it is the fallback -
	but an implant renamed or rebalanced in `/liveedit` has to say so on the
	tooltip in somebody's hands, and the item file is not what changed.
]]
function ITEM:GetName()
	local implant = ix.implants.Get(self.implant)

	return implant and implant.name or self.name
end

function ITEM:GetDescription()
	local implant = ix.implants.Get(self.implant)

	if (not implant) then return self.description end

	local lines = {implant.description or self.description}

	for code, amount in SortedPairs(implant.buffs or {}) do
		local stat = ix.buff.stats[code]

		lines[#lines + 1] = string.format("%s%d %s", amount >= 0 and "+" or "",
			amount, stat and stat.name or code)
	end

	if (implant.faction) then
		local faction = ix.faction.teams[implant.faction]

		lines[#lines + 1] = string.format("Only %s may handle it.",
			faction and faction.name or implant.faction)
	end

	return table.concat(lines, "\n")
end

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
	name = "Implant",
	icon = "icon16/user_add.png",

	--[[
		SHOWN ONLY WHEN THERE IS SOMEBODY TO IMPLANT. `OnCanRun` runs on both
		realms - the client to draw the option, the server to honour it - so
		the same trace decides both.
	]]
	OnCanRun = function(item)
		if (not item.implant) then return false end

		local client = item.player

		return IsValid(client) and item:GetTarget(client) ~= nil
	end,

	OnRun = function(item)
		local client = item.player
		local target = item:GetTarget(client)

		if (not IsValid(target)) then return false end

		local character = target:GetCharacter()
		local mine = client:GetCharacter()

		if (not character or not mine) then return false end

		local implant = ix.implants.Get(item.implant)
		local can, reason = ix.implants.CanTake(character, item.implant)

		if (not can) then
			client:Notify(reason)

			return false
		end

		--[[
			THE ITEM'S OWN RULE, if it has one - the C.I.T implant burns
			anybody who is not C.I.T for trying, and says so itself.
		]]
		if (implant.CanImplant) then
			local allowed, why = implant.CanImplant(client, target)

			if (not allowed) then
				if (why) then client:Notify(why) end

				return false
			end
		end

		--[[
			WHAT EACH OF THEM CALLS THE OTHER. Helix's recognition plugin puts
			`GetName(viewer)` on a character - an unrecognised person is
			"Someone", which is exactly right for a stranger doing surgery on
			you in an alley.
		]]
		local theirName = character:GetName(client)
		local myName = mine:GetName(target)

		target:ChatPrint(string.format("%s is trying to implant you with %s.",
			myName, implant.name))
		client:ChatPrint(string.format("You begin implanting %s with %s.",
			theirName, implant.name))

		local time = ix.config.Get("implantTime", 5)

		client:SetAction("@implanting", time)
		client:DoStaredAction(target, function()
			if (not IsValid(client) or not IsValid(target)) then return end

			--[[
				ASKED AGAIN AT THE END. Five seconds is long enough for them to
				have been implanted with something else, or to have died and
				come back as somebody with a different set.
			]]
			local still = target:GetCharacter()

			if (not still) then return end

			if (not ix.implants.Add(still, item.implant, client)) then return end

			target:ChatPrint(string.format("You have been implanted with %s.",
				implant.name))
			client:ChatPrint(string.format("You implant %s with %s.",
				theirName, implant.name))

			item:Remove()
		end, time, function()
			if (IsValid(client)) then
				client:SetAction()
				client:ChatPrint("You stop implanting.")
			end

			if (IsValid(target)) then
				target:ChatPrint("They stop implanting you.")
			end
		end, ix.config.Get("implantRange", 96) * 2)

		--[[
			FALSE, so the item is not consumed HERE - the stared action removes
			it when the surgery finishes. An implant that vanished when the
			needle went in and the patient walked away would be an implant
			nobody got.
		]]
		return false
	end
}
