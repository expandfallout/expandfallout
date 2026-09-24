--[[
	Fallout UI - character appearance.

	Phoenix's `nutCharCustomize`: a live preview beside a column of cycling
	pickers - gender, ethnicity, face, hair, facial hair, hair colour - each
	written straight into the creation payload.

	    self.characterData.gender = gender
	    self.characterData.skinColor = genderRaces[self.raceChoice]
	    self.characterData.hair = 0
	    self.previewModel:SetModelColor("hair", string.ToColor(...))

	Theirs is a separate popup reached from the faction screen. This is a step
	INSIDE Helix's creation flow instead, because that flow owns the payload and
	the validation, and a popup that writes into it from outside would have to
	reimplement both.

	WHAT IS OFFERED IS WHAT IS INSTALLED
	------------------------------------
	Every picker is built from `ix.races`, which drops models the server does
	not have. So the beard picker simply does not appear while that content is
	missing, rather than offering fourteen options that all render as errors.
	`fo_races_report` says what was dropped and why.
]]

ix.fallout = ix.fallout or {}

local function Scaled(value)
	return math.Round(value * ix.fallout.GetFontScale())
end

--------------------------------------------------------------------------------
-- Cycler
--------------------------------------------------------------------------------

--[[
	`< Label   value >`.

	Phoenix uses a single button whose text is "Race: caucasian" and which
	advances on click. Arrows are used here instead: with 22 female hairstyles,
	a forward-only control means clicking 21 times to see the one you passed.
]]
local PANEL = {}

function PANEL:Init()
	self.options = {}
	self.index = 1

	self.left = self:Add("DButton")
	self.left:SetText("")
	self.left:Dock(LEFT)
	self.left:SetWide(Scaled(26))
	self.left.DoClick = function()
		self:Advance(-1)
	end

	self.right = self:Add("DButton")
	self.right:SetText("")
	self.right:Dock(RIGHT)
	self.right:SetWide(Scaled(26))
	self.right.DoClick = function()
		self:Advance(1)
	end

	self.left.Paint = function(this, w, h)
		self:PaintArrow(this, w, h, "<")
	end

	self.right.Paint = function(this, w, h)
		self:PaintArrow(this, w, h, ">")
	end
end

function PANEL:PaintArrow(button, width, height, glyph)
	local palette = ix.fallout.GetPalette()
	local enabled = #self.options > 1

	draw.NoTexture()

	if (button.Hovered and enabled) then
		surface.SetDrawColor(palette.color_primary)
		surface.DrawRect(0, 0, width, height)
	end

	draw.SimpleText(glyph, "UI_Bold", width * 0.5, height * 0.5,
		enabled and (button.Hovered and palette.color_background or palette.color_primary)
			or palette.text_disabled,
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function PANEL:SetLabel(text)
	self.label = text
end

--[[
	`options` is a list of {value, text}. The VALUE is what goes in the payload
	and the TEXT is what is shown, because the payload wants `caucasian` and the
	player wants "Caucasian" - and for hair the value is an index while the text
	is a number or "None".
]]
function PANEL:SetOptions(options, selected)
	self.options = options or {}
	self.index = 1

	for i = 1, #self.options do
		if (self.options[i].value == selected) then
			self.index = i
			break
		end
	end
end

function PANEL:GetValue()
	local option = self.options[self.index]

	return option and option.value
end

function PANEL:Advance(direction)
	local count = #self.options

	if (count < 2) then return end

	-- Wraps, so the last option is one click from the first.
	self.index = ((self.index - 1 + direction) % count) + 1

	ix.fallout.PlayUISound("select")
	self:OnChanged(self:GetValue())
end

function PANEL:OnChanged(value)
end

function PANEL:Paint(width, height)
	local palette = ix.fallout.GetPalette()
	local option = self.options[self.index]

	draw.NoTexture()

	surface.SetDrawColor(0, 0, 0, 220)
	surface.DrawRect(0, 0, width, height)

	surface.SetDrawColor(palette.color_primary)
	surface.DrawOutlinedRect(0, 0, width, height)

	draw.SimpleText(self.label or "", "UI_Small", Scaled(32), height * 0.32,
		palette.color_active, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	draw.SimpleText(option and option.text or "-", "UI_Regular",
		width * 0.5, height * 0.68,
		palette.text_primary, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

vgui.Register("ixFOCycler", PANEL, "Panel")

--------------------------------------------------------------------------------
-- Customiser
--------------------------------------------------------------------------------

PANEL = {}

function PANEL:Init()
	self.cyclers = {}

	self.list = self:Add("Panel")
	self.list:Dock(FILL)
	self.list:DockMargin(Scaled(12), 0, 0, 0)
end

--[[
	The payload this customiser writes into.

	Held rather than copied, so every cycler writes to the live payload and
	`SendPayload` picks the values up with no synchronisation step.
]]
function PANEL:SetPayload(payload)
	ix.fallout.CreateTrace("customizer: SetPayload")

	self.payload = payload

	--[[
		Seed the defaults into the payload rather than only reading through
		them. The preview and the payload have to agree from the first frame,
		and a payload that reaches the server without a race would be coerced
		to one server-side - silently choosing for the player.
	]]
	local class = self:Read("race", ix.races.GetDefault())

	self:Write("race", class)

	local gender = self:Read("gender", ix.races.GetFirstGender(class))

	self:Write("gender", gender)
	self:Write("ethnicity", self:Read("ethnicity",
		ix.races.GetFirstEthnicity(class, gender)))

	self:Rebuild()
	self:Refresh()
end

--[[
	Register a model panel to be driven by this customiser.

	More than one, because every step of creation shows the character: the
	appearance step's own preview plus the faction, description and attributes
	panels. They all have to reflect the CHOICES, not a hardcoded default -
	otherwise picking female here still leaves a male body on the next screen.

	`ixPartsSource` is the hook `ix.fallout.SetPreviewModel` offers for supplying
	parts, and it reads the payload each time it is called rather than being
	handed a snapshot, so a panel registered before any choice is made is still
	correct after one.
]]
function PANEL:AddPreview(modelPanel)
	if (not IsValid(modelPanel)) then return end

	self.previews = self.previews or {}
	self.previews[#self.previews + 1] = modelPanel

	modelPanel.ixPartsSource = function()
		return self:GetParts()
	end
end

--- Recompose every registered preview after a change.
function PANEL:Refresh()
	ix.fallout.CreateTrace("customizer: Refresh")

	for _, modelPanel in ipairs(self.previews or {}) do
		if (IsValid(modelPanel)) then
			ix.fallout.SetPreviewModel(modelPanel, ix.fallout.animationModel)
		end
	end
end

--- Read a payload value, falling back to the character var's default.
function PANEL:Read(key, fallback)
	local value = self.payload and self.payload[key]

	if (value ~= nil) then return value end

	return fallback
end

function PANEL:Write(key, value)
	if (not self.payload) then return end

	--[[
		`payload:Set` rather than a raw assignment: Helix runs its payload hooks
		off Set, which is what keeps the three creation model panels in step.
	]]
	if (self.payload.Set) then
		self.payload:Set(key, value)
	else
		self.payload[key] = value
	end
end

--- The part list for the current payload, in the shape the composer wants.
function PANEL:GetParts()
	ix.fallout.CreateTrace("customizer: GetParts")
	local class = self:Read("race", ix.races.GetDefault())
	local gender = self:Read("gender", ix.races.GetFirstGender(class))
	local ethnicity = self:Read("ethnicity", ix.races.GetFirstEthnicity(class, gender))
	local parts = {}

	local body = ix.races.GetBody(class, gender)
	local skin = ix.races.GetSkin(class, gender, ethnicity)

	if (body) then
		parts[#parts + 1] = {model = body, skin = skin}
	end

	local head = ix.races.GetHead(class, gender, ethnicity)

	if (head) then
		parts[#parts + 1] = {model = head, skin = skin}
	end

	local color = string.ToColor(self:Read("hairColor", "82 56 16 255")) or color_white

	-- Per gender: this race's male and female hair textures are not equally
	-- bright, so one tint value cannot serve both. See RACE.hairBoost.
	local boost = ix.races.GetHairBoost(class, gender)

	local hairs = ix.races.GetHairs(class, gender)
	local hair = self:Read("hair", 0)

	if (hair > 0 and hairs[hair]) then
		parts[#parts + 1] = {model = hairs[hair], hair = true, color = color,
			boost = boost}
	end

	local beards = ix.races.GetBeards(class, gender)
	local beard = self:Read("beard", 0)

	if (beard > 0 and beards[beard]) then
		parts[#parts + 1] = {model = beards[beard], hair = true, color = color,
			boost = boost}
	end

	return parts
end


--- Add one cycler to the column.
function PANEL:AddCycler(label, options, selected, onChanged)
	local cycler = self.list:Add("ixFOCycler")

	cycler:Dock(TOP)
	cycler:SetTall(Scaled(40))
	cycler:DockMargin(0, 0, 0, Scaled(8))
	cycler:SetLabel(label)
	cycler:SetOptions(options, selected)
	cycler.OnChanged = onChanged

	self.cyclers[#self.cyclers + 1] = cycler

	return cycler
end

--[[
	Hair colour.

	A full picker rather than a fixed list. Phoenix stores an arbitrary
	"r g b a" string, which is what this writes, so any colour is expressible -
	`DColorMixer` is GMod's own wheel plus saturation cube and gives the whole
	range without needing a custom control.

	The alpha bar and the preset palette are turned off: alpha is meaningless
	on a tint that is multiplied into the model, and the swatch palette is a
	shortcut to colours the wheel already covers.
]]
local function AddHairColor(self, class, gender)
	if (not ix.races.CanColorHair(class, gender)) then return end

	local container = self.list:Add("Panel")

	container:Dock(TOP)
	container:SetTall(Scaled(150))
	container:DockMargin(0, 0, 0, Scaled(8))

	local label = container:Add("DLabel")

	label:Dock(TOP)
	label:SetTall(Scaled(18))
	label:SetFont("UI_Small")
	label:SetTextColor(ix.fallout.GetPalette().color_active)
	label:SetText("HAIR COLOUR")

	local mixer = container:Add("DColorMixer")

	mixer:Dock(FILL)
	mixer:SetPalette(false)
	mixer:SetAlphaBar(false)
	mixer:SetWangs(false)
	mixer:SetColor(string.ToColor(self:Read("hairColor", "82 56 16 255"))
		or Color(82, 56, 16))

	--[[
		`ValueChanged` fires continuously while the cursor is dragged, and each
		one recomposes every registered preview - four model panels, each
		rebuilding its merged parts. Refreshing on a change of VALUE rather than
		on every event keeps that to one rebuild per actual colour.
	]]
	local last

	mixer.ValueChanged = function(_, color)
		local value = string.format("%d %d %d 255", color.r, color.g, color.b)

		if (value == last) then return end

		last = value

		self:Write("hairColor", value)
		self:Refresh()
	end

	self.cyclers[#self.cyclers + 1] = container
end

--[[
	Rebuild every picker.

	Called again whenever gender or race changes, because both change what the
	other pickers may offer - a female character has 22 hairstyles and no
	beards, a male has 10 and 14. Rebuilding is simpler than reconciling, and
	this happens on a click, not per frame.
]]
function PANEL:Rebuild()
	ix.fallout.CreateTrace("customizer: Rebuild")
	if (not self.payload) then return end

	for _, cycler in ipairs(self.cyclers) do
		if (IsValid(cycler)) then
			cycler:Remove()
		end
	end

	self.cyclers = {}

	local class = self:Read("race", ix.races.GetDefault())

	if (not ix.races.Get(class)) then return end

	-- Gender.
	local gender = self:Read("gender", ix.races.GetFirstGender(class))
	local genders = {}

	for name, enabled in SortedPairs(ix.races.GetGenders(class)) do
		if (enabled) then
			genders[#genders + 1] = {
				value = name,
				text = name:sub(1, 1):upper() .. name:sub(2)
			}
		end
	end

	if (#genders > 1) then
		self:AddCycler("GENDER", genders, gender, function(_, value)
			self:Write("gender", value)

			--[[
				Hair and beard indices are per gender, so a hairstyle chosen as
				male is a different one as female - or out of range entirely.
				Reset rather than carry them across.
			]]
			self:Write("hair", 0)
			self:Write("beard", 0)

			local ethnicities = ix.races.GetEthnicities(class, value)

			self:Write("ethnicity", ethnicities[1])
			self:Rebuild()
			self:Refresh()
		end)
	end

	-- Ethnicity. Drives both the head mesh and the body's skin index.
	local ethnicity = self:Read("ethnicity", ix.races.GetFirstEthnicity(class, gender))
	local ethnicities = {}

	for _, name in ipairs(ix.races.GetEthnicities(class, gender)) do
		ethnicities[#ethnicities + 1] = {
			value = name,
			text = name:sub(1, 1):upper() .. name:sub(2)
		}
	end

	if (#ethnicities > 1) then
		self:AddCycler("APPEARANCE", ethnicities, ethnicity, function(_, value)
			self:Write("ethnicity", value)
			self:Refresh()
		end)
	end

	--[[
		Hair and beard, as indices with 0 meaning none.

		Only offered when the race actually has any for this gender: female
		beards are `false` in the data, and male beards are absent entirely
		while that content is uninstalled.
	]]
	self:AddIndexCycler("HAIR", "hair", ix.races.GetHairs(class, gender))
	self:AddIndexCycler("FACIAL HAIR", "beard", ix.races.GetBeards(class, gender))

	-- Hair colour, only where there is hair to tint.
	if (self:Read("hair", 0) > 0 or self:Read("beard", 0) > 0) then
		AddHairColor(self, class, gender)
	end
end

--- A cycler over a model list, with "None" at index 0.
function PANEL:AddIndexCycler(label, key, models)
	if (not istable(models) or #models == 0) then return end

	local options = {{value = 0, text = "None"}}

	for i = 1, #models do
		options[#options + 1] = {value = i, text = tostring(i)}
	end

	self:AddCycler(label, options, self:Read(key, 0), function(_, value)
		self:Write(key, value)

		--[[
			Going from none to some, or back, adds or removes the hair colour
			picker - so the column is rebuilt rather than just refreshed.
		]]
		self:Rebuild()
		self:Refresh()
	end)
end

function PANEL:Paint(width, height)
	ix.fallout.PaintContainer(self, width, height)
end

vgui.Register("ixFOCustomizer", PANEL, "Panel")

--[[
	Contract check.

	A panel method that goes missing produces nothing at load and an
	`attempt to call method 'X' (a nil value)` at the moment a player clicks -
	by which point the menu is a grey screen and the cause is several edits in
	the past. That is exactly how `SetPayload` disappeared: a scripted edit
	meant to replace `SetPreview` took the method above it as well.

	Checked at load instead, where it names the missing method immediately and
	`fo_ui_report` can show it. Cheap: one pass over a fixed list, once.
]]
do
	local required = {
		"SetPayload", "AddPreview", "Refresh", "Read", "Write",
		"GetParts", "AddCycler", "Rebuild", "AddIndexCycler"
	}

	local tbl = vgui.GetControlTable("ixFOCustomizer")
	local missing = {}

	for _, name in ipairs(required) do
		if (not tbl or not isfunction(tbl[name])) then
			missing[#missing + 1] = name
		end
	end

	ix.fallout.customizerMissing = missing

	if (#missing > 0) then
		ErrorNoHalt(string.format(
			"[falloutrp] ixFOCustomizer is missing: %s - character creation will fail\n",
			table.concat(missing, ", ")))
	end
end

--[[
	Load marker. If the trace file stops before this line, THIS file threw
	partway through - which leaves everything above the throw in place and
	every patch below it silently unregistered.
]]
ix.fallout.CreateTrace("load: cl_customizer.lua")
