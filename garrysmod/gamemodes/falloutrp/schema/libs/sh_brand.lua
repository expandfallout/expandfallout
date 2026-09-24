--[[
	Branding a weapon to your faction.

	Phoenix's, from `sh_moddableweapons.lua`: right-click a weapon, pay
	`weaponBrandCost`, confirm, and it carries your faction's mark and a serial
	number for the rest of its life. Theirs is three groups of four hex digits;
	this is three groups of five, which is the shape people remember it as.

	WHAT IT IS FOR. A branded weapon can be traced. It says which faction issued
	it, and the serial says WHICH ONE - so a rifle taken off a body, sold on and
	found three owners later is still evidence, and a faction that arms people
	can tell its own kit from a copy. None of that is enforced by code; it is a
	fact stamped on the object that people can argue about.

	    branded      it has a mark at all
	    brandedTo    the faction's name, as it was when it was branded
	    brandID      the serial, and the thing a ticket or a log quotes
	    brandedBy    who did it. NOT shown on the weapon - the mark is the
	                 faction's, not the individual's - but it is in the log,
	                 which is what an admin reading a report needs

	THE NAME IS STORED, NOT THE FACTION ID. A faction renamed later does not
	silently rewrite what is stamped on every weapon it ever issued, and a
	faction deleted entirely leaves its mark behind rather than a blank. That is
	the whole point of a brand: it records what was true when it was made.

	IT CANNOT BE UNDONE, and there is no unbranding item. Phoenix have none
	either. A mark you can take off is not a mark.
]]

ix.brand = ix.brand or {}

--[[
	What it costs. 500 is Phoenix's.

	Zero means free, and the confirmation is skipped when it is - a popup
	asking somebody to agree to spend nothing is a popup that trains people to
	click through popups.
]]
ix.config.Add("weaponBrandCost", 500,
	"What it costs to brand a weapon to your faction.", nil, {
	data = {min = 0, max = 100000},
	category = "Weapon"
})

--[[
	The serial: `XXXXX-XXXXX-XXXXX`.

	NO 0, O, 1, I, 5 OR S. A serial exists to be read off a screen and typed
	into a ticket by somebody else, and those six are the pairs that get typed
	wrong - which turns "the rifle with this serial" into an argument. Twenty-six
	symbols over fifteen characters is still more combinations than this server
	will ever have items.
]]
local ALPHABET = "ABCDEFGHJKLMNPQRTUVWXYZ23467890"

function ix.brand.Generate()
	local parts = {}

	for group = 1, 3 do
		local out = {}

		for _ = 1, 5 do
			local index = math.random(#ALPHABET)

			out[#out + 1] = string.sub(ALPHABET, index, index)
		end

		parts[group] = table.concat(out)
	end

	return table.concat(parts, "-")
end

--------------------------------------------------------------------------------
-- Reading one
--------------------------------------------------------------------------------

--- The serial on an item, or nil.
function ix.brand.Get(item)
	if (not item or not item.GetData) then return nil end
	if (not item:GetData("branded")) then return nil end

	local id = item:GetData("brandID")

	return isstring(id) and id ~= "" and id or nil
end

--- The faction name a weapon is branded to, or nil.
function ix.brand.Owner(item)
	if (not ix.brand.Get(item)) then return nil end

	local owner = item:GetData("brandedTo")

	return isstring(owner) and owner ~= "" and owner or "Unknown"
end

--[[
	Is this weapon brandable by this character AT ALL? `true`, or
	`false, reason`.

	EVERYTHING EXCEPT THE MONEY, and the split matters: the menu entry is
	offered on this, so somebody who cannot afford it still SEES the option and
	is told the price. An entry that silently disappears when you are short is
	an entry nobody ever learns exists.
]]
function ix.brand.CanOffer(client, item)
	local character = client and client:GetCharacter()

	if (not character) then return false, "No character." end
	if (not item) then return false, "No item." end

	local itemTable = ix.item.list[item.uniqueID]

	if (not itemTable or itemTable.base ~= "base_weapons") then
		return false, "Only weapons can be branded."
	end

	if (ix.brand.Get(item)) then
		return false, "That is already branded."
	end

	local faction = ix.faction.indices[character:GetFaction()]

	if (not faction) then return false, "You have no faction." end

	--[[
		NOT THE DEFAULT FACTION. Phoenix refuse Wastelanders by name; this
		refuses whichever faction is flagged `isDefault`, which is the same
		faction and stays right if it is ever renamed.

		A wastelander is not an organisation and has nothing to issue kit in
		the name of - a brand from one would mean "somebody, somewhere", which
		is exactly what an unbranded weapon already says.
	]]
	if (faction.isDefault) then
		return false, string.format("%s are not a faction that brands "
			.. "anything.", faction.name)
	end

	return true
end

--[[
	May this character brand this weapon RIGHT NOW? `true`, or `false, reason`.

	`CanOffer` plus the caps. This is what the server asks; see gotcha 15 - a
	menu entry that is not drawn is not a permission, and the message can be
	sent by anything.
]]
function ix.brand.CanBrand(client, item)
	local allowed, reason = ix.brand.CanOffer(client, item)

	if (not allowed) then return false, reason end

	local cost = ix.brand.Cost()
	local character = client:GetCharacter()

	if (cost > 0 and character:GetMoney() < cost) then
		return false, string.format("Branding costs %s.",
			ix.currency.Get(cost))
	end

	return true
end

--- What it costs, never negative.
function ix.brand.Cost()
	return math.max(math.floor(ix.config.Get("weaponBrandCost", 500)), 0)
end

--------------------------------------------------------------------------------
-- The menu entries, and the mark on the description
--------------------------------------------------------------------------------

--[[
	Added to every registered weapon on `InitializedPlugins`.

	NOT TO THE BASE ITEM, which would look like the obvious place. Helix COPIES
	a base into each item at registration rather than leaving a metatable
	behind - see `ix.item.Register` - so a function added to `base_weapons`
	afterwards reaches nothing at all. `cl_rarity.lua` wraps every weapon the
	same way and for the same reason.
]]
local function Inject(itemTable)
	if (itemTable.ixBrand) then return end

	itemTable.ixBrand = true
	itemTable.functions = itemTable.functions or {}

	--[[
		NAMED `zBrand` SO IT SORTS LAST. The right-click menu is built with
		`SortedPairs`, so the key decides the order - and "Brand" would sit
		above "Equip", putting an irreversible action that costs 500 caps
		where the muscle memory for equipping a rifle is. Helix's own armour
		base does the same thing with `EquipUn` for the same reason.
	]]
	itemTable.functions.zBrand = {
		name = "Brand",
		icon = "icon16/tag_orange.png",

		OnCanRun = function(item)
			return not IsValid(item.entity)
				and ix.brand.CanOffer(item.player, item) == true
		end,

		--[[
			THE CONFIRMATION, and the reason this returns false either way.

			`OnClick` runs on the CLIENT and its return decides whether the
			action is sent at all - so returning false always, and sending the
			action ourselves from inside the query's callback, is what turns
			one click into "ask, then do". Letting it send and asking
			afterwards would mean the caps were already gone.
		]]
		OnClick = function(item)
			local cost = ix.brand.Cost()

			local function Send()
				net.Start("ixInventoryAction")
					net.WriteString("zBrand")
					net.WriteUInt(item.id, 32)
					net.WriteUInt(item.invID or 0, 32)
					net.WriteTable({})
				net.SendToServer()
			end

			--- Free needs no confirming; see the note on `weaponBrandCost`.
			if (cost <= 0) then
				Send()

				return false
			end

			Derma_Query(string.format("Brand this %s to your faction for "
				.. "%s?\n\nIt cannot be undone, and the serial stays on "
				.. "it for good.", item.name or "weapon",
				ix.currency.Get(cost)),
				"Brand", "Brand it", Send, "Cancel", function() end)

			return false
		end,

		OnRun = function(item)
			ix.brand.Apply(item.player, item)

			--- False: the item is not consumed and the menu stays open.
			return false
		end
	}

	--[[
		Copying the serial is a CLIENT action and never reaches the server -
		`OnRun` returning false is what stops the click doing anything there.

		It is worth having for the same reason the serial is worth reading: it
		is quoted into a ticket, a Discord report or a chat line by somebody
		who should not have to transcribe fifteen characters by eye.
	]]
	itemTable.functions.zBrandCopy = {
		name = "Copy Brand ID",
		icon = "icon16/page_copy.png",

		OnCanRun = function(item)
			return not IsValid(item.entity) and ix.brand.Get(item) ~= nil
		end,

		OnClick = function(item)
			local id = ix.brand.Get(item)

			if (not id) then return false end

			SetClipboardText(id)

			if (IsValid(LocalPlayer())) then
				LocalPlayer():Notify("Brand ID copied: " .. id)
			end

			return false
		end,

		OnRun = function() return false end
	}

	--[[
		The mark, on the description, wrapped rather than replaced - a weapon
		may already have a description function of its own and every one of
		them is somebody's work.
	]]
	local getDescription = itemTable.GetDescription

	itemTable.GetDescription = function(self)
		local description = getDescription and getDescription(self)
			or self.description or ""
		local id = ix.brand.Get(self)

		if (not id) then return description end

		return string.format("%s\n\nBranded to:\n - %s\nBrand ID:\n - %s",
			description, ix.brand.Owner(self), id)
	end
end

hook.Add("InitializedPlugins", "ixBrand", function()
	for _, itemTable in pairs(ix.item.list) do
		if (itemTable.base == "base_weapons") then
			Inject(itemTable)
		end
	end
end)
