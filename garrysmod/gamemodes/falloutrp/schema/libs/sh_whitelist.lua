--[[
	A whitelist is permission to MAKE a character, not permission to keep one.

	Helix checks it in both places. `GM:CanPlayerUseCharacter` refuses to load a
	character whose faction the player is not whitelisted for, which sounds
	reasonable until you follow what it does on this server:

	    an admin moves somebody into a faction with `/charsetfaction`
	    - which deliberately does NOT grant a whitelist, because moving one
	      character and granting standing access to create more are two
	      different decisions
	    they log out
	    they can never load that character again

	The same happens to anybody whose whitelist is taken away after they have
	been playing a character for a month: their character is not deleted, it is
	simply unloadable, which is a worse outcome than either "you are kicked out
	of the faction" or "nothing happens".

	SO THE RULE HERE IS: a whitelist gates CREATION. Character creation still
	checks it - that is Helix's `CanPlayerCreateCharacter`, untouched, and the
	faction list at creation still only offers what you may take. Loading is
	between a player and a character that already exists.

	HOW THE OVERRIDE WORKS, and why it repeats the ban check:

	`hook.Call` runs `hook.Add` listeners before the gamemode's own function and
	stops at the first non-nil answer (gotcha 27) - which is the mechanism this
	needs and the trap it has to avoid. Returning `true` here skips
	`GM:CanPlayerUseCharacter` ENTIRELY, and that function does two things: the
	whitelist check this is here to remove, and the CHARACTER BAN check, which
	must survive. So the ban check is repeated below, and this returns true only
	when it passes.

	Shared, because the character menu greys out what it cannot load on the
	client and the server refuses it on the way in.
]]

hook.Add("CanPlayerUseCharacter", "ixWhitelistIsForCreation",
	function(client, character)
		--[[
			BANS ARE HELIX'S, COPIED EXACTLY - a number is an expiry and
			anything else is permanent, which is the shape `/charban` writes.
			Getting this wrong would quietly unban every banned character on the
			server, which is precisely the kind of thing an override like this
			does when nobody writes down what it replaced.
		]]
		local banned = character:GetData("banned")

		if (banned) then
			if (not isnumber(banned)) then
				return false, "@charBanned"
			end

			if (banned > os.time()) then
				return false, "@charBannedTemp"
			end
		end

		--[[
			TRUE, NOT NIL. Nil would fall through to the gamemode function,
			which is the whitelist refusal this exists to skip.
		]]
		return true
	end)
