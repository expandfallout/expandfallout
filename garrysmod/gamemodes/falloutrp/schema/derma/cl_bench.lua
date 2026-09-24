--[[
	The window you get for pressing E on a workbench.

	    LEFT     every recipe the bench knows
	    RIGHT    the one you picked: what goes in, what comes out, and Craft
	    BOTTOM   the bar for whatever is running, and STORAGE

	ONE WINDOW, NOT THREE. Phoenix open a crafting frame, a separate inventory
	frame beside it, and a third for the recipe - then have to keep the three
	positioned relative to each other and remove two when the first closes.

	STORAGE opens Helix's own inventory window for the bench, which is the right
	tool for moving things and already knows how to drag. It cannot be stacked
	against this window in either direction - see the STORAGE button for why -
	so this one goes transparent and deaf while it is open, and comes back when
	it closes.

	WHAT YOU HAVE COUNTS BOTH PLACES: the bench and your pockets, added
	together, because that is what a craft consumes from.
]]

if (not CLIENT) then return end

local PANEL = {}

local function Scaled(value)
	return math.Round(value * ix.fallout.GetFontScale())
end

--- Rows paint themselves; `ixFOButton` inverts on hover and eats the text.
local function Row(parent, height)
	local row = parent:Add("DButton")

	row:Dock(TOP)
	row:SetTall(height)
	row:DockMargin(0, 0, 0, Scaled(2))
	row:SetText("")

	row.selected = false

	row.Paint = function(pnl, width, tall)
		local palette = ix.fallout.GetPalette()
		local colour = Color(30, 30, 36, 200)

		if (pnl.selected) then
			colour = Color(70, 58, 32, 255)
		elseif (pnl:IsHovered()) then
			colour = Color(56, 52, 40, 255)
		end

		surface.SetDrawColor(colour)
		surface.DrawRect(0, 0, width, tall)

		if (pnl.selected or pnl:IsHovered()) then
			surface.SetDrawColor(palette.color_primary)
			surface.DrawRect(0, 0, Scaled(3), tall)
		end

		if (pnl.PaintRow) then
			pnl:PaintRow(width, tall)
		end
	end

	return row
end

--[[
	A model preview at a size somebody chose.

	`SpawnIcon` docked TOP fills the width it is given and renders the model to
	fit THAT - so a 300-wide column produced a 300-wide icon and an item the
	size of a dinner plate. It goes in a container instead, at a fixed square,
	centred; the container is what docks.
]]
local function Preview(parent, model, size)
	local holder = parent:Add("Panel")

	holder:Dock(TOP)
	holder:SetTall(size)
	holder:DockMargin(0, 0, 0, Scaled(6))

	local icon = holder:Add("SpawnIcon")

	icon:SetSize(size, size)
	icon:SetModel(model or "")

	--- Nothing to click; the recipe list is what selects things.
	icon:SetMouseInputEnabled(false)

	holder.PerformLayout = function(pnl, width)
		icon:SetPos((width - size) * 0.5, 0)
	end

	return icon
end

function PANEL:Init()
	if (IsValid(ix.gui.bench)) then
		ix.gui.bench:Remove()
	end

	ix.gui.bench = self

	ix.fallout.LoadMenuFonts()

	self:SetSize(math.min(ScrW() - Scaled(60), Scaled(920)),
		math.min(ScrH() - Scaled(60), Scaled(700)))
	self:Center()
	self:MakePopup()
	self:SetTitle("WORKBENCH")

	self.selected = nil
	self.contents = {}
	self.counts = {}

	local footer = self:Add("Panel")

	footer:Dock(BOTTOM)
	footer:SetTall(Scaled(30))
	footer:DockMargin(0, Scaled(8), 0, 0)

	local close = footer:Add("ixFOButton")

	close:Dock(RIGHT)
	close:SetWide(Scaled(90))
	close:SetText("CLOSE")
	close:SetContentAlignment(5)
	close.DoClick = function() self:Remove() end

	--[[
		Helix's own inventory window for the bench.

		Whether anything may be put IN is the bench's setting (`allowInput`),
		enforced on the server by `CanTransferItem` - this button only opens
		the window, and a bench that refuses input simply refuses the drop.
	]]
	self.storage = footer:Add("ixFOButton")
	self.storage:Dock(RIGHT)
	self.storage:SetWide(Scaled(110))
	self.storage:DockMargin(0, 0, Scaled(6), 0)
	self.storage:SetText("STORAGE")
	self.storage:SetContentAlignment(5)

	self.storage.DoClick = function()
		if (not IsValid(self.entity)) then return end

		net.Start("ixBenchStorage")
			net.WriteEntity(self.entity)
		net.SendToServer()

		--[[
			Nothing is restacked here; `Think` hides this window instead.

			Raising the storage view cannot work, and the reason is worth
			writing down. `ixStorageView` is a fullscreen `Panel` that is never
			a popup, its two grids are `SetPaintedManually(true)`, and its own
			`Paint` draws them:

			    function PANEL:Paint(width, height)
			        ix.util.DrawBlurAt(0, 0, width, height)
			        for _, v in ipairs(self:GetChildren()) do
			            v:PaintManual()
			        end
			    end

			So the grids take INPUT at their own popup depth but are RENDERED
			at the parent's, and the parent - not being a popup - is below
			every popup on screen, this window included. Raising the children
			fixes the clicking and changes nothing about the drawing; raising
			the PARENT puts an invisible screen-sized panel over its own
			children and eats every click. Both of those were tried.

			The two are not orderable against each other, so they do not share
			the screen: this window goes transparent and stops taking input for
			as long as the storage view exists.
		]]
	end

	--[[
		Cancel takes the LAST thing queued, not the one running - see the
		server's handler. Hidden while nothing is queued rather than greyed,
		because a bench with an empty queue has nothing the button could mean.
	]]
	self.cancel = footer:Add("ixFOButton")
	self.cancel:Dock(RIGHT)
	self.cancel:SetWide(Scaled(110))
	self.cancel:DockMargin(0, 0, Scaled(6), 0)
	self.cancel:SetText("CANCEL LAST")
	self.cancel:SetContentAlignment(5)
	self.cancel:SetVisible(false)

	self.cancel.DoClick = function()
		if (not IsValid(self.entity)) then return end

		net.Start("ixBenchCancel")
			net.WriteEntity(self.entity)
		net.SendToServer()
	end

	--- Only on the modes that run by themselves; see `Rebuild`.
	self.toggle = footer:Add("ixFOButton")
	self.toggle:Dock(RIGHT)
	self.toggle:SetWide(Scaled(90))
	self.toggle:DockMargin(0, 0, Scaled(6), 0)
	self.toggle:SetContentAlignment(5)
	self.toggle:SetVisible(false)

	self.toggle.DoClick = function()
		if (not IsValid(self.entity)) then return end

		net.Start("ixBenchToggle")
			net.WriteEntity(self.entity)
		net.SendToServer()
	end

	self.hint = footer:Add("ixFOLabel")
	self.hint:Dock(FILL)
	self.hint:SetContentAlignment(4)
	self.hint:SetFont("ixLootSmall")
	self.hint:SetText("")

	--[[
		Hidden when nothing is running rather than drawn empty. An empty bar on
		an idle bench reads as a bench that is stuck.
	]]
	self.progress = self:Add("Panel")
	self.progress:Dock(BOTTOM)
	self.progress:SetTall(Scaled(26))
	self.progress:DockMargin(0, Scaled(6), 0, 0)
	self.progress:SetVisible(false)

	self.progress.Paint = function(pnl, width, height)
		local palette = ix.fallout.GetPalette()

		surface.SetDrawColor(20, 20, 24, 230)
		surface.DrawRect(0, 0, width, height)

		surface.SetDrawColor(ColorAlpha(palette.color_primary, 110))
		surface.DrawRect(0, 0, width * self:GetProgress(), height)

		surface.SetDrawColor(palette.color_primary)
		surface.DrawOutlinedRect(0, 0, width, height, 1)

		draw.SimpleText(self.progressText or "", "ixLootRow", width * 0.5,
			height * 0.5, palette.text_primary, TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER)
	end

	self.detail = self:Add("ixFOScrollPanel")
	self.detail:Dock(RIGHT)
	self.detail:SetWide(Scaled(280))
	self.detail:DockMargin(Scaled(10), 0, 0, 0)

	self.list = self:Add("ixFOScrollPanel")
	self.list:Dock(FILL)
end

--[[
	Which bench this window is for.

	Everything else is read back off the entity, which is where the server
	keeps it. Nothing is cached here that the entity already answers, so a
	bench edited or finishing a craft while the window is open catches up.
]]
function PANEL:SetBench(entity)
	self.entity = entity
	self.contents = {}
	self.counts = {}

	self:Ask()
	self:Rebuild()
end

--- Ask the server what is in the bench. Answered by `ixBenchCounts`.
function PANEL:Ask()
	if (not IsValid(self.entity)) then return end

	self.nextAsk = CurTime() + 1

	net.Start("ixBenchCounts")
		net.WriteEntity(self.entity)
	net.SendToServer()
end

function PANEL:GetDefinition()
	if (not IsValid(self.entity)) then return nil end

	return ix.bench.types[self.entity:GetBenchType()]
end

--[[
	How many of something is within reach: the bench, plus your own pockets.

	THE TWO HALVES COME FROM DIFFERENT PLACES, and neither is guessed. The
	bench's half is `self.counts`, sent by the server once a second because the
	client has no record to read it from; your own half is counted here, because
	the client's own inventory is the one thing it always knows accurately.
	Added together, this is what `ix.bench.Consume` will take on the server.
]]
function PANEL:Have(uniqueID)
	local character = LocalPlayer():GetCharacter()
	local own = character and character:GetInventory()

	return (self.counts[uniqueID] or 0) + ix.stack.Count(own, uniqueID)
end

--- How far through the job at the front of the queue, 0 to 1.
function PANEL:GetProgress()
	if (not IsValid(self.entity)) then return 0 end

	local length = self.entity:GetJobLength()

	if (length <= 0) then return 0 end

	local remaining = math.max(self.entity:GetJobFinish() - CurTime(), 0)

	return math.Clamp(1 - remaining / length, 0, 1)
end

--------------------------------------------------------------------------------
-- The recipe list
--------------------------------------------------------------------------------

function PANEL:Rebuild()
	if (not IsValid(self.entity)) then
		self:Remove()

		return
	end

	local definition = self:GetDefinition()

	if (not definition) then
		self:SetTitle("WORKBENCH")
		self.hint:SetText("This bench is not registered. Tell an admin.")

		return
	end

	local mode = ix.bench.GetMode(definition.mode)

	self:SetTitle(string.upper(definition.name or "WORKBENCH"))

	self.toggle:SetVisible(mode and mode.automatic or false)

	--[[
		An Instacraftory has no inventory at all, so the button would open a
		window onto nothing. Hidden rather than greyed - a disabled control is
		a promise that it does something in some other circumstance, and this
		one never does on this bench.
	]]
	self.storage:SetVisible(not (mode and mode.direct))
	self.hint:SetText(definition.description ~= ""
		and definition.description or (mode and mode.description or ""))

	self.list:Clear()

	self.rows = {}

	--[[
		Through the accessor, because a BLUEPRINT bench's list is what this
		character has learned rather than the type's own - see
		`ix.bench.Recipes`. Held in a field so `Select` reads exactly what was
		drawn, and an index cannot mean two different things a frame apart.
	]]
	self.recipes = ix.bench.Recipes(definition, LocalPlayer())

	for index, recipe in ipairs(self.recipes) do
		local row = Row(self.list, Scaled(40))
		local itemTable = ix.item.list[recipe.output]

		row.PaintRow = function(_, width, tall)
			local palette = ix.fallout.GetPalette()
			local amount = math.max(recipe.outputAmount or 1, 1)
			local name = ix.bench.RecipeName(recipe)

			if (amount > 1) then
				name = string.format("%s x%d", name, amount)
			end

			draw.SimpleText(name, "ixLootRow", Scaled(10), tall * 0.3,
				palette.text_primary, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			draw.SimpleText(itemTable and itemTable.category or "",
				"ixLootSmall", Scaled(10), tall * 0.72,
				ColorAlpha(palette.text_primary, 150),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			draw.SimpleText(ix.bench.FormatTime(recipe.time or 10),
				"ixLootSmall", width - Scaled(10), tall * 0.5,
				ColorAlpha(palette.color_primary, 200),
				TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end

		row.DoClick = function()
			self:Select(index)
		end

		self.rows[index] = row
	end

	if (#self.recipes < 1) then
		local empty = self.list:Add("ixFOLabel")

		empty:Dock(TOP)
		empty:SetTall(Scaled(40))
		empty:SetContentAlignment(5)
		empty:SetWrap(true)
		empty:SetFont("ixLootSmall")
		empty:SetText(definition.blueprint
			and "You have not learned any blueprints. Find one and read it."
			or "This bench has no recipes.")
	end

	--[[
		The selection survives a rebuild where it still exists. A bench that
		finished a craft rebuilds, and losing what you had open every time one
		finished would make a processing bench unusable to read.
	]]
	self:Select(self.selected or (self.recipes[1] and 1) or nil)
end

function PANEL:Select(index)
	local definition = self:GetDefinition()
	local recipe = (self.recipes or {})[index]

	self.selected = recipe and index or nil

	for i, row in pairs(self.rows or {}) do
		row.selected = i == self.selected
	end

	self.detail:Clear()

	if (not recipe) then return end

	local title = self.detail:Add("ixFOLabel")

	title:Dock(TOP)
	title:SetTall(Scaled(24))
	title:SetFont("ixLootHeader")
	title:SetText(ix.bench.RecipeName(recipe))

	local itemTable = ix.item.list[recipe.output]

	if (itemTable) then
		Preview(self.detail, itemTable.model, Scaled(96))

		local description = self.detail:Add("ixFOLabel")

		description:Dock(TOP)
		description:SetFont("ixLootSmall")
		description:SetWrap(true)
		description:SetAutoStretchVertical(true)
		description:DockMargin(0, 0, 0, Scaled(8))
		description:SetText(string.format("Makes %d %s. Takes %s.",
			math.max(recipe.outputAmount or 1, 1), itemTable.name,
			ix.bench.FormatTime(recipe.time or 10)))
	end

	local needed = ix.bench.Needed(recipe)

	if (table.Count(needed) > 0) then
		local header = self.detail:Add("ixFOLabel")

		header:Dock(TOP)
		header:SetTall(Scaled(22))
		header:SetFont("ixLootHeader")
		header:SetText("NEEDS")

		for uniqueID, amount in SortedPairs(needed) do
			local input = ix.item.list[uniqueID]
			local line = self.detail:Add("ixFOLabel")

			line:Dock(TOP)
			line:SetTall(Scaled(20))
			line:SetFont("ixLootSmall")
			line:SetText("")

			--[[
				Counted every frame rather than at build time. Materials move
				while this is open, and a count that only refreshed on a click
				would be wrong exactly when somebody is gathering them.
			]]
			line.Paint = function(pnl, width, height)
				local palette = ix.fallout.GetPalette()
				local have = self:Have(uniqueID)

				draw.SimpleText(input and input.name or uniqueID,
					"ixLootSmall", 0, height * 0.5, palette.text_primary,
					TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

				draw.SimpleText(string.format("%d / %d", have, amount),
					"ixLootSmall", width, height * 0.5,
					have >= amount and Color(140, 210, 140)
						or Color(210, 120, 120),
					TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end
		end
	end

	local mode = ix.bench.GetMode(definition.mode)

	local craft = self.detail:Add("ixFOButton")

	craft:Dock(TOP)
	craft:SetTall(Scaled(32))
	craft:DockMargin(0, Scaled(10), 0, 0)
	craft:SetContentAlignment(5)
	craft:SetText(mode and mode.automatic and "MAKE THIS" or "CRAFT")

	craft.DoClick = function()
		net.Start("ixBenchCraft")
			net.WriteEntity(self.entity)
			net.WriteUInt(index, 8)
		net.SendToServer()

		timer.Simple(0.1, function()
			if (IsValid(self)) then self:Ask() end
		end)
	end

	if (not mode or mode.automatic) then return end

	local note = self.detail:Add("ixFOLabel")

	note:Dock(TOP)
	note:SetFont("ixLootSmall")
	note:SetWrap(true)
	note:SetAutoStretchVertical(true)
	note:DockMargin(0, Scaled(6), 0, 0)
	if (mode.direct) then
		note:SetText(string.format("Straight into your pockets - this bench "
			.. "has no storage. Press it again to queue another, up to %d.",
			math.max(definition.queueMax or 10, 1)))

		return
	end

	note:SetText(string.format("Press it again to queue another. Up to %d, "
		.. "and %s. Materials are taken when you queue, not when it starts.",
		math.max(definition.queueMax or 10, 1),
		definition.parallel and "they all run at once"
			or "they run one after another"))
end

--------------------------------------------------------------------------------
-- Keeping up
--------------------------------------------------------------------------------

function PANEL:Think()
	if (not IsValid(self.entity)) then
		self:Remove()

		return
	end

	if (LocalPlayer():GetPos():Distance(self.entity:GetPos()) > 250) then
		self:Remove()

		return
	end

	local index = self.entity:GetRecipeIndex()
	local queued = self.entity:GetQueued()
	local running = self.entity:GetJobName() ~= ""

	self.progress:SetVisible(running)
	self.cancel:SetVisible(queued > 0)

	if (running) then
		local remaining = math.max(self.entity:GetJobFinish() - CurTime(), 0)

		self.progressText = string.format("%s - %s left%s",
			self.entity:GetJobName(), ix.bench.FormatTime(remaining),
			queued > 1 and string.format("   (%d more queued)", queued - 1)
				or "")
	end

	--[[
		Out of the way while the storage window is up - see the STORAGE button.
		Alpha and input rather than `SetVisible(false)`, because a hidden panel
		is not guaranteed to keep thinking, and this is the think that has to
		notice the storage closing again and bring the window back.
	]]
	local storageOpen = IsValid(ix.gui.openedStorage)

	if (self.stepped ~= storageOpen) then
		self.stepped = storageOpen

		self:SetAlpha(storageOpen and 0 or 255)
		self:SetMouseInputEnabled(not storageOpen)
		self:SetKeyboardInputEnabled(not storageOpen)
	end

	if ((self.nextAsk or 0) < CurTime()) then
		self:Ask()
	end

	if (self.toggle:IsVisible()) then
		self.toggle:SetText(self.entity:GetRunning() and "STOP" or "START")
	end

	--[[
		`lastRecipe` and `lastQueued` are what make the rebuild happen once
		rather than every frame: the entity is the only thing that knows a
		craft finished, and comparing what it says now against last frame is
		cheaper than any message and cannot be missed.
	]]
	if (self.lastRecipe ~= index or self.lastQueued ~= queued) then
		self.lastRecipe = index
		self.lastQueued = queued

		self:Select(self.selected)
	end
end

function PANEL:OnRemove()
	if (ix.gui.bench == self) then
		ix.gui.bench = nil
	end
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Remove()
	end
end

vgui.Register("ixFOBench", PANEL, "ixFOFrame")

net.Receive("ixBenchCounts", function()
	local entity = net.ReadEntity()
	local count = net.ReadUInt(8)

	--[[
		`contents` is the item list and `counts` the tally of it. Only the
		tally is drawn now - the output bin is Helix's storage window again -
		but the server sends the items because the same message answers both,
		and one message that cannot disagree with itself is worth a few bytes.
	]]
	local contents, counts = {}, {}

	for _ = 1, count do
		local id = net.ReadUInt(32)
		local uniqueID = net.ReadString()
		local quantity = net.ReadUInt(16)

		contents[#contents + 1] =
			{id = id, uniqueID = uniqueID, quantity = quantity}

		counts[uniqueID] = (counts[uniqueID] or 0) + quantity
	end

	--[[
		Dropped unless it is for the bench the window is showing. A reply can
		arrive after the player has walked to a different bench, and counting
		one bench's contents against another's recipe is worse than counting
		nothing.
	]]
	if (not IsValid(ix.gui.bench) or ix.gui.bench.entity ~= entity) then
		return
	end

	ix.gui.bench.contents = contents
	ix.gui.bench.counts = counts
end)
