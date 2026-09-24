--[[
	Perception Implant.

	The item is only how it gets there - the bonuses, the rules and the
	description all live in `ix.implants.list` under `perception`, which is what
	makes them editable in `/liveedit`. See `items/base/sh_implant.lua`.

	NO `ITEM.base` LINE. Helix takes the base from the FOLDER - `LoadFromDir`
	loads `items/implant/*` with `base_implant` - so writing one here does not
	add a base, it REPLACES the right one with whatever was typed:

	    [Helix] Item 'implant_agility' has a non-existent base! (implant)
]]

ITEM.name = "Perception Implant"
ITEM.implant = "perception"
