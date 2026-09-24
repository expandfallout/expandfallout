--[[
	The `!` and `~` prefixes, and the admin verbs every server expects.

	Helix only knows `/`. Anybody who has run a Garry's Mod server types `!goto`
	without thinking about it, and a server where that silently says nothing is
	a server that feels broken before anybody has done anything wrong.

	`!` IS AN ALIAS, NOT A SECOND SYSTEM. Chat starting with `!` is rewritten to
	`/` and handed to Helix's own parser, so every command gets both prefixes,
	the rank overrides apply identically, and there is exactly one place where
	a command's access is decided.

	`~` IS THE SAME COMMAND WITHOUT TELLING THEM.

	`!bring` says "so-and-so brought you" and `~bring` says nothing at all. It
	is for watching somebody rather than dealing with them - the moment a
	player knows an admin is interested they stop doing the thing, which makes
	the report impossible to confirm.

	Three rules keep it honest:

	    IT IS A PERMISSION.  `admin.silent`, granted separately, because being
	                         able to act on somebody invisibly is a bigger
	                         thing than being able to act on them.
	    NOT EVERY COMMAND.   Only the moderation verbs - `ix.admin.silent`
	                         below. `~advert` is not a secret advert; it is
	                         just an advert.
	    ALWAYS LOGGED.       Silent is silent to the PLAYER. Every one of these
	                         still writes its log line, and the log records
	                         that it was run quietly.

	THE VERBS ARE THIN. `!ignite` sets somebody on fire and writes a log line;
	it does not reimplement anything. What makes them worth having is that they
	all go through `ix.admin.Can` and `ix.admin.Outranks`, so a moderator
	cannot freeze an admin, and every one of them is recorded.
]]

--------------------------------------------------------------------------------
-- The prefix
--------------------------------------------------------------------------------

if (SERVER) then
	--[[
		`!command` is run HERE, not handed onwards as `/command`.

		THE FIRST VERSION RETURNED THE REWRITTEN STRING AND NOTHING WORKED.

		Helix parses chat in `GM:PlayerSay`, a GAMEMODE METHOD - and
		`hook.Call` runs every `hook.Add` listener FIRST and returns the moment
		one of them returns a value, without ever calling the gamemode method.
		So returning "/goto bob" did not feed the rewritten text to Helix; it
		replaced the whole of `PlayerSay` with that string, and the engine said
		it out loud as ordinary chat. The message looked almost right, which is
		why it read as "the commands do not exist" rather than as a hook
		problem.

		A hook that returns is a hook that ENDS the call. So this one does the
		work: `ix.command.Parse` is exactly what `GM:PlayerSay` calls for a
		`/command`, including the "that command does not exist" reply, so `!`
		and `/` reach the same code by the same route and there is still one
		place a command's access is decided.

		Returning "" suppresses the chat line, which is what Helix does for
		`/commands` too - and it returns before `PostPlayerSay`, again matching
		Helix, so a command is not written into the chat log as something
		somebody said.
	]]
	hook.Add("PlayerSay", "ixAdminPrefix", function(client, text)
		local prefix = string.sub(text, 1, 1)

		if (prefix ~= "!" and prefix ~= "~") then return end

		--[[
			`!!` and `~~` are left alone. Somebody typing "!!!" is shouting,
			not running a command named `!`, and eating it would be worse than
			ignoring it.
		]]
		local second = string.sub(text, 2, 2)

		if (second == prefix or second == "") then return end

		local rewritten = "/" .. string.sub(text, 2)

		--[[
			A CHAT TYPE IS NOT A COMMAND, and `!ooc hello` used to say "sorry,
			that command does not exist".

			`/ooc`, `/y`, `/w`, `/me` and `/advert` are CHAT PREFIXES: Helix
			matches them in `ix.chat.Parse` inside `GM:PlayerSay` and registers
			a command of that name on the CLIENT ONLY, purely so the chatbox
			can autocomplete it. So `ix.command.list` on the server has no
			entry for any of them, and a `!` that only ever looked there
			refused every chat type in the game.

			Parsed with `bNoSend`, which makes it a pure question - "would this
			have been a chat type, and what is left after the prefix" - and
			only sent once the answer is yes. `ic` is the answer when NOTHING
			matched, and sending that would say "/ooc hello" out loud in
			character, which is exactly the bug this replaces.
		]]
		local name = string.match(string.lower(rewritten), "^/([_%w]+)")

		--[[
			QUIET, IF THEY ASKED FOR IT AND MAY HAVE IT.

			The flag lives on the player for the length of one command, which
			is safe because `ix.command.Parse` runs it synchronously - it is
			set, the command runs, it is cleared, and nothing else has had a
			turn in between. A field rather than an argument because the thing
			that reads it is `target:Notify` inside a verb, eleven frames of
			framework away from here.

			A `~` on something that is not a moderation command is simply a
			`!`. Refusing it would mean explaining a distinction the person
			typing does not care about.
		]]
		if (prefix == "~" and name and ix.admin.silent[name]) then
			if (ix.admin.Can(client, "admin.silent")) then
				client.ixSilent = true
			else
				client:Notify("You cannot run commands silently - that one "
					.. "ran normally.")
			end
		end

		if (name and not ix.command.list[name]) then
			local chatType, message, anonymous = ix.chat.Parse(client,
				rewritten, true)

			if (chatType and chatType ~= "ic") then
				ix.chat.Send(client, chatType, message, anonymous)

				return ""
			end
		end

		ix.command.Parse(client, rewritten)

		--[[
			CLEARED IMMEDIATELY. A flag that outlived its command would make
			the NEXT one silent too, which is the kind of bug nobody reports
			because the symptom is something not happening.
		]]
		client.ixSilent = nil

		return ""
	end)
end

--------------------------------------------------------------------------------
-- Shared helpers
--------------------------------------------------------------------------------

ix.admin = ix.admin or {}

--[[
	The check every verb makes: may I, and do I outrank them?

	One function because the answer has two halves and forgetting the second is
	how a moderator ends up able to freeze the owner. Returns `true`, or
	`false, reason`.
]]
--[[
	The commands `~` actually silences, by the name typed.

	Aliases are listed as well as real names, because the prefix hook reads
	what somebody wrote rather than what it resolves to - `!goto` and `!plygoto`
	are the same command and only one of them is in `ix.command.list` under
	that key.

	WHAT IS NOT HERE MATTERS AS MUCH. `warn` is deliberately absent: a warning
	the player never sees is not a warning, it is a note. So is anything that
	is not moderation - a silent advert is a contradiction.
]]
ix.admin.silent = {
	plygoto = true, ["goto"] = true, tp = true,
	plybring = true, bring = true,
	["return"] = true,
	plykick = true, kick = true,
	ban = true, banid = true,
	slay = true, respawn = true,
	freeze = true, unfreeze = true,
	ignite = true, extinguish = true,
	god = true, ungod = true,
	strip = true,
	blind = true, unblind = true,
	sethealth = true, setarmour = true, setarmor = true
}

if (ix.admin.RegisterPermission) then
	ix.admin.RegisterPermission("admin.silent",
		"Run moderation commands silently with ~", "Staff")
end

--[[
	Tell them, unless this was run with `~`.

	Every verb notifies its target through here rather than calling `Notify`
	itself, so "silent" is one decision made in one place instead of a check
	copied into fourteen commands - and a verb added later that forgets to use
	it is loud, which is the safe way round to be wrong.
]]
function ix.admin.Quiet(client, target, text)
	if (IsValid(client) and client.ixSilent) then return end
	if (not IsValid(target)) then return end

	target:Notify(text)
end

--- Whether the current command is being run quietly. For the wording of logs.
function ix.admin.IsSilent(client)
	return IsValid(client) and client.ixSilent == true
end

function ix.admin.CanActOn(client, target, permission)
	if (not ix.admin.Can(client, permission)) then
		return false, "You cannot do that."
	end

	if (not IsValid(target)) then return false, "They are not here." end

	if (not ix.admin.Outranks(client, target)) then
		return false, "They outrank you, or match you."
	end

	return true
end

--[[
	FROM HERE DOWN IS SHARED, and it used to return early on the client.

	That looked harmless - the bodies only ever run on the server - but the
	permissions are registered here too, and a permission that is registered
	only on the server is INVISIBLE IN THE RANK EDITOR. Eleven of them were
	missing from the tickbox list with nothing to say why, which reads as the
	editor being incomplete rather than as the permission not existing on that
	realm.

	Commands are registered shared in Helix anyway - the client needs to know
	they exist to autocomplete them - so the only genuinely server-side things
	in this file are the log types and the position table, and those are
	guarded individually.
]]

--[[
	Every verb, as data.

	Written as a table because they are all the same shape - check, act, log,
	answer - and eleven copies of that shape is eleven places for one of them
	to forget the check. `Run` is the only part that differs.
]]
local VERBS = {
	{
		name = "Ignite", permission = "player.ignite", verb = "set fire to",
		description = "Set a player on fire.",
		Run = function(client, target) target:Ignite(20) end
	},
	{
		name = "Extinguish", permission = "player.ignite",
		verb = "put out", description = "Put a player's fire out.",
		Run = function(client, target) target:Extinguish() end
	},
	{
		name = "Slay", permission = "player.slay", verb = "slayed",
		description = "Kill a player.",
		Run = function(client, target) target:Kill() end
	},
	{
		name = "Freeze", permission = "player.freeze", verb = "froze",
		description = "Freeze a player in place.",
		Run = function(client, target) target:Freeze(true) end
	},
	{
		name = "Unfreeze", permission = "player.freeze", verb = "unfroze",
		description = "Unfreeze a player.",

		--[[
			THROUGH `ix.physgun.Release` WHERE IT EXISTS, because somebody
			frozen in the air by the physics gun is also on `MOVETYPE_NONE` -
			see `sh_physgun.lua`. `Freeze(false)` alone would leave them
			unfrozen and still unable to move, with nothing on screen to say
			why.
		]]
		Run = function(client, target)
			if (ix.physgun and ix.physgun.Release) then
				ix.physgun.Release(target)

				return
			end

			target:Freeze(false)
		end
	},
	{
		name = "God", permission = "player.god", verb = "gave god to",
		description = "Make a player invulnerable.",
		Run = function(client, target) target:GodEnable() end
	},
	{
		name = "Ungod", permission = "player.god", verb = "took god from",
		description = "Make a player mortal again.",
		Run = function(client, target) target:GodDisable() end
	},
	{
		name = "Strip", permission = "player.strip", verb = "stripped",
		description = "Take every weapon from a player.",
		Run = function(client, target) target:StripWeapons() end
	},
	{
		name = "Respawn", permission = "player.respawn", verb = "respawned",
		description = "Respawn a player where they stand.",
		Run = function(client, target)
			if (not target:Alive()) then target:Spawn() return end

			local position = target:GetPos()

			target:Spawn()
			target:SetPos(position)
		end
	},
	{
		name = "Blind", permission = "player.blind", verb = "blinded",
		description = "Black out a player's screen.",
		Run = function(client, target) target:SetNetVar("ixBlind", true) end
	},
	{
		name = "Unblind", permission = "player.blind", verb = "unblinded",
		description = "Give a player their screen back.",
		Run = function(client, target) target:SetNetVar("ixBlind", nil) end
	}
}

for _, verb in ipairs(VERBS) do
	ix.admin.RegisterPermission(verb.permission,
		verb.description, "People")

	ix.command.Add(verb.name, {
		description = verb.description,
		arguments = {ix.type.player},

		OnCheckAccess = function(self, client)
			return ix.admin.Can(client, verb.permission)
		end,

		OnRun = function(self, client, target)
			local ok, reason = ix.admin.CanActOn(client, target,
				verb.permission)

			if (not ok) then return reason end

			verb.Run(client, target)

			ix.log.Add(client, "adminVerb", verb.verb, target:Name(),
				target:SteamID())

			ix.admin.Quiet(client, target, string.format("%s %s you.",
				client:Name(), verb.verb))

			--[[
				AND THE REST OF THE TEAM SEES IT. `ix.admin.Announce` is a
				no-op for a `~` command, so this one line gives every verb both
				behaviours - see `sh_ticket.lua`, where the staff channel is.
			]]
			ix.admin.Announce(client, string.format("%s %s %s.",
				client:SteamName(), verb.verb, target:Name()))

			return string.format("%s %s.", verb.verb, target:Name())
		end
	})
end

if (SERVER) then
	--[[
		THE LOG SAYS WHEN IT WAS QUIET. Silent means the player was not told;
		it does not mean there is no record, and an entry that did not
		distinguish the two would make the log useless for the one question
		anybody asks it afterwards - "did they know?"
	]]
	ix.log.AddType("adminVerb", function(client, verb, name, steamID)
		return string.format("%s %s %s (%s).%s", client:Name(), verb, name,
			steamID, ix.admin.IsSilent(client) and " [silent]" or "")
	end, FLAG_WARNING)
end

--------------------------------------------------------------------------------
-- The ones that take a number
--------------------------------------------------------------------------------

ix.admin.RegisterPermission("player.health", "Set health and armour",
	"People")
ix.admin.RegisterPermission("player.speed", "Set a player's speed", "People")

ix.command.Add("SetHealth", {
	description = "Set a player's health.",
	arguments = {ix.type.player, ix.type.number},

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "player.health")
	end,

	OnRun = function(self, client, target, amount)
		local ok, reason = ix.admin.CanActOn(client, target, "player.health")

		if (not ok) then return reason end

		amount = math.Clamp(math.floor(amount), 1, 10000)

		target:SetHealth(amount)

		ix.admin.Announce(client, string.format("%s set %s's health to %d.",
			client:SteamName(), target:Name(), amount))

		ix.log.Add(client, "adminNumber", "health", amount, target:Name(),
			target:SteamID())

		return string.format("%s has %d health.", target:Name(), amount)
	end
})

ix.command.Add("SetArmour", {
	description = "Set a player's armour.",
	alias = {"SetArmor"},
	arguments = {ix.type.player, ix.type.number},

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "player.health")
	end,

	OnRun = function(self, client, target, amount)
		local ok, reason = ix.admin.CanActOn(client, target, "player.health")

		if (not ok) then return reason end

		amount = math.Clamp(math.floor(amount), 0, 10000)

		target:SetArmor(amount)

		ix.admin.Announce(client, string.format("%s set %s's armour to %d.",
			client:SteamName(), target:Name(), amount))

		ix.log.Add(client, "adminNumber", "armour", amount, target:Name(),
			target:SteamID())

		return string.format("%s has %d armour.", target:Name(), amount)
	end
})

if (SERVER) then
	ix.log.AddType("adminNumber", function(client, what, amount, name,
		steamID)
		return string.format("%s set %s's (%s) %s to %d.", client:Name(),
			name, steamID, what, amount)
	end, FLAG_WARNING)
end

--------------------------------------------------------------------------------
-- Moving people about
--------------------------------------------------------------------------------

ix.admin.RegisterPermission("player.return", "Send a player back where they "
	.. "were", "People")

--[[
	Where somebody was before an admin moved them.

	`!return` is the other half of `!bring`, and without it bringing somebody
	out of a scene means asking them where they were. Stored per player in
	memory, because it is only meaningful for as long as they are connected.
]]
local returns = {}

if (SERVER) then
	hook.Add("PlayerDisconnected", "ixAdminReturn", function(client)
		returns[client:SteamID()] = nil
	end)
end

function ix.admin.RememberPosition(target)
	if (not IsValid(target)) then return end

	returns[target:SteamID()] = target:GetPos()
end

ix.command.Add("Return", {
	description = "Send a player back to where they were brought from.",
	arguments = {ix.type.player},

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "player.return")
	end,

	OnRun = function(self, client, target)
		local ok, reason = ix.admin.CanActOn(client, target, "player.return")

		if (not ok) then return reason end

		local position = returns[target:SteamID()]

		if (not position) then
			return "Nobody has moved them."
		end

		target:SetPos(position)

		returns[target:SteamID()] = nil

		ix.admin.Announce(client, string.format("%s returned %s.",
			client:SteamName(), target:Name()))

		ix.log.Add(client, "adminVerb", "returned", target:Name(),
			target:SteamID())

		return string.format("Sent %s back.", target:Name())
	end
})
