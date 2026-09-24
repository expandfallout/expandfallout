--[[
	Phoenix's `sh_idcard_legion.lua`, on the `base_idcard` base. See
	`items/base/sh_idcard.lua` for what a card does when worn.
]]

ITEM.name = "Legion Loyalist Coin"
ITEM.description = "A token carried by members of Caesar's Legion to show their loyalty."
ITEM.model = "models/models/fallout/legionaureus.mdl"
ITEM.width = 1
ITEM.height = 1

ITEM.caps = 10
ITEM.idIcon = "phoenix/faction_icons/legion.png"
ITEM.cardType = "id"
ITEM.faction = FACTION_LEGION
