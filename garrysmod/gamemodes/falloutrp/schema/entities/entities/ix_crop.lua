--[[
	One crop growing in a plot.

	Phoenix's `nut_farm_plant`: an entity parented into a slot, with a growth
	number from 0 to 100 and a model that scales up as it fills. It is a
	separate entity rather than a number on the plot for one good reason -
	each crop is a different model, and nine of them have to be drawn in nine
	places.

	It has no `Use` of its own. Harvesting is the PLOT's job, because you take
	everything ripe at once and a crop you have to click individually is nine
	clicks nobody wants.
]]

AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Crop"
ENT.Category = "Fallout RP"
ENT.Spawnable = false
ENT.bNoPersist = true
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
	--- 0 to 100. A float, because it moves by fractions every second.
	self:NetworkVar("Float", 0, "Growth")

	--- The item this yields, which is also how the client names it.
	self:NetworkVar("String", 0, "PlantID")
end

--- Grown enough to pick.
function ENT:IsRipe()
	return self:GetGrowth() >= 100
end

if (SERVER) then
	function ENT:Initialize()
		self:SetModel(ix.farming.fallbackModel)
		self:SetMoveType(MOVETYPE_NONE)

		--[[
			NOT SOLID, deliberately. A crop is inside a box somebody has to be
			able to press E on; nine solid lumps in front of the plot would
			catch the use trace and the plot would never see it.
		]]
		self:SetSolid(SOLID_NONE)
		self:SetCollisionGroup(COLLISION_GROUP_WORLD)
		self:DrawShadow(false)
	end

	--[[
		Plant it. The model comes from what it grows, and the scale from how
		far along it is - so a crop restored from a save comes back the size it
		was rather than starting again as a seedling.
	]]
	function ENT:Sow(uniqueID, growth)
		self:SetPlantID(uniqueID)
		self:SetGrowth(math.Clamp(tonumber(growth) or 0, 0, 100))
		self:SetModel(ix.farming.CropModel(uniqueID))
		self:ApplyScale()
	end

	--- Half size at nothing, full size ripe. Phoenix's curve.
	function ENT:ApplyScale()
		self:SetModelScale(0.5 * (1 + (self:GetGrowth() / 100)), 0.1)
	end

	function ENT:AddGrowth(amount)
		local growth = math.min(self:GetGrowth() + amount, 100)

		self:SetGrowth(growth)
		self:ApplyScale()

		return growth
	end

	return
end

--------------------------------------------------------------------------------
-- What it looks like
--------------------------------------------------------------------------------

--[[
	THE BAR IS THE PLOT'S JOB, not this one's.

	A crop is parented and not solid, so a trace never returns one - the plot is
	what the crosshair finds. This drew its own bar when the trace's HIT
	POSITION landed within twelve units of it, which is a window nobody could
	find deliberately and the reason the growth bars looked missing. The plot
	draws all nine, over each crop, because it is the thing being looked at.
]]
function ENT:Draw()
	self:DrawModel()
end
