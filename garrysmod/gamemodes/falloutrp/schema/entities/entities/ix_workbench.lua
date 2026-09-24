--[[
	A workbench standing in the world.

	The recipes, the model, the size and the gating are a TYPE, in
	`sh_bench.lua`; the inventory and the job in progress are a placed RECORD,
	in `sv_bench.lua`. This entity holds the id of that record and nothing else
	that matters, so a bench is the same bench whatever happens to the prop.

	Everything networked here exists so the window and the tooltip can be drawn
	without asking the server: the type it is, what it is making, and how long
	is left. `NetworkVar` rather than `SetNW2` for all of it - a datatable
	sends its values including the defaults, where writing an NW2 var with its
	default value REMOVES it and the removal does not reliably reach clients.
	See `07-gotchas.md`.
]]

AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Workbench"
ENT.Category = "Fallout RP"
ENT.Spawnable = false
ENT.bNoPersist = true

function ENT:SetupDataTables()
	--- Which placed record this is. Everything else is looked up from it.
	self:NetworkVar("Int", 0, "BenchID")

	--- Which recipe is running, 0 for none.
	self:NetworkVar("Int", 1, "RecipeIndex")

	--- How many jobs are queued, the one running included.
	self:NetworkVar("Int", 2, "Queued")

	self:NetworkVar("String", 0, "BenchType")
	self:NetworkVar("String", 1, "BenchName")

	--- Who holds a capturable one, blank when nobody does.
	self:NetworkVar("String", 2, "OwnerName")

	--[[
		What the running job is making, by name.

		Networked rather than looked up from the recipe index, because a
		BLUEPRINT bench's recipe list belongs to whoever is standing at it -
		an index means nothing to anybody else, and the tooltip is read by
		people walking past.
	]]
	self:NetworkVar("String", 3, "JobName")

	--- Automatic benches only: whether it is switched on.
	self:NetworkVar("Bool", 0, "Running")

	--[[
		`CurTime` on both, and the pair rather than a fraction: a fraction has
		to be re-sent to move, and these two let the client draw a bar that
		fills smoothly from one message.
	]]
	self:NetworkVar("Float", 0, "JobFinish")
	self:NetworkVar("Float", 1, "JobLength")
end

if (SERVER) then
	function ENT:Initialize()
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
			physics:Sleep()
		end
	end

	--[[
		Frozen, and frozen again after every wake.

		`EnableMotion(false)` at spawn is not enough on its own: a physics
		object woken by an explosion or by a prop landing on it starts moving
		again, and a bench sliding down a hill is a bench nobody can find.
	]]
	function ENT:PhysicsUpdate(physics)
		if (physics:IsMotionEnabled()) then
			physics:EnableMotion(false)
			physics:Sleep()
		end
	end

	--[[
		ONE PRESS IS ONE PRESS.

		`SIMPLE_USE` fires again while E is held down, and every one of those
		sends the window's "open" message - which tears the panel down and
		builds it again, several times a second, for as long as the key is
		held. On the ordinary bench that reads as a flicker; on the modulate
		bench, whose window is a list of rows you are about to click, it reads
		as the window fighting you.

		Per PLAYER rather than per bench, because two people at one bench are
		two presses and neither should eat the other's.
	]]
	function ENT:Use(client)
		if (not IsValid(client) or not client:IsPlayer()) then return end

		client.ixNextBench = client.ixNextBench or 0

		if (client.ixNextBench > CurTime()) then return end

		client.ixNextBench = CurTime() + 1

		local record = ix.bench.Get(self:GetBenchID())

		if (not record) then
			client:Notify("This bench is not registered. Tell an admin.")

			return
		end

		--[[
			A capturable bench answers a press with the capture flow until
			somebody holds it - see `ix.bench.UseCapture`, which returns true
			when it has dealt with the press so the window is not opened as
			well.
		]]
		if (ix.bench.UseCapture and ix.bench.UseCapture(client, record)) then
			return
		end

		ix.bench.Open(client, record)
	end

	--[[
		THE RECORD OWNS THE INVENTORY, SO THE RECORD IS ASKED.

		Defined at all because an addon can shadow this through the Entity
		metatable and answer for a bench with something that is not a bench's
		inventory - `sh_entitymeta.lua` is what restores the precedence, and
		this is the method it restores. See `07-gotchas.md`, principle 8.
	]]
	function ENT:GetInventory()
		local record = ix.bench.Get(self:GetBenchID())

		return record and ix.inventory.Get(record.invID)
	end

	--[[
		The inventory is NOT destroyed with the entity.

		A bench removed by a map change or a cleanup keeps everything in it,
		because the record owns the inventory's lifetime. `ix.bench.Destroy` is
		the only thing that empties one, and it says so before it does.
	]]
	function ENT:OnRemove()
		local inventory = self:GetInventory()

		if (inventory and ix.storage.InUse(inventory)) then
			ix.storage.Close(inventory)
		end

		local record = ix.bench.Get(self:GetBenchID())

		if (record and record.entity == self) then
			record.entity = nil
		end
	end
else
	function ENT:Draw()
		self:DrawModel()
	end

	--[[
		The tooltip says what it is and what it is doing.

		A bench with nothing in progress says how to open it; one that is
		working says what it is making and how long is left, so somebody
		walking past a smelter can see it is running without opening it.
	]]
	function ENT:OnPopulateEntityInfo(tooltip)
		local title = tooltip:AddRow("name")

		title:SetImportant()
		title:SetText(self:GetBenchName() ~= "" and self:GetBenchName()
			or "Workbench")
		title:SizeToContents()

		local definition = ix.bench.GetType(self:GetBenchType())

		if (self:GetJobName() ~= "") then
			local remaining = math.max(self:GetJobFinish() - CurTime(), 0)
			local queued = self:GetQueued()
			local row = tooltip:AddRow("job")

			row:SetText(string.format("Making %s - %s left%s",
				self:GetJobName(),
				ix.bench.FormatTime(remaining),
				queued > 1 and string.format(" (%d queued)", queued - 1)
					or ""))
			row:SetBackgroundColor(ix.config.Get("color"))
			row:SizeToContents()

			return
		end

		--[[
			Said on the prop rather than only on the refusal, so somebody
			walking past a bench they cannot use knows it is the server being
			quiet and not the bench being broken.
		]]
		if (definition) then
			local enough, why = ix.bench.HasPopulation(definition)

			if (not enough) then
				local row = tooltip:AddRow("population")

				row:SetText(why)
				row:SizeToContents()

				return
			end
		end

		--[[
			Who holds it, on the prop. A bench you cannot open because somebody
			else took it should say so from across the room - that is most of
			what makes it worth taking.
		]]
		if (definition and definition.capturable) then
			local row = tooltip:AddRow("owner")

			row:SetText(self:GetOwnerName() ~= "" and ("Held by "
				.. self:GetOwnerName()) or "Unclaimed - press E to take it")
			row:SizeToContents()
		end

		local mode = definition and ix.bench.GetMode(definition.mode)

		if (mode and mode.automatic and not self:GetRunning()) then
			local row = tooltip:AddRow("off")

			row:SetText("Switched off.")
			row:SizeToContents()

			return
		end

		local row = tooltip:AddRow("use")

		row:SetText("Press E to use.")
		row:SizeToContents()
	end
end
