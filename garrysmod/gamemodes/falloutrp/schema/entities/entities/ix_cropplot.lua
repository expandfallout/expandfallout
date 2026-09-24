--[[
	A crop plot.

	Nine slots, a water level, and everything that happens to a farm. Phoenix's
	`nut_farm_planter`, on this schema's deployables and with its persistence -
	see `sh_farming.lua` for what is theirs and what is not.

	    a seed goes in     by Use on the plot with the seed in hand, or by
	                       dropping the seed on it
	    water goes in      the same two ways with a canister
	    E on the plot      takes every ripe crop, or as many as will fit

	THE SLOTS HOLD ENTITIES, not numbers - `ix_crop`, one each, parented into
	place. Nine different models have to be drawn in nine different spots and
	an entity is what draws a model.

	THE METHOD NAMES ARE DELIBERATELY ODD - `PlantSeed`, `AddWater`, `Advance`,
	`HarvestFor` rather than the obvious `Plant`, `Water`, `Tick`, `Harvest`.
	Gotcha 17: a method called `Respawn` on a scripted entity in this build
	answers nil however it is written, nobody has found out why, and it cost
	three rounds of debugging on the plants. Nothing here is worth finding a
	second one with.
]]

AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Crop Plot"
ENT.Category = "Fallout RP"
ENT.Spawnable = false
ENT.bNoPersist = true

ENT.Model = "models/fallout/plot/planter.mdl"
--[[
	RENDERGROUP_BOTH, AND WITHOUT IT NOTHING BELOW IS EVER DRAWN.

	`ENT:DrawTranslucent` is only called for entities in a translucent render
	group, and an anim entity with an opaque model is not in one - so the bars
	were written, were correct, and never ran. The two entities in this schema
	whose translucent drawing does work (`ix_breachcharge`'s glow and the
	orbital beacon's dome) both set this and that is the whole difference.
]]
ENT.RenderGroup = RENDERGROUP_BOTH


function ENT:SetupDataTables()
	--- Networked so the client can draw the water bar without asking.
	self:NetworkVar("Float", 0, "Water")
end

if (SERVER) then
	function ENT:Initialize()
		self:SetModel(self.Model)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		--- `[slot] = ix_crop`. Sparse: slot 4 can be full with 1 to 3 empty.
		self.crops = {}

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			--[[
				Heavy and frozen. Phoenix set a mass of a thousand because the
				model is "like a feather by default" and a farm you can shove
				across the room with your face is not a farm.
			]]
			physics:SetMass(1000)
			physics:EnableMotion(false)
			physics:Sleep()
		end
	end

	--- Frozen again after every wake; see `ix_factionstorage.lua`.
	function ENT:PhysicsUpdate(physics)
		if (physics:IsMotionEnabled()) then
			physics:EnableMotion(false)
			physics:Sleep()
		end
	end

	function ENT:OnRemove()
		for _, crop in pairs(self.crops or {}) do
			if (IsValid(crop)) then crop:Remove() end
		end
	end

	--- How many crops are in it.
	function ENT:Planted()
		local count = 0

		for _, crop in pairs(self.crops) do
			if (IsValid(crop)) then count = count + 1 end
		end

		return count
	end

	--- The first empty slot, or nil when it is full.
	function ENT:FreeSlot()
		for index = 1, ix.farming.slots do
			if (not IsValid(self.crops[index])) then return index end
		end
	end

	--------------------------------------------------------------------------
	-- Planting and watering
	--------------------------------------------------------------------------

	--[[
		Put a seed in. `growth` is only passed when a save is being restored;
		a seed somebody plants starts at nothing.
	]]
	function ENT:PlantSeed(uniqueID, growth)
		local slot = self:FreeSlot()

		if (not slot) then return false, "This plot is full." end

		if (not ix.item.list[uniqueID]) then
			return false, "That seed grows nothing."
		end

		local crop = ents.Create("ix_crop")

		if (not IsValid(crop)) then return false, "Could not plant that." end

		crop:SetPos(self:LocalToWorld(ix.farming.SlotOffset(slot)))
		crop:SetAngles(self:GetAngles())
		crop:Spawn()

		--[[
			PARENTED AFTER SPAWNING, and positioned before it. A parent set
			before `Spawn` is lost, and a local position set before parenting
			is a world position - which is how crops end up in a neat row
			somewhere near the map origin.
		]]
		crop:SetParent(self)
		crop:SetLocalPos(ix.farming.SlotOffset(slot))
		crop:SetLocalAngles(angle_zero)

		crop:Sow(uniqueID, growth)

		self.crops[slot] = crop

		ix.farming.Save()

		return true
	end

	--[[
		Tip a canister in.

		ONLY INTO A DRY PLOT. Not "only when it is not full" - only when there
		is nothing left in it at all. Topping a plot up whenever you walk past
		means a farm is never dry and the water is a formality; making you wait
		until it runs out is what turns watering into something you have to come
		back for, which is the whole point of the mechanic.
	]]
	function ENT:AddWater(amount)
		local max = ix.config.Get("farmWaterMax", 100)
		local water = self:GetWater()

		if (water > 0) then
			return false, string.format("This plot still has water in it - "
				.. "%d%% left.", math.ceil((water / math.max(max, 1)) * 100))
		end

		self:SetWater(math.min(amount, max))

		ix.farming.Save()

		return true
	end

	--------------------------------------------------------------------------
	-- Growing
	--------------------------------------------------------------------------

	--[[
		One second of growing, called by the farming tick.

		NOTHING GROWS WITHOUT WATER, which is Phoenix's rule and the only thing
		that makes a farm a thing you keep coming back to rather than a thing
		you place and forget.
	]]
	function ENT:Advance(seconds)
		local planted = self:Planted()

		if (planted == 0) then return false end

		local water = self:GetWater()

		if (water <= 0) then return false end

		local drain = ix.config.Get("farmWaterDrain", 0.05) * planted * seconds

		self:SetWater(math.max(water - drain, 0))

		--- 0 to 100 over the configured time, so the config reads as seconds.
		local step = (100 / math.max(ix.config.Get("farmGrowTime", 200), 1))
			* seconds

		local ripened = false

		for _, crop in pairs(self.crops) do
			if (not IsValid(crop) or crop:IsRipe()) then continue end

			if (crop:AddGrowth(step) >= 100) then ripened = true end
		end

		return ripened
	end

	--------------------------------------------------------------------------
	-- Harvesting
	--------------------------------------------------------------------------

	--[[
		Take everything ripe, or as much of it as will fit.

		A PARTIAL HARVEST IS THE POINT. Phoenix check the free slots first and
		refuse the whole thing if the yield will not fit, which means a full
		bag costs you the entire plot until you go and empty it. Here each crop
		is tried in turn and the first one that will not fit stops the harvest -
		everything already taken stays taken, and what is left is still ripe.
	]]
	function ENT:HarvestFor(client)
		local character = client:GetCharacter()
		local inventory = character and character:GetInventory()

		if (not inventory) then return end

		if (self:Planted() == 0) then
			client:Notify("There is nothing planted here.")

			return
		end

		local yield = ix.config.Get("farmYield", 3)
		local experience = ix.config.Get("farmXP", 1)

		local taken, ripe, full = 0, 0, false

		for slot, crop in pairs(self.crops) do
			if (not IsValid(crop) or not crop:IsRipe()) then continue end

			ripe = ripe + 1

			local uniqueID = crop:GetPlantID()
			local given = 0

			for _ = 1, yield do
				local added = inventory:Add(uniqueID)

				if (added == false or added == nil) then
					full = true

					break
				end

				given = given + 1
			end

			--[[
				NOTHING FIT, SO NOTHING WAS PICKED. The crop is left standing;
				taking it for no yield would be the worst of both.
			]]
			if (given == 0) then break end

			crop:Remove()
			self.crops[slot] = nil

			taken = taken + 1

			if (experience > 0) then character:AddXP(experience) end

			ix.log.Add(client, "farmHarvest", uniqueID, given)

			if (full) then break end
		end

		if (taken > 0) then
			self:EmitSound("phoenix/ui/nv/ui_items_generic_up_0"
				.. math.random(4) .. ".mp3", 65)

			ix.farming.Save()
		end

		if (ripe == 0) then
			client:Notify("None of these are ripe yet.")
		elseif (full and taken > 0) then
			client:Notify(string.format("You take %d - no room for the rest.",
				taken))
		elseif (full) then
			client:Notify("You have no room for any of this.")
		else
			client:Notify(string.format("You take %d ripe crop%s.", taken,
				taken == 1 and "" or "s"))
		end
	end

	function ENT:Use(activator)
		if (not IsValid(activator) or not activator:IsPlayer()) then return end

		--- Holding E fires `Use` several times a second.
		if ((activator.ixNextPlot or 0) > CurTime()) then return end

		activator.ixNextPlot = CurTime() + 1

		if (activator:IsRestricted()) then
			activator:Notify("Your hands are tied.")

			return
		end

		--[[
			WHAT IS IN YOUR HANDS DECIDES. Holding a seed plants it; holding a
			canister waters; holding neither harvests. That is the "just click
			use on it" half of getting a seed in, and it means the plot needs no
			menu at all.
		]]
		if (ix.farming.UseHeld(activator, self)) then return end

		self:HarvestFor(activator)
	end

	--[[
		A seed or a canister dropped on the plot goes in.

		Phoenix's flow is exactly this, with the item deployed as an entity
		first; here the dropped ITEM is the entity, so the same touch does it.

		TOUCH IS NOT ENOUGH ON ITS OWN. Two frozen physics props that come to
		rest against each other do not reliably produce a `StartTouch` - they
		collide and stop - so an item dropped neatly onto the soil can sit there
		untouched. The farming tick sweeps for anything resting on a plot as
		well; this is the fast path, that is the one that always works.
	]]
	function ENT:StartTouch(entity)
		if (not IsValid(entity) or entity:GetClass() ~= "ix_item") then
			return
		end

		ix.farming.AbsorbItem(self, entity)
	end

	return
end

--------------------------------------------------------------------------------
-- What it looks like
--------------------------------------------------------------------------------

local COLOR_WATER = Color(66, 134, 244)
local COLOR_DRY = Color(200, 90, 60)
local COLOR_BACK = Color(0, 0, 0, 130)

function ENT:Draw()
	self:DrawModel()
end

local COLOR_GROW = Color(244, 167, 66)
local COLOR_RIPE = Color(120, 220, 120)

--[[
	One bar, in world space, centred on `position` and facing the camera.

	Both the water and the nine crops are the same drawing job with different
	numbers, and doing it twice by hand is how the two ended up looking like
	different features.
]]
local function Bar(position, width, height, fraction, colour, text, font)
	local angles = EyeAngles()

	angles.p = 0
	angles.y = angles.y - 90
	angles.r = 90

	cam.Start3D2D(position, angles, 0.05)
		surface.SetDrawColor(COLOR_BACK)
		surface.DrawRect(-(width + 8) * 0.5, -4, width + 8, height + 8)

		surface.SetDrawColor(colour)
		surface.DrawRect(-width * 0.5, 0, width * math.Clamp(fraction, 0, 1),
			height)

		draw.SimpleText(text, font, 2, height * 0.5 + 2, color_black,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		draw.SimpleText(text, font, 0, height * 0.5, color_white,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	cam.End3D2D()
end

--[[
	The water bar ABOVE the plot, and a growth bar over every crop in it.

	BOTH ARE DRAWN BY THE PLOT, which is the fix for "each plant needs a
	progress bar". The crops tried to draw their own and mostly did not: a crop
	is parented and NOT SOLID, so a trace never returns one - the plot is what
	the crosshair finds - and the fallback of measuring the distance from the
	trace's hit position was a twelve unit window somebody had to find by
	accident. The plot knows where its crops are and can see all nine at once.

	The height comes from the model rather than a guess, so the bar floats over
	the planter instead of through it.
]]
function ENT:DrawTranslucent()
	local client = LocalPlayer()

	if (not IsValid(client)) then return end

	--- Looking at the plot, or at something standing in it.
	local looking = client:GetEyeTrace().Entity

	if (looking ~= self and (not IsValid(looking)
	or looking:GetParent() ~= self)) then
		return
	end

	local top = self:LocalToWorld(Vector(0, 0, self:OBBMaxs().z))

	local max = math.max(ix.config.Get("farmWaterMax", 100), 1)
	local water = math.Clamp(self:GetWater() / max, 0, 1)

	Bar(top + Vector(0, 0, 34), 1000, 75, water,
		water > 0 and COLOR_WATER or COLOR_DRY,
		water > 0 and string.format("Water %d%%", math.ceil(water * 100))
			or "DRY - nothing is growing", "ixZoneName")

	--- One over each crop, wherever that crop happens to be sitting.
	for _, crop in ipairs(self:GetChildren()) do
		if (not IsValid(crop) or crop:GetClass() ~= "ix_crop") then continue end

		local growth = math.Clamp(crop:GetGrowth() / 100, 0, 1)
		local ripe = growth >= 1
		local item = ix.item.list[crop:GetPlantID()]
		local name = item and item.name or "Crop"

		Bar(crop:GetPos() + Vector(0, 0, 12), 260, 34, growth,
			ripe and COLOR_RIPE or COLOR_GROW,
			ripe and (name .. " - ripe")
				or string.format("%s %d%%", name, math.floor(growth * 100)),
			"ixLootHeader")
	end
end
