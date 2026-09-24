--[[
	What chems and withdrawal look like.

	Two sources, one renderer. Withdrawal effects come from the addiction's
	severity; a chem's effects come from the item and last as long as its
	buffs do. Both end up in the same table and the same
	`RenderScreenspaceEffects` pass, so two things happening at once compose
	instead of fighting.

	PHOENIX'S EFFECTS, THEIR SETTINGS. Their `drugs_simple/cl_plugin.lua` is
	the source for the four they use and the numbers they use them at:

	    DrawSobel(0.5)
	    DrawSharpen(0.8, 0.8)
	    DrawMotionBlur(0.4, 0.8, 0.01)
	    DrawToyTown(2, ScrH() / 2)

	The rest here are new. Their whole roster only ever reaches for Sobel and
	Blur, at severity 2 and 3 of Jet, and a wasteland full of different drugs
	that all look the same going down is a missed opportunity.

	WHY EFFECTS ARE DECLARED PER ADDICTION AND PER CHEM RATHER THAN BY
	SEVERITY ALONE. Withdrawal from Cateye should hurt your eyes and withdrawal
	from Psycho should not - "everything at severity 2 desaturates" is one
	rule and one look. The default IS by severity, so an addiction that says
	nothing still behaves like theirs.
]]

if (not CLIENT) then return end

ix.chemfx = ix.chemfx or {}

--[[
	Effects currently running, as `[name] = {source = source}`.

	Keyed by source so two things asking for the same effect do not cancel each
	other when one of them stops - Jet withdrawal and Psycho withdrawal both
	desaturating is one Sobel, and it lasts until both have gone.
]]
ix.chemfx.active = ix.chemfx.active or {}

--[[
	The renderers.

	Each takes the strength of the strongest request. Phoenix's numbers where
	they had one; picked to be noticeable without being unplayable where they
	did not - these run for minutes at a time, and an effect you cannot see
	past is one players will simply not take the chem for.
]]
ix.chemfx.renderers = {
	--- Desaturated and edge-traced. Phoenix use this for Jet withdrawal.
	sobel = function() DrawSobel(0.5) end,

	--- Smeared motion. Their severity 3.
	blur = function() DrawMotionBlur(0.4, 0.8, 0.01) end,

	--- Over-sharp, everything too crisp. Reads as being wired.
	sharpen = function() DrawSharpen(0.8, 0.8) end,

	--- Tilt-shift. The world stops looking real.
	toytown = function() DrawToyTown(2, ScrH() / 2) end,

	--[[
		Washed out and grey. For withdrawal that is more misery than damage -
		Day Tripper, Daddy-O - where the world going flat says it better than
		an edge filter.
	]]
	grey = function()
		DrawColorModify({
			["$pp_colour_addr"] = 0,
			["$pp_colour_addg"] = 0,
			["$pp_colour_addb"] = 0,
			["$pp_colour_brightness"] = -0.02,
			["$pp_colour_contrast"] = 0.9,
			["$pp_colour_colour"] = 0.25,
			["$pp_colour_mulr"] = 0,
			["$pp_colour_mulg"] = 0,
			["$pp_colour_mulb"] = 0
		})
	end,

	--- Blown out and hot. Psycho and the combat chems.
	rage = function()
		DrawColorModify({
			["$pp_colour_addr"] = 0.06,
			["$pp_colour_addg"] = 0,
			["$pp_colour_addb"] = 0,
			["$pp_colour_brightness"] = 0.01,
			["$pp_colour_contrast"] = 1.25,
			["$pp_colour_colour"] = 1.4,
			["$pp_colour_mulr"] = 0.08,
			["$pp_colour_mulg"] = 0,
			["$pp_colour_mulb"] = 0
		})
	end,

	--- Cold and over-bright. Mentats: everything is very clear.
	clarity = function()
		DrawColorModify({
			["$pp_colour_addr"] = 0,
			["$pp_colour_addg"] = 0.01,
			["$pp_colour_addb"] = 0.04,
			["$pp_colour_brightness"] = 0.03,
			["$pp_colour_contrast"] = 1.15,
			["$pp_colour_colour"] = 0.8,
			["$pp_colour_mulr"] = 0,
			["$pp_colour_mulg"] = 0,
			["$pp_colour_mulb"] = 0.05
		})
	end,

	--- Green and lifted. Cateye, and the dark stops being dark.
	nightvision = function()
		DrawColorModify({
			["$pp_colour_addr"] = 0,
			["$pp_colour_addg"] = 0.09,
			["$pp_colour_addb"] = 0,
			["$pp_colour_brightness"] = 0.14,
			["$pp_colour_contrast"] = 0.85,
			["$pp_colour_colour"] = 0.35,
			["$pp_colour_mulr"] = 0,
			["$pp_colour_mulg"] = 0.1,
			["$pp_colour_mulb"] = 0
		})
	end,

	--- Warm and soft-edged. Day Tripper, Party Time Mentats: everything is fine.
	euphoria = function()
		DrawColorModify({
			["$pp_colour_addr"] = 0.05,
			["$pp_colour_addg"] = 0.03,
			["$pp_colour_addb"] = 0,
			["$pp_colour_brightness"] = 0.05,
			["$pp_colour_contrast"] = 0.85,
			["$pp_colour_colour"] = 1.5,
			["$pp_colour_mulr"] = 0.04,
			["$pp_colour_mulg"] = 0.02,
			["$pp_colour_mulb"] = 0
		})
	end,

	--[[
		Sick green, pulsing. Radiation chems and the home-brewed ones.

		The only animated renderer. Slow enough not to be a strobe - a
		half-hertz sine, which is a swell rather than a flash.
	]]
	nausea = function()
		local pulse = 0.5 + math.sin(RealTime() * 3) * 0.5

		DrawColorModify({
			["$pp_colour_addr"] = 0,
			["$pp_colour_addg"] = 0.03 + pulse * 0.03,
			["$pp_colour_addb"] = 0,
			["$pp_colour_brightness"] = -0.01,
			["$pp_colour_contrast"] = 1 + pulse * 0.1,
			["$pp_colour_colour"] = 0.6,
			["$pp_colour_mulr"] = 0,
			["$pp_colour_mulg"] = 0.04,
			["$pp_colour_mulb"] = 0
		})
	end
}

--[[
	Withdrawal, when the addiction does not name its own.

	Phoenix's shape exactly: nothing at severity 1, desaturation at 2, and
	motion blur on top at 3.
]]
ix.chemfx.defaultWithdrawal = {
	[1] = {},
	[2] = {"sobel"},
	[3] = {"sobel", "blur"}
}

--- Turn an effect on for a source. Idempotent.
function ix.chemfx.Add(effect, source)
	if (not ix.chemfx.renderers[effect]) then return end

	ix.chemfx.active[effect] = ix.chemfx.active[effect] or {}
	ix.chemfx.active[effect][source or "?"] = true
end

--- Turn off everything one source asked for.
function ix.chemfx.ClearSource(source)
	for effect, sources in pairs(ix.chemfx.active) do
		sources[source] = nil

		if (table.IsEmpty(sources)) then
			ix.chemfx.active[effect] = nil
		end
	end
end

function ix.chemfx.Clear()
	ix.chemfx.active = {}
end

--[[
	Rebuild the whole set from what is currently true.

	Cleared and re-derived rather than added to and removed from, for the same
	reason the withdrawal buffs are - see `sv_addiction.lua`. An effect that
	was turned on by something that has since gone is invisible to look for
	and permanent once it happens.
]]
function ix.chemfx.Rebuild()
	ix.chemfx.Clear()

	local client = LocalPlayer()

	if (not IsValid(client) or not client:GetCharacter()) then return end

	--- Withdrawal, from the addictions the server last sent.
	for _, addiction in ipairs(ix.addiction.GetLocal and ix.addiction.GetLocal() or {}) do
		if (addiction.severity > 0) then
			local data = ix.addiction.Get(addiction.name or "")
			local set = (data and data.screen or ix.chemfx.defaultWithdrawal)[addiction.severity]

			for _, effect in ipairs(set or {}) do
				ix.chemfx.Add(effect, "wd_" .. (addiction.name or addiction.text))
			end
		end
	end

	--- Chem highs, from the buffs currently running.
	for _, entry in ipairs(ix.chemfx.chemEffects or {}) do
		if (ix.buff.Has(client, entry.id)) then
			for _, effect in ipairs(entry.effects) do
				ix.chemfx.Add(effect, "chem_" .. entry.id)
			end
		end
	end
end

--[[
	Which `aidID` produces which effects while it is running.

	Held here rather than on the items because the client cannot see an item it
	is not carrying, and the effect has to keep running after the chem is used
	up. The buff is what persists, so the buff's id is the key.
]]
ix.chemfx.chemEffects = {
	{id = "Jet", effects = {"sharpen"}},
	{id = "Turbo", effects = {"sharpen", "blur"}},
	{id = "Psycho", effects = {"rage"}},
	{id = "Mentats", effects = {"clarity"}},
	{id = "Cateye", effects = {"nightvision"}},
	{id = "DayTripper", effects = {"euphoria"}},
	{id = "DaddyO", effects = {"clarity"}},
	{id = "XCell", effects = {"sharpen", "clarity"}},
	{id = "Serum", effects = {"euphoria", "sharpen"}},
	{id = "StealthBoy", effects = {"toytown"}}
}

--[[
	Rebuilt on a timer rather than on every message.

	Buffs expire on their own without the server saying anything, so an
	event-driven rebuild would leave a chem's effect running until the next
	sync. Twice a second is far finer than an effect that lasts minutes needs.
]]
timer.Create("ixChemFX", 0.5, 0, ix.chemfx.Rebuild)

hook.Add("RenderScreenspaceEffects", "ixChemFX", function()
	for effect in pairs(ix.chemfx.active) do
		local renderer = ix.chemfx.renderers[effect]

		if (renderer) then
			renderer()
		end
	end
end)

--[[
	The flash and the noise a chem makes going in.

	Phoenix's three, with their sounds: a needle, a swallow and an inhaler. The
	server picks which by the item's own `useEffect`, so a pill and a syringe
	do not feel the same.
]]
ix.chemfx.intake = {
	inject = {sound = "ambient/voices/m_scream1.wav", colour = Color(255, 255, 255)},
	swallow = {sound = "npc/barnacle/barnacle_gulp1.wav", colour = Color(255, 255, 255)},
	inhale = {sound = "HL1/fvox/hiss.wav", colour = Color(220, 240, 255)}
}

net.Receive("ixChemIntake", function()
	local kind = net.ReadString()
	local data = ix.chemfx.intake[kind]

	if (not data) then return end

	local client = LocalPlayer()

	if (not IsValid(client)) then return end

	--[[
		A one second fade rather than Phoenix's two: theirs holds long enough
		to be in the way, and this fires every time anybody takes anything.
	]]
	client:ScreenFade(SCREENFADE.IN, data.colour, 1, 0)

	--[[
		Their `Inject` plays a human scream, which is startling the first time
		and comical the twentieth. Kept because it is theirs and it is right
		for a needle going in, but at a volume that reads as a wince.
	]]
	surface.PlaySound(data.sound)
end)

hook.Add("CharacterLoaded", "ixChemFX", ix.chemfx.Clear)
