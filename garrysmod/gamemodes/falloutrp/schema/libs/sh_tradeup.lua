--[[
	The trade-up bench.

	Phoenix's: five weapons of the same kind and the same quality go in, one of
	the same kind at the NEXT quality comes out, straight into your pockets.
	It is what makes a pile of Common rifles worth keeping - a currency for the
	rarity ladder that is not caps.

	IT IS A BENCH MODE, NOT ITS OWN BENCH. `tradeup` joins `craft`,
	`instacraftory`, `process` and `infinite` in `ix.bench.modes`, so it is
	placed, moved, gated by faction, rank and level, and deleted by exactly the
	same commands as every other bench. What it changes is the WINDOW - see
	`cl_tradeup.lua` - because the thing being chosen is not a recipe.

	    five of a kind      same uniqueID AND same rarity. A Common pipe rifle
	                        and a Common laser rifle are not four of a kind
	    the same weapon      you get the kind you put in, one tier better -
	                        never a different gun
	    instant              nothing to wait for and nothing to collect. It is
	                        Phoenix's, and a queue would mean a bench holding
	                        five guns somebody else could take out
	    a ceiling            `tradeupMaxRarity`, defaulting to Legendary, so
	                        Master Craft and Pearlescent stay things you roll
	                        rather than things you buy with enough rifles

	THE CEILING IS THE POINT OF THE CONFIG. The two tiers above Legendary are
	1% and 0.1% at fifty Luck; letting the bench reach them would make the top
	of the curve a matter of grinding, and the curve is the whole reason Luck is
	worth spending on.
]]

ix.tradeup = ix.tradeup or {}

--[[
	How many go in for one to come out.

	Five is Phoenix's. It is also, roughly, what the curve says a tier is worth:
	Superior is 20% and Legendary 5% at full Luck, so four to five of one tier
	per one of the next is the exchange rate the rolls already imply.
]]
ix.config.Add("tradeupAmount", 5,
	"How many weapons of one kind and quality make one of the next.", nil, {
	data = {min = 2, max = 20},
	category = "Trade Up"
})

--[[
	The best quality the bench will ever hand out.

	Stored as a tier ID rather than an index, for the reason `sh_rarity.lua`
	gives: an index would re-point if a tier were ever inserted in the middle.
]]
ix.config.Add("tradeupMaxRarity", "legendary",
	"The best quality a trade-up bench can produce.", nil, {
	category = "Trade Up"
})

--- How many go into one trade, honouring the config's own bounds.
function ix.tradeup.Amount()
	return math.Clamp(math.floor(ix.config.Get("tradeupAmount", 5)), 2, 20)
end

--[[
	The ceiling as a tier, never nil.

	A `tradeupMaxRarity` naming a tier that does not exist - a typo, or a tier
	renamed later - falls back to Legendary rather than to the top of the list,
	because the failure of a ceiling should be the safe direction.
]]
function ix.tradeup.Cap()
	local id = ix.config.Get("tradeupMaxRarity", "legendary")

	return ix.rarity.byID[id] or ix.rarity.byID.legendary or ix.rarity.tiers[1]
end

--[[
	What a given quality trades up INTO, or nil when it cannot.

	Nil has two meanings and both are "no": the tier is the last one there is,
	or the next one is above the ceiling. Callers only ever want the answer.
]]
function ix.tradeup.NextTier(id)
	local tier = ix.rarity.byID[id]

	if (not tier) then return nil end

	local nextTier = ix.rarity.tiers[tier.index + 1]

	if (not nextTier) then return nil end
	if (nextTier.index > ix.tradeup.Cap().index) then return nil end

	return nextTier
end

--[[
	Can this item be traded up at all?

	EQUIPPED WEAPONS ARE NOT ELIGIBLE. Consuming the rifle in somebody's hands
	because it happened to be the fifth of its kind is a way to lose a weapon
	you were relying on, and the bench cannot know which one you meant.
]]
function ix.tradeup.Eligible(item)
	if (not item or not item.uniqueID) then return false end
	if (item:GetData("equip")) then return false end

	local itemTable = ix.item.list[item.uniqueID]

	if (not itemTable or itemTable.base ~= "base_weapons") then return false end

	return ix.rarity.Get(item) ~= nil
end

--[[
	Everything in an inventory that could go into a trade, grouped.

	Returns a list of `{uniqueID, name, rarity, count, ready}` sorted by name
	then by quality, which is the order the window draws them in. Built the same
	way on both realms - the client draws from its own inventory and the server
	checks against the real one - so a row that says READY is a row the server
	will agree about.
]]
function ix.tradeup.Groups(inventory)
	local groups = {}
	local order = {}

	for item in ix.inventory.Each(inventory) do
		if (not ix.tradeup.Eligible(item)) then continue end

		local rarity = ix.rarity.Get(item)
		local key = item.uniqueID .. "/" .. rarity

		if (not groups[key]) then
			groups[key] = {
				uniqueID = item.uniqueID,
				name = item.name or item.uniqueID,
				rarity = rarity,
				count = 0
			}

			order[#order + 1] = groups[key]
		end

		groups[key].count = groups[key].count + 1
	end

	local amount = ix.tradeup.Amount()

	for _, group in ipairs(order) do
		local nextTier = ix.tradeup.NextTier(group.rarity)

		group.nextTier = nextTier and nextTier.id or nil
		group.ready = nextTier ~= nil and group.count >= amount
	end

	table.sort(order, function(a, b)
		if (a.name == b.name) then
			return ix.rarity.Tier(a.rarity).index
				< ix.rarity.Tier(b.rarity).index
		end

		return a.name < b.name
	end)

	return order
end
