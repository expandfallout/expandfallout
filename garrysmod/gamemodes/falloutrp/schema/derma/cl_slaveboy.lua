--[[
	The SlaveBoy 2000's screen.

	Phoenix's is a manifest window listing everybody you own, with what you can
	do to each of them. Theirs also sells people to a vendor; that half needs
	the vendor and the mine, which are a later job, so this is the collar half:
	who you own, how long they have left, and the two things you can do about it
	from wherever you are stood.

	    the time      counted down live from the deadline the server sent, so
	                  it is right without anything being re-sent
	    release       the collar comes off and they are free
	    trigger       the fuse starts, and they are told in no uncertain terms

	TRIGGER ASKS FIRST. It is the only button in this schema that kills
	somebody outright with one click, and a misclick on a list of names is
	exactly the kind of accident a confirmation is for.

	The window closes on its own if the list arrives empty, because a SlaveBoy
	with nobody on it has nothing to show.
]]

if (not CLIENT) then return end

local PANEL = {}

local function Scaled(value)
	return math.Round(value * ix.fallout.GetFontScale())
end

function PANEL:Init()
	if (IsValid(ix.gui.slaveBoy)) then
		ix.gui.slaveBoy:Remove()
	end

	ix.gui.slaveBoy = self

	ix.fallout.LoadMenuFonts()

	self:SetSize(math.min(ScrW() - Scaled(80), Scaled(520)),
		math.min(ScrH() - Scaled(80), Scaled(460)))
	self:Center()
	self:MakePopup()
	self:SetTitle("SLAVEBOY 2000")

	self.slaves = {}

	local footer = self:Add("Panel")

	footer:Dock(BOTTOM)
	footer:SetTall(Scaled(30))
	footer:DockMargin(0, Scaled(8), 0, 0)

	--[[
		`ixFOFrame` turns Helix's own close button off in its Init - the title
		is drawn into a gap in the top rule and there is nowhere to put one - so
		every window built on it provides its own. Escape works as well, but a
		window with no visible way out is one people get stuck in.
	]]
	local close = footer:Add("ixFOButton")

	close:Dock(RIGHT)
	close:SetWide(Scaled(100))
	close:SetText("CLOSE")
	close:SetContentAlignment(5)
	close.DoClick = function() self:Remove() end

	self.hint = footer:Add("ixFOLabel")
	self.hint:Dock(FILL)
	self.hint:SetContentAlignment(4)
	self.hint:SetFont("ixLootSmall")
	self.hint:SetText("Everybody whose collar you armed.")

	self.list = self:Add("ixFOScrollPanel")
	self.list:Dock(FILL)
end

--[[
	Rebuild from a list the server sent.

	`{id, name, until, fuse}` per slave; `until` and `fuse` are `os.time`
	deadlines, so the rows can count down without another message.
]]
function PANEL:SetSlaves(slaves)
	self.slaves = slaves
	self.list:Clear()

	if (#slaves == 0) then
		local row = self.list:Add("ixFOPanelBracketed")

		row:Dock(TOP)
		row:SetTall(Scaled(40))
		row:DockMargin(0, 0, 0, Scaled(4))
		row:DockPadding(Scaled(8), Scaled(6), Scaled(8), Scaled(6))

		local label = row:Add("ixFOLabel")
		label:Dock(FILL)
		label:SetFont("ixLootRow")
		label:SetText("You do not own anybody.")

		return
	end

	for _, slave in ipairs(slaves) do
		self:AddRow(slave)
	end
end

function PANEL:AddRow(slave)
	local row = self.list:Add("ixFOPanelBracketed")

	row:Dock(TOP)
	row:SetTall(Scaled(44))
	row:DockMargin(0, 0, 0, Scaled(4))
	row:DockPadding(Scaled(8), Scaled(6), Scaled(8), Scaled(6))
	row:SetNoOverdraw(true)

	--[[
		Reversed, because docking RIGHT stacks right to left in child order -
		the same note the dev terminal's rows carry, and the same reason.
	]]
	local trigger = row:Add("ixFOButton")

	trigger:Dock(RIGHT)
	trigger:SetWide(Scaled(84))
	trigger:DockMargin(Scaled(4), 0, 0, 0)
	trigger:SetText("TRIGGER")
	trigger:SetContentAlignment(5)
	trigger.DoClick = function()
		Derma_Query(string.format("Set off %s's collar? This will kill them.",
			slave.name), "SlaveBoy 2000",
			"Trigger", function()
				self:Send("trigger", slave.id)
			end,
			"Cancel", function() end)
	end

	local release = row:Add("ixFOButton")

	release:Dock(RIGHT)
	release:SetWide(Scaled(84))
	release:DockMargin(Scaled(4), 0, 0, 0)
	release:SetText("RELEASE")
	release:SetContentAlignment(5)
	release.DoClick = function()
		self:Send("disarm", slave.id)
	end

	local locate = row:Add("ixFOButton")
	locate:Dock(RIGHT)
	locate:SetWide(Scaled(84))
	locate:DockMargin(Scaled(4), 0, 0, 0)
	locate:SetText("LOCATE")
	locate:SetContentAlignment(5)
	locate:SetTooltip("Mark where they are for a while. Only you see it.")
	locate.DoClick = function()
		self:Send("locate", slave.id)
	end

	local name = row:Add("ixFOLabel")

	name:Dock(TOP)
	name:SetTall(Scaled(18))
	name:SetFont("ixLootRow")
	name:SetText(slave.name)

	--[[
		The countdown is drawn rather than set, because it changes every second
		and a label that is re-set every frame is a layout pass every frame.
	]]
	local time = row:Add("Panel")

	time:Dock(FILL)
	time.Paint = function(_, width, height)
		local text

		if (slave.fuse > 0) then
			text = "ARMED - " .. ix.slavery.FormatTime(slave.fuse - os.time())
		else
			text = "Collar: "
				.. ix.slavery.FormatTime(slave["until"] - os.time())
		end

		draw.SimpleText(text, "ixLootSmall", 0, height * 0.5,
			slave.fuse > 0 and Color(255, 120, 120) or Color(190, 190, 180),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
end

function PANEL:Send(action, id)
	net.Start("ixSlaveBoyAction")
		net.WriteString(action)
		net.WriteUInt(id, 32)
	net.SendToServer()

	ix.fallout.PlayUISound("select")
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then self:Remove() end
end

vgui.Register("ixFOSlaveBoy", PANEL, "ixFOFrame")

--[[
	The list arriving is what opens the window, and the same message refreshes
	one that is already open - so there is no "open" message separate from the
	data, and no window that can be open with nothing in it.
]]
net.Receive("ixSlaveBoyOpen", function()
	local count = net.ReadUInt(8)
	local slaves = {}

	for _ = 1, count do
		slaves[#slaves + 1] = {
			id = net.ReadUInt(32),
			name = net.ReadString(),
			["until"] = net.ReadUInt(32),
			fuse = net.ReadUInt(32)
		}
	end

	local panel = ix.gui.slaveBoy

	if (not IsValid(panel)) then
		panel = vgui.Create("ixFOSlaveBoy")
	end

	panel:SetSlaves(slaves)
end)
