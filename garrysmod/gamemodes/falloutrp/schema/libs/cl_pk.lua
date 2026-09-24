--[[
	Player killing - the countdown on your own screen.

	Phoenix's, in the place they put it:

	    local x,y = ScrW() * 0.25, ScrH() * 0.2
	    draw.SimpleText("PK Active: " .. timeLeft .. "s", ...)

	A quarter of the way across rather than centred, so it does not sit on top
	of everything else that wants the middle of the screen.

	ONLY YOUR OWN. Being marked is something the people who were standing near
	you when it happened know about - that is what the local announcement is
	for - and a marker over everybody's head would turn it into a scoreboard.

	It reads a NETVAR IN `CurTime`, not the character data. The data is the
	truth and is in `os.time`, which is a wall clock and would be minutes out
	on anybody whose computer clock is wrong; the netvar is set from the
	server's own clock for exactly this.
]]

if (not CLIENT) then return end

ix.pk = ix.pk or {}

--[[
	The red chat line.

	Two halves rather than one string: the name, or whatever the sentence is
	about, in the brighter red, and the rest in a softer one. That is Phoenix's
	own shape -

	    chat.AddText(Color(255, 0, 0), speaker:Name(),
	        Color(255, 80, 80), " has been marked for death.")

	- and it is what makes the line scan as being ABOUT somebody rather than as
	a server notice.
]]
net.Receive("ixPKChat", function()
	local highlight = net.ReadString()
	local rest = net.ReadString()

	chat.AddText(Color(255, 0, 0), highlight, Color(255, 80, 80), rest)

	surface.PlaySound("phoenix/ui/nv/ui_rep_bad.mp3")
end)

--------------------------------------------------------------------------------
-- Becoming somebody else
--------------------------------------------------------------------------------

--[[
	The rename, after a PK. It cannot be dismissed.

	NO CLOSE BUTTON, NO ESCAPE, AND IT COMES BACK. That is not the enforcement
	though - the enforcement is that the server has frozen them and will not
	unfreeze until it has accepted a name and a description. This panel is the
	polite half; `ix.pk.Prompt` is the half that matters, and it is why closing
	this by any means simply leaves somebody standing still.

	The lengths are read from the same configs the character creation screen
	uses, so the two can never disagree about what a name is - and they are
	shown, because being refused twice for a rule nobody stated is how somebody
	ends up typing "aaaaaaaaaaaaaaaa".
]]
local panel

--[[
	One labelled field.

	A CONTAINER PER FIELD, rather than docking the label and the entry as
	siblings of the frame. The first version did that and the two labels ended
	up on top of each other with the entries in the wrong order underneath:
	`ixFOLabel` is a `DLabel`, whose `PerformLayout` sizes itself to its text
	and throws away whatever `SetTall` was given it, so every sibling after it
	was laid out against a height that changed a frame later.

	Inside a container of a known height, the label takes its 20 at the top and
	the entry fills what is left. Nothing after it can move.
]]
local function Field(parent, text, tall, bMultiline)
	local row = parent:Add("DPanel")

	row:Dock(TOP)
	row:SetTall(22 + tall)
	row:DockMargin(0, 0, 0, 10)
	row:SetPaintBackground(false)

	local label = row:Add("ixFOLabel")

	label:Dock(TOP)
	label:SetTall(20)
	label:SetFont("ixLootSmall")
	label:SetText(text)

	local entry = row:Add("ixFOTextEntry")

	entry:Dock(FILL)

	if (bMultiline) then entry:SetMultiline(true) end

	return entry
end

--[[
	The rename, after a PK. It cannot be dismissed.

	NO CLOSE BUTTON, NO ESCAPE, AND IT COMES BACK. That is not the enforcement
	though - the enforcement is that the server has frozen them and will not
	unfreeze until it has accepted a name and a description. This panel is the
	polite half; `ix.pk.Prompt` is the half that matters, and it is why closing
	this by any means simply leaves somebody standing still.

	The lengths are read from the same configs the character creation screen
	uses, so the two can never disagree about what a name is - and they are on
	the labels, because being refused twice for a rule nobody stated is how
	somebody ends up typing "aaaaaaaaaaaaaaaa".
]]
local function Rename()
	if (IsValid(panel)) then panel:Remove() end

	if (not ix.fallout.LoadMenuFonts or not ix.fallout.LoadMenuFonts()) then
		--- Without the fonts every label measures as nothing and stacks.
		timer.Simple(1, Rename)

		return
	end

	local minimumName = ix.config.Get("minNameLength", 4)
	local minimumDescription = ix.config.Get("minDescriptionLength", 16)

	panel = vgui.Create("ixFOFrame")

	--[[
		Sized from the contents rather than guessed at: the blurb, two fields
		and the button, plus the frame's own `DockPadding(12, 36, 12, 12)`.
		The first version was 340 tall for 360 of content, which is why the
		bottom rule was drawn off the end of it.
	]]
	panel:SetSize(math.min(ScrW() - 80, 600),
		math.min(ScrH() - 80, 36 + 12 + 70 + 62 + 142 + 62 + 36 + 12))
	panel:Center()
	panel:MakePopup()
	panel:SetTitle("WHO ARE YOU NOW?")
	panel:ShowCloseButton(false)

	--- Escape is caught and thrown away; this is the one panel that must stay.
	panel.OnKeyCodePressed = function() end

	local blurb = panel:Add("ixFOLabel")

	blurb:Dock(TOP)
	blurb:SetTall(70)
	blurb:SetWrap(true)
	blurb:SetFont("ixLootSmall")
	blurb:DockMargin(0, 0, 0, 6)
	blurb:SetText("You were killed while marked. Nobody knows you and you "
		.. "know nobody. Give them a name, and say who they are in a sentence "
		.. "or two - you cannot carry on until you do.")

	local name = Field(panel, string.format("NAME - %d characters or more",
		minimumName), 30)

	local description = Field(panel, string.format(
		"DESCRIPTION - %d characters or more, more than one word",
		minimumDescription), 110, true)

	--[[
		AND THE BODY, because a PK is a new person rather than a new name.

		The same three the creation screen asks for, in the same units and with
		the same panels - `ixFOHeightEntry` is feet and inches, because nobody
		gives their height in inches. Filled with the middle of each range so
		somebody who does not care can press the button.
	]]
	local body = panel:Add("Panel")

	body:Dock(TOP)
	body:SetTall(56)
	body:DockMargin(0, 0, 0, 6)

	local bodyLabel = body:Add("ixFOLabel")

	bodyLabel:Dock(TOP)
	bodyLabel:SetTall(18)
	bodyLabel:SetFont("ixLootSmall")
	bodyLabel:SetText("HEIGHT, WEIGHT AND AGE")

	local fields = body:Add("Panel")

	fields:Dock(FILL)

	local height = fields:Add("ixFOHeightEntry")

	height:Dock(LEFT)
	height:SetWide(190)
	height:SetFeetRange(math.floor(ix.fallout.MIN_HEIGHT / 12),
		math.floor(ix.fallout.MAX_HEIGHT / 12))
	height:SetValue(70)

	local weight = fields:Add("ixFONumberEntry")

	weight:Dock(LEFT)
	weight:SetWide(150)
	weight:DockMargin(6, 0, 0, 0)
	--- `SetMin`/`SetMax`, which is what `ixFONumberEntry` calls its range.
	weight:SetMin(ix.fallout.MIN_WEIGHT)
	weight:SetMax(ix.fallout.MAX_WEIGHT)
	weight:SetSuffix("lbs")
	weight:SetValue(150)

	local age = fields:Add("ixFONumberEntry")

	age:Dock(LEFT)
	age:SetWide(130)
	age:DockMargin(6, 0, 0, 0)
	--[[
		THE MINIMUM AGE IS A CONFIG, not a constant.

		Height and weight are `ix.fallout.MIN_*`/`MAX_*` - sanity bounds nobody
		changes - but the youngest a character may be is a decision a server
		makes, so it lives in `minimumAge`. There is no `ix.fallout.MIN_AGE`,
		and reaching for one passed nil into `SetMin`, which `AccessorFunc`'s
		FORCE_NUMBER turned into a nil minimum and every later `math.Clamp` and
		`GetPlaceholder` threw on.

		The same two lines `sh_biography.lua` uses for the creation screen.
	]]
	age:SetMin(ix.config.Get("minimumAge", 18))
	age:SetMax(ix.fallout.MAX_AGE)
	age:SetSuffix("years")
	age:SetValue(math.max(ix.config.Get("minimumAge", 18), 30))

	local confirm = panel:Add("ixFOButton")

	confirm:Dock(BOTTOM)
	confirm:SetTall(36)
	confirm:SetText("THAT IS ME")
	confirm:SetContentAlignment(5)

	confirm.DoClick = function()
		net.Start("ixPKRename")
			net.WriteString(name:GetValue())
			net.WriteString(description:GetValue())
			net.WriteUInt(math.Clamp(math.floor(height:GetValue() or 70),
				0, 255), 8)
			net.WriteUInt(math.Clamp(math.floor(weight:GetValue() or 150),
				0, 1023), 10)
			net.WriteUInt(math.Clamp(math.floor(age:GetValue() or 30),
				0, 255), 8)
		net.SendToServer()

		--[[
			Closed on the way out rather than waiting for an answer. The server
			re-opens it if what was sent was not good enough, which is the same
			path a relog takes - so there is one way back into this panel
			rather than two.
		]]
		panel:Remove()
	end

	name:RequestFocus()
end

net.Receive("ixPKRename", Rename)

hook.Add("HUDPaint", "ixPK", function()
	local client = LocalPlayer()

	if (not IsValid(client) or not client:Alive()) then return end
	if (not ix.fallout.LoadMenuFonts or not ix.fallout.LoadMenuFonts()) then
		return
	end

	local until_ = client:GetNetVar("pkUntil")

	if (not until_) then return end

	local left = math.ceil(until_ - CurTime())

	if (left <= 0) then return end

	local text = "PK Active: " .. left .. "s"
	local x, y = ScrW() * 0.25, ScrH() * 0.2

	--[[
		Pulsing, which theirs does not do. Being marked is a state somebody
		needs to keep noticing rather than read once, and a static line in the
		corner is one the eye stops seeing after a minute.
	]]
	local pulse = 0.65 + 0.35 * math.abs(math.sin(RealTime() * 3))

	draw.SimpleText(text, "ixZoneName", x + 2, y + 2, Color(0, 0, 0, 200),
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	draw.SimpleText(text, "ixZoneName", x, y,
		Color(235, 70, 60, 255 * pulse), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)
