--[[
	The trade-up window.

	Everything on it is read from YOUR OWN inventory rather than sent by the
	server: a character's inventory is synced to them, item data included, so
	the client can group and count without a round trip - see
	`ix.tradeup.Groups`, which both realms call.

	The server checks the same thing again when the button is pressed. This
	window is a view, not a permission.
]]

local PANEL = {}

local function Scaled(value)
	return math.Round(value * ix.fallout.GetFontScale())
end

function PANEL:Init()
	if (IsValid(ix.gui.tradeup)) then
		ix.gui.tradeup:Remove()
	end

	ix.gui.tradeup = self

	if (ix.fallout.LoadMenuFonts) then
		ix.fallout.LoadMenuFonts()
	end

	self:SetSize(math.min(ScrW() - Scaled(80), Scaled(760)),
		math.min(ScrH() - Scaled(80), Scaled(600)))
	self:Center()
	self:MakePopup()
	self:SetTitle("TRADE UP")

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

	self.trade = footer:Add("ixFOButton")

	self.trade:Dock(LEFT)
	self.trade:SetWide(Scaled(140))
	self.trade:SetText("TRADE UP")
	self.trade:SetContentAlignment(5)
	self.trade:SetDisabled(true)
	self.trade.DoClick = function() self:Trade() end

	self.hint = footer:Add("ixFOLabel")

	self.hint:Dock(FILL)
	self.hint:DockMargin(Scaled(10), 0, Scaled(10), 0)
	self.hint:SetContentAlignment(4)
	self.hint:SetFont("ixLootSmall")

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

	THE WINDOW IS REBUILT WHEN THIS CHANGES AND AT NO OTHER TIME. A trade is
	answered by the five leaving your inventory and the new one arriving, which
	is its own message and does not come back through this window - so rather
	than inventing a "done" reply, the list notices. Rebuilding on a timer
	instead makes the window twitch under the cursor; see `cl_modulate.lua`,
	which had exactly that fault.
]]
function PANEL:Signature()
	local character = LocalPlayer():GetCharacter()

	if (not character) then return "none" end

	local parts = {}

	for _, group in ipairs(ix.tradeup.Groups(character:GetInventory())) do
		parts[#parts + 1] = string.format("%s.%s=%d", group.uniqueID,
			group.rarity, group.count)
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

	self.list:Clear()

	local amount = ix.tradeup.Amount()
	local cap = ix.tradeup.Cap()

	self.hint:SetText(string.format("%d of one kind and quality make one of "
		.. "the next, up to %s. Equipped weapons are left alone.",
		amount, cap.name))

	local groups = ix.tradeup.Groups(inventory)
	local chosen = nil

	for _, group in ipairs(groups) do
		local row = self:AddGroup(group, amount)

		if (self.selected and self.selected.uniqueID == group.uniqueID
		and self.selected.rarity == group.rarity) then
			chosen = group

			row:SetActive(true)
		end
	end

	--[[
		A selection that no longer exists is dropped rather than kept. It is
		what happens to the five that were just traded, and a button that stays
		lit on a row that is gone is a button that will refuse when pressed.
	]]
	self.selected = chosen

	self.trade:SetDisabled(not (chosen and chosen.ready))

	if (#groups < 1) then
		local empty = self.list:Add("ixFOLabel")

		empty:Dock(TOP)
		empty:SetTall(Scaled(60))
		empty:SetContentAlignment(5)
		empty:SetWrap(true)
		empty:SetFont("ixLootSmall")
		empty:SetText("Nothing here can be traded up. Only crafted weapons "
			.. "carry a quality, and only unequipped ones count.")
	end

	self.list:InvalidateLayout(true)
	self.list:GetVBar():SetScroll(scroll)
end

--- One kind-and-quality row.
function PANEL:AddGroup(group, amount)
	local row = self.list:Add("ixFOButton")

	row:Dock(TOP)
	row:SetTall(Scaled(42))
	row:DockMargin(0, 0, Scaled(4), Scaled(4))
	row:SetText("")
	row.DoClick = function()
		self.selected = group

		self:Rebuild()
	end

	local tier = ix.rarity.Tier(group.rarity)
	local nextTier = group.nextTier and ix.rarity.Tier(group.nextTier)

	row.PaintOver = function(panel, width, height)
		local palette = ix.fallout.GetPalette()
		local faded = ColorAlpha(palette.text_primary, 150)

		--- The quality's own colour, which is how the rarity reads everywhere.
		draw.SimpleText(group.name, "ixLootRow", Scaled(10), height * 0.32,
			ix.rarity.GetColor(group.rarity), TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)

		draw.SimpleText(string.format("%s - %d of %d", tier.name,
			group.count, amount), "ixLootSmall", Scaled(10), height * 0.72,
			group.ready and palette.color_primary or faded,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		local right = nextTier and ("makes " .. nextTier.name)
			or "at this bench's ceiling"

		draw.SimpleText(right, "ixLootSmall", width - Scaled(10),
			height * 0.5, nextTier and ix.rarity.GetColor(nextTier.id)
				or faded, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end

	return row
end

function PANEL:Trade()
	if (not self.selected or not IsValid(self.entity)) then return end

	net.Start("ixTradeUp")
		net.WriteEntity(self.entity)
		net.WriteString(self.selected.uniqueID)
		net.WriteString(self.selected.rarity)
	net.SendToServer()
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then self:Remove() end
end

vgui.Register("ixFOTradeUp", PANEL, "ixFOFrame")
