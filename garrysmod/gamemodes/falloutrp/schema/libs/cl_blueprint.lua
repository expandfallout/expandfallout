--[[
	Blueprints, client side: the overrides and what this character knows.

	The DEFAULTS are not sent - they are in `sh_blueprintdefaults.lua`, which
	both realms load off disk. Only what an admin has changed since arrives
	over the wire, which keeps a join from carrying 259 recipes the client
	already has.
]]

if (not CLIENT) then return end

ix.blueprint = ix.blueprint or {}
ix.blueprint.recipes = ix.blueprint.recipes or {}
ix.blueprint.frames = ix.blueprint.frames or {}

net.Receive("ixBlueprintSync", function()
	ix.blueprint.recipes = net.ReadTable() or {}
	ix.blueprint.frames = net.ReadTable() or {}

	--[[
		Sizes are written onto the item TABLES, so this has to run on the
		client too - the server places a frame into the grid and the client
		draws it, and a disagreement about the size is an item that cannot be
		picked up where it appears to be.
	]]
	ix.blueprint.ApplySizes()

	if (IsValid(ix.gui.benchConfig)) then
		ix.gui.benchConfig:Rebuild()
	end

	if (IsValid(ix.gui.bench)) then
		ix.gui.bench:Rebuild()
	end
end)

--[[
	What this character has learned - a NUDGE, not the data.

	`character:SetData` does not exist on the client. It is registered inside
	`if (SERVER)`, and calling it here was an outright error:

	    attempt to call method 'SetData' (a nil value)

	It was also unnecessary, which is the more useful half. Helix registers
	`data` as a character var with `isLocal = true` and an `OnSet` that
	networks the change to the owner over `ixCharacterData` - so by the time
	this message lands the client's `character:GetData("blueprints")` is
	already right. Net messages arrive in order and the server writes the data
	before it sends this, so there is no window where the two disagree.

	`ix.blueprint.Known` reads `GetData`, which works on BOTH realms. Storing
	a second copy here would have been a second source of truth for the same
	fact, and the one that goes stale is always the copy.

	So this reads the list only to drain the message, and its whole job is to
	rebuild the window the instant something is learned rather than on its next
	poll.
]]
net.Receive("ixBlueprintKnown", function()
	local count = net.ReadUInt(16)

	for _ = 1, count do
		net.ReadString()
	end

	if (IsValid(ix.gui.bench)) then
		ix.gui.bench:Rebuild()
	end
end)
