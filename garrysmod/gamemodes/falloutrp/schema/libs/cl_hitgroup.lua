--[[
	The hitgroup overrides, client side.

	Only the OVERRIDES are sent. The profiles themselves are in
	`sh_hitgroup.lua`, which both realms load off disk - shipping eight fixed
	tables over the wire would carry information the client already has.
]]

if (not CLIENT) then return end

ix.hitgroup = ix.hitgroup or {}
ix.hitgroup.overrides = ix.hitgroup.overrides or {}

net.Receive("ixHitgroupSync", function()
	ix.hitgroup.overrides = net.ReadTable() or {}
end)
