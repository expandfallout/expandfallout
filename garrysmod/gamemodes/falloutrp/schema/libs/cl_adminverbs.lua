--[[
	The blind effect, drawn for whoever an admin has blinded.

	A NETVAR RATHER THAN A MESSAGE, so somebody who is blinded and then
	reconnects or respawns is still blinded - a state that only existed as a
	one-off message would quietly clear itself at the worst moment, which for a
	staff tool is the moment somebody is being questioned.

	Drawn over everything including the HUD, because half a blind is not a
	blind.
]]

if (not CLIENT) then return end

hook.Add("HUDPaint", "ixAdminBlind", function()
	local client = LocalPlayer()

	if (not IsValid(client) or not client:GetNetVar("ixBlind")) then return end

	surface.SetDrawColor(0, 0, 0, 255)
	surface.DrawRect(0, 0, ScrW(), ScrH())

	draw.SimpleText("You have been blinded by a member of staff.",
		"ixLootRow", ScrW() * 0.5, ScrH() * 0.5, Color(120, 120, 120),
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)
