--[[
	Sub-factions.

	A faction can belong to another one. House runs the Omertas, the White
	Glove Society and the Chairmen; Arroyo has the Great Khans under it; the
	Fiends and the Powder Gangers answer to the same people. Those are real
	relationships in the setting and nothing in Helix expresses them - a
	faction there is a flat list entry and nothing else.

	ONE LEVEL, DELIBERATELY. A parent and its children, and no deeper. Every
	relationship anybody has asked for fits in one level, and a tree of
	arbitrary depth needs cycle checks, a recursive "is X under Y", and a
	configurer that can draw it - all to express something nobody wanted. If a
	grandchild is ever needed, this is the file that changes.

	CONFIGURED IN GAME, NOT IN THE FILES. The generated faction files are
	rewritten whenever the roster changes, so a link stored in one would be
	lost the next time somebody added a faction. Links live in `ix.data`,
	per schema and not per map, because who answers to whom does not change
	when the map does.
]]

ix.faction = ix.faction or {}

--- `[childUniqueID] = parentUniqueID`.
ix.faction.parents = ix.faction.parents or {}

--[[
	The parent of a faction, or nil.

	Takes a uniqueID rather than an index, like the spawn system, because an
	index is a load-order artefact and these are stored.
]]
function ix.faction.GetParent(uniqueID)
	return ix.faction.parents[uniqueID]
end

--- Every faction directly under this one, sorted.
function ix.faction.GetChildren(uniqueID)
	local out = {}

	for child, parent in pairs(ix.faction.parents) do
		if (parent == uniqueID) then
			out[#out + 1] = child
		end
	end

	table.sort(out)

	return out
end

--- Every faction that has children, sorted. The tops of the trees.
function ix.faction.GetRoots()
	local seen, out = {}, {}

	for _, parent in pairs(ix.faction.parents) do
		if (not seen[parent]) then
			seen[parent] = true
			out[#out + 1] = parent
		end
	end

	table.sort(out)

	return out
end

--[[
	The group a faction belongs to: its parent if it has one, otherwise itself.

	This is the function most callers actually want. "Are these two on the same
	side" is `GetGroup(a) == GetGroup(b)`, and it answers correctly for a
	parent against its own child without the caller knowing which is which.
]]
function ix.faction.GetGroup(uniqueID)
	return ix.faction.parents[uniqueID] or uniqueID
end

--- Whether two factions are in the same group.
function ix.faction.SameGroup(a, b)
	if (not a or not b) then return false end

	return ix.faction.GetGroup(a) == ix.faction.GetGroup(b)
end

--[[
	Everything in a faction's group, including the parent and itself.

	Used by anything that wants "all of House" - the spawn system offers a
	character their whole group's locations, so an Omerta can return to the
	Strip rather than only to Gomorrah.
]]
function ix.faction.GetGroupMembers(uniqueID)
	local root = ix.faction.GetGroup(uniqueID)
	local out = {root}

	for _, child in ipairs(ix.faction.GetChildren(root)) do
		out[#out + 1] = child
	end

	return out
end

if (SERVER) then
	util.AddNetworkString("ixFactionTree")
	util.AddNetworkString("ixFactionTreeOpen")

	function ix.faction.SaveTree()
		ix.data.Set("factiontree", ix.faction.parents, false, true)
		ix.faction.SyncTree()
	end

	function ix.faction.LoadTree()
		ix.faction.parents = ix.data.Get("factiontree", {}, false, true) or {}

		--[[
			Links naming a faction that no longer exists are dropped on load
			rather than kept. A faction can be removed from the roster between
			restarts, and a link to nothing is a link that will confuse every
			reader of it from then on.
		]]
		local dropped = 0

		for child, parent in pairs(ix.faction.parents) do
			if (not ix.faction.teams[child] or not ix.faction.teams[parent]) then
				ix.faction.parents[child] = nil
				dropped = dropped + 1
			end
		end

		local count = table.Count(ix.faction.parents)

		MsgC(Color(255, 200, 100), string.format(
			"[falloutrp] loaded %d faction link(s)%s\n", count,
			dropped > 0 and string.format(", dropped %d naming a faction that "
				.. "no longer exists", dropped) or ""))
	end

	--[[
		Sent to everyone, not just admins.

		The tree is not secret - it is who visibly answers to whom - and the
		client needs it for anything that colours or groups a player by side.
	]]
	function ix.faction.SyncTree(client)
		net.Start("ixFactionTree")
			net.WriteUInt(table.Count(ix.faction.parents), 8)

			for child, parent in pairs(ix.faction.parents) do
				net.WriteString(child)
				net.WriteString(parent)
			end

		if (IsValid(client)) then
			net.Send(client)
		else
			net.Broadcast()
		end
	end

	--[[
		Link or unlink. `parent` of nil detaches.

		Returns `true` or `false, reason`, so the command can say what was
		wrong rather than failing silently.
	]]
	function ix.faction.SetParent(child, parent)
		if (not ix.faction.teams[child]) then
			return false, "No faction with the uniqueID '" .. tostring(child) ..
				"'. Use /classnameviewer to see them."
		end

		if (not parent) then
			if (not ix.faction.parents[child]) then
				return false, child .. " is not a sub-faction of anything."
			end

			ix.faction.parents[child] = nil
			ix.faction.SaveTree()

			return true
		end

		if (not ix.faction.teams[parent]) then
			return false, "No faction with the uniqueID '" .. tostring(parent) .. "'."
		end

		if (child == parent) then
			return false, "A faction cannot be under itself."
		end

		--[[
			ONE LEVEL. A faction that already has children cannot become a
			child, and a child cannot become a parent - either would make a
			second level, and everything reading this assumes there is only
			one.

			This also happens to make cycles impossible, which is worth having
			for free: a two-faction cycle would make `GetGroup` alternate
			between them forever.
		]]
		if (#ix.faction.GetChildren(child) > 0) then
			return false, child .. " already has sub-factions of its own."
		end

		if (ix.faction.parents[parent]) then
			return false, parent .. " is itself a sub-faction of " ..
				ix.faction.parents[parent] .. "."
		end

		ix.faction.parents[child] = parent
		ix.faction.SaveTree()

		return true
	end

	hook.Add("LoadData", "ixFactionTree", ix.faction.LoadTree)

	--[[
		The same three triggers everything else that loads data uses -
		`InitPostEntity` does not reach this schema, so a plain timer is the
		one that cannot fail. See `24-devtools.md`.
	]]
	hook.Add("InitPostEntity", "ixFactionTree", function()
		timer.Simple(2, ix.faction.LoadTree)
	end)

	timer.Simple(10, function()
		if (table.IsEmpty(ix.faction.parents)) then
			ix.faction.LoadTree()
		end
	end)

	hook.Add("PlayerInitialSpawn", "ixFactionTree", function(client)
		timer.Simple(2, function()
			if (IsValid(client)) then
				ix.faction.SyncTree(client)
			end
		end)
	end)
else
	net.Receive("ixFactionTree", function()
		local count = net.ReadUInt(8)

		ix.faction.parents = {}

		for _ = 1, count do
			local child = net.ReadString()

			ix.faction.parents[child] = net.ReadString()
		end

		--[[
			The server broadcasts a fresh tree after every link and unlink, so
			this fires whenever the hierarchy changes for any reason. The
			configurer redraws off it rather than assuming its own click
			worked - if the server refused the link, the panel shows the tree
			that actually exists.
		]]
		hook.Run("FactionTreeChanged")
	end)
end
