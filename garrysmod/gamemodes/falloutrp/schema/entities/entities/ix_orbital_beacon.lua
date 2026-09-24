--[[
	An orbital drop beacon.

	It lands on a drop site, counts down, and calls the craft. While it is
	there the ground around it is a red dome and anybody inside it has a
	countdown and a PVP warning on their screen.

	PHOENIX'S `nut_orbital_beacon`, rebuilt. Their timings and their look:

	    a 640 unit radius, drawn as a red sphere and a floor box
	    a red glow sprite that blips faster as the time runs out
	    "Drop Countdown: hh:mm:ss" and "WARNING: PVP ZONE" inside the radius
	    at zero: an alert, then fifteen seconds, then the craft

	Written rather than copied - their draw code calls `nut.gui.palette` and
	their own net vars, and this schema's rule is that the scrapes are a
	reference and never a source. What it produces is the same.

	THE DOME IS DRAWN WITH A STENCIL, which is theirs and worth keeping: a
	plain translucent sphere is drawn over everything inside it, so a player
	standing in the dome would see the world through red. Writing the box to
	the stencil buffer first and testing against it means the sphere only
	appears where the marker on the ground is, which reads as a dome sitting on
	the world rather than a filter over it.
]]

AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Orbital Drop Beacon"
ENT.Category = "Fallout RP"
ENT.Spawnable = false
ENT.bNoPersist = true
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:SetupDataTables()
	--- When the craft is called. Networked so the countdown needs no message.
	self:NetworkVar("Float", 0, "DropTime")
end

if (SERVER) then
	function ENT:Initialize()
		self:SetModel(ix.orbital.assets.beacon)
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
			physics:Sleep()
		end

		local time = math.max(ix.config.Get("orbitalBeaconTime", 300), 5)

		self:SetDropTime(CurTime() + time)
		self:EmitSound(ix.orbital.assets.standby, 75, 90)

		--[[
			One timer for the countdown and a second for the launch delay, the
			way theirs is written - the fifteen seconds between "authorised"
			and the craft appearing is what makes the alert mean something.
		]]
		timer.Simple(time, function()
			if (not IsValid(self)) then return end

			self:EmitSound(ix.orbital.assets.authorized, 90)

			for _, client in ipairs(player.GetAll()) do
				if (client:GetPos():Distance(self:GetPos())
				> ix.orbital.radius * 2) then continue end

				client:ChatPrint("[Orbital] Drop authorised. Stand clear.")
			end

			timer.Simple(ix.orbital.launchDelay, function()
				if (not IsValid(self)) then return end

				local drone = ents.Create("ix_orbital_drone")

				if (IsValid(drone)) then
					--[[
						SPAWNED FIRST, AIMED SECOND. Everything the craft is
						told before `Spawn` would be told to an entity that
						does not exist yet; `Launch` is what starts its clock,
						so calling it after is also what stops it flying its
						whole pass during the frame it was created.
					]]
					drone:Spawn()
					drone:Launch(self:GetPos())

					ix.orbital.active = drone
				else
					ix.orbital.Finished()
				end

				--[[
					Handed over before removing itself: `ix.orbital.active` is
					what stops a second drop starting, and a gap between the
					beacon going and the craft arriving would be a gap where
					one could.
				]]
				self.ixHandedOver = true

				self:Remove()
			end)
		end)
	end

	function ENT:PhysicsUpdate(physics)
		if (physics:IsMotionEnabled()) then
			physics:EnableMotion(false)
			physics:Sleep()
		end
	end

	function ENT:OnRemove()
		self:EmitSound(ix.orbital.assets.destroyed, 70, 150)

		--[[
			If it was removed rather than having finished - a cleanup, an
			admin, a map change - the event is over and the clock restarts.
			Otherwise the craft it just created owns the event now.
		]]
		if (not self.ixHandedOver and ix.orbital.active == self) then
			ix.orbital.Finished()
		end
	end

	--- E says how long is left, for anybody who cannot read the sky.
	function ENT:Use(activator)
		if (not IsValid(activator) or not activator:IsPlayer()) then return end

		local left = math.max(self:GetDropTime() - CurTime(), 0)

		activator:Notify(string.format("Drop in %s.",
			string.FormattedTime(left, "%02i:%02i")))
	end
else
	local GLOW = Material("sprites/glow04_noz.vmt")
	local RED = Color(255, 50, 50)

	--- Every beacon on the map, so the HUD and the dome have a list to walk.
	local beacons = {}

	function ENT:Initialize()
		self.blip = 255

		beacons[#beacons + 1] = self
	end

	function ENT:OnRemove()
		--[[
			By value, not by a remembered index: removing an earlier entry
			renumbers everything after it, so an index kept from `Initialize`
			names the wrong beacon by the time it is used.
		]]
		table.RemoveByValue(beacons, self)
	end

	function ENT:Draw()
		self:DrawModel()
	end

	function ENT:BlipLight()
		local light = DynamicLight(self:EntIndex())

		if (not light) then return end

		light.Pos = self:GetPos() + self:GetUp() * 5
		light.r, light.g, light.b = RED.r, RED.g, RED.b
		light.Brightness = 5
		light.Size = 128
		light.Decay = 256
		light.DieTime = CurTime() + 0.5
	end

	--[[
		The blip runs down and resets, and it runs down faster in the last
		three seconds. That is theirs, and it is a good trick: the sound and
		the light are driven by the same falling number as the sprite's size,
		so all three speed up together without a second clock.
	]]
	function ENT:Think()
		local left = self:GetDropTime() - CurTime()

		if (left <= 0) then
			self.blip = 255
		elseif (left > 3) then
			self.blip = self.blip - FrameTime() * 500
		else
			self.blip = self.blip - FrameTime() * 2000
		end

		if (self.blip <= 0) then
			self.blip = 255

			self:EmitSound(ix.orbital.assets.blip, 70, 150, 0.4)
			self:BlipLight()
		end
	end

	function ENT:DrawTranslucent()
		local position = self:GetPos() + self:GetUp() * 5

		render.SetMaterial(GLOW)

		if (self:GetDropTime() - CurTime() <= 0) then
			render.DrawSprite(position, 24, 24, RED)
		else
			local size = self.blip / 5

			render.DrawSprite(position, size, size, RED)
		end
	end

	--------------------------------------------------------------------------
	-- The dome
	--------------------------------------------------------------------------

	hook.Add("PostDrawOpaqueRenderables", "ixOrbitalDome", function(depth)
		if (depth or #beacons == 0) then return end

		local client = LocalPlayer()

		if (not IsValid(client)) then return end

		local radius = ix.orbital.radius
		local reach = ix.orbital.renderDistance * ix.orbital.renderDistance

		render.SetStencilWriteMask(0xFF)
		render.SetStencilTestMask(0xFF)
		render.SetStencilReferenceValue(0)
		render.SetStencilPassOperation(STENCIL_KEEP)
		render.SetStencilZFailOperation(STENCIL_KEEP)
		render.ClearStencil()
		render.SetStencilEnable(true)

		for _, beacon in ipairs(beacons) do
			if (not IsValid(beacon)) then continue end
			if (beacon:GetPos():DistToSqr(client:GetPos()) > reach) then
				continue
			end

			--- The footprint, written to the stencil and not to the screen.
			render.SetStencilReferenceValue(1)
			render.SetStencilCompareFunction(STENCIL_NEVER)
			render.SetStencilFailOperation(STENCIL_REPLACE)

			render.SetColorMaterial()
			render.DrawBox(beacon:GetPos(), angle_zero,
				Vector(-radius, -radius, 0), Vector(radius, radius, 32),
				Color(255, 0, 0), true)

			--- The dome, only where the footprint is.
			render.SetStencilCompareFunction(STENCIL_EQUAL)
			render.SetStencilFailOperation(STENCIL_KEEP)

			render.SetColorMaterial()

			cam.Start3D()
				render.DrawSphere(beacon:GetPos(), radius, 25, 25,
					Color(255, 0, 0, 100))

				--- Again inside out, so it is there from within as well.
				render.DrawSphere(beacon:GetPos(), -radius, 25, 25,
					Color(255, 0, 0, 100))
			cam.End3D()
		end

		render.SetStencilEnable(false)
	end)

	--------------------------------------------------------------------------
	-- The countdown
	--------------------------------------------------------------------------

	hook.Add("HUDPaint", "ixOrbitalCountdown", function()
		if (#beacons == 0) then return end

		local client = LocalPlayer()

		if (not IsValid(client) or not client:Alive()) then return end

		local radius = ix.orbital.radius * ix.orbital.radius

		for _, beacon in ipairs(beacons) do
			if (not IsValid(beacon)) then continue end
			if (beacon:GetPos():DistToSqr(client:GetPos()) > radius) then
				continue
			end

			local left = beacon:GetDropTime() - CurTime()

			if (left <= 0) then break end

			local x = ScrW() * 0.5
			local text = "Drop Countdown: "
				.. string.FormattedTime(left, "%02i:%02i:%02i")

			draw.SimpleText(text, "ixZoneNote", x + 1, 76,
				Color(0, 0, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			draw.SimpleText(text, "ixZoneNote", x, 75,
				ix.config.Get("color"), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

			draw.SimpleText("WARNING: PVP ZONE", "ixZoneNote", x + 1, 101,
				Color(0, 0, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			draw.SimpleText("WARNING: PVP ZONE", "ixZoneNote", x, 100,
				Color(255, 0, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

			--- One beacon's worth of warning is enough; theirs breaks too.
			break
		end
	end)
end
