--[[
	A blank modulator.

	Phoenix's `modulator` junk item: "a rare piece of equipment used to craft
	Armor Modulators". It does nothing by itself and is not fitted to anything -
	it is the ingredient every modulator recipe wants, which is what makes the
	eight of them one economy rather than eight.

	NO RECIPES ARE SHIPPED WITH IT. What a modulator costs is a balance
	decision, and this schema keeps those in the bench configurer where they can
	be changed without editing a file - see `/benchconfig`.

	In `items/` root rather than a folder, deliberately, and NOT in
	`items/modulator/`: everything in there inherits `base_modulator` and is
	therefore something the modulate bench will offer to fit. A blank one is not
	fitted to anything.

	Their model is `models/props_lab/tpplugholder_single.mdl`, which is Half-Life
	2 content this server does not have - checked with
	`_docs/tools/resolve_asset.py`, see gotcha 16 - so it uses the same modbox
	the finished ones do.
]]

ITEM.name = "Modulator"
ITEM.description = "A blank armour modulator. Worth nothing until somebody "
	.. "programmes it into something."
ITEM.model = "models/mosi/fallout4/props/junk/modbox.mdl"
ITEM.category = "Junk"

ITEM.width = 1
ITEM.height = 1
