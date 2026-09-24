--[[
	The order of the tabs in the F1 menu.

	Helix builds them with `SortedPairs`, so the order is alphabetical by the
	tab's internal name - "business", "help", "inv", "you" - which is an order
	nobody chose and which puts the inventory in the middle of the list.

	THE BUTTONS ARE RE-STACKED, NOT REBUILT. They are docked TOP inside the tab
	column, and docking order follows `SetZPos` - so a tab's position is one
	number per button and Helix's own `PopulateTabs` is left to build them
	exactly as it always did. Reimplementing that loop would mean owning a copy
	of every tab's creation, gating and default-selection logic for ever.

	The order is a SERVER setting, edited in `/liveedit` under MENU, because
	"where is the inventory" should be the same for everybody being helped
	through it.
]]

ix.live = ix.live or {}

--[[
	The known tabs, in the order they are shown when nobody has said otherwise.

	This is a DEFAULT rather than a fixed list: the real order is whatever the
	store says, and a tab that appears from a plugin nobody here knows about
	sorts after these, alphabetically, exactly as it does now.
]]
ix.live.tabDefaults = {"you", "inv", "business", "help"}

--- `[tab name] = position`, from the live editor.
ix.live.tabOrder = ix.live.tabOrder or {}

--[[
	Where a tab sits. Lower is further up the column.

	Anything with no position is pushed past everything that has one and keeps
	its alphabetical place among the others, which is what makes an unknown tab
	appear at the bottom rather than at a random point in the middle.
]]
function ix.live.TabPosition(name)
	local stored = ix.live.tabOrder[name]

	if (stored) then return stored end

	for index, id in ipairs(ix.live.tabDefaults) do
		if (id == name) then return index end
	end

	return 100
end

--[[
	EVERY TAB THAT REALLY EXISTS, asked of the menu itself.

	The list used to be four names written down here, which is why the editor
	showed four rows on a server whose F1 menu has seven: plugins add tabs
	through `CreateMenuButtons` and nothing here could know their names in
	advance. Running that hook is exactly what the menu does when it builds
	itself, so this is the same answer from the same source.

	Nothing is created by it - the hook fills a table of `{Create = function}`
	entries and the panels are only built when a tab is opened - so it is
	cheap enough to ask every time the editor is drawn.

	CLIENT ONLY: the menu is the client's, and the server has no menu to ask.
	The server keeps the written-down defaults, which it only needs for
	sorting anyway.
]]
function ix.live.RealTabs()
	if (not CLIENT) then return {} end

	local tabs = {}

	hook.Run("CreateMenuButtons", tabs)

	local out = {}

	for name in pairs(tabs) do out[#out + 1] = name end

	table.sort(out)

	return out
end

--[[
	The tabs to show in the editor, in their current order.

	WHAT EXISTS NOW, not what used to. The list is `RealTabs()` - the menu's own
	answer - and the written-down defaults are used only when that comes back
	empty, which is the server, where there is no menu to ask.

	A tab that has been REMOVED is therefore gone from the editor as well. It
	used to be listed anyway, from two directions: `tabDefaults` names four tabs
	whether or not they still exist, and `tabOrder` remembers a position for
	every tab anybody has ever reordered. Both outlived the tab itself, so the
	editor offered to reorder things that were not in the menu.

	The stored positions for those are left alone rather than cleaned up. They
	cost nothing, they are what makes a tab go back where it was if it is ever
	restored, and deleting somebody's arrangement because a plugin was
	temporarily off is not a trade worth making.
]]
function ix.live.TabList()
	local out = ix.live.RealTabs()

	if (#out == 0) then
		for _, name in ipairs(ix.live.tabDefaults) do
			out[#out + 1] = name
		end
	end

	table.sort(out, function(a, b)
		local left, right = ix.live.TabPosition(a), ix.live.TabPosition(b)

		if (left == right) then return a < b end

		return left < right
	end)

	return out
end

if (not CLIENT) then return end

--[[
	Wrapped once, when the panel exists. `vgui.GetControlTable` is the same door
	every other panel in this schema is patched through - see
	`fallout_ui/cl_panels.lua`.

	`ixFOMenu`, NOT `ixMenu`.

	This schema has its own menu panel - `fallout_ui/cl_menu.lua` - and Helix's
	is not the one on the screen. Patching theirs did nothing at all, which is
	worth remembering for anything else that reaches for a Helix panel by name:
	check which one this schema actually uses first.

	Its buttons are in `self.tabButtons` and carry `tabID`, and they are docked
	TOP inside the tab column - so a z position is all a reorder needs.
]]
local function Wrap()
	local PANEL = vgui.GetControlTable("ixFOMenu")

	if (not PANEL) then return false end
	if (PANEL.ixTabOrder) then return true end

	PANEL.ixTabOrder = true

	local original = PANEL.PopulateTabs

	--[[
		THE ARRAY IS THE ORDER, and z positions are not.

		This panel does not dock its tab buttons: `PerformLayout` walks
		`self.tabButtons` and calls `SetPos` on each in turn, so a button's
		place on screen is its INDEX IN THAT TABLE and nothing else. Setting a
		z position - which is what this did, and which is how it would work on
		a docked strip - was a real instruction that changed nothing, and the
		tab order silently did nothing at all.

		Sorting the array is therefore the whole fix. Everything else about the
		strip, including the widths and the centring, is left to the layout
		pass that was already there.
	]]
	function PANEL:PopulateTabs()
		original(self)

		table.sort(self.tabButtons or {}, function(a, b)
			local left = a.tabID and ix.live.TabPosition(a.tabID) or 100
			local right = b.tabID and ix.live.TabPosition(b.tabID) or 100

			--- Alphabetically among equals, which is Helix's own order.
			if (left == right) then
				return tostring(a.tabID) < tostring(b.tabID)
			end

			return left < right
		end)

		self:InvalidateLayout(true)
	end

	return true
end

if (not Wrap()) then
	local attempts = 0

	timer.Create("ixTabOrderWrap", 1, 10, function()
		attempts = attempts + 1

		if (Wrap()) then
			timer.Remove("ixTabOrderWrap")
		elseif (attempts >= 10) then
			ErrorNoHalt("[falloutrp] ixFOMenu never appeared - the F1 tab order "
				.. "is Helix's alphabetical one\n")
		end
	end)
end
