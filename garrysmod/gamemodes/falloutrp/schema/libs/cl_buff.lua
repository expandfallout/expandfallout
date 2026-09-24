--[[
	Buffs and addictions on the client.

	Nothing here draws anything. `fallout_ui/cl_hud.lua` already has a list of
	active modifiers in the top left, and it was written with this in mind:

	    A future buff plugin registers here; nothing about the drawing needs
	    to know where a modifier came from.
	                        -- ix.fallout.hud.buffSources

	So this registers a source and publishes what the addiction block needs,
	and the HUD keeps deciding where things go. A second painter in the same
	corner would have had to guess where the first one stopped.

	THE CLIENT KEEPS ITS OWN COPY, WHOLE. The server sends the entire list on
	every change rather than a stream of add and remove messages, so there is
	nothing to replay and nothing to get out of step - see `sv_buff.lua`. The
	one thing the client does for itself is count down, because a timer that
	only moves when the server says so is not a timer.
]]

if (not CLIENT) then return end

--[[
	TWO LOAD-ORDER TRAPS, BOTH OF WHICH THIS FILE SITS IN.

	`libs/` is included before `sh_schema.lua`, which is what pulls in
	`fallout_ui/cl_hud.lua` - so `ix.fallout.hud` does not exist while this
	file is being read. And within `libs/`, files load alphabetically, so
	`cl_buff` is read before `sh_addiction` and `ix.addiction` does not exist
	either.

	Either one, touched at file scope, throws - and the file then aborts before
	its `net.Receive` calls, so the buffs simply never arrive and nothing says
	why. That is the same failure that made `/lootconfig` open nothing; see
	`16-ui.md`.

	So the table is created defensively here, and the HUD registration is
	deferred to a timer below.
]]
ix.addiction = ix.addiction or {}

--[[
	Remaining seconds are stored as an EXPIRY on the local clock.

	The server sends "42 seconds left" and this turns it into "expires at local
	time X" once, on arrival. Storing the number and decrementing it every
	frame would drift with the frame rate; storing the end point cannot.

	`RealTime` rather than `CurTime`, so a countdown keeps counting while the
	game is paused in single player and does not jump when the server hitches.
]]
local buffs = {}
local addictions = {}

local ROMAN = {"I", "II", "III"}

net.Receive("ixBuffSync", function()
	local count = net.ReadUInt(8)
	local now = RealTime()

	buffs = {}

	for index = 1, count do
		local stat = net.ReadString()
		local value = net.ReadInt(16)
		local remaining = net.ReadUInt(16)
		local label = net.ReadString()

		buffs[index] = {
			stat = stat,
			value = value,
			expires = remaining > 0 and now + remaining or 0,
			label = label ~= "" and label or nil
		}
	end
end)

net.Receive("ixAddictionSync", function()
	local count = net.ReadUInt(8)

	addictions = {}

	for index = 1, count do
		addictions[index] = {
			name = net.ReadString(),
			label = net.ReadString(),
			severity = net.ReadUInt(4)
		}
	end
end)

--[[
	What the HUD's addiction block draws.

	Returned pre-formatted rather than as raw fields, so the severity numeral
	is decided in one place. The HUD asks for lines; it does not need to know
	that severity is 1 to 3 or that it is written in Roman numerals.
]]
function ix.addiction.GetLocal()
	local out = {}

	for _, addiction in ipairs(addictions) do
		local severity = addiction.severity or 0

		out[#out + 1] = {
			name = addiction.name,
			severity = severity,
			text = addiction.label
				.. (severity > 0 and ("  " .. (ROMAN[severity] or severity)) or "")
		}
	end

	return out
end

--[[
	The modifier source.

	Chem buffs are listed individually rather than summed per stat, unlike the
	armour source above it: two chems both giving +2 Perception have different
	amounts of time left, and a single "+4 PER" would have nothing sensible to
	count down.
]]
local function ChemModifiers(client, character, out)
	local now = RealTime()

	for _, buff in ipairs(buffs) do
		--[[
			Expired locally but not yet resynced. The server catches up
			within a second; skipping it here means the number on screen
			never counts past zero.
		]]
		if (buff.expires ~= 0 and buff.expires <= now) then continue end
		if (buff.value == 0) then continue end

		out[#out + 1] = {
			type = buff.stat,
			value = buff.value,
			suffix = buff.expires > 0
				and string.format("%ds", math.ceil(buff.expires - now))
				or buff.label,
			--[[
				A negative buff is a withdrawal penalty in every case that
				can currently produce one, and the sign is the honest test:
				anything taking a number away from you is bad news whatever
				put it there.
			]]
			bad = buff.value < 0
		}
	end
end

--[[
	Registered on a zero timer, which runs after every file has loaded.

	`hook.Add("InitPostEntity")` would be the obvious alternative and does not
	run in this schema at all - see `24-devtools.md`. A timer depends on
	nothing but the client ticking.

	Guarded, because a Lua refresh re-runs this file while `buffSources` still
	holds the previous registration, and two copies would list every chem
	twice.
]]
timer.Simple(0, function()
	if (not ix.fallout or not ix.fallout.hud) then return end

	ix.fallout.hud.buffSources = ix.fallout.hud.buffSources or {}

	for _, source in ipairs(ix.fallout.hud.buffSources) do
		if (source == ChemModifiers) then return end
	end

	ix.fallout.hud.buffSources[#ix.fallout.hud.buffSources + 1] = ChemModifiers
end)

--[[
	Cleared on a character change.

	The server syncs on load anyway, but between the swap and that message
	arriving the old character's chems would be on screen - and one of the two
	is somebody else.
]]
hook.Add("CharacterLoaded", "ixBuffHUD", function()
	buffs = {}
	addictions = {}
end)
