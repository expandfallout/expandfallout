--[[
	The death screen.

	Drawn rather than built as a panel, for the same reason the buff list is:
	it is a short list that changes rarely and has to sit over a view the
	player cannot interact with anyway. A panel would need `MakePopup`, which
	takes the mouse away from a dead player and gives it back at a moment
	nothing here controls.

	So it takes keyboard input instead - number keys pick a location, and that
	is both simpler to use while looking at your own ragdoll and impossible to
	misclick.
]]

if (not CLIENT) then return end

local choices = {}
local shown = 0

local function Scaled(value)
	return math.Round(value * ix.fallout.GetFontScale())
end

net.Receive("ixSpawnChoices", function()
	local count = net.ReadUInt(8)

	choices = {}

	for index = 1, count do
		choices[index] = net.ReadString()
	end

	shown = RealTime()
end)

--[[
	Cleared on respawn.

	`PlayerSpawn` would be the obvious hook and does not fire on the client for
	the local player in a way that can be relied on; watching `Alive` is the
	honest test, and it costs one call a frame while a menu is up.
]]
local function Clear()
	choices = {}
end

hook.Add("HUDPaint", "ixDeathScreen", function()
	if (#choices == 0) then return end

	local client = LocalPlayer()

	if (not IsValid(client)) then return end

	if (client:Alive()) then
		Clear()
		return
	end

	local palette = ix.fallout.GetPalette()
	local width, height = ScrW(), ScrH()

	--[[
		A dim over the whole screen rather than a panel with a background. The
		player is looking at their own body; the point is to make the list
		readable without hiding what happened.
	]]
	surface.SetDrawColor(0, 0, 0, 190)
	surface.DrawRect(0, 0, width, height)

	local y = height * 0.32

	draw.SimpleText("YOU DIED", "UI_Huge", width * 0.5, y,
		palette.text_red, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	y = y + Scaled(60)

	draw.SimpleText("Choose where to return.", "UI_Regular", width * 0.5, y,
		palette.color_primary, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	y = y + Scaled(38)

	for index, name in ipairs(choices) do
		--[[
			Numbered from one and pressed on the number row. Ten is the most
			that can be offered this way, which is far more locations than a
			faction should have.
		]]
		draw.SimpleText(string.format("%d.  %s", index, name), "UI_Bold",
			width * 0.5, y, palette.color_primary,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		y = y + Scaled(30)
	end

	draw.SimpleText("Press the number of a location.", "UI_Small",
		width * 0.5, y + Scaled(12), palette.text_disabled,
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

--[[
	`PlayerButtonDown` rather than a panel's key handler.

	There is no panel, and the player has no cursor. This fires for any key
	while the game has focus, which is exactly the input a dead player still
	has.
]]
hook.Add("PlayerButtonDown", "ixDeathScreen", function(client, button)
	if (#choices == 0 or client ~= LocalPlayer()) then return end
	if (client:Alive()) then return end

	--[[
		Both key rows, because a player whose hand is on the numpad should not
		have to move it. `KEY_1` through `KEY_0` are contiguous, so the index
		is the offset - and `KEY_0` is deliberately not mapped, since a tenth
		option is one more than a faction should ever need.
	]]
	local index

	if (button >= KEY_1 and button <= KEY_9) then
		index = button - KEY_1 + 1
	elseif (button >= KEY_PAD_1 and button <= KEY_PAD_9) then
		index = button - KEY_PAD_1 + 1
	end

	if (not index or not choices[index]) then return end

	net.Start("ixSpawnPick")
		net.WriteUInt(index, 8)
	net.SendToServer()

	Clear()
end)

hook.Add("CharacterLoaded", "ixDeathScreen", Clear)
