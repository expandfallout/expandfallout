--[[
	Squads, drawn: the list in the corner, the marks over people's heads, and
	the card that says somebody wants you.

	THE CLIENT KNOWS ONE SQUAD - ITS OWN. `ix.squad.mine` is whatever the
	server last sent (`ixSquadSync`), reshaped so `ix.squad.RankIn` reads it
	the way it reads a server squad: `roster` is the list the HUD walks,
	`members` and `officers` are the sets the shared code asks. Nothing here
	decides anything; every button and command is a request the server checks.

	`ix.squad` IS DECLARED HERE TOO: `cl_` files load before `sh_` ones
	(gotcha 26), so this runs before `sh_squad.lua` and must not read
	anything from it at file scope.
]]

if (not CLIENT) then return end

ix.squad = ix.squad or {}

local hud = CreateClientConVar("fo_squad_hud", "1", true, false,
	"Show your squad in the corner of the screen.")
local hudX = CreateClientConVar("fo_squad_hud_x", "0.01", true, false,
	"Where the squad list sits, as a fraction of the screen width.")
local hudY = CreateClientConVar("fo_squad_hud_y", "0.32", true, false,
	"Where the squad list sits, as a fraction of the screen height.")
local markers = CreateClientConVar("fo_squad_markers", "1", true, false,
	"Mark squad mates over their heads.")

--------------------------------------------------------------------------------
-- What the server says
--------------------------------------------------------------------------------

net.Receive("ixSquadSync", function()
	if (not net.ReadBool()) then
		ix.squad.mine = nil

		hook.Run("SquadUpdated")

		return
	end

	local data = net.ReadTable()

	data.members, data.officers = {}, {}

	for _, entry in ipairs(data.roster or {}) do
		data.members[entry.id] = true

		if (entry.rank == ix.squad.OFFICER) then
			data.officers[entry.id] = true
		end
	end

	ix.squad.mine = data

	--- Being in a squad answers any invitation that was still open.
	ix.squad.invite = nil

	hook.Run("SquadUpdated")
end)

net.Receive("ixSquadInvite", function()
	local data = net.ReadTable()

	data.expires = CurTime() + (data.seconds or 30)
	ix.squad.invite = data

	local entry = ix.squad.palette and ix.squad.palette[data.color or 1]
	local color = entry and entry.color or color_white

	chat.AddText(color, "[SQUAD] ", color_white, (data.from or "Somebody")
		.. " invited you to the squad '" .. (data.squad or "?") .. "'. ",
		color, "/squadaccept", color_white, " or ", color, "/squaddecline",
		color_white, ".")

	LocalPlayer():EmitSound("phoenix/ui/nv/ui_highlight.mp3", 60, 100, 0.6)
end)

net.Receive("ixSquadMenu", function()
	ix.squad.OpenMenu()
end)

--------------------------------------------------------------------------------
-- Asking for things
--------------------------------------------------------------------------------

--- Every request the window and the binds make, in one message.
function ix.squad.Act(action, id, text)
	net.Start("ixSquadAct")
		net.WriteString(action)
		net.WriteUInt(id or 0, 32)
		net.WriteString(text or "")
	net.SendToServer()

	if (action == "accept" or action == "decline") then
		ix.squad.invite = nil
	end
end

function ix.squad.OpenMenu()
	if (IsValid(ix.gui.squad)) then ix.gui.squad:Remove() end

	ix.gui.squad = vgui.Create("ixFOSquad")
end

--- Bindable: `bind f7 fo_squad_accept`.
concommand.Add("fo_squad_accept", function() ix.squad.Act("accept") end)
concommand.Add("fo_squad_decline", function() ix.squad.Act("decline") end)
concommand.Add("fo_squad_menu", function() ix.squad.OpenMenu() end)

--------------------------------------------------------------------------------
-- Drawing it
--------------------------------------------------------------------------------

local BLACK = Color(0, 0, 0, 220)
local DIM = Color(140, 140, 140)
local DOWN = Color(210, 60, 50)
local NOTE = Color(190, 190, 180)

local function S(value)
	return math.max(math.Round(value * (ScrH() / 1080)), 1)
end

--[[
	FONTS OF ITS OWN. The first version drew names in `UI_Bold`, which is a
	heading size: the list came out twice as tall as its rows and the bar
	ran through the letters. These are sized for a list read at a glance,
	scaled with the screen the way `cl_menufonts.lua` scales the menus, and
	rebuilt when the resolution changes.
]]
local FONTS = {
	ixSquadTitle = {size = 22, weight = 700},
	ixSquadName = {size = 17, weight = 700},
	ixSquadSmall = {size = 13, weight = 600},
	ixSquadMarker = {size = 15, weight = 700},
	ixSquadMarkerFar = {size = 11, weight = 600}
}

local builtAt

local function Fonts()
	local scale = ScrH() / 1080

	if (builtAt == scale) then return end

	builtAt = scale

	for name, data in pairs(FONTS) do
		surface.CreateFont(name, {
			font = "Roboto",
			size = math.max(math.Round(data.size * scale), 9),
			weight = data.weight,
			antialias = true,
			extended = true
		})
	end
end

--- The player playing a character, by the id the server networks with them.
local function PlayerOf(id)
	for _, client in player.Iterator() do
		if (client:GetNetVar("char") == id) then return client end
	end

	return nil
end

local function Bar(x, y, w, h, fraction, color)
	surface.SetDrawColor(0, 0, 0, 200)
	surface.DrawRect(x - 1, y - 1, w + 2, h + 2)
	surface.SetDrawColor(color.r, color.g, color.b, color.a or 255)
	surface.DrawRect(x, y, math.max(0, math.floor(w * fraction)), h)
end

local function Health(client)
	if (not IsValid(client) or not client:Alive()) then return 0 end

	return math.Clamp(client:Health() / math.max(client:GetMaxHealth(), 1),
		0, 1)
end

local function Marked(entry)
	local mark = ix.squad.rankMarks and ix.squad.rankMarks[entry.rank]

	return mark and (entry.name .. " " .. mark) or entry.name
end

--[[
	One person on the list: their level in a box of the squad's colour, their
	name with the leader's star, a health bar under the name, and how far
	away they are - which is the thing a list in the corner is FOR. Somebody
	offline is greyed and says so; somebody dead has a red bar and says DOWN.

	The row is `ROW` tall: the box on the left, the name along the top, the
	bar along the bottom, so nothing runs through anything else.
]]
local ROW = 36

local function Member(entry, x, y, color, me)
	local box = S(20)
	local client = entry.online and PlayerOf(entry.id) or nil
	local here = IsValid(client)
	local alive = here and client:Alive()
	local tint = entry.online and color or DIM

	surface.SetDrawColor(0, 0, 0, 200)
	surface.DrawRect(x - 1, y + S(2) - 1, box + 2, box + 2)
	surface.SetDrawColor(tint.r, tint.g, tint.b, 255)
	surface.DrawRect(x, y + S(2), box, box)

	draw.SimpleText(entry.level or 1, "ixSquadSmall", x + box / 2,
		y + S(2) + box / 2, color_black, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	local left = x + box + S(8)

	draw.SimpleTextOutlined(Marked(entry), "ixSquadName", left, y - S(1),
		tint, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, BLACK)

	local barW, barH = S(120), S(5)
	local barY = y + S(22)

	if (here) then
		Bar(left, barY, barW, barH, Health(client), alive and tint or DOWN)

		if (client ~= me) then
			local text = alive and (math.Round(me:GetPos():Distance(
				client:GetPos()) / 52.49) .. "m") or "DOWN"

			draw.SimpleTextOutlined(text, "ixSquadSmall", left + barW + S(8),
				barY + barH / 2, alive and tint or DOWN, TEXT_ALIGN_LEFT,
				TEXT_ALIGN_CENTER, 1, BLACK)
		end
	else
		draw.SimpleTextOutlined(entry.online and "somewhere" or "offline",
			"ixSquadSmall", left, barY + barH / 2, DIM, TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER, 1, BLACK)
	end
end

--[[
	A POINT OVER A SQUAD MATE, THE SIZE OF HOW FAR AWAY THEY ARE.

	Text does not scale with distance, so a name over somebody two hills
	away was as big as one over somebody beside you - and a big label on a
	distant dot reads as a mistake. The point is a triangle drawn at a size
	that shrinks from `NEAR` to `FAR`; the name is drawn in a smaller font
	past `NEAR` but always drawn, because callouts need it; the health bar is
	only shown up close, where it can be read.
]]
local NEAR, FAR = 600, 2500

local function Point(x, y, size, color, alpha)
	draw.NoTexture()

	surface.SetDrawColor(0, 0, 0, alpha)
	surface.DrawPoly({
		{x = x - size - 1, y = y - size - 1},
		{x = x + size + 1, y = y - size - 1},
		{x = x, y = y + size + 1}
	})

	surface.SetDrawColor(color.r, color.g, color.b, alpha)
	surface.DrawPoly({
		{x = x - size, y = y - size},
		{x = x + size, y = y - size},
		{x = x, y = y + size}
	})
end

local function Marker(client, entry, color, me)
	if (not IsValid(client) or client == me or client:IsDormant()) then
		return
	end

	local top = client:GetPos() + Vector(0, 0, client:OBBMaxs().z + 12)
	local screen = top:ToScreen()

	if (not screen.visible) then return end

	local distance = me:GetPos():Distance(client:GetPos())
	local far = math.Clamp((distance - NEAR) / (FAR - NEAR), 0, 1)
	local size = Lerp(far, S(11), S(4))
	local alpha = math.Round(Lerp(far, 255, 170))
	local alive = client:Alive()
	local base = alive and color or DOWN
	local tint = Color(base.r, base.g, base.b, alpha)

	Point(screen.x, screen.y, size, base, alpha)

	--[[
		THE NAME IS ALWAYS THERE - it is what a callout is made of, and a
		point with no name on it is a point you cannot say anything about.
		Smaller past `NEAR`, never gone, never faded. Only the bar goes with
		distance, because a bar too small to read is noise.
	]]
	draw.SimpleTextOutlined(Marked(entry),
		distance < NEAR and "ixSquadMarker" or "ixSquadMarkerFar",
		screen.x, screen.y - size - S(3), base, TEXT_ALIGN_CENTER,
		TEXT_ALIGN_BOTTOM, 1, BLACK)

	if (alive and distance < NEAR) then
		Bar(screen.x - S(18), screen.y + size + S(4), S(36), S(3),
			Health(client), tint)
	end
end

--[[
	The invitation, as a card at the top of the screen with the two commands
	on it and a count-down. No popup, because a popup takes the mouse and
	somebody asked into a squad is usually in the middle of something - this
	waits, and `/squadaccept`, `fo_squad_accept` on a key, or the window's
	buttons answer it.
]]
local function Invitation(invite)
	local left = invite.expires - CurTime()

	if (left <= 0) then
		ix.squad.invite = nil

		return
	end

	local entry = ix.squad.palette and ix.squad.palette[invite.color or 1]
	local color = entry and entry.color or color_white
	local w, h = S(420), S(76)
	local x, y = (ScrW() - w) / 2, ScrH() * 0.16

	surface.SetDrawColor(10, 10, 10, 215)
	surface.DrawRect(x, y, w, h)
	surface.SetDrawColor(color.r, color.g, color.b, 255)
	surface.DrawRect(x, y, S(4), h)

	draw.SimpleText("SQUAD INVITATION", "ixSquadTitle", x + S(16), y + S(6),
		color)
	draw.SimpleText((invite.from or "Somebody") .. " invites you to '"
		.. (invite.squad or "?") .. "'", "ixSquadName", x + S(16), y + S(34),
		color_white)
	draw.SimpleText(string.format("/squadaccept    /squaddecline    %ds",
		math.ceil(left)), "ixSquadSmall", x + S(16), y + S(56), NOTE)
end

hook.Add("HUDPaint", "ixSquad", function()
	local me = LocalPlayer()

	if (not IsValid(me)) then return end

	Fonts()

	if (ix.squad.invite) then Invitation(ix.squad.invite) end

	local mine = ix.squad.mine

	if (not mine or not hud:GetBool()) then return end

	local color = ix.squad.ColorOf(mine)
	local x, y = ScrW() * hudX:GetFloat(), ScrH() * hudY:GetFloat()

	draw.SimpleTextOutlined(mine.name, "ixSquadTitle", x, y, color,
		TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, BLACK)

	surface.SetFont("ixSquadTitle")

	local tw, th = surface.GetTextSize(mine.name)

	surface.SetDrawColor(0, 0, 0, 200)
	surface.DrawRect(x - 1, y + th + S(1), tw + S(8), S(4))
	surface.SetDrawColor(color.r, color.g, color.b, 255)
	surface.DrawRect(x, y + th + S(2), tw + S(6), S(2))

	local rowY = y + th + S(12)

	for _, entry in ipairs(mine.roster or {}) do
		Member(entry, x, rowY, color, me)

		rowY = rowY + S(ROW)
	end

	if (not markers:GetBool()) then return end

	for _, entry in ipairs(mine.roster or {}) do
		if (entry.online) then
			Marker(PlayerOf(entry.id), entry, color, me)
		end
	end
end)
