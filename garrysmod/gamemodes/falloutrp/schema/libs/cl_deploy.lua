--[[
	The placement ghost.

	A translucent copy of what you are about to put down, following your aim,
	turnable with J and K, placed with left click and abandoned with right.

	ONE GHOST AT A TIME, AND IT OWNS ITS OWN HOOKS. Phoenix add three named
	hooks when the ghost appears and remove them from inside each of the three
	when the ghost goes - so cancelling in one path leaves the other two live
	until they next run and notice. Here the hooks are added once at file scope
	and do nothing while there is no ghost, which cannot leak and cannot be
	half-removed.

	It is a `ClientsideModel`, so `GetMaterial` and friends cannot be read back
	off it - see `07-gotchas.md`. Nothing here reads its state back.
]]

if (not CLIENT) then return end

ix.deploy = ix.deploy or {}

--- The ghost, and what to do when it is placed.
local ghost, callback, lastRotate

--[[
	Start placing something.

	`onPlace(position, angles)` runs on a left click that lands somewhere legal.
	The caller decides what that means - an item sends a net message, the
	faction menu sends a different one - so this knows nothing about what is
	being placed.
]]
function ix.deploy.Begin(model, onPlace)
	ix.deploy.Cancel()

	if (not model or model == "") then return false end

	ghost = ClientsideModel(model, RENDERGROUP_TRANSLUCENT)

	if (not IsValid(ghost)) then
		ghost = nil

		return false
	end

	ghost:SetRenderMode(RENDERMODE_TRANSALPHA)
	ghost:SetColor(Color(90, 255, 90, 110))
	ghost:SetAngles(Angle(0, LocalPlayer():EyeAngles().y + 180, 0))

	--[[
		Facing the player, not the world. Something put down in front of you is
		almost always meant to face you, so the useful default is the one you
		would otherwise have to rotate to every time.
	]]
	callback = onPlace
	lastRotate = 0

	return true
end

function ix.deploy.Cancel()
	if (IsValid(ghost)) then
		ghost:Remove()
	end

	ghost = nil
	callback = nil
end

function ix.deploy.IsPlacing()
	return IsValid(ghost)
end

--[[
	Where the ghost sits for a given aim.

	Lifted by its own bounds so it rests ON the surface rather than sinking
	into it: `GetModelBounds` gives the model's own origin offset, and props in
	these packs are modelled with the origin anywhere the artist felt like.
]]
local function GhostPosition()
	local trace = LocalPlayer():GetEyeTrace()
	local mins = ghost:GetModelBounds()

	return trace.HitPos + Vector(0, 0, -mins.z)
end

hook.Add("Think", "ixDeployGhost", function()
	if (not IsValid(ghost)) then return end

	ghost:SetPos(GhostPosition())

	if (lastRotate + ix.deploy.rotateInterval > CurTime()) then return end

	local left = input.IsKeyDown(KEY_J)
	local right = input.IsKeyDown(KEY_K)

	if (not left and not right) then return end

	lastRotate = CurTime()

	ghost:SetAngles(ghost:GetAngles()
		+ Angle(0, left and ix.deploy.rotateStep or -ix.deploy.rotateStep, 0))
end)

hook.Add("HUDPaint", "ixDeployGhost", function()
	if (not IsValid(ghost)) then return end

	local ok, reason = ix.deploy.CanPlace(LocalPlayer(), ghost:GetPos())

	--[[
		The ghost turns red when the click would be refused, so the answer
		arrives before the click rather than as a notification after it.
	]]
	ghost:SetColor(ok and Color(90, 255, 90, 110) or Color(255, 90, 90, 110))

	local screen = ghost:GetPos():ToScreen()
	local palette = ix.fallout.GetPalette()
	local x, y = screen.x, screen.y

	draw.SimpleTextOutlined(ok and "LEFT CLICK to place" or reason,
		"ixLootRow", x, y, ok and palette.text_primary or Color(255, 120, 120),
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)

	draw.SimpleTextOutlined("J and K to turn", "ixLootSmall", x, y + 20,
		palette.text_primary, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1,
		color_black)

	draw.SimpleTextOutlined("RIGHT CLICK to cancel", "ixLootSmall", x, y + 38,
		palette.text_primary, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1,
		color_black)
end)

--[[
	`KeyPress` rather than a mouse hook, because the player is not in a menu -
	the ghost is placed with the same buttons as firing, and this is the hook
	that sees them.

	The shot is swallowed by `CanPlayerDoPrimaryAction` below, or placing
	something would also swing whatever you are holding.
]]
hook.Add("KeyPress", "ixDeployGhost", function(client, key)
	if (not IsValid(ghost) or client ~= LocalPlayer()) then return end

	if (key == IN_ATTACK2) then
		ix.deploy.Cancel()

		return
	end

	if (key ~= IN_ATTACK) then return end

	local position, angles = ghost:GetPos(), ghost:GetAngles()

	if (not ix.deploy.CanPlace(client, position)) then return end

	local run = callback

	--[[
		Cancelled BEFORE the callback runs. The callback usually opens a menu
		or sends a message, and a ghost still standing there afterwards is a
		second placement waiting to happen on the next click.
	]]
	ix.deploy.Cancel()

	if (run) then
		run(position, angles)
	end
end)

--- Placing something should not also fire the weapon in your hands.
hook.Add("CanPlayerDoPrimaryAction", "ixDeployGhost", function()
	if (IsValid(ghost)) then return false end
end)

--[[
	The ghost does not survive dying, or the character changing under it. Both
	leave you aiming a translucent locker you can no longer place.
]]
hook.Add("PlayerDeath", "ixDeployGhost", ix.deploy.Cancel)
hook.Add("CharacterLoaded", "ixDeployGhost", ix.deploy.Cancel)
