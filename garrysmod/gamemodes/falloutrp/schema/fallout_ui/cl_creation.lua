--[[
	Fallout UI - character creation.

	Helix's creation flow is three subpanels that slide horizontally: faction,
	description, attributes. Each is full-width, with a model panel docked to
	one side and the controls to the other.

	Phoenix's is a row of compact frames that appear left to right as you commit
	to each step - a narrow faction list, then an info board naming the faction
	with its artwork and blurb, then (once races exist) a race column:

	    self.factions:SetPos(ScrW() * 0.1, ScrH() - (ScrH() * 0.2 + sH() * 0.45) - 24)
	    self.factions:SetSize(256, (sH() * 0.45) + 24)
	    self.info:SetPos(fX + self.factions:GetWide() + 12, fY)
	    self.info:SetSize(536, (sH() * 0.45) + 24)

	WHAT THIS FILE DOES, AND WHAT IT DELIBERATELY DOESN'T
	----------------------------------------------------
	It restyles Helix's flow into that column layout. It does NOT replace the
	flow, because the parts that are not visual are worth keeping: the payload
	hooks, `VerifyProgression` running each character var's `OnValidate`, the
	whitelist filter on the faction list, and `SendPayload`. Phoenix's
	equivalents are in `sv_*.lua` files that the scrapes never captured, so
	replacing the flow would mean rewriting all of that blind.

	So the subpanels, the slide animation and the progress bar all stay. What
	changes is the size and arrangement of what sits inside them, plus a faction
	info board that Helix has no equivalent of at all - stock Helix never shows
	`FACTION.description` anywhere in creation.
]]

ix.fallout = ix.fallout or {}

--[[
	The same patch helpers `cl_panels.lua` uses, and for the same reason: call
	Helix's original first, then ours. See that file's header on why replacing a
	Helix panel method wholesale is how features disappear without an error.
]]
local Wrap = ix.fallout.WrapPanel
local Replace = ix.fallout.ReplacePanel

local function Scaled(value)
	return math.Round(value * ix.fallout.GetFontScale())
end

--[[
	The band the creation columns occupy.

	Phoenix anchors to `ScrH() - (ScrH() * 0.2 + sH() * 0.45)`, i.e. a block
	45% of the screen tall sitting 20% up from the bottom. Matched here, but
	CENTRED horizontally rather than pinned to `ScrW() * 0.1`: the number of
	columns changes between steps (and again when races land), and a left pin
	makes the group appear to drift sideways as you move through the flow.
]]
local cvarBandHeight = CreateClientConVar("fo_create_height", "0.45", false, false,
	"Height of the character creation columns, as a fraction of the screen.")

local cvarBandBottom = CreateClientConVar("fo_create_bottom", "0.2", false, false,
	"Gap below the creation columns, as a fraction of the screen.")

--[[
	Total width of the columns.

	Phoenix's faction step is a 256px list, a 12px gap and a 536px info board.
	That is what the band is built from - scaled, so it holds at any resolution -
	rather than a fraction of the screen: a fraction that looks right at 1080p is
	half again too wide at 1440p, which is exactly what the first attempt did
	(0.62 of a 2560px screen is 1587px against Phoenix's ~1072).

	The convar is a MULTIPLIER on that, so 1.0 is Phoenix's proportions and
	anything else is a deliberate departure from them.
]]
local PHOENIX_COLUMN = 256
local PHOENIX_BOARD = 536

local cvarBandScale = CreateClientConVar("fo_create_width", "1.0", false, false,
	"Width of the creation columns, as a multiple of Phoenix's own.")

--[[
	Is this panel of a given scripted class?

	NOT via `GetClassName()`, which returns the engine class - "Panel",
	"EditablePanel", "LuaEditablePanel" - and never the `vgui.Register` name.

	Not really via `ClassName` either. GMod's `derma.DefineControl` puts the
	registered name on a `.Derma` SUB-TABLE, and the panels searched for here
	are registered with plain `vgui.Register`, so whether an instance carries a
	usable `ClassName` at all is engine behaviour that cannot be confirmed from
	the Lua on disk.

	So the panels are MARKED instead, in the Init wraps this file already
	applies to every instance of them. A flag we set ourselves is not a guess.
	The name checks stay as a fallback for anything built before its wrap ran.

	This mattered: searching by class name silently found nothing, which cost
	the faction step its proceed button and left the SPECIAL rows alphabetical
	through three separate attempts at reordering them.
]]
local function IsClass(panel, class, marker)
	if (not IsValid(panel)) then return false end

	if (marker and panel[marker]) then return true end

	return panel.ClassName == class or panel:GetName() == class
end

--- The gap between columns. Phoenix uses a flat 12px; scaled so it holds at 4K.
local function Gap()
	return Scaled(12)
end

--------------------------------------------------------------------------------
-- SPECIAL allocation rows
--------------------------------------------------------------------------------

--[[
	`ixAttributeBar` is Helix's attribute widget, and SPECIAL rides on Helix
	attributes (see `libs/sh_special.lua`, which prunes the list to the seven),
	so this is the panel the creation screen uses to spend SPECIAL points.

	Init is WRAPPED, never replaced: it builds the +/- buttons, wires their
	press-and-hold repeat through `Think`, and sets up the value animation. Only
	the drawing is swapped afterwards, onto `ix.fallout.DrawSpecialRow` - the
	same renderer the F1 tab uses, so the two cannot drift apart.
]]
Wrap("ixAttributeBar", "Init", function(panel)
	ix.fallout.CreateTrace("attributeBar: init")

	-- Our own marker, so finding these never depends on how the engine names
	-- a scripted panel. See IsClass.
	panel.ixIsAttributeBar = true
	panel:SetTall(ix.fallout.GetSpecialRowHeight())

	--[[
		The row box is drawn on the PANEL, so it spans the buttons too - in
		Phoenix the action sits inside the row's border, not beside it. The
		bar and its label are Helix's own drawing and are cleared out rather
		than removed, since `SetText` and the value animation still write to
		them.
	]]
	if (IsValid(panel.bar)) then
		panel.bar.Paint = function() end
	end

	if (IsValid(panel.label)) then
		panel.label:SetVisible(false)
	end

	--[[
		Both buttons move to the RIGHT so they read as one action cluster.

		The z-order is explicit because docking processes children in ascending
		z and the FIRST one processed lands outermost - so without this, `sub`
		(created first) would end up to the right of `add` and the pair would
		read "+ -".
	]]
	local size = Scaled(22)

	for button, sign in pairs({[panel.add] = "+", [panel.sub] = "-"}) do
		if (IsValid(button)) then
			button:SetSize(size, size)
			button:Dock(RIGHT)
			button:DockMargin(Scaled(4), Scaled(10), Scaled(4), Scaled(10))
			button:SetZPos(sign == "+" and 1 or 2)

			--[[
				`DImageButton` is a DButton holding a CHILD `DImage`, so
				overriding the button's Paint leaves the icon drawing merrily on
				top - which is why Helix's icon16 add/delete circles survived
				the first attempt at this. `SetImageVisible` is the real switch.

				Do NOT reach for `SetImage("")` instead: that lands in
				`Material("")`, which returns nil, and DImage indexes it
				unconditionally.
			]]
			button:SetImageVisible(false)

			button.Paint = function(this, w, h)
				local palette = ix.fallout.GetPalette()
				local disabled = this:GetDisabled()
				local color = disabled and palette.text_disabled
					or (this.Hovered and palette.color_background or palette.color_primary)

				draw.NoTexture()

				if (this.Hovered and not disabled) then
					surface.SetDrawColor(palette.color_primary)
					surface.DrawRect(0, 0, w, h)
				end

				surface.SetDrawColor(disabled and palette.text_disabled or palette.color_primary)
				surface.DrawOutlinedRect(0, 0, w, h)

				draw.SimpleText(sign, "UI_Bold", w * 0.5, h * 0.5, color,
					TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		end
	end
end)

--[[
	The row itself.

	Replaced rather than wrapped: `ixAttributeBar` does not define Paint at all,
	so the original here is DPanel's background fill and nothing else.
]]
Replace("ixAttributeBar", "Paint", function(panel, width, height)
	local name = panel.ixAttributeName or ""

	--[[
		The list is not all SPECIAL. Helix adds a points-remaining bar with
		`SetText(L("attribPointsLeft"))` and a green `SetColor`, which would
		otherwise be given a meaningless "P" initial next to Perception's - so
		the initial is drawn only for names in `ix.special.isSpecial`, and the
		bar's own colour drives the value so the budget row stays green.
	]]
	local isSpecial = ix.special and ix.special.isSpecial[name:lower()]

	ix.fallout.DrawSpecialRow(0, 0, width, height, {
		letter = isSpecial and name:sub(1, 1):upper() or nil,
		name = name,
		value = math.Round(panel.value or 0),
		valueColor = panel.color
	})
end)

--[[
	Helix sets the bar's text to the attribute name, and that is the only place
	the name is available to us - so it is captured here for the initial cell.
]]
Wrap("ixAttributeBar", "SetText", function(panel, text)
	ix.fallout.CreateTrace("attributeBar: text = " .. tostring(text))
	panel.ixAttributeName = tostring(text or "")
end)

--------------------------------------------------------------------------------
-- The creation panel
--------------------------------------------------------------------------------

--[[
	Faction info board.

	New - stock Helix shows `FACTION.description` nowhere in creation, so the
	only thing distinguishing one faction from another is its name and model.
	Phoenix devotes the middle column to it: artwork on top, blurb below, and
	the commit button at the bottom.

	`FACTION.image` is honoured if a faction sets one. None currently do, and
	rather than shipping a broken-image box, the slot falls back to the faction
	model - which is the thing you actually want to see anyway, and is why the
	model panel is reparented into this board rather than kept as its own
	column.
]]
local function BuildInfoBoard(panel, parent, modelPanel, proceed)
	local board = parent:Add("ixFOPanelBracketed")
	board:Dock(FILL)
	board:DockMargin(Gap(), 0, 0, 0)
	board:DockPadding(Scaled(10), Scaled(10), Scaled(10), Scaled(10))

	local title = board:Add("DLabel")
	title:Dock(TOP)
	title:SetFont("UI_Bold")
	title:SetTextColor(ix.fallout.GetPalette().color_primary)
	title:SetContentAlignment(5)
	title:SetTall(Scaled(24))
	title:SetText("")

	--[[
		The commit button sits at the bottom, so it docks before the filler.

		Created here if Helix's could not be found rather than left absent: the
		faction step is a dead end without it - you can select a faction and
		have no way forward - and one missing button should not be able to trap
		a player on the first screen.
	]]
	if (not IsValid(proceed)) then
		proceed = board:Add("ixMenuButton")
		panel.ixFactionProceed = proceed
	else
		proceed:SetParent(board)
	end

	proceed:Dock(BOTTOM)
	proceed:DockMargin(0, Scaled(6), 0, 0)
	proceed:SetContentAlignment(5)
	proceed:SetText("CHOOSE FACTION")
	proceed:SizeToContents()

	local description = board:Add("DLabel")
	description:Dock(BOTTOM)
	description:SetFont("UI_Regular")
	description:SetTextColor(ix.fallout.GetPalette().text_primary)
	description:SetContentAlignment(7)
	description:SetWrap(true)
	description:SetAutoStretchVertical(true)
	description:SetTall(Scaled(64))
	description:DockMargin(0, Scaled(6), 0, 0)
	description:SetText("")

	if (IsValid(modelPanel)) then
		modelPanel:SetParent(board)
		modelPanel:Dock(FILL)
	end

	panel.ixInfoTitle = title
	panel.ixInfoDescription = description
	panel.ixInfoBoard = board

	return board
end

--- Fill the info board in from whichever faction is currently selected.
local function RefreshInfoBoard(panel)
	if (not IsValid(panel.ixInfoTitle)) then return end

	local faction = ix.faction.indices[panel.payload and panel.payload.faction or -1]

	if (not faction) then
		panel.ixInfoTitle:SetText("")
		panel.ixInfoDescription:SetText("")
		return
	end

	panel.ixInfoTitle:SetText(L(faction.name):utf8upper())
	panel.ixInfoTitle:SetTextColor(faction.color or ix.fallout.GetPalette().color_primary)

	-- Re-applied rather than set once at build time, so switching palette
	-- with fo_theme repaints the board instead of leaving it on the old accent.
	panel.ixInfoDescription:SetTextColor(ix.fallout.GetPalette().text_primary)

	--[[
		`FACTION.description` is not translated by Helix anywhere else, so it
		goes through L() the same way the name does - a schema that ships
		language files gets it for free, and a plain string passes through.
	]]
	panel.ixInfoDescription:SetText(faction.description
		and L(faction.description)
		or "This faction has no description.")
end

--[[
	Restructure the three subpanels into columns.

	Everything here re-docks panels Helix has already created rather than
	creating a parallel set, so Helix's own references (`self.factionModel`,
	`self.descriptionPanel`, the payload hooks that write into them) all keep
	pointing at live panels.
]]
--[[
	Wrap a list and the step's back button into one bracketed column.

	Phoenix's RETURN sits at the bottom of the FACTIONS frame, not across the
	whole screen. Helix docks it BOTTOM on the subpanel, so it spans the full
	band - reparenting it into the column is what makes the step read as
	Phoenix's stack of frames rather than one wide page.
]]
local function BuildColumn(parent, content, footer, width)
	local column = parent:Add("ixFOPanelBracketed")
	column:Dock(LEFT)
	column:SetWide(width)
	column:DockPadding(Scaled(8), Scaled(8), Scaled(8), Scaled(8))

	if (IsValid(footer)) then
		footer:SetParent(column)
		footer:Dock(BOTTOM)
		footer:DockMargin(0, Scaled(6), 0, 0)
		footer:SetContentAlignment(5)
	end

	if (IsValid(content)) then
		content:SetParent(column)
		content:Dock(FILL)

		--[[
			The column already draws the background and brackets. The list
			class paints those itself (see cl_panels.lua), so nesting it here
			unchanged would double every rule - hence the per-INSTANCE clear,
			which leaves the same class alone in the main menu and load screen.
		]]
		content.Paint = function() end
	end

	return column
end

--[[
	Make a creation model panel compose its body.

	The faction model is `models/phoenix/humans/animations.mdl`, which has no
	visible mesh - so all three creation model panels render nothing at all,
	which is why the description step looked like it had a large empty box
	where the character should be. Same cause as the character select preview,
	same fix: bone-merge the body and head onto the animation skeleton.

	Helix drives these through `SetModel` from its `model` payload hook, so the
	interception goes there rather than at a call site.

--[[
	How much closer creation frames the body than character select does.

	The creation column is narrower and taller than the select screen's slot, so
	the distance tuned there leaves the model small and marooned. This is a
	multiplier on `ix.fallout.SetPreviewModel`'s framing, applied per panel.
]]
local cvarModelZoom = CreateClientConVar("fo_create_modelzoom", "2.0", false, false,
	"How much closer the creation screen frames the body than character select.")

--[[
	Kill switch for the appearance step.

	`fo_create_appearance 0` builds the creation flow exactly as it was before
	races landed - faction, description, attributes - with no fourth subpanel,
	no customiser and no composed preview.

	It exists so a crash in this step can be localised in ONE run instead of a
	round of guesses: if turning it off makes the crash go away, it is in here;
	if it does not, it is not. Read at panel construction, so it takes effect
	when the character menu is next opened.
]]
local cvarAppearance = CreateClientConVar("fo_create_appearance", "1", false, false,
	"Include the appearance step in character creation. 0 disables it.")

--[[
	Make a creation model panel compose its body.

	The faction model is `models/phoenix/humans/animations.mdl`, which has no
	visible mesh - so all three creation model panels render nothing at all,
	which is why the description step looked like it had a large empty box where
	the character should be. Same cause as the character select preview, same
	fix: bone-merge the body and head onto the animation skeleton.

	Helix drives these through `SetModel` from its `model` payload hook, so the
	interception goes there rather than at a call site.

	`ixComposing` guards re-entry: `ix.fallout.SetPreviewModel` sets the panel's
	model itself, which would otherwise land straight back in this override.
]]
--[[
	Kill switch for composing bodies on the CREATION panels.

	Separate from `fo_create_appearance` because they fail differently. The
	appearance switch removes a whole subpanel; this one leaves the flow intact
	and only stops the three creation model panels bone-merging a body onto the
	animation skeleton - which is the heaviest new thing that happens inside
	Helix's Populate, and therefore the first suspect for a crash located there.

	With it off the model panels render the meshless animation model, i.e.
	nothing - visually the same as before races landed.
]]
local cvarCompose = CreateClientConVar("fo_create_compose", "1", false, false,
	"Compose bodies on the character creation model panels. 0 disables it.")

local function ComposeModelPanel(modelPanel)
	if (not cvarCompose:GetBool()) then return end
	if (not IsValid(modelPanel) or modelPanel.ixComposePatched) then return end

	modelPanel.ixComposePatched = true
	ix.fallout.CreateTrace("compose: patched " .. tostring(modelPanel))

	-- Passed as a function, not a value: FramePreview calls it every layout
	-- pass, so the convar re-frames the model live instead of being captured
	-- once here and needing a menu reopen to take effect.
	modelPanel.ixZoom = function()
		return cvarModelZoom:GetFloat()
	end

	local baseSetModel = modelPanel.SetModel

	modelPanel.SetModel = function(this, model, skin, groups)
		ix.fallout.CreateTrace("compose: SetModel " .. tostring(model)
			.. (this.ixComposing and " [reentrant]" or ""))
		if (this.ixComposing) then
			return baseSetModel(this, model, skin, groups)
		end

		this.ixComposing = true
		ix.fallout.SetPreviewModel(this, model, skin, groups)
		this.ixComposing = false
	end
end

--- The first ixMenuButton among a panel's children, or nil.
local function FindMenuButton(parent)
	for _, child in ipairs(parent:GetChildren()) do
		if (IsClass(child, "ixMenuButton", "ixIsMenuButton")) then
			return child
		end
	end
end

--[[
	The appearance step.

	Added as a fourth subpanel and spliced into the flow between description and
	attributes, which is where Phoenix puts it - you pick a faction, then who
	you are, then what you are made of, then your SPECIAL.

	The two buttons that cross this seam are Helix's own, so their `DoClick` is
	WRAPPED rather than replaced: `descriptionProceed` runs
	`VerifyProgression("description")` and refuses to advance on a bad name, and
	losing that to a re-route would turn a validation message into a silently
	skipped check.
]]
local function BuildAppearanceStep(panel)
	ix.fallout.CreateTrace("appearance: entered")
	if (not cvarAppearance:GetBool()) then return end
	if (not ix.races or table.IsEmpty(ix.races.list)) then return end

	local step = panel:AddSubpanel("appearance")

	step:SetTitle("chooseAppearance")

	--[[
		Helix's own title lookup runs the name through `L()`, which falls back
		to the key when a schema ships no language file. "chooseAppearance" is
		not a phrase, so it is set explicitly here.
	]]
	if (IsValid(step.title)) then
		step.title:SetText("DEFINE YOUR APPEARANCE")
		step.title:SizeToContents()
	end

	-- Model column, matching the other steps.
	local modelColumn = step:Add("ixFOPanelBracketed")
	modelColumn:Dock(LEFT)
	modelColumn:SetWide(Scaled(300))
	modelColumn:DockPadding(Scaled(8), Scaled(8), Scaled(8), Scaled(8))

	local back = modelColumn:Add("ixMenuButton")

	panel.ixAppearanceBack = back
	back:SetText("return")
	back:Dock(BOTTOM)
	back:SetContentAlignment(5)
	back:SizeToContents()
	-- Navigation lives in RouteAppearanceStep, so the two seams either side
	-- of this step are decided in one place rather than half here.

	local model = modelColumn:Add("ixModelPanel")
	model:Dock(FILL)
	model:SetModel(ix.fallout.animationModel)
	model:SetFOV((ScrW() > ScrH() * 1.8) and 92 or 70)
	model.PaintModel = model.Paint

	ComposeModelPanel(model)

	local customizer = step:Add("ixFOCustomizer")
	customizer:Dock(FILL)
	customizer:DockMargin(Gap(), 0, 0, 0)
	customizer:DockPadding(Scaled(10), Scaled(10), Scaled(10), Scaled(10))

	local proceed = customizer:Add("ixMenuButton")

	panel.ixAppearanceProceed = proceed
	proceed:SetText("proceed")
	proceed:Dock(BOTTOM)
	proceed:SetContentAlignment(5)
	proceed:SizeToContents()
	-- Destination set in RouteAppearanceStep, as above.

	--[[
		Every screen in the flow shows the character, so every one of them is
		registered - not just this step's own preview. Otherwise choosing female
		here still leaves a male body on description and attributes.
	]]
	customizer:AddPreview(model)
	customizer:AddPreview(panel.factionModel)
	customizer:AddPreview(panel.descriptionModel)
	customizer:AddPreview(panel.attributesModel)
	ix.fallout.CreateTrace("appearance: preview attached")

	--[[
		Sit BEFORE attributes in the slide order.

		`AddSubpanel` only appends, and the array order is what the slide
		animation traverses - so left as added, moving from description to
		appearance would visibly sweep PAST the attributes step and back.

		THE LINKS MUST BE CLEARED FIRST. `SetupSubpanelReferences` only ever
		SETS left/right, never clears them, and its `if (IsValid(nextPanel))`
		guard means the LAST panel's `right` is left exactly as it was:

		    if (IsValid(nextPanel)) then
		        panel:SetRightPanel(nextPanel)
		    end

		So after `AddSubpanel` had ordered them [faction, description,
		attributes, appearance] and set `attributes.right = appearance`,
		reordering to [faction, description, appearance, attributes] set
		`appearance.right = attributes` - and `attributes.right` still pointed
		at appearance. A cycle.

		`SetSubpanelPos` then walks that chain with `while (IsValid(current))`
		and never terminates. The client HANGS - no Lua error, no console
		output, nothing traced; the server just reports the player timed out,
		which reads like a crash and is why this took several passes to find.
	]]
	local subpanels = panel.subpanels

	table.remove(subpanels)
	table.insert(subpanels, 2, step)

	for i = 1, #subpanels do
		subpanels[i]:SetLeftPanel(nil)
		subpanels[i]:SetRightPanel(nil)
		subpanels[i].subpanelID = i
	end

	panel:SetupSubpanelReferences()

	--[[
		Every route into this step goes through OnSetActive - forward from
		description, back from attributes - so the payload is handed over here
		rather than at each call site.
	]]
	step.OnSetActive = function()
		customizer:SetPayload(panel.payload)
	end

	panel.appearance = step
	panel.appearancePanel = customizer
	panel.appearanceModel = model
end

--[[
	Keep the bar on whichever step is actually showing.

	Counting Increment/Decrement calls does not survive this flow: the
	one-faction skip jumps a step without incrementing, the appearance return
	delegates to Helix's own handler which decrements on its own, and Helix's
	description proceed can skip attributes entirely. Any of those leaves the
	bar off by one.

	So progress is DERIVED from the active subpanel instead. `SetActiveSubpanel`
	calls `OnSetActive` last, after the buttons have already done their
	incrementing, so this runs afterwards and wins - the increments become
	harmless.
]]
local function SyncProgress(panel)
	for _, subpanel in ipairs({panel.factionPanel, panel.appearance,
	panel.description, panel.attributes}) do
		if (IsValid(subpanel)) then
			local base = subpanel.OnSetActive

			subpanel.OnSetActive = function(this, ...)
				--[[
					The faction step's own handler may divert to another
					subpanel, whose OnSetActive then sets the correct index - so
					it runs FIRST and this only fills in when nothing diverted.
				]]
				if (base) then
					base(this, ...)
				end

				local index = panel.ixProgressIndex
					and panel.ixProgressIndex[this.subpanelName]

				if (index and IsValid(panel.progress)) then
					panel.progress:SetProgress(index)
				end
			end
		end
	end
end

--[[
	Wire appearance in as the step straight after faction.

	    faction -> appearance -> description -> attributes

	Appearance comes first because it is the part of a character you actually
	decide first: who they look like, then what they are called, then what they
	are good at. It also means the model shown on every later screen is already
	the one you chose.

	The buttons either side of each seam are Helix's own. Where the change is
	only a DESTINATION, the handler is rebuilt rather than wrapped - wrapping
	would run Helix's navigation and then immediately navigate somewhere else,
	which animates the slide twice. Each rebuilt handler reproduces Helix's own
	body exactly, with the target changed; they are three lines each and quoted
	in the comments so the copy can be checked against the original.
]]
local function RouteAppearanceStep(panel)
	if (not IsValid(panel.appearance)) then return end

	--[[
		Faction -> appearance. Helix's is:

		    self.progress:IncrementProgress()
		    self:Populate()
		    self:SetActiveSubpanel("description")
	]]
	local factionProceed = panel.ixFactionProceed

	if (IsValid(factionProceed)) then
		factionProceed.DoClick = function()
			panel.progress:IncrementProgress()
			panel:Populate()
			panel:SetActiveSubpanel("appearance")
		end
	end

	--[[
		With a single whitelisted faction Helix skips the faction step entirely,
		and it skipped it TO description. That has to follow the reorder too, or
		a one-faction server never sees the appearance step at all.
	]]
	if (IsValid(panel.factionPanel)) then
		panel.factionPanel.OnSetActive = function()
			if (#panel.factionButtons == 1) then
				panel:SetActiveSubpanel("appearance", 0)
			end
		end
	end

	--[[
		Appearance -> description, and back to faction.

		The back button reproduces Helix's own faction-step return when there is
		only one faction to go back to: decrement, reset to the faction panel,
		slide the whole creation panel down and undim the main menu.
	]]
	if (IsValid(panel.ixAppearanceBack)) then
		panel.ixAppearanceBack.DoClick = function()
			--[[
				Delegated, NOT decremented first. Helix's faction-step return
				already decrements, so doing it here as well would take the
				progress bar back two steps for one click.
			]]
			if (#panel.factionButtons == 1 and IsValid(panel.ixFactionBack)) then
				panel.ixFactionBack:DoClick()
			else
				panel.progress:DecrementProgress()
				panel:SetActiveSubpanel("faction")
			end
		end
	end

	if (IsValid(panel.ixAppearanceProceed)) then
		panel.ixAppearanceProceed.DoClick = function()
			panel.progress:IncrementProgress()
			panel:SetActiveSubpanel("description")
		end
	end

	--[[
		Description -> attributes is already Helix's own behaviour, so its
		proceed button is left completely alone: it runs
		`VerifyProgression("description")` and refuses to advance on a bad name,
		and it decides on its own whether the attributes step is worth showing.

		Only the RETURN changes, from faction to appearance.
	]]
	local descriptionBack = FindMenuButton(IsValid(panel.descriptionModel)
		and panel.descriptionModel:GetParent())

	if (IsValid(descriptionBack)) then
		descriptionBack.DoClick = function()
			panel.progress:DecrementProgress()
			panel:SetActiveSubpanel("appearance")
		end
	end
end

Wrap("ixCharMenuNew", "Init", function(panel)
	ix.fallout.CreateTrace("Init: start")
	for _, model in ipairs({panel.factionModel, panel.descriptionModel, panel.attributesModel}) do
		ComposeModelPanel(model)
	end

	--[[
		FACTION STEP: [ faction list + RETURN ][ info board: model, blurb, PICK ]

		Helix docks the model's container RIGHT at half the panel width and the
		button list FILL, with the back button spanning the bottom. All three
		are rehoused into two columns.
	]]
	local factionBack = FindMenuButton(panel.factionPanel)

	-- Routing needs both of these later, and BuildColumn is about to reparent
	-- the back button into the faction column where FindMenuButton won't see it.
	panel.ixFactionBack = factionBack

	if (IsValid(panel.factionButtonsPanel)) then
		BuildColumn(panel.factionPanel, panel.factionButtonsPanel, factionBack,
			Scaled(PHOENIX_COLUMN))
	end

	local modelList = IsValid(panel.factionModel) and panel.factionModel:GetParent()

	if (IsValid(modelList)) then
		--[[
			The model's old container also held the proceed button. Both move
			onto the info board, leaving it empty - so it is removed rather than
			left as an invisible docked panel still eating width.
		]]
		panel.ixFactionProceed = FindMenuButton(modelList)

		BuildInfoBoard(panel, panel.factionPanel, panel.factionModel,
			panel.ixFactionProceed)
		modelList:Remove()
	end

	--[[
		DESCRIPTION AND ATTRIBUTES STEPS: [ model + RETURN ][ fields + PROCEED ]

		Same shape, one column narrower. Helix already docks these LEFT and
		RIGHT; they need Phoenix's proportions and the bracketed treatment.
	]]
	for _, entry in ipairs({
		{model = panel.descriptionModel, content = panel.descriptionPanel},
		{model = panel.attributesModel, content = panel.attributesPanel}
	}) do
		local container = IsValid(entry.model) and entry.model:GetParent()

		if (IsValid(container)) then
			container:Dock(LEFT)
			container:SetWide(Scaled(300))
			container.Paint = ix.fallout.PaintContainer
			container:DockPadding(Scaled(8), Scaled(8), Scaled(8), Scaled(8))
		end

		if (IsValid(entry.content)) then
			entry.content:Dock(FILL)
			entry.content:DockMargin(Gap(), 0, 0, 0)
			entry.content:DockPadding(Scaled(10), Scaled(10), Scaled(10), Scaled(10))
			entry.content.Paint = ix.fallout.PaintContainer
		end
	end

	--[[
		The progress bar is positioned once in Helix's Init against the parent
		size at that moment. It is re-placed in PerformLayout instead, directly
		below the band rather than at the very bottom of the screen.
	]]
	if (IsValid(panel.progress)) then
		panel.progress:SetBarColor(ix.fallout.GetPalette().color_primary)
	end

	BuildAppearanceStep(panel)
	ix.fallout.CreateTrace("Init: appearance step built")
	RouteAppearanceStep(panel)
	SyncProgress(panel)
	ix.fallout.CreateTrace("Init: routed")
end)

--[[
	Size the columns into the band.

	`ixSubpanel` sizes itself to the whole parent minus padding, and that is
	load-bearing - it is the unit the slide animation moves. So the band is
	produced with DOCK PADDING on the subpanel rather than by resizing it: the
	subpanel stays full-size and invisible, and its children are inset to
	Phoenix's block.

	Doing it in PerformLayout rather than Init is what makes it survive a
	resolution change, and lets the convars above take effect live.
]]
Wrap("ixCharMenuNew", "PerformLayout", function(panel, width, height)
	local bandHeight = math.Clamp(cvarBandHeight:GetFloat(), 0.2, 0.9)
	local bandBottom = math.Clamp(cvarBandBottom:GetFloat(), 0, 0.5)
	local bandScale = math.Clamp(cvarBandScale:GetFloat(), 0.4, 2)

	local columnHeight = math.Round(height * bandHeight)
	local columnWidth = math.min(
		math.Round(Scaled(PHOENIX_COLUMN + 12 + PHOENIX_BOARD) * bandScale), width)

	-- Phoenix measures the gap from the BOTTOM of the screen upward.
	local top = height - math.Round(height * bandBottom) - columnHeight
	local left = math.Round((width - columnWidth) * 0.5)

	panel.ixBand = {x = left, y = top, w = columnWidth, h = columnHeight}

	--[[
		SUBPANEL COORDINATE SPACE.

		`left` and `top` are in the creation panel's space, but the insets below
		are applied to a SUBPANEL - and `ixSubpanel:Init` sizes itself to
		`parent - padding * 2` then centres, so its origin is not `(0, 0)`.

		That origin is derived from the subpanel's own SIZE rather than read
		from `GetPadding()`: the two only agree while nothing has changed the
		padding since the subpanels were built, and it is derived from
		`Center()` regardless.

		Its live position cannot be used either - the slide animation moves
		subpanels horizontally, so `GetPos` mid-transition would bake the
		animation offset into the padding and the columns would drift.
	]]
	for _, subpanel in ipairs({panel.factionPanel, panel.description,
		panel.appearance, panel.attributes}) do
		if (IsValid(subpanel)) then
			local subWidth, subHeight = subpanel:GetSize()
			local localLeft = left - math.Round((width - subWidth) * 0.5)
			local localTop = top - math.Round((height - subHeight) * 0.5)

			--[[
				The title docks TOP inside this padding, so the top inset is
				pulled up by its height and the title then sits just above the
				columns - which is where Phoenix's frame titles are.
			]]
			local titleHeight = IsValid(subpanel.title) and subpanel.title:GetTall() or 0

			if (IsValid(subpanel.title)) then
				subpanel.title:SetFont("UI_Big")
				subpanel.title:SetTextColor(ix.fallout.GetPalette().color_primary)
				subpanel.title:SizeToContents()
			end

			subpanel:DockPadding(
				math.max(localLeft, 0),
				math.max(localTop - titleHeight, 0),
				math.max(subWidth - localLeft - columnWidth, 0),
				math.max(subHeight - localTop - columnHeight, 0)
			)
		end
	end

	-- Progress bar directly under the band, not pinned to the screen bottom.
	if (IsValid(panel.progress)) then
		panel.progress:SetWide(columnWidth)
		panel.progress:SizeToContents()
		panel.progress:SetPos(left, top + columnHeight + Scaled(16))
	end
end)

--[[
	Put the rows into SPECIAL order.

	Helix builds the list with `SortedPairsByMemberValue(ix.attributes.list,
	"name")` - alphabetical - so the seven come out A.C.E.I.L.P.S. The acronym
	is the whole point of the stat block.

	This has been wrong three times, so it now TRACES what it finds rather than
	assuming. `fo_create_trace.txt` gets the bar names it collected and the
	order it put them in; if the rows are still alphabetical on screen while the
	trace says otherwise, the fault is in the layout and not in here - and if it
	found nothing, that is the answer instead.

	Both mechanisms are applied. Docked children are laid out in z-position
	order, and in child-list order where the z-positions are equal, so setting
	the z AND re-parenting covers whichever one the engine actually honours.
]]
local function OrderSpecialRows(container)
	if (not IsValid(container)) then
		ix.fallout.CreateTrace("order: container invalid")
		return
	end

	local parent, bars
	local seenClasses = {}

	local function Collect(panel)
		for _, child in ipairs(panel:GetChildren()) do
			seenClasses[#seenClasses + 1] = tostring(child.ClassName
				or child:GetName() or "?")

			if (IsClass(child, "ixAttributeBar", "ixIsAttributeBar")) then
				parent = panel
				bars = bars or {}
				bars[#bars + 1] = child
			else
				Collect(child)
			end
		end
	end

	Collect(container)

	if (not parent or not bars) then
		ix.fallout.CreateTrace("order: NO BARS FOUND - saw "
			.. table.concat(seenClasses, ","))
		return
	end

	local function Names(list)
		local out = {}

		for i = 1, #list do
			out[i] = tostring(list[i].ixAttributeName or "?")
		end

		return table.concat(out, ",")
	end

	ix.fallout.CreateTrace("order: found " .. #bars .. " bars: " .. Names(bars))

	local ordered = {}
	local seen = {}

	-- Anything that is not one of the seven - the points-remaining bar - keeps
	-- its place at the top.
	for _, bar in ipairs(bars) do
		if (not ix.special.isSpecial[(bar.ixAttributeName or ""):lower()]) then
			ordered[#ordered + 1] = bar
			seen[bar] = true
		end
	end

	for _, key in ipairs(ix.special.order) do
		for _, bar in ipairs(bars) do
			if (not seen[bar] and (bar.ixAttributeName or ""):lower() == key) then
				ordered[#ordered + 1] = bar
				seen[bar] = true
				break
			end
		end
	end

	for _, bar in ipairs(bars) do
		if (not seen[bar]) then
			ordered[#ordered + 1] = bar
		end
	end

	for i, bar in ipairs(ordered) do
		bar:SetZPos(i)
		bar:SetParent(parent)
		bar:Dock(TOP)
	end

	parent:InvalidateLayout(true)

	ix.fallout.CreateTrace("order: applied " .. Names(ordered))
end

--[[
	Keep the info board in step with the selected faction.

	`Populate` is where Helix (re)builds the faction buttons and sets the
	initial payload, and it runs again whenever the flow returns to the faction
	step, so it is the one place guaranteed to see the current selection.

	The per-button refresh is hooked separately because selecting a different
	faction does not repopulate.
]]
--[[
	Wrap that runs BEFORE Helix's original.

	`ix.fallout.WrapPanel` deliberately calls the original first, so anything it
	adds is guaranteed to see the finished state. That is the right default -
	but it makes it useless for tracing, because a trace line placed there only
	prints once the thing being traced has already succeeded.

	`Populate` is exactly that case: it never printed, which is what localised
	the crash INSIDE Helix's Populate rather than before it.
]]
local function WrapBefore(class, method, fn)
	local tbl = vgui.GetControlTable(class)

	if (not tbl) then return end

	local original = tbl[method]

	tbl[method] = function(panel, ...)
		fn(panel, ...)

		if (original) then
			return original(panel, ...)
		end
	end
end

WrapBefore("ixCharMenuNew", "Populate", function(panel)
	ix.fallout.CreateTrace("Populate: ENTERING Helix's own Populate")
end)

Wrap("ixCharMenuNew", "Populate", function(panel)
	ix.fallout.CreateTrace("Populate: start")
	RefreshInfoBoard(panel)
	OrderSpecialRows(panel.attributesPanel)
	ix.fallout.CreateTrace("Populate: rows ordered")

	--[[
		Rebuild the progress bar's segments to match the real flow.

		Two problems with Helix's list. It only adds a faction segment when
		there is more than one faction to choose from - so a one-faction server
		shows no faction step at all, even though the flow still has one. And
		`AddSegment` only appends, so the appearance step would land last in a
		bar for a flow that runs it second.

		Rebuilt from `panel.ixSteps` instead, which is the order the flow
		actually visits. `ixProgressIndex` is the reverse lookup that keeps the
		bar in step with the active subpanel - see SyncProgress.

		Guarded by its own flag rather than Helix's `bInitialPopulate`, which is
		already true by the time this wrap runs.
	]]
	if (not panel.ixSegmentsBuilt and IsValid(panel.progress)) then
		panel.ixSegmentsBuilt = true

		local steps = {
			{name = "faction", label = "faction"},
			{name = "appearance", label = "appearance"}
		}

		-- Only real if the step exists; races failing to load removes it.
		if (not IsValid(panel.appearance)) then
			table.remove(steps, 2)
		end

		steps[#steps + 1] = {name = "description", label = "description"}

		--[[
			Helix skips the attributes step entirely when nothing registered any
			attributes, and its own segment list reflects that - so this has to
			as well, or the bar shows a step that can never be reached.
		]]
		if (#panel.attributesPanel:GetChildren() > 1) then
			steps[#steps + 1] = {name = "attributes", label = "skills"}
		end

		local segments = panel.progress:GetSegments()

		table.Empty(segments)

		panel.ixSteps = steps
		panel.ixProgressIndex = {}

		for i = 1, #steps do
			segments[i] = L(steps[i].label):utf8upper()
			panel.ixProgressIndex[steps[i].name] = i
		end

		panel.progress:SetVisible(#steps > 1)
		panel.progress:SetProgress(1)
	end

	for _, button in ipairs(panel.factionButtons or {}) do
		if (IsValid(button) and not button.ixInfoHooked) then
			button.ixInfoHooked = true

			local baseSelected = button.OnSelected

			button.OnSelected = function(this)
				if (baseSelected) then
					baseSelected(this)
				end

				ix.fallout.PlayUISound("select")
				RefreshInfoBoard(panel)
			end
		end
	end
end)

--------------------------------------------------------------------------------
-- Report
--------------------------------------------------------------------------------

--[[
	The creation flow is several screens deep behind a faction click, so a
	layout that is wrong there is expensive to look at. These are the numbers
	that decide it.
]]
concommand.Add("fo_create_report", function()
	local accent = Color(255, 199, 44)
	local plain = Color(180, 180, 180)
	local bad = Color(255, 100, 100)

	MsgC(accent, "\n[Fallout UI] Character creation\n")

	local menu = ix.gui.characterMenu
	local panel = IsValid(menu) and menu.newCharacterPanel

	if (not IsValid(panel)) then
		MsgC(bad, "  creation panel is not open - press New Character first\n\n")
		return
	end

	MsgC(plain, string.format("  %-22s %d x %d\n", "screen", ScrW(), ScrH()))

	local band = panel.ixBand

	if (band) then
		MsgC(plain, string.format("  %-22s x %d  y %d  %d x %d\n", "band",
			band.x, band.y, band.w, band.h))
		MsgC(plain, string.format("  %-22s left %d  right %d  bottom %d\n", "band margins",
			band.x, ScrW() - band.x - band.w, ScrH() - band.y - band.h))
	else
		MsgC(bad, "  band              NOT LAID OUT\n")
	end

	--[[
		The subpanel chain.

		Walked with a HARD BOUND rather than `while (IsValid(panel))`, which is
		how Helix walks it - and how a stale link once hung the client outright.
		A cycle here is not a cosmetic fault; it is an infinite loop inside a
		mouse click, so it is worth a line in the report every time.
	]]
	local subpanels = panel.subpanels or {}
	local names = {}

	for i = 1, #subpanels do
		names[#names + 1] = subpanels[i].subpanelName or "?"
	end

	MsgC(plain, string.format("  %-22s %s\n", "subpanel order", table.concat(names, " > ")))

	local seen, order, cycle = {}, {}, nil
	local current = subpanels[1]

	for _ = 1, #subpanels + 2 do
		if (not IsValid(current)) then break end

		if (seen[current]) then
			cycle = current.subpanelName or "?"
			break
		end

		seen[current] = true
		order[#order + 1] = current.subpanelName or "?"
		current = current:GetRightPanel()
	end

	if (cycle) then
		MsgC(bad, string.format("  %-22s CYCLE back to '%s' after %s\n", "chain",
			cycle, table.concat(order, " > ")))
	elseif (#order ~= #subpanels) then
		MsgC(bad, string.format("  %-22s BROKEN - %d of %d reachable (%s)\n", "chain",
			#order, #subpanels, table.concat(order, " > ")))
	else
		MsgC(plain, string.format("  %-22s ok, %d linked\n", "chain", #order))
	end
	MsgC(plain, string.format("  %-22s %s\n", "active subpanel",
		panel:GetActiveSubpanel() and panel:GetActiveSubpanel().subpanelName or "none"))

	MsgC(plain, string.format("  %-22s %d\n", "factions listed", #(panel.factionButtons or {})))

	local selected

	for _, button in ipairs(panel.factionButtons or {}) do
		if (IsValid(button) and button:GetSelected()) then
			selected = button:GetText()
		end
	end

	MsgC(selected and plain or bad, string.format("  %-22s %s\n", "faction selected",
		selected or "NONE"))

	MsgC(IsValid(panel.ixInfoBoard) and plain or bad, string.format("  %-22s %s\n",
		"info board", IsValid(panel.ixInfoBoard)
			and string.format("%d x %d", panel.ixInfoBoard:GetWide(), panel.ixInfoBoard:GetTall())
			or "MISSING"))

	MsgC(IsValid(panel.ixFactionProceed) and plain or bad,
		string.format("  %-22s %s\n", "faction proceed",
		IsValid(panel.ixFactionProceed)
			and string.format("'%s' %dx%d", panel.ixFactionProceed:GetText(),
				panel.ixFactionProceed:GetWide(), panel.ixFactionProceed:GetTall())
			or "MISSING - faction step is a dead end"))

	if (IsValid(panel.ixInfoDescription)) then
		local text = panel.ixInfoDescription:GetText() or ""

		MsgC(text ~= "" and plain or bad, string.format("  %-22s %s\n", "description",
			text ~= "" and ("\"" .. text:sub(1, 46) .. "\"") or "EMPTY"))
	end

	--[[
		Attribute rows.

		Counted RECURSIVELY. Helix's attributes character var wraps the bars in
		a plain DPanel before adding that to the container, so a direct-children
		search reports zero however many rows are on screen - and zero is also
		what a genuinely broken attributes step reports, which would make this
		line worse than useless.
	]]
	local bars = 0

	local function CountBars(parent)
		for _, child in ipairs(parent:GetChildren()) do
			if (IsClass(child, "ixAttributeBar", "ixIsAttributeBar")) then
				bars = bars + 1
			end

			CountBars(child)
		end
	end

	if (IsValid(panel.attributesPanel)) then
		CountBars(panel.attributesPanel)
	end

	MsgC(bars > 0 and plain or bad, string.format("  %-22s %d\n", "attribute rows", bars))

	MsgC(plain, string.format("  %-22s h %.2f  bottom %.2f  width x%.2f\n", "convars",
		cvarBandHeight:GetFloat(), cvarBandBottom:GetFloat(), cvarBandScale:GetFloat()))

	MsgC(accent, "\n")
end)

--[[
	Load marker. If the trace file stops before this line, THIS file threw
	partway through - which leaves everything above the throw in place and
	every patch below it silently unregistered.
]]
ix.fallout.CreateTrace("load: cl_creation.lua")
