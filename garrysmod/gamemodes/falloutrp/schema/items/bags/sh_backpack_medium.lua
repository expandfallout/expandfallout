--[[
	A backpack that holds things: Helix's bag base on the classic backpack,
	two by two of your inventory, with a container whose size is the dev
	config's "Backpacks" block. Opens on a click, or with Open on the menu,
	and takes a name. See `libs/sh_backpack.lua`.
]]

ITEM.name = "Medium Backpack"
ITEM.description = "A day pack. Room for a trip."
ITEM.model = "models/galang/fallout/clutter/classicbackpacklarge.mdl"
ITEM.category = "Storage"
ITEM.width = 2
ITEM.height = 2
ITEM.price = 140

ix.backpack.Bag(ITEM, "medium")
