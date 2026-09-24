--[[
	Phoenix's `sh_idcard_bos.lua`, on the `base_idcard` base. See
	`items/base/sh_idcard.lua` for what a card does when worn.
]]

ITEM.name = "BoS Civilian Tag"
ITEM.description = "A holotag with the insignia of the Brotherhood of Steel, issued to civilians under its protection."
ITEM.model = "models/models/fallout/holodogtag.mdl"
ITEM.width = 1
ITEM.height = 1

ITEM.caps = 10
ITEM.idIcon = "phoenix/faction_icons/bos.png"
ITEM.cardType = "id"
ITEM.faction = FACTION_BOS
