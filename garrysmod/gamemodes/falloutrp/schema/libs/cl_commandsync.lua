--[[
	The commands the client did not know about, from `sv_commandsync.lua`.

	A STUB IS ENOUGH TO LIST ONE. Nothing on the client ever RUNS a command -
	typing `/ambush` sends chat text and the server parses it - so what the
	chatbox needs is a name and a description in `ix.command.list`.

	BUT IT IS REGISTERED THROUGH `ix.command.Add`, NOT WRITTEN INTO THE TABLE.

	A command is not a plain table by the time anything reads it: `Add` gives it
	`GetDescription`, an `OnCheckAccess` built from CAMI, a `uniqueID` and a
	tidied `syntax`. The first version of this file put a hand-made table
	straight into `ix.command.list` and the chatbox died on the first keystroke:

	    cl_chatbox.lua:799: attempt to call method 'GetDescription' (a nil value)

	which is the general lesson - if a library has a registration function, the
	shape it produces is part of its contract, and half of that shape is added
	by the function rather than declared by the caller.
]]

ix.command = ix.command or {}

if (not CLIENT) then return end

net.Receive("ixCommandList", function()
	local list = net.ReadTable()
	local added = 0

	for _, entry in ipairs(list) do
		--[[
			ONLY WHAT IS MISSING. A command defined in a shared file already has
			its real table here, with its arguments, its access check and its
			`OnRun` - replacing that with a stub would be a downgrade.
		]]
		if (ix.command.list[string.lower(entry.name)]) then continue end

		ix.command.Add(entry.name, {
			description = entry.description or "",
			adminOnly = entry.adminOnly,
			superAdminOnly = entry.superAdminOnly,
			syntax = entry.syntax,

			--[[
				The server owns this one, and `Add` refuses a command with no
				callback at all - so this says what it is rather than being an
				empty function somebody later mistakes for a stub of the real
				thing.
			]]
			OnRun = function()
				return "That command runs on the server."
			end
		})

		added = added + 1
	end

	if (added > 0 and ix.fallout and ix.fallout.CreateTrace) then
		ix.fallout.CreateTrace(string.format(
			"commands: %d server-side one(s) added to the list", added))
	end
end)
