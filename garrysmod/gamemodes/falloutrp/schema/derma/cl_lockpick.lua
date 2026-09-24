--[[
	The lock itself: two models, a cylinder and a bobby pin.

	This is Phoenix's lockpicking screen rebuilt on our own panels, and it is
	the same one New Vegas has: move the mouse to rotate the pin, hold the left
	button to turn the cylinder, and read how far it gets. The models
	(`lockpickinterface.mdl`, `bobbypin01.mdl`) and every sound come from
	`af_content_pack_1`, which this schema already mounts.

	WHAT THE CLIENT KNOWS: the pin's angle, and how far the cylinder turned
	when it asked. Nothing else. The sweet spot lives on the server and the
	answer comes back as one float - see `sv_lockpick.lua`.

	THE STATE MACHINE, because a panel with five booleans instead is a panel
	nobody can fix:

	    Intro    the interface animates in, then the pin
	    Idle     the pin can be rotated, and the cylinder turned
	    Break    the pin snaps, the server is told, and Idle resumes
	    NoPins   nothing left to pick with

	`difference` carries three meanings and they are worth naming: -2 is "not
	asked", -1 is "asked, waiting", and 0 to 1 is the answer. It is one number
	rather than three flags because the Think loop reads it every frame and a
	frame that arrives between two of those flags is a frame that draws a lie.
]]

local PANEL = {}

--[[
	SOUNDS THAT ACTUALLY EXIST.

	Phoenix pick `math.random(9)` for the cylinder and `math.random(17)` for
	the pin, and the content pack has neither: cylinderturn is missing 06, and
	pickmovement stops at 13. A missing sound is a silent frame and a console
	warning, so these are the files rather than the ranges.
]]
local CYLINDER = {"01", "02", "03", "04", "05", "07", "08", "09"}
local MOVEMENT = {}

for index = 1, 13 do
	MOVEMENT[index] = string.format("%02d", index)
end

local SOUND_PATH = "hrp/fx/lockpicking/"
local TENSION = SOUND_PATH .. "ui_lockpicking_picktension_01_lpm.mp3"

--- How fast the pin bends while the cylinder is jammed against its limit.
local WEAR_RATE = 60

function PANEL:Init()
	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:MakePopup()
	self:SetKeyboardInputEnabled(true)
	self:SetMouseInputEnabled(true)

	self.openTime = SysTime()
	self.state = "Intro"
	self.pinAngle = 0
	self.pinHealth = 100
	self.difference = -2
	self.turning = false
	self.lastCursorX = nil
	self.nextSound = 0
	self.breakAt = 0
	self.hideAt = 0
	self.debounce = CurTime() + 0.75

	--[[
		The camera looks down the +X axis at the lock, which is the way both
		models are built - the interface faces -X and the pin sits just below
		the origin.
	]]
	self.camPos = Vector(45, 0, 0)
	self.lookAt = vector_origin

	self.interface = ClientsideModel(
		"models/roadkill/fallout/terminals/lockpickinterface.mdl",
		RENDERGROUP_OTHER)

	self.pin = ClientsideModel(
		"models/roadkill/fallout/terminals/bobbypin01.mdl", RENDERGROUP_OTHER)

	for _, model in ipairs({self.interface, self.pin}) do
		if (IsValid(model)) then
			model:SetNoDraw(true)
			model:SetPos(vector_origin)
			model:SetAngles(angle_zero)
		end
	end

	if (IsValid(self.pin)) then
		self.pin:SetPos(Vector(0, 0, -1.75))
	end

	ix.gui.lockpick = self
end

function PANEL:Setup(entity, level, pins)
	self.entity = entity
	self.level = level or 1
	self.pins = pins or 0
	self.state = "Intro"
	self.pinHealth = 100

	self:Sequence(self.interface, "intro")
	self:Sequence(self.pin, "intro")

	if (IsValid(self.interface)) then self.interface:SetNoDraw(false) end
	if (IsValid(self.pin)) then self.pin:SetNoDraw(self.pins < 1) end
end

--------------------------------------------------------------------------------
-- The models
--------------------------------------------------------------------------------

function PANEL:Sequence(model, name)
	if (not IsValid(model)) then return false end

	local id = model:LookupSequence(name)

	if (not id or id < 0) then return false end

	model:ResetSequence(id)
	model:SetCycle(0)

	return true
end

--- The same, but only if it is not already playing - for a per-frame caller.
function PANEL:SequenceIfNew(model, name)
	if (not IsValid(model)) then return false end

	local id = model:LookupSequence(name)

	if (not id or id < 0 or model:GetSequence() == id) then return false end

	model:ResetSequence(id)
	model:SetCycle(0)

	return true
end

function PANEL:Play(path, gap, bForce)
	if (not bForce and self.nextSound > CurTime()) then return end

	LocalPlayer():EmitSound(path)
	self.nextSound = CurTime() + (gap or 0)
end

--------------------------------------------------------------------------------
-- Talking to the server
--------------------------------------------------------------------------------

--[[
	Ask how far the cylinder turns from where the pin is.

	ONCE PER TURN, which is what `difference == -1` is for. `Think` runs sixty
	times a second and the mouse button is held for whole seconds at a time; a
	request per frame would be sixty messages for one question.
]]
function PANEL:Ask()
	if (not self.turning or self.difference ~= -2) then return end
	if (not IsValid(self.entity)) then return end

	self.difference = -1

	net.Start("ixLockpickTurn")
		net.WriteEntity(self.entity)
		net.WriteInt(math.Round(self.pinAngle), 9)
	net.SendToServer()
end

function PANEL:Release()
	self.turning = false
	self.difference = -2

	LocalPlayer():StopSound(TENSION)

	if (IsValid(self.pin)) then
		self:SequenceIfNew(self.pin, "idle")
		self.pin:SetCycle(1)
	end
end

function PANEL:Opened()
	self:Play(SOUND_PATH .. "ui_lockpicking_unlock.mp3", 0.1, true)

	net.Start("ixLockpickUnlock")
		net.WriteEntity(self.entity)
		net.WriteInt(math.Round(self.pinAngle), 9)
	net.SendToServer()

	self:Remove()
end

function PANEL:Snap()
	self.state = "Break"
	self.pins = math.max(self.pins - 1, 0)
	self.breakAt = 0

	LocalPlayer():StopSound(TENSION)

	self:Sequence(self.pin, "break")
	self:Play(SOUND_PATH .. "pickbreak/ui_lockpicking_pickbreak_0"
		.. math.random(3) .. ".mp3", 0.1, true)
end

--------------------------------------------------------------------------------
-- The states
--------------------------------------------------------------------------------

function PANEL:Intro(delta)
	local interfaceCycle = self.interface:GetCycle()

	self.interface:SetCycle(math.min(interfaceCycle + delta, 1))

	if (self.pins < 1) then
		if (interfaceCycle >= 1) then
			self.state = "NoPins"
			self.pin:SetNoDraw(true)
			self:Sequence(self.interface, "turn")
		end

		return
	end

	if (interfaceCycle < 0.35) then return end

	self:Play(SOUND_PATH .. "ui_lockpicking_enter.mp3", 1.5)
	self.pin:SetNoDraw(false)

	local pinCycle = self.pin:GetCycle()

	self.pin:SetCycle(math.min(pinCycle + delta, 1))

	if (pinCycle < 1) then return end

	self.state = "Idle"
	self:Sequence(self.pin, "idle")
	self:Sequence(self.interface, "turn")
end

function PANEL:Idle(delta)
	local cycle = self.interface:GetCycle()

	--[[
		NOT TURNING: the cylinder falls back to rest. Reading the position of a
		cylinder that stays where you left it would give the answer away for
		free.
	]]
	if (not self.turning) then
		self.interface:SetCycle(math.Clamp(cycle - delta, 0, 1))

		LocalPlayer():StopSound(TENSION)
		self:SequenceIfNew(self.pin, "idle")
		self.pin:SetCycle(1)

		return
	end

	--- Asked, not answered yet. The cylinder waits rather than guessing.
	if (self.difference < 0) then return end

	if (cycle < self.difference) then
		self.interface:SetCycle(math.min(cycle + delta, self.difference))
		self:Play(SOUND_PATH .. "cylinderturn/ui_lockpicking_cylinderturn_"
			.. CYLINDER[math.random(#CYLINDER)] .. ".mp3", 0.7)

		return
	end

	--- All the way round: the lock is open.
	if (self.difference >= 1) then
		self:Opened()

		return
	end

	--[[
		JAMMED. The cylinder is as far as this angle will take it, so the pin
		takes the strain - and it is the HOLDING that breaks it, which is what
		makes hunting for the spot in small movements the right way to play.
	]]
	self.pinHealth = math.max(self.pinHealth - delta * WEAR_RATE, 0)

	if (self:SequenceIfNew(self.pin, "shake")) then
		self:Play(TENSION, 0.1, true)
	end

	local pinCycle = self.pin:GetCycle()

	self.pin:SetCycle(pinCycle >= 1 and 0 or pinCycle + delta * 2)

	if (self.pinHealth <= 0) then
		self:Snap()
	end
end

function PANEL:Break(delta)
	local cycle = self.pin:GetCycle()

	self.pin:SetCycle(math.min(cycle + delta, 0.9))

	--[[
		The server is told ONCE, on the frame the break begins, and it is the
		server that takes the pin out of the inventory. `breakAt` is both the
		"told" flag and the timer, which is why it is set before anything else.
	]]
	if (self.breakAt == 0) then
		self.breakAt = CurTime() + 2
		self.hideAt = CurTime() + 1.25

		net.Start("ixLockpickBroke")
			net.WriteEntity(self.entity)
		net.SendToServer()

		return
	end

	if (CurTime() > self.hideAt and CurTime() < self.breakAt) then
		self.pin:SetNoDraw(true)

		return
	end

	if (CurTime() < self.breakAt) then return end

	self.breakAt = 0
	self.difference = -2
	self.turning = false
	self.pinHealth = 100

	if (self.pins < 1) then
		self.state = "NoPins"
		self:Sequence(self.interface, "intro")

		return
	end

	self.state = "Intro"
	self.pin:SetNoDraw(false)
	self:Sequence(self.pin, "intro")
	self:Sequence(self.interface, "intro")
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------

function PANEL:PaintScene(width, height)
	local x, y = self:LocalToScreen(0, 0)
	local angles = (self.lookAt - self.camPos):Angle()

	--[[
		The pin is ROTATED BY A BONE rather than by the model's angles, because
		the model's own angles are what the intro animation is moving - turning
		the whole thing would fight it.
	]]
	self.pin:SetPos(Vector(0, 0, -1.75))
	self.pin:ManipulateBoneAngles(1, Angle(self.pinAngle, 0, 0))

	cam.Start3D(self.camPos, angles, 70, x, y, width, height, nil, 4096)
		render.SuppressEngineLighting(true)
		render.SetLightingOrigin(self.interface:GetPos())
		render.SetAmbientLight(0.2, 0.2, 0.2)
		render.SetModelLighting(BOX_TOP, 1, 1, 1)
		render.SetModelLighting(BOX_FRONT, 1, 1, 1)

		self.interface:DrawModel()

		if (not self.pin:GetNoDraw()) then
			self.pin:DrawModel()
		end

		render.SuppressEngineLighting(false)
		render.ResetModelLighting(1, 1, 1)
	cam.End3D()
end

function PANEL:PaintReadout(width, height)
	local palette = ix.fallout.GetPalette()
	local colour = palette.text_primary

	surface.SetDrawColor(colour)
	surface.DrawRect(width * 0.07, height * 0.65, 1, height * 0.09)
	surface.DrawRect(width * 0.07, height * 0.74, width * 0.125, 1)

	local function Row(label, value, y)
		draw.SimpleTextOutlined(label, "UI_Bold", width * 0.075, height * y,
			colour, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1, color_black)
		draw.SimpleTextOutlined(value, "UI_Bold", width * 0.2, height * y,
			colour, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER, 1, color_black)
	end

	Row("Bobby Pins", tostring(self.pins), 0.70)
	Row("Lock Level", ix.lockpick.Name(self.level), 0.72)

	draw.SimpleTextOutlined(self.state == "NoPins"
		and "Out of bobby pins - E to leave"
		or "E to leave", "UI_Bold", width * 0.95, height * 0.72, colour,
		TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER, 1, color_black)

	--[[
		THE PIN'S CONDITION, which Phoenix do not show and which this minigame
		reads much better with: the bar is the warning that the turn has been
		held too long, and without it the snap is a surprise every time.
	]]
	if (self.state ~= "Idle" or self.pinHealth >= 100) then return end

	local barWidth = width * 0.125

	surface.SetDrawColor(0, 0, 0, 200)
	surface.DrawRect(width * 0.075, height * 0.76, barWidth, 6)

	surface.SetDrawColor(ColorAlpha(palette.color_primary, 230))
	surface.DrawRect(width * 0.075, height * 0.76,
		barWidth * (self.pinHealth / 100), 6)
end

function PANEL:Paint(width, height)
	if (not IsValid(self.interface) or not IsValid(self.pin)) then return end

	--[[
		BLUR FIRST, DIM SECOND. `DrawBlur` redraws the blurred world on top of
		whatever is already on the panel, so dimming first and blurring second
		undoes the dim - the same order `fallout_ui/cl_menu.lua` settled on.
	]]
	ix.util.DrawBlur(self, 10, nil, 255)

	surface.SetDrawColor(0, 0, 0, 235)
	surface.DrawRect(0, 0, width, height)

	self:PaintScene(width, height)
	self:PaintReadout(width, height)
end

--------------------------------------------------------------------------------
-- Input
--------------------------------------------------------------------------------

function PANEL:Think()
	if (self:GetWide() ~= ScrW() or self:GetTall() ~= ScrH()) then
		self:SetSize(ScrW(), ScrH())
		self:SetPos(0, 0)
	end

	--- Walking away closes it, the same reach the server checks.
	local client = LocalPlayer()

	if (not IsValid(self.entity) or not IsValid(client)
	or client:GetPos():DistToSqr(self.entity:GetPos()) > 160 * 160) then
		self:Remove()

		return
	end

	local delta = RealFrameTime()

	if (self.state == "Intro") then
		self:Intro(delta)
	elseif (self.state == "Idle") then
		self:Idle(delta)
	elseif (self.state == "Break") then
		self:Break(delta)
	end
end

function PANEL:OnMousePressed(code)
	if (code ~= MOUSE_LEFT or self.state ~= "Idle") then return end
	if (self.debounce > CurTime()) then return end

	self.turning = true

	self:Ask()
end

function PANEL:OnMouseReleased(code)
	if (code ~= MOUSE_LEFT) then return end

	self:Release()
end

--[[
	The pin follows the mouse SIDEWAYS ONLY, and only when the cylinder is at
	rest - a pin that could be moved mid-turn would let somebody sweep the dial
	with the button held and read the answer off the animation.
]]
function PANEL:OnCursorMoved(x)
	if (self.state ~= "Idle" or self.turning or not IsValid(self.pin)
	or self.pin:GetCycle() < 1) then
		self.lastCursorX = x

		return
	end

	if (self.lastCursorX) then
		local moved = self.lastCursorX - x

		if (moved ~= 0) then
			self.pinAngle = math.Clamp(self.pinAngle - moved / 4, -90, 90)

			self:Play(SOUND_PATH .. "pickmovement/ui_lockpicking_pickmovement_"
				.. MOVEMENT[math.random(#MOVEMENT)] .. ".mp3", 0.2)
		end
	end

	self.lastCursorX = x
end

function PANEL:OnKeyCodePressed(key)
	if (self.debounce > CurTime()) then return end

	if (key == KEY_E or key == KEY_ESCAPE) then
		self:Remove()
	end
end

function PANEL:OnRemove()
	LocalPlayer():StopSound(TENSION)

	for _, model in ipairs({self.interface, self.pin}) do
		if (IsValid(model)) then model:Remove() end
	end

	if (ix.gui.lockpick == self) then ix.gui.lockpick = nil end
end

vgui.Register("ixFOLockpick", PANEL, "EditablePanel")
