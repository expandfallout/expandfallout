--[[
	The SlaveBoy's tracker, drawn: a mark over somebody you own, for a while,
	that only you can see.

	`ixSlaveLocate` arrives with the person and how long the mark lasts. The
	mark is the squad marker's shape - a point, a name, a distance - in the
	collar's colour, and when they are off screen it sits along the bottom of
	the view at their bearing, so it still says which way to walk.

	`ix.slavery` IS DECLARED HERE TOO: `cl_` files load before `sh_` ones
	(gotcha 26).
]]

if (not CLIENT) then return end

ix.slavery = ix.slavery or {}

--- `[player] = expires`.
local marks = {}

net.Receive("ixSlaveLocate", function()
	local target = net.ReadEntity()
	local seconds = net.ReadUInt(16)

	if (IsValid(target)) then marks[target] = CurTime() + seconds end

	LocalPlayer():EmitSound("phoenix/ui/nv/ui_popup_messagewindow.mp3", 60, 110,
		0.5)
end)

local COLLAR = Color(255, 120, 60)
local BLACK = Color(0, 0, 0, 220)

local function S(value)
	return math.max(math.Round(value * (ScrH() / 1080)), 1)
end

local builtAt

local function Fonts()
	local scale = ScrH() / 1080

	if (builtAt == scale) then return end

	builtAt = scale

	surface.CreateFont("ixSlaveMark", {font = "Roboto",
		size = math.max(math.Round(16 * scale), 9), weight = 700,
		antialias = true, extended = true})
	surface.CreateFont("ixSlaveMarkSmall", {font = "Roboto",
		size = math.max(math.Round(12 * scale), 9), weight = 600,
		antialias = true, extended = true})
end

local function Point(x, y, size, alpha)
	draw.NoTexture()

	surface.SetDrawColor(0, 0, 0, alpha)
	surface.DrawPoly({
		{x = x - size - 1, y = y - size - 1},
		{x = x + size + 1, y = y - size - 1},
		{x = x, y = y + size + 1}
	})

	surface.SetDrawColor(COLLAR.r, COLLAR.g, COLLAR.b, alpha)
	surface.DrawPoly({
		{x = x - size, y = y - size},
		{x = x + size, y = y - size},
		{x = x, y = y + size}
	})
end

hook.Add("HUDPaint", "ixSlaveLocate", function()
	if (next(marks) == nil) then return end

	local me = LocalPlayer()

	if (not IsValid(me)) then return end

	Fonts()

	local eye = me:EyePos()
	local yaw = me:EyeAngles().y

	for target, expires in pairs(marks) do
		if (not IsValid(target) or expires < CurTime()) then
			marks[target] = nil

			continue
		end

		local left = math.ceil(expires - CurTime())
		local at = target:GetPos() + Vector(0, 0, target:OBBMaxs().z + 12)
		local distance = math.Round(eye:Distance(at) / 52.49)
		local screen = at:ToScreen()
		local text = string.format("%s  %dm  (%ds)", target:Name(), distance,
			left)

		if (screen.visible and not target:IsDormant()) then
			Point(screen.x, screen.y, S(9), 255)
			draw.SimpleTextOutlined(text, "ixSlaveMark", screen.x,
				screen.y - S(12), COLLAR, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1,
				BLACK)
		else
			--[[
				OFF SCREEN: along the bottom edge at their bearing. A mark for
				somebody behind you that says nothing is no mark at all.
			]]
			local bearing = math.AngleDifference((at - eye):Angle().y, yaw)
			local x = ScrW() / 2 - math.Clamp(bearing / 90, -1, 1) * ScrW() * 0.42
			local y = ScrH() * 0.86

			Point(x, y, S(7), 220)
			draw.SimpleTextOutlined(text, "ixSlaveMarkSmall", x, y + S(10),
				COLLAR, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, BLACK)
		end
	end
end)
