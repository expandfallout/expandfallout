--[[
	Raids, client side: the buttons on the scoreboard and the panel that shows
	who is fighting whom.

	THE BUTTONS ARE ADDED TO HELIX'S OWN FACTION PANEL rather than to a
	scoreboard of our own. `ixScoreboardFaction` is an `ixCategoryPanel` with a
	coloured header, and one of those per faction is already exactly the row
	the buttons belong on - see `libs/cl_scoreboard.lua`, which wraps the same
	panel for the karma icons.

	WHICH BUTTONS APPEAR depends on what is happening:

	    nothing running     RAID and HOSTILITIES on every other faction
	    running, us out     ASSIST on each side, SKIRMISH if the type allows
	    running, us in      nothing - you are already in it

	A button always asks before it does anything. Calling a raid commits your
	whole faction for a quarter of an hour and puts it on cooldown for longer
	than that; that is not a thing to do by clicking the wrong row.
]]

ix.raid = ix.raid or {}

if (not CLIENT) then return end

--- What the server last told us, mirrored so the buttons can read it.
ix.raid.cooldowns = ix.raid.cooldowns or {}
ix.raid.shields = ix.raid.shields or {}

net.Receive("ixRaidState", function()
	ix.raid.disabled = net.ReadBool()

	local current = net.ReadTable()

	--- An empty table is "nothing running" - `net.WriteTable` has no nil.
	ix.raid.current = next(current) and current or nil
	ix.raid.cooldowns = net.ReadTable()
	ix.raid.shields = net.ReadTable()

	if (IsValid(ix.gui.raidPanel)) then
		ix.gui.raidPanel:Rebuild()
	end
end)

net.Receive("ixRaidAnnounce", function()
	local text = net.ReadString()
	local sound = net.ReadString()

	chat.AddText(Color(255, 80, 60), "[CONFLICT] ", color_white, text)

	if (sound ~= "") then surface.PlaySound(sound) end
end)

net.Receive("ixRaidStats", function()
	local stats = net.ReadTable()

	if (not next(stats)) then
		chat.AddText(Color(255, 150, 0), "Nothing has been fought yet.")

		return
	end

	if (IsValid(ix.gui.raidStats)) then ix.gui.raidStats:Remove() end

	local panel = vgui.Create("ixFORaidStats")

	if (IsValid(panel)) then panel:Setup(stats) end
end)

--------------------------------------------------------------------------------
-- The scoreboard buttons
--------------------------------------------------------------------------------

--[[
	Ask, then send. Every one of these goes through here.
]]
local function Confirm(text, title, accept, callback)
	Derma_Query(text, title, accept, callback, "CANCEL", function() end)
end

local function CallConflict(typeID, faction)
	local info = ix.raid.types[typeID]
	local data = ix.faction.indices[faction]

	if (not info or not data) then return end

	local can, reason = ix.raid.CanCall(LocalPlayer(), typeID, faction)

	if (not can) then
		ix.util.Notify(reason)

		return
	end

	Confirm(string.format("Call %s on %s?\n\nIt lasts %d minutes. Both "
		.. "factions go on cooldown afterwards, and yours cannot fight again "
		.. "until it is up.", info.name, data.name,
		math.floor(ix.config.Get(typeID .. "Time", 900) / 60)),
		string.upper(info.name) .. "?", string.upper(info.name), function()
			net.Start("ixRaidCall")
				net.WriteString(typeID)
				net.WriteUInt(faction, 8)
			net.SendToServer()
		end)
end

local function JoinConflict(side)
	local can, reason = ix.raid.CanJoin(LocalPlayer(), side)

	if (not can) then
		ix.util.Notify(reason)

		return
	end

	local words = side == "skirmishers"
		and "Fight BOTH sides as a third party?"
		or string.format("Join the %s?",
			side == "attackers" and "attack" or "defence")

	Confirm(words .. "\n\nYour faction is committed for the rest of the "
		.. "conflict and goes on cooldown when it ends.",
		side == "skirmishers" and "SKIRMISH?" or "ASSIST?",
		side == "skirmishers" and "SKIRMISH" or "ASSIST", function()
			net.Start("ixRaidJoin")
				net.WriteString(side)
			net.SendToServer()
		end)
end

--[[
	The buttons for one faction row, rebuilt whenever the state changes.

	They are parented to the faction panel and positioned in its layout rather
	than docked, because the panel's own header is drawn by `ixCategoryPanel`
	and docking into it moves the label.
]]
local function BuildButtons(panel)
	for _, button in ipairs(panel.ixRaidButtons or {}) do
		if (IsValid(button)) then button:Remove() end
	end

	panel.ixRaidButtons = {}

	local faction = panel.faction

	if (not faction or not LocalPlayer():GetCharacter()) then return end

	local mine = ix.raid.FactionOf(LocalPlayer())

	if (not mine or mine == faction.index) then return end

	local function Add(text, tooltip, callback)
		local button = panel:Add("ixFOButton")

		button:SetText(text)
		button:SetFont("ixLootSmall")
		button:SetContentAlignment(5)
		button:SetTooltip(tooltip)
		button:SetSize(84, 20)
		button.DoClick = callback

		panel.ixRaidButtons[#panel.ixRaidButtons + 1] = button

		return button
	end

	local raid = ix.raid.current

	if (not raid) then
		--[[
			A shield or a cooldown is shown as a DISABLED button with the
			reason in its tooltip rather than as nothing at all: "why can I not
			raid them" is the question, and an empty row does not answer it.
		]]
		for _, typeID in ipairs({"raid", "hostilities"}) do
			local info = ix.raid.types[typeID]

			if (not info) then continue end

			local can, reason = ix.raid.CanCall(LocalPlayer(), typeID,
				faction.index)

			local button = Add(string.upper(info.name),
				can and ("Call " .. info.name .. " on " .. faction.name)
					or reason,
				function() CallConflict(typeID, faction.index) end)

			button:SetDisabled(not can)
		end

		return
	end

	--[[
		ALREADY IN IT: the only button is the way out, and only for the
		faction that started it.

		The defender does not get one, because "call off the raid on us" is
		not a decision the people being raided should be able to make - it is
		a surrender that costs the attacker their fight.
	]]
	if (ix.raid.Side(mine)) then
		if (raid.attacker == mine and faction.index == raid.defender) then
			local rank = ix.factionmgmt and ix.factionmgmt.GetRank(LocalPlayer())
				or 0

			if (rank >= 2) then
				Add("CALL OFF", "End the conflict your faction started. The "
					.. "cooldown still applies.", function()
					Confirm("Call off the conflict your faction started?\n\n"
						.. "Everybody goes on cooldown as if it had run its "
						.. "course, and the report is still written.",
						"CALL IT OFF?", "CALL IT OFF", function()
							net.Start("ixRaidCancel")
							net.SendToServer()
						end)
				end)
			end
		end

		return
	end

	local side = ix.raid.Side(faction.index)

	if (side == "attackers" or side == "defenders") then
		local can = ix.raid.CanJoin(LocalPlayer(), side)

		if (can) then
			Add("ASSIST", string.format("Join %s's side.", faction.name),
				function() JoinConflict(side) end)
		end

		if (ix.raid.CanJoin(LocalPlayer(), "skirmishers")) then
			Add("SKIRMISH", "Fight everybody in this conflict.",
				function() JoinConflict("skirmishers") end)
		end
	end
end

--[[
	The wrap. Same door as `cl_scoreboard.lua`'s karma icons, and the same
	one-time guard - see gotcha 22's neighbour: a wrapper wrapped twice runs
	its original twice.
]]
local function Wrap()
	local PANEL = vgui.GetControlTable("ixScoreboardFaction")

	if (not PANEL) then return false end
	if (PANEL.ixRaid) then return true end

	PANEL.ixRaid = true

	local update = PANEL.Update

	function PANEL:Update()
		update(self)

		--[[
			HIDDEN FACTIONS DISAPPEAR ENTIRELY. `hiddenFromTab` is for the
			factions that are not meant to be a visible part of the server -
			an event faction, an NPC faction - and hiding it here rather than
			in Helix's own loop means it also loses its buttons, which is the
			point: you cannot raid something you cannot see.
		]]
		if (self.faction and ix.faction.Hidden(self.faction.index)) then
			self:SetVisible(false)

			return
		end

		--[[
			Rebuilt when the CONFLICT changes rather than every half second:
			`Update` is on a timer and remaking four buttons twice a second
			would fight the mouse.
		]]
		local stamp = tostring(ix.raid.current and ix.raid.current.type or "-")
			.. tostring(ix.raid.current and ix.raid.current.endTime or 0)
			.. tostring(ix.raid.disabled)

		if (self.ixRaidStamp ~= stamp) then
			self.ixRaidStamp = stamp

			BuildButtons(self)
		end
	end

	local layout = PANEL.PerformLayout

	function PANEL:PerformLayout(width, height)
		if (layout) then layout(self, width, height) end

		--[[
			Right to left along the header, which is the top 32 pixels of an
			`ixCategoryPanel`. Manual because the header is painted rather than
			being a panel to dock inside.
		]]
		--[[
			LEFT OF THE KARMA, which is drawn over the same header by
			`cl_scoreboard.lua` and was being drawn straight through: the icon,
			the band name and the percentage all sat underneath two buttons.

			`ixKarmaWidth` is measured during that paint, because the font is
			only measurable once it has been loaded - so it is nil on the first
			frame and 0 for a faction with no karma, and both are the right
			answer to "how much room does it need".
		]]
		local x = width - (self.ixKarmaWidth or 0) - 8

		for _, button in ipairs(self.ixRaidButtons or {}) do
			if (not IsValid(button)) then continue end

			x = x - button:GetWide()

			button:SetPos(x, 6)

			x = x - 4
		end
	end

	return true
end

--[[
	The scoreboard panel is registered by Helix at load, so this usually takes
	on the first try - the timer is for the case where it has not.
]]
if (not Wrap()) then
	local attempts = 0

	timer.Create("ixRaidWrap", 1, 10, function()
		attempts = attempts + 1

		if (Wrap()) then
			timer.Remove("ixRaidWrap")
		elseif (attempts >= 10) then
			ErrorNoHalt("[falloutrp] the scoreboard faction panel never "
				.. "appeared - there are no raid buttons\n")
		end
	end)
end

--------------------------------------------------------------------------------
-- The conflict panel
--------------------------------------------------------------------------------

--[[
	THE CONFLICT PANEL, top right, the way Phoenix draw it.

	A bracketed box with the kind of conflict, a bar that fills as the clock
	runs down, the seconds left - and under it the attacker's icon, VS, and a
	column of everybody on the other side. Their factions are pictures rather
	than names because a raid with five factions in it is unreadable as a list
	and obvious as a row of badges.

	DRAWN RATHER THAN BUILT. It is four rectangles, some text and a handful of
	materials that change twice in a quarter of an hour; a panel with children
	would need rebuilding every time somebody assisted, and this does not.
]]
local ICONS = {}

--- Cached, because `Material` on every frame for every faction is a stall.
local function Icon(path)
	if (not path or path == "") then return nil end

	if (ICONS[path] == nil) then
		ICONS[path] = Material(path, "smooth")
	end

	return ICONS[path]
end

--- Every faction on one side of the conflict, principal first.
local function SideFactions(raid, side)
	local out = {}

	if (side == "attackers" and raid.attacker) then
		out[#out + 1] = raid.attacker
	elseif (side == "defenders" and raid.defender) then
		out[#out + 1] = raid.defender
	end

	--[[
		THE FACTION THAT CALLED IT STAYS AT THE TOP, and the ones that came to
		help are sorted UNDER it rather than in whatever order `pairs` felt like
		- which changed with every sync, so an assisting faction could push the
		principal down the column and swap places with another assist while
		nobody had done anything.

		Sorted separately from the principal for that reason: it is first
		because it is the conflict, not because of its index.
	]]
	local helping = {}

	for faction in pairs(raid[side] or {}) do
		helping[#helping + 1] = tonumber(faction)
	end

	table.sort(helping)

	for _, faction in ipairs(helping) do
		out[#out + 1] = faction
	end

	return out
end

local function DrawIcon(index, x, y, size)
    local data = ix.faction.indices[index]

    if (not data) then return end

    local icon = Icon(data.icon)

    if (icon) then
        surface.SetDrawColor(color_white)
        surface.SetMaterial(icon)
        surface.DrawTexturedRect(x, y, size, size)

        return
    end

    --- A faction with no icon still has a colour, which is better than a gap.
    surface.SetDrawColor(data.color or color_white)
    surface.DrawRect(x + size * 0.2, y + size * 0.2, size * 0.6, size * 0.6)
end

hook.Add("HUDPaint", "ixRaid", function()
	local raid = ix.raid.current

	if (not raid) then return end

	local client = LocalPlayer()

	if (not IsValid(client) or client.DisableHud) then return end

	local palette = ix.fallout.GetPalette()
	local scale = ScrH() / 1080
	local width = math.Round(300 * scale)
	local icon = math.Round(46 * scale)
	local pad = math.Round(10 * scale)

	local x = ScrW() - width - math.Round(24 * scale)
	local y = math.Round(24 * scale)

	local info = ix.raid.types[raid.type]
	local left = math.max(raid.endTime - CurTime(), 0)
	local total = math.max(raid.endTime - (raid.startTime or 0), 1)

	--[[
		THE HEAD OF THE PANEL: title, bar, seconds. Bracketed the way every
		other frame in this schema is - see `ixFOPanelBracketed` - so it reads
		as part of the same interface rather than as a HUD element somebody
		bolted on.
	]]
	local headHeight = math.Round(84 * scale)

	surface.SetDrawColor(0, 0, 0, 200)
	surface.DrawRect(x, y, width, headHeight)

	surface.SetDrawColor(palette.color_primary)
	surface.DrawOutlinedRect(x, y, width, headHeight, math.max(scale, 1))

	draw.SimpleText(info and info.name or "Conflict", "UI_Bold",
		x + width * 0.5, y + pad, palette.color_primary, TEXT_ALIGN_CENTER,
		TEXT_ALIGN_TOP)

	local barY = y + math.Round(34 * scale)
	local barHeight = math.Round(18 * scale)
	local progress = 1 - math.Clamp(left / total, 0, 1)

	surface.SetDrawColor(0, 0, 0, 220)
	surface.DrawRect(x + pad, barY, width - pad * 2, barHeight)

	surface.SetDrawColor(palette.color_primary)
	surface.DrawRect(x + pad, barY, (width - pad * 2) * progress, barHeight)
	surface.DrawOutlinedRect(x + pad, barY, width - pad * 2, barHeight,
		math.max(scale, 1))

	draw.SimpleText(left > 0 and (math.ceil(left) .. "s") or "OVERTIME",
		"UI_Bold", x + width * 0.5, barY + barHeight + math.Round(2 * scale),
		left > 0 and palette.text_primary or Color(255, 90, 70),
		TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

	--[[
		ONE ICON A SIDE UNLESS YOU ASK FOR THE REST.

		A raid with six factions in it is a column of badges nobody can read at
		a glance, and the glance is what this panel is for: who called it, on
		whom, how long left. HOLD C for everybody else - the same key that
		already means "show me more" in this game, and the panel says so while
		there is more to show.
	]]
	local attackers = SideFactions(raid, "attackers")
	local defenders = SideFactions(raid, "defenders")
	local skirmishers = SideFactions(raid, "skirmishers")

	local expanded = input.IsKeyDown(KEY_C)
	local hidden = math.max(#attackers - 1, 0) + math.max(#defenders - 1, 0)
		+ math.max(#skirmishers - 1, 0)

	local bodyY = y + headHeight + math.Round(22 * scale)
	local leftX = x + math.Round(30 * scale)
	local rightX = x + width - icon - math.Round(30 * scale)

	--[[
		THE TWO COLUMNS ARE LABELLED, both of them.

		The label used to be whichever side the VIEWER was on, drawn once in
		the middle - which said "ATTACKERS" over a gap between two columns and
		nothing at all over the other one. A side is a column, so the name goes
		over the column, and the viewer's own is picked out in the theme colour
		instead of being the only one drawn.
	]]
	local mySide = ix.raid.Side(ix.raid.FactionOf(client))
	local dim = Color(170, 170, 160)

	local function Column(list, columnX, columnY, side, label)
		if (#list == 0) then return 0 end

		draw.SimpleTextOutlined(label, "ixLootSmall", columnX + icon * 0.5,
			columnY - math.Round(6 * scale),
			mySide == side and palette.color_primary or dim,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, color_black)

		local shown = expanded and #list or 1

		for index = 1, shown do
			DrawIcon(list[index], columnX,
				columnY + (index - 1) * (icon + math.Round(4 * scale)), icon)
		end

		--- "+2" where the rest would be, so the panel admits what it is hiding.
		if (not expanded and #list > 1) then
			draw.SimpleTextOutlined("+" .. (#list - 1), "ixLootSmall",
				columnX + icon * 0.5, columnY + icon + math.Round(2 * scale),
				dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, color_black)
		end

		return shown
	end

	local attackerRows = Column(attackers, leftX, bodyY, "attackers",
		"ATTACKERS")
	local defenderRows = Column(defenders, rightX, bodyY, "defenders",
		"DEFENDERS")

	draw.SimpleText("VS", "UI_Bold", x + width * 0.5, bodyY + icon * 0.5,
		palette.color_primary, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	--[[
		SKIRMISHERS GET THEIR OWN ROW, under both, with a VS of their own -
		they are on neither side and drawing them in one of the columns would
		say they were.
	]]
	if (#skirmishers > 0) then
		--[[
			NO SECOND "VS". There is one fight and one VS in the middle of it -
			a second one under the skirmishers read as though they were facing
			something of their own, which is the opposite of what a skirmisher
			is. Their label says what they are.
		]]
		local rows = math.max(attackerRows, defenderRows)
		local skirmishY = bodyY + rows * (icon + math.Round(4 * scale))
			+ math.Round(26 * scale)

		Column(skirmishers, x + width * 0.5 - icon * 0.5, skirmishY,
			"skirmishers", "SKIRMISHERS")
	end

	if (hidden > 0 and not expanded) then
		draw.SimpleTextOutlined("hold C for all", "ixLootSmall",
			x + width * 0.5, y + headHeight + math.Round(4 * scale), dim,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, color_black)
	end
end)
