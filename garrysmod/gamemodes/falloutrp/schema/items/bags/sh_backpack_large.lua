--[[
	A backpack that holds things: Helix's bag base on the classic backpack,
	two by three of your inventory, with a container whose size is the dev
	config's "Backpacks" block. Opens on a click, or with Open on the menu,
	and takes a name. See `libs/sh_backpack.lua`.
]]

ITEM.name = "Large Backpack"
ITEM.description = "A frame pack. Room for everything you own and some of what you find."
ITEM.model = "models/galang/fallout/clutter/classicbackpacklarge.mdl"
ITEM.category = "Storage"
ITEM.width = 2
ITEM.height = 3
ITEM.price = 260

ix.backpack.Bag(ITEM, "large")
