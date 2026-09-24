--[[
	The client's copy of the blacklist.

	Purely so the charge's Use button can be honest about a door it will refuse
	to stick to. The server sends it on join and again whenever it changes, and
	checks it again itself when a charge is actually planted - this end is a
	courtesy, not a permission.
]]

if (not CLIENT) then return end

ix.breach = ix.breach or {}
ix.breach.blacklist = ix.breach.blacklist or {}

net.Receive("ixBreachList", function()
	local count = net.ReadUInt(16)
	local list = {}

	for _ = 1, count do
		list[net.ReadString()] = true
	end

	ix.breach.blacklist = list
end)
