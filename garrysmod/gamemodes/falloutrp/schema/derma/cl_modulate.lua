--[[
	The modulate bench window.

	The suit you are wearing on the left, every kind of modulator on the right,
	each row saying which of the three things it is: already fitted, in your
	pockets and ready, or not owned.

	Phoenix's window is the same three states, plus a model preview of the
	character. There is no preview here: a modulator changes nothing visible, so
	a picture of your own armour would be a picture that never changes.

	EVERYTHING IS READ FROM YOUR OWN INVENTORY. The server checks it all again -
	see `sv_modulator.lua` - so this is a view, not a permission.
]]

local PANEL = {}

local function Scaled(value)
	return math.Round(value * ix.fallout.GetFontScale())
end

function PANEL:Init()
	if (IsValid(ix.gui.modulate)) then
		ix.gui.modulate:Remove()
	end

	ix.gui.modulate = self

	if (ix.fallout.LoadMenuFonts) then
		ix.fallout.LoadMenuFonts()
	end

	self:SetSize(math.min(ScrW() - Scaled(80), Scaled(820)),
		math.min(ScrH() - Scaled(80), Scaled(600)))
	self:Center()
	self:MakePopup()
	self:SetTitle("MODULATE")

	local footer = self:Add("Panel")

	footer:Dock(BOTTOM)
	footer:SetTall(Scaled(32))
	footer:DockMargin(0, Scaled(8), 0, 0)

	local close = footer:Add("ixFOButton")

	close:Dock(RIGHT)
	close:SetWide(Scaled(100))
	close:SetText("CLOSE")
	close:SetContentAlignment(5)
	close.DoClick = function() self:Remove() end

	self.hint = footer:Add("ixFOLabel")

	self.hint:Dock(FILL)
	self.hint:DockMargin(0, 0, Scaled(10), 0)
	self.hint:SetContentAlignment(4)
	self.hint:SetFont("ixLootSmall")
	self.hint:SetText("One of each kind per suit, and body armour only. "
		.. "A fitted modulator is not recoverable.")

	--- The suit, which is the whole left half because it is the subject.
	self.armor = self:Add("ixFOPanelBracketed")

	self.armor:Dock(LEFT)
	self.armor:SetWide(Scaled(300))
	self.armor:DockMargin(0, 0, Scaled(8), 0)
	self.armor:DockPadding(Scaled(10), Scaled(10), Scaled(10), Scaled(10))

	self.list = self:Add("ixFOScrollPanel")
	self.list:Dock(FILL)

	self:Rebuild()
end

function PANEL:SetBench(entity)
	self.entity = entity
	self.signature = self:Signature()

	self:Rebuild()
end

--[[
	Everything this window draws, as one string.

	THE WINDOW IS REBUILT WHEN THIS CHANGES AND AT NO OTHER TIME, which is the
	fix for it flickering. It used to rebuild once a second whatever had
	happened: every panel on it was destroyed and made again while somebody was
	reading it, so the row under the cursor lost its hover, a click could land
	on a button that had been replaced a frame earlier, and the whole thing
	twitched. Nothing here changes without the player doing something, so
	checking costs one walk of the inventory a second and the window is still.
]]
function PANEL:Signature()
	local character = LocalPlayer():GetCharacter()

	if (not character) then return "none" end

	local worn = ix.armor.GetEquipped(character).body
	local parts = {worn and tostring(worn.id) or "bare"}

	for uniqueID in SortedPairs(ix.modulator.Installed(worn)) do
		parts[#parts + 1] = uniqueID
	end

	local held = {}

	for item in ix.inventory.Each(character:GetInventory()) do
		if (item.isModulator) then
			held[item.uniqueID] = (held[item.uniqueID] or 0) + 1
		end
	end

	for uniqueID, count in SortedPairs(held) do
		parts[#parts + 1] = uniqueID .. "=" .. count
	end

	return table.concat(parts, "/")
end

function PANEL:Think()
	--- Nothing until `SetBench`, which is a frame after the window is made.
	if (not self.entity) then return end

	if (not IsValid(self.entity)) then
		self:Remove()

		return
	end

	if (self.nextCheck and CurTime() < self.nextCheck) then return end

	self.nextCheck = CurTime() + 0.25

	local signature = self:Signature()

	if (signature == self.signature) then return end

	self.signature = signature

	self:Rebuild()
end

function PANEL:Rebuild()
	local character = LocalPlayer():GetCharacter()
	local inventory = character and character:GetInventory()
	local scroll = self.list:GetVBar():GetScroll()

	--[[
		`ix.armor.GetEquipped` is shared and keyed by slot, so the suit this
		window is about is the same table the resistance sums read - rather
		than a second search here that could disagree with the server's.
	]]
	self.worn = ix.armor.GetEquipped(character).body

	self:BuildArmor()

	self.list:Clear()

	--- How many of each kind are in your pockets, counted once for every row.
	local held = {}

	for item in ix.inventory.Each(inventory) do
		if (item.isModulator) then
			held[item.uniqueID] = (held[item.uniqueID] or 0) + 1
		end
	end

	local fitted = ix.modulator.Installed(self.worn)

	for _, itemTable in ipairs(ix.modulator.Kinds()) do
		self:AddKind(itemTable, fitted[itemTable.uniqueID],
			held[itemTable.uniqueID] or 0)
	end

	self.list:InvalidateLayout(true)
	self.list:GetVBar():SetScroll(scroll)
end

--- The left half: what is being modulated, and what is already in it.
function PANEL:BuildArmor()
	self.armor:Clear()

	local title = self.armor:Add("ixFOLabel")

	title:Dock(TOP)
	title:SetTall(Scaled(24))
	title:SetFont("UI_Bold")
	title:SetText(self.worn and string.upper(self.worn.name or "ARMOUR")
		or "NOTHING WORN")

	local note = self.armor:Add("ixFOLabel")

	note:Dock(TOP)
	note:SetFont("ixLootSmall")
	note:SetWrap(true)
	note:SetAutoStretchVertical(true)
	note:DockMargin(0, 0, 0, Scaled(8))
	note:SetText(self.worn and "Fitted to this suit:"
		or "Put on a suit of body armour. A modulator goes into the armour "
			.. "you are wearing, not into a spare one in your pockets.")

	if (not self.worn) then return end

	local lines = ix.modulator.Lines(self.worn)

	if (#lines < 1) then
		local empty = self.armor:Add("ixFOLabel")

		empty:Dock(TOP)
		empty:SetFont("ixLootSmall")
		empty:SetWrap(true)
		empty:SetAutoStretchVertical(true)
		empty:SetTextColor(ix.fallout.GetPalette().color_active)
		empty:SetText("Nothing yet.")

		return
	end

	for _, line in ipairs(lines) do
		local row = self.armor:Add("ixFOLabel")

		row:Dock(TOP)
		row:SetFont("ixLootSmall")
		row:SetWrap(true)
		row:SetAutoStretchVertical(true)
		row:DockMargin(0, 0, 0, Scaled(2))
		row:SetTextColor(ix.fallout.GetPalette().color_primary)
		row:SetText(line)
	end
end

--[[
	One modulator kind.

	THE STATE IS ON THE ROW, not only on the button - a disabled button with no
	explanation is the thing people report as "the bench is broken". Every row
	says which of the three cases it is and why.
]]
function PANEL:AddKind(itemTable, bFitted, count)
	local row = self.list:Add("ixFOPanelBracketed")

	row:Dock(TOP)
	row:SetTall(Scaled(50))
	row:DockMargin(0, 0, Scaled(4), Scaled(4))
	row:DockPadding(Scaled(8), Scaled(5), Scaled(8), Scaled(5))
	row:SetNoOverdraw(true)

	local ready = not bFitted and count > 0 and self.worn ~= nil

	local button = row:Add("ixFOButton")

	button:Dock(RIGHT)
	button:SetWide(Scaled(90))
	button:SetText(bFitted and "FITTED" or "FIT")
	button:SetContentAlignment(5)
	button:SetDisabled(not ready)
	button.DoClick = function()
		if (not ready or not IsValid(self.entity)) then return end

		net.Start("ixModulate")
			net.WriteEntity(self.entity)
			net.WriteString(itemTable.uniqueID)
		net.SendToServer()

		--[[
			Nothing is drawn as done here. The modulator leaving your pockets
			and appearing on the suit is what redraws this, through
			`Signature` - so what the window shows is what the SERVER did,
			rather than what it was asked to do.
		]]
	end

	local name = row:Add("ixFOLabel")

	name:Dock(TOP)
	name:SetTall(Scaled(18))
	name:SetFont("ixLootRow")
	name:SetText(itemTable.name or itemTable.uniqueID)

	local state

	if (bFitted) then
		state = "already in this suit"
	elseif (not self.worn) then
		state = "no armour worn"
	elseif (count > 0) then
		state = string.format("%d in your pockets", count)
	else
		state = "you have none"
	end

	local note = row:Add("ixFOLabel")

	note:Dock(FILL)
	note:SetFont("ixLootSmall")
	note:SetTextColor(ready and ix.fallout.GetPalette().color_primary
		or Color(160, 160, 150))
	note:SetWrap(true)
	note:SetText(string.format("%s - %s", ix.modulator.Line(itemTable), state))
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then self:Remove() end
end

vgui.Register("ixFOModulate", PANEL, "ixFOFrame")
