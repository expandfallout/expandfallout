--[[
	The permission registry, and nothing else.

	IT EXISTS BECAUSE OF LOAD ORDER. `libs/` is included alphabetically, so
	`sh_adminverbs.lua` runs at 24 and `sh_usergroups.lua` at 61 - and the
	verbs register permissions, which lived in the usergroups file. The result
	was

	    attempt to call field 'RegisterPermission' (a nil value)

	and a schema that would not load. Renaming one file so the order happened
	to work would have fixed the symptom and left the trap: the next file that
	registers a permission gets to rediscover it.

	So the registry sorts FIRST, ahead of everything that uses it, and the
	dependency stops being a question. `sh_adminbase` beats `sh_adminlog`,
	`sh_adminverbs` and `sh_usergroups`, which is the whole design of the name.

	Permissions are REGISTERED RATHER THAN INFERRED. Reading them off the ranks
	would only ever show the ones somebody had already granted, so a permission
	nobody has yet would be invisible in the very screen you would go to to
	grant it.
]]

ix.admin = ix.admin or {}

--- `[id] = {id, description, category}`.
ix.admin.permissions = ix.admin.permissions or {}

function ix.admin.RegisterPermission(id, description, category)
	ix.admin.permissions[id] = {
		id = id,
		description = description or id,
		category = category or "General"
	}
end

--- Sorted, and grouped by category, for a menu.
function ix.admin.SortedPermissions()
	local out = {}

	for _, permission in pairs(ix.admin.permissions) do
		out[#out + 1] = permission
	end

	table.sort(out, function(a, b)
		if (a.category ~= b.category) then return a.category < b.category end

		return a.id < b.id
	end)

	return out
end
