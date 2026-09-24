--[[
	Levelling - the popups.

	Ported to match Phoenix's `derma/cl_getxp.lua` and `cl_getlevel.lua`
	exactly, because this is the part players actually see:

	    256 x 64 panel, no background
	    x = 64, y = ScrH() / 2 - 64   (XP)  /  - 100  (level up)
	    UI_Medium, palette primary, 1px expensive shadow
	    fade in over 2s, then out over 2s after a 4s hold
	    sounds phoenix/ui/76/ui_experience_up.mp3 and ui_leveluptext.mp3
	           played through CreateSound at 0.6 volume

	Their XP panel ACCUMULATES rather than stacking: a second award while one
	is on screen adds to the number already showing instead of opening a
	second panel. That is why it is held in a single reference rather than
	created per message, and it is the detail that keeps a firefight from
	filling the screen with little labels.

	ONE DELIBERATE DIFFERENCE. Theirs queues the fade-out once, when the panel
	opens, so it disappears four seconds after the FIRST award no matter how
	much lands afterwards - a long fight ends with the counter fading while it
	is still climbing. Here every award restarts the hold, so the number stays
	up until the XP stops and then goes. That is what the panel looks like it
	is promising, and Phoenix's own `increaseXP` looks like it was meant to.
]]

if (not CLIENT) then return end

local XP_SOUND = "phoenix/ui/76/ui_experience_up.mp3"
local LEVEL_SOUND = "phoenix/ui/76/ui_leveluptext.mp3"

--[[
	Phoenix's timings: two seconds in, four seconds held, two seconds out.
	`FADE_RECOVER` is ours and has no equivalent there, because nothing there
	ever restarts the hold.
]]
local FADE_IN = 2
local FADE_RECOVER = 0.15
local FADE_OUT = 2
local HOLD = 4

--[[
	The one live XP panel, if any.

	Phoenix hold this in the global `NUTXPPANEL`; it is a local here, which is
	the same thing without adding a global.
]]
local xpPanel

local PANEL = {}

function PANEL:Init()
	self:SetSize(256, 64)
	self:DockPadding(6, 0, 0, 0)
	self:SetPos(64, (ScrH() / 2) - 64)
	self:SetPaintBackground(false)

	self.xp = 0
end

function PANEL:Open(xp, bMute)
	self.xp = xp or 0

	self.label = self:Add("DLabel")
	self.label:Dock(FILL)
	self.label:SetText("+" .. self.xp)
	self.label:SetTextColor(ix.fallout.GetPalette().color_primary)
	self.label:SetFont("UI_Medium")
	self.label:SetExpensiveShadow(1, color_black)

	if (not bMute) then
		--[[
			`CreateSound` on the world rather than `surface.PlaySound`, as
			theirs does, so the sound can be stopped and restarted when a
			second award lands while the first is still ringing.
		]]
		self.sound = CreateSound(game.GetWorld(), XP_SOUND)

		if (self.sound) then
			self.sound:SetSoundLevel(0)
			self.sound:PlayEx(0.6, 100)
		end
	end

	self:SetAlpha(0)
	self:Hold(FADE_IN)
end

--[[
	Queue the wait and the fade-out, replacing any already queued.

	`Stop` clears the animation queue, which is the only way to cancel a fade
	that has not started yet - `AlphaTo` with a delay is a queued animation,
	not a timer, so there is nothing else to cancel. The alpha is then brought
	back up rather than assumed: an award landing mid-fade finds the panel
	part-way transparent, and starting the hold without restoring it would
	leave the number sitting at whatever opacity it had reached.

	`fadeIn` is how long that takes. The first award passes Phoenix's two
	seconds; every later one uses a fraction of a second, because the panel is
	already visible and a second slow fade-in would read as a flicker.

	Note that `Open` MUST go through here rather than queueing its own fade and
	then calling this - the `Stop` would cancel the fade it had just queued.
]]
function PANEL:Hold(fadeIn)
	self:Stop()
	self:AlphaTo(255, fadeIn or FADE_RECOVER)
	self:AlphaTo(0, FADE_OUT, HOLD, function()
		self:Remove()
	end)
end

--- A second award while this one is still up adds to it rather than stacking.
function PANEL:IncreaseXP(xp)
	self.xp = self.xp + (xp or 0)

	if (IsValid(self.label)) then
		self.label:SetText("+" .. self.xp)
	end

	self:Hold()
end

function PANEL:OnRemove()
	if (self.sound) then
		self.sound:Stop()
	end
end

vgui.Register("ixFOGetXP", PANEL, "DPanel")

local LEVEL = {}

function LEVEL:Init()
	self:SetSize(256, 64)
	self:DockPadding(6, 0, 0, 0)
	self:SetPos(64, (ScrH() / 2) - 100)
	self:SetPaintBackground(false)
end

function LEVEL:Open(level, points)
	local label = self:Add("DLabel")

	label:Dock(FILL)
	label:SetText("Level up!")
	label:SetTextColor(ix.fallout.GetPalette().color_primary)
	label:SetFont("UI_Medium")
	label:SetExpensiveShadow(1, color_black)

	--[[
		The level reached and the points awarded are added underneath, which
		Phoenix's panel does not show. Their version says only "Level up!" and
		leaves the player to open a menu to find out what they got - and since
		points are the entire reward, that is worth one line.
	]]
	if (level) then
		self.subtitle = string.format("Level %d%s", level,
			(points and points > 0) and string.format("   +%d SPECIAL", points) or "")
	end

	self.sound = CreateSound(game.GetWorld(), LEVEL_SOUND)

	if (self.sound) then
		self.sound:SetSoundLevel(0)
		self.sound:PlayEx(0.6, 100)
	end

	self:SetAlpha(0)
	self:AlphaTo(255, 2)
	self:AlphaTo(0, 2, 4, function()
		self:Remove()
	end)
end

function LEVEL:PaintOver(width, height)
	if (not self.subtitle) then return end

	draw.SimpleText(self.subtitle, "UI_Small", 6, height - 8,
		ix.fallout.GetPalette().color_active, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
end

function LEVEL:OnRemove()
	if (self.sound) then
		self.sound:Stop()
	end
end

vgui.Register("ixFOLevelUp", LEVEL, "DPanel")

net.Receive("ixLevelingXP", function()
	local xp = net.ReadInt(32)
	local bMute = net.ReadBool()

	if (IsValid(xpPanel)) then
		xpPanel:IncreaseXP(xp)
		return
	end

	xpPanel = vgui.Create("ixFOGetXP")

	if (IsValid(xpPanel)) then
		xpPanel:Open(xp, bMute)
	end
end)

net.Receive("ixLevelingLevelUp", function()
	local level = net.ReadUInt(16)
	local points = net.ReadUInt(16)

	local panel = vgui.Create("ixFOLevelUp")

	if (IsValid(panel)) then
		panel:Open(level, points)
	end
end)
