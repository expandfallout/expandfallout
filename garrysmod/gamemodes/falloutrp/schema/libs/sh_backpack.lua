--[[
	Backpacks that hold things.

	Phoenix's backpacks were two things at once: the twelve coloured packs in
	`items/armor/` - armour for the `backpack` slot, drawn on the back - and
	a storage that lived in a server file the scrape does not have. After
	wearing one here they are two things SEPARATELY:

	    the coloured packs are COSMETIC. Armour, drawn on the back, holding
	    nothing. (`items/armor/sh_armor_*_backpack_*.lua`)

	    the Small, Medium and Large backpacks are BAGS. Helix's own
	    `base_bags`, on the classic backpack model, taking 1x1, 2x2 and 2x3
	    of the inventory and holding a container whose size is a config -
	    the dev config's "Backpacks" block. They open on a click or with
	    Open on the right-click menu, and can be named (`sh_rename.lua`).
	    (`items/bags/sh_backpack_*.lua`)

	`ix.backpack.Bag(ITEM, size)` at the bottom of each bag item is the part
	that is not Helix's: the config-driven size, the growing, the naming,
	and the bin.

	SIZES ARE READ WHEN A BAG IS MADE and again when one is sent to its
	owner: a config raised later grows every existing pack the next time it
	loads; one lowered leaves existing packs alone, because shrinking an
	inventory with things in it loses them.
]]

ix.backpack = ix.backpack or {}

ix.backpack.sizes = {
	small = {name = "Small", width = "backpackSmallWidth",
		height = "backpackSmallHeight"},
	medium = {name = "Medium", width = "backpackMediumWidth",
		height = "backpackMediumHeight"},
	large = {name = "Large", width = "backpackLargeWidth",
		height = "backpackLargeHeight"}
}

local function OnChange()
	if (ix.backpack.Register) then ix.backpack.Register() end
end

for _, size in pairs(ix.backpack.sizes) do
	local defaults = {small = {4, 2}, medium = {5, 3}, large = {6, 4}}
	local key = size.name:lower()

	ix.config.Add(size.width, defaults[key][1],
		size.name .. " backpack: slots across.", OnChange,
		{data = {min = 1, max = 12}, category = "Backpacks"})
	ix.config.Add(size.height, defaults[key][2],
		size.name .. " backpack: slots down.", OnChange,
		{data = {min = 1, max = 8}, category = "Backpacks"})
end

--- Width and height for a size name, from the configs.
function ix.backpack.Size(kind)
	local size = ix.backpack.sizes[kind] or ix.backpack.sizes.small

	return ix.config.Get(size.width, 4), ix.config.Get(size.height, 2)
end

--- (Re)register every backpack's inventory type at the current sizes.
function ix.backpack.Register()
	for uniqueID, item in pairs(ix.item.list) do
		if (item.backpack) then
			local w, h = ix.backpack.Size(item.backpack)

			item.invWidth, item.invHeight = w, h
			ix.inventory.Register(uniqueID, w, h, true)
		end
	end
end

--- Grow an existing pack's inventory to the current config, never shrink.
local function Grow(inventory, kind)
	local w, h = ix.backpack.Size(kind)

	if (inventory.w < w or inventory.h < h) then
		inventory:SetSize(math.max(inventory.w, w), math.max(inventory.h, h))
	end
end

--[[
	Make a `base_bags` item a backpack of one size. Called at the bottom of
	the item file, so the item already carries Helix's bag - `View`,
	`combine`, `OnInstanced`, `OnSendData`, the drop and removal hooks -
	and this only adds to it.
]]
function ix.backpack.Bag(ITEM, kind)
	kind = ix.backpack.sizes[kind] and kind or "small"

	ITEM.backpack = kind
	ITEM.isBag = true
	ITEM.invWidth, ITEM.invHeight = ix.backpack.Size(kind)

	ix.inventory.Register(ITEM.uniqueID, ITEM.invWidth, ITEM.invHeight, true)

	local size = ix.backpack.sizes[kind]

	--[[
		THE SIZE IS IN THE DESCRIPTION, read live - a config raised after
		the item loaded should say the new number, and a description built
		once at load would not.
	]]
	local describe = ITEM.GetDescription

	function ITEM:GetDescription()
		local base = describe and describe(self) or self.description or ""
		local w, h = ix.backpack.Size(kind)

		return string.format("%s\n\n%s pack: %dx%d of storage.", base,
			size.name, w, h)
	end

	--[[
		Helix's own View, called "Open", opened OUR way on the client: Helix
		parents the window to the menu's tile canvas, which this schema's
		menu pads down to the main grid's exact size, so the window was
		laid out below the visible edge. `cl_backpack.lua` puts it on the
		page beside the grid instead. Everything else - the checks, the
		storage case - is Helix's.
	]]
	if (ITEM.functions.View) then
		ITEM.functions.View.name = "Open"

		local view = ITEM.functions.View.OnClick

		ITEM.functions.View.OnClick = function(item)
			if (CLIENT and ix.backpack.Open) then
				ix.backpack.Open(item)

				return false
			end

			return view and view(item) or false
		end
	end

	--- Naming it. See `sh_rename.lua`.
	if (ix.rename) then
		ITEM.functions.Rename = ix.rename.Entry()
		ix.rename.Wrap(ITEM)
	end

	--[[
		GROWN TO THE CONFIG when it is sent to its owner, after Helix has
		found or restored it. A pack restored from the database on this
		very send is not in memory yet when this runs; it is grown on the
		next one.
	]]
	local send = ITEM.OnSendData

	function ITEM:OnSendData()
		if (send) then send(self) end

		local inventory = self.GetInventory and self:GetInventory()

		if (inventory and inventory.w) then Grow(inventory, kind) end
	end

	--[[
		INTO A CRATE, AND INTO THE BIN. Helix refuses a bag inside any
		storage - `nestedBags`, "you cannot put an inventory inside of a
		storage inventory" - because every container this schema makes
		carries `vars.isBag = true`, the flag Helix's own containers plugin
		sets. A bag's own inventory carries the flag too, but as its item's
		id (a STRING, from `ix.inventory.New`): that is the one case that
		stays refused, a pack inside a pack. A container - crate, stash,
		faction storage, bench, bin - takes a pack like anything else. The
		bag says so here, and the hook below says it for Helix.
	]]
	local canTransfer = ITEM.CanTransfer

	function ITEM:CanTransfer(oldInventory, newInventory)
		if (newInventory and ix.backpack.IsContainer(newInventory)) then
			return true
		end

		if (canTransfer) then return canTransfer(self, oldInventory, newInventory) end

		return true
	end
end

--- A container's inventory, as opposed to a bag's: flagged, but not by an item id.
function ix.backpack.IsContainer(inventory)
	local flag = inventory and inventory.vars and inventory.vars.isBag

	return flag == true
end

--[[
	A backpack may go in a container.

	Helix's own `GM:CanTransferItem` is skipped when a hook answers - and so
	are the schema's other listeners, in whatever order the engine runs
	them - so the check that matters is made here: the mover has to be
	somebody BOTH inventories are shown to. A storage's receivers are the
	people the server let open it, so membership and permission were
	settled when the window opened.
]]
local function Shown(inventory, client)
	if (not inventory or not inventory.GetReceivers) then return true end

	for _, v in ipairs(inventory:GetReceivers() or {}) do
		if (v == client) then return true end
	end

	return false
end

hook.Add("CanTransferItem", "ixBackpackContainer", function(item, curInv, inventory)
	if (not item or not item.backpack) then return end
	if (not ix.backpack.IsContainer(inventory)) then return end

	if (not SERVER) then return true end

	local client = item.GetOwner and item:GetOwner() or nil

	if (IsValid(client)) then
		if (not Shown(curInv, client) or not Shown(inventory, client)) then
			return false
		end
	end

	return true
end)

--- Sizes are re-read once everything has loaded, after every item registered.
hook.Add("InitializedSchema", "ixBackpack", function()
	ix.backpack.Register()
end)

--------------------------------------------------------------------------------
-- Not opened for you
--------------------------------------------------------------------------------

--[[
	Helix opens every bag in the inventory the moment the menu opens
	(`openBags`, on by default) - through the bag's own View, so it was
	these packs popping up unasked. Off, and off the options page: a pack
	opens on a click, or from its menu.
]]
ix.option.Add("openBags", ix.type.bool, false, {
	category = "general",
	hidden = function() return true end
})

--- The pack item whose storage this inventory is, or nil.
function ix.backpack.ItemOf(inventory)
	local id = inventory and inventory.GetID and inventory:GetID()

	if (not id) then return nil end

	for _, item in pairs(ix.item.instances) do
		if (item.backpack and item.GetData and item:GetData("id") == id) then
			return item
		end
	end
end
