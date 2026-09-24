--[[
	Target tokens: `^` yourself, `@` whoever you are looking at, `*` everybody.

	    !goto @        the player in front of you
	    !bring *       all of them
	    !sethealth ^ 1 yourself

	WHY THIS WRAPS `ix.command.Run` AND NOT `ix.util.FindPlayer`.

	`FindPlayer` is the function that turns "bob" into a player, and it is the
	obvious place to put this - except it takes a name and nothing else. `^` and
	`@` are questions about WHO IS ASKING, and that is not something a name
	lookup can be told. `ix.command.Run` has the caller, the command definition
	and the raw arguments, which is everything the answer needs.

	IT SUBSTITUTES A STEAMID, NOT A NAME. `FindPlayer` matches names loosely -
	"bob" finds "bobby" - so writing the target's name back into the arguments
	would be handing an exact answer to a fuzzy matcher and hoping. It takes a
	`STEAM_` id as an exact match, so that is what goes in.

	IT ONLY TOUCHES SLOTS DECLARED AS A PLAYER OR A CHARACTER. A `*` inside a
	ban reason is a `*` inside a ban reason. Commands with no declared
	`arguments` table parse their own text and are left entirely alone.

	This covers Helix's commands and the schema's identically, for the same
	reason the rank overrides do: everything with a `/` in front of it arrives
	at `ix.command.Run`, and neither kind knows the difference.
]]

ix.target = ix.target or {}

--- What each token means, for the menu and for the error messages.
ix.target.tokens = {
	{token = "^", description = "yourself"},
	{token = "@", description = "whoever you are looking at"},
	{token = "*", description = "everybody on the server"}
}

--[[
	The player somebody is looking at, or nil.

	A RAGDOLLED PLAYER COUNTS. Helix turns a downed or restrained player into a
	prop_ragdoll and hangs the player on it as `ixPlayer` - so without this,
	`@` would stop working at exactly the moment an admin is most likely to be
	standing over somebody using it.
]]
function ix.target.LookingAt(client)
	if (not IsValid(client) or not client:IsPlayer()) then return end

	local entity = client:GetEyeTrace().Entity

	if (not IsValid(entity)) then return end
	if (entity:IsPlayer()) then return entity end
	if (IsValid(entity.ixPlayer)) then return entity.ixPlayer end
end

--[[
	Which argument slots take a player or a character.

	Returns nil when there are none, so the common case - a command with no
	player argument at all - costs one table read and nothing else.
]]
function ix.target.Slots(command)
	if (not command or not command.arguments) then return end

	local slots

	for index = 1, #command.arguments do
		local argType = command.arguments[index]

		if (bit.band(argType, ix.type.optional) == ix.type.optional) then
			argType = bit.bxor(argType, ix.type.optional)
		end

		if (argType == ix.type.player or argType == ix.type.character) then
			slots = slots or {}
			slots[#slots + 1] = index
		end
	end

	return slots
end

--------------------------------------------------------------------------------
-- The wrapper
--------------------------------------------------------------------------------

--[[
	`ix.command.Run` is server-only - it is defined inside `if (SERVER)` in
	`sh_command.lua` - so there is nothing here to wrap on the client. The
	lookups above stay shared because the menu lists the tokens.
]]
if (not SERVER) then return end

local Run = ix.command.Run

function ix.command.Run(client, command, arguments)
	local definition = ix.command.list[tostring(command):lower()]
	local slots = ix.target.Slots(definition)

	if (not slots or not arguments) then
		return Run(client, command, arguments)
	end

	local everyone

	for _, index in ipairs(slots) do
		local given = arguments[index]

		if (given == "^") then
			if (not IsValid(client) or not client:IsPlayer()) then
				print("'^' means you, and the console is not a player.")

				return
			end

			arguments[index] = client:SteamID()
		elseif (given == "@") then
			local target = ix.target.LookingAt(client)

			if (not IsValid(target)) then
				if (IsValid(client)) then
					client:Notify("You are not looking at anybody.")
				else
					print("'@' means who you are looking at, and the console "
						.. "has no eyes.")
				end

				return
			end

			arguments[index] = target:SteamID()
		elseif (given == "*") then
			--[[
				ONLY THE FIRST. Two `*` slots would be a command run once for
				every pair of players, which is never what anybody meant and is
				a very effective way to lock up a server.
			]]
			everyone = everyone or index
		end
	end

	if (not everyone) then
		return Run(client, command, arguments)
	end

	--[[
		Run once per player.

		THE COOLDOWN IS CLEARED BETWEEN RUNS. `ix.command.Run` sets
		`ixCommandCooldown` to half a second after every successful run and
		refuses at the top while it stands - so without this, `*` would run on
		the first player and silently do nothing for the other twenty. It is
		put back afterwards, because the caller has still only typed one
		command and the anti-spam is still wanted.
	]]
	local targets = player.GetAll()

	for _, target in ipairs(targets) do
		local copy = table.Copy(arguments)

		copy[everyone] = target:SteamID()

		if (IsValid(client)) then client.ixCommandCooldown = 0 end

		Run(client, command, copy)
	end

	if (IsValid(client)) then
		client.ixCommandCooldown = RealTime() + 0.5

		--[[
			Said once, at the end. Each run answers for itself - "they outrank
			you" twenty times over is not information - but "on 20 player(s)"
			is how somebody knows the `*` was read as a `*`.
		]]
		client:Notify(string.format("Ran on %d player(s).", #targets))

		ix.log.Add(client, "commandEveryone", tostring(command), #targets)
	end
end

ix.log.AddType("commandEveryone", function(client, command, count)
	return string.format("%s ran /%s on all %d player(s).",
		client and client:Name() or "the console", command, count)
end, FLAG_WARNING)
