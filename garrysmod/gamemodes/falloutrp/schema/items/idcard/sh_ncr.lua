--[[
	Phoenix's `sh_idcard_ncr.lua`, on the `base_idcard` base. See
	`items/base/sh_idcard.lua` for what a card does when worn.
]]

ITEM.name = "NCR ID Card"
ITEM.description = "A standard identification card issued to members of the New California Republic."
ITEM.model = "models/fallout3/clutter/passcardblue.mdl"
ITEM.width = 1
ITEM.height = 1

ITEM.caps = 10
ITEM.idIcon = "phoenix/faction_icons/ncr.png"
ITEM.cardType = "id"
ITEM.faction = FACTION_NCR
