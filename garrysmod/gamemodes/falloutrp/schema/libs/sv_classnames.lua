--[[
	The command that opens the class name viewer.

	Server side because the window is admin only, and "who may open this" is
	not a decision a client gets to make. The panel itself is in
	`derma/cl_classnames.lua`.
]]

if (not SERVER) then return end

util.AddNetworkString("ixClassNamesOpen")

--[[
	The commands for this library live in `sh_commands.lua`.
	They have to be declared on both realms or the chatbox cannot
	see them - see the header there.
]]
