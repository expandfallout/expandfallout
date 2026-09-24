--[[
	Putting a plot down.

	The ghost, the rotation and the red-when-illegal preview are all
	`cl_deploy.lua`'s, which knows nothing about what it is placing - this is
	the same three lines the workbench placer uses, and for the same reason: one
	placement flow means one set of habits for everything you can put down.
]]

if (not CLIENT) then return end

ix.farming = ix.farming or {}

net.Receive("ixFarmBeginPlacing", function()
	local model = net.ReadString()

	if (not ix.deploy.Begin(model, function(position, angles)
		net.Start("ixFarmPlace")
			net.WriteVector(position)
			net.WriteAngle(angles)
		net.SendToServer()
	end)) then
		LocalPlayer():Notify("That model could not be loaded.")

		return
	end

	LocalPlayer():Notify("Left click to place, J and K to turn, right click "
		.. "to cancel.")
end)
