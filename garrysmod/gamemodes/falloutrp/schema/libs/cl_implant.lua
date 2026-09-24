--[[
	Implants, client side: the extractor's window.

	One list and two buttons. It is deliberately small - the decision is "which
	one", and everything else about the surgery happens on the server while you
	stand still.
]]

ix.implants = ix.implants or {}

if (not CLIENT) then return end

net.Receive("ixImplantList", function()
	local target = net.ReadEntity()
	local count = net.ReadUInt(8)
	local list = {}

	for index = 1, count do
		list[index] = net.ReadString()
	end

	if (not IsValid(target) or #list == 0) then return end

	if (IsValid(ix.gui.implants)) then ix.gui.implants:Remove() end

	local scale = ScrH() / 1080

	local frame = vgui.Create("ixFOFrame")

	frame:SetSize(math.Round(420 * scale), math.Round(300 * scale))
	frame:Center()
	frame:MakePopup()
	frame:SetTitle("IMPLANT EXTRACTOR")

	ix.gui.implants = frame

	local heading = frame:Add("ixFOLabel")

	heading:Dock(TOP)
	heading:SetTall(math.Round(40 * scale))
	heading:DockMargin(math.Round(10 * scale), math.Round(28 * scale),
		math.Round(10 * scale), 0)
	heading:SetFont("ixLootRow")
	heading:SetWrap(true)
	heading:SetText("What is inside them. Taking one out means standing still "
		.. "for a few seconds - and they can walk away.")

	--[[
		A BUTTON EACH, rather than a dropdown and an accept.

		Phoenix use a combo box, and a combo box is two clicks and a decision
		about what "Select an implant" means when you have not selected one.
		There are never more than a handful of these.
	]]
	local scroll = frame:Add("ixFOScrollPanel")

	scroll:Dock(FILL)
	scroll:DockMargin(math.Round(10 * scale), math.Round(6 * scale),
		math.Round(10 * scale), 0)

	for _, id in ipairs(list) do
		local implant = ix.implants.Get(id)
		local button = scroll:Add("ixFOButton")

		button:Dock(TOP)
		button:SetTall(math.Round(30 * scale))
		button:DockMargin(0, 0, 0, math.Round(4 * scale))
		button:SetText(string.upper(implant and implant.name or id))
		button:SetFont("ixLootRow")
		button:SetContentAlignment(5)

		if (implant and implant.faction) then
			button:SetTooltip("Only " .. implant.faction .. " should touch "
				.. "this one.")
		end

		button.DoClick = function()
			net.Start("ixImplantExtract")
				net.WriteEntity(target)
				net.WriteString(id)
			net.SendToServer()

			frame:Remove()
		end
	end

	--- Every window in this schema draws its own way out - see `ixFOFrame`.
	local close = frame:Add("ixFOButton")

	close:Dock(BOTTOM)
	close:SetTall(math.Round(30 * scale))
	close:DockMargin(math.Round(10 * scale), math.Round(6 * scale),
		math.Round(10 * scale), math.Round(10 * scale))
	close:SetText("CLOSE")
	close:SetFont("ixLootHeader")
	close:SetContentAlignment(5)
	close.DoClick = function() frame:Remove() end

	frame.OnKeyCodePressed = function(_, key)
		if (key == KEY_ESCAPE) then frame:Remove() end
	end

	frame.OnRemove = function()
		if (ix.gui.implants == frame) then ix.gui.implants = nil end
	end
end)
