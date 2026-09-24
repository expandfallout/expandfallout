--[[
	What a transformation looks like.

	Phoenix throw `util.Effect("VortDispel")` once a second with
	`ambient/machines/thumper_hit.wav` under it - the "womb, womb" - and freeze
	the player while their model scales. Neither of those assets is on this
	server: `thumper_hit.wav` is Half-Life 2 (gotcha 16), and an effect that
	does not exist fails silently rather than loudly.

	SO IT IS DRAWN RATHER THAN SPAWNED. `render.SetColorMaterial` and
	`render.DrawSphere` need no content at all - they are engine primitives -
	so this cannot be broken by a missing pack, and it looks like what it is
	meant to look like: a shell of light that swells and collapses on every
	beat, a light on the ground, and a screen shake for anybody near enough to
	feel it.

	THE SOUND IS PITCHED DOWN, which is the whole trick. `ui_karma_down` is a
	short descending tone; played at pitch 45 it is a low thump, and one per
	second for nine seconds is the pulse Phoenix's has.
]]

if (not CLIENT) then return end

ix.raceinject = ix.raceinject or {}

--- `[player] = {start, finish, beat}`. Cleared when it ends.
local active = {}

net.Receive("ixRaceTransform", function()
	local client = net.ReadEntity()
	local seconds = net.ReadUInt(8)

	if (not IsValid(client)) then return end

	active[client] = {
		start = CurTime(),
		finish = CurTime() + seconds,
		beat = 0
	}
end)

--[[
	The beats: a sound and a shake on each one.

	Done in `Think` rather than with nine timers, because the entity can go
	away mid-way through and a timer holding a reference to it would keep
	firing at nothing.
]]
hook.Add("Think", "ixRaceTransform", function()
	local now = CurTime()
	local viewer = LocalPlayer()

	for client, state in pairs(active) do
		if (not IsValid(client) or now >= state.finish) then
			active[client] = nil

			continue
		end

		local beat = math.floor(now - state.start)

		if (beat <= state.beat) then continue end

		state.beat = beat

		--[[
			PITCH FALLS AS IT GOES, so the pulse gets deeper and the thing
			plainly builds towards something. 60 down to about 35 over nine
			beats.
		]]
		local fraction = math.Clamp((now - state.start)
			/ math.max(state.finish - state.start, 1), 0, 1)

		client:EmitSound("phoenix/ui/nv/ui_karma_down.mp3", 85,
			60 - fraction * 25, 0.9)

		--[[
			The shake is the VIEWER's, and it falls off with distance - being
			near one of these should be felt, and being across the map should
			not.
		]]
		if (IsValid(viewer)) then
			local distance = viewer:GetPos():Distance(client:GetPos())

			if (distance < 700) then
				util.ScreenShake(viewer:GetPos(),
					4 * (1 - distance / 700), 8, 0.6, 1)
			end
		end
	end
end)

--[[
	The shell.

	`PostDrawTranslucentRenderables` rather than `PostDrawOpaqueRenderables`,
	because it is transparent and has to be sorted against smoke, glass and
	the other translucent things in the world - drawn in the opaque pass it
	would punch a hole through anything behind it.
]]
hook.Add("PostDrawTranslucentRenderables", "ixRaceTransform",
	function(depth, sky)
	if (sky) then return end

	local now = CurTime()

	for client, state in pairs(active) do
		if (not IsValid(client)) then continue end

		local length = math.max(state.finish - state.start, 1)
		local fraction = math.Clamp((now - state.start) / length, 0, 1)

		--[[
			Two spheres: a slow one that grows for the whole nine seconds and
			says how far along this is, and a fast one that swells and
			collapses on every beat, which is what reads as a pulse.
		]]
		local centre = client:LocalToWorld(client:OBBCenter())
		local pulse = 1 - math.abs(math.sin(now * math.pi))
		local radius = 20 + fraction * 40

		render.SetColorMaterial()

		render.DrawSphere(centre, -(radius + pulse * 22), 24, 24,
			Color(120, 255, 160, 20 + pulse * 40))

		render.DrawWireframeSphere(centre, radius, 16, 16,
			Color(150, 255, 190, 90 + pulse * 90), true)

		--[[
			A light on the floor, so the transformation lights the room rather
			than floating in it. `DynamicLight` is keyed by an index, and using
			the player's entity index means two people transforming at once get
			two lights rather than fighting over one.
		]]
		local light = DynamicLight(client:EntIndex())

		if (light) then
			light.pos = centre
			light.r = 120
			light.g = 255
			light.b = 170
			light.brightness = 2 + pulse * 3
			light.decay = 1000
			light.size = 220
			light.dietime = now + 0.2
		end
	end
end)
