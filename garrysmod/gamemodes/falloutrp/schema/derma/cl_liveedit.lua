--[[
	The live editor - `/LiveEdit`.

	Three columns, which is the shape every configurer in this schema settles
	on and the one that fits the job: WHAT KIND of thing on the left, WHICH one
	in the middle, and its fields on the right.

	NOTHING HERE KNOWS WHAT A WEAPON IS. The sections come from
	`ix.live.Sections`, the list from a kind's `List`, and the rows from its
	`fields` - so adding "every ammunition type" to the editor is a table in
	`sh_livekinds.lua` and no change at all to this file. It is the same
	arrangement as the crosshair menu and for the same reason.

	AN EDITED FIELD IS MARKED, and so is a subject with any edit on it: the
	first question anybody asks a live editor a week later is "what did I
	change", and a screen of four hundred weapons cannot answer that unless it
	says so on the rows.
]]

local PANEL = {}

local function Scaled(value)
	return math.Round(value * ix.fallout.GetFontScale())
end

function PANEL:Init()
	if (IsValid(ix.gui.liveEdit)) then
		ix.gui.liveEdit:Remove()
	end

	ix.gui.liveEdit = self

	if (ix.fallout.LoadMenuFonts) then
		ix.fallout.LoadMenuFonts()
	end

	self:SetSize(math.min(ScrW() - Scaled(60), Scaled(1280)),
		math.min(ScrH() - Scaled(60), Scaled(840)))
	self:Center()
	self:MakePopup()
	self:SetTitle("LIVE EDITOR")

	self.section = ix.live.Sections()[1]
	self.filter = ""

	self:BuildFooter()
	self:BuildNav()
	self:BuildList()
	self:BuildFields()

	self:Rebuild()
end

function PANEL:Say(text)
	if (IsValid(self.hint)) then self.hint:SetText(text) end
end

function PANEL:BuildFooter()
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
	self.hint:DockMargin(Scaled(6), 0, Scaled(6), 0)
	self.hint:SetContentAlignment(4)
	self.hint:SetFont("ixLootSmall")
	self.hint:SetText("Every change is live, for everybody, and saved. "
		.. "RESET puts a field back to what its file says.")
end

function PANEL:BuildNav()
	local nav = self:Add("Panel")

	nav:Dock(LEFT)
	nav:SetWide(Scaled(190))

	self.navButtons = {}

	for _, section in ipairs(ix.live.Sections()) do
		local button = nav:Add("ixFOButton")

		button:Dock(TOP)
		button:SetTall(Scaled(40))
		button:DockMargin(0, 0, 0, Scaled(4))
		button:SetText(section.name)
		button:SetContentAlignment(7)
		button:DockPadding(Scaled(6), Scaled(4), 0, 0)

		--- The subtitle is painted for the reason the dev terminal's is.
		button.PaintOver = function(panel, width, height)
			local palette = ix.fallout.GetPalette()
			local colour = (panel:IsHovered() or panel:GetActive())
				and palette.text_hover or palette.color_active

			draw.SimpleText(section.note or "", "ixLootSmall", Scaled(7),
				height - Scaled(5), colour, TEXT_ALIGN_LEFT,
				TEXT_ALIGN_BOTTOM)
		end

		button.DoClick = function()
			self.section = section
			self.subject = nil
			self.filter = ""

			if (IsValid(self.search)) then self.search:SetValue("") end

			self:Rebuild()
			ix.fallout.PlayUISound("select")
		end

		self.navButtons[section.id] = button
	end
end

function PANEL:BuildList()
	local column = self:Add("Panel")

	column:Dock(LEFT)
	column:SetWide(Scaled(320))
	column:DockMargin(Scaled(8), 0, Scaled(8), 0)

	self.search = column:Add("ixFOTextEntry")

	self.search:Dock(TOP)
	self.search:SetTall(Scaled(26))
	self.search:DockMargin(0, 0, 0, Scaled(6))
	self.search:SetUpdateOnType(true)
	self.search.OnValueChange = function(_, text)
		self.filter = string.lower(string.Trim(text or ""))

		self:BuildRows()
	end

	self.list = column:Add("ixFOScrollPanel")
	self.list:Dock(FILL)
end

function PANEL:BuildFields()
	self.fields = self:Add("ixFOScrollPanel")
	self.fields:Dock(FILL)
end

--------------------------------------------------------------------------------
-- The middle column
--------------------------------------------------------------------------------

function PANEL:Rebuild()
	for id, button in pairs(self.navButtons) do
		button:SetActive(self.section ~= nil and self.section.id == id)
	end

	self:BuildRows()
	self:BuildEditor()
end

function PANEL:BuildRows()
	self.list:Clear()

	if (not self.section) then return end

	local entries = self.section.List and self.section.List() or {}
	local shown = 0

	for _, entry in ipairs(entries) do
		if (self.filter ~= ""
		and not string.find(string.lower(entry.name), self.filter, 1, true)
		and not string.find(string.lower(entry.id), self.filter, 1, true)) then
			continue
		end

		shown = shown + 1

		--[[
			CAPPED, and the count below says by how much. Four hundred rows is
			four hundred panels rebuilt on every keystroke, and the search is
			the way through a list that long.
		]]
		if (shown > 150) then continue end

		local row = self.list:Add("ixFOButton")
		local edited = ix.live.IsEdited(self.section.id, entry.id)

		row:Dock(TOP)
		row:SetTall(Scaled(38))
		row:DockMargin(0, 0, Scaled(4), Scaled(3))
		row:SetText("")
		row:SetActive(self.subject == entry.id)

		row.PaintOver = function(panel, width, height)
			local palette = ix.fallout.GetPalette()
			local active = panel:IsHovered() or panel:GetActive()

			draw.SimpleText(entry.name, "ixLootRow", Scaled(8), height * 0.3,
				active and palette.text_hover or palette.text_primary,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			draw.SimpleText(entry.note or entry.id, "ixLootSmall", Scaled(8),
				height * 0.72,
				active and palette.text_hover
					or ColorAlpha(palette.text_primary, 150),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			--- A dot for "something on this has been changed".
			if (edited) then
				surface.SetDrawColor(palette.color_active)
				surface.DrawRect(width - Scaled(12), height * 0.5 - Scaled(3),
					Scaled(6), Scaled(6))
			end
		end

		row.DoClick = function()
			self.subject = entry.id

			self:Rebuild()
		end
	end

	if (shown == 0) then
		local empty = self.list:Add("ixFOLabel")

		empty:Dock(TOP)
		empty:SetTall(Scaled(40))
		empty:SetContentAlignment(5)
		empty:SetFont("ixLootSmall")
		empty:SetText("Nothing matches that.")
	elseif (shown > 150) then
		local more = self.list:Add("ixFOLabel")

		more:Dock(TOP)
		more:SetTall(Scaled(30))
		more:SetContentAlignment(5)
		more:SetFont("ixLootSmall")
		more:SetText(string.format("Showing 150 of %d - search to narrow it.",
			shown))
	end
end

--------------------------------------------------------------------------------
-- The right column
--------------------------------------------------------------------------------

function PANEL:BuildEditor()
	self.fields:Clear()

	if (not self.section) then return end

	--- The menu section is a list, not a subject with fields; see `BuildTabs`.
	if (self.section.id == "menu") then
		self:BuildTabs()

		return
	end

	if (not self.subject) then
		local empty = self.fields:Add("ixFOLabel")

		empty:Dock(TOP)
		empty:SetTall(Scaled(60))
		empty:SetContentAlignment(5)
		empty:SetWrap(true)
		empty:SetFont("ixLootSmall")
		empty:SetText("Pick something on the left.")

		return
	end

	local kind = self.section

	if (not kind.Target or not kind.Target(self.subject)) then
		local gone = self.fields:Add("ixFOLabel")

		gone:Dock(TOP)
		gone:SetTall(Scaled(60))
		gone:SetContentAlignment(5)
		gone:SetWrap(true)
		gone:SetFont("ixLootSmall")
		gone:SetText("That is not registered any more.")

		return
	end

	local header = self.fields:Add("ixFOLabel")

	header:Dock(TOP)
	header:SetTall(Scaled(26))
	header:SetFont("UI_Bold")
	header:SetText(string.upper(self.subject))

	for _, field in ipairs(ix.live.Fields(kind, self.subject)) do
		self:AddField(kind, field)
	end

	--- Weapons carry a second half that is not a field on any table.
	if (kind.id == "weapon") then
		self:AddWeaponExtras()
	end
end

--[[
	One row.

	The control is chosen from the field's `kind`, the same way the crosshair
	menu chooses one - a number gets a box, a boolean a switch, a vector three
	boxes, a colour a mixer, a choice a row of buttons.
]]
function PANEL:AddField(kind, field)
	local row = self.fields:Add("ixFOPanelBracketed")
	local value = ix.live.Value(kind.id, self.subject, field)
	local overridden = ((ix.live.overrides[kind.id] or {})[self.subject]
		or {})[field.key] ~= nil

	row:Dock(TOP)
	row:SetTall(Scaled((field.kind == "vector" or field.kind == "angle")
		and 64 or (field.note and 54 or 40)))
	row:DockMargin(0, 0, Scaled(4), Scaled(4))
	row:DockPadding(Scaled(8), Scaled(5), Scaled(8), Scaled(5))
	row:SetNoOverdraw(true)

	local function Send(newValue, bReset)
		net.Start("ixLiveSet")
			net.WriteString(kind.id)
			net.WriteString(self.subject)
			net.WriteString(field.key)
			net.WriteBool(bReset == true)
			net.WriteType(newValue)
		net.SendToServer()

		--[[
			Redrawn on a delay rather than at once: the answer is the server's
			sync, and painting what was typed would show a number the server
			may have clamped.
		]]
		timer.Simple(0.25, function()
			if (IsValid(self)) then self:BuildEditor() end
		end)
	end

	--- RESET is offered only where there is something to put back.
	if (overridden) then
		local reset = row:Add("ixFOButton")

		reset:Dock(RIGHT)
		reset:SetWide(Scaled(64))
		reset:DockMargin(Scaled(4), 0, 0, 0)
		reset:SetText("RESET")
		reset:SetFont("ixLootSmall")
		reset:SetContentAlignment(5)
		reset.DoClick = function() Send(nil, true) end
	end

	if (field.kind == "bool") then
		local button = row:Add("ixFOButton")

		button:Dock(RIGHT)
		button:SetWide(Scaled(70))
		button:SetText(value and "ON" or "OFF")
		button:SetContentAlignment(5)
		button:SetActive(value == true)
		button.DoClick = function() Send(not value) end
	elseif (field.kind == "choice") then
		local choices = field.choices and field.choices() or {}

		for index = #choices, 1, -1 do
			local choice = choices[index]
			local button = row:Add("ixFOButton")

			button:Dock(RIGHT)
			button:SetWide(Scaled(76))
			button:DockMargin(Scaled(3), 0, 0, 0)
			button:SetText(string.upper(choice))
			button:SetFont("ixLootSmall")
			button:SetContentAlignment(5)
			button:SetActive(value == choice)
			button.DoClick = function() Send(choice) end
		end
	elseif (field.kind == "items") then
		--[[
			A LIST OF TICKS rather than a box: the value is a set of item ids
			and nobody should have to type one. Every item the field's filter
			admits is a toggle, sorted by name; the whole set is sent on every
			click, and the row grows to whatever the grid turns out to need.
			This branch lays out its own label and note, because the grid
			has to sit between them.
		]]
		local chosen = istable(value) and value or {}
		local items = {}

		for uniqueID, itemTable in pairs(ix.item.list) do
			if (not field.filter or field.filter(itemTable)) then
				items[#items + 1] = {id = uniqueID,
					name = itemTable.name or uniqueID}
			end
		end

		table.sort(items, function(a, b) return a.name < b.name end)

		local label = row:Add("ixFOLabel")

		label:Dock(TOP)
		label:SetTall(Scaled(18))
		label:SetFont("ixLootRow")
		label:SetText(string.format("%s  (%d ticked)%s", field.name,
			table.Count(chosen), overridden and "  *" or ""))
		label:SetTextColor(overridden and ix.fallout.GetPalette().color_active
			or ix.fallout.GetPalette().text_primary)

		if (field.note) then
			local note = row:Add("ixFOLabel")

			note:Dock(TOP)
			note:SetTall(Scaled(30))
			note:SetFont("ixLootSmall")
			note:SetTextColor(Color(160, 160, 150))
			note:SetWrap(true)
			note:SetText(field.note)
		end

		local grid = row:Add("DIconLayout")

		grid:Dock(TOP)
		grid:DockMargin(0, Scaled(4), 0, 0)
		grid:SetSpaceX(Scaled(4))
		grid:SetSpaceY(Scaled(4))

		for _, entry in ipairs(items) do
			local button = grid:Add("ixFOButton")

			button:SetSize(Scaled(150), Scaled(24))
			button:SetText(entry.name)
			button:SetFont("ixLootSmall")
			button:SetContentAlignment(5)
			button:SetActive(chosen[entry.id] == true)
			button.DoClick = function()
				local set = table.Copy(chosen)

				if (set[entry.id]) then
					set[entry.id] = nil
				else
					set[entry.id] = true
				end

				Send(set)
			end
		end

		--- As tall as the grid turns out to be.
		row.Think = function(this)
			local _, top = grid:GetPos()
			local want = top + grid:GetTall() + Scaled(8)

			if (math.abs(this:GetTall() - want) > 1) then
				this:SetTall(want)
				this:InvalidateParent(true)
			end
		end

		return
	elseif (field.kind == "vector" or field.kind == "colour"
	or field.kind == "angle") then
		--[[
			Three boxes, right to left, so they read x y z - docking RIGHT
			stacks in reverse child order.
		]]
		local boxes = {}

		for index = 3, 1, -1 do
			local entry = row:Add("ixFOTextEntry")

			entry:Dock(RIGHT)
			entry:SetWide(Scaled(64))
			entry:DockMargin(Scaled(3), 0, 0, 0)
			entry:SetValue(tostring(math.Round(tonumber(value[index]) or 0, 3)))

			boxes[index] = entry

			entry.OnEnter = function()
				Send({
					tonumber(boxes[1]:GetValue()) or 0,
					tonumber(boxes[2]:GetValue()) or 0,
					tonumber(boxes[3]:GetValue()) or 0
				})
			end
		end
	elseif (field.kind == "number") then
		local entry = row:Add("ixFOTextEntry")

		entry:Dock(RIGHT)
		entry:SetWide(Scaled(110))
		entry:SetValue(tostring(math.Round(tonumber(value) or 0,
			field.decimals or 2)))

		entry.OnEnter = function()
			Send(tonumber(entry:GetValue()) or 0)
		end
	else
		local entry = row:Add("ixFOTextEntry")

		entry:Dock(RIGHT)
		entry:SetWide(Scaled(220))
		entry:SetValue(tostring(value or ""))

		entry.OnEnter = function() Send(entry:GetValue()) end
	end

	local label = row:Add("ixFOLabel")

	label:Dock(TOP)
	label:SetTall(Scaled(18))
	label:SetFont("ixLootRow")
	label:SetText(field.name .. (overridden and "  *" or ""))
	label:SetTextColor(overridden and ix.fallout.GetPalette().color_active
		or ix.fallout.GetPalette().text_primary)

	if (not field.note) then return end

	local note = row:Add("ixFOLabel")

	note:Dock(FILL)
	note:SetFont("ixLootSmall")
	note:SetTextColor(Color(160, 160, 150))
	note:SetWrap(true)
	note:SetText(field.note)
end

--------------------------------------------------------------------------------
-- Weapons: the parts that are not fields on a table
--------------------------------------------------------------------------------

--[[
	The ironsight buttons, the quality ceiling and the hit multipliers.

	These are not fields on the SWEP - they are decisions the DAMAGE HOOK reads
	(`sh_livecombat.lua`) and a button that toggles somebody else's editor - so
	they are built here rather than being squeezed into the field table.
]]
function PANEL:AddWeaponExtras()
	local class = self.subject
	local itemTable

	for uniqueID, item in pairs(ix.item.list) do
		if (item.class == class) then
			itemTable = item
			itemTable.uniqueID = uniqueID

			break
		end
	end

	if (not itemTable) then return end

	local heading = self.fields:Add("ixFOLabel")

	heading:Dock(TOP)
	heading:SetTall(Scaled(28))
	heading:DockMargin(0, Scaled(6), 0, Scaled(2))
	heading:SetFont("UI_Bold")
	heading:SetText("IRONSIGHTS")

	local sights = self.fields:Add("ixFOPanelBracketed")

	sights:Dock(TOP)
	sights:SetTall(Scaled(40))
	sights:DockMargin(0, 0, Scaled(4), Scaled(4))
	sights:DockPadding(Scaled(8), Scaled(5), Scaled(8), Scaled(5))
	sights:SetNoOverdraw(true)

	local save = sights:Add("ixFOButton")

	save:Dock(RIGHT)
	save:SetWide(Scaled(110))
	save:DockMargin(Scaled(4), 0, 0, 0)
	save:SetText("SAVE SIGHTS")
	save:SetFont("ixLootSmall")
	save:SetContentAlignment(5)

	--[[
		The base's editor moves the numbers on the WEAPON somebody is holding
		and nowhere else - it is a tuning tool that prints its result. This
		reads them back off that weapon and stores them as overrides, which is
		the step it has never had.
	]]
	save.DoClick = function()
		local weapon = LocalPlayer():GetActiveWeapon()

		if (not IsValid(weapon) or weapon:GetClass() ~= class) then
			self:Say("Hold the weapon you are aiming to save its sights.")

			return
		end

		--[[
			BOTH TYPES, because they are not the same type.

			`IronSightsPos` is a Vector and `IronSightsAng` is an Angle. This
			used to test `isvector` for both and `continue` on anything else,
			so the angle was silently never saved - you could move the sights
			with the editor, press SAVE, and get the position back without the
			rotation.
		]]
		for _, key in ipairs({"IronSightsPos", "IronSightsAng"}) do
			local value = weapon[key]
			local numbers

			if (isvector(value)) then
				numbers = {value.x, value.y, value.z}
			elseif (isangle(value)) then
				numbers = {value.p, value.y, value.r}
			else
				continue
			end

			net.Start("ixLiveSet")
				net.WriteString("weapon")
				net.WriteString(class)
				net.WriteString(key)
				net.WriteBool(false)
				net.WriteType(numbers)
			net.SendToServer()
		end

		--[[
			SAVING IS FINISHING, so the editor is closed with it.

			The base's editor is a toggle and nothing else turns it off, so
			pressing SAVE left you still holding the gun with the movement keys
			still moving the sights - and the next thing you nudged was
			unsaved again. It is closed only if it is OPEN: the toggle would
			otherwise turn it ON for somebody who typed the numbers in by hand
			and pressed SAVE without ever using it.

			`longsword_ironsighteditor` is a networked bool the server sets, so
			the client can read the current state before deciding.
		]]
		local wasEditing = LocalPlayer():GetNWBool(
			"longsword_ironsighteditor", false)

		if (wasEditing) then
			RunConsoleCommand("longsword_ironsighteditor")
		end

		self:Say(wasEditing
			and "Sights saved, and the editor is closed."
			or "Sights saved from the weapon in your hands.")

		--- The boxes above still show what the sights were before this.
		timer.Simple(0.3, function()
			if (IsValid(self)) then self:BuildEditor() end
		end)
	end

	local edit = sights:Add("ixFOButton")

	edit:Dock(RIGHT)
	edit:SetWide(Scaled(110))
	edit:SetText("EDIT SIGHTS")
	edit:SetFont("ixLootSmall")
	edit:SetContentAlignment(5)
	edit.DoClick = function() ix.live.ToggleSights() end

	local note = sights:Add("ixFOLabel")

	note:Dock(FILL)
	note:SetFont("ixLootSmall")
	note:SetWrap(true)
	note:SetText("Hold the weapon, press EDIT SIGHTS, then move them with the "
		.. "movement keys.")

	--------------------------------------------------------------------------
	-- Hit multipliers and the quality ceiling
	--------------------------------------------------------------------------

	local combat = ix.combat.Get(itemTable.uniqueID)

	local combatHeading = self.fields:Add("ixFOLabel")

	combatHeading:Dock(TOP)
	combatHeading:SetTall(Scaled(28))
	combatHeading:DockMargin(0, Scaled(6), 0, Scaled(2))
	combatHeading:SetFont("UI_Bold")
	combatHeading:SetText("HIT MULTIPLIERS - " ..
		string.upper(ix.hitgroup.ProfileID(itemTable.uniqueID)))

	--[[
		The whole of it is edited and sent TOGETHER, because the three parts
		mean different things in combination - a static head with a scaled body
		is a real thing to want, and saving them one at a time would leave the
		weapon in states nobody asked for in between.
	]]
	local working = {
		scaled = combat.scaled and table.Copy(combat.scaled) or {},
		static = combat.static and table.Copy(combat.static) or {},
		rarity = combat.rarity and table.Copy(combat.rarity) or {},
		cap = combat.cap or 0
	}

	local function SendCombat()
		net.Start("ixLiveCombat")
			net.WriteString(itemTable.uniqueID)
			net.WriteTable({
				scaled = next(working.scaled) and working.scaled or nil,
				static = next(working.static) and working.static or nil,
				rarity = next(working.rarity) and working.rarity or nil,
				cap = working.cap
			})
		net.SendToServer()

		timer.Simple(0.25, function()
			if (IsValid(self)) then self:BuildEditor() end
		end)
	end

	local function MultiplierRow(label, store, note)
		local row = self.fields:Add("ixFOPanelBracketed")

		row:Dock(TOP)
		row:SetTall(Scaled(54))
		row:DockMargin(0, 0, Scaled(4), Scaled(4))
		row:DockPadding(Scaled(8), Scaled(5), Scaled(8), Scaled(5))
		row:SetNoOverdraw(true)

		for index = #ix.combat.groups, 1, -1 do
			local group = ix.combat.groups[index]
			local entry = row:Add("ixFOTextEntry")

			entry:Dock(RIGHT)
			entry:SetWide(Scaled(62))
			entry:DockMargin(Scaled(3), 0, 0, 0)
			entry:SetValue(store[group] and tostring(store[group]) or "")

			entry.OnEnter = function()
				local number = tonumber(entry:GetValue())

				store[group] = number

				SendCombat()
			end
		end

		local title = row:Add("ixFOLabel")

		title:Dock(TOP)
		title:SetTall(Scaled(18))
		title:SetFont("ixLootRow")
		title:SetText(label .. "   (head / body / limb)")

		local hint = row:Add("ixFOLabel")

		hint:Dock(FILL)
		hint:SetFont("ixLootSmall")
		hint:SetTextColor(Color(160, 160, 150))
		hint:SetWrap(true)
		hint:SetText(note)
	end

	MultiplierRow("Scaled", working.scaled,
		"replaces the shared profile for this weapon. Quality still "
		.. "multiplies on top. Blank uses the profile")

	MultiplierRow("Static", working.static,
		"quality is IGNORED entirely where one of these is set - the damage "
		.. "is what it says whatever the weapon rolled")

	local capRow = self.fields:Add("ixFOPanelBracketed")

	capRow:Dock(TOP)
	capRow:SetTall(Scaled(54))
	capRow:DockMargin(0, 0, Scaled(4), Scaled(4))
	capRow:DockPadding(Scaled(8), Scaled(5), Scaled(8), Scaled(5))
	capRow:SetNoOverdraw(true)

	local capEntry = capRow:Add("ixFOTextEntry")

	capEntry:Dock(RIGHT)
	capEntry:SetWide(Scaled(110))
	capEntry:SetValue(tostring(working.cap or 0))

	capEntry.OnEnter = function()
		working.cap = math.Clamp(tonumber(capEntry:GetValue()) or 0, 0, 10)

		SendCombat()
	end

	local capTitle = capRow:Add("ixFOLabel")

	capTitle:Dock(TOP)
	capTitle:SetTall(Scaled(18))
	capTitle:SetFont("ixLootRow")
	capTitle:SetText("Quality damage ceiling")

	local capHint = capRow:Add("ixFOLabel")

	capHint:Dock(FILL)
	capHint:SetFont("ixLootSmall")
	capHint:SetTextColor(Color(160, 160, 150))
	capHint:SetWrap(true)
	capHint:SetText("the highest multiplier quality may reach on this weapon. "
		.. "0 is no ceiling; Legendary is 1.4 and Pearlescent is 2")

	--------------------------------------------------------------------------
	-- The quality ladder, for this weapon alone
	--------------------------------------------------------------------------

	--[[
		WHAT EACH TIER IS WORTH ON THIS GUN.

		The ceiling above says "no further than this", which is a blunt answer
		to a question that is usually about shape rather than height: a minigun
		wants a FLAT ladder because it fires nine hundred rounds a minute, and a
		hunting rifle wants a steep one because a Pearlescent bolt-action is
		meant to be a story. Both are the same ceiling and completely different
		weapons.

		Each box is one tier's multiplier. BLANK MEANS THE SHARED LADDER, and
		that is what the greyed number in each box is showing - so a weapon
		nobody has touched here behaves exactly as it did, and a weapon with one
		tier set differs only in that tier.

		The ceiling still applies on top: `ix.combat.RarityDamage` takes the
		weapon's own number and then clamps it.
	]]
	local ladderHeading = self.fields:Add("ixFOLabel")

	ladderHeading:Dock(TOP)
	ladderHeading:SetTall(Scaled(28))
	ladderHeading:DockMargin(0, Scaled(6), 0, Scaled(2))
	ladderHeading:SetFont("UI_Bold")
	ladderHeading:SetText("QUALITY LADDER")

	local ladderNote = self.fields:Add("ixFOLabel")

	ladderNote:Dock(TOP)
	ladderNote:SetTall(Scaled(30))
	ladderNote:DockMargin(0, 0, Scaled(4), Scaled(4))
	ladderNote:SetFont("ixLootSmall")
	ladderNote:SetTextColor(Color(160, 160, 150))
	ladderNote:SetWrap(true)
	ladderNote:SetText("what each tier multiplies this weapon's damage by. "
		.. "Leave one blank to use the server-wide ladder, shown greyed out.")

	for _, tier in ipairs(ix.rarity.tiers) do
		local row = self.fields:Add("ixFOPanelBracketed")

		row:Dock(TOP)
		row:SetTall(Scaled(30))
		row:DockMargin(0, 0, Scaled(4), Scaled(3))
		row:DockPadding(Scaled(8), Scaled(4), Scaled(8), Scaled(4))
		row:SetNoOverdraw(true)

		local entry = row:Add("ixFOTextEntry")

		entry:Dock(RIGHT)
		entry:SetWide(Scaled(80))
		entry:SetValue(working.rarity[tier.id]
			and tostring(working.rarity[tier.id]) or "")

		--[[
			The shared ladder's number, in the box, in grey. A placeholder
			rather than a value: typing over it sets an override and clearing
			the box removes one, and the difference between "1.4 because that
			is the default" and "1.4 because somebody typed it" stays visible.
		]]
		entry:SetPlaceholderText(tostring(tier.damage or 1))

		entry.OnEnter = function()
			working.rarity[tier.id] = tonumber(entry:GetValue())

			SendCombat()
		end

		local name = row:Add("ixFOLabel")

		name:Dock(FILL)
		name:SetFont("ixLootRow")
		name:SetTextColor(tier.color or color_white)
		name:SetText(tier.name)
	end
end

--------------------------------------------------------------------------------
-- The menu tab order
--------------------------------------------------------------------------------

--[[
	One row per tab, with arrows.

	UP AND DOWN RATHER THAN DRAGGING, because there are four of them and a drag
	list is a thing that needs its own drop indicator, its own scroll handling
	and its own bugs. The whole order is sent on every move - see `ixLiveTabs`.
]]
function PANEL:BuildTabs()
	self.fields:Clear()

	local header = self.fields:Add("ixFOLabel")

	header:Dock(TOP)
	header:SetTall(Scaled(26))
	header:SetFont("UI_Bold")
	header:SetText("F1 MENU TAB ORDER")

	local note = self.fields:Add("ixFOLabel")

	note:Dock(TOP)
	note:SetFont("ixLootSmall")
	note:SetWrap(true)
	note:SetAutoStretchVertical(true)
	note:DockMargin(0, 0, 0, Scaled(6))
	note:SetText("Helix orders these alphabetically by their internal name, "
		.. "which is why the inventory sits in the middle. This is everybody's "
		.. "order, not yours - reopen the menu to see a change.")

	local order = ix.live.TabList()

	local function Send()
		net.Start("ixLiveTabs")
			net.WriteUInt(#order, 8)

			for _, name in ipairs(order) do
				net.WriteString(name)
			end
		net.SendToServer()

		timer.Simple(0.25, function()
			if (IsValid(self)) then self:BuildTabs() end
		end)
	end

	for index, name in ipairs(order) do
		local row = self.fields:Add("ixFOPanelBracketed")

		row:Dock(TOP)
		row:SetTall(Scaled(36))
		row:DockMargin(0, 0, Scaled(4), Scaled(4))
		row:DockPadding(Scaled(8), Scaled(5), Scaled(8), Scaled(5))
		row:SetNoOverdraw(true)

		--- Reversed: docking RIGHT stacks right to left in child order.
		local down = row:Add("ixFOButton")

		down:Dock(RIGHT)
		down:SetWide(Scaled(44))
		down:DockMargin(Scaled(3), 0, 0, 0)
		down:SetText("v")
		down:SetContentAlignment(5)
		down:SetDisabled(index >= #order)
		down.DoClick = function()
			order[index], order[index + 1] = order[index + 1], order[index]

			Send()
		end

		local up = row:Add("ixFOButton")

		up:Dock(RIGHT)
		up:SetWide(Scaled(44))
		up:SetText("^")
		up:SetContentAlignment(5)
		up:SetDisabled(index <= 1)
		up.DoClick = function()
			order[index], order[index - 1] = order[index - 1], order[index]

			Send()
		end

		local label = row:Add("ixFOLabel")

		label:Dock(FILL)
		label:SetContentAlignment(4)
		label:SetFont("ixLootRow")
		label:SetText(string.format("%d.  %s", index, string.upper(name)))
	end
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then self:Remove() end
end

vgui.Register("ixFOLiveEdit", PANEL, "ixFOFrame")
