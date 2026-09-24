--[[
	Lockpicking, client side: opening the window and carrying the one answer.

	Two messages, and both of them are short. The panel is
	`derma/cl_lockpick.lua`; this is the door it comes through.
]]

ix.lockpick = ix.lockpick or {}

if (not CLIENT) then return end

net.Receive("ixLockpickOpen", function()
	local entity = net.ReadEntity()
	local level = net.ReadUInt(4)
	local pins = net.ReadUInt(10)

	if (not IsValid(entity)) then return end

	--- One at a time. Opening a second lock closes the first.
	if (IsValid(ix.gui.lockpick)) then
		ix.gui.lockpick:Remove()
	end

	local panel = vgui.Create("ixFOLockpick")

	if (not IsValid(panel)) then return end

	panel:Setup(entity, level, pins)
end)

--[[
	HOW FAR THE CYLINDER TURNS. The whole of what the server tells a picker,
	and the reason the answer cannot be read out of the client: it is a
	consequence of the angle rather than the angle itself.
]]
net.Receive("ixLockpickDifference", function()
	local difference = net.ReadFloat()

	if (not IsValid(ix.gui.lockpick)) then return end

	ix.gui.lockpick.difference = difference
end)
