--[[
	The capture bar, along the bottom of the screen.

	One message drives it and one message ends it: a length of zero means stop,
	so there is no second netstring and no way to be left showing a bar for a
	capture that has already finished. See `sv_benchcapture.lua`.

	IT INTERPOLATES FROM THE FINISH TIME rather than being told how full it is.
	The server sends the moment it ends, once, and every frame after that is
	arithmetic here - so the bar moves smoothly at any framerate and a dropped
	packet cannot leave it stuck halfway.

	IT DRAWS ITSELF OUT OF EXISTENCE. `finish` passing is the end of it, with
	no message required, because the server has to end the capture anyway and a
	bar that outlived its capture by a frame is worse than one that stops a
	frame early.
]]

if (not CLIENT) then return end

ix.bench = ix.bench or {}

--- What is being taken, how long it takes, and when it ends. Nil for none.
local capture

net.Receive("ixBenchCapture", function()
	local name = net.ReadString()
	local length = net.ReadUInt(16)
	local finish = net.ReadFloat()

	if (length < 1) then
		capture = nil

		return
	end

	capture = {name = name, length = length, finish = finish}
end)

--- Whether a capture is running, for anything else that wants to know.
function ix.bench.IsCapturing()
	return capture ~= nil
end

hook.Add("HUDPaint", "ixBenchCapture", function()
	if (not capture) then return end

	local remaining = capture.finish - CurTime()

	if (remaining <= 0) then
		--[[
			Left up at full for a moment rather than vanishing on the exact
			tick. The server's completion lands a fraction later and the bar
			blinking out just before the notification arrives reads as a
			failure rather than a success.
		]]
		if (remaining < -1) then capture = nil end

		remaining = 0
	end

	local scale = ix.fallout and ix.fallout.GetFontScale
		and ix.fallout.GetFontScale() or 1
	local width = math.Round(math.min(ScrW() * 0.35, 520 * scale))
	local height = math.Round(28 * scale)
	local x = (ScrW() - width) * 0.5
	local y = ScrH() - height - math.Round(90 * scale)

	local fraction = math.Clamp(1 - remaining / capture.length, 0, 1)
	local palette = ix.fallout and ix.fallout.GetPalette
		and ix.fallout.GetPalette() or nil
	local colour = palette and palette.color_primary or Color(255, 200, 100)
	local text = palette and palette.text_primary or color_white

	surface.SetDrawColor(15, 15, 18, 230)
	surface.DrawRect(x, y, width, height)

	surface.SetDrawColor(ColorAlpha(colour, 130))
	surface.DrawRect(x, y, width * fraction, height)

	surface.SetDrawColor(colour)
	surface.DrawOutlinedRect(x, y, width, height, 1)

	draw.SimpleText(string.format("TAKING %s - %s",
		string.upper(capture.name),
		ix.bench.FormatTime and ix.bench.FormatTime(remaining)
			or math.ceil(remaining) .. "s"),
		"ixLootRow", x + width * 0.5, y + height * 0.5, text,
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	--[[
		Said under the bar, every second of it. Somebody who started this by
		pressing a key twice should not be able to forget what it does before
		it finishes.
	]]
	draw.SimpleText("Stay close. Whoever holds it knows you are here.",
		"ixLootSmall", x + width * 0.5, y + height + math.Round(4 * scale),
		ColorAlpha(text, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
end)
