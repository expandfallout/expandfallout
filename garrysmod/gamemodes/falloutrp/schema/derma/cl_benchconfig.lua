--[[
	The workbench creator and configurer. `/benchconfig`.

	    LEFT     every kind of bench there is
	    MIDDLE   that bench's settings, then its recipes
	    RIGHT    the recipe you are editing, and what goes into it

	ONE WINDOW, THREE COLUMNS. Phoenix's creator is a 1273-line wizard with
	Next and Back buttons over five pages, a preset system to avoid retyping
	what the wizard makes you retype, and a separate frame for each of the
	three bench types. That shape exists because their bench data is spread
	across the entity, and the wizard is what assembles it. Ours is one table,
	so the whole thing is one form - and you can see the recipe you are editing
	against the bench it belongs to, which the wizard cannot show you at all.

	EDITED ON A COPY. `self.editing` is a deep copy of the definition, and
	nothing is sent until SAVE. Half-finished edits leaking into a live bench
	is how you get a recipe that consumes without producing, and the server
	validates the whole table on arrival anyway - see `ix.bench.Validate`.
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

--- A labelled row in the editor, so every field is built the same way.
local function Field(parent, text)
	local label = parent:Add("ixFOLabel")

	label:Dock(TOP)
	label:SetTall(Scaled(18))
	label:SetFont("ixLootSmall")
	label:SetText(text)

	return label
end

function PANEL:Init()
	if (IsValid(ix.gui.benchConfig)) then
		ix.gui.benchConfig:Remove()
	end

	ix.gui.benchConfig = self

	ix.fallout.LoadMenuFonts()

	self:SetSize(math.min(ScrW() - Scaled(60), Scaled(1200)),
		math.min(ScrH() - Scaled(60), Scaled(740)))
	self:Center()
	self:MakePopup()
	self:SetTitle("WORKBENCHES")

	--- The definition being edited, and which of its recipes is open.
	self.editing = nil
	self.recipe = nil

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

	self.save = footer:Add("ixFOButton")
	self.save:Dock(RIGHT)
	self.save:SetWide(Scaled(90))
	self.save:DockMargin(0, 0, Scaled(6), 0)
	self.save:SetText("SAVE")
	self.save:SetContentAlignment(5)
	self.save.DoClick = function() self:Commit() end

	self.delete = footer:Add("ixFOButton")
	self.delete:Dock(RIGHT)
	self.delete:SetWide(Scaled(90))
	self.delete:DockMargin(0, 0, Scaled(6), 0)
	self.delete:SetText("DELETE")
	self.delete:SetContentAlignment(5)

	self.delete.DoClick = function()
		if (not self.editing) then return end

		local placed = ix.bench.CountPlaced(self.editing.uniqueID)

		Derma_Query(string.format("Delete %s? %s", self.editing.name,
			placed > 0 and string.format("The %d already placed go with it, "
				.. "and everything inside them.", placed)
				or "None are placed."),
			"Workbenches", "Delete", function()
				net.Start("ixBenchConfigDelete")
					net.WriteString(self.editing.uniqueID)
				net.SendToServer()

				self.editing = nil
				self.recipe = nil
			end, "Cancel", function() end)
	end

	--[[
		Placing from here rather than only from `/benchplace`.

		You have just finished describing a bench; being told to close the
		window and type its id is the kind of small friction that makes a tool
		feel unfinished. It refuses an UNSAVED one deliberately - the server
		places from its own copy of the type, so placing a bench it has never
		been told about would put down something that does not exist yet.
	]]
	self.place = footer:Add("ixFOButton")
	self.place:Dock(RIGHT)
	self.place:SetWide(Scaled(90))
	self.place:DockMargin(0, 0, Scaled(6), 0)
	self.place:SetText("PLACE")
	self.place:SetContentAlignment(5)

	self.place.DoClick = function()
		if (not self.editing) then return end

		local uniqueID = self.editing.uniqueID

		if (not ix.bench.types[uniqueID]) then
			self:Say("SAVE it first - the server has never heard of it.")

			return
		end

		self:Remove()
		ix.bench.BeginPlacing(uniqueID)
	end

	--[[
		The blueprint recipes are not a property of any bench - one list is
		shared by every blueprint bench, because the knowledge is on the
		character. So it is its own window, reached from here because here is
		where somebody would look for it.
	]]
	local blueprints = footer:Add("ixFOButton")

	blueprints:Dock(RIGHT)
	blueprints:SetWide(Scaled(110))
	blueprints:DockMargin(0, 0, Scaled(6), 0)
	blueprints:SetText("BLUEPRINTS")
	blueprints:SetContentAlignment(5)
	blueprints.DoClick = function() vgui.Create("ixFOBlueprintConfig") end

	self.hint = footer:Add("ixFOLabel")
	self.hint:Dock(FILL)
	self.hint:SetContentAlignment(4)
	self.hint:SetFont("ixLootSmall")
	self.hint:SetText("Pick a bench, or make one. Nothing is sent until SAVE.")

	-- right: the recipe editor
	self.editor = self:Add("ixFOScrollPanel")
	self.editor:Dock(RIGHT)
	self.editor:SetWide(Scaled(320))
	self.editor:DockMargin(Scaled(10), 0, 0, 0)

	-- left: the benches
	local left = self:Add("Panel")

	left:Dock(LEFT)
	left:SetWide(Scaled(240))
	left:DockMargin(0, 0, Scaled(10), 0)

	local new = left:Add("ixFOButton")

	new:Dock(BOTTOM)
	new:SetTall(Scaled(28))
	new:DockMargin(0, Scaled(6), 0, 0)
	new:SetText("NEW BENCH")
	new:SetContentAlignment(5)
	new.DoClick = function() self:OpenCreate() end

	self.benches = left:Add("ixFOScrollPanel")
	self.benches:Dock(FILL)

	-- middle: settings, then recipes
	self.middle = self:Add("ixFOScrollPanel")
	self.middle:Dock(FILL)

	self:Rebuild()
end

function PANEL:Say(text)
	self.hint:SetText(text)
end

--------------------------------------------------------------------------------
-- The bench list
--------------------------------------------------------------------------------

function PANEL:Rebuild()
	self.benches:Clear()

	--[[
		`self.editing` IS NOT RE-READ HERE, and that is the point.

		A sync arrives every time anybody saves anything, and this runs on each
		one. Refreshing the open copy from the server's would throw away a
		half-written recipe because somebody else pressed SAVE on a different
		bench. The list on the left is what refreshes; the form keeps what you
		typed until you SAVE it or close it.
	]]
	local sorted = ix.bench.SortedTypes()

	for _, definition in ipairs(sorted) do
		local row = Row(self.benches, Scaled(38))

		row.selected = self.editing
			and self.editing.uniqueID == definition.uniqueID

		row.PaintRow = function(_, width, tall)
			local palette = ix.fallout.GetPalette()
			local mode = ix.bench.GetMode(definition.mode)

			draw.SimpleText(definition.name or definition.uniqueID,
				"ixLootRow", Scaled(10), tall * 0.3, palette.text_primary,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			draw.SimpleText(string.format("%s - %d recipe(s)",
				mode and mode.name or definition.mode,
				#(definition.recipes or {})), "ixLootSmall", Scaled(10),
				tall * 0.72, ColorAlpha(palette.text_primary, 150),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			local placed = ix.bench.CountPlaced(definition.uniqueID)

			if (placed > 0) then
				draw.SimpleText(placed .. " out", "ixLootSmall",
					width - Scaled(8), tall * 0.5,
					ColorAlpha(palette.color_primary, 200),
					TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end
		end

		row.DoClick = function()
			self:Edit(definition)
		end
	end

	if (#sorted < 1) then
		local empty = self.benches:Add("ixFOLabel")

		empty:Dock(TOP)
		empty:SetTall(Scaled(40))
		empty:SetContentAlignment(5)
		empty:SetWrap(true)
		empty:SetFont("ixLootSmall")
		empty:SetText("No benches yet. NEW BENCH makes one.")
	end

	self:BuildMiddle()
end

--- Take a copy of a definition and open it.
function PANEL:Edit(definition)
	self.editing = table.Copy(definition)
	self.editing.recipes = self.editing.recipes or {}
	self.recipe = nil

	self:Rebuild()
	self:BuildEditor()
end

--------------------------------------------------------------------------------
-- The bench's own settings, and its recipes
--------------------------------------------------------------------------------

function PANEL:BuildMiddle()
	self.middle:Clear()

	local definition = self.editing

	if (not definition) then
		local empty = self.middle:Add("ixFOLabel")

		empty:Dock(TOP)
		empty:SetTall(Scaled(40))
		empty:SetContentAlignment(5)
		empty:SetFont("ixLootRow")
		empty:SetText("Pick a bench on the left.")

		return
	end

	local header = self.middle:Add("ixFOLabel")

	header:Dock(TOP)
	header:SetTall(Scaled(26))
	header:SetFont("ixLootHeader")
	header:SetText("SETTINGS")

	--- Name.
	Field(self.middle, "Name")

	local name = self.middle:Add("ixFOTextEntry")

	name:Dock(TOP)
	name:SetTall(Scaled(26))
	name:DockMargin(0, 0, 0, Scaled(6))
	name:SetText(definition.name or "")
	name:SetUpdateOnType(true)
	name.OnValueChange = function(_, text) definition.name = text end

	--- What it says under the name in the bench window.
	Field(self.middle, "Description")

	local description = self.middle:Add("ixFOTextEntry")

	description:Dock(TOP)
	description:SetTall(Scaled(26))
	description:DockMargin(0, 0, 0, Scaled(6))
	description:SetText(definition.description or "")
	description:SetUpdateOnType(true)

	description.OnValueChange = function(_, text)
		definition.description = text
	end

	--- Mode.
	Field(self.middle, "Mode")

	local mode = self.middle:Add("DComboBox")

	mode:Dock(TOP)
	mode:SetTall(Scaled(26))
	mode:DockMargin(0, 0, 0, Scaled(2))
	mode:SetSortItems(false)

	for _, entry in ipairs(ix.bench.modes) do
		mode:AddChoice(entry.name, entry.id,
			entry.id == definition.mode)
	end

	local modeHint = self.middle:Add("ixFOLabel")

	modeHint:Dock(TOP)
	modeHint:SetFont("ixLootSmall")
	modeHint:SetWrap(true)
	modeHint:SetAutoStretchVertical(true)
	modeHint:DockMargin(0, 0, 0, Scaled(6))
	modeHint:SetText((ix.bench.GetMode(definition.mode) or {}).description
		or "")

	mode.OnSelect = function(_, _, _, data)
		definition.mode = data

		modeHint:SetText((ix.bench.GetMode(data) or {}).description or "")
	end

	--- Model, with a preview that is the check on whether it exists.
	Field(self.middle, "Model")

	local model = self.middle:Add("ixFOTextEntry")

	model:Dock(TOP)
	model:SetTall(Scaled(26))
	model:SetText(definition.model or "")
	model:SetUpdateOnType(true)

	local preview = self.middle:Add("DModelPanel")

	preview:Dock(TOP)
	preview:SetTall(Scaled(150))
	preview:DockMargin(0, Scaled(4), 0, Scaled(4))
	preview:SetModel(definition.model or "")
	preview:SetFOV(45)

	--[[
		The camera is set from the model's OWN bounds rather than from a fixed
		distance: these props range from an anvil to a power armour station,
		and one distance that framed both does not exist.
	]]
	local function Frame()
		local entity = preview:GetEntity()

		if (not IsValid(entity)) then return end

		local mins, maxs = entity:GetRenderBounds()
		local size = math.max(maxs:Distance(mins), 16)

		preview:SetCamPos(Vector(size * 0.8, size * 0.8, size * 0.5))
		preview:SetLookAt((mins + maxs) * 0.5)
	end

	Frame()

	model.OnValueChange = function(_, text)
		definition.model = text

		preview:SetModel(text)
		Frame()
	end

	local presets = self.middle:Add("DComboBox")

	presets:Dock(TOP)
	presets:SetTall(Scaled(26))
	presets:DockMargin(0, 0, 0, Scaled(6))
	presets:SetValue("Installed bench models")
	presets:SetSortItems(false)

	for _, path in ipairs(ix.bench.models) do
		presets:AddChoice(string.GetFileFromFilename(path), path)
	end

	presets.OnSelect = function(_, _, _, data)
		definition.model = data

		model:SetText(data)
		preview:SetModel(data)
		Frame()
	end

	--- Inventory size.
	Field(self.middle, "Inventory size (only affects benches placed after)")

	local sizes = self.middle:Add("Panel")

	sizes:Dock(TOP)
	sizes:SetTall(Scaled(30))
	sizes:DockMargin(0, 0, 0, Scaled(6))

	local width = sizes:Add("ixFONumberEntry")

	width:Dock(LEFT)
	width:SetWide(Scaled(120))
	width:SetMin(ix.bench.minSize)
	width:SetMax(ix.bench.maxSize)
	width:SetSuffix("wide")
	width:SetValue(definition.invW or 6)
	width.OnChanged = function(_, value) definition.invW = value or 6 end

	local height = sizes:Add("ixFONumberEntry")

	height:Dock(LEFT)
	height:SetWide(Scaled(120))
	height:DockMargin(Scaled(6), 0, 0, 0)
	height:SetMin(ix.bench.minSize)
	height:SetMax(ix.bench.maxSize)
	height:SetSuffix("tall")
	height:SetValue(definition.invH or 4)
	height.OnChanged = function(_, value) definition.invH = value or 4 end

	--- Who may use it.
	Field(self.middle, "Faction")

	local faction = self.middle:Add("DComboBox")

	faction:Dock(TOP)
	faction:SetTall(Scaled(26))
	faction:DockMargin(0, 0, 0, Scaled(6))
	faction:AddChoice("Everyone", ix.shop.GLOBAL,
		definition.faction == ix.shop.GLOBAL)

	local factions = {}

	for _, team in pairs(ix.faction.teams) do
		factions[#factions + 1] = team
	end

	table.sort(factions, function(a, b) return a.name < b.name end)

	for _, team in ipairs(factions) do
		faction:AddChoice(team.name, team.uniqueID,
			definition.faction == team.uniqueID)
	end

	local rankLabel = Field(self.middle, "Lowest rank")

	local rank = self.middle:Add("DComboBox")

	rank:Dock(TOP)
	rank:SetTall(Scaled(26))
	rank:DockMargin(0, 0, 0, Scaled(6))
	rank:SetSortItems(false)

	--[[
		THE RANK NAMES ARE THE FACTION'S OWN.

		`ix.class.GetRanks` answers what a faction actually calls its four
		steps - not every faction runs Enlisted to Lead, and a menu offering
		"Enlisted" to a faction that has no such thing is a menu that cannot be
		used. Same call the shop configurer makes, for the same reason.
	]]
	local function FillRanks()
		rank:Clear()

		if (definition.faction == ix.shop.GLOBAL) then
			rankLabel:SetText("Lowest rank (faction only)")
			rank:SetValue("Anyone")
			rank:SetEnabled(false)

			return
		end

		rankLabel:SetText("Lowest rank")
		rank:SetEnabled(true)

		--[[
			`GetRanks` answers RANK NUMBERS, not names - the rungs this faction
			actually has classes for, so what cannot be reached cannot be
			chosen. `GetRankName` is what turns one into the faction's own word
			for it. Reading the list as labels and the array index as the value
			is the mistake this comment exists to stop being made again: it
			produces a menu of "1, 2, 3" that happens to work for factions
			whose rungs start at one and silently sets the wrong rank for every
			faction whose rungs do not.
		]]
		for _, value in ipairs(ix.class.GetRanks(definition.faction)) do
			rank:AddChoice(string.format("%d - %s", value,
				ix.class.GetRankName(definition.faction, value)),
				value, value == (definition.rank or 1))
		end
	end

	FillRanks()

	rank.OnSelect = function(_, _, _, data)
		definition.rank = data
	end

	faction.OnSelect = function(_, _, _, data)
		definition.faction = data

		FillRanks()
	end

	--- Level.
	Field(self.middle, "Lowest level")

	local level = self.middle:Add("ixFONumberEntry")

	level:Dock(TOP)
	level:SetTall(Scaled(30))
	level:DockMargin(0, 0, 0, Scaled(10))
	level:SetMin(1)
	level:SetMax(100)
	level:SetSuffix("level")
	level:SetValue(definition.level or 1)
	level.OnChanged = function(_, value) definition.level = value or 1 end

	--- Blueprints.
	local blueprint = self.middle:Add("DCheckBoxLabel")

	blueprint:Dock(TOP)
	blueprint:SetTall(Scaled(20))
	blueprint:DockMargin(0, 0, 0, Scaled(2))
	blueprint:SetText("Blueprint bench - builds what you have learned")
	blueprint:SetTextColor(ix.fallout.GetPalette().text_primary)
	blueprint:SetValue(definition.blueprint and true or false)

	blueprint.OnChange = function(_, value)
		definition.blueprint = value and true or false
	end

	local blueprintHint = self.middle:Add("ixFOLabel")

	blueprintHint:Dock(TOP)
	blueprintHint:SetFont("ixLootSmall")
	blueprintHint:SetWrap(true)
	blueprintHint:SetAutoStretchVertical(true)
	blueprintHint:DockMargin(0, 0, 0, Scaled(10))
	blueprintHint:SetText("It ignores the recipe list below and offers what "
		.. "the person standing at it has learned, so two people see different "
		.. "things. Has to be a Crafting bench. BLUEPRINTS edits what each one "
		.. "costs.")

	--- Capturing.
	local capturable = self.middle:Add("DCheckBoxLabel")

	capturable:Dock(TOP)
	capturable:SetTall(Scaled(20))
	capturable:DockMargin(0, 0, 0, Scaled(4))
	capturable:SetText("Has to be captured before it can be used")
	capturable:SetTextColor(ix.fallout.GetPalette().text_primary)
	capturable:SetValue(definition.capturable and true or false)

	local captureTime = self.middle:Add("ixFONumberEntry")

	captureTime:Dock(TOP)
	captureTime:SetTall(Scaled(30))
	captureTime:DockMargin(0, 0, 0, Scaled(2))
	captureTime:SetMin(5)
	captureTime:SetMax(600)
	captureTime:SetSuffix("seconds")
	captureTime:SetValue(definition.captureTime or 30)
	captureTime:SetVisible(definition.capturable and true or false)

	captureTime.OnChanged = function(_, value)
		definition.captureTime = value or 30
	end

	local captureHint = self.middle:Add("ixFOLabel")

	captureHint:Dock(TOP)
	captureHint:SetFont("ixLootSmall")
	captureHint:SetWrap(true)
	captureHint:SetAutoStretchVertical(true)
	captureHint:DockMargin(0, 0, 0, Scaled(10))
	captureHint:SetVisible(definition.capturable and true or false)
	captureHint:SetText("Press E once for a warning, again to start, then "
		.. "stand there. Whoever holds it is told by name the moment somebody "
		.. "begins. It is held by the taker's FACTION - or by them personally "
		.. "if they are in the default faction, since 'everyone unaffiliated' "
		.. "cannot own a bench.")

	capturable.OnChange = function(_, value)
		definition.capturable = value and true or false

		captureTime:SetVisible(definition.capturable)
		captureHint:SetVisible(definition.capturable)
	end

	--- How busy the server has to be.
	Field(self.middle, "Players needed")

	local players = self.middle:Add("ixFONumberEntry")

	players:Dock(TOP)
	players:SetTall(Scaled(30))
	players:DockMargin(0, 0, 0, Scaled(2))
	players:SetMin(1)
	players:SetMax(64)
	players:SetSuffix("playing")
	players:SetValue(definition.minPlayers or 1)

	players.OnChanged = function(_, value)
		definition.minPlayers = value or 1
	end

	local playersHint = self.middle:Add("ixFOLabel")

	playersHint:Dock(TOP)
	playersHint:SetFont("ixLootSmall")
	playersHint:SetWrap(true)
	playersHint:SetAutoStretchVertical(true)
	playersHint:DockMargin(0, 0, 0, Scaled(10))
	playersHint:SetText("Loaded characters, not connections - somebody in the "
		.. "character menu does not count, and neither do bots. Below this it "
		.. "cannot be opened and will not produce, so nobody farms it alone on "
		.. "an empty server. 1 means the server just has to not be empty.")

	--- Whether it is a workspace or an output bin.
	local input = self.middle:Add("DCheckBoxLabel")

	input:Dock(TOP)
	input:SetTall(Scaled(20))
	input:DockMargin(0, 0, 0, Scaled(2))
	input:SetText("Things can be put into this bench")
	input:SetTextColor(ix.fallout.GetPalette().text_primary)
	input:SetValue(definition.allowInput ~= false)

	input.OnChange = function(_, value)
		definition.allowInput = value and true or false
	end

	local inputHint = self.middle:Add("ixFOLabel")

	inputHint:Dock(TOP)
	inputHint:SetFont("ixLootSmall")
	inputHint:SetWrap(true)
	inputHint:SetAutoStretchVertical(true)
	inputHint:DockMargin(0, 0, 0, Scaled(10))
	inputHint:SetText("Off, it is an output bin: things only come out, so it "
		.. "cannot be used as a locker. A PROCESSING bench needs this on - it "
		.. "draws its materials from its own inventory.")

	--- The queue.
	Field(self.middle, "Queue length")

	local queue = self.middle:Add("ixFONumberEntry")

	queue:Dock(TOP)
	queue:SetTall(Scaled(30))
	queue:DockMargin(0, 0, 0, Scaled(6))
	queue:SetMin(1)
	queue:SetMax(50)
	queue:SetSuffix("jobs")
	queue:SetValue(definition.queueMax or 10)
	queue.OnChanged = function(_, value) definition.queueMax = value or 10 end

	local parallel = self.middle:Add("DCheckBoxLabel")

	parallel:Dock(TOP)
	parallel:SetTall(Scaled(20))
	parallel:DockMargin(0, 0, 0, Scaled(2))
	parallel:SetText("Everything queued runs at the same time")
	parallel:SetTextColor(ix.fallout.GetPalette().text_primary)
	parallel:SetValue(definition.parallel and true or false)

	parallel.OnChange = function(_, value)
		definition.parallel = value and true or false
	end

	local parallelHint = self.middle:Add("ixFOLabel")

	parallelHint:Dock(TOP)
	parallelHint:SetFont("ixLootSmall")
	parallelHint:SetWrap(true)
	parallelHint:SetAutoStretchVertical(true)
	parallelHint:DockMargin(0, 0, 0, Scaled(10))
	parallelHint:SetText("Off, the queue is a line and one thing is made at a "
		.. "time. On, ten stimpaks take as long as one - which is a bench with "
		.. "no cost to using it, so leave it off unless that is the point.")

	--- Recipes.
	local recipeHeader = self.middle:Add("ixFOLabel")

	recipeHeader:Dock(TOP)
	recipeHeader:SetTall(Scaled(26))
	recipeHeader:SetFont("ixLootHeader")
	recipeHeader:SetText("RECIPES")

	for index, recipe in ipairs(definition.recipes) do
		local row = Row(self.middle, Scaled(34))

		row.selected = self.recipe == index

		row.PaintRow = function(_, panelWidth, tall)
			local palette = ix.fallout.GetPalette()
			local count = table.Count(ix.bench.Needed(recipe))

			draw.SimpleText(string.format("%d. %s", index,
				ix.bench.RecipeName(recipe)), "ixLootRow", Scaled(10),
				tall * 0.5, palette.text_primary, TEXT_ALIGN_LEFT,
				TEXT_ALIGN_CENTER)

			draw.SimpleText(string.format("%s, %d input(s)",
				ix.bench.FormatTime(recipe.time or 10), count),
				"ixLootSmall", panelWidth - Scaled(8), tall * 0.5,
				ColorAlpha(palette.text_primary, 150), TEXT_ALIGN_RIGHT,
				TEXT_ALIGN_CENTER)
		end

		row.DoClick = function()
			self.recipe = index

			self:BuildMiddle()
			self:BuildEditor()
		end
	end

	local add = self.middle:Add("ixFOButton")

	add:Dock(TOP)
	add:SetTall(Scaled(28))
	add:DockMargin(0, Scaled(6), 0, 0)
	add:SetText("ADD A RECIPE")
	add:SetContentAlignment(5)

	add.DoClick = function()
		self:OpenItemPicker("Make what?", function(uniqueID)
			local recipes = definition.recipes

			recipes[#recipes + 1] = ix.bench.NewRecipe(uniqueID)
			self.recipe = #recipes

			self:BuildMiddle()
			self:BuildEditor()
		end)
	end
end

--------------------------------------------------------------------------------
-- One recipe
--------------------------------------------------------------------------------

function PANEL:BuildEditor()
	self.editor:Clear()

	local definition = self.editing
	local recipe = definition and definition.recipes[self.recipe]

	if (not recipe) then
		local empty = self.editor:Add("ixFOLabel")

		empty:Dock(TOP)
		empty:SetTall(Scaled(40))
		empty:SetContentAlignment(5)
		empty:SetWrap(true)
		empty:SetFont("ixLootSmall")
		empty:SetText(definition and "Pick a recipe, or add one."
			or "Nothing open.")

		return
	end

	local header = self.editor:Add("ixFOLabel")

	header:Dock(TOP)
	header:SetTall(Scaled(26))
	header:SetFont("ixLootHeader")
	header:SetText(string.upper(ix.bench.RecipeName(recipe)))

	--- A name of its own, where the item's is not what you want to call it.
	Field(self.editor, "Name (blank uses the item's)")

	local name = self.editor:Add("ixFOTextEntry")

	name:Dock(TOP)
	name:SetTall(Scaled(26))
	name:DockMargin(0, 0, 0, Scaled(6))
	name:SetText(recipe.name or "")
	name:SetUpdateOnType(true)

	name.OnValueChange = function(_, text)
		recipe.name = text

		header:SetText(string.upper(ix.bench.RecipeName(recipe)))
	end

	--- Output.
	Field(self.editor, "Makes")

	local output = self.editor:Add("ixFOButton")

	output:Dock(TOP)
	output:SetTall(Scaled(28))
	output:DockMargin(0, 0, 0, Scaled(6))
	output:SetContentAlignment(5)

	local outputTable = ix.item.list[recipe.output]

	output:SetText(outputTable and outputTable.name
		or (recipe.output or "PICK AN ITEM"))

	output.DoClick = function()
		self:OpenItemPicker("Make what?", function(uniqueID)
			recipe.output = uniqueID

			self:BuildMiddle()
			self:BuildEditor()
		end)
	end

	local amount = self.editor:Add("ixFONumberEntry")

	amount:Dock(TOP)
	amount:SetTall(Scaled(30))
	amount:DockMargin(0, 0, 0, Scaled(6))
	amount:SetMin(1)
	amount:SetMax(99)
	amount:SetSuffix("made")
	amount:SetValue(recipe.outputAmount or 1)
	amount.OnChanged = function(_, value) recipe.outputAmount = value or 1 end

	--- Time and experience.
	Field(self.editor, "Time")

	local time = self.editor:Add("ixFONumberEntry")

	time:Dock(TOP)
	time:SetTall(Scaled(30))
	time:DockMargin(0, 0, 0, Scaled(2))
	time:SetMin(ix.bench.minTime)
	time:SetMax(ix.bench.maxTime)
	time:SetSuffix("seconds")
	time:SetValue(recipe.time or 10)

	local timeHint = self.editor:Add("ixFOLabel")

	timeHint:Dock(TOP)
	timeHint:SetTall(Scaled(18))
	timeHint:SetFont("ixLootSmall")
	timeHint:DockMargin(0, 0, 0, Scaled(6))
	timeHint:SetText(ix.bench.FormatTime(recipe.time or 10))

	time.OnChanged = function(_, value)
		recipe.time = value or 10

		timeHint:SetText(ix.bench.FormatTime(recipe.time))
	end

	Field(self.editor, "Experience")

	local xp = self.editor:Add("ixFONumberEntry")

	xp:Dock(TOP)
	xp:SetTall(Scaled(30))
	xp:DockMargin(0, 0, 0, Scaled(10))
	xp:SetMin(0)
	xp:SetMax(1000)
	xp:SetSuffix("XP")
	xp:SetValue(recipe.xp or 0)
	xp.OnChanged = function(_, value) recipe.xp = value or 0 end

	--- Inputs.
	local inputHeader = self.editor:Add("ixFOLabel")

	inputHeader:Dock(TOP)
	inputHeader:SetTall(Scaled(26))
	inputHeader:SetFont("ixLootHeader")
	inputHeader:SetText("NEEDS")

	if (definition.mode == "infinite") then
		local note = self.editor:Add("ixFOLabel")

		note:Dock(TOP)
		note:SetFont("ixLootSmall")
		note:SetWrap(true)
		note:SetAutoStretchVertical(true)
		note:DockMargin(0, 0, 0, Scaled(6))
		note:SetText("An infinite bench consumes nothing, so inputs here are "
			.. "refused on save. Clear them, or change the mode.")
	end

	recipe.input = recipe.input or {}

	for index, entry in ipairs(recipe.input) do
		local row = self.editor:Add("Panel")

		row:Dock(TOP)
		row:SetTall(Scaled(30))
		row:DockMargin(0, 0, 0, Scaled(4))

		local remove = row:Add("ixFOButton")

		remove:Dock(RIGHT)
		remove:SetWide(Scaled(30))
		remove:SetText("X")
		remove:SetContentAlignment(5)

		remove.DoClick = function()
			table.remove(recipe.input, index)

			self:BuildMiddle()
			self:BuildEditor()
		end

		local quantity = row:Add("ixFONumberEntry")

		quantity:Dock(RIGHT)
		quantity:SetWide(Scaled(90))
		quantity:DockMargin(0, 0, Scaled(4), 0)
		quantity:SetMin(1)
		quantity:SetMax(999)
		quantity:SetValue(entry.amount or 1)
		quantity.OnChanged = function(_, value) entry.amount = value or 1 end

		local label = row:Add("ixFOLabel")

		label:Dock(FILL)
		label:SetFont("ixLootSmall")
		label:SetContentAlignment(4)

		local inputTable = ix.item.list[entry.item]

		label:SetText(inputTable and inputTable.name
			or (entry.item or "?") .. " (missing)")
	end

	local addInput = self.editor:Add("ixFOButton")

	addInput:Dock(TOP)
	addInput:SetTall(Scaled(28))
	addInput:DockMargin(0, Scaled(4), 0, 0)
	addInput:SetText("ADD AN INPUT")
	addInput:SetContentAlignment(5)

	addInput.DoClick = function()
		self:OpenItemPicker("Needs what?", function(uniqueID)
			recipe.input[#recipe.input + 1] = {item = uniqueID, amount = 1}

			self:BuildMiddle()
			self:BuildEditor()
		end)
	end

	local removeRecipe = self.editor:Add("ixFOButton")

	removeRecipe:Dock(TOP)
	removeRecipe:SetTall(Scaled(28))
	removeRecipe:DockMargin(0, Scaled(10), 0, 0)
	removeRecipe:SetText("REMOVE THIS RECIPE")
	removeRecipe:SetContentAlignment(5)

	removeRecipe.DoClick = function()
		table.remove(definition.recipes, self.recipe)

		self.recipe = nil

		self:BuildMiddle()
		self:BuildEditor()
	end
end

--------------------------------------------------------------------------------
-- Pickers
--------------------------------------------------------------------------------

--[[
	Making a new kind of bench.

	The id is asked for ONCE and never again: it is the key everything else
	refers to, so a placed bench whose type was renamed would be a bench
	pointing at nothing. The name is what people see and can be changed freely.
]]
function PANEL:OpenCreate()
	Derma_StringRequest("New bench", "An id for it - lower case, no spaces. "
		.. "This cannot be changed later.", "", function(text)
			local uniqueID = string.lower(string.Trim(text or ""))

			uniqueID = string.gsub(uniqueID, "[^%w_]", "")

			if (uniqueID == "") then
				self:Say("That is not an id.")

				return
			end

			if (ix.bench.types[uniqueID]) then
				self:Say("There is already a bench called '"
					.. uniqueID .. "'.")

				return
			end

			local definition = ix.bench.NewType(uniqueID)

			definition.name = string.upper(string.sub(uniqueID, 1, 1))
				.. string.sub(uniqueID, 2)

			self.editing = definition
			self.recipe = nil

			self:Rebuild()
			self:BuildEditor()
			self:Say("Add at least one recipe, then SAVE.")

		--[[
			`Derma_StringRequest(title, text, default, fnEnter, fnCancel,
			okText, cancelText)`.

			`Derma_Query` takes its two buttons as TEXT-then-FUNCTION pairs and
			this one takes both functions first, so the shape that is right
			next door - `"Cancel", function() end` - lands the cancel TEXT in
			the cancel FUNCTION slot here, and the button text argument gets a
			function:

			    bad argument #1 to 'SetText' (string expected, got function)

			The two calls read almost identically and mean different things.
		]]
		end, function() end, "Create", "Cancel")
end

function PANEL:OpenItemPicker(title, callback)
	local frame = vgui.Create("ixFOFrame")

	frame:SetSize(Scaled(420), Scaled(520))
	frame:Center()
	frame:MakePopup()
	frame:SetTitle(string.upper(title))

	local close = frame:Add("ixFOButton")

	close:Dock(BOTTOM)
	close:SetText("CANCEL")
	close:SetContentAlignment(5)
	close.DoClick = function() frame:Remove() end

	local search = frame:Add("ixFOTextEntry")

	search:Dock(TOP)
	search:SetTall(Scaled(26))
	search:DockMargin(0, 0, 0, Scaled(6))
	search:SetUpdateOnType(true)
	search:SetPlaceholderText("Search items")

	local list = frame:Add("ixFOScrollPanel")

	list:Dock(FILL)

	local function Fill(filter)
		list:Clear()

		local sorted = {}

		for uniqueID, itemTable in pairs(ix.item.list) do
			--[[
				Bases are skipped. `base_ammo` and the rest are templates, not
				things - a recipe naming one makes an item that cannot be
				instanced.
			]]
			if (string.StartWith(uniqueID, "base_")) then continue end

			if (filter ~= "" and not string.find(
			string.lower(itemTable.name or ""), filter, 1, true)
			and not string.find(uniqueID, filter, 1, true)) then
				continue
			end

			sorted[#sorted + 1] = {id = uniqueID, name = itemTable.name,
				category = itemTable.category}
		end

		table.sort(sorted, function(a, b)
			return (a.name or a.id) < (b.name or b.id)
		end)

		for index, item in ipairs(sorted) do
			if (index > 200) then
				local more = list:Add("ixFOLabel")

				more:Dock(TOP)
				more:SetTall(Scaled(22))
				more:SetContentAlignment(5)
				more:SetFont("ixLootSmall")
				more:SetText(string.format("%d more - narrow the search",
					#sorted - 200))

				break
			end

			local row = Row(list, Scaled(24))

			row.PaintRow = function(_, width, tall)
				local palette = ix.fallout.GetPalette()

				draw.SimpleText(item.name or item.id, "ixLootRow", Scaled(10),
					tall * 0.5, palette.text_primary, TEXT_ALIGN_LEFT,
					TEXT_ALIGN_CENTER)

				draw.SimpleText(item.category or "", "ixLootSmall",
					width - Scaled(8), tall * 0.5,
					ColorAlpha(palette.color_primary, 180), TEXT_ALIGN_RIGHT,
					TEXT_ALIGN_CENTER)
			end

			row.DoClick = function()
				callback(item.id)
				frame:Remove()
			end
		end
	end

	search.OnValueChange = function(_, text)
		Fill(string.lower(string.Trim(text or "")))
	end

	Fill("")
end

--------------------------------------------------------------------------------
-- Saving
--------------------------------------------------------------------------------

function PANEL:Commit()
	if (not self.editing) then
		self:Say("Nothing open.")

		return
	end

	--[[
		Checked HERE as well as on the server, so the reason appears in the
		window instead of as a notification over the top of it. The server
		checks again on arrival; this is a courtesy, not the guard.
	]]
	local ok, reason = ix.bench.Validate(self.editing)

	if (not ok) then
		self:Say(reason)

		return
	end

	net.Start("ixBenchConfigSet")
		net.WriteTable(self.editing)
	net.SendToServer()

	self:Say("Saved " .. self.editing.name .. ".")
end

function PANEL:OnRemove()
	if (ix.gui.benchConfig == self) then
		ix.gui.benchConfig = nil
	end
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Remove()
	end
end

vgui.Register("ixFOBenchConfig", PANEL, "ixFOFrame")
