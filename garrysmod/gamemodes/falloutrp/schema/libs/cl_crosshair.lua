--[[
	Drawing it.

	See `sh_crosshair.lua` for what the settings are. This is the drawing, the
	hit marker, and keeping every other crosshair out of the way.

	IT IS DRAWN AT THE END OF THE HUD, in `PostDrawHUD`, which is where
	Phoenix's is: anything drawn in `HUDPaint` can be covered by a panel or a
	weapon's own overlay, and a crosshair under something else is worse than
	none.
]]

if (not CLIENT) then return end

ix.crosshair = ix.crosshair or {}

--[[
	The live settings, filled in by `Load`.

	EMPTY AT FILE SCOPE, not `ix.crosshair.Defaults()`. `libs/` is included in
	alphabetical order, so this file runs BEFORE `sh_crosshair.lua` and there is
	no `Defaults` to call yet - calling it here is an error on load, and an
	error on load means nothing below this line exists at all.

	It does not need one: `Get` falls back to the setting's own default for any
	key that is not in here, so an empty table behaves exactly like a fresh set
	of defaults until the file is read.
]]
ix.crosshair.current = ix.crosshair.current or {}

local FILE = "falloutrp/crosshair.json"

function ix.crosshair.Get(key)
	local value = ix.crosshair.current[key]

	if (value == nil) then
		local setting = ix.crosshair.byKey[key]

		return setting and setting.default
	end

	return value
end

function ix.crosshair.Set(key, value)
	local clean = ix.crosshair.Clean(key, value)

	if (clean == nil) then return end

	ix.crosshair.current[key] = clean

	ix.crosshair.Save()
end

--------------------------------------------------------------------------------
-- The file
--------------------------------------------------------------------------------

--[[
	Saved on this player's own machine, like Phoenix's.

	A crosshair is a preference rather than character state - it should follow
	somebody between characters and between servers running this schema, and it
	has no business in the database.
]]
function ix.crosshair.Save()
	if (not file.Exists("falloutrp", "DATA")) then
		file.CreateDir("falloutrp")
	end

	file.Write(FILE, util.TableToJSON(ix.crosshair.current, true))
end

function ix.crosshair.Load()
	local defaults = ix.crosshair.Defaults()

	if (file.Exists(FILE, "DATA")) then
		local stored = util.JSONToTable(file.Read(FILE, "DATA") or "") or {}

		--[[
			MERGED INTO THE DEFAULTS, not used instead of them. A file written
			before a setting existed is missing that key, and a crosshair that
			half loads is one nobody can explain.
		]]
		for key, value in pairs(stored) do
			local clean = ix.crosshair.Clean(key, value)

			if (clean ~= nil) then defaults[key] = clean end
		end
	end

	ix.crosshair.current = defaults
	ix.crosshair.loaded = true
end

function ix.crosshair.Reset()
	ix.crosshair.current = ix.crosshair.Defaults()

	ix.crosshair.Save()
end

hook.Add("InitPostEntity", "ixCrosshair", ix.crosshair.Load)

--- `InitPostEntity` has already gone by on a `lua_refresh`, hence the timer.
timer.Simple(1, function()
	if (not ix.crosshair.loaded) then
		ix.crosshair.Load()
	end
end)

--------------------------------------------------------------------------------
-- Getting out of the way
--------------------------------------------------------------------------------

--[[
	Helix's, the engine's, and every weapon's own.

	`CHudCrosshair` is the engine element. A SWEP draws its own when
	`SWEP.DrawCrosshair` is true, which is a field on the weapon's TABLE rather
	than anything hookable - so the field is turned off on every registered
	weapon, and remembered, so that turning ours off puts theirs back exactly as
	it was rather than leaving the server's weapons quietly modified.
]]
local hidden = {}

local function Suppress(bState)
	for _, weapon in ipairs(weapons.GetList()) do
		local class = weapon.ClassName

		if (not class) then continue end

		local stored = weapons.GetStored(class)

		if (not stored) then continue end

		if (bState) then
			if (hidden[class] == nil) then
				hidden[class] = stored.DrawCrosshair == nil and "nil"
					or stored.DrawCrosshair
			end

			stored.DrawCrosshair = false
		elseif (hidden[class] ~= nil) then
			stored.DrawCrosshair = hidden[class] ~= "nil" and hidden[class]
				or nil

			hidden[class] = nil
		end
	end
end

--[[
	Applied a moment after joining and whenever the setting changes. On a timer
	rather than immediately because the weapon list is not complete until the
	server has sent its own.
]]
function ix.crosshair.Apply()
	Suppress(ix.crosshair.Get("enabled") and true or false)
end

timer.Simple(5, ix.crosshair.Apply)

hook.Add("HUDShouldDraw", "ixCrosshair", function(element)
	if (element == "CHudCrosshair" and ix.crosshair.Get("enabled")) then
		return false
	end
end)

--------------------------------------------------------------------------------
-- The hit marker
--------------------------------------------------------------------------------

local lastHit = 0

--[[
	Phoenix listen for the weapon base's `longsword_hitmarker`, which only the
	guns send. This listens for that AND for the schema's own message, which is
	sent for anything that damages anybody - so a pickaxe, a knife and a
	grenade all mark as well.
]]
net.Receive("ixHitMarker", function()
	lastHit = CurTime()
end)

net.Receive("longsword_hitmarker", function()
	lastHit = CurTime()
end)

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------

--[[
	A line with thickness, which `surface.DrawLine` does not have.

	Phoenix's `DrawThickLine`, kept whole: four points either side of the line's
	normal, drawn as a quad.
]]
local function ThickLine(x1, y1, x2, y2, thickness)
	local dx, dy = x2 - x1, y2 - y1
	local length = math.sqrt(dx * dx + dy * dy)

	if (length == 0) then return end

	local nx, ny = -dy / length, dx / length
	local half = thickness * 0.5

	surface.DrawPoly({
		{x = x1 + nx * half, y = y1 + ny * half},
		{x = x1 - nx * half, y = y1 - ny * half},
		{x = x2 - nx * half, y = y2 - ny * half},
		{x = x2 + nx * half, y = y2 + ny * half}
	})
end

--- An arm of the cross, with its outline underneath.
local function Arm(x, y, width, height, colour, outline, thickness)
	if (outline) then
		surface.SetDrawColor(outline)
		surface.DrawRect(x - thickness, y - thickness,
			width + thickness * 2, height + thickness * 2)
	end

	surface.SetDrawColor(colour)
	surface.DrawRect(x, y, width, height)
end

--- Where the crosshair goes: the aim point, or the middle of the screen.
local function Centre(client)
	local x, y = ScrW() * 0.5, ScrH() * 0.5

	if (not ix.crosshair.Get("follow")) then return x, y end

	local angles = client:EyeAngles()

	angles:Add(client:GetViewPunchAngles())

	local trace = util.TraceLine({
		start = client:GetShootPos(),
		endpos = client:GetShootPos() + angles:Forward() * 9000,
		filter = client
	})

	if (not trace.Hit) then return x, y end

	local screen = trace.HitPos:ToScreen()

	if (not screen.visible) then return x, y end

	return math.Round(screen.x), math.Round(screen.y)
end

--[[
	Whether there is any point drawing one at all.

	The list is Phoenix's, plus the two this schema has of its own: the
	character menu and the interaction menu both take the screen.
]]
local function ShouldDraw(client)
	if (not ix.crosshair.Get("enabled")) then return false end
	if (not client:GetCharacter() or not client:Alive()) then return false end
	if (IsValid(client:GetVehicle())) then return false end
	if (vgui.CursorVisible()) then return false end

	local ragdoll = Entity(client:GetLocalVar("ragdoll", 0))

	if (IsValid(ragdoll) and not ragdoll:IsWorld()) then return false end

	if (hook.Run("ShouldDrawCrosshair") == false) then return false end

	--[[
		A WEAPON, MEANING SOMETHING THAT SHOOTS OR SWINGS.

		Hands and keys are weapon entities as far as the engine is concerned,
		so "is holding a weapon" has to mean more than `IsValid` - the list is
		`ix.armor.validStealthWeapons`, which is the same question asked
		elsewhere for stealth, and the same answer.
	]]
	local weapon = client:GetActiveWeapon()
	local real = IsValid(weapon)
		and not ix.armor.validStealthWeapons[weapon:GetClass()]

	if (ix.crosshair.Get("weaponsOnly") and not real) then return false end

	--[[
		LOWERED ONLY APPLIES TO A REAL WEAPON. `IsWepRaised` is false for empty
		hands and always will be, so asking it about them would hide the
		crosshair for anybody not holding a gun - which is exactly the bug this
		setting caused when it was on by default.
	]]
	if (real and ix.crosshair.Get("hideLowered") and client.IsWepRaised
	and not client:IsWepRaised()) then
		return false
	end

	return true
end

hook.Add("PostDrawHUD", "ixCrosshair", function()
	local client = LocalPlayer()

	if (not IsValid(client) or not ShouldDraw(client)) then return end

	local colour = ix.crosshair.ToColor(ix.crosshair.Get("colour"))
	local outline = ix.crosshair.Get("outline")
		and ix.crosshair.ToColor(ix.crosshair.Get("outlineColour")) or nil
	local outlineSize = ix.crosshair.Get("outlineSize")

	local cx, cy = Centre(client)
	local shape = ix.crosshair.Get("shape")
	local gap = ix.crosshair.Get("gap")
	local size = ix.crosshair.Get("size")
	local thickness = ix.crosshair.Get("thickness")

	--[[
		THE GAP OPENS WITH THE WEAPON'S SPREAD, which is Phoenix's
		`recoilEffectsSpread` and reads off the same field: the longsword base
		keeps its current spread on `LastSpread`.
	]]
	if (ix.crosshair.Get("spread")) then
		local weapon = client:GetActiveWeapon()

		if (IsValid(weapon) and weapon.LastSpread) then
			gap = gap + weapon.LastSpread * 100
		end
	end

	if (shape == "cross") then
		local half = math.floor(thickness * 0.5)

		Arm(cx - gap - size, cy - half, size, thickness, colour, outline,
			outlineSize)
		Arm(cx + gap, cy - half, size, thickness, colour, outline, outlineSize)
		Arm(cx - half, cy + gap, thickness, size, colour, outline, outlineSize)

		--- The top arm is what a T crosshair leaves off.
		if (not ix.crosshair.Get("tShape")) then
			Arm(cx - half, cy - gap - size, thickness, size, colour, outline,
				outlineSize)
		end
	elseif (shape == "circle") then
		if (outline) then
			for ring = 0, outlineSize do
				surface.DrawCircle(cx, cy, gap + size + ring, outline)
				surface.DrawCircle(cx, cy, gap - ring, outline)
			end
		end

		for ring = 0, math.max(size - 1, 0) do
			surface.DrawCircle(cx, cy, gap + ring, colour)
		end
	end

	if (ix.crosshair.Get("dot") or shape == "dot") then
		local dot = ix.crosshair.Get("dotSize")
		local half = dot * 0.5

		Arm(cx - half, cy - half, dot, dot, colour, outline, outlineSize)
	end

	--------------------------------------------------------------------------
	-- The hit marker
	--------------------------------------------------------------------------

	if (not ix.crosshair.Get("hitMarker")) then return end

	local life = ix.crosshair.Get("hitTime") / 10
	local left = lastHit + life - CurTime()

	if (left <= 0) then return end

	--[[
		Fading out over its own lifetime, which is what makes it read as a
		flash rather than as something that appeared and vanished.
	]]
	local marker = ix.crosshair.ToColor(ix.crosshair.Get("hitColour"))

	marker.a = marker.a * math.Clamp(left / life, 0, 1)

	local length = ix.crosshair.Get("hitSize")
	local hitGap = math.max(length * 0.4, 2)
	local thick = math.max(math.Round(ScrH() * 0.0015), 1)

	surface.SetDrawColor(marker)

	ThickLine(cx - hitGap, cy - hitGap, cx - hitGap - length,
		cy - hitGap - length, thick)
	ThickLine(cx + hitGap, cy - hitGap, cx + hitGap + length,
		cy - hitGap - length, thick)
	ThickLine(cx - hitGap, cy + hitGap, cx - hitGap - length,
		cy + hitGap + length, thick)
	ThickLine(cx + hitGap, cy + hitGap, cx + hitGap + length,
		cy + hitGap + length, thick)
end)

--- `/Crosshair` asks the server, which asks back. See `cl_crosshairconfig.lua`.
net.Receive("ixCrosshairOpen", function()
	vgui.Create("ixFOCrosshair")
end)
