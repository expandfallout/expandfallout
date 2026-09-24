--[[
	Squads.

	Phoenix's `plugins/squads` is forty-four shared lines and a HUD: a squad
	is a name, a leader and a set of players, made with `/squadcreate`, left
	with `/squadleave`, handed on with `/squadpromote`, and gone the moment
	the server restarts. Invites, kicks and "force to squad" hang off their
	hold-E menu, with every check on the client.

	This keeps that shape - the same commands, the same corner of the screen,
	the same over-the-head markers - and does the rest properly:

	    it lasts        squads are saved by CHARACTER, so a squad survives a
	                    restart and a member survives logging off; they are
	                    listed as offline until they are back
	    it has ranks    a leader, officers who can invite and kick members,
	                    and members. `/squadpromote` lifts a member to
	                    officer and an officer to leader
	    it talks        `/sq` is a channel only the squad hears, in the
	                    squad's colour
	    it knows you    squad mates always recognise each other
	    it is staffed   `/forcesquad` and `/forcesquadremove` on whoever you
	                    are looking at, behind `squad.force`, and they say so
	                    in staff chat like every other moderation command
	    it is checked   every action is validated on the server - the client
	                    only ever asks

	WHO IS WHO: a squad's people are character ids, never players or Steam
	ids. A player is one character at a time and a character is one person,
	so switching character leaves the squad behind on the one that joined it,
	which is the only answer that does not put a Legion officer in an NCR
	squad because somebody has two characters.

	This file is the shared half - the rules, the commands, the chat class,
	the hold-E entries. `sv_squad.lua` owns the squads; `cl_squad.lua` draws
	them; `derma/cl_squad.lua` is the window.
]]

ix.squad = ix.squad or {}

--------------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------------

ix.config.Add("squadEnabled", true, "Whether players can form squads.", nil,
	{category = "Squads"})

ix.config.Add("squadMaxSize", 8, "How many people one squad can hold.", nil,
	{data = {min = 2, max = 32}, category = "Squads"})

ix.config.Add("squadInviteTime", 30,
	"Seconds an invitation to a squad stays open.", nil,
	{data = {min = 5, max = 300}, category = "Squads"})

if (ix.admin and ix.admin.RegisterPermission) then
	ix.admin.RegisterPermission("squad.force",
		"Force people into and out of squads", "Staff")
end

--------------------------------------------------------------------------------
-- Ranks and colours
--------------------------------------------------------------------------------

ix.squad.MEMBER = 1
ix.squad.OFFICER = 2
ix.squad.LEADER = 3

ix.squad.rankNames = {
	[ix.squad.MEMBER] = "Member",
	[ix.squad.OFFICER] = "Officer",
	[ix.squad.LEADER] = "Leader"
}

--- What goes after a name on the HUD. A member gets nothing.
ix.squad.rankMarks = {
	[ix.squad.OFFICER] = "◆",
	[ix.squad.LEADER] = "★"
}

--[[
	The colours a squad can be, by index - an index rather than a colour so
	the save is a number and a leader picks from a list that all reads well
	on the HUD. A new squad takes the next one along.
]]
ix.squad.palette = {
	{name = "Amber", color = Color(255, 182, 66)},
	{name = "Ember", color = Color(232, 92, 58)},
	{name = "Rust", color = Color(200, 128, 64)},
	{name = "Moss", color = Color(126, 180, 84)},
	{name = "Pip", color = Color(64, 224, 128)},
	{name = "Sky", color = Color(96, 172, 240)},
	{name = "Violet", color = Color(172, 116, 232)},
	{name = "Rose", color = Color(240, 116, 164)},
	{name = "Bone", color = Color(230, 224, 200)},
	{name = "Steel", color = Color(156, 166, 180)}
}

--- A squad's colour, safely - an out-of-range index is the first one.
function ix.squad.ColorOf(squad)
	local entry = squad and ix.squad.palette[squad.color or 1]

	return entry and entry.color or ix.squad.palette[1].color
end

--[[
	A name somebody may give a squad.

	Trimmed, single-spaced, no control characters, three to twenty-four
	characters. Returns the cleaned name, or nil and the reason.
]]
function ix.squad.CleanName(name)
	name = tostring(name or "")
	name = (string.gsub(name, "[%c]", ""))
	name = (string.gsub(name, "%s+", " "))
	name = string.Trim(name)

	if (#name < 3) then
		return nil, "A squad name needs at least three characters."
	end

	if (#name > 24) then
		return nil, "A squad name can be twenty-four characters at most."
	end

	return name
end

--------------------------------------------------------------------------------
-- Asking about one
--------------------------------------------------------------------------------

--[[
	The character a player is playing, as an id.

	`GetNetVar("char")` rather than `GetCharacter():GetID()` so the answer is
	the same for a bot on a client that never loaded its character table -
	the id is networked with the player; the table is not always.
]]
function ix.squad.CharacterID(client)
	if (not IsValid(client) or not client:IsPlayer()) then return nil end

	local character = client:GetCharacter()

	if (character) then return character:GetID() end

	return client:GetNetVar("char")
end

--- Somebody's rank in a squad, or 0 for not in it. Shared shape, see below.
function ix.squad.RankIn(squad, id)
	if (not squad or not id) then return 0 end
	if (squad.leader == id) then return ix.squad.LEADER end
	if (squad.officers and squad.officers[id]) then return ix.squad.OFFICER end
	if (squad.members and squad.members[id]) then return ix.squad.MEMBER end

	return 0
end

--[[
	The squad a character is in, on either side.

	The server has every squad; a client has only its own, which is the only
	one it is ever asked about - the HUD, the menu, the hold-E entries and
	recognition all concern people in the SAME squad as the person looking.
	Both keep the same shape: `members` and `officers` are sets of character
	ids and `leader` is one, so `RankIn` reads either.
]]
function ix.squad.SquadOfCharacter(id)
	if (not id) then return nil end

	if (SERVER) then
		local squadID = ix.squad.byMember and ix.squad.byMember[id]

		return squadID and ix.squad.list and ix.squad.list[squadID] or nil
	end

	local mine = ix.squad.mine

	return (mine and ix.squad.RankIn(mine, id) > 0) and mine or nil
end

--- The squad a player is in, or nil.
function ix.squad.Get(client)
	return ix.squad.SquadOfCharacter(ix.squad.CharacterID(client))
end

--- A player's rank in their squad, or 0.
function ix.squad.Rank(client)
	return ix.squad.RankIn(ix.squad.Get(client), ix.squad.CharacterID(client))
end

--- Whether two players are in one squad.
function ix.squad.Same(a, b)
	local squad = ix.squad.Get(a)

	return squad ~= nil and squad == ix.squad.Get(b)
end

--------------------------------------------------------------------------------
-- Squad mates know each other
--------------------------------------------------------------------------------

--[[
	Helix asks this from `character:DoesRecognize`, on both sides, and the
	first listener to answer wins - so this answers ONLY yes. Anybody not in
	the same squad falls through to the recognition plugin as before.
]]
hook.Add("IsCharacterRecognized", "ixSquad", function(character, id)
	if (not character or not id) then return end

	local squad = ix.squad.SquadOfCharacter(character:GetID())

	if (squad and ix.squad.RankIn(squad, id) > 0) then return true end
end)

--------------------------------------------------------------------------------
-- Squad chat
--------------------------------------------------------------------------------

--[[
	`/sq hold the door` - heard by the squad and nobody else, alive or dead,
	at any range. The tag is drawn in the squad's colour, which is the same
	colour its HUD and its markers use, so a line in chat reads as coming
	from the people on the left of the screen.
]]
ix.chat.Register("squad", {
	prefix = {"/sq", "/squadsay"},
	deadCanChat = true,

	CanSay = function(self, speaker, text)
		if (not ix.squad.Get(speaker)) then
			if (SERVER) then speaker:Notify("You are not in a squad.") end

			return false
		end

		return true
	end,

	CanHear = function(self, speaker, listener)
		return ix.squad.Same(speaker, listener)
	end,

	OnChatAdd = function(self, speaker, text)
		local color = ix.squad.ColorOf(ix.squad.Get(speaker))

		chat.AddText(color, "[SQUAD] ", color_white,
			(IsValid(speaker) and speaker:Name() or "Someone") .. ": " .. text)
	end
})

--------------------------------------------------------------------------------
-- Commands
--------------------------------------------------------------------------------

--[[
	Every command body lives in `sv_squad.lua` and answers with a string for
	the person who typed it; the definitions are here so the chat's command
	list knows them on the client. Each returns whatever the server said.
]]
local function Enabled()
	if (not ix.config.Get("squadEnabled", true)) then
		return false, "Squads are switched off."
	end

	return true
end

ix.command.Add("SquadCreate", {
	description = "Form a squad with the name you give it.",
	arguments = {ix.type.text},

	OnRun = function(self, client, name)
		if (CLIENT) then return end

		local ok, why = Enabled()

		if (not ok) then return why end

		return ix.squad.Create(client, name)
	end
})

ix.command.Add("SquadDisband", {
	description = "Dissolve your squad. Leader only.",

	OnRun = function(self, client)
		if (CLIENT) then return end

		return ix.squad.Disband(client)
	end
})

ix.command.Add("SquadLeave", {
	description = "Leave your squad.",

	OnRun = function(self, client)
		if (CLIENT) then return end

		return ix.squad.Leave(client)
	end
})

ix.command.Add("SquadRename", {
	description = "Rename your squad. Leader only.",
	arguments = {ix.type.text},

	OnRun = function(self, client, name)
		if (CLIENT) then return end

		return ix.squad.Rename(client, name)
	end
})

ix.command.Add("SquadColor", {
	description = "Pick your squad's colour, 1-10. Leader only.",
	alias = {"SquadColour"},
	arguments = {ix.type.number},

	OnRun = function(self, client, index)
		if (CLIENT) then return end

		return ix.squad.SetColor(client, index)
	end
})

ix.command.Add("SquadInvite", {
	description = "Invite somebody to your squad. Leader or officer.",
	arguments = {ix.type.player},

	OnRun = function(self, client, target)
		if (CLIENT) then return end

		return ix.squad.Invite(client, target)
	end
})

ix.command.Add("SquadAccept", {
	description = "Accept the squad invitation you were sent.",

	OnRun = function(self, client)
		if (CLIENT) then return end

		return ix.squad.Accept(client)
	end
})

ix.command.Add("SquadDecline", {
	description = "Turn down the squad invitation you were sent.",

	OnRun = function(self, client)
		if (CLIENT) then return end

		return ix.squad.Decline(client)
	end
})

ix.command.Add("SquadKick", {
	description = "Remove somebody from your squad. Leader or officer.",
	arguments = {ix.type.player},

	OnRun = function(self, client, target)
		if (CLIENT) then return end

		return ix.squad.Kick(client, ix.squad.CharacterID(target))
	end
})

ix.command.Add("SquadPromote", {
	description = "Make a member an officer, or an officer the leader.",
	arguments = {ix.type.player},

	OnRun = function(self, client, target)
		if (CLIENT) then return end

		return ix.squad.Promote(client, ix.squad.CharacterID(target))
	end
})

ix.command.Add("SquadDemote", {
	description = "Make an officer a member again. Leader only.",
	arguments = {ix.type.player},

	OnRun = function(self, client, target)
		if (CLIENT) then return end

		return ix.squad.Demote(client, ix.squad.CharacterID(target))
	end
})

ix.command.Add("SquadLeader", {
	description = "Hand the squad to somebody else. Leader only.",
	arguments = {ix.type.player},

	OnRun = function(self, client, target)
		if (CLIENT) then return end

		return ix.squad.Transfer(client, ix.squad.CharacterID(target))
	end
})

ix.command.Add("Squad", {
	description = "Open the squad window.",
	alias = {"Squads", "SquadMenu"},

	OnRun = function(self, client)
		if (CLIENT) then return end

		ix.squad.OpenMenu(client)
	end
})

--[[
	THE PERSON YOU ARE LOOKING AT, which is what was asked for and is also
	the right shape: staff sorting out a squad are stood in front of the
	people involved. A name argument would be a second way to say the same
	thing and a second thing to get wrong.
]]
local function LookedAt(client)
	local target = client:GetEyeTrace().Entity

	if (not IsValid(target) or not target:IsPlayer()) then
		return nil, "Look at somebody."
	end

	if (not target:GetCharacter()) then
		return nil, "They are not anybody yet."
	end

	return target
end

ix.command.Add("ForceSquad", {
	description = "Put the person you are looking at in a squad - the one "
		.. "you name, or your own.",
	arguments = {bit.bor(ix.type.text, ix.type.optional)},

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "squad.force")
	end,

	OnRun = function(self, client, name)
		if (CLIENT) then return end

		local target, why = LookedAt(client)

		if (not target) then return why end

		return ix.squad.Force(client, target, name)
	end
})

ix.command.Add("ForceSquadRemove", {
	description = "Take the person you are looking at out of their squad.",

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "squad.force")
	end,

	OnRun = function(self, client)
		if (CLIENT) then return end

		local target, why = LookedAt(client)

		if (not target) then return why end

		return ix.squad.ForceRemove(client, target)
	end
})

--------------------------------------------------------------------------------
-- Holding E on somebody
--------------------------------------------------------------------------------

--[[
	The hold-E menu is where Phoenix put inviting, and it is where this puts
	it too - plus kicking, promoting and demoting, so a leader stood next to
	their squad never needs the chat. `canSee` decides what is DRAWN, from
	the client's copy of its own squad; `OnCanRun` decides what HAPPENS,
	from the server's. See `sh_interact.lua`.
]]
if (ix.interact and ix.interact.Add) then
	local function Ranks(target, me)
		local mine = ix.squad.Get(me)

		if (not mine) then return nil end

		return mine, ix.squad.RankIn(mine, ix.squad.CharacterID(me)),
			ix.squad.RankIn(mine, ix.squad.CharacterID(target))
	end

	ix.interact.Add("squadInvite", {
		name = "Invite to squad",
		order = 60,

		canSee = function(target, me)
			local mine, myRank, theirs = Ranks(target, me)

			return mine ~= nil and myRank >= ix.squad.OFFICER and theirs == 0
		end,

		OnRun = function(client, target)
			local said = ix.squad.Invite(client, target)

			if (said) then client:Notify(said) end
		end
	})

	ix.interact.Add("squadKick", {
		name = "Kick from squad",
		order = 61,

		canSee = function(target, me)
			local mine, myRank, theirs = Ranks(target, me)

			return mine ~= nil and theirs > 0 and myRank > theirs
		end,

		OnRun = function(client, target)
			local said = ix.squad.Kick(client, ix.squad.CharacterID(target))

			if (said) then client:Notify(said) end
		end
	})

	ix.interact.Add("squadPromote", {
		name = function(target, me)
			local _, _, theirs = Ranks(target, me)

			return theirs == ix.squad.OFFICER and "Make squad leader"
				or "Make squad officer"
		end,
		order = 62,

		canSee = function(target, me)
			local mine, myRank, theirs = Ranks(target, me)

			return mine ~= nil and myRank == ix.squad.LEADER
				and theirs > 0 and theirs < ix.squad.LEADER
		end,

		OnRun = function(client, target)
			local said = ix.squad.Promote(client, ix.squad.CharacterID(target))

			if (said) then client:Notify(said) end
		end
	})

	ix.interact.Add("squadDemote", {
		name = "Demote to squad member",
		order = 63,

		canSee = function(target, me)
			local mine, myRank, theirs = Ranks(target, me)

			return mine ~= nil and myRank == ix.squad.LEADER
				and theirs == ix.squad.OFFICER
		end,

		OnRun = function(client, target)
			local said = ix.squad.Demote(client, ix.squad.CharacterID(target))

			if (said) then client:Notify(said) end
		end
	})
end

--------------------------------------------------------------------------------
-- Logs
--------------------------------------------------------------------------------

--- `ix.log.AddType` exists on the server alone (Helix's `sh_log.lua`).
if (SERVER) then
	ix.log.AddType("squadCreate", function(client, name)
		return string.format("%s formed the squad '%s'.", client:Name(), name)
	end, FLAG_NORMAL)

	ix.log.AddType("squadDisband", function(client, name)
		return string.format("%s disbanded the squad '%s'.", client:Name(), name)
	end, FLAG_NORMAL)

	ix.log.AddType("squadJoin", function(client, name)
		return string.format("%s joined the squad '%s'.", client:Name(), name)
	end, FLAG_NORMAL)

	ix.log.AddType("squadLeave", function(client, name)
		return string.format("%s left the squad '%s'.", client:Name(), name)
	end, FLAG_NORMAL)

	ix.log.AddType("squadKick", function(client, who, name)
		return string.format("%s removed %s from the squad '%s'.", client:Name(),
			who, name)
	end, FLAG_NORMAL)

	ix.log.AddType("squadRank", function(client, who, rank, name)
		return string.format("%s made %s %s of the squad '%s'.", client:Name(),
			who, rank, name)
	end, FLAG_NORMAL)

	ix.log.AddType("squadForce", function(client, who, name)
		return string.format("%s forced %s %s.", client:Name(), who,
			name and ("into the squad '" .. name .. "'") or "out of their squad")
	end, FLAG_WARNING)
end
