--[[
	The sizes the server is actually using, applied to this client's copy.

	`ix.container.stored` exists on both realms - Helix's containers plugin is
	shared - so without this the developer terminal would list the framework's
	numbers rather than the server's, and every row would be wrong for any
	crate an admin had changed.

	Nothing else on the client reads a container's size: the grid is drawn from
	the inventory the server syncs, which already carries its own dimensions.
	This is for the terminal, and for anything later that wants to ask.
]]

if (not CLIENT) then return end

ix.containers = ix.containers or {}

net.Receive("ixContainerSizes", function()
	local count = net.ReadUInt(8)

	for _ = 1, count do
		local model = net.ReadString()
		local width = net.ReadUInt(6)
		local height = net.ReadUInt(6)

		--[[
			Written into BOTH the definition and the override table. The
			definition is what the terminal reads; the override table is what
			`ix.containers.SizeOf` reads, and a client that disagreed with
			itself would show one number and send another.
		]]
		ix.containers.sizes[model] = {width, height}

		ix.containers.Apply(model, width, height)
	end
end)
