--[[
	Per-weapon hitgroup profile overrides.

	The PROFILES are code - see `sh_hitgroup.lua` - and which weapon follows
	which is data, because that is the half somebody changes while the server
	is running. A weapon with no override follows its `SWEP.Type`, so this
	table stays small and holds only the deliberate exceptions.
]]

if (not SERVER) then return end

util.AddNetworkString("ixHitgroupSync")

local KEY = "hitgroups"
local loaded = false

function ix.hitgroup.Save()
	if (not loaded) then return end

	ix.data.Set(KEY, ix.hitgroup.overrides, false, true)
end

function ix.hitgroup.Load()
	if (loaded) then return end

	ix.hitgroup.overrides = ix.data.Get(KEY, {}, false, true) or {}
	loaded = true

	MsgC(Color(255, 200, 100), string.format(
		"[falloutrp] %d weapon hitgroup override(s)\n",
		table.Count(ix.hitgroup.overrides)))
end

hook.Add("LoadData", "ixHitgroup", ix.hitgroup.Load)
hook.Add("PostLoadData", "ixHitgroup", ix.hitgroup.Load)
timer.Simple(10, ix.hitgroup.Load)

--[[
	Sent to everybody, because the client draws the description from the same
	profile the server applies - and a description that disagreed with the
	damage would be worse than none.
]]
function ix.hitgroup.SendAll(client)
	net.Start("ixHitgroupSync")
		net.WriteTable(ix.hitgroup.overrides)
	if (IsValid(client)) then net.Send(client) else net.Broadcast() end
end

hook.Add("PlayerLoadedCharacter", "ixHitgroup", function(client)
	timer.Simple(1, function()
		if (IsValid(client)) then ix.hitgroup.SendAll(client) end
	end)
end)

--[[
	Set or clear one weapon's profile.

	A command rather than a window, for now. The profiles are eight named sets
	and the weapons are 259, so the useful shape of a UI here is a searchable
	list beside a dropdown - which is the blueprint editor's shape, and worth
	building alongside it rather than twice.
]]
ix.command.Add("WeaponHitgroup", {
	description = "Set which hitgroup profile a weapon follows.",
	adminOnly = true,
	arguments = {ix.type.string, bit.bor(ix.type.string, ix.type.optional)},

	OnRun = function(self, client, uniqueID, profile)
		uniqueID = string.lower(string.Trim(uniqueID or ""))

		local itemTable = ix.item.list[uniqueID]

		if (not itemTable or itemTable.base ~= "base_weapons") then
			return "No weapon called '" .. uniqueID .. "'."
		end

		--[[
			No profile clears the override, which is how a weapon is put back
			on its type's default - and is a thing somebody will want the
			moment they set one by mistake.
		]]
		if (not profile or profile == "") then
			ix.hitgroup.overrides[uniqueID] = nil

			ix.hitgroup.Save()
			ix.hitgroup.SendAll()

			return string.format("%s follows its type again (%s).",
				itemTable.name, ix.hitgroup.ProfileID(uniqueID))
		end

		profile = string.lower(string.Trim(profile))

		if (not ix.hitgroup.profiles[profile]) then
			return "No such profile. There is: "
				.. table.concat(ix.hitgroup.All(), ", ")
		end

		ix.hitgroup.overrides[uniqueID] = profile

		ix.hitgroup.Save()
		ix.hitgroup.SendAll()

		local set = ix.hitgroup.profiles[profile]

		return string.format("%s is now %s - head %sx, body %sx, legs %sx.",
			itemTable.name, set.name, ix.hitgroup.Format(set.head),
			ix.hitgroup.Format(set.body), ix.hitgroup.Format(set.limb))
	end
})

--- What a weapon currently follows, and why.
ix.command.Add("WeaponHitgroupList", {
	description = "Show the hitgroup profiles, and every weapon overridden.",
	adminOnly = true,

	OnRun = function(self, client)
		for _, id in ipairs(ix.hitgroup.All()) do
			local set = ix.hitgroup.profiles[id]

			--- The dismemberment chance lives on the profile too; see
			--- `sh_dismember.lua` for why a calibre owns both.
			client:ChatPrint(string.format(
				"%-10s head %sx  body %sx  legs %sx  limbs off %d%%",
				id, ix.hitgroup.Format(set.head), ix.hitgroup.Format(set.body),
				ix.hitgroup.Format(set.limb), set.dismember or 0))
		end

		local count = 0

		for uniqueID, id in SortedPairs(ix.hitgroup.overrides) do
			local itemTable = ix.item.list[uniqueID]

			client:ChatPrint(string.format("  %s -> %s",
				itemTable and itemTable.name or uniqueID, id))

			count = count + 1
		end

		return string.format("%d weapon(s) overridden.", count)
	end
})
