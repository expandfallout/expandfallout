--[[
	Shift-click an item to send it to the other open inventory.

	Helix has drag and drop and nothing else, which is fine for one item and
	tedious for twenty - emptying a container is twenty drags across the screen
	when it could be twenty clicks in one place.

	WRAPPED, NOT REPLACED. `ixItemIcon` is Helix's own panel and its
	`OnMousePressed` starts the drag, opens the right-click menu and records
	where the cursor was. Copying that body here to add one branch would mean
	owning a copy of it for ever, silently drifting from theirs on every
	update. Instead the original is kept in an upvalue and called for
	everything this does not handle.

	`vgui.GetControlTable` is what makes that possible: it hands back the table
	`vgui.Register` stored, and writing to it affects panels created afterwards.
	So this file runs once, late, and every icon built from then on has it.

	IT REUSES HELIX'S OWN MOVE. `icon:Move(x, y, panel)` is what a completed
	drag calls, and it does the local reparenting AND sends `ixInventoryMove`
	through `OnTransfer` - which is also where `CanTransferItem` is asked. So a
	shift-click is refused by exactly the same rules a drag is, including the
	one that stops anything being put into a workbench, without this file
	knowing any of them.
]]

if (not CLIENT) then return end

--[[
	Every open inventory panel, by the id it is showing.

	Helix keys them `ix.gui["inv" .. invID]`, and the character's own is always
	`inv1` regardless of its real id - `sh_item.lua` maps it on the way in. So
	the panel's own `invID` is read rather than the key, because that is the
	number the move message has to carry.
]]
local function OpenInventories()
	local out = {}

	for key, panel in pairs(ix.gui) do
		if (not isstring(key) or not string.StartWith(key, "inv")) then
			continue
		end

		if (not IsValid(panel) or not panel.invID or not panel.slots) then
			continue
		end

		out[#out + 1] = panel
	end

	return out
end

--[[
	Where should a shift-click send this?

	The other open inventory, and only when there is exactly one candidate. Two
	containers open at once is a real situation - a corpse and a crate - and
	guessing which one somebody meant is worse than doing nothing, because the
	wrong guess moves their things somewhere they were not looking.
]]
local function Destination(source)
	local found

	for _, panel in ipairs(OpenInventories()) do
		if (panel == source or panel.invID == source.invID) then continue end

		if (found) then return nil, "more than one" end

		found = panel
	end

	return found
end

--------------------------------------------------------------------------------
-- Squares already spoken for
--------------------------------------------------------------------------------

--[[
	WHERE THE THREE PISTOLS IN ONE SQUARE CAME FROM.

	`FindEmptySlot` answers from the CLIENT's copy of the destination
	inventory, and that copy does not change until the SERVER answers the move.
	Shift-click three things in half a second and all three are told the same
	square is free, so all three are sent to it - and Helix's `Inventory:Add`
	does not check the slots when it is given a position, so the server obeys
	all three.

	`sv_gridguard.lua` is the guarantee that nothing ever lands on top of
	anything: it redirects a placement into an occupied square to the first free
	one. This is the manners - twenty shift-clicks fill twenty different squares
	rather than sending twenty moves for the server to redirect one at a time,
	and the icons land where the person clicking expected them to.

	A reservation is only a few seconds long. It is a stand-in for a sync that
	has not arrived yet, so it has to expire on its own: a move the server
	refuses sends nothing back that could clear one.
]]
local reserved = {}
local RESERVE_TIME = 4

local function Reserve(invID, x, y, width, height)
	reserved[invID] = reserved[invID] or {}

	table.insert(reserved[invID], {
		x = x, y = y, w = width, h = height,
		expires = CurTime() + RESERVE_TIME
	})
end

--- Is any live reservation sitting in this rectangle?
local function Taken(invID, x, y, width, height)
	local list = reserved[invID]

	if (not list) then return false end

	local now = CurTime()

	for index = #list, 1, -1 do
		local entry = list[index]

		if (entry.expires < now) then
			table.remove(list, index)

			continue
		end

		if (x < entry.x + entry.w and entry.x < x + width
		and y < entry.y + entry.h and entry.y < y + height) then
			return true
		end
	end

	return false
end

--[[
	The first square that is free in the client's copy AND not spoken for.

	`FindEmptySlot`'s own scan with one extra test, rather than a call to it:
	there is no way to tell it about the reservations, and its answer is the
	one square this needs to skip past.
]]
local function FreeSlot(inventory, invID, width, height)
	local w, h = inventory:GetSize()

	if (width > w or height > h) then return nil end

	for y = 1, h - (height - 1) do
		for x = 1, w - (width - 1) do
			if (inventory:CanItemFit(x, y, width, height)
			and not Taken(invID, x, y, width, height)) then
				return x, y
			end
		end
	end
end

--[[
	Wrapped as soon as the panel exists, and NOT from `InitPostEntity` - that
	hook does not fire in this schema at all; see `07-gotchas.md`. Helix
	registers `ixItemIcon` in its core, which loads before the schema, so at
	file scope it is normally already there and the retry never runs.
]]
local function Wrap()
	local PANEL = vgui.GetControlTable("ixItemIcon")

	if (not PANEL) then return false end
	if (PANEL.ixQuickMove) then return true end

	--- Marked so a lua_refresh cannot wrap the wrapper around itself.
	PANEL.ixQuickMove = true

	local original = PANEL.OnMousePressed

	function PANEL:OnMousePressed(code)
		if (code ~= MOUSE_LEFT or not input.IsShiftDown()) then
			return original(self, code)
		end

		local item = self:GetItemTable()
		local source = self:GetParent()

		if (not item or not IsValid(source) or not source.invID) then
			return original(self, code)
		end

		local destination, why = Destination(source)

		if (not destination) then
			--[[
				Nothing to send it to, so it behaves as an ordinary click and
				starts a drag. Swallowing the click instead would make
				shift-clicking in a single open inventory feel broken.
			]]
			if (why) then
				LocalPlayer():Notify("Two containers are open - drag it to "
					.. "the one you mean.")
			end

			return original(self, code)
		end

		local inventory = ix.item.inventories[destination.invID]

		if (not inventory) then return original(self, code) end

		local width = item.width or 1
		local height = item.height or 1
		local x, y = FreeSlot(inventory, destination.invID, width, height)

		if (not x) then
			LocalPlayer():Notify("No room over there.")

			return
		end

		--[[
			Helix's own move, so this shares every rule a drag has - see the
			note at the top. It sends the message itself; nothing else here
			talks to the server.

			The square is spoken for BEFORE the move is sent, so the next
			shift-click a frame later already knows about it.
		]]
		Reserve(destination.invID, x, y, width, height)

		self:Move(x, y, destination)
	end

	return true
end

if (not Wrap()) then
	--[[
		A retry rather than a hook, because there is no hook that reliably
		means "Helix's derma is registered" on the client. Ten seconds of
		one-second attempts, and then it gives up loudly rather than leaving
		shift-click quietly doing nothing for the rest of the session.
	]]
	local attempts = 0

	timer.Create("ixQuickMoveWrap", 1, 10, function()
		attempts = attempts + 1

		if (Wrap()) then
			timer.Remove("ixQuickMoveWrap")
		elseif (attempts >= 10) then
			ErrorNoHalt("[falloutrp] ixItemIcon never appeared - shift-click "
				.. "to move items is not active\n")
		end
	end)
end

--[[
	`fo_grid_report` - what the client thinks is where.

	Prints every item in every open inventory with the slot it occupies and the
	size it believes it is, then looks for pairs whose rectangles intersect.

	IT SEPARATES TWO DIFFERENT BUGS that look identical on screen. Items drawn
	on top of each other is either

	  * a PLACEMENT fault - two items really are at overlapping coordinates,
	    which means something moved one there without checking; or
	  * a SIZE disagreement - the client thinks an item is 2x2 and the server
	    put it down as 1x1, so the coordinates are fine and the drawing is not.

	The first shows up as an OVERLAP line here. The second shows up as a size
	that does not match the item file. Reasoning about the screenshot cannot
	tell them apart, and each has a completely different fix.
]]
concommand.Add("fo_grid_report", function()
	local function Line(text)
		MsgC(Color(255, 200, 100), "[grid] " .. text .. "\n")

		if (IsValid(LocalPlayer())) then
			LocalPlayer():ChatPrint("[grid] " .. text)
		end
	end

	local panels = OpenInventories()

	if (#panels == 0) then
		Line("no inventory windows are open")

		return
	end

	for _, panel in ipairs(panels) do
		local inventory = ix.item.inventories[panel.invID]

		if (not inventory) then
			Line(string.format("inventory %d: the client has no copy of it",
				panel.invID))

			continue
		end

		local width, height = inventory:GetSize()
		local placed = {}

		Line(string.format("inventory %d - %dx%d", panel.invID, width, height))

		--[[
			ONCE PER ITEM, not once per square.

			`Iter()` yields an item once for every slot of its footprint, so
			the overlap check below compared a six-square rifle against itself
			fifteen times and called every one of them an overlap. A report
			built to find grid corruption was manufacturing it.
		]]
		for item in ix.inventory.Each(inventory) do
			local x, y = item.gridX, item.gridY
			local w = item.width or 1
			local h = item.height or 1

			Line(string.format("   %-28s id %-6d at %s,%s  %dx%d",
				item.name or item.uniqueID, item.id, tostring(x), tostring(y),
				w, h))

			if (x and y) then
				placed[#placed + 1] = {item = item, x = x, y = y, w = w, h = h}
			end
		end

		local overlaps = 0

		for i = 1, #placed do
			for j = i + 1, #placed do
				local a, b = placed[i], placed[j]

				if (a.x < b.x + b.w and b.x < a.x + a.w
				and a.y < b.y + b.h and b.y < a.y + a.h) then
					overlaps = overlaps + 1

					Line(string.format("   OVERLAP: %s (%d) and %s (%d)",
						a.item.name or a.item.uniqueID, a.item.id,
						b.item.name or b.item.uniqueID, b.item.id))
				end
			end
		end

		Line(string.format("   %d item(s), %d overlap(s)", #placed, overlaps))
	end
end)
