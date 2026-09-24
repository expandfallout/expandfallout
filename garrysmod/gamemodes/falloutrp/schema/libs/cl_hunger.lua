--[[
	Being drunk, on screen.

	Ported from their `thirsthunger/cl_plugin.lua` - motion blur, a sharpen
	pass and a tilt-shift, for ninety seconds:

	    DrawMotionBlur(0.4, 0.8, 0.01)
	    DrawSharpen(1.2, 1.2)
	    DrawToyTown(2, ScrH() / 2)

	Their death check is kept and is cleverer than it looks: rather than
	hooking death, it records `Deaths()` when the effect starts and clears the
	effect the moment that number changes. That survives a disconnect, a
	character switch and a respawn without listening for any of them.
]]

if (not CLIENT) then return end

local EFFECT = "ixAlcoholEffect"
local DURATION = 90

net.Receive("ixAlcoholEffect", function()
	local client = LocalPlayer()

	if (not IsValid(client)) then return end

	local deaths = client:Deaths()

	hook.Add("RenderScreenspaceEffects", EFFECT, function()
		local current = LocalPlayer()

		if (not IsValid(current) or current:Deaths() ~= deaths) then
			hook.Remove("RenderScreenspaceEffects", EFFECT)
			return
		end

		DrawMotionBlur(0.4, 0.8, 0.01)
		DrawSharpen(1.2, 1.2)
		DrawToyTown(2, ScrH() / 2)
	end)

	--[[
		A named timer, so a second drink extends the haze rather than starting
		a second one that clears the first early.
	]]
	timer.Create(EFFECT, DURATION, 1, function()
		hook.Remove("RenderScreenspaceEffects", EFFECT)
	end)
end)
