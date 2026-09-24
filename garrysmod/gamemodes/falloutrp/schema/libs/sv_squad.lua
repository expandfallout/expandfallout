--[[
	Squads, the server's half: the squads themselves, who is in them, and
	every change to that.

	EVERY ANSWER IS A STRING FOR THE PERSON WHO ASKED. The commands in
	`sh_squad.lua` return whatever these return, so a function here says what
	went wrong in words rather than in a boolean somebody has to translate.
	Nil means it worked and the person has already been told.

	See `sh_squad.lua` for the shape of a squad and why its people are
	character ids.
]]

if (not SERVER) then return end

util.AddNetworkString("ixSquadSync")
util.AddNetworkString("ixSquadInvite")
util.AddNetworkString("ixSquadAct")
util.AddNetworkString("ixSquadMenu")

--- `[id] = squad`. A squad is `{id, name, color, leader, officers, members,
--- names, levels, created}`; the last five are keyed by character id.
ix.squad.list = ix.squad.list or {}

--- `[characterID] = squadID`, so "which squad" is a lookup and not a loop.
ix.squad.byMember = ix.squad.byMember or {}

--- `[characterID] = {squad, from, fromID, expires}`. Memory only.
ix.squad.invites = ix.squad.invites or {}

--------------------------------------------------------------------------------
-- Saving them
--------------------------------------------------------------------------------

local KEY = "squads"
local loaded = false
local nextID = 1

local function Index()
	ix.squad.byMember = {}

	for id, squad in pairs(ix.squad.list) do
		squad.id = id
		squad.officers = squad.officers or {}
		squad.members = squad.members or {}
		squad.names = squad.names or {}
		squad.levels = squad.levels or {}

		for member in pairs(squad.members) do
			ix.squad.byMember[member] = id
		end

		if (id >= nextID) then nextID = id + 1 end
	end
end

function ix.squad.Save()
	if (not loaded) then return end

	ix.data.Set(KEY, {list = ix.squad.list, next = nextID}, false, true)
end

--[[
	Loaded the way every persistent table in this schema is - from
	`LoadData`, again from `PostLoadData`, and once on a timer for a reload
	that fires neither. `InitPostEntity` never fires in the schema.

	JSON TURNS NUMERIC KEYS INTO STRINGS, and every key here is a character
	id. They are turned back on the way in, or a squad saved with member
	`{[42] = true}` comes back as `{["42"] = true}` and nobody is in it.
]]
local function Renumber(set)
	local out = {}

	for key, value in pairs(set or {}) do
		out[tonumber(key) or key] = value
	end

	return out
end

function ix.squad.Load()
	if (loaded) then return end

	local saved = ix.data.Get(KEY, nil, false, true)
	local list = {}

	for key, squad in pairs(saved and saved.list or {}) do
		local id = tonumber(key)

		if (id and istable(squad)) then
			squad.leader = tonumber(squad.leader)
			squad.officers = Renumber(squad.officers)
			squad.members = Renumber(squad.members)
			squad.names = Renumber(squad.names)
			squad.levels = Renumber(squad.levels)

			list[id] = squad
		end
	end

	ix.squad.list = list
	nextID = tonumber(saved and saved.next) or 1
	loaded = true

	Index()
end

hook.Add("LoadData", "ixSquad", ix.squad.Load)
hook.Add("PostLoadData", "ixSquad", ix.squad.Load)
timer.Simple(10, ix.squad.Load)

--------------------------------------------------------------------------------
-- Finding people
--------------------------------------------------------------------------------

--- The player currently playing a character, or nil.
function ix.squad.PlayerOf(id)
	if (not id) then return nil end

	for _, client in player.Iterator() do
		local character = client:GetCharacter()

		if (character and character:GetID() == id) then return client end
	end

	return nil
end

--- Everybody in a squad who is online.
function ix.squad.Online(squad)
	local out = {}

	for id in pairs(squad.members) do
		local client = ix.squad.PlayerOf(id)

		if (IsValid(client)) then out[#out + 1] = client end
	end

	return out
end

--- A squad by name, case-insensitively.
function ix.squad.Find(name)
	name = string.lower(string.Trim(name or ""))

	if (name == "") then return nil end

	for _, squad in pairs(ix.squad.list) do
		if (string.lower(squad.name) == name) then return squad end
	end

	return nil
end

--- What a character is called, from the player if they are here.
local function NameOf(squad, id)
	local client = ix.squad.PlayerOf(id)

	if (IsValid(client)) then
		local character = client:GetCharacter()

		squad.names[id] = character:GetName()
		squad.levels[id] = character.GetLevel and character:GetLevel() or 1
	end

	return squad.names[id] or "Somebody"
end

--- Tell everybody in the squad who is here something.
local function Tell(squad, text, except)
	for _, client in ipairs(ix.squad.Online(squad)) do
		if (client ~= except) then client:Notify(text) end
	end
end

--------------------------------------------------------------------------------
-- Telling the clients
--------------------------------------------------------------------------------

--[[
	What a client is sent about its own squad. A roster rather than the sets,
	ordered leader first, so the HUD draws it in that order without sorting
	every frame - and with each person's name and level, so a bot or somebody
	offline reads the same as anyone else.
]]
function ix.squad.Payload(squad)
	local roster = {}

	for id in pairs(squad.members) do
		local client = ix.squad.PlayerOf(id)

		roster[#roster + 1] = {
			id = id,
			name = NameOf(squad, id),
			rank = ix.squad.RankIn(squad, id),
			online = IsValid(client),
			level = squad.levels[id] or 1
		}
	end

	table.sort(roster, function(a, b)
		if (a.rank ~= b.rank) then return a.rank > b.rank end
		if (a.online ~= b.online) then return a.online end

		return a.name < b.name
	end)

	return {
		id = squad.id,
		name = squad.name,
		color = squad.color,
		leader = squad.leader,
		created = squad.created,
		roster = roster
	}
end

--- One player is told they are in no squad.
function ix.squad.SyncNone(client)
	if (not IsValid(client)) then return end

	net.Start("ixSquadSync")
		net.WriteBool(false)
	net.Send(client)
end

--- Everybody in a squad who is online gets its current state.
function ix.squad.Sync(squad)
	local online = ix.squad.Online(squad)

	if (#online == 0) then return end

	local payload = ix.squad.Payload(squad)

	net.Start("ixSquadSync")
		net.WriteBool(true)
		net.WriteTable(payload)
	net.Send(online)
end

--- One player gets whatever squad they are in, or told they are in none.
function ix.squad.SyncPlayer(client)
	local squad = ix.squad.Get(client)

	if (squad) then
		net.Start("ixSquadSync")
			net.WriteBool(true)
			net.WriteTable(ix.squad.Payload(squad))
		net.Send(client)
	else
		ix.squad.SyncNone(client)
	end
end

function ix.squad.OpenMenu(client)
	if (not IsValid(client)) then return end

	ix.squad.SyncPlayer(client)

	net.Start("ixSquadMenu")
	net.Send(client)
end

--------------------------------------------------------------------------------
-- Making and unmaking
--------------------------------------------------------------------------------

function ix.squad.Create(client, name)
	local character = client:GetCharacter()

	if (not character) then return "You are not anybody yet." end
	if (ix.squad.Get(client)) then return "You are already in a squad." end

	local clean, why = ix.squad.CleanName(name)

	if (not clean) then return why end
	if (ix.squad.Find(clean)) then return "There is already a squad called that." end

	local id = nextID

	nextID = nextID + 1

	local squad = {
		id = id,
		name = clean,
		color = ((id - 1) % #ix.squad.palette) + 1,
		leader = character:GetID(),
		officers = {},
		members = {[character:GetID()] = true},
		names = {[character:GetID()] = character:GetName()},
		levels = {[character:GetID()] = character.GetLevel
			and character:GetLevel() or 1},
		created = os.time()
	}

	ix.squad.list[id] = squad
	ix.squad.byMember[character:GetID()] = id

	ix.squad.Save()
	ix.squad.Sync(squad)

	client:Notify("You formed the squad '" .. clean .. "'.")
	ix.log.Add(client, "squadCreate", clean)
	hook.Run("SquadCreated", squad, client)
end

--- Gone entirely. Everybody in it is told and cleared.
function ix.squad.Delete(squad, why)
	for _, client in ipairs(ix.squad.Online(squad)) do
		ix.squad.SyncNone(client)

		if (why) then client:Notify(why) end
	end

	for id in pairs(squad.members) do
		if (ix.squad.byMember[id] == squad.id) then ix.squad.byMember[id] = nil end
	end

	ix.squad.list[squad.id] = nil

	ix.squad.Save()
	hook.Run("SquadDeleted", squad)
end

function ix.squad.Disband(client)
	local squad = ix.squad.Get(client)

	if (not squad) then return "You are not in a squad." end

	if (ix.squad.Rank(client) < ix.squad.LEADER) then
		return "Only the leader can disband a squad."
	end

	local name = squad.name

	ix.squad.Delete(squad, "The squad '" .. name .. "' was disbanded.")
	ix.log.Add(client, "squadDisband", name)
end

--------------------------------------------------------------------------------
-- Joining and leaving
--------------------------------------------------------------------------------

--[[
	Somebody into a squad, whichever door they came through. `bForce` waives
	the size limit, because staff putting somebody in a squad have decided
	that already.
]]
function ix.squad.AddMember(squad, client, bForce)
	local character = client:GetCharacter()

	if (not character) then return "They are not anybody yet." end

	local id = character:GetID()

	if (squad.members[id]) then return "They are already in it." end

	if (not bForce and table.Count(squad.members)
	>= ix.config.Get("squadMaxSize", 8)) then
		return "The squad is full."
	end

	local before = ix.squad.SquadOfCharacter(id)

	if (before) then
		ix.squad.RemoveMember(before, id,
			"You left the squad '" .. before.name .. "'.")
	end

	squad.members[id] = true
	squad.names[id] = character:GetName()
	squad.levels[id] = character.GetLevel and character:GetLevel() or 1
	ix.squad.byMember[id] = squad.id
	ix.squad.invites[id] = nil

	ix.squad.Save()

	Tell(squad, character:GetName() .. " joined the squad.", client)
	client:Notify("You are in the squad '" .. squad.name .. "'.")

	ix.squad.Sync(squad)
	ix.log.Add(client, "squadJoin", squad.name)
	hook.Run("SquadMemberAdded", squad, id, client)
end

--[[
	Who takes over when the leader goes: an officer who is here, then any
	officer, then a member who is here, then anybody. Nobody means the squad
	is finished.
]]
local function Heir(squad)
	local best, bestScore

	for id in pairs(squad.members) do
		if (id ~= squad.leader) then
			local score = (squad.officers[id] and 2 or 0)
				+ (IsValid(ix.squad.PlayerOf(id)) and 1 or 0)

			if (not bestScore or score > bestScore) then
				best, bestScore = id, score
			end
		end
	end

	return best
end

--[[
	Somebody out of a squad, whichever door. `why` is what they are told.
	Returns false if they were not in it; a squad left with nobody in it is
	deleted, and a squad that lost its leader gets a new one.
]]
function ix.squad.RemoveMember(squad, id, why)
	if (not squad.members[id]) then return false end

	local name = NameOf(squad, id)
	local client = ix.squad.PlayerOf(id)

	squad.members[id] = nil
	squad.officers[id] = nil

	if (ix.squad.byMember[id] == squad.id) then ix.squad.byMember[id] = nil end

	if (IsValid(client)) then
		ix.squad.SyncNone(client)

		if (why) then client:Notify(why) end
	end

	if (squad.leader == id) then
		local heir = Heir(squad)

		if (not heir) then
			ix.squad.Delete(squad)

			return true
		end

		squad.leader = heir
		squad.officers[heir] = nil

		Tell(squad, NameOf(squad, heir) .. " now leads the squad.")
	end

	ix.squad.Save()
	ix.squad.Sync(squad)
	hook.Run("SquadMemberRemoved", squad, id, name)

	return true
end

function ix.squad.Leave(client)
	local squad = ix.squad.Get(client)

	if (not squad) then return "You are not in a squad." end

	local name = squad.name

	ix.squad.RemoveMember(squad, ix.squad.CharacterID(client),
		"You left the squad '" .. name .. "'.")

	if (ix.squad.list[squad.id]) then
		Tell(squad, client:Name() .. " left the squad.")
	end

	ix.log.Add(client, "squadLeave", name)
end

--------------------------------------------------------------------------------
-- Invitations
--------------------------------------------------------------------------------

function ix.squad.Invite(client, target)
	local squad = ix.squad.Get(client)

	if (not squad) then return "You are not in a squad." end

	if (ix.squad.Rank(client) < ix.squad.OFFICER) then
		return "Only the leader and the officers can invite people."
	end

	if (not IsValid(target) or not target:IsPlayer() or target == client) then
		return "Invite somebody else."
	end

	local id = ix.squad.CharacterID(target)

	if (not id) then return "They are not anybody yet." end
	if (squad.members[id]) then return "They are already in your squad." end

	if (ix.squad.SquadOfCharacter(id)) then
		return "They are in another squad. They have to leave it first."
	end

	if (table.Count(squad.members) >= ix.config.Get("squadMaxSize", 8)) then
		return "The squad is full."
	end

	local pending = ix.squad.invites[id]

	if (pending and pending.squad == squad.id and pending.expires > CurTime()) then
		return "They already have an invitation from your squad."
	end

	local seconds = ix.config.Get("squadInviteTime", 30)

	ix.squad.invites[id] = {
		squad = squad.id,
		from = client:Name(),
		fromID = ix.squad.CharacterID(client),
		expires = CurTime() + seconds
	}

	net.Start("ixSquadInvite")
		net.WriteTable({
			squad = squad.name,
			color = squad.color,
			from = client:Name(),
			seconds = seconds
		})
	net.Send(target)

	return "You invited " .. target:Name() .. " to the squad."
end

function ix.squad.Accept(client)
	local id = ix.squad.CharacterID(client)
	local invite = id and ix.squad.invites[id]

	if (not invite) then return "Nobody has invited you to a squad." end

	ix.squad.invites[id] = nil

	if (invite.expires < CurTime()) then return "That invitation has expired." end

	local squad = ix.squad.list[invite.squad]

	if (not squad) then return "That squad no longer exists." end

	return ix.squad.AddMember(squad, client)
end

function ix.squad.Decline(client)
	local id = ix.squad.CharacterID(client)

	if (not id or not ix.squad.invites[id]) then
		return "Nobody has invited you to a squad."
	end

	local invite = ix.squad.invites[id]

	ix.squad.invites[id] = nil

	local from = ix.squad.PlayerOf(invite.fromID)

	if (IsValid(from)) then
		from:Notify(client:Name() .. " turned down the invitation.")
	end

	return "You turned the invitation down."
end

--------------------------------------------------------------------------------
-- Rank
--------------------------------------------------------------------------------

--- The squad and both ranks, or a reason. Shared by everything below.
local function Both(client, id)
	local squad = ix.squad.Get(client)

	if (not squad) then return nil, "You are not in a squad." end
	if (not id or not squad.members[id]) then
		return nil, "They are not in your squad."
	end

	return squad, ix.squad.Rank(client), ix.squad.RankIn(squad, id)
end

function ix.squad.Kick(client, id)
	local squad, mine, theirs = Both(client, id)

	if (not squad) then return mine end
	if (id == ix.squad.CharacterID(client)) then return "Use /squadleave." end

	if (mine < ix.squad.OFFICER or theirs >= mine) then
		return "You cannot remove them."
	end

	local who = NameOf(squad, id)

	ix.squad.RemoveMember(squad, id,
		"You were removed from the squad '" .. squad.name .. "'.")

	if (ix.squad.list[squad.id]) then
		Tell(squad, who .. " was removed from the squad.")
	end

	ix.log.Add(client, "squadKick", who, squad.name)
end

--- Member to officer; officer to leader, the old leader becoming an officer.
function ix.squad.Promote(client, id)
	local squad, mine, theirs = Both(client, id)

	if (not squad) then return mine end

	if (mine < ix.squad.LEADER) then
		return "Only the leader can promote people."
	end

	if (theirs == ix.squad.LEADER) then return "That is you." end

	local who = NameOf(squad, id)

	if (theirs == ix.squad.OFFICER) then
		return ix.squad.Transfer(client, id)
	end

	squad.officers[id] = true

	ix.squad.Save()
	ix.squad.Sync(squad)

	Tell(squad, who .. " is now an officer of the squad.")
	ix.log.Add(client, "squadRank", who, "an officer", squad.name)
end

function ix.squad.Demote(client, id)
	local squad, mine, theirs = Both(client, id)

	if (not squad) then return mine end

	if (mine < ix.squad.LEADER) then
		return "Only the leader can demote people."
	end

	if (theirs ~= ix.squad.OFFICER) then return "They are not an officer." end

	local who = NameOf(squad, id)

	squad.officers[id] = nil

	ix.squad.Save()
	ix.squad.Sync(squad)

	Tell(squad, who .. " is a member of the squad again.")
	ix.log.Add(client, "squadRank", who, "a member", squad.name)
end

function ix.squad.Transfer(client, id)
	local squad, mine, theirs = Both(client, id)

	if (not squad) then return mine end

	if (mine < ix.squad.LEADER) then
		return "Only the leader can hand the squad on."
	end

	if (theirs == ix.squad.LEADER) then return "That is you." end

	local who = NameOf(squad, id)
	local old = squad.leader

	squad.leader = id
	squad.officers[id] = nil
	squad.officers[old] = true

	ix.squad.Save()
	ix.squad.Sync(squad)

	Tell(squad, who .. " now leads the squad.")
	ix.log.Add(client, "squadRank", who, "the leader", squad.name)
end

--------------------------------------------------------------------------------
-- Name and colour
--------------------------------------------------------------------------------

function ix.squad.Rename(client, name)
	local squad = ix.squad.Get(client)

	if (not squad) then return "You are not in a squad." end

	if (ix.squad.Rank(client) < ix.squad.LEADER) then
		return "Only the leader can rename the squad."
	end

	local clean, why = ix.squad.CleanName(name)

	if (not clean) then return why end

	local taken = ix.squad.Find(clean)

	if (taken and taken ~= squad) then
		return "There is already a squad called that."
	end

	squad.name = clean

	ix.squad.Save()
	ix.squad.Sync(squad)

	Tell(squad, "The squad is now called '" .. clean .. "'.")
end

function ix.squad.SetColor(client, index)
	local squad = ix.squad.Get(client)

	if (not squad) then return "You are not in a squad." end

	if (ix.squad.Rank(client) < ix.squad.LEADER) then
		return "Only the leader can pick the colour."
	end

	index = math.floor(tonumber(index) or 0)

	if (not ix.squad.palette[index]) then
		return "Pick a colour from 1 to " .. #ix.squad.palette .. "."
	end

	squad.color = index

	ix.squad.Save()
	ix.squad.Sync(squad)
end

--------------------------------------------------------------------------------
-- Staff
--------------------------------------------------------------------------------

--[[
	Into the squad named, or into the admin's own. Size does not apply: staff
	putting somebody in a squad have decided that already, and the squad's
	people are told who did it.
]]
function ix.squad.Force(admin, target, name)
	if (not ix.admin.Can(admin, "squad.force")) then return "No." end

	local squad

	if (name and string.Trim(name) ~= "") then
		squad = ix.squad.Find(name)

		if (not squad) then return "There is no squad called that." end
	else
		squad = ix.squad.Get(admin)

		if (not squad) then
			return "Name a squad, or be in one to put them in yours."
		end
	end

	local id = ix.squad.CharacterID(target)

	if (squad.members[id]) then return "They are already in it." end

	local why = ix.squad.AddMember(squad, target, true)

	if (why) then return why end

	ix.admin.Announce(admin, string.format("%s put %s in the squad '%s'.",
		admin:Name(), target:Name(), squad.name))
	ix.log.Add(admin, "squadForce", target:Name(), squad.name)
end

function ix.squad.ForceRemove(admin, target)
	if (not ix.admin.Can(admin, "squad.force")) then return "No." end

	local squad = ix.squad.Get(target)

	if (not squad) then return "They are not in a squad." end

	local name = squad.name

	ix.squad.RemoveMember(squad, ix.squad.CharacterID(target),
		"You were removed from the squad '" .. name .. "' by staff.")

	if (ix.squad.list[squad.id]) then
		Tell(squad, target:Name() .. " was removed from the squad by staff.")
	end

	ix.admin.Announce(admin, string.format("%s took %s out of the squad '%s'.",
		admin:Name(), target:Name(), name))
	ix.log.Add(admin, "squadForce", target:Name(), nil)
end

--------------------------------------------------------------------------------
-- The window asking for things
--------------------------------------------------------------------------------

--[[
	One message for everything the squad window can do, dispatched by name
	and validated by the same functions the commands use - there is no
	second permission check to get out of step. `id` is a character id, so
	the window can act on somebody who is offline, which a player-name
	command cannot.
]]
local actions = {
	accept = function(client) return ix.squad.Accept(client) end,
	decline = function(client) return ix.squad.Decline(client) end,
	leave = function(client) return ix.squad.Leave(client) end,
	disband = function(client) return ix.squad.Disband(client) end,
	kick = function(client, id) return ix.squad.Kick(client, id) end,
	promote = function(client, id) return ix.squad.Promote(client, id) end,
	demote = function(client, id) return ix.squad.Demote(client, id) end,
	leader = function(client, id) return ix.squad.Transfer(client, id) end,
	rename = function(client, _, text) return ix.squad.Rename(client, text) end,
	color = function(client, id) return ix.squad.SetColor(client, id) end,

	create = function(client, _, text)
		if (not ix.config.Get("squadEnabled", true)) then
			return "Squads are switched off."
		end

		return ix.squad.Create(client, text)
	end,

	invite = function(client, _, text)
		local target = ix.util.FindPlayer(text)

		if (not IsValid(target)) then return "Nobody by that name is here." end

		return ix.squad.Invite(client, target)
	end
}

net.Receive("ixSquadAct", function(_, client)
	if ((client.ixSquadNext or 0) > CurTime()) then return end

	client.ixSquadNext = CurTime() + 0.2

	local action = actions[net.ReadString()]
	local id = net.ReadUInt(32)
	local text = net.ReadString()

	if (not action) then return end

	local said = action(client, id > 0 and id or nil, text)

	if (said) then client:Notify(said) end
end)

--------------------------------------------------------------------------------
-- People coming and going
--------------------------------------------------------------------------------

--[[
	A squad's picture of who is here changes when anybody in it loads a
	character, switches away from one, or leaves - and the person themselves
	needs to be told which squad they are in, if any, every time they become
	somebody.
]]
hook.Add("PlayerLoadedCharacter", "ixSquad", function(client, character, old)
	if (old) then
		local before = ix.squad.SquadOfCharacter(old:GetID())

		if (before) then ix.squad.Sync(before) end
	end

	local squad = ix.squad.SquadOfCharacter(character:GetID())

	if (squad) then
		squad.names[character:GetID()] = character:GetName()
		squad.levels[character:GetID()] = character.GetLevel
			and character:GetLevel() or 1

		ix.squad.Sync(squad)
	else
		ix.squad.SyncNone(client)
	end
end)

hook.Add("OnCharacterDisconnect", "ixSquad", function(client, character)
	local squad = character and ix.squad.SquadOfCharacter(character:GetID())

	if (IsValid(client)) then ix.squad.SyncNone(client) end

	if (squad) then
		timer.Simple(0, function()
			if (ix.squad.list[squad.id]) then ix.squad.Sync(squad) end
		end)
	end
end)

hook.Add("PlayerDisconnected", "ixSquad", function(client)
	local squad = ix.squad.Get(client)

	if (not squad) then return end

	timer.Simple(0, function()
		if (ix.squad.list[squad.id]) then ix.squad.Sync(squad) end
	end)
end)

--- A deleted character is nobody's squad mate.
hook.Add("CharacterDeleted", "ixSquad", function(client, id)
	local squad = ix.squad.SquadOfCharacter(tonumber(id))

	if (squad) then ix.squad.RemoveMember(squad, tonumber(id)) end
end)
