--[[
	`ITEM.bodygroups`, which Helix does not have.

	Helix supports a `skin` on an item and nothing else: `ENT:SetItem` does
	`SetSkin(itemTable:GetSkin())`, and the inventory icon takes a skin as its
	second argument. There is no equivalent for bodygroups.

	THE ORES NEED IT. All seven are one model - the mining addon's
	`zrms_resource.mdl` - with a bodygroup per kind, so without this every ore in
	the game is the same lump of rock in the inventory and on the floor.

	    ITEM.bodygroups = {[0] = 3}

	is "bodygroup 0, option 3". A table rather than a single number because a
	model may have several groups, and an item that needs two is otherwise a
	second feature.

	TWO PLACES HAVE TO BE TOLD, and they are both wraps rather than edits:

	    the dropped entity   `ix_item:SetItem`, on the server - bodygroups are
	                         networked entity state, so setting it there is
	                         enough for everybody to see it
	    the inventory icon   `ixItemIcon:SetItemTable`, on the client, which is
	                         called immediately after the panel's model is set
]]

ix.item = ix.item or {}

--- Apply an item's bodygroups to any entity. Safe on anything, including nil.
function ix.item.ApplyBodygroups(entity, itemTable)
	if (not IsValid(entity) or not itemTable) then return end

	local groups = itemTable.bodygroups

	if (not istable(groups)) then return end

	for index, value in pairs(groups) do
		index = tonumber(index)
		value = tonumber(value)

		if (index and value) then entity:SetBodygroup(index, value) end
	end
end

if (SERVER) then
	--[[
		The dropped item.

		Wrapped by name on the stored entity table, which is the same trick the
		keys and the cuffs addon get - `scripted_ents.GetStored` hands back the
		table every new `ix_item` is built from, so this reaches every one of
		them without the file being touched.
	]]
	local function Wrap()
		local stored = scripted_ents.GetStored("ix_item")
		local table_ = stored and stored.t

		if (not table_ or not table_.SetItem) then return false end
		if (table_.ixBodygroups) then return true end

		table_.ixBodygroups = true

		local original = table_.SetItem

		function table_:SetItem(itemID)
			original(self, itemID)

			ix.item.ApplyBodygroups(self, ix.item.instances[itemID])
		end

		return true
	end

	if (not Wrap()) then
		timer.Create("ixItemBodygroups", 1, 10, function()
			if (Wrap()) then timer.Remove("ixItemBodygroups") end
		end)
	end

	return
end

--[[
	The inventory icon.

	`ixInventory:AddIcon` sets the model and then the item table, in that order,
	so this runs with the panel's entity already built - which is why it hangs
	off `SetItemTable` rather than `SetModel`, whose caller does not know which
	item it is drawing.
]]
local function WrapIcon()
	local PANEL = vgui.GetControlTable("ixItemIcon")

	if (not PANEL or not PANEL.SetItemTable) then return false end
	if (PANEL.ixBodygroups) then return true end

	PANEL.ixBodygroups = true

	local original = PANEL.SetItemTable

	function PANEL:SetItemTable(itemTable)
		original(self, itemTable)

		ix.item.ApplyBodygroups(self.Entity, itemTable)
	end

	return true
end

--- The same retry the bin's money wrap uses; there is no "derma is ready" hook.
if (not WrapIcon()) then
	timer.Create("ixItemBodygroupIcons", 1, 10, function()
		if (WrapIcon()) then timer.Remove("ixItemBodygroupIcons") end
	end)
end
