--[[
	Faction spawn points, and choosing between them.

	Phoenix hold you on a death screen until you pick where to come back. That
	is worth having for a reason beyond flavour: a faction with a base, an
	outpost and a camp has three sensible places to return to, and which one
	you pick is a real decision about how far you are willing to walk.

	    a faction with locations   -> death screen, pick one, respawn there
	    a faction with none        -> the map's own spawn points, as normal

	THE FALLBACK IS THE IMPORTANT HALF. Most factions will have no locations
	set for a long time, and a death screen offering an empty list is worse
	than no death screen at all. So an unconfigured faction respawns exactly
	the way it did before this existed, and nothing has to be set up for the
	server to work.

	PER MAP, like everything else that is a position. A spawn point on
	`rp_utah` means nothing anywhere else.
]]

ix.spawns = ix.spawns or {}

--[[
	`[factionUniqueID] = {{name = "...", position = Vector, angles = Angle}}`

	Keyed by the faction's uniqueID rather than its index, because the index is
	assigned in load order and shifts the moment a faction file is added or
	removed - which would silently move every spawn point to a different
	faction.
]]
ix.spawns.list = ix.spawns.list or {}

ix.config.Add("deathScreenTime", 5,
	"Seconds before a dead player may choose where to respawn.", nil, {
	data = {min = 0, max = 60}, category = "Spawns"
})

--- Every location a faction can return to. Empty is the normal case.
function ix.spawns.Get(faction)
	return ix.spawns.list[faction] or {}
end

--- Whether this faction has anywhere of its own.
function ix.spawns.Has(faction)
	return #ix.spawns.Get(faction) > 0
end

--[[
	The faction uniqueID for a character.

	Helix stores the faction INDEX on the character, and the index is a load
	order artefact. This is the one place the two are turned into each other,
	so nothing else has to know that the stored value is not the stable one.
]]
function ix.spawns.GetFaction(character)
	if (not character) then return end

	local faction = ix.faction.indices[character:GetFaction()]

	return faction and faction.uniqueID
end

--- Every faction that has at least one location, sorted, for the report.
function ix.spawns.GetConfigured()
	local out = {}

	for faction, points in pairs(ix.spawns.list) do
		if (#points > 0) then
			out[#out + 1] = faction
		end
	end

	table.sort(out)

	return out
end
