--[[
	Damage readout.

	Ported from Phoenix's `plugins/damageview`. On weapon switch it prints the
	held weapon's damage and the bonus SPECIAL adds, beside the crosshair, then
	fades out:

	    DMG: 20 (+12.03)

	Phoenix's version, kept:
	  * position beside the crosshair at ScrW/2 + 25, ScrH/2 - 45
	  * UI_Medium, palette colour, one second solid then a fade
	  * the bonus is the SPECIAL modifier applied to base damage

	Fixed on the way over:

	  * **Their line 61 crashes on melee.** `self.energyAmmo[primary.Ammo]` is
	    tested BEFORE the melee branch, and a melee weapon has no `Primary`, so
	    indexing it throws. The classification here goes through
	    `ix.special.ClassifyWeapon`, which handles that.
	  * **Unrounded floats.** They concatenate `damage * modifier` raw, which
	    prints things like `12.030000000001`. Formatted to two decimals.
	  * Their `nut.rarity:dmgMult` call is dropped - no rarity system yet. The
	    `GetWeaponDisplayDamage` hook below is where it plugs in when there is
	    one, so this file will not need editing again.
]]

local PLUGIN_COLOR = Color(255, 255, 255, 255)

local shouldDraw = false
local fadeStart = 0
local alpha = 0

local HOLD_TIME = 1      -- seconds fully opaque
local FADE_RATE = 100    -- alpha per second

--[[
	The clientside signature of PlayerSwitchWeapon is (oldWeapon, newWeapon) -
	no player argument - while the serverside one leads with the player. Sniffing
	the first argument covers both, rather than assuming one shape.
]]
hook.Add("PlayerSwitchWeapon", "ixDamageView", function(first)
	if (IsValid(first) and first.IsPlayer and first:IsPlayer()
	and first ~= LocalPlayer()) then
		return
	end

	shouldDraw = true
	alpha = 255
	fadeStart = CurTime() + HOLD_TIME
end)

--[[
	Phoenix drives the fade from a Think hook that they add and remove on every
	weapon switch. Doing it in HUDPaint is equivalent and does not churn hooks.
]]
hook.Add("HUDPaint", "ixDamageView", function()
	if (not shouldDraw) then return end

	local client = LocalPlayer()

	if (not IsValid(client) or not client:Alive() or client.DisableHud) then return end

	local character = client:GetCharacter()

	if (not character) then return end

	local weapon = client:GetActiveWeapon()

	if (not IsValid(weapon)) then return end

	local damage = ix.special.GetWeaponDamage(weapon)

	if (not damage or damage <= 0) then return end

	-- Where a rarity system will scale the displayed damage.
	damage = hook.Run("GetWeaponDisplayDamage", client, weapon, damage) or damage

	if (CurTime() > fadeStart) then
		alpha = math.max(alpha - FrameTime() * FADE_RATE, 0)

		if (alpha <= 0) then
			shouldDraw = false
			return
		end
	end

	local multiplier = ix.special.GetDamageMultiplier(character, weapon)
	local bonus = damage * (multiplier - 1)

	local palette = ix.fallout.GetPalette()

	PLUGIN_COLOR.r, PLUGIN_COLOR.g, PLUGIN_COLOR.b =
		palette.color_primary.r, palette.color_primary.g, palette.color_primary.b
	PLUGIN_COLOR.a = alpha

	local text = string.format("DMG: %s (+%.2f)", damage, bonus)

	draw.TextShadow({
		text = text,
		font = "UI_Medium",
		pos = {ScrW() * 0.5 + 25, ScrH() * 0.5 - 45},
		color = PLUGIN_COLOR
	}, 1, alpha)
end)
