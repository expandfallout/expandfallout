--[[
	Holding E on a person.

	Phoenix put every action you can take against another PLAYER - recognise
	me, tie them up, search them, check their collar - behind one menu, and
	registered them from wherever the feature lived:

	    nut.playerInteract.addFunc("ziptieRelease", {
	        name = "Untie",
	        callback = function(target) ... end,
	        canSee = function(target) ... end
	    })

	`nut.playerInteract` itself is server/schema code and is not in the scrape,
	so this is the same shape rebuilt on Helix's own parts rather than a port.

	WHAT HELIX ALREADY HAD, and why this file is small:

	    the checks         `Player:IsRestricted`, `DoStaredAction`, `SetAction`
	    the reach          96 units, which is what E has always meant here

	What Helix does NOT have is a menu that leaves you in control of your own
	character, so the list is drawn on the HUD instead of built as a panel -
	see the note above `ix.interact.Send` for why that matters more than it
	sounds like it should.

	SO WHAT IS ACTUALLY HERE: a registry, an ordering, and ONE net message.

	Phoenix gave every action its own net string and its own server handler,
	which is a receiver per verb and a validation per receiver - and their
	`canSee` runs on the CLIENT, so a handler that forgets to re-check is a
	client that can untie anybody anywhere. Here the client sends an id, and
	`ix.interact.Run` does the reach, alive and character checks once, for
	every action, before that action's own `OnCanRun`.

	THE FIELDS:

	    name       string, or function(target) for text that changes - the
	               collar entry counts its own time down in the menu
	    order      lower is higher up the list; `pairs` order is a different
	               menu on every open and that is unusable
	    canSee     CLIENT. Whether the entry is drawn at all
	    callback   CLIENT, optional. Runs INSTEAD of sending, for anything that
	               is purely presentation - a submenu, a confirmation
	    OnCanRun   SERVER, optional. The real permission check
	    OnRun      SERVER. The action
]]

ix.interact = ix.interact or {}
ix.interact.stored = ix.interact.stored or {}

--[[
	How far away the menu still works.

	Helix traces 96 units to open it and checks 96 again in
	`CanPlayerInteractEntity`. This is deliberately a little longer: the menu
	takes a moment to read and people drift, and a refusal that means "you
	moved four units" is indistinguishable from a bug.
]]
ix.interact.reach = 128

--- Register an action. Called from wherever the feature lives, not from here.
function ix.interact.Add(id, data)
	assert(isstring(id), "expected string id")
	assert(istable(data), "expected table for interaction '" .. id .. "'")

	data.id = id
	data.order = data.order or 100

	ix.interact.stored[id] = data
end

--[[
	The checks EVERY action shares, in one place.

	Returns false and a reason, so a caller can say what went wrong rather than
	failing silently - which is how Phoenix's read, and why "nothing happened"
	was the usual symptom over there.
]]
function ix.interact.CanReach(client, target)
	if (not IsValid(client) or not IsValid(target)) then return false end
	if (not target:IsPlayer() or target == client) then return false end

	if (not client:GetCharacter() or not target:GetCharacter()) then
		return false, "They are not anybody yet."
	end

	if (not client:Alive() or not target:Alive()) then
		return false, "Not now."
	end

	if (client:GetPos():DistToSqr(target:GetPos())
	> ix.interact.reach * ix.interact.reach) then
		return false, "You are too far away."
	end

	return true
end

if (SERVER) then
	util.AddNetworkString("ixInteract")

	--[[
		Run an action on somebody's behalf.

		The order matters: the shared checks, then the action's own, then the
		action. `OnCanRun` may return a reason as its second value and it is
		shown to whoever asked.
	]]
	function ix.interact.Run(client, id, target)
		local entry = ix.interact.stored[id]

		if (not entry or not entry.OnRun) then return false end

		local allowed, reason = ix.interact.CanReach(client, target)

		if (not allowed) then
			if (reason) then client:Notify(reason) end

			return false
		end

		if (entry.OnCanRun) then
			local ok, why = entry.OnCanRun(client, target)

			if (not ok) then
				if (why) then client:Notify(why) end

				return false
			end
		end

		return entry.OnRun(client, target) ~= false
	end

	net.Receive("ixInteract", function(length, client)
		--[[
			A quarter of a second between actions.

			Not a rate limit for its own sake: several of these start a stared
			action with a progress bar, and two of them started in the same
			frame leave a bar that never finishes.
		]]
		if ((client.ixInteractNext or 0) > CurTime()) then return end

		client.ixInteractNext = CurTime() + 0.25

		local id = net.ReadString()
		local target = net.ReadEntity()

		ix.interact.Run(client, id, target)
	end)

	return
end

--------------------------------------------------------------------------------
-- The menu
--------------------------------------------------------------------------------

--[[
	IT IS DRAWN ON THE HUD, NOT BUILT AS A PANEL, and that is the whole design.

	The first version used `ixEntityMenu` - Helix's own, the one a dropped item
	opens. It is a full screen VGUI panel that calls `MakePopup`, which grabs
	the mouse: the world greys out, the camera stops, and you stand still until
	you have chosen something. That is right for looting a box and wrong for
	this, because everything in this menu is something you do to a PERSON who is
	stood in front of you and is under no obligation to wait.

	So: a list of text drawn over the world while you hold E. You keep walking,
	you keep aiming, the crosshair is the pointer, and a click runs whatever it
	is on. Nothing is a panel and nothing takes the mouse.

	    hold E on somebody     the list appears where they are
	    look                   the crosshair moves over the entries
	    click                  that entry runs, and the list closes
	    let go of E            it closes, having done nothing

	THE LIST IS ANCHORED IN THE WORLD, BESIDE THEIR HEAD, and it has to be.

	The first version pinned it to the SCREEN at the position their head
	happened to be when it opened, on the theory that a list which does not
	move is easier to click. It is not clickable at all: the crosshair is
	welded to the centre of the screen, so a list that is also welded to the
	screen can never be reached by it - the list "locks on screen and does not
	move", which is exactly what it was told to do.

	Turning your head is the only thing that moves the crosshair relative to
	the world, so the entries have to be IN the world. They hang beside the
	target, projected to the screen every frame, and you look at the one you
	want. Walking away, turning right round, or the target moving all behave
	the way anybody would expect, because the list is where the person is.
]]

--- Ask the server to run an action. The default when an entry has no callback.
function ix.interact.Send(id, target)
	net.Start("ixInteract")
		net.WriteString(id)
		net.WriteEntity(target)
	net.SendToServer()
end

--[[
	Everything this player may do to that one, in order.

	`canSee` throwing is caught, because one badly written entry taking the
	whole menu down with it would be a feature nobody can use rather than an
	entry nobody can see.
]]
function ix.interact.Options(target)
	local options = {}

	for id, entry in pairs(ix.interact.stored) do
		if (entry.canSee) then
			local ok, visible = pcall(entry.canSee, target, LocalPlayer())

			if (not ok) then
				ErrorNoHalt("[falloutrp] interaction '" .. id
					.. "' canSee failed: " .. tostring(visible) .. "\n")

				continue
			end

			if (not visible) then continue end
		end

		local name = entry.name

		if (isfunction(name)) then
			local ok, text = pcall(name, target, LocalPlayer())

			name = ok and text or nil
		end

		if (not name) then continue end

		options[#options + 1] = {
			id = id,
			name = name,
			order = entry.order,
			callback = entry.callback
		}
	end

	table.sort(options, function(a, b)
		if (a.order == b.order) then return a.name < b.name end

		return a.order < b.order
	end)

	return options
end

--- `{target, options, x, y, hovered, refreshAt}` while one is open.
local open

local function Scaled(value)
	local scale = ix.fallout and ix.fallout.GetFontScale
		and ix.fallout.GetFontScale() or 1

	return math.Round(value * scale)
end

function ix.interact.IsOpen()
	return open ~= nil
end

function ix.interact.Close()
	open = nil
end

--[[
	Open it on somebody.

	The anchor is worked out here and then left alone. `ToScreen` on a head
	that is behind you answers nonsense, so the result is clamped into the
	screen with room for the whole list - which is also what stops a list
	opening half off the bottom when you look at somebody stood above you.
]]
function ix.interact.Open(target)
	local options = ix.interact.Options(target)

	if (#options == 0) then return false end

	open = {
		target = target,
		options = options,
		hovered = nil,
		refreshAt = CurTime() + 0.25
	}

	LocalPlayer():EmitSound("phoenix/ui/nv/ui_highlight.mp3", 45, 100, 0.4)

	return true
end

--[[
	Where the list hangs, in the world: IN FRONT OF THE PERSON.

	Not beside their head, which is where it was and which put the entries off
	to one corner of them - you had to look away from somebody to read a menu
	about them. It hangs a little in front of their chest instead, facing you,
	so the list is over the person it belongs to and the crosshair is already
	near it when you open it.

	FORWARD MEANS TOWARDS THE VIEWER, not the target's own forward: a menu
	behind somebody's back would be invisible for the exact half of encounters
	where you walked up behind them. The offset is worked out flat, ignoring
	pitch, so looking up or down at somebody does not slide the list sideways.
]]
function ix.interact.Anchor(target)
	local client = LocalPlayer()

	--[[
		Chest height. `EyePos` is the top of the head and hangs the list over
		them like a hat; a hand's width below it is where a person's face and
		chest are, which is where somebody looks when they walk up to you.
	]]
	local middle = target:EyePos() - Vector(0, 0, 14)

	local direction = client:EyePos() - middle
	direction.z = 0

	--- Standing exactly on top of them. Any direction will do.
	if (direction:IsZero()) then
		direction = client:GetAimVector() * -1
		direction.z = 0
	end

	direction:Normalize()

	--[[
		Sixteen units towards you, which is far enough that the text is not
		inside their model and near enough that it is plainly THEIR menu.
	]]
	return middle + direction * 16
end

--[[
	Run one. A `callback` is a client-side entry - a submenu, a confirmation -
	and everything else goes to the server by id.
]]
function ix.interact.Choose(option, target)
	target = target or (open and open.target)

	if (not option or not IsValid(target)) then return end

	ix.interact.Close()

	surface.PlaySound("phoenix/ui/nv/menu_next.mp3")

	if (option.callback) then
		option.callback(target)

		return
	end

	ix.interact.Send(option.id, target)
end

--------------------------------------------------------------------------------
-- Opening and closing it
--------------------------------------------------------------------------------

local function LookingAt()
	local client = LocalPlayer()
	local data = {}

	data.start = client:GetShootPos()
	data.endpos = data.start + client:GetAimVector() * 96
	data.filter = client

	local entity = util.TraceLine(data).Entity

	if (not IsValid(entity) or not entity:IsPlayer()) then return end
	if (entity == client) then return end

	return entity
end

--[[
	While E is down and somebody is in front of you.

	THE TRACE IS ONLY FOR OPENING. Once the list is up it stays up while they
	are near enough and alive, so you can look away from them and at the
	entries - which is the entire point of anchoring it in screen space.
]]
hook.Add("Think", "ixInteract", function()
	local client = LocalPlayer()

	if (not IsValid(client) or not client:GetCharacter() or not client:Alive()
	or vgui.CursorVisible() or ix.menu.IsOpen()) then
		ix.interact.Close()

		return
	end

	if (not client:KeyDown(IN_USE)) then
		ix.interact.Close()

		return
	end

	if (not open) then
		local target = LookingAt()

		if (target) then ix.interact.Open(target) end

		return
	end

	if (not ix.interact.CanReach(client, open.target)) then
		ix.interact.Close()

		return
	end

	--[[
		The names are rebuilt four times a second, because some of them count:
		the collar entry reads a deadline off the person wearing it, and a
		"Collar: 04:11" that never changes is worse than no number at all.
	]]
	if (CurTime() >= open.refreshAt) then
		open.refreshAt = CurTime() + 0.25

		local options = ix.interact.Options(open.target)

		if (#options == 0) then
			ix.interact.Close()

			return
		end

		open.options = options
	end
end)

--[[
	The click.

	`CreateMove` rather than a key hook, because the attack has to be REMOVED
	from the command as well as read: holding E and clicking would otherwise
	fire whatever is in your hands at the person you are choosing a menu entry
	on, which is a spectacular way to end a negotiation.

	The rising edge is tracked by hand. `cmd:KeyDown` is true for every frame
	the button is held, and one held click would run every entry the crosshair
	passed over.
]]
local attackWasDown = false

hook.Add("CreateMove", "ixInteract", function(cmd)
	if (not open) then
		attackWasDown = cmd:KeyDown(IN_ATTACK)

		return
	end

	local down = cmd:KeyDown(IN_ATTACK)

	if (down and not attackWasDown and open.hovered) then
		local option = open.hovered

		--[[
			CLOSED NOW, RUN NEXT FRAME.

			`CreateMove` is prediction: it can be called more than once for the
			same frame, and sending a net message or playing a sound from
			inside it is asking for both to happen twice. Closing here is what
			makes the second call a no-op; the action itself waits for a frame
			where it is an ordinary thing to do.
		]]
		local target = open.target

		ix.interact.Close()

		timer.Simple(0, function()
			if (not IsValid(target)) then return end

			surface.PlaySound("phoenix/ui/nv/menu_next.mp3")

			if (option.callback) then
				option.callback(target)

				return
			end

			ix.interact.Send(option.id, target)
		end)
	end

	attackWasDown = down

	cmd:RemoveKey(IN_ATTACK)
end)

--------------------------------------------------------------------------------
-- Drawing it
--------------------------------------------------------------------------------

local COLOR_SHADOW = Color(0, 0, 0, 200)
local COLOR_BACK = Color(12, 14, 12, 205)
local COLOR_BACK_HOVER = Color(30, 40, 30, 235)
local COLOR_TEXT = Color(210, 210, 200)
local COLOR_HINT = Color(160, 160, 150)
local COLOR_NONE = Color(0, 0, 0, 0)

hook.Add("HUDPaint", "ixInteract", function()
	if (not open) then return end

	if (not ix.fallout.LoadMenuFonts or not ix.fallout.LoadMenuFonts()) then
		return
	end

	local palette = ix.fallout.GetPalette()
	local target = open.target

	if (not IsValid(target)) then
		ix.interact.Close()

		return
	end

	--[[
		THE CROSSHAIR IS THE CURSOR AND IT NEVER MOVES. The list does, because
		it is in the world - see the note at the top of this file.
	]]
	local cursorX, cursorY = ScrW() * 0.5, ScrH() * 0.5
	local rowHeight = Scaled(26)
	local padding = Scaled(10)

	local screen = ix.interact.Anchor(target):ToScreen()

	--- Behind you. Nothing to draw, but the list is still open.
	if (not screen.visible) then
		open.hovered = nil

		return
	end

	--- Wide enough for the longest entry, and never narrower than the name.
	surface.SetFont("ixLootRow")

	local width = Scaled(150)

	for _, option in ipairs(open.options) do
		local textWidth = surface.GetTextSize(option.name)

		width = math.max(width, textWidth + padding * 4)
	end

	surface.SetFont("ixLootHeader")

	--[[
		Whoever this is, BY THE NAME YOU KNOW THEM BY. `GetCharacterName` is
		the recognition hook, so somebody you have not been introduced to is
		described rather than named - the menu must not be the one place in the
		game that leaks a name.
	]]
	local character = target:GetCharacter()
	local title = (character and hook.Run("GetCharacterName", target))
		or (character and character:GetName())
		or target:Name()

	local titleWidth = surface.GetTextSize(title)

	width = math.max(width, titleWidth + padding * 4)

	--[[
		Centred on the anchor, and clamped only enough to keep it on screen -
		clamping harder would peel the list away from the person it belongs to,
		which is the thing that made the first version unusable.
	]]
	local height = Scaled(24) + #open.options * rowHeight + Scaled(20)

	local x = math.Clamp(screen.x - width * 0.5, Scaled(8),
		math.max(ScrW() - width - Scaled(8), Scaled(8)))
	local y = math.Clamp(screen.y - height * 0.5, Scaled(8),
		math.max(ScrH() - height - Scaled(8), Scaled(8)))

	surface.SetDrawColor(COLOR_SHADOW)
	surface.DrawRect(x, y, width, Scaled(22))

	draw.SimpleText(title, "ixLootHeader", x + width * 0.5, y + Scaled(11),
		palette.color_primary, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	y = y + Scaled(24)

	--[[
		The hovered entry is worked out while DRAWING rather than in `Think`,
		because it is a question about rectangles that only exist here - and
		answering it twice would be two places to get the same maths wrong.
	]]
	open.hovered = nil

	for _, option in ipairs(open.options) do
		local hovered = cursorX >= x and cursorX <= x + width
			and cursorY >= y and cursorY <= y + rowHeight

		if (hovered) then open.hovered = option end

		surface.SetDrawColor(hovered and COLOR_BACK_HOVER or COLOR_BACK)
		surface.DrawRect(x, y, width, rowHeight)

		surface.SetDrawColor(hovered and palette.color_primary or COLOR_NONE)
		surface.DrawOutlinedRect(x, y, width, rowHeight, 1)

		draw.SimpleText(option.name, "ixLootRow", x + width * 0.5,
			y + rowHeight * 0.5,
			hovered and palette.color_bright or COLOR_TEXT,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		y = y + rowHeight
	end

	draw.SimpleText("Look at an option and click", "ixLootSmall",
		x + width * 0.5, y + Scaled(10), COLOR_HINT,
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

--[[
	HELIX'S OWN MENU IS SUPPRESSED, NOT USED.

	`GM:KeyRelease` calls `ShowEntityMenu` when E is released while looking at
	anything with a `GetEntityMenu`, which the player meta has - so letting it
	run would open the full screen panel this file exists to replace, on the
	very key release that just closed our list.

	Returning a value is what stops the gamemode method running at all; see
	gotcha 9, where the same mechanism was a bug rather than the point.
]]
hook.Add("ShowEntityMenu", "ixInteract", function(entity)
	if (not IsValid(entity) or not entity:IsPlayer()) then return end

	return true
end)
