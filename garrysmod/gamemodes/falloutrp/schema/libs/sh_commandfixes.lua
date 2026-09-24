--[[
	Two things Helix's own commands get wrong for this server, fixed by
	replacing them rather than by patching around them.

	`ix.command.Add` REGISTERS BY NAME, and the schema loads after the
	framework - so defining a command Helix already has replaces it outright.
	That is the supported way to disagree with one of them, and it leaves
	nothing to go stale: there is one `PlyWhitelist` and this is it.

	WHAT CHANGED, and why:

	    the target is no longer told they were whitelisted. It is an
	    administrative fact about their account, not news - and a player who
	    has just been put in a faction does not need a second message about
	    the mechanism that let it happen.

	Everything else about both commands is Helix's, including who may run them
	and what they answer.
]]

local function FindFaction(client, name)
	local faction = ix.faction.teams[name]

	if (faction) then return faction end

	for _, data in ipairs(ix.faction.indices) do
		if (ix.util.StringMatches(L(data.name, client), name)
		or ix.util.StringMatches(data.uniqueID, name)) then
			return data
		end
	end
end

ix.command.Add("PlyWhitelist", {
	description = "@cmdPlyWhitelist",

	--- Helix's own privilege name, so any CAMI grant already made still holds.
	privilege = "Manage Character Whitelist",
	superAdminOnly = true,
	arguments = {ix.type.player, ix.type.text},

	OnRun = function(self, client, target, name)
		if (name == "") then return "@invalidArg", 2 end

		local faction = FindFaction(client, name)

		if (not faction) then return "@invalidFaction" end

		if (not target:SetWhitelisted(faction.index, true)) then return end

		--[[
			STAFF ONLY. Helix's version includes `or v == target`, which is the
			line this exists to remove.
		]]
		for _, listener in player.Iterator() do
			if (self:OnCheckAccess(listener)) then
				listener:NotifyLocalized("whitelist", client:GetName(),
					target:GetName(), L(faction.name, listener))
			end
		end
	end
})

ix.command.Add("PlyUnwhitelist", {
	description = "@cmdPlyUnwhitelist",
	privilege = "Manage Character Whitelist",
	superAdminOnly = true,
	arguments = {ix.type.player, ix.type.text},

	OnRun = function(self, client, target, name)
		if (name == "") then return "@invalidArg", 2 end

		local faction = FindFaction(client, name)

		if (not faction) then return "@invalidFaction" end

		if (not target:SetWhitelisted(faction.index, false)) then return end

		for _, listener in player.Iterator() do
			if (self:OnCheckAccess(listener)) then
				listener:NotifyLocalized("unwhitelist", client:GetName(),
					target:GetName(), L(faction.name, listener))
			end
		end
	end
})
