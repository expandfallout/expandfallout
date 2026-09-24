--[[
	Ambushes, client side: the question, the gunfire and the countdown.

	See `sh_ambush.lua` for what an ambush is.
]]

ix.ambush = ix.ambush or {}

if (not CLIENT) then return end

--[[
	Distant gunfire, for everybody.

	Ten bursts spread over twelve seconds, from behind and above rather than
	from a point - `city_battle` is a stereo ambient and playing it at the
	listener's own position makes it sound like it is in the room. Phoenix
	offset it by 500 units on every axis, which is far enough to read as "over
	there" without being far enough to be quiet.
]]
local function Gunfire()
	local client = LocalPlayer()

	if (not IsValid(client)) then return end

	local origin = client:GetPos() + Vector(500, 500, 500)

	for index = 10, 1, -1 do
		timer.Simple(index * 1.2, function()
			if (not IsValid(client)) then return end

			sound.Play(string.format(
				"ambient/levels/streetwar/city_battle%d.wav", math.random(10)),
				origin, 85, 100, 1)
		end)
	end
end

net.Receive("ixAmbushNotice", function()
	local index = net.ReadUInt(4)

	Gunfire()

	chat.AddText(ix.ambush.colour,
		ix.ambush.notices[index] or ix.ambush.notices[1])
end)

--[[
	THE STATE, whole, every time it changes.

	`ix.ambush.active` holds the same shape here as on the server minus the
	caller - the HUD reads it directly, so there is one table rather than a
	separate copy for drawing.
]]
net.Receive("ixAmbushState", function()
	local count = net.ReadUInt(8)
	local active = {}

	for index = 1, count do
		local faction = net.ReadUInt(8)

		active[faction] = {endTime = net.ReadFloat()}
	end

	local mine = LocalPlayer():GetCharacter()
	local faction = mine and mine:GetFaction()

	--[[
		BATTLE MUSIC WHEN YOUR OWN FACTION'S AMBUSH BEGINS, not when anybody's
		does. Phoenix play a VATS sting here; that file is not in the packs
		this server mounts, and their raids use the rural battle cue for the
		same moment - so this uses that, which is present and is the sound the
		rest of the fighting systems will use.
	]]
	if (faction and active[faction] and not ix.ambush.active[faction]) then
		surface.PlaySound(string.format(
			"phoenix/amb/mus_bttl_in_rural_%02d.mp3", math.random(4)))
	end

	ix.ambush.active = active
end)

--[[
	The confirmation.

	`Derma_Query` is what every other confirm in this schema uses and the skin
	restyles it, so it looks like the rest of the UI without a panel of its
	own. Its buttons are TEXT-then-FUNCTION pairs - see `cl_benchconfig.lua`,
	where getting that wrong once cost an afternoon.
]]
net.Receive("ixAmbushAsk", function()
	local bEnd = net.ReadBool()
	local seconds = net.ReadUInt(16)

	local text = bEnd
		and string.format("End your faction's ambush early?\n\n%d seconds "
			.. "are left. Everybody in your faction stops fighting.", seconds)
		or string.format("Call an ambush for your faction?\n\nIt lasts %d "
			.. "seconds, the wasteland will hear it, and your faction cannot "
			.. "call another until the cooldown is up.", seconds)

	Derma_Query(text, bEnd and "End the ambush?" or "Call an ambush?",
		bEnd and "END IT" or "AMBUSH", function()
			net.Start("ixAmbushAnswer")
				net.WriteBool(bEnd)
			net.SendToServer()
		end,
		"CANCEL", function() end)
end)

--[[
	The countdown, for the faction that called it.

	Drawn rather than networked as text so it counts down smoothly without a
	message a second, which is what `endTime` is for.
]]
hook.Add("HUDPaint", "ixAmbush", function()
	local client = LocalPlayer()

	if (not IsValid(client) or not client:Alive() or client.DisableHud) then
		return
	end

	local character = client:GetCharacter()

	if (not character) then return end

	local faction = character:GetFaction()
	local entry = ix.ambush.active[faction]

	if (not entry) then return end

	local left = math.ceil(entry.endTime - CurTime())

	if (left <= 0) then return end

	local palette = ix.fallout.GetPalette()
	local x = ScrW() * 0.5

	draw.SimpleTextOutlined("AMBUSH ACTIVE", "UI_Bold", x, ScrH() * 0.125,
		palette.color_primary, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1,
		color_black)

	draw.SimpleTextOutlined(string.format("for %d more seconds", left),
		"UI_Medium", x, ScrH() * 0.15, palette.text_primary,
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
end)
