--[[
	Fallout UI - HUD.

	Ported from Phoenix's `fallout_ui/cl_fallout_hud.lua`. Two styles, chosen
	per client through the `falloutHud` option:

	  nv  - New Vegas. The bracketed left/right plates with tick-mark HP and AP
	        meters, ammo on the right, condition icons stacked at the left.
	  f4  - Fallout 4. Flat labelled bars.

	Plus a shared compass along the top.

	Differences from Phoenix, deliberate:

	  * Everything reads through a PROVIDER table rather than calling
	    `char:getHunger()` and friends directly. Phoenix's HUD assumes their
	    hunger, thirst, radiation and race systems all exist; ours has none of
	    them yet, and a direct call would be a nil-index error every frame. A
	    provider that returns nil simply removes that readout from the HUD, so
	    this file needs no edit when those systems land - just fill in the
	    provider.
	  * Colours come from the cached palette instead of being rebuilt inline
	    every frame. Phoenix allocates a table per bar per frame in `drawBar`.
	  * `max = max - 1` in Phoenix's drawBar divides by zero when max is 1.
	    Guarded.
	  * The F4 ammo readout used fixed pixel offsets (w - 52, h - 128), which
	    drift badly off 1080p. Screen-relative now.
	  * Radiation tick sounds are guarded behind a file check - that content
	    pack is not installed, and PlaySound on a missing file spams the console.
]]

ix.fallout = ix.fallout or {}
ix.fallout.hud = ix.fallout.hud or {}

local leftHud = Material("phoenix/hud/leftbar.png", "noclamp smooth")
local rightHud = Material("phoenix/hud/rightbar.png", "noclamp smooth")
local hudTick = Material("phoenix/hud/hudtick_new.png", "noclamp smooth")

local hungerIcon = Material("phoenix/overhaul/food.png", "noclamp smooth")
local thirstIcon = Material("phoenix/overhaul/water.png", "noclamp smooth")
local radiationIcon = Material("phoenix/overhaul/rads.png", "noclamp smooth")
local radiationCounter = Material("phoenix/overhaul/rads_counter.png", "noclamp smooth")

local gradient = Material("vgui/gradient_down")

--[[
	New Vegas meter slot.

	The HP and AP tick runs have to sit inside the printed meter area of
	leftbar.png / rightbar.png. Phoenix positions each tick from its own
	fraction of the plate width (0.0175 wide, 0.003 apart, 43 of them) - the
	run length is therefore whatever 43 of those happens to add up to, which
	is not tied to the artwork and drifts as rounding changes with resolution.

	Here the SLOT is the primitive: the ticks are spaced to fill exactly that
	span, so the run can never extend past it at any resolution.

	Fractions are convars so the slot can be aligned against the art live -
	`fo_hud_debug 1` outlines the plate and the slot to align against.
]]
local cvarSlotX = CreateClientConVar("fo_hud_slot_x", "0.045", true, false,
	"NV HUD: meter slot start, as a fraction of the plate width.")
local cvarSlotW = CreateClientConVar("fo_hud_slot_w", "0.8", true, false,
	"NV HUD: meter slot width, as a fraction of the plate width.")
local cvarSlotY = CreateClientConVar("fo_hud_slot_y", "0.45", true, false,
	"NV HUD: meter slot vertical position, as a fraction of the plate height.")
local cvarDebug = CreateClientConVar("fo_hud_debug", "0", true, false,
	"NV HUD: outline the plate and meter slot for alignment.")

--[[
	Data providers.

	Each returns `value, max`, or nil when the underlying system is not
	installed. The HUD skips any readout whose provider returns nil, so adding
	hunger later is a one-line change here rather than a HUD rewrite.
]]
ix.fallout.hud.providers = {
	health = function(client)
		return client:Health(), client:GetMaxHealth()
	end,

	-- Helix ships a stamina plugin using the same "stm" local var NutScript
	-- did, so this works as-is when that plugin is enabled.
	stamina = function(client)
		if (not ix.plugin.list["stamina"]) then return end

		return client:GetLocalVar("stm", 100), 100
	end,

	--[[
		Both return nil for a race that does not eat, which is what makes the
		rows disappear rather than sit at a permanent 100 - Phoenix gate the
		same readout on `nut.races:hasHunger`.
	]]
	hunger = function(client)
		local character = client:GetCharacter()

		if (not character or not ix.hunger or not ix.hunger.HasHunger(character)) then
			return
		end

		return character:GetHunger(), 100
	end,

	thirst = function(client)
		local character = client:GetCharacter()

		if (not character or not ix.hunger or not ix.hunger.HasHunger(character)) then
			return
		end

		return character:GetThirst(), 100
	end,

	--[[
		Radiation reads the character rather than a networked var: it is
		stored as character data, which Helix replicates to the owning client
		only, and the owning client is the one drawing this.
	]]
	radiation = function(client)
		local character = client:GetCharacter()

		if (not character or not character.GetRadiation) then return end

		return character:GetRadiation(), 100
	end
}

local function GetStat(name, client)
	local provider = ix.fallout.hud.providers[name]

	if (not provider) then return end

	local ok, value, max = pcall(provider, client)

	if (not ok or not value) then return end

	return value, max or 100
end

--[[
	Radiation gain popup. Driven by ix.fallout.hud.ShowRadiationGain so any
	future radiation system can trigger it without touching this file.
]]
local gainingRads = 0
local lastGainRads = 0
local radiationAlpha = 0

local radSoundsChecked, radSoundsExist = false, false

local function HasRadSounds()
	if (not radSoundsChecked) then
		radSoundsExist = file.Exists("sound/phoenix/fx/radiation/ui_pipboy_radiation_a_01.mp3", "GAME")
		radSoundsChecked = true
	end

	return radSoundsExist
end

function ix.fallout.hud.ShowRadiationGain(rads)
	gainingRads = math.Round(rads, 1)
	lastGainRads = CurTime() + 3
	radiationAlpha = 255

	if (not HasRadSounds()) then return end

	local band = rads < 5 and "a" or (rads < 10 and "b" or "c")

	surface.PlaySound(string.format(
		"phoenix/fx/radiation/ui_pipboy_radiation_%s_0%d.mp3", band, math.random(3)))
end

net.Receive("ixRadiation:Update", function()
	ix.fallout.hud.ShowRadiationGain(net.ReadFloat())
end)

local function UpdateRadiationAlpha()
	local ct = CurTime()

	if (ct < lastGainRads) then
		radiationAlpha = 255
	elseif (radiationAlpha > 0) then
		radiationAlpha = math.max(0, radiationAlpha - FrameTime() * 100)
	end

	return radiationAlpha
end

local function DrawRadiationCounter(x, y, size, align)
	if (radiationAlpha <= 0) then return end

	local color = Color(255, 0, 0, radiationAlpha)
	local rotation = (CurTime() * 25) % 360

	surface.SetMaterial(radiationCounter)
	surface.SetDrawColor(0, 0, 0, radiationAlpha)
	surface.DrawTexturedRectRotated(x + 1, y + 1, size, size, rotation)
	surface.SetDrawColor(color)
	surface.DrawTexturedRectRotated(x, y, size, size, rotation)

	draw.TextShadow({
		text = "+" .. gainingRads,
		font = "UI_Big",
		pos = {x, y - size * 0.6},
		color = color,
		xalign = align or TEXT_ALIGN_CENTER,
		yalign = TEXT_ALIGN_CENTER
	}, 1, radiationAlpha)

	draw.TextShadow({
		text = "RADS/SEC",
		font = "UI_RADS",
		pos = {x, y + size * 0.5},
		color = color,
		xalign = align or TEXT_ALIGN_CENTER,
		yalign = TEXT_ALIGN_CENTER
	}, 1, radiationAlpha)
end

--[[
	Compass.
]]
local compassLabels = {
	{ang = 0, text = "N", big = true},
	{ang = 45, text = "NE"},
	{ang = 90, text = "E", big = true},
	{ang = 135, text = "SE"},
	{ang = 180, text = "S", big = true},
	{ang = 225, text = "SW"},
	{ang = 270, text = "W", big = true},
	{ang = 315, text = "NW"}
}

-- Scratch colours, reused each frame. Phoenix allocates one per label per
-- frame through ColorAlpha, which is a lot of garbage for a permanent HUD.
local scratchLabel = Color(255, 255, 255, 255)
local scratchShadow = Color(0, 0, 0, 255)

local function GetCompassAlpha(x, left, right, fadeSize)
	if (x < left - fadeSize or x > right + fadeSize) then
		return 0
	end

	if (x < left) then
		return math.Clamp(255 * (1 - ((left - x) / fadeSize)), 0, 255)
	end

	if (x > right) then
		return math.Clamp(255 * (1 - ((x - right) / fadeSize)), 0, 255)
	end

	local edgeDist = math.min(x - left, right - x)

	return math.Clamp(255 * (edgeDist / fadeSize), 0, 255)
end

function ix.fallout.hud.DrawCompass()
	local client = LocalPlayer()

	if (not IsValid(client) or not client:Alive()) then return end

	local palette = ix.fallout.GetPalette()
	local primary = palette.color_primary

	local scrW, scrH = ScrW(), ScrH()
	local compassSize = scrW * 0.4
	local middle = scrW * 0.5
	local halfCompass = compassSize * 0.5
	local compassX = middle - halfCompass
	local compassY = scrH * 0.011
	local edgeLength = scrH * 0.01

	local leftBar = middle - halfCompass
	local rightBar = middle + halfCompass

	surface.SetMaterial(gradient)
	surface.SetDrawColor(primary.r, primary.g, primary.b, 50)
	surface.DrawTexturedRect(compassX, compassY + 2, compassSize, edgeLength * 0.8)

	surface.SetDrawColor(0, 0, 0, 255)
	draw.NoTexture()
	surface.DrawRect(compassX + 1, compassY + 1, compassSize, 2)
	surface.DrawRect(leftBar + 1, compassY + 1, 2, edgeLength)
	surface.DrawRect(rightBar + 1, compassY + 1, 2, edgeLength)

	surface.SetDrawColor(primary)
	surface.DrawRect(compassX, compassY, compassSize, 2)
	surface.DrawRect(leftBar, compassY, 2, edgeLength)
	surface.DrawRect(rightBar, compassY, 2, edgeLength)

	local rot = math.NormalizeAngle(client:EyeAngles().y)

	for i = 1, #compassLabels do
		local data = compassLabels[i]
		local diff = math.AngleDifference(data.ang, -rot)
		local labelX = middle + (diff / 90) * (scrW * 0.1)

		if (labelX < compassX or labelX > compassX + compassSize) then
			continue
		end

		local alpha = GetCompassAlpha(labelX, leftBar, rightBar, compassSize * 0.15)

		if (alpha <= 0) then continue end

		scratchLabel.r, scratchLabel.g, scratchLabel.b = primary.r, primary.g, primary.b
		scratchLabel.a = alpha
		scratchShadow.a = alpha

		local font = data.big and "UI_Bold" or "UI_Regular"
		local pos = compassY + (data.big and scrH * 0.015 or scrH * 0.01)
		local barSize = data.big and 4 or 2

		draw.TextShadow({
			text = data.text,
			font = font,
			pos = {labelX, pos},
			color = scratchLabel,
			xalign = TEXT_ALIGN_CENTER,
			yalign = TEXT_ALIGN_CENTER
		}, 1, alpha)

		surface.SetDrawColor(scratchShadow)
		surface.DrawRect(labelX + 1, compassY + 3, 2, barSize)

		surface.SetDrawColor(scratchLabel)
		surface.DrawRect(labelX, compassY + 2, 2, barSize)
	end

	draw.TextShadow({
		text = math.Round(-rot % 360),
		font = "UI_Small",
		pos = {middle, compassY - scrH * 0.005},
		color = primary,
		xalign = TEXT_ALIGN_CENTER,
		yalign = TEXT_ALIGN_CENTER
	}, 1, 255)
end

--[[
	New Vegas HUD.
]]
function ix.fallout.hud.DrawNewVegas()
	local client = LocalPlayer()

	if (not IsValid(client)) then return end

	local palette = ix.fallout.GetPalette()
	local color = palette.color_primary
	local darker = palette.color_dark

	local scrW, scrH = ScrW(), ScrH()
	local scale = 0.6
	local w, h = (scrW * 0.38) * scale, (scrH * 0.25) * scale
	local halfHeight = h * 0.5
	local xOffset, yOffset = scrW * 0.01, scrH * 0.925 - halfHeight

	surface.SetDrawColor(color)
	surface.SetMaterial(leftHud)
	surface.DrawTexturedRect(xOffset, yOffset, w, h)

	surface.SetMaterial(rightHud)
	surface.DrawTexturedRect(scrW - xOffset - w, yOffset - 1, w, h)

	local ticks = 43

	-- The slot, then the ticks derived from it. `step` is the pitch, and the
	-- last tick's right edge lands exactly on slotW - overflow is impossible
	-- regardless of resolution or rounding.
	local slotW = w * cvarSlotW:GetFloat()
	local step = slotW / ticks
	local tickWidth = math.max(step * 0.8, 1)
	local tickHeight = math.max(h * 0.15, 1)

	local leftSlotX = xOffset + (w * cvarSlotX:GetFloat())
	local rightSlotX = scrW - xOffset - (w * cvarSlotX:GetFloat()) - slotW
	local slotY = yOffset + (h * cvarSlotY:GetFloat()) - tickHeight

	surface.SetDrawColor(darker)
	surface.SetMaterial(hudTick)

	-- HP fills left to right.
	local health, maxHealth = GetStat("health", client)
	local filled = math.ceil(math.Clamp(health / math.max(maxHealth, 1), 0, 1) * ticks)

	for i = 0, filled - 1 do
		surface.DrawTexturedRect(leftSlotX + i * step, slotY, tickWidth, tickHeight)
	end

	-- AP fills right to left, mirroring the plate. Only drawn when a stamina
	-- system is actually installed.
	local stamina, maxStamina = GetStat("stamina", client)

	if (stamina) then
		local staminaFilled = math.ceil(math.Clamp(stamina / math.max(maxStamina, 1), 0, 1) * ticks)

		for i = 0, staminaFilled - 1 do
			surface.DrawTexturedRect(
				rightSlotX + slotW - tickWidth - (i * step), slotY, tickWidth, tickHeight)
		end
	end

	if (cvarDebug:GetBool()) then
		surface.SetDrawColor(255, 0, 0, 255)
		surface.DrawOutlinedRect(xOffset, yOffset, w, h)
		surface.DrawOutlinedRect(scrW - xOffset - w, yOffset, w, h)

		surface.SetDrawColor(0, 255, 255, 255)
		surface.DrawOutlinedRect(leftSlotX, slotY, slotW, tickHeight)
		surface.DrawOutlinedRect(rightSlotX, slotY, slotW, tickHeight)
	end

	-- Labels anchor to the slot, not to their own fractions of the plate, so
	-- they track the meters when the slot convars are tuned.
	draw.TextShadow({
		text = "HP",
		font = "UI_Big",
		pos = {leftSlotX, yOffset + (h * 0.05)},
		color = color
	}, 1, 255)

	if (stamina) then
		draw.TextShadow({
			text = "AP",
			font = "UI_Big",
			pos = {rightSlotX + slotW, yOffset + (h * 0.05)},
			color = color,
			xalign = TEXT_ALIGN_RIGHT
		}, 1, 255)
	end

	-- Ammo.
	local weapon = client:GetActiveWeapon()

	-- Deliberately does NOT consult CanDrawAmmoHUD: we return false from that
	-- hook ourselves to suppress Helix's ammo counter, so checking it here
	-- would gate our own readout on our own suppression.
	if (IsValid(weapon) and weapon.DrawAmmo ~= false) then
		local clip = weapon:Clip1()
		local count = client:GetAmmoCount(weapon:GetPrimaryAmmoType())

		if (clip >= 0) then
			draw.TextShadow({
				text = clip .. " | " .. count,
				font = "UI_Medium",
				pos = {rightSlotX + slotW, yOffset + (h * 0.7)},
				color = color,
				xalign = TEXT_ALIGN_RIGHT,
				yalign = TEXT_ALIGN_CENTER
			}, 1, 255)
		end
	end

	if (not client:GetCharacter()) then return end

	-- Condition readouts. Each is skipped entirely when unsupported, so the
	-- stack collapses rather than showing empty bars.
	local hunger = GetStat("hunger", client)
	local thirst = GetStat("thirst", client)
	local radiation = GetStat("radiation", client)

	if (hunger or thirst or radiation) then
		local iconSize = scrH * 0.025
		local iconHalf = iconSize * 0.5
		local iconStart = scrH * 0.765
		local iconX = scrW * 0.005 + iconSize
		local rotation = (CurTime() * 25) % 360

		local barLength = scrW * 0.05
		local barStart = iconX + iconSize
		local barOffset = iconSize * 0.25
		local barWidth = iconSize * 0.5

		--[[
			ROW INDEX IS FIXED, NOT A RUNNING COUNTER.

			Phoenix hard-code the three positions and always draw radiation at
			the third:

			    bar1x = iconStart + barOffset                    -- hunger
			    bar2x = iconStart + iconSize + barOffset         -- thirst
			    bar3x = iconStart + (iconSize * 2) + barOffset   -- radiation

			and only the first two are inside their `if hasHunger` check. So on
			a race without hunger the rad bar stays where it is and the space
			above it is simply empty.

			A counter that incremented per drawn row - which is what this used
			to be - collapses the stack, and with hunger and thirst not yet
			ported that put the radiation bar at the TOP of the group instead
			of the bottom. Same numbers, wrong place.
		]]
		local function DrawRow(icon, value, row, rotate)
			local y = iconStart + (row * iconSize)

			surface.SetDrawColor(color)
			surface.SetMaterial(icon)

			if (rotate) then
				surface.DrawTexturedRectRotated(iconX + iconHalf, y + iconHalf, iconSize, iconSize, rotation)
			else
				surface.DrawTexturedRect(iconX, y, iconSize, iconSize)
			end

			surface.SetDrawColor(palette.color_faint)
			draw.NoTexture()
			surface.DrawRect(barStart, y + barOffset, barLength, barWidth)

			surface.SetDrawColor(darker)
			surface.DrawRect(barStart, y + barOffset, barLength * math.Clamp(value / 100, 0, 1), barWidth)
		end

		if (hunger) then DrawRow(hungerIcon, hunger, 0) end
		if (thirst) then DrawRow(thirstIcon, thirst, 1) end
		if (radiation) then DrawRow(radiationIcon, radiation, 2, true) end
	end

	if (UpdateRadiationAlpha() > 0) then
		DrawRadiationCounter(
			xOffset + (w * 0.92),
			yOffset + (h * 0.225),
			scrW * 0.035,
			TEXT_ALIGN_RIGHT
		)
	end
end

--[[
	Fallout 4 HUD - flat labelled bars.
]]
local function DrawBar(x, y, w, h, pos, max, right, label, font, color, rightDrain, icon)
	max = math.max(max, 1)
	pos = math.Clamp(pos, 0, max)

	if (label) then
		surface.SetFont(font)
		surface.SetTextColor(0, 0, 0)

		if (not right) then
			surface.SetTextPos(x + 1, y - 5)
			surface.DrawText(label)
			surface.SetTextColor(color.r, color.g, color.b)
			surface.SetTextPos(x, y - 6)
			surface.DrawText(label)

			x = x + 50
		else
			surface.SetTextPos(x + w + 13, y - 5)
			surface.DrawText(label)
			surface.SetTextColor(color.r, color.g, color.b)
			surface.SetTextPos(x + w + 12, y - 6)
			surface.DrawText(label)

			x = x - 10
		end
	end

	if (icon) then
		surface.SetDrawColor(color.r, color.g, color.b)
		surface.SetMaterial(icon)
		surface.DrawTexturedRect(x - 25, y - 2, 20, 20)
	end

	local filled = math.max(((w - 2) / max) * pos, 0)

	surface.SetDrawColor(0, 0, 0, 150)
	draw.NoTexture()
	surface.DrawRect(x, y, w + 6, h)
	surface.SetDrawColor(0, 0, 0, 200)
	surface.DrawOutlinedRect(x, y, w + 6, h)

	surface.SetDrawColor(color.r, color.g, color.b)

	if (rightDrain) then
		surface.DrawRect((x + w) - filled + 4, y + 3, filled, h - 6)
	else
		surface.DrawRect(x + 3, y + 3, filled, h - 6)
	end
end

function ix.fallout.hud.DrawFallout4()
	local client = LocalPlayer()

	if (not IsValid(client) or not client:GetCharacter()) then return end

	local palette = ix.fallout.GetPalette()
	local color = palette.color_bright
	local scrW, scrH = ScrW(), ScrH()

	local mainLen = scrW * 0.1325
	local offset = scrW * 0.04
	local barY = scrH * 0.925

	local health, maxHealth = GetStat("health", client)

	DrawBar(32, barY, mainLen, 14, health, maxHealth, false, "HP", "UI_Medium", color)

	local stamina, maxStamina = GetStat("stamina", client)

	if (stamina) then
		DrawBar(scrW - mainLen - offset, barY, mainLen, 14, stamina, maxStamina,
			true, "AP", "UI_Medium", color, true)
	end

	local small = scrW * 0.05
	local row = 0

	local function DrawCondition(icon, value)
		DrawBar(scrW * 0.045, scrH * 0.9 - (row * 24), small, 14, value, 100,
			false, false, "UI_Regular", color, false, icon)

		row = row + 1
	end

	local hunger = GetStat("hunger", client)
	local thirst = GetStat("thirst", client)
	local radiation = GetStat("radiation", client)

	if (hunger) then DrawCondition(hungerIcon, hunger) end
	if (thirst) then DrawCondition(thirstIcon, thirst) end
	if (radiation) then DrawCondition(radiationIcon, radiation) end

	-- Ammo. Phoenix pinned this to fixed pixel offsets; screen-relative here so
	-- it stays put on any resolution.
	local weapon = client:GetActiveWeapon()

	-- Deliberately does NOT consult CanDrawAmmoHUD: we return false from that
	-- hook ourselves to suppress Helix's ammo counter, so checking it here
	-- would gate our own readout on our own suppression.
	if (IsValid(weapon) and weapon.DrawAmmo ~= false) then
		local clip = weapon:Clip1()
		local count = client:GetAmmoCount(weapon:GetPrimaryAmmoType())
		local secondary = client:GetAmmoCount(weapon:GetSecondaryAmmoType())

		local x = scrW - scrW * 0.027
		local y = scrH - scrH * 0.148

		if (secondary > 0) then
			draw.SimpleText(secondary, "UI_Medium", x - 29, y - 26, color_black, TEXT_ALIGN_CENTER)
			draw.SimpleText(secondary, "UI_Medium", x - 30, y - 27, color, TEXT_ALIGN_CENTER)
		elseif (clip >= 0) then
			draw.SimpleText(count, "UI_Medium", x - 29, y + 1, color_black, TEXT_ALIGN_CENTER)
			draw.SimpleText(count, "UI_Medium", x - 30, y, color, TEXT_ALIGN_CENTER)

			surface.SetDrawColor(color_black)
			surface.DrawRect(x - 65, y - 13, 70, 6)
			surface.SetDrawColor(color)
			surface.DrawRect(x - 66, y - 14, 70, 6)

			y = y - scrH * 0.044

			draw.SimpleText(clip, "UI_Medium", x - 29, y + 1, color_black, TEXT_ALIGN_CENTER)
			draw.SimpleText(clip, "UI_Medium", x - 30, y, color, TEXT_ALIGN_CENTER)
		end
	end

	if (UpdateRadiationAlpha() > 0) then
		DrawRadiationCounter(scrW * 0.2, scrH * 0.92, scrW * 0.035)
	end
end

--[[
	Entry point.
]]
--[[
	Radiation grain.

	Phoenix draw this from the radiation plugin rather than the HUD, on a
	plain `HUDPaint`, so it is independent of which HUD style is selected and
	shows even with the HUD turned off. Kept that way: the grain is feedback
	about your body, not part of the interface.

	`35 * (radiation / 100)` is their alpha curve exactly - barely visible at
	low exposure, and still only 35/255 at a lethal dose.
]]
local radNoise = Material("phoenix/overhaul/noiseadd")

function ix.fallout.hud.DrawRadiationGrain(client)
	local character = client:GetCharacter()

	if (not character or not character.GetRadiation) then return end

	local radiation = character:GetRadiation()

	if (radiation <= 0) then return end

	surface.SetMaterial(radNoise)
	surface.SetDrawColor(255, 255, 255, 35 * (radiation / 100))
	surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
end

--[[
	ACTIVE MODIFIERS, TOP LEFT.

	Phoenix draw this from their `buffs` plugin, not from the HUD:

	    local x, y = 10, 10
	    draw.TextShadow({ text = buff.type .. (buff.value > 0 and " +" or " ")
	        .. buff.value, font = "UI_Regular", ... })
	    y = y + 20

	Same position, same font, same spacing, same `TYPE +N` / `TYPE -N` format,
	and the same rule that a modifier of zero is not drawn at all.

	WHAT FEEDS IT IS DIFFERENT. Theirs is a real buff system - chems and
	faction buffs pushed over the network into an `ACTIVEBUFFS` table. That
	does not exist here, so instead of shipping an empty display this reads the
	modifiers that ARE real: armour bonuses and radiation sickness. A buff
	system later adds itself to `buffSources` rather than replacing this.

	Short codes rather than our lowercase keys, because this is the one place
	the display is meant to match theirs exactly. It is presentation only - the
	unified naming still governs everything that reads or writes a value.
]]
local SPECIAL_CODES = {
	strength = "STR",
	perception = "PER",
	endurance = "END",
	charisma = "CHR",
	intelligence = "INT",
	agility = "AGL",
	luck = "LCK"
}

--[[
	Each source appends `{type = "STR", value = 2}` entries.

	A future buff plugin registers here; nothing about the drawing needs to
	know where a modifier came from.
]]
ix.fallout.hud.buffSources = {
	--[[
		SPECIAL, netted per attribute.

		Armour bonuses and radiation penalties are summed together rather than
		listed separately, so +1 Endurance of armour against -1 of sickness
		reads as nothing at all - which is the truth, and is what Phoenix's
		`value == 0` skip does for stacked buffs.
	]]
	function(client, character, out)
		local totals = {}

		if (ix.armor) then
			for key, value in pairs(ix.armor.GetSpecialBonus(character)) do
				totals[key] = (totals[key] or 0) + value
			end
		end

		if (ix.radiation and character.GetRadiation) then
			local tier = ix.radiation.GetTier(character:GetRadiation())

			for key, value in pairs(tier.special or {}) do
				totals[key] = (totals[key] or 0) + value
			end
		end

		-- Walked in SPECIAL order so the list never reshuffles between frames.
		for _, key in ipairs(ix.special and ix.special.order or {}) do
			if (totals[key] and totals[key] ~= 0) then
				out[#out + 1] = {type = SPECIAL_CODES[key] or key, value = totals[key]}
			end
		end
	end,

	--[[
		Movement. `SPD` and `JMP` are two of their own buff types, and heavy
		armour is the main thing that moves them - usually downwards, which is
		worth being able to see.
	]]
	function(client, character, out)
		if (not ix.armor) then return end

		local speed = ix.armor.GetSpeedBoost(character)
		local jump = ix.armor.GetJumpBoost(character)

		if (speed ~= 0) then out[#out + 1] = {type = "SPD", value = speed} end
		if (jump ~= 0) then out[#out + 1] = {type = "JMP", value = jump} end
	end
}

--[[
	Cached, because the SPECIAL source walks the whole inventory and this is
	drawn every frame. Four times a second is far quicker than equipment can
	actually change - and quick enough for a chem's countdown, which only ever
	shows whole seconds.
]]
local buffCache, nextBuffCache = {}, 0

function ix.fallout.hud.GetActiveBuffs(client)
	if (CurTime() < nextBuffCache) then return buffCache end

	nextBuffCache = CurTime() + 0.25

	local character = client:GetCharacter()
	local out = {}

	if (character) then
		for _, source in ipairs(ix.fallout.hud.buffSources) do
			-- pcall: a badly behaved source must not take the whole HUD down.
			pcall(source, client, character, out)
		end
	end

	buffCache = out

	return out
end

--[[
	Two fields were added to a modifier when chems arrived: `suffix` and `bad`.

	`suffix` is the note after the number - a chem's remaining seconds, or what
	a withdrawal penalty is from. `bad` draws it red. Neither is required, so
	the two sources that predate chems are untouched: armour and radiation
	still append `{type, value}` and still draw exactly as they did.

	Red for a penalty matters more here than it did before. Armour's are all
	trade-offs you chose and can see on the item; a withdrawal penalty is
	something happening TO you, and it reading the same as a bonus is the
	difference between noticing it and not.
]]
function ix.fallout.hud.DrawBuffs(client)
	local x, y = 10, 10
	local palette = ix.fallout.GetPalette()

	for _, buff in ipairs(ix.fallout.hud.GetActiveBuffs(client)) do
		local text = buff.type .. (buff.value > 0 and " +" or " ") .. buff.value

		draw.TextShadow({
			text = text,
			font = "UI_Regular",
			pos = {x, y},
			color = buff.bad and palette.text_red or palette.color_primary
		}, 1, 255)

		if (buff.suffix) then
			--[[
				MEASURED, not offset by a guess.

				This was drawn at a fixed `x + 74`, which is fine for "SPD +30"
				and runs straight through "STEALTH +1" - the suffix landed on
				top of the value and neither could be read. The only number
				that cannot be wrong is the width of the text actually drawn.
			]]
			surface.SetFont("UI_Regular")

			local width = surface.GetTextSize(text)

			draw.TextShadow({
				text = buff.suffix,
				font = "UI_Small",
				pos = {x + width + 10, y + 5},
				--[[
					`text_disabled` is the palette's dark brown, which is
					legible against a menu background and not against the
					world. Dimmed primary keeps it subordinate to the value
					while staying readable over anything.
				]]
				color = ColorAlpha(palette.color_primary, 190)
			}, 1, 255)
		end

		y = y + 21
	end

	--[[
		Addictions below the modifiers, in their own block.

		They are not modifiers - an addiction at severity 0 is costing nothing
		and still needs saying, because it is about to. `{type, value}` cannot
		express that, which is why this is drawn here rather than pushed
		through `buffSources`.
	]]
	if (not ix.addiction or not ix.addiction.GetLocal) then return end

	local list = ix.addiction.GetLocal()

	if (#list == 0) then return end

	y = y + 4

	for _, addiction in ipairs(list) do
		draw.TextShadow({
			text = addiction.text,
			font = "UI_Small",
			pos = {x, y},
			color = addiction.severity > 0
				and palette.text_red or ColorAlpha(palette.color_primary, 190)
		}, 1, 255)

		y = y + 17
	end
end

function Schema:HUDPaint()
	local client = LocalPlayer()

	if (not IsValid(client) or not client:GetCharacter()) then return end
	if (not client:Alive() or client.DisableHud) then return end

	ix.fallout.hud.DrawRadiationGrain(client)

	--[[
		Drawn outside the HUD-style branch, like the grain. Phoenix's is a
		separate plugin and shows whichever HUD you have chosen, including
		none - these are facts about your body rather than interface furniture.
	]]
	ix.fallout.hud.DrawBuffs(client)

	local hudType = ix.option.Get("falloutHud", "nv")

	if (hudType == "nv") then
		ix.fallout.hud.DrawNewVegas()
	elseif (hudType == "f4") then
		ix.fallout.hud.DrawFallout4()
	end

	if (hudType ~= "none" and ix.option.Get("falloutCompass", true)) then
		ix.fallout.hud.DrawCompass()
	end
end

-- Suppress Helix's own bars and ammo counter - ours replace them. Both hooks
-- exist in Helix under the same names NutScript used.
hook.Add("ShouldHideBars", "ixFalloutHud", function()
	return ix.option.Get("falloutHud", "nv") ~= "none"
end)

hook.Add("CanDrawAmmoHUD", "ixFalloutHud", function()
	if (ix.option.Get("falloutHud", "nv") == "none") then return end

	return false
end)

--[[
	Load marker. If the trace file stops before this line, THIS file threw
	partway through - which leaves everything above the throw in place and
	every patch below it silently unregistered.
]]
ix.fallout.CreateTrace("load: cl_hud.lua")
