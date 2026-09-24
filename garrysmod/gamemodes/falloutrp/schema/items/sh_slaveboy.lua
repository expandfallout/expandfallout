--[[
	The SlaveBoy 2000.

	Phoenix's handheld: it lists everybody whose collar you own and lets you do
	something about them from wherever you are. Theirs also sells people to a
	slave vendor, which needs the vendor, the mine and the manifest that go with
	it - a later job - so this is the half that only needs the collar.

	    every slave you own      by name, with the time left on their collar
	    disarm                   the collar comes off and they are freed
	    trigger                  the fuse starts, wherever they are

	IT IS NOT CONSUMED. Using it opens a screen and nothing else; there is
	nothing in it to use up, and an item that vanished when you looked at your
	own slaves would be unusable by design.

	THE POINT OF IT IS THE DISTANCE. Every other thing you can do to a slave is
	in the hold-E menu and needs you stood in front of them. This does not, and
	that is what makes a collar a leash rather than a threat you can walk away
	from - see the note at the bottom of `sh_slavery.lua`.

	In `items/` root rather than a folder, for the reason the fusion core
	gives: `ix.item.LoadFromDir` gives anything in `items/<folder>/` the base
	`base_<folder>`, so a folder would demand a base that does not exist.
]]

ITEM.name = "SlaveBoy 2000"
ITEM.description = "A battered handheld wired to a set of collar "
	.. "transmitters. It knows where everybody you own is."
--[[
	A DETONATOR, because this server has no Pip-Boy prop and a collar
	transmitter is what the thing actually is. Checked with
	`resolve_asset.py`, like every model in this schema.
]]
ITEM.model = "models/catmop/fallout/weapons/world/pistols/detonator.mdl"
ITEM.category = "Junk"

ITEM.width = 1
ITEM.height = 1

--- What `ix.slavery` looks for when somebody asks for the list.
ITEM.isSlaveBoy = true

ITEM.functions.Use = {
	name = "Use",
	icon = "icon16/application_side_list.png",

	OnRun = function(item)
		local client = item.player

		if (not IsValid(client)) then return false end

		ix.slavery.SendList(client)

		--[[
			FALSE, ALWAYS. `true` would destroy the item - this is a screen you
			open, not a stimpak.
		]]
		return false
	end,

	OnCanRun = function(item)
		return not IsValid(item.entity) and IsValid(item.player)
	end
}
