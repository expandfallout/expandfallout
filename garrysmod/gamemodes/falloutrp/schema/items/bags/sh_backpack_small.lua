--[[
	A backpack that holds things: Helix's bag base on the classic backpack,
	one slot of your inventory, with a container whose size is the dev
	config's "Backpacks" block. Opens on a click, or with Open on the menu,
	and takes a name. See `libs/sh_backpack.lua`.
]]

ITEM.name = "Small Backpack"
ITEM.description = "A satchel-sized pack. Room for the essentials."
ITEM.model = "models/galang/fallout/clutter/classicbackpacklarge.mdl"
ITEM.category = "Storage"
ITEM.width = 1
ITEM.height = 1
ITEM.price = 60

ix.backpack.Bag(ITEM, "small")
