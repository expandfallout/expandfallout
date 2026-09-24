--[[
	Ranks, and what each one may do.

	Helix ships no admin system at all - it asks `client:IsAdmin()` and
	`IsSuperAdmin()` and leaves the rest to whatever admin mod is installed.
	Two levels cannot express "a moderator may read the logs but not hand out
	money", or "a helper may see the player list and nothing else".

	THE SHAPE IS SAM'S, and it is better than the one this file had first.
	(SAM is Srlion's paid admin mod; nothing here is its code, and the ideas
	below are the standard ones every serious admin mod converges on.) What it
	gets right, and what a fixed ladder of hardcoded groups got wrong:

	  * RANKS ARE DATA, not code. They live in `ix.data` and are made in the
	    menu, so a server can have an "eventstaff" rank without an edit and a
	    restart.

	  * PERMISSIONS ARE GRANTED PER RANK, not implied by a threshold. The old
	    version gave every permission at or below your power number, so making
	    a helper able to read the economy log meant giving them everything a
	    moderator has. Here a rank grants exactly what it grants.

	  * INHERITANCE IS SEPARATE FROM AUTHORITY. A rank inherits its parent's
	    permissions and can REVOKE one by granting it `false` - and how far up
	    the pecking order it sits is `immunity`, a number, which is a different
	    question with a different answer.

	Immunity is a number rather than a chain because "may this moderator kick
	that admin" comes up constantly and a number answers it in one comparison.

	GMOD'S OWN USERGROUP IS KEPT IN SYNC, coarsely. Forty-eight places in this
	schema ask `IsAdmin()`, as does every third-party addon and sandbox's own
	tool permissions - so a rank is mapped onto GMod's `user`, `admin` or
	`superadmin` underneath. The fine rank answers `ix.admin.Can`; the coarse
	one keeps everything written before this file from silently breaking.
]]

ix.admin = ix.admin or {}

--[[
	The one account that is always root, whatever is stored.

	A HARDCODED OWNER IS THE POINT, not a shortcut. Every other rank lives in
	`ix.data` and can be edited in a menu, which means a mistake in that menu -
	or somebody who talks their way into `rank.manage` - can leave a server
	with nobody able to fix it. This is the account that cannot be demoted, by
	anybody, including itself.

	Stored as the 64-bit id because that is what `SteamID64` returns and what
	the membership table is keyed by; the readable form is
	STEAM_0:0:00000000.
]]
ix.admin.rootSteamID = "PUT_YOUR_STEAMID64_HERE"

--- `[id] = rank`. Loaded from `ix.data`, seeded on a server that has none.
ix.admin.ranks = ix.admin.ranks or {}

--[[
	The permissions this schema's own systems use.

	The REGISTRY itself is in `sh_adminbase.lua`, which sorts ahead of every
	file that registers into it - see the note there. These are only the
	entries.
]]
do
	local P = ix.admin.RegisterPermission

	P("player.list", "See who is on the server", "Seeing")
	P("player.inspect", "See a player's character and inventory", "Seeing")
	P("log.view", "Open the log at all", "Logs")
	P("log.chat", "Read the chat log", "Logs")
	P("log.economy", "Read the money log", "Logs")
	P("log.items", "Read the item log", "Logs")
	P("log.admin", "Read the admin log", "Logs")

	P("player.goto", "Teleport to a player", "People")
	P("player.bring", "Teleport a player to you", "People")
	P("player.kick", "Kick a player", "People")
	P("player.ban", "Ban a player", "People")
	P("player.charedit", "Edit somebody's character", "People")

	P("item.spawn", "Spawn items", "World")
	P("money.give", "Hand out money", "World")
	P("bench.config", "Configure workbenches", "World")
	P("shop.config", "Configure faction shops", "World")
	P("loot.config", "Configure loot tables", "World")
	P("faction.manage", "Manage any faction", "World")

	P("rank.manage", "Create ranks and move people between them", "Danger")
	P("dev.terminal", "Use the developer terminal", "Danger")
	P("server.config", "Change server configuration", "Danger")
end

--------------------------------------------------------------------------------
-- Reading a rank
--------------------------------------------------------------------------------

--[[
	Never nil, so no caller needs a guard before reading a name or a colour.

	`ranks.user` is the normal fallback, and the literal behind it is for the
	window between a table being cleared and being refilled - which is exactly
	when a menu asked and got nothing back.
]]
function ix.admin.Rank(id)
	return ix.admin.ranks[id] or ix.admin.ranks.user or {
		id = "user", name = "User", immunity = 0, native = "user",
		color = Color(200, 200, 200), permissions = {}
	}
end

--[[
	HOW MANY CHARACTERS A PLAYER MAY HAVE.

	Helix asks `GetMaxPlayerCharacter` and falls back to the `maxCharacters`
	config; this answers it from the player's RANK, so a donator rank can have
	more slots than a user without a plugin or a whitelist file.

	A rank of 0 - which is every rank until somebody sets one - means "use the
	config", so this changes nothing until it is asked to. Inheritance is
	followed, because a rank that inherits from another inherits its slots
	along with its permissions.
]]
function ix.admin.MaxCharacters(client)
	local rank = ix.admin.Rank(ix.admin.GetRankID(client))
	local seen = {}

	while (rank and not seen[rank.id]) do
		seen[rank.id] = true

		local own = tonumber(rank.maxCharacters) or 0

		if (own > 0) then return own end

		rank = rank.inherit and ix.admin.ranks[rank.inherit] or nil
	end

	return ix.config.Get("maxCharacters", 5)
end

--[[
	Helix's own hook for it, so the character menu, the creation limit and the
	refusal message all agree - there is no second place asking.

	`hook.Add` rather than a `Schema:` function: nothing in Helix's plugins
	answers this one, so an ordinary listener is reached (see gotcha 22 for
	when it would not be).
]]
hook.Add("GetMaxPlayerCharacter", "ixRankCharacters", function(client)
	return ix.admin.MaxCharacters(client)
end)

--- Every rank, worst first, for a menu.
function ix.admin.SortedRanks()
	local out = {}

	for _, rank in pairs(ix.admin.ranks) do
		out[#out + 1] = rank
	end

	table.sort(out, function(a, b)
		if (a.immunity ~= b.immunity) then return a.immunity < b.immunity end

		return a.id < b.id
	end)

	return out
end

--[[
	Which rank a player is in.

	`ixGroup` is networked, so this answers the same on both realms - the menu
	draws a player list with everybody's rank on it, and asking the server per
	row would be a message per player per frame.

	IT FALLS BACK TO GMOD'S OWN GROUP, which is what lets the first person on a
	fresh server - a superadmin from `users.txt` and nothing else - promote
	themselves without editing a file.
]]
function ix.admin.GetRankID(client)
	if (not IsValid(client)) then return "root" end

	--- Checked before anything stored, so nothing stored can override it.
	if (client:SteamID64() == ix.admin.rootSteamID) then return "root" end

	local stored = client:GetNetVar("ixGroup")

	if (stored and ix.admin.ranks[stored]) then return stored end

	local native = client:GetUserGroup()

	if (ix.admin.ranks[native]) then return native end

	if (client:IsSuperAdmin()) then return "superadmin" end
	if (client:IsAdmin()) then return "admin" end

	return "user"
end

function ix.admin.GetRank(client)
	return ix.admin.Rank(ix.admin.GetRankID(client))
end

--- Kept under the old names, because the rest of the schema calls them.
ix.admin.GetGroupID = ix.admin.GetRankID
ix.admin.GetGroup = ix.admin.GetRank

--------------------------------------------------------------------------------
-- Permissions
--------------------------------------------------------------------------------

--[[
	Does a RANK have a permission? Walks up the inheritance chain.

	A rank that names a permission decides it, `true` or `false` - so a child
	can REVOKE something its parent grants, which is the thing a threshold
	model cannot express at all.

	`visited` guards against a cycle. Ranks are edited in a menu by people, and
	"moderator inherits admin inherits moderator" is a thing somebody will do
	eventually; without this it is an infinite loop and a hung server rather
	than a wrong answer.
]]
function ix.admin.RankCan(rankID, permission)
	local visited = {}

	while (rankID) do
		if (visited[rankID]) then return false end

		visited[rankID] = true

		local rank = ix.admin.ranks[rankID]

		if (not rank) then return false end

		--- The top rank has everything, including permissions added later.
		if (rank.root) then return true end

		local granted = rank.permissions and rank.permissions[permission]

		if (granted ~= nil) then return granted end

		rankID = rank.inherit
	end

	return false
end

--[[
	May this player do this? The one question the rest of the schema asks.

	A NIL OR INVALID CLIENT IS THE CONSOLE, and the console may do anything -
	commands run from the server console have no player, and refusing them
	would make the server unable to administer itself.
]]
function ix.admin.Can(client, permission)
	if (not IsValid(client)) then return true end

	return ix.admin.RankCan(ix.admin.GetRankID(client), permission)
end

--------------------------------------------------------------------------------
-- Authority
--------------------------------------------------------------------------------

--- How high up somebody sits. The console is above everyone.
function ix.admin.Immunity(client)
	if (not IsValid(client)) then return math.huge end

	return ix.admin.GetRank(client).immunity or 0
end

--- Kept under the old name, because the rest of the schema calls it.
ix.admin.Power = ix.admin.Immunity

--[[
	Can A act on B?

	STRICTLY GREATER, so equals cannot touch each other. Two admins undoing one
	another's decisions is the argument that ends with both of them banned, and
	it is the same rule the faction management uses for ranks.
]]
function ix.admin.Outranks(client, target)
	if (not IsValid(target)) then return true end
	if (client == target) then return true end

	return ix.admin.Immunity(client) > ix.admin.Immunity(target)
end

--- Every rank somebody may hand out - strictly below their own.
function ix.admin.AssignableBy(client)
	local immunity = ix.admin.Immunity(client)
	local out = {}

	for _, rank in ipairs(ix.admin.SortedRanks()) do
		--[[
			Strictly below, so nobody can promote somebody to their own level
			and then be unable to demote them again.
		]]
		if (rank.immunity < immunity) then out[#out + 1] = rank end
	end

	return out
end

--[[
	The longest ban a rank may hand out, in seconds. 0 means permanent.

	SAM's `ban_limit`, and worth having for the same reason: the difference
	between a moderator and an admin is usually not WHETHER they can ban but
	for how long.
]]
function ix.admin.BanLimit(client)
	if (not IsValid(client)) then return 0 end

	return ix.admin.GetRank(client).banLimit or 0
end

--------------------------------------------------------------------------------
-- The ranks a fresh server starts with
--------------------------------------------------------------------------------

--[[
	Written as GRANTS on top of a parent, which is how the inheritance earns
	its keep: `moderator` says only what a moderator adds to a helper.

	The `root` flag rather than a list of every permission, so a permission
	added tomorrow is one it has without anybody remembering to tick it.
]]
function ix.admin.DefaultRanks()
	return {
		user = {
			id = "user", name = "User", immunity = 0, native = "user",
			color = Color(200, 200, 200), permissions = {}
		},
		vip = {
			id = "vip", name = "VIP", inherit = "user", immunity = 10,
			native = "user", color = Color(120, 200, 255), permissions = {}
		},
		helper = {
			id = "helper", name = "Helper", inherit = "vip", immunity = 20,
			native = "user", color = Color(120, 220, 160),
			permissions = {
				["player.list"] = true,
				["player.inspect"] = true,
				["log.view"] = true,
				["log.chat"] = true
			}
		},
		moderator = {
			id = "moderator", name = "Moderator", inherit = "helper",
			immunity = 30, native = "user", color = Color(90, 180, 255),
			banLimit = 60 * 60 * 24 * 3,
			permissions = {
				["player.goto"] = true,
				["player.bring"] = true,
				["player.kick"] = true,
				["player.ban"] = true,
				["log.economy"] = true,
				["log.items"] = true,
				["log.admin"] = true,

				--[[
					The verbs a moderator needs to run a scene: stop somebody
					moving, put them back, put a fire out. The ones that change
					what a character HAS are admin.
				]]
				["player.ignite"] = true,
				["player.freeze"] = true,
				["player.respawn"] = true,
				["player.return"] = true,
				["player.blind"] = true,
				["player.warn"] = true,

				--[[
					MARKING SOMEBODY FOR DEATH is a moderator's call, because
					it is the answer to somebody breaking a rule in character
					and that is the situation a moderator is already handling.
					Collecting it costs levels and caps, so the command asks
					before it does anything - see `/pk`.
				]]
				["player.pk"] = true
			}
		},
		admin = {
			id = "admin", name = "Admin", inherit = "moderator",
			immunity = 40, native = "admin", color = Color(255, 160, 60),
			banLimit = 60 * 60 * 24 * 30,
			permissions = {
				["player.charedit"] = true,
				["item.spawn"] = true,

				--[[
					THE Q MENU, which nothing gated before `sv_sandbox.lua`
					existed. Granting it here rather than leaving it ungranted
					is deliberate: the permissions default to nobody, so
					shipping them unassigned would have taken the spawn menu
					away from the admins who use it daily and called that a
					security improvement.

					Ordinary players get none of these, which IS the change -
					sandbox hands everybody the whole spawn menu and Helix does
					not take it away.
				]]
				["spawn.prop"] = true,
				["spawn.weapon"] = true,
				["spawn.entity"] = true,
				["spawn.npc"] = true,
				["spawn.vehicle"] = true,
				["spawn.effect"] = true,
				["spawn.ragdoll"] = true,
				["spawn.tool"] = true,
				["spawn.physgun"] = true,
				["spawn.property"] = true,
				--[[
					CLEANING UP YOUR OWN PROPS is an admin's, wiping the map is
					a super admin's - `gmod_admin_cleanup` calls
					`game.CleanUpMap`, which takes every lootable, workbench,
					storage and capture point off the map at once. Most of it
					comes back on the next map load; none of it comes back
					before then.
				]]
				["cleanup.self"] = true,

				["tool.remover"] = true,
				["tool.duplicator"] = true,
				["tool.weld"] = true,
				["tool.permaprop"] = true,
				["money.give"] = true,
				["bench.config"] = true,
				["shop.config"] = true,
				["loot.config"] = true,
				["faction.manage"] = true,

				--[[
					BUILDING THE MAP. Zones, cap stashes, capture points, drop
					sites and door rules are all map furniture - an admin who
					can already spawn props and place workbenches is the same
					person who lays these out.

					The two that are NOT here are `zone.claim.force` and
					`door.worldtp`, which sit with the super admins below: one
					takes ground off a faction that earned it, and the other
					deletes something out of the map for good.
				]]
				["zone.edit"] = true,
				["point.edit"] = true,
				["door.edit"] = true,
				["orbital.force"] = true,

				--[[
					The verbs that change what somebody HAS, rather than manage
					a situation - those are moderator, below.
				]]
				["player.slay"] = true,
				["player.god"] = true,
				["player.strip"] = true,
				["player.health"] = true,
				["player.speed"] = true,

				--[[
					Removing a warning is an admin's job, not a moderator's -
					a record somebody can erase as easily as they can write it
					is not a record.
				]]
				["player.warn.remove"] = true
			}
		},
		superadmin = {
			id = "superadmin", name = "Super Admin", inherit = "admin",
			immunity = 50, native = "superadmin", color = Color(255, 90, 90),
			banLimit = 0,
			permissions = {
				["rank.manage"] = true,
				["dev.terminal"] = true,
				["server.config"] = true,

				--- See the note under `zone.edit` for why these two are here.
				["zone.claim.force"] = true,
				["door.worldtp"] = true,

				--- And the note under `cleanup.self` for this one.
				["cleanup.map"] = true
			}
		},
		root = {
			id = "root", name = "Root", inherit = "superadmin",
			immunity = 100, native = "superadmin",
			color = Color(255, 80, 200), banLimit = 0, root = true,
			permissions = {}
		}
	}
end

--[[
	The ranks that cannot be deleted or renamed out of existence.

	`user` is what everybody falls back to and `root` is the one that can undo
	a mistake, so a menu that could remove either is a menu that can lock the
	server. Everything between them is fair game.
]]
ix.admin.protected = {user = true, root = true}

--[[
	SEEDED HERE, IN THE SHARED FILE, and this is a load-order fix rather than a
	nicety.

	`libs/` is included in alphabetical order, so `cl_usergroups.lua` runs
	BEFORE `sh_usergroups.lua` - and it used to seed the defaults itself, which
	meant calling `ix.admin.DefaultRanks` a good forty files before that
	function existed. The result was an empty `ix.admin.ranks` on the client,
	and the admin menu died on

	    attempt to index a nil value

	the first time it asked what rank anybody was.

	Doing it here means both realms have a sane ladder the instant this file
	has finished, whatever loads next. The server replaces it from `ix.data`
	on `LoadData`; the client replaces it when the server's copy arrives.
]]
if (table.IsEmpty(ix.admin.ranks)) then
	ix.admin.ranks = ix.admin.DefaultRanks()
end
