--[[
	Which log category a type belongs to.

	SHARED, because both realms need it and for different reasons: the server
	sorts entries into categories as it writes them, and the admin menu draws a
	filter button per category. It lived in `sv_adminlog.lua` at first, which
	made `ix.adminlog.categoryNames` nil on the client and took the LOGS tab
	down with

	    attempt to index field 'adminlog' (a nil value)

	Data that a window draws is client data, wherever it is also used.
]]

ix.adminlog = ix.adminlog or {}

--[[
	Which category a log type belongs to.

	Matched as a PREFIX so a whole family lands together without listing every
	member - `charMoney` catches `charMoneyGive`, `charMoneyTake` and anything
	added later with the same stem. Longest prefix wins, so a specific rule can
	always override a general one.
]]
ix.adminlog.categories = {
	{prefix = "charMoney", category = "economy"},
	{prefix = "money", category = "economy"},
	{prefix = "shopBuy", category = "economy"},
	{prefix = "shop", category = "economy"},
	{prefix = "benchCraft", category = "items"},
	{prefix = "rarityCraft", category = "items"},
	{prefix = "trash", category = "items"},
	{prefix = "item", category = "items"},
	{prefix = "charGiveItem", category = "items"},
	{prefix = "charTakeItem", category = "items"},
	{prefix = "storage", category = "items"},
	{prefix = "factionStorage", category = "items"},
	{prefix = "combat", category = "combat"},
	{prefix = "sandbox", category = "sandbox"},
	{prefix = "command", category = "commands"},
	{prefix = "chat", category = "chat"},
	{prefix = "ooc", category = "chat"},
	{prefix = "pm", category = "chat"},
	{prefix = "admin", category = "admin"},
	{prefix = "punish", category = "admin"},

	--[[
		A PK is a staff action when an admin marks somebody and a character
		event when it is collected, so the two go to different places - the
		longer prefix wins, which is what lets one family split like this.
	]]
	{prefix = "pk", category = "admin"},
	{prefix = "pkDeath", category = "character"},

	--[[
		Map furniture is staff work, so it lands with the staff actions - with
		three exceptions, each of which is a PLAYER doing something rather than
		an admin building something. Longest prefix wins, so the exceptions sit
		next to the general rules rather than needing an order.
	]]
	{prefix = "zone", category = "admin"},
	{prefix = "point", category = "admin"},
	{prefix = "door", category = "admin"},
	{prefix = "pointLoot", category = "economy"},
	{prefix = "pointCapture", category = "faction"},
	{prefix = "doorTeleport", category = "character"},
	{prefix = "zoneOutOfBounds", category = "character"},
	--[[
		Tying somebody up, blowing their door open and collaring them are all
		things PLAYERS do to each other, so none of them are staff actions -
		they belong with the rest of what happened to a character.
	]]
	--- Picking a plant is an item appearing, so it lands with the items.
	{prefix = "plant", category = "items"},

	--- A mugging is caps changing hands, whatever else it is.
	{prefix = "mug", category = "economy"},

	--- A farm is items appearing, and a plot is furniture somebody placed.
	{prefix = "farm", category = "items"},

	--[[
		Digging ore up is an item appearing; placing and configuring nodes is
		staff work, so the longer prefixes split off - the same shape the zones
		and points use.
	]]
	{prefix = "mine", category = "items"},
	{prefix = "mining", category = "admin"},

	{prefix = "restrain", category = "character"},
	{prefix = "breach", category = "character"},
	{prefix = "collar", category = "character"},

	{prefix = "dev", category = "admin"},
	{prefix = "bench", category = "admin"},
	{prefix = "blueprint", category = "admin"},
	{prefix = "loot", category = "admin"},
	{prefix = "permaProp", category = "admin"},
	{prefix = "fm", category = "faction"},
	{prefix = "faction", category = "faction"},
	{prefix = "char", category = "character"},
	{prefix = "player", category = "character"}
}

--- The order they are offered in, and what each is called.
ix.adminlog.categoryNames = {
	{id = "economy", name = "Economy"},
	{id = "items", name = "Items"},
	{id = "combat", name = "Combat"},
	{id = "sandbox", name = "Q Menu"},
	{id = "chat", name = "Chat"},
	{id = "commands", name = "Commands"},
	{id = "character", name = "Characters"},
	{id = "faction", name = "Factions"},
	{id = "admin", name = "Admin"},
	{id = "other", name = "Other"}
}

function ix.adminlog.Categorise(logType)
	local best, length = "other", 0

	for _, rule in ipairs(ix.adminlog.categories) do
		if (string.StartWith(logType, rule.prefix)
		and #rule.prefix > length) then
			best, length = rule.category, #rule.prefix
		end
	end

	return best
end
