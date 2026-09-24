--[[
	The looting window.

	A list of what is in the container, click to take. Phoenix used a tetris
	grid - their `FakeInventory` places each item at an x/y with a width and
	height - which looks like an inventory but is doing something a container
	does not need: you are not arranging loot, you are emptying it.

	So this is a list. It shows what the grid could not - the item's real name,
	how many there are and what it is - and it never has to tell a player their
	loot did not fit in the box it was already in.

	The window closes on distance, because a container you walked away from
	should not still be lootable.
]]

local PANEL = {}

local function Scaled(value)
	return math.Round(value * ix.fallout.GetFontScale())
end

function PANEL:Init()
	if (IsValid(ix.gui.loot)) then
		ix.gui.loot:Remove()
	end

	ix.gui.loot = self

	self:SetSize(Scaled(420), Scaled(460))
	self:Center()
	self:MakePopup()
	self:SetTitle("CONTAINER")

	local footer = self:Add("Panel")

	footer:Dock(BOTTOM)
	footer:SetTall(Scaled(34))
	footer:DockMargin(0, Scaled(8), 0, 0)

	local close = footer:Add("ixFOButton")

	close:Dock(RIGHT)
	close:SetWide(Scaled(110))
	close:SetText("CLOSE")
	close.DoClick = function()
		self:Remove()
	end

	self.hint = footer:Add("ixFOLabel")
	self.hint:Dock(FILL)
	self.hint:SetContentAlignment(4)
	self.hint:SetText("Click an item to take it.")

	self.list = self:Add("ixFOScrollPanel")
	self.list:Dock(FILL)
end

function PANEL:SetEntity(entity)
	self.entity = entity
end

--[[
	Rebuilt whenever the server sends contents, which it does on open and after
	every take by anyone looking at the same container.
]]
function PANEL:SetContents(contents)
	self.list:Clear()

	local remaining = 0

	for index, entry in ipairs(contents) do
		if ((entry.count or 0) > 0) then
			remaining = remaining + 1
			self:AddRow(index, entry)
		end
	end

	if (remaining == 0) then
		local label = self.list:Add("ixFOLabel")

		label:Dock(TOP)
		label:SetTall(Scaled(28))
		label:SetContentAlignment(5)
		label:SetText("Empty.")
	end
end

function PANEL:AddRow(index, entry)
	local itemTable = ix.item.list[entry.uniqueID]

	if (not itemTable) then return end

	local row = self.list:Add("ixFOPanelBracketed")

	row:Dock(TOP)
	row:SetTall(Scaled(42))
	row:DockMargin(0, 0, 0, Scaled(4))
	row:DockPadding(Scaled(6), Scaled(6), Scaled(6), Scaled(6))
	row:SetNoOverdraw(true)

	local take = row:Add("ixFOButton")

	take:Dock(RIGHT)
	take:SetWide(Scaled(70))
	take:DockMargin(Scaled(4), 0, 0, 0)
	take:SetText("TAKE")
	--[[
		Centred. `ixFOButton` defaults to left alignment, which is right for a
		wide button with a label and wrong for a narrow one with a verb: the
		word sat against the left edge of its box with the highlight extending
		past it on the other side.
	]]
	take:SetContentAlignment(5)
	take.DoClick = function()
		if (not IsValid(self.entity)) then return end

		net.Start("ixLootTake")
			net.WriteEntity(self.entity)
			net.WriteUInt(index, 8)
		net.SendToServer()

		--[[
			No click sound here. The server emits the item's own pickup sound
			once it knows the take actually succeeded, and playing a UI blip on
			the way out would put two noises on one action - one of which fires
			even when the take is refused for lack of room.
		]]
	end

	local label = row:Add("ixFOLabel")

	label:Dock(FILL)
	label:SetContentAlignment(4)
	label:SetText(entry.count > 1
		and string.format("%s x%d", itemTable.name, entry.count)
		or itemTable.name)

	row.PaintOver = function(_, width, height)
		draw.SimpleText(itemTable.category or "Item", "UI_Small",
			Scaled(8), height - Scaled(6),
			ix.fallout.GetPalette().color_active, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
	end
end

--[[
	Walking away closes it. Checked here rather than trusted to the player,
	and the server enforces the same distance on every take - this is the
	courtesy, that is the rule.
]]
function PANEL:Think()
	if (not IsValid(self.entity)
	or LocalPlayer():GetPos():DistToSqr(self.entity:GetPos()) > 170 * 170) then
		self:Remove()
	end
end

function PANEL:OnRemove()
	if (IsValid(self.entity)) then
		net.Start("ixLootClose")
			net.WriteEntity(self.entity)
		net.SendToServer()
	end
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Remove()
	end
end

vgui.Register("ixFOLoot", PANEL, "ixFOFrame")

net.Receive("ixLootOpen", function()
	local entity = net.ReadEntity()
	local count = net.ReadUInt(8)
	local contents = {}

	for i = 1, count do
		contents[i] = {
			uniqueID = net.ReadString(),
			count = net.ReadUInt(8)
		}
	end

	if (not IsValid(entity)) then return end

	--[[
		Reused when already open, so a take does not close and reopen the
		window under the cursor.
	]]
	local panel = IsValid(ix.gui.loot) and ix.gui.loot or vgui.Create("ixFOLoot")

	if (not IsValid(panel)) then return end

	panel:SetEntity(entity)
	panel:SetContents(contents)
end)
