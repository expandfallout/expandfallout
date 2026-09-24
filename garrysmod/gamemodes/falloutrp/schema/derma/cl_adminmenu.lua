--[[
	The admin menu. `/admin`.

	    PLAYERS   who is on, their rank, and what can be done to them
	    LOGS      everything that has happened, filtered and searchable
	    GROUPS    the ladder, and what each rung may do
	    COMMANDS  every command, split into ours and the framework's

	EVERY SECTION IS GATED SEPARATELY. A helper opening this sees the player
	list and the chat log and nothing else - the tabs they cannot use are not
	drawn, rather than drawn and refused, because a button that always says no
	is worse than no button.

	IT ASKS THE SERVER FOR LOGS AND NOTHING ELSE. The player list and the
	command list are built from things the client already has; only the log is
	a query, because only the log is data the client is not entitled to by
	default.
]]

if (not CLIENT) then return end

local PANEL = {}

local function Scaled(value)
	return math.Round(value * ix.fallout.GetFontScale())
end

local function Row(parent, height)
	local row = parent:Add("DButton")

	row:Dock(TOP)
	row:SetTall(height)
	row:DockMargin(0, 0, 0, Scaled(2))
	row:SetText("")

	row.selected = false

	row.Paint = function(pnl, width, tall)
		local palette = ix.fallout.GetPalette()
		local colour = Color(30, 30, 36, 200)

		if (pnl.selected) then
			colour = Color(70, 58, 32, 255)
		elseif (pnl:IsHovered()) then
			colour = Color(56, 52, 40, 255)
		end

		surface.SetDrawColor(colour)
		surface.DrawRect(0, 0, width, tall)

		if (pnl.selected or pnl:IsHovered()) then
			surface.SetDrawColor(palette.color_primary)
			surface.DrawRect(0, 0, Scaled(3), tall)
		end

		if (pnl.PaintRow) then
			pnl:PaintRow(width, tall)
		end
	end

	return row
end

--- Which sections exist, and what each needs to be seen at all.
local SECTIONS = {
	{id = "players", name = "PLAYERS", permission = "player.list"},
	{id = "logs", name = "LOGS", permission = "log.view"},
	{id = "bans", name = "BANS", permission = "player.ban"},
	{id = "groups", name = "RANKS", permission = "player.list"},
	{id = "commands", name = "COMMANDS", permission = "player.list"}
}

function PANEL:Init()
	if (IsValid(ix.gui.adminMenu)) then
		ix.gui.adminMenu:Remove()
	end

	ix.gui.adminMenu = self

	ix.fallout.LoadMenuFonts()

	self:SetSize(math.min(ScrW() - Scaled(60), Scaled(1180)),
		math.min(ScrH() - Scaled(60), Scaled(720)))
	self:Center()
	self:MakePopup()
	self:SetTitle("ADMINISTRATION")

	self.section = nil
	self.results = {}
	self.filter = {}

	--[[
		Asked for once when the menu opens. Bans and warnings are pushed on
		join too, but somebody promoted mid-session has never had them - and
		opening this menu is the moment they matter.
	]]
	net.Start("ixPunishRequest")
	net.SendToServer()

	local footer = self:Add("Panel")

	footer:Dock(BOTTOM)
	footer:SetTall(Scaled(30))
	footer:DockMargin(0, Scaled(8), 0, 0)

	local close = footer:Add("ixFOButton")

	close:Dock(RIGHT)
	close:SetWide(Scaled(90))
	close:SetText("CLOSE")
	close:SetContentAlignment(5)
	close.DoClick = function() self:Remove() end

	self.hint = footer:Add("ixFOLabel")
	self.hint:Dock(FILL)
	self.hint:SetContentAlignment(4)
	self.hint:SetFont("ixLootSmall")
	self.hint:SetText(string.format("You are %s.",
		ix.admin.GetRank(LocalPlayer()).name))

	local nav = self:Add("Panel")

	nav:Dock(LEFT)
	nav:SetWide(Scaled(150))
	nav:DockMargin(0, 0, Scaled(10), 0)

	self.buttons = {}

	local first

	for _, section in ipairs(SECTIONS) do
		if (not ix.admin.Can(LocalPlayer(), section.permission)) then
			continue
		end

		local button = nav:Add("ixFOButton")

		button:Dock(TOP)
		button:SetTall(Scaled(30))
		button:DockMargin(0, 0, 0, Scaled(4))
		button:SetText(section.name)
		button.DoClick = function() self:SetSection(section.id) end

		self.buttons[section.id] = button
		first = first or section.id
	end

	--[[
		THE HORIZONTAL SLIDER LIVES ON THE FRAME, not in the content panel.

		`self.content` is a `DScrollPanel`, whose canvas grows to fit whatever
		is docked TOP inside it - so `Dock(BOTTOM)` and `Dock(FILL)` mean
		nothing there. A list docked FILL got zero height and drew no rows at
		all, and the slider docked BOTTOM appeared at the top, which is exactly
		what the screenshot showed.

		Docked after the footer, so it sits above it. Hidden unless the log
		section is open, because it steers nothing else.
	]]
	self.logSlider = self:Add("DSlider")
	self.logSlider:Dock(BOTTOM)
	self.logSlider:SetTall(Scaled(14))
	self.logSlider:DockMargin(0, Scaled(6), 0, 0)
	self.logSlider:SetLockY(0.5)
	self.logSlider:SetVisible(false)
	self.logSlider.Knob:SetVisible(false)

	self.logSlider.Paint = function(pnl, width, height)
		local palette = ix.fallout.GetPalette()

		surface.SetDrawColor(20, 20, 24, 200)
		surface.DrawRect(0, height * 0.5 - 2, width, 4)

		surface.SetDrawColor(palette.color_primary)
		surface.DrawRect(pnl:GetSlideX() * (width - Scaled(80)), 0,
			Scaled(80), height)
	end

	self.logSlider.OnValueChanged = function(pnl, x)
		self.logOffset = -x * (self.logRoom or 0)
	end

	self.content = self:Add("ixFOScrollPanel")
	self.content:Dock(FILL)

	if (first) then
		self:SetSection(first)
	else
		self:Say("You do not have access to any of this.")
	end
end

function PANEL:Say(text)
	self.hint:SetText(text)
end

function PANEL:SetSection(id)
	self.section = id

	--- Only the log scrolls sideways; see the note in `Init`.
	if (IsValid(self.logSlider)) then
		self.logSlider:SetVisible(id == "logs")
	end

	for sectionID, button in pairs(self.buttons) do
		button:SetActive(sectionID == id)
	end

	self:Populate()
end

function PANEL:Populate()
	self.content:Clear()

	if (self.section == "players") then
		self:PopulatePlayers()
	elseif (self.section == "logs") then
		self:PopulateLogs()
	elseif (self.section == "bans") then
		self:PopulateBans()
	elseif (self.section == "groups") then
		self:PopulateGroups()
	elseif (self.section == "commands") then
		self:PopulateCommands()
	end
end

--------------------------------------------------------------------------------
-- Players
--------------------------------------------------------------------------------

function PANEL:PopulatePlayers()
	local me = LocalPlayer()

	local players = player.GetAll()

	--[[
		Sorted by rank and then by name, so the staff are together at the top.
		Somebody scanning this list is usually looking for who is on duty.
	]]
	table.sort(players, function(a, b)
		local pa, pb = ix.admin.Power(a), ix.admin.Power(b)

		if (pa ~= pb) then return pa > pb end

		return a:Name() < b:Name()
	end)

	for _, target in ipairs(players) do
		local group = ix.admin.GetRank(target)
		local character = target:GetCharacter()
		local row = self.content:Add("ixFOPanelBracketed")

		row:Dock(TOP)
		row:SetTall(Scaled(44))
		row:DockMargin(0, 0, 0, Scaled(4))
		row:DockPadding(Scaled(8), Scaled(6), Scaled(8), Scaled(6))

		row.Paint = function(pnl, width, height)
			surface.SetDrawColor(30, 30, 36, 200)
			surface.DrawRect(0, 0, width, height)

			surface.SetDrawColor(group.color)
			surface.DrawRect(0, 0, Scaled(3), height)
		end

		row.PaintOver = function(pnl, width, height)
			local palette = ix.fallout.GetPalette()

			draw.SimpleText(target:Name(), "ixLootRow", Scaled(10),
				height * 0.3, palette.text_primary, TEXT_ALIGN_LEFT,
				TEXT_ALIGN_CENTER)

			draw.SimpleText(string.format("%s   %s   %s", group.name,
				target:SteamID(),
				character and character:GetName() or "no character"),
				"ixLootSmall", Scaled(10), height * 0.72,
				ColorAlpha(palette.text_primary, 150), TEXT_ALIGN_LEFT,
				TEXT_ALIGN_CENTER)

			--[[
				The warning count, where there is one.

				It is the single most useful thing to know before deciding what
				to do about somebody - "third time this week" is what turns a
				kick into a ban - and it is invisible everywhere else.

				Placed clear of the buttons, which dock RIGHT at 62 wide plus a
				4 margin and run to eight of them - and the eighth, WARNS, is
				the one that only appears when this text does.
			]]
			local warnings = ix.punish.Count(target:SteamID64())

			if (warnings > 0) then
				draw.SimpleText(warnings .. " warning(s)", "ixLootSmall",
					width - Scaled(560), height * 0.5, Color(230, 140, 60),
					TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end
		end

		--[[
			Reversed, because docking RIGHT stacks right-to-left in child
			order - the same reason the dev menu reverses its own buttons.
		]]
		local actions = {}

		if (ix.admin.Can(me, "rank.manage")
		and ix.admin.Outranks(me, target)) then
			actions[#actions + 1] = {text = "RANK", callback = function()
				self:OpenGroupPicker(target)
			end}
		end

		if (ix.admin.Can(me, "player.warn")
		and ix.admin.Outranks(me, target)) then
			actions[#actions + 1] = {text = "WARN", callback = function()
				Derma_StringRequest("Warn " .. target:Name(),
					"What for? They are told, and it stays on the record.", "",
					function(reason)
						if (string.Trim(reason) == "") then return end

						LocalPlayer():ConCommand(string.format(
							"say /warn \"%s\" %s", target:Name(), reason))
					end, function() end, "Warn", "Cancel")
			end}
		end

		--[[
			Only when there are any. A button that opens an empty list is a
			button that teaches people not to press it, and the count is already
			drawn on the row when it matters.
		]]
		if (ix.admin.Can(me, "player.warn")
		and ix.punish.Count(target:SteamID64()) > 0) then
			actions[#actions + 1] = {text = "WARNS", callback = function()
				self:OpenWarnings(target:SteamID64(), target:Name())
			end}
		end

		if (ix.admin.Can(me, "player.ban")
		and ix.admin.Outranks(me, target)) then
			actions[#actions + 1] = {text = "BAN", callback = function()
				self:OpenBanDialog(target:Name())
			end}
		end

		if (ix.admin.Can(me, "player.kick")
		and ix.admin.Outranks(me, target)) then
			actions[#actions + 1] = {text = "KICK", callback = function()
				Derma_StringRequest("Kick", "Why?", "", function(reason)
					LocalPlayer():ConCommand(string.format(
						"say /plykick \"%s\" %s", target:Name(), reason))
				end, function() end, "Kick", "Cancel")
			end}
		end

		if (ix.admin.Can(me, "player.goto")) then
			actions[#actions + 1] = {text = "GOTO", callback = function()
				LocalPlayer():ConCommand(string.format("say /plygoto \"%s\"",
					target:Name()))
			end}

			actions[#actions + 1] = {text = "BRING", callback = function()
				LocalPlayer():ConCommand(string.format("say /plybring \"%s\"",
					target:Name()))
			end}
		end

		if (ix.admin.Can(me, "log.view")) then
			actions[#actions + 1] = {text = "LOGS", callback = function()
				--[[
					DEPTH ON, because coming from a player is exactly the case
					where the category strip must not wipe the filter you just
					set by clicking it.
				]]
				self.filter = {steamID = target:SteamID()}
				self.depth = true

				self:SetSection("logs")
				self:Query()
			end}
		end

		for index = #actions, 1, -1 do
			local action = actions[index]
			local button = row:Add("ixFOButton")

			button:Dock(RIGHT)
			button:SetWide(Scaled(62))
			button:DockMargin(Scaled(4), 0, 0, 0)
			button:SetFont("ixLootSmall")
			button:SetText(action.text)
			button:SetContentAlignment(5)
			button.DoClick = action.callback
		end
	end

	if (#players == 0) then
		self:Say("Nobody is on.")
	end
end

function PANEL:OpenGroupPicker(target)
	local menu = DermaMenu()

	for _, group in ipairs(ix.admin.AssignableBy(LocalPlayer())) do
		menu:AddOption(group.name, function()
			net.Start("ixGroupSet")
				net.WriteEntity(target)
				net.WriteString(group.id)
			net.SendToServer()

			timer.Simple(0.3, function()
				if (IsValid(self)) then self:Populate() end
			end)
		end)
	end

	menu:Open()
end

--------------------------------------------------------------------------------
-- Logs
--------------------------------------------------------------------------------

function PANEL:Query()
	net.Start("ixLogQuery")
		net.WriteTable(self.filter or {})
	net.SendToServer()
end

--[[
	The log, with a category strip, a search box and a depth toggle.

	CHOOSING A CATEGORY CLEARS THE SEARCH, unless DEPTH is ticked. Those are
	two different things somebody wants: normally "show me the economy log" and
	the old search text is stale, so keeping it means an empty result and a
	confused admin. With DEPTH on, the text is kept and the category narrows
	it - which is what you want when you are hunting one person or one item
	across several categories.

	IT SCROLLS SIDEWAYS. A combat entry naming two players, a weapon, a
	hitgroup list and a position is far wider than the panel, and a log that
	silently truncates the end of its own lines is a log that hides the part
	somebody needed.
]]
function PANEL:PopulateLogs()
	local controls = self.content:Add("Panel")

	controls:Dock(TOP)
	controls:SetTall(Scaled(30))
	controls:DockMargin(0, 0, 0, Scaled(6))

	local depth = controls:Add("DCheckBoxLabel")

	depth:Dock(RIGHT)
	depth:SetWide(Scaled(120))
	depth:DockMargin(Scaled(8), Scaled(6), 0, 0)
	depth:SetText("Depth search")
	depth:SetTextColor(ix.fallout.GetPalette().text_primary)
	depth:SetValue(self.depth and true or false)
	depth.OnChange = function(_, value) self.depth = value end

	local go = controls:Add("ixFOButton")

	go:Dock(RIGHT)
	go:SetWide(Scaled(80))
	go:DockMargin(Scaled(6), 0, 0, 0)
	go:SetText("SEARCH")
	go:SetContentAlignment(5)

	local search = controls:Add("ixFOTextEntry")

	search:Dock(FILL)
	search:SetPlaceholderText("Search - a name, a SteamID, an item id, "
		.. "anything")
	search:SetText(self.filter.text or "")

	local function Run()
		self.filter.text = search:GetValue()
		self.filter.page = 0

		self:Query()
	end

	--[[
		PAGES. The server answers with the newest two hundred matches; the
		whole log is thousands, and one net message cannot carry it. OLDER
		asks for the two hundred before those, NEWER for the ones after.
	]]
	local function Turn(step)
		local page = (self.filter.page or 0) + step

		if (page < 0) then return self:Say("This is the newest page.") end
		if (step > 0 and not self.more) then return self:Say("There is nothing older.") end

		self.filter.page = page
		self:Query()
	end

	for _, button in ipairs({{"OLDER", 1}, {"NEWER", -1}}) do
		local turn = controls:Add("ixFOButton")

		turn:Dock(RIGHT)
		turn:SetWide(Scaled(70))
		turn:DockMargin(Scaled(6), 0, 0, 0)
		turn:SetText(button[1])
		turn:SetContentAlignment(5)
		turn.DoClick = function() Turn(button[2]) end
	end

	search.OnEnter = Run
	go.DoClick = Run

	--[[
		A plain Panel, not a scroll panel. It has a fixed height and its child
		docks FILL - and FILL inside a `DScrollPanel` is the exact shape that
		gave the log list zero height. It happened to render here; it is not
		worth leaving a second instance of a known trap in the file.
	]]
	local categories = self.content:Add("Panel")

	categories:Dock(TOP)
	categories:SetTall(Scaled(30))
	categories:DockMargin(0, 0, 0, Scaled(6))

	--[[
		The strip scrolls too. There are eight categories and more will be
		added; a fixed row silently drops the ones past the edge.
	]]
	local strip = categories:Add("DHorizontalScroller")

	strip:Dock(FILL)
	strip:SetOverlap(-Scaled(4))

	local function Choose(id)
		self.filter.category = id
		self.filter.page = 0

		--[[
			The search text is cleared unless DEPTH is on - see the note at the
			top of this function.
		]]
		if (not self.depth) then
			self.filter.text = nil

			search:SetText("")
		end

		self:Query()
	end

	local all = vgui.Create("ixFOButton")

	all:SetWide(Scaled(70))
	all:SetFont("ixLootSmall")
	all:SetText("ALL")
	all:SetContentAlignment(5)
	all:SetActive(not self.filter.category)
	all.DoClick = function() Choose(nil) end

	strip:AddPanel(all)

	for _, category in ipairs(ix.adminlog.categoryNames) do
		local button = vgui.Create("ixFOButton")

		button:SetWide(Scaled(96))
		button:SetFont("ixLootSmall")
		button:SetText(string.upper(category.name))
		button:SetContentAlignment(5)
		button:SetActive(self.filter.category == category.id)
		button.DoClick = function() Choose(category.id) end

		strip:AddPanel(button)
	end

	if (self.filter.steamID) then
		local clear = self.content:Add("ixFOButton")

		clear:Dock(TOP)
		clear:SetTall(Scaled(24))
		clear:DockMargin(0, 0, 0, Scaled(6))
		clear:SetFont("ixLootSmall")
		clear:SetText("ONLY " .. self.filter.steamID .. "  -  CLEAR")
		clear:SetContentAlignment(5)

		clear.DoClick = function()
			self.filter.steamID = nil

			self:Query()
		end
	end

	--[[
		Rows go straight into `self.content`, docked TOP, which is the only
		docking a `DScrollPanel` understands - see the note in `Init` about the
		nested FILL panel that drew nothing.

		`self.logOffset` is how far the message column is scrolled sideways,
		moved by the slider on the frame. One number, read by every row's
		`Paint`, with no per-row state to keep in step.
	]]
	self.logOffset = self.logOffset or 0

	local widest = 0

	surface.SetFont("ixLootSmall")

	for _, entry in ipairs(self.results or {}) do
		widest = math.max(widest, surface.GetTextSize(entry.message or ""))
	end

	--[[
		How far the text may travel, worked out once here. The panel's own
		width is known by now because the frame has been laid out, which it had
		not been when this lived in the slider's callback.
	]]
	self.logRoom = math.max(widest + Scaled(330) - self.content:GetWide(), 0)

	if (IsValid(self.logSlider)) then
		self.logSlider:SetSlideX(0)
		self.logSlider:SetEnabled(self.logRoom > 0)
	end

	self.logOffset = 0

	for _, entry in ipairs(self.results or {}) do
		local row = self.content:Add("DPanel")

		row:Dock(TOP)
		row:SetTall(Scaled(30))
		row:DockMargin(0, 0, 0, Scaled(2))

		row.Paint = function(pnl, width, height)
			local palette = ix.fallout.GetPalette()
			local colour = ix.log.color[entry.flag] or palette.text_primary
			local faint = ColorAlpha(palette.text_primary, 120)

			surface.SetDrawColor(pnl:IsHovered() and Color(40, 38, 30, 220)
				or Color(26, 26, 32, 190))
			surface.DrawRect(0, 0, width, height)

			--[[
				The three fixed columns do NOT move with the offset - a
				timestamp that scrolled off the left would make a scrolled log
				unreadable, and they are the columns you keep your place by.
			]]
			draw.SimpleText(os.date("%d/%m %H:%M:%S", entry.time),
				"ixLootSmall", Scaled(6), height * 0.5, faint,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			draw.SimpleText(entry.category, "ixLootSmall", Scaled(112),
				height * 0.5, ColorAlpha(palette.color_primary, 180),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			--[[
				The faction is CLIPPED to its column. "Midwestern
				Expeditionary Force" is wider than the space between two
				columns and ran straight through the message beside it -
				`SetScissorRect` is what stops a long name eating the line it
				sits on.
			]]
			if (entry.faction ~= "") then
				local x, y = pnl:LocalToScreen(Scaled(186), 0)

				render.SetScissorRect(x, y, x + Scaled(120), y + height, true)

				draw.SimpleText(entry.faction, "ixLootSmall", Scaled(186),
					height * 0.5, faint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

				render.SetScissorRect(0, 0, 0, 0, false)
			end

			--- Only the message moves, and only within its own column.
			local x, y = pnl:LocalToScreen(Scaled(312), 0)

			render.SetScissorRect(x, y, x + width, y + height, true)

			draw.SimpleText(entry.message, "ixLootSmall",
				Scaled(312) + self.logOffset, height * 0.5, colour,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			render.SetScissorRect(0, 0, 0, 0, false)
		end

		--[[
			RIGHT CLICK IS WHERE THE USEFUL ACTIONS ARE. Reading a log entry
			almost always leads to one of four things: copy the SteamID to ban
			with, look at everything else that person did, look at everything
			else of that kind, or paste the line into a report.
		]]
		row.OnMousePressed = function(pnl, code)
			if (code ~= MOUSE_RIGHT) then return end

			local menu = DermaMenu()

			if (entry.steamID ~= "") then
				menu:AddOption("Copy SteamID  (" .. entry.steamID .. ")",
					function()
						SetClipboardText(entry.steamID)
						self:Say("Copied " .. entry.steamID .. ".")
					end)

				menu:AddOption("Only this player", function()
					self.filter.steamID = entry.steamID
					self.depth = true

					self:Query()
				end)
			end

			menu:AddOption("Only '" .. entry.type .. "' entries", function()
				self.filter.text = entry.type
				self.depth = true

				self:Query()
			end)

			menu:AddOption("Copy this line", function()
				SetClipboardText(string.format("[%s] %s",
					os.date("%Y-%m-%d %H:%M:%S", entry.time), entry.message))

				self:Say("Copied the line.")
			end)

			menu:AddSpacer()

			menu:AddOption("Copy everything shown", function()
				local lines = {}

				for _, other in ipairs(self.results or {}) do
					lines[#lines + 1] = string.format("[%s] %s",
						os.date("%Y-%m-%d %H:%M:%S", other.time),
						other.message)
				end

				SetClipboardText(table.concat(lines, "\n"))
				self:Say(#lines .. " line(s) copied.")
			end)

			menu:Open()
		end
	end

	if (#(self.results or {}) == 0) then
		local empty = self.content:Add("ixFOLabel")

		empty:Dock(TOP)
		empty:SetTall(Scaled(40))
		empty:SetContentAlignment(5)
		empty:SetFont("ixLootSmall")
		empty:SetText("Nothing yet - press SEARCH, or pick a category.")
	end
end

--------------------------------------------------------------------------------
-- Bans
--------------------------------------------------------------------------------

--[[
	Asking for a length and a reason, then handing it to the command.

	It goes through `/ban` rather than a net message of its own so that one
	place decides whether a ban is allowed - the rank limit, the root account,
	the immunity check. A second route into banning would be a second place for
	one of those to be forgotten.
]]
function PANEL:OpenBanDialog(name)
	Derma_StringRequest("Ban " .. name,
		"How long? A bare number is minutes - or 2h, 7d, 0 for permanent.",
		"60", function(length)
			Derma_StringRequest("Ban " .. name, "What for?", "",
				function(reason)
					LocalPlayer():ConCommand(string.format(
						"say /ban \"%s\" %s %s", name, length, reason))
				end, function() end, "Ban", "Cancel")
		end, function() end, "Next", "Cancel")
end

--[[
	Every warning on one account, newest at the top.

	Removal is by INDEX INTO THE LIST as the server holds it, and the server
	holds it oldest-first - so the index sent is counted from that end, not from
	the order drawn here. Getting that backwards removes the wrong warning and
	nobody would ever notice.
]]
function PANEL:OpenWarnings(steamID64, name)
	local list = ix.punish.warnings[tostring(steamID64)] or {}

	local frame = vgui.Create("ixFOFrame")

	frame:SetSize(Scaled(560), Scaled(420))
	frame:Center()
	frame:MakePopup()
	frame:SetTitle("WARNINGS - " .. string.upper(name or steamID64))

	local scroll = frame:Add("ixFOScrollPanel")

	scroll:Dock(FILL)

	for index = #list, 1, -1 do
		local warning = list[index]
		local row = scroll:Add("DPanel")

		row:Dock(TOP)
		row:SetTall(Scaled(44))
		row:DockMargin(0, 0, 0, Scaled(2))
		row:DockPadding(0, Scaled(7), Scaled(6), Scaled(7))

		row.Paint = function(pnl, width, height)
			local palette = ix.fallout.GetPalette()

			surface.SetDrawColor(30, 30, 36, 200)
			surface.DrawRect(0, 0, width, height)

			surface.SetDrawColor(230, 140, 60)
			surface.DrawRect(0, 0, Scaled(3), height)

			draw.SimpleText(string.format("%d.  %s", index,
				warning.reason or "no reason given"), "ixLootRow", Scaled(10),
				height * 0.3, palette.text_primary, TEXT_ALIGN_LEFT,
				TEXT_ALIGN_CENTER)

			draw.SimpleText(string.format("by %s   %s",
				warning.admin or "the console",
				warning.time and os.date("%d/%m/%Y %H:%M", warning.time)
					or "some time ago"),
				"ixLootSmall", Scaled(10), height * 0.72,
				ColorAlpha(palette.text_primary, 150), TEXT_ALIGN_LEFT,
				TEXT_ALIGN_CENTER)
		end

		if (ix.admin.Can(LocalPlayer(), "player.warn.remove")) then
			local remove = row:Add("ixFOButton")

			remove:Dock(RIGHT)
			remove:SetWide(Scaled(70))
			remove:SetFont("ixLootSmall")
			remove:SetText("REMOVE")
			remove:SetContentAlignment(5)

			remove.DoClick = function()
				LocalPlayer():ConCommand(string.format("say /unwarn %s %d",
					steamID64, index))

				frame:Remove()
			end
		end
	end

	if (#list == 0) then
		local empty = scroll:Add("ixFOLabel")

		empty:Dock(TOP)
		empty:SetTall(Scaled(40))
		empty:SetContentAlignment(5)
		empty:SetFont("ixLootSmall")
		empty:SetText("No warnings on this account.")
	end
end

function PANEL:PopulateBans()
	--[[
		Searched on ENTER and on the button, not on every keystroke. Typing
		rebuilds the panel that owns the box, which takes the focus with it -
		the log tab found that out first and this is the same shape.
	]]
	local controls = self.content:Add("Panel")

	controls:Dock(TOP)
	controls:SetTall(Scaled(26))
	controls:DockMargin(0, 0, 0, Scaled(6))

	local go = controls:Add("ixFOButton")

	go:Dock(RIGHT)
	go:SetWide(Scaled(80))
	go:DockMargin(Scaled(6), 0, 0, 0)
	go:SetText("SEARCH")
	go:SetContentAlignment(5)

	local search = controls:Add("ixFOTextEntry")

	search:Dock(FILL)
	search:SetPlaceholderText("Search bans - a name, a SteamID, a reason, "
		.. "the admin")
	search:SetText(self.banFilter or "")

	local function Run()
		self.banFilter = search:GetValue()

		self:Populate()
	end

	search.OnEnter = Run
	go.DoClick = Run

	--- Newest first: a ban somebody is asking about was probably just made.
	local sorted = {}

	for _, ban in pairs(ix.punish.bans) do
		sorted[#sorted + 1] = ban
	end

	table.sort(sorted, function(a, b)
		return (a.time or 0) > (b.time or 0)
	end)

	local filter = string.lower(string.Trim(self.banFilter or ""))
	local shown = 0

	for _, ban in ipairs(sorted) do
		local matches = true

		if (filter ~= "") then
			local haystack = string.lower(string.format("%s %s %s %s",
				ban.name or "", ban.steamID or "", ban.reason or "",
				ban.admin or ""))

			matches = string.find(haystack, filter, 1, true) ~= nil
		end

		if (matches) then
			shown = shown + 1

			self:AddBanRow(ban)
		end
	end

	if (shown == 0) then
		local empty = self.content:Add("ixFOLabel")

		empty:Dock(TOP)
		empty:SetTall(Scaled(40))
		empty:SetContentAlignment(5)
		empty:SetFont("ixLootSmall")
		empty:SetText(filter ~= "" and "Nothing matches that."
			or "Nobody is banned.")
	end

	self:Say(string.format("%d ban(s).", shown))
end

--[[
	One ban.

	A `DPanel` and not an `ixFOLabel`, because a label has mouse input off by
	default and its child buttons would never see a click - which is exactly
	what broke the ranks tab.
]]
function PANEL:AddBanRow(ban)
	local row = self.content:Add("DPanel")

	row:Dock(TOP)
	row:SetTall(Scaled(44))
	row:DockMargin(0, 0, 0, Scaled(2))
	row:DockPadding(0, Scaled(7), Scaled(6), Scaled(7))

	local permanent = (ban.length or 0) <= 0

	row.Paint = function(pnl, width, height)
		local palette = ix.fallout.GetPalette()

		surface.SetDrawColor(30, 30, 36, 200)
		surface.DrawRect(0, 0, width, height)

		--- Red for a permanent ban, amber for one that runs out on its own.
		surface.SetDrawColor(permanent and Color(200, 70, 60)
			or Color(220, 150, 60))
		surface.DrawRect(0, 0, Scaled(3), height)

		draw.SimpleText(string.format("%s   %s", ban.name or "unknown",
			ban.steamID or "?"), "ixLootRow", Scaled(10), height * 0.3,
			palette.text_primary, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		--[[
			Worked out every frame rather than once, so a ban with four minutes
			left says so until it says three. The panel is not rebuilt while
			somebody is looking at it.
		]]
		local left = permanent and "PERMANENT"
			or (ix.punish.FormatLength(ix.punish.Remaining(ban)) .. " left")

		draw.SimpleText(string.format("%s   by %s   %s", left,
			ban.admin or "the console", ban.reason or "no reason given"),
			"ixLootSmall", Scaled(10), height * 0.72,
			ColorAlpha(palette.text_primary, 150), TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)

		draw.SimpleText(ban.time and os.date("%d/%m/%Y", ban.time) or "",
			"ixLootSmall", width - Scaled(140), height * 0.5,
			ColorAlpha(palette.text_primary, 110), TEXT_ALIGN_RIGHT,
			TEXT_ALIGN_CENTER)
	end

	local copy = row:Add("ixFOButton")

	copy:Dock(RIGHT)
	copy:SetWide(Scaled(62))
	copy:DockMargin(Scaled(4), 0, 0, 0)
	copy:SetFont("ixLootSmall")
	copy:SetText("COPY")
	copy:SetContentAlignment(5)

	copy.DoClick = function()
		SetClipboardText(ban.steamID or "")

		self:Say("Copied " .. (ban.steamID or "") .. ".")
	end

	if (not ix.admin.Can(LocalPlayer(), "player.ban")) then return end

	local lift = row:Add("ixFOButton")

	lift:Dock(RIGHT)
	lift:SetWide(Scaled(62))
	lift:DockMargin(Scaled(4), 0, 0, 0)
	lift:SetFont("ixLootSmall")
	lift:SetText("UNBAN")
	lift:SetContentAlignment(5)

	lift.DoClick = function()
		Derma_Query(string.format("Lift the ban on %s?",
			ban.name or ban.steamID or "them"), "Bans", "Unban", function()
				net.Start("ixPunishUnban")
					net.WriteString(ban.steamID or "")
				net.SendToServer()
			end, "Cancel", function() end)
	end
end

--------------------------------------------------------------------------------
-- Groups
--------------------------------------------------------------------------------

--[[
	The rank editor.

	IT SHOWS WHAT A RANK ACTUALLY HAS, not only what it grants. A permission
	inherited from a parent is ticked and greyed with the parent's answer
	standing - so "why can a moderator do that" is answerable from the screen
	rather than by walking the chain in your head.
]]
function PANEL:PopulateGroups()
	local me = LocalPlayer()
	local canEdit = ix.admin.Can(me, "rank.manage")

	if (canEdit) then
		local add = self.content:Add("ixFOButton")

		add:Dock(TOP)
		add:SetTall(Scaled(28))
		add:DockMargin(0, 0, 0, Scaled(6))
		add:SetText("NEW RANK")
		add:SetContentAlignment(5)

		add.DoClick = function()
			Derma_StringRequest("New rank", "An id - lower case, no spaces.",
				"", function(text)
					local id = string.gsub(string.lower(string.Trim(text)),
						"[^%w_]", "")

					if (id == "") then
						self:Say("That is not an id.")

						return
					end

					self:OpenRankEditor({
						id = id, name = id, inherit = "user", immunity = 1,
						banLimit = 0, maxCharacters = 0, permissions = {}
					})
				end, function() end, "Create", "Cancel")
		end
	end

	for _, rank in ipairs(ix.admin.SortedRanks()) do
		local granted, inherited = 0, 0

		for id in pairs(ix.admin.permissions) do
			if (rank.permissions and rank.permissions[id] == true) then
				granted = granted + 1
			elseif (ix.admin.RankCan(rank.id, id)) then
				inherited = inherited + 1
			end
		end

		--[[
			A DPanel, NOT an `ixFOLabel`. That is a DLabel, and Derma turns
			mouse input OFF on labels by default - so the EDIT and DELETE
			buttons added to one were drawn perfectly and could never be
			clicked. The players tab worked all along because it uses a panel.
		]]
		local row = self.content:Add("DPanel")

		row:Dock(TOP)
		row:SetTall(Scaled(50))
		row:DockMargin(0, 0, 0, Scaled(4))
		row:DockPadding(Scaled(6), Scaled(6), Scaled(6), Scaled(6))

		row.Paint = function(pnl, width, height)
			local palette = ix.fallout.GetPalette()

			surface.SetDrawColor(30, 30, 36, 200)
			surface.DrawRect(0, 0, width, height)

			surface.SetDrawColor(rank.color or palette.color_primary)
			surface.DrawRect(0, 0, Scaled(3), height)

			draw.SimpleText(string.format("%s   (%s)", rank.name, rank.id),
				"ixLootRow", Scaled(10), Scaled(9), palette.text_primary,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

			--[[
				The ban limit is shown ONLY WHERE IT BITES - a rank that cannot
				ban has no limit worth reading, and "permanent" beside a rank
				that will never use it reads as an alarming grant.
			]]
			local limit = ""

			if (ix.admin.RankCan(rank.id, "player.ban")) then
				limit = "   bans up to "
					.. ((rank.banLimit or 0) > 0
						and ix.punish.FormatLength(rank.banLimit)
						or "permanent")
			end

			draw.SimpleText(string.format(
				"immunity %d%s   %d granted, %d inherited%s%s", rank.immunity,
				rank.inherit and (" - inherits " .. rank.inherit) or "",
				granted, inherited, limit,
				rank.root and "   ROOT - has everything" or ""),
				"ixLootSmall", Scaled(10), Scaled(29),
				ColorAlpha(palette.text_primary, 150), TEXT_ALIGN_LEFT,
				TEXT_ALIGN_TOP)
		end

		if (not canEdit or rank.immunity >= ix.admin.Immunity(me)) then
			continue
		end

		local edit = row:Add("ixFOButton")

		edit:Dock(RIGHT)
		edit:SetWide(Scaled(70))
		edit:SetFont("ixLootSmall")
		edit:SetText("EDIT")
		edit:SetContentAlignment(5)
		edit.DoClick = function() self:OpenRankEditor(rank) end

		if (ix.admin.protected[rank.id]) then continue end

		local remove = row:Add("ixFOButton")

		remove:Dock(RIGHT)
		remove:SetWide(Scaled(70))
		remove:DockMargin(0, 0, Scaled(4), 0)
		remove:SetFont("ixLootSmall")
		remove:SetText("DELETE")
		remove:SetContentAlignment(5)

		remove.DoClick = function()
			Derma_Query(string.format("Delete %s? Anybody in it drops to %s.",
				rank.name, rank.inherit or "user"), "Ranks", "Delete",
				function()
					net.Start("ixRankDelete")
						net.WriteString(rank.id)
					net.SendToServer()
				end, "Cancel", function() end)
		end
	end
end

function PANEL:OpenRankEditor(rank)
	local editing = table.Copy(rank)

	editing.permissions = editing.permissions or {}

	local frame = vgui.Create("ixFOFrame")

	frame:SetSize(Scaled(560), Scaled(640))
	frame:Center()
	frame:MakePopup()
	frame:SetTitle("RANK - " .. string.upper(editing.id))

	local save = frame:Add("ixFOButton")

	save:Dock(BOTTOM)
	save:SetTall(Scaled(30))
	save:SetText("SAVE")
	save:SetContentAlignment(5)

	save.DoClick = function()
		net.Start("ixRankSave")
			net.WriteTable(editing)
		net.SendToServer()

		frame:Remove()
	end

	local name = frame:Add("ixFOTextEntry")

	name:Dock(TOP)
	name:SetTall(Scaled(26))
	name:DockMargin(0, 0, 0, Scaled(4))
	name:SetText(editing.name or editing.id)
	name:SetUpdateOnType(true)
	name.OnValueChange = function(_, text) editing.name = text end

	local immunity = frame:Add("ixFONumberEntry")

	immunity:Dock(TOP)
	immunity:SetTall(Scaled(30))
	immunity:DockMargin(0, 0, 0, Scaled(4))
	immunity:SetMin(0)
	immunity:SetMax(math.max(ix.admin.Immunity(LocalPlayer()) - 1, 0))
	immunity:SetSuffix("immunity")
	immunity:SetValue(editing.immunity or 1)
	immunity.OnChanged = function(_, value) editing.immunity = value or 1 end

	--[[
		The longest ban this rank may hand out, IN HOURS - stored in seconds,
		because that is what `ix.punish` works in, but nobody thinks about a
		three day ban as 259200.

		ZERO IS NO LIMIT, which is also the number that means "permanent" for a
		ban length. The two zeroes mean opposite things, so the suffix says so
		rather than leaving somebody to guess which one this is.
	]]
	local banLimit = frame:Add("ixFONumberEntry")

	banLimit:Dock(TOP)
	banLimit:SetTall(Scaled(30))
	banLimit:DockMargin(0, 0, 0, Scaled(4))
	banLimit:SetMin(0)
	banLimit:SetMax(8760)
	banLimit:SetSuffix("hour ban limit, 0 = any")
	banLimit:SetValue(math.floor((editing.banLimit or 0) / 3600))

	banLimit.OnChanged = function(_, value)
		editing.banLimit = math.floor((value or 0) * 3600)
	end

	--[[
		HOW MANY CHARACTERS SOMEBODY IN THIS RANK MAY MAKE.

		Zero means "whatever the server's `maxCharacters` says", which is what
		every rank is until somebody changes one - so this field appearing
		changes nothing on its own. See `ix.admin.MaxCharacters`.
	]]
	local characters = frame:Add("ixFONumberEntry")

	characters:Dock(TOP)
	characters:SetTall(Scaled(30))
	characters:DockMargin(0, 0, 0, Scaled(4))
	characters:SetMin(0)
	characters:SetMax(64)
	characters:SetSuffix(string.format("character slots, 0 = server default "
		.. "(%d)", ix.config.Get("maxCharacters", 5)))
	characters:SetValue(editing.maxCharacters or 0)

	characters.OnChanged = function(_, value)
		editing.maxCharacters = math.floor(value or 0)
	end

	local inherit = frame:Add("DComboBox")

	inherit:Dock(TOP)
	inherit:SetTall(Scaled(26))
	inherit:DockMargin(0, 0, 0, Scaled(4))
	inherit:SetSortItems(false)
	inherit:AddChoice("inherits nothing", "", not editing.inherit)

	for _, other in ipairs(ix.admin.SortedRanks()) do
		if (other.id ~= editing.id) then
			inherit:AddChoice("inherits " .. other.name, other.id,
				editing.inherit == other.id)
		end
	end

	inherit.OnSelect = function(_, _, _, data)
		editing.inherit = data ~= "" and data or nil
	end

	local hint = frame:Add("ixFOLabel")

	hint:Dock(TOP)
	hint:SetFont("ixLootSmall")
	hint:SetWrap(true)
	hint:SetAutoStretchVertical(true)
	hint:DockMargin(0, 0, 0, Scaled(6))
	hint:SetText("Ticked is granted by this rank. Greyed is inherited from a "
		.. "parent, and stays whether or not you tick it here.")

	local list = frame:Add("ixFOScrollPanel")

	list:Dock(FILL)

	local lastCategory

	for _, permission in ipairs(ix.admin.SortedPermissions()) do
		if (permission.category ~= lastCategory) then
			lastCategory = permission.category

			local header = list:Add("ixFOLabel")

			header:Dock(TOP)
			header:SetTall(Scaled(24))
			header:DockMargin(0, Scaled(6), 0, Scaled(2))
			header:SetFont("ixLootHeader")
			header:SetText(string.upper(permission.category))
		end

		local own = editing.permissions[permission.id] == true
		local fromParent = editing.inherit
			and ix.admin.RankCan(editing.inherit, permission.id)

		local box = list:Add("DCheckBoxLabel")

		box:Dock(TOP)
		box:SetTall(Scaled(20))
		box:SetText(string.format("%s  -  %s", permission.id,
			permission.description))
		box:SetValue(own or fromParent)

		--[[
			Greyed when it comes from the parent, so the tick reads as "this rank
			has it" and the colour says where from.
		]]
		box:SetTextColor(fromParent and not own and Color(150, 150, 150)
			or ix.fallout.GetPalette().text_primary)

		box.OnChange = function(_, value)
			--[[
				`nil` rather than `false` when unticked, so the rank stops DECIDING
				it and the parent's answer applies again. Writing `false` would
				revoke it outright - a different thing, and not what unticking a box
				looks like it means.
			]]
			editing.permissions[permission.id] = value and true or nil
		end
	end
end

--------------------------------------------------------------------------------
-- Commands
--------------------------------------------------------------------------------

--[[
	The target tokens, said once at the top of the list.

	They work on every command with a player argument, ours and Helix's alike,
	so this is the only place that can tell somebody they exist without
	repeating it on a hundred rows.
]]
function PANEL:AddTokenHint()
	local hint = self.content:Add("ixFOLabel")

	hint:Dock(TOP)
	hint:SetTall(Scaled(24))
	hint:DockMargin(0, 0, 0, Scaled(6))
	hint:SetFont("ixLootSmall")
	hint:SetText("  Targets:  ^ you    @ who you are looking at    "
		.. "* everybody")
end

--[[
	Every command, in two lists.

	OURS AND THEIRS, because they are different questions. "What did we add to
	this server" is answered by the first and is what somebody learning the
	schema needs; "what does Helix give me" is answered by the second and is
	what somebody who already knows the schema needs.

	They are told apart by where the command was DEFINED, using
	`debug.getinfo` - the same tool that cracked the container bug. A list
	maintained by hand would be wrong within a week.
]]
local function Ours(command)
	local source = command.ixSource

	if (source) then return source end

	local info = command.OnRun and debug.getinfo(command.OnRun, "S")

	source = info and info.short_src or ""

	command.ixSource = source

	return source
end

function PANEL:PopulateCommands()
	self:AddTokenHint()

	local mine, theirs = {}, {}

	for name, command in pairs(ix.command.list) do
		local source = Ours(command)
		local list = string.find(source, "falloutrp", 1, true) and mine
			or theirs

		list[#list + 1] = {name = name, command = command}
	end

	local function Sort(a, b) return a.name < b.name end

	table.sort(mine, Sort)
	table.sort(theirs, Sort)

	for _, group in ipairs({
		{name = "THIS SCHEMA", list = mine},
		{name = "HELIX", list = theirs}
	}) do
		local header = self.content:Add("ixFOLabel")

		header:Dock(TOP)
		header:SetTall(Scaled(28))
		header:DockMargin(0, Scaled(6), 0, Scaled(4))
		header:SetFont("ixLootHeader")
		header:SetText(string.format("%s - %d", group.name, #group.list))

		for _, entry in ipairs(group.list) do
			local command = entry.command

			--[[
				Captured per row. `name` above belongs to the `pairs` loop that
				built these lists and has long since finished - reading it
				inside a Paint that runs a frame later would draw whichever
				command happened to be last.
			]]
			local commandName = entry.name

			--[[
				A DPanel, not an `ixFOLabel` - the SET button below is a child,
				and Derma turns mouse input off on labels by default, so it
				would draw and never click. The ranks tab had exactly this bug.
			]]
			local row = self.content:Add("DPanel")

			row:Dock(TOP)
			row:SetTall(Scaled(30))
			row:DockMargin(0, 0, 0, Scaled(2))

			row.Paint = function(pnl, width, height)
				local palette = ix.fallout.GetPalette()

				surface.SetDrawColor(26, 26, 32, 190)
				surface.DrawRect(0, 0, width, height)

				--[[
					The gate is drawn beside the name, because "which of these
					can a moderator use" is the question this list is opened to
					answer.
				]]
				--[[
					An OVERRIDE is shown in the rank's own colour and the
					command's own check in grey, so a screen of a hundred
					commands makes the handful somebody has changed obvious at
					a glance.
				]]
				local override = ix.admin.commandRanks[
					string.lower(commandName)]
				local gate, colour

				if (override and ix.admin.ranks[override]) then
					local rank = ix.admin.Rank(override)

					gate = rank.name
					colour = rank.color
				else
					gate = command.superAdminOnly and "superadmin"
						or command.adminOnly and "admin"
						or command.OnCheckAccess and "custom" or "everyone"
					colour = ColorAlpha(palette.text_primary, 110)
				end

				draw.SimpleText("/" .. commandName, "ixLootRow", Scaled(8),
					height * 0.5, palette.text_primary, TEXT_ALIGN_LEFT,
					TEXT_ALIGN_CENTER)

				draw.SimpleText(command.description or "", "ixLootSmall",
					Scaled(200), height * 0.5,
					ColorAlpha(palette.text_primary, 150), TEXT_ALIGN_LEFT,
					TEXT_ALIGN_CENTER)

				draw.SimpleText(gate, "ixLootSmall", width - Scaled(166),
					height * 0.5, colour, TEXT_ALIGN_RIGHT,
					TEXT_ALIGN_CENTER)

				--[[
					AND WHO IS SHUT OUT, which the gate cannot say. A command
					set to "moderator and above" with the event team excluded
					reads as moderator-and-above everywhere else, and the
					exception is the thing somebody is looking for when they
					come back to this screen.
				]]
				local excluded = ix.admin.commandExcludes[
					string.lower(commandName)]

				if (excluded) then
					local names = {}

					for rankID in pairs(excluded) do
						local rank = ix.admin.ranks[rankID]

						names[#names + 1] = rank and rank.name or rankID
					end

					table.sort(names)

					draw.SimpleText("not " .. table.concat(names, ", "),
						"ixLootSmall", width - Scaled(166),
						height * 0.5 + Scaled(9), Color(220, 120, 120),
						TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
				end
			end

			row.OnMousePressed = function()
				SetClipboardText("/" .. commandName)

				self:Say("Copied /" .. commandName .. " to the clipboard.")
			end

			if (not ix.admin.Can(LocalPlayer(), "rank.manage")) then
				continue
			end

			local set = row:Add("ixFOButton")

			set:Dock(RIGHT)
			set:SetWide(Scaled(74))
			set:SetFont("ixLootSmall")
			set:SetText("SET")
			set:SetContentAlignment(5)

			set.DoClick = function()
				local menu = DermaMenu()

				--[[
					"Its own check" is first and always offered - putting a
					command back the way Helix wrote it is the thing somebody
					needs most after setting it wrong.
				]]
				menu:AddOption("Its own check", function()
					net.Start("ixCommandRankSet")
						net.WriteString(commandName)
						net.WriteString("")
					net.SendToServer()
				end)

				menu:AddSpacer()

				for _, rank in ipairs(
				ix.admin.AssignableBy(LocalPlayer())) do
					menu:AddOption(rank.name .. " and above", function()
						net.Start("ixCommandRankSet")
							net.WriteString(commandName)
							net.WriteString(rank.id)
						net.SendToServer()
					end)
				end

				menu:Open()
			end

			--[[
				EXCLUDING A RANK is a second button rather than another entry
				on the first menu, because it is a different question: the
				first sets a floor and this one takes one group off the list
				whatever the floor says. Ticked ranks are marked, so the menu
				is also where you see what has been done.
			]]
			local exclude = row:Add("ixFOButton")

			exclude:Dock(RIGHT)
			exclude:SetWide(Scaled(76))
			exclude:SetFont("ixLootSmall")
			exclude:SetText("EXCLUDE")
			exclude:SetContentAlignment(5)

			exclude.DoClick = function()
				local menu = DermaMenu()
				local excluded = ix.admin.commandExcludes[
					string.lower(commandName)] or {}

				for _, rank in ipairs(
				ix.admin.AssignableBy(LocalPlayer())) do
					local option = menu:AddOption(rank.name, function()
						net.Start("ixCommandExclude")
							net.WriteString(commandName)
							net.WriteString(rank.id)
						net.SendToServer()
					end)

					if (excluded[rank.id]) then
						option:SetIcon("icon16/cross.png")
					end
				end

				menu:Open()
			end
		end
	end
end

function PANEL:OnRemove()
	if (ix.gui.adminMenu == self) then
		ix.gui.adminMenu = nil
	end
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Remove()
	end
end

vgui.Register("ixFOAdminMenu", PANEL, "ixFOFrame")

net.Receive("ixLogResult", function()
	local count = net.ReadUInt(16)
	local results = {}

	for _ = 1, count do
		results[#results + 1] = {
			time = net.ReadUInt(32),
			name = net.ReadString(),
			steamID = net.ReadString(),
			faction = net.ReadString(),
			category = net.ReadString(),
			type = net.ReadString(),
			flag = net.ReadUInt(4),
			message = net.ReadString()
		}
	end

	local more = net.ReadBool()
	local page = net.ReadUInt(16)
	local total = net.ReadUInt(32)
	local limit = net.ReadUInt(16)

	if (not IsValid(ix.gui.adminMenu)) then return end

	local menu = ix.gui.adminMenu

	menu.results = results
	menu.more = more
	menu.filter = menu.filter or {}
	menu.filter.page = page

	if (menu.section == "logs") then
		menu:Populate()
	end

	local pages = math.max(1, math.ceil(total / math.max(limit, 1)))
	local first = count > 0 and (page * limit + 1) or 0

	menu:Say(string.format("Showing %d-%d of %d entries - page %d of %d%s.",
		first, page * limit + count, total, page + 1, pages,
		more and ", OLDER for the next" or ""))
end)
