--[[
	`/audit` - every character on one account, and what may be done to them.

	The list on the left, one character's details on the right, and two buttons
	that open their storage next to your own. See `libs/sv_audit.lua` for where
	any of it comes from.

	EVERY FIELD IS EDITABLE IN PLACE. There is no save button: a field commits
	when you press enter in it, the server answers with the whole list again,
	and the window redraws from that. A save button on a window that can change
	six things about forty characters is a save button somebody forgets.
]]

local PANEL = {}

local function Scaled(value)
	return math.max(math.Round(value * (ScrH() / 1080)), 1)
end

function PANEL:Init()
	self:SetSize(math.min(ScrW() - Scaled(80), Scaled(1180)),
		math.min(ScrH() - Scaled(60), Scaled(760)))
	self:Center()
	self:MakePopup()
	self:SetTitle("AUDIT")

	--[[
		A CONTENT PANEL, never the frame itself - `ixFOFrame` hides DFrame's
		close button and paints its own title, and clearing the frame takes
		both with it. See `cl_raidstats.lua`, which learned that loudly.
	]]
	self.content = self:Add("Panel")
	self.content:Dock(FILL)
	self.content:DockMargin(Scaled(8), Scaled(28), Scaled(8), Scaled(4))

	local close = self:Add("ixFOButton")

	close:Dock(BOTTOM)
	close:SetTall(Scaled(30))
	close:DockMargin(Scaled(8), Scaled(4), Scaled(8), Scaled(8))
	close:SetText("CLOSE")
	close:SetFont("ixLootHeader")
	close:SetContentAlignment(5)
	close.DoClick = function() self:Remove() end

	self.list = self.content:Add("ixFOScrollPanel")
	self.list:Dock(LEFT)
	self.list:SetWide(Scaled(360))

	self.detail = self.content:Add("ixFOScrollPanel")
	self.detail:Dock(FILL)
	self.detail:DockMargin(Scaled(8), 0, 0, 0)

	ix.gui.audit = self
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then self:Remove() end
end

function PANEL:Setup(steamID64, characters)
	self.steamID64 = steamID64
	self.characters = characters

	--[[
		The character that was open stays open across a refresh - every edit
		round-trips through the server and comes back as a whole new list, and
		a window that jumped back to the top after every change would be a
		window nobody could set two fields in.
	]]
	local keep = self.selected

	self:BuildList()

	for _, character in ipairs(characters) do
		if (character.id == keep) then
			self:ShowCharacter(character)

			return
		end
	end

	self:ShowCharacter(characters[1])
end

function PANEL:BuildList()
	self.list:Clear()

	local header = self.list:Add("ixFOLabel")

	header:Dock(TOP)
	header:SetTall(Scaled(24))
	header:SetFont("UI_Bold")
	header:SetText(string.format("%d CHARACTER(S)", #self.characters))

	local id = self.list:Add("ixFOLabel")

	id:Dock(TOP)
	id:SetTall(Scaled(20))
	id:SetFont("ixLootSmall")
	id:SetTextColor(Color(160, 160, 150))
	id:SetText(self.steamID64 or "")

	for _, character in ipairs(self.characters) do
		local faction = ix.faction.indices[character.faction]
		local row = self.list:Add("ixFOButton")

		row:Dock(TOP)
		row:SetTall(Scaled(44))
		row:DockMargin(0, 0, Scaled(6), Scaled(4))
		row:SetText("")
		row.DoClick = function() self:ShowCharacter(character) end

		row.PaintOver = function(_, width, height)
			draw.SimpleText(character.name, "ixLootRow", Scaled(8),
				height * 0.32, faction and faction.color or color_white,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			draw.SimpleText(string.format("#%d   level %d   %s caps",
				character.id, character.level,
				ix.util.FormatNumber and ix.util.FormatNumber(character.money)
					or character.money),
				"ixLootSmall", Scaled(8), height * 0.7,
				Color(170, 170, 160), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			--- Online is worth seeing at a glance: it changes what an edit does.
			if (character.online) then
				draw.SimpleText("ONLINE", "ixLootSmall", width - Scaled(8),
					height * 0.32, Color(120, 220, 120), TEXT_ALIGN_RIGHT,
					TEXT_ALIGN_CENTER)
			elseif (character.loadable == false) then
				--[[
					THE PLAYER CANNOT SEE THIS ONE. Its faction is not one this
					schema has, so Helix's character query skips the row - it is
					in the table and nowhere else.
				]]
				draw.SimpleText("UNLOADABLE", "ixLootSmall", width - Scaled(8),
					height * 0.32, Color(230, 120, 100), TEXT_ALIGN_RIGHT,
					TEXT_ALIGN_CENTER)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- One character
--------------------------------------------------------------------------------

--- A row with a label and something to type in.
function PANEL:Field(label, value, help, callback)
	local row = self.detail:Add("ixFOPanelBracketed")

	row:Dock(TOP)
	row:SetTall(Scaled(help and 54 or 40))
	row:DockMargin(0, 0, Scaled(4), Scaled(4))
	row:DockPadding(Scaled(8), Scaled(5), Scaled(8), Scaled(5))
	row:SetNoOverdraw(true)

	local entry = row:Add("ixFOTextEntry")

	entry:Dock(RIGHT)
	entry:SetWide(Scaled(220))
	entry:SetValue(tostring(value))
	entry.OnEnter = function()
		callback(entry:GetValue())
	end

	local title = row:Add("ixFOLabel")

	title:Dock(TOP)
	title:SetTall(Scaled(18))
	title:SetFont("ixLootRow")
	title:SetText(label)

	if (not help) then return row end

	local note = row:Add("ixFOLabel")

	note:Dock(FILL)
	note:SetFont("ixLootSmall")
	note:SetTextColor(Color(160, 160, 150))
	note:SetWrap(true)
	note:SetText(help)

	return row
end

function PANEL:Set(id, key, value)
	net.Start("ixAuditSet")
		net.WriteUInt(id, 32)
		net.WriteString(key)
		net.WriteType(value)
		net.WriteString(self.steamID64 or "")
	net.SendToServer()
end

function PANEL:ShowCharacter(character)
	self.detail:Clear()

	if (not character) then
		local empty = self.detail:Add("ixFOLabel")

		empty:Dock(TOP)
		empty:SetTall(Scaled(40))
		empty:SetFont("ixLootRow")
		empty:SetTextColor(Color(160, 160, 150))
		empty:SetText("That account has no characters.")

		return
	end

	self.selected = character.id

	local faction = ix.faction.indices[character.faction]

	local header = self.detail:Add("ixFOLabel")

	header:Dock(TOP)
	header:SetTall(Scaled(30))
	header:SetFont("UI_Bold")
	header:SetTextColor(faction and faction.color or color_white)
	header:SetText(string.format("%s   #%d", character.name, character.id))

	local subtitle = self.detail:Add("ixFOLabel")

	subtitle:Dock(TOP)
	subtitle:SetTall(Scaled(38))
	subtitle:SetFont("ixLootSmall")
	subtitle:SetTextColor(Color(160, 160, 150))
	subtitle:SetWrap(true)
	subtitle:SetText(string.format(
		"%s   -   race %s   -   made %s   -   last seen %s   -   %d implant(s)"
		.. "%s", faction and faction.name
			or ((character.factionName or "?") .. " (not a faction any more)"),
		character.race ~= "" and character.race or "unknown",
		character.created, character.seen, character.implants,
		character.banned and "   -   BANNED" or ""))

	--[[
		WHY IT IS NOT IN THEIR MENU, said plainly - this is the row somebody
		opens the audit to ask about, and "it does not exist for me any more"
		is what they say about it.
	]]
	if (character.loadable == false) then
		local warning = self.detail:Add("ixFOLabel")

		warning:Dock(TOP)
		warning:SetTall(Scaled(36))
		warning:DockMargin(0, 0, Scaled(4), Scaled(4))
		warning:SetFont("ixLootSmall")
		warning:SetTextColor(Color(230, 120, 100))
		warning:SetWrap(true)
		warning:SetText("THE PLAYER CANNOT LOAD THIS. Its faction is not one "
			.. "this schema has, so it never appears in their character list - "
			.. "but the row and everything it holds are still in the database. "
			.. "Give it a real faction below to bring it back, or delete it.")
	end

	--[[
		THE STORAGE BUTTONS FIRST, because they are why somebody opened this.

		Both open the auditor's own inventory alongside, so an item is dragged
		from one to the other exactly the way it is between a bag and a
		character - no transfer of our own, no rules to duplicate.
	]]
	local buttons = self.detail:Add("Panel")

	buttons:Dock(TOP)
	buttons:SetTall(Scaled(32))
	buttons:DockMargin(0, 0, Scaled(4), Scaled(8))

	local function Storage(text, bStash, tooltip)
		local button = buttons:Add("ixFOButton")

		button:Dock(LEFT)
		button:SetWide(Scaled(170))
		button:DockMargin(0, 0, Scaled(6), 0)
		button:SetText(text)
		button:SetFont("ixLootHeader")
		button:SetContentAlignment(5)
		button:SetTooltip(tooltip)
		button.DoClick = function()
			net.Start("ixAuditInventory")
				net.WriteUInt(character.id, 32)
				net.WriteBool(bStash)
			net.SendToServer()
		end
	end

	Storage("INVENTORY", false, "Open what they are carrying, next to yours.")
	Storage("STASH", true, "Open their stash, next to your inventory.")

	--[[
		DELETE, and it asks twice over: the button is red, the confirmation
		says what goes with it, and the server refuses while anybody is on the
		character. There is no undo and the audit is where orphans are found.
	]]
	local delete = buttons:Add("ixFOButton")

	delete:Dock(RIGHT)
	delete:SetWide(Scaled(150))
	delete:SetText("DELETE")
	delete:SetFont("ixLootHeader")
	delete:SetContentAlignment(5)
	delete:SetTooltip("Remove this character, its inventories and every item "
		.. "in them. Only while nobody is on it.")
	delete:SetDisabled(character.online)

	delete.DoClick = function()
		Derma_Query(string.format("Delete %s (#%d)?\n\nEverything it holds "
			.. "goes with it - the inventory, the stash and every item in "
			.. "them. There is no undo.", character.name, character.id),
			"DELETE CHARACTER?",

			"DELETE", function()
				net.Start("ixAuditDelete")
					net.WriteUInt(character.id, 32)
					net.WriteString(self.steamID64 or "")
				net.SendToServer()
			end,

			"CANCEL", function() end)
	end

	self:Field("Name", character.name, nil, function(value)
		self:Set(character.id, "name", value)
	end)

	self:Field("Caps", character.money,
		"what they are carrying. Not their stash, and not anything they have "
		.. "lent somebody", function(value)
			self:Set(character.id, "money", tonumber(value) or 0)
		end)

	self:Field("Level", character.level,
		"the experience floor for the new level comes with it, or the next "
		.. "kill would put the old one straight back", function(value)
			self:Set(character.id, "level", tonumber(value) or 1)
		end)

	self:Field("Experience", character.xp, nil, function(value)
		self:Set(character.id, "xp", tonumber(value) or 0)
	end)

	self:Field("Description", character.description or "", nil,
		function(value)
			self:Set(character.id, "description", value)
		end)

	--[[
		THE FACTION IS A LIST, not a box - it is the one field where a typo
		would put somebody in a faction that does not exist, and there are
		forty-five of them to remember the ids of.
	]]
	local factionRow = self.detail:Add("ixFOPanelBracketed")

	factionRow:Dock(TOP)
	factionRow:SetTall(Scaled(40))
	factionRow:DockMargin(0, 0, Scaled(4), Scaled(4))
	factionRow:DockPadding(Scaled(8), Scaled(5), Scaled(8), Scaled(5))
	factionRow:SetNoOverdraw(true)

	local combo = factionRow:Add("DComboBox")

	combo:Dock(RIGHT)
	combo:SetWide(Scaled(220))
	combo:SetValue(faction and faction.name or "none")

	for _, data in ipairs(ix.faction.indices) do
		combo:AddChoice(data.name, data.index)
	end

	combo.OnSelect = function(_, _, _, data)
		self:Set(character.id, "faction", data)
	end

	local factionLabel = factionRow:Add("ixFOLabel")

	factionLabel:Dock(TOP)
	factionLabel:SetTall(Scaled(18))
	factionLabel:SetFont("ixLootRow")
	factionLabel:SetText("Faction")
end

function PANEL:OnRemove()
	if (ix.gui.audit == self) then ix.gui.audit = nil end
end

vgui.Register("ixFOAudit", PANEL, "ixFOFrame")
