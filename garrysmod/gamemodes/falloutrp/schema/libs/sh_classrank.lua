--[[
	Who may be which class.

	Helix lets any member of a faction switch to any of its classes freely, so
	on a stock install a Legion recruit can make themselves Legion - Lead the
	moment they spawn and switch back whenever they like. Phoenix have the same
	hole; their four rank booleans are read by nothing.

	NOBODY PICKS THEIR OWN CLASS HERE. There are exactly two ways to get one:

	    /charsetclass                  an admin puts you in it
	    the C menu, `sh_factionmgmt`   somebody above you in your faction does

	which is the whole point of having a ladder. A class is a position other
	people put you in.

	THIS REPLACED A GRANT SYSTEM, and the story is worth keeping because the
	first design was more machinery for less result. It stored a per-character
	list of classes an admin had allowed, gated everything at or above a
	configurable rank behind it, and needed three commands of its own to
	manage. Then `/charsetclass` had to hand out a grant to be worth using, and
	the faction hierarchy had to hand out a grant to be able to promote anyone
	- so every route that set a class also granted it, and the grant recorded
	nothing the class itself did not already say.

	It was guarding a door that is simply closed now. Removing it took with it
	a config, four functions, two commands, and the two-realms problem they
	came with: character data is `isLocal`, so one client could never see
	another's grants, which is why the faction menu had to skip the check it
	was supposedly enforcing.

	WHAT IS LEFT IS NOT A PERMISSION. A race lock is a statement of fact: a
	Mother is a deathclaw matriarch, and no permission makes a human one.

	SHARED, because `CanPlayerJoinClass` runs on both realms.
]]

ix.class = ix.class or {}

--[[
	Whether a character could be this class at all.

	Returns `true`, or `false, reason`. Its own function rather than living
	only in the hook, so the context menu can ask the same question and get the
	same answer.
]]
function ix.class.CanCharacterTake(character, info)
	if (not character or not info) then return false, "No such class." end

	if (info.races) then
		local race = character:GetRace()

		if (not table.HasValue(info.races, race)) then
			local names = {}

			for _, id in ipairs(info.races) do
				local data = ix.races and ix.races.Get(id)

				names[#names + 1] = data and data.name or id
			end

			return false, string.format("%s is only for %s.",
				info.name, table.concat(names, ", "))
		end
	end

	return true
end

--[[
	What a faction CALLS a rank.

	"Enlisted / NCO / Officer / Lead" is the shape of every ladder and the name
	of almost none of them. The Kings have a Greaser, a Sergeant-at-Arms, a
	Lieutenant and The King; the White Glove Society has a Maitre d'; the
	Deathclaws have a Mother. Offering "3 - Officer" when configuring a Kings
	shop is asking somebody to translate in their head, and getting it wrong is
	silent - the rank number is right and the label is a lie.

	So the label comes from the faction's OWN class at that rank. Where a
	faction has several - CIT has four rank-4 division leads - the first
	alphabetically stands for the rung, because any of them says the same thing
	about seniority and a list of four does not fit in a dropdown.

	`generic` is the fallback for a faction with no class at that rank at all,
	which is every creature faction above its own top rung.
]]
local GENERIC = {[1] = "Enlisted", [2] = "NCO", [3] = "Officer", [4] = "Lead"}

function ix.class.GetRankName(faction, rank)
	if (not faction) then return GENERIC[rank] or ("Rank " .. tostring(rank)) end

	--[[
		Takes an index or a uniqueID, because the shop stores factions by
		uniqueID and everything else in Helix hands you an index.
	]]
	if (isstring(faction)) then
		local team = ix.faction.teams[faction]

		faction = team and team.index
	end

	local best

	for _, info in ipairs(ix.class.list) do
		if (info.faction ~= faction) then continue end
		if ((info.rank or 1) ~= rank) then continue end

		if (not best or info.name < best) then
			best = info.name
		end
	end

	--[[
		The faction's prefix is stripped where it has one. Phoenix name their
		classes "NCR - Officer", and a dropdown inside a window that already
		says NCR does not need to say it again.
	]]
	if (best) then
		local trimmed = string.match(best, "^.- %- (.+)$")

		return trimmed or best
	end

	return GENERIC[rank] or ("Rank " .. tostring(rank))
end

--[[
	Every rank a faction actually has a class for, in order.

	The configurer offers these rather than 1-4: a faction whose ladder stops
	at 2 has nothing at 3, so offering it would let somebody set a price nobody
	can ever reach.
]]
function ix.class.GetRanks(faction)
	if (isstring(faction)) then
		local team = ix.faction.teams[faction]

		faction = team and team.index
	end

	local seen, out = {}, {}

	for _, info in ipairs(ix.class.list) do
		if (info.faction ~= faction) then continue end

		local rank = info.rank or 1

		if (not seen[rank]) then
			seen[rank] = true
			out[#out + 1] = rank
		end
	end

	table.sort(out)

	--[[
		Never empty. A faction with no classes at all would otherwise give a
		dropdown with nothing in it, and rank 1 is the honest default - it is
		what `GetRank` returns for a character with no class.
	]]
	if (#out == 0) then out[1] = 1 end

	return out
end

--[[
	`CanPlayerJoinClass` rather than a `CanSwitchTo` in every generated class
	file: one listener covers all 222, and the rule stays somewhere a person
	can read rather than being copied into files that get regenerated.
]]
hook.Add("CanPlayerJoinClass", "ixClassRank", function(client, class, info)
	local character = client:GetCharacter()

	if (not character) then return end

	--[[
		Only ever returns false or nothing. Returning TRUE here would override
		every other plugin's refusal, because `hook.Run` stops at the first
		non-nil answer - a permissive hook is a hole, not a permission.
	]]
	if (not ix.class.CanCharacterTake(character, info)) then
		return false
	end
end)

--[[
	`/becomeclass` is removed, and it is the door that actually mattered.

	`cl_special.lua` takes the Classes tab out of the F1 menu, which is the
	visible half - but the tab was never the mechanism. Helix ships
	`/becomeclass` as a PLAIN, NON-ADMIN command that calls
	`character:JoinClass` on anything in your own faction, so with the tab gone
	a Legion recruit could still type

	    /becomeclass "Legion - Lead"

	and be one. Hiding a button while leaving the command behind it is not a
	restriction; it is a restriction that looks like it works, which is worse
	than none.

	Removed on BOTH realms. The server half is what refuses it - `ix.command.
	Parse` looks the name up in this table - and the client half is what stops
	the chatbox offering a completion for a command that no longer exists.

	Removal rather than a `CanPlayerJoinClass` refusal, because the hook cannot
	tell WHERE a switch came from: the admin command and the faction menu go
	through the same `SetClass`, so a hook strict enough to stop this would
	stop those too.
]]
ix.command.list = ix.command.list or {}
ix.command.list["becomeclass"] = nil

if (SERVER) then
	--[[
		CLASS IS NOT SAVED BY HELIX, AND HAS TO BE.

		`ix.char.RegisterVar("class", {bNoDisplay = true})` declares no `field`,
		so there is no column for it and `character:Save()` writes nothing.
		Every character therefore came back on the faction's default class after
		a reconnect or a restart, silently undoing every promotion anybody had
		been given - and it looks like it worked right up until the next
		restart, which is the worst shape a bug can have.

		So it is kept in character DATA, which is a real column, under the class
		uniqueID rather than its index: an index is a load-order artefact, and
		adding one class file would otherwise re-point every stored class above
		it in the alphabet.

		Data is also the reason the faction menu can manage somebody who is
		offline - `data` is a column, so their class is readable from the
		database without them being here.
	]]
	local CLASS_KEY = "class"

	function ix.class.Remember(character)
		local info = ix.class.list[character:GetClass()]

		if (info) then
			character:SetData(CLASS_KEY, info.uniqueID)
		end
	end

	--- The class a character should come back on, or nil for the default.
	function ix.class.Remembered(character)
		local uniqueID = character:GetData(CLASS_KEY)

		if (not uniqueID) then return end

		for _, info in ipairs(ix.class.list) do
			if (info.uniqueID == uniqueID) then return info end
		end
	end

	--[[
		The class a character should be in when the one they are in is not
		available to them.

		Prefers a class their race actually fits, THEN the faction default.
		This is what makes the creature factions work: every class in Feral is
		race-locked, so a Reaver loading in gets the faction default - Feral
		Ghoul - which is locked to a race they are not, and they would sit in a
		class they cannot have with nothing to say so.

		Also covers a class file removed between restarts, and a race changed
		with `/charsetrace` while holding a class locked to the old one.
	]]
	local function BestClass(character)
		local faction = character:GetFaction()
		local fallback

		for _, info in ipairs(ix.class.list) do
			if (info.faction ~= faction) then continue end

			if (info.races and ix.class.CanCharacterTake(character, info)) then
				return info.index
			end

			if (info.isDefault) then
				fallback = info.index
			end
		end

		return fallback
	end

	local function Reconcile(client)
		local character = client:GetCharacter()

		if (not character) then return end

		--[[
			The remembered class is restored FIRST, before anything is checked.

			Helix has already put them on the faction default by this point -
			`PlayerLoadedCharacter` in its own `sv_hooks` does that - so this
			runs after it and puts back what they actually are. It is still
			checked below: a class that has since become race-locked against
			them, or been deleted, is corrected the same as any other.
		]]
		local remembered = ix.class.Remembered(character)

		if (remembered and remembered.faction == character:GetFaction()
		and remembered.index ~= character:GetClass()) then
			character:SetClass(remembered.index)
		end

		local info = ix.class.list[character:GetClass()]

		if (info and ix.class.CanCharacterTake(character, info)) then
			ix.class.Remember(character)

			return
		end

		local best = BestClass(character)

		if (best and best ~= character:GetClass()) then
			character:SetClass(best)
		end

		ix.class.Remember(character)
	end

	--[[
		On load rather than on spawn. Helix assigns the faction's default class
		in its own `PlayerLoadedCharacter`, and this has to run after that or
		it would be correcting a class that is about to be overwritten.
	]]
	hook.Add("PlayerLoadedCharacter", "ixClassRank", function(client)
		timer.Simple(0, function()
			if (IsValid(client)) then
				Reconcile(client)
			end
		end)
	end)

	--- And again when the race changes, which is the other way to end up wrong.
	hook.Add("CharacterVarChanged", "ixClassRank", function(character, key)
		if (key ~= "race" and key ~= "faction") then return end

		local client = character:GetPlayer()

		if (IsValid(client)) then
			timer.Simple(0, function()
				if (IsValid(client)) then
					Reconcile(client)
				end
			end)
		end
	end)
end

if (SERVER) then
	--[[
		Anything that sets a class writes it down.

		A hook rather than a call at each of the three call sites - the admin
		command, the faction menu, and the reconcile above - because the fourth
		one somebody adds later will not remember to.
	]]
	hook.Add("CharacterVarChanged", "ixClassRemember", function(character, key)
		if (key ~= "class") then return end

		timer.Simple(0, function()
			if (character and character.GetClass) then
				ix.class.Remember(character)
			end
		end)
	end)
end
