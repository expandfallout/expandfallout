--[[
	Player killing - marking, collecting, and forgetting.

	See `sh_pk.lua` for what a PK is and what came from Phoenix.

	RECOGNITION IS WIPED IN BOTH DIRECTIONS, which is the part with a real
	problem behind it. Helix keeps recognition as a string of character ids on
	each character - `rgn`, ",4,17,92," - so "this character no longer knows
	anybody" is one field to clear, and "nobody knows this character any more"
	is that character's id removed from everybody else's field.

	Everybody else includes people who are not here. An offline character's
	`rgn` is a row in the database, and reaching into it means SQL against a
	column that holds a JSON blob of every piece of character data there is.
	So instead the id goes on a FORGET LIST, and the strip runs as each
	character loads. Nobody is missed and nothing is rewritten by hand.

	The list is pruned after a month. A character that has not logged in for a
	month and still remembers somebody who was PK'd is not a problem worth
	keeping a row for.
]]

if (not SERVER) then return end

ix.pk = ix.pk or {}

util.AddNetworkString("ixPKChat")
util.AddNetworkString("ixPKRename")

--[[
	A chat line in red.

	`ChatPrint` is white and has no way not to be, which is what made "somebody
	has been marked for death" read like a server message about a map change.
	Phoenix colour theirs through a registered chat type; one net message with
	two halves is the same thing with nothing else attached to it.
]]
local function Say(receivers, highlight, rest)
	if (istable(receivers) and #receivers == 0) then return end

	net.Start("ixPKChat")
		net.WriteString(highlight or "")
		net.WriteString(rest or "")
	net.Send(receivers)
end

--- `[character id] = when they were PK'd`. Global; a PK is not per map.
ix.pk.forget = ix.pk.forget or {}

ix.pk.loaded = false

local FORGET_KEY = "pkforget"

--- How long an id stays on the forget list.
local FORGET_FOR = 60 * 60 * 24 * 30

--------------------------------------------------------------------------------
-- The forget list
--------------------------------------------------------------------------------

function ix.pk.Save()
	if (not ix.pk.loaded) then return end

	ix.data.Set(FORGET_KEY, ix.pk.forget, true, true)
end

function ix.pk.Load()
	if (ix.pk.loaded) then return end

	ix.pk.forget = ix.data.Get(FORGET_KEY, {}, true, true) or {}
	ix.pk.loaded = true

	local now = os.time()
	local pruned = 0

	for id, when in pairs(ix.pk.forget) do
		if (now - (tonumber(when) or 0) > FORGET_FOR) then
			ix.pk.forget[id] = nil
			pruned = pruned + 1
		end
	end

	if (pruned > 0) then ix.pk.Save() end
end

hook.Add("LoadData", "ixPK", ix.pk.Load)
hook.Add("PostLoadData", "ixPK", ix.pk.Load)
timer.Simple(10, ix.pk.Load)

--[[
	Take a list of ids out of one character's recognition.

	`rgn` is ",4,17,92," - leading and trailing commas included, which is what
	makes `find(",17,")` a safe test for membership rather than one that also
	matches 117. The same shape is what this writes back.
]]
local function Strip(character, ids)
	local recognised = character:GetData("rgn", "")

	if (recognised == "") then return false end

	local changed = false

	for id in pairs(ids) do
		local needle = "," .. tostring(id) .. ","

		while (string.find(recognised, needle, 1, true)) do
			recognised = string.Replace(recognised, needle, ",")
			changed = true
		end
	end

	--- A string of nothing but commas is nobody.
	if (changed and not string.find(recognised, "%d")) then recognised = "" end

	if (changed) then character:SetData("rgn", recognised) end

	return changed
end

--[[
	Applied as a character loads, so somebody who was offline when the PK
	happened forgets them the moment they come back.

	Run every load rather than once: stripping an id that is not there does
	nothing, so there is no state to keep about which characters have caught up
	and nothing to go wrong if it runs twice.
]]
hook.Add("PlayerLoadedCharacter", "ixPKForget", function(client, character)
	if (not character or table.IsEmpty(ix.pk.forget)) then return end

	Strip(character, ix.pk.forget)
end)

--------------------------------------------------------------------------------
-- Marking
--------------------------------------------------------------------------------

--[[
	Push the countdown to the person carrying it.

	A NETVAR IN `CurTime`, ALONGSIDE THE CHARACTER DATA IN `os.time`. The data
	is the truth and survives a disconnect; the netvar is what the HUD counts
	down, because the client's `os.time` is its own machine's clock and would
	be minutes out on somebody with a badly set computer.
]]
local function Push(client)
	if (not IsValid(client)) then return end

	local character = client:GetCharacter()
	local left = character and ix.pk.Remaining(character) or 0

	client:SetNetVar("pkUntil", left > 0 and (CurTime() + left) or nil)
end

--[[
	Mark somebody. `seconds` defaults to the `/pk` config.

	ONE WAY IN, so the mugging system that does not exist yet has somewhere to
	call and nothing here has to be told about it. `reason` is only ever for
	the log.
]]
function ix.pk.Mark(client, target, seconds, reason)
	local character = IsValid(target) and target:GetCharacter()

	if (not character) then return false, "They have no character." end

	seconds = math.max(tonumber(seconds)
		or ix.config.Get("pkDuration", 1800), 1)

	character:SetData("pkUntil", os.time() + seconds)

	Push(target)

	target:Notify(string.format("You are marked for death for %s.",
		ix.bench and ix.bench.FormatTime(seconds) or (seconds .. " seconds")))

	target:EmitSound("phoenix/ui/nv/ui_rep_bad.mp3", 75)

	--[[
		Anybody standing nearby is told, which is Phoenix's `pknotify` chat
		type - a local announcement rather than a server-wide one, so being
		marked is something the people around you saw happen.
	]]
	local range = ix.config.Get("pkNotifyRange", 800)

	local nearby = {}

	for _, other in ipairs(player.GetAll()) do
		if (other == target) then continue end
		if (other:GetPos():Distance(target:GetPos()) > range) then continue end

		nearby[#nearby + 1] = other

		other:EmitSound("phoenix/ui/nv/ui_rep_bad.mp3", 70, 100, 0.5)
	end

	Say(nearby, target:Name(), " has been marked for death.")

	ix.log.Add(client, "pkMark", target:Name(), target:SteamID(), seconds,
		reason or "no reason given")

	hook.Run("OnPlayerMarkedForPK", client, target, seconds, reason)

	return true, seconds
end

function ix.pk.Unmark(client, target)
	local character = IsValid(target) and target:GetCharacter()

	if (not character) then return false, "They have no character." end

	if (not ix.pk.IsActive(character)) then
		return false, "They are not marked."
	end

	character:SetData("pkUntil", 0)

	Push(target)

	target:Notify("You are no longer marked for death.")

	ix.log.Add(client, "pkUnmark", target:Name(), target:SteamID())

	hook.Run("OnPlayerUnmarkedForPK", client, target)

	return true
end

--[[
	The countdown has to stop on its own as well.

	Once a second, which is finer than it needs to be and is what makes the
	notice land when the timer ends rather than up to a minute afterwards.
]]
timer.Create("ixPKExpire", 1, 0, function()
	for _, client in ipairs(player.GetAll()) do
		local character = client:GetCharacter()

		if (not character) then continue end
		if (ix.pk.Until(character) <= 0) then continue end
		if (ix.pk.IsActive(character)) then continue end

		character:SetData("pkUntil", 0)

		Push(client)

		client:Notify("You are no longer marked for death.")
	end
end)

--- The countdown is pushed again on load, because the mark outlived the login.
hook.Add("PlayerLoadedCharacter", "ixPK", function(client)
	timer.Simple(1, function() Push(client) end)
end)

--------------------------------------------------------------------------------
-- The head
--------------------------------------------------------------------------------

--[[
	THERE IS NO `ix.pk.DropHead` ANY MORE.

	It spawned a named head at a position and was called from one place: the
	moment somebody was permanently killed. That is not where a head comes from
	now - `ix.corpse.TakeHead` makes one when somebody cuts it off a body, and
	it reads the name off the corpse. Keeping a second way to make a head would
	have meant two places that decide what a head is called.
]]

--[[
	Where every head on the server is, and what it thinks it is in.

	Written because a head came back reported as being in somebody's inventory
	AND refusing to be dropped with "same inv" - which is `ITEM:Transfer`
	saying the item is already in the inventory it is being moved to. Both
	symptoms are one number, `item.invID`, and this prints it rather than
	inviting a fifth guess about what it might be.
]]
concommand.Add("fo_head_report", function(client)
	if (IsValid(client) and not ix.admin.Can(client, "dev.terminal")) then
		return
	end

	local accent, plain = Color(255, 200, 100), Color(200, 200, 200)
	local found = 0

	MsgC(accent, "\n-- heads ------------------------------------------------\n")

	if (IsValid(client) and client:GetCharacter()) then
		local inventory = client:GetCharacter():GetInventory()

		MsgC(plain, string.format("  your inventory id: %s\n",
			tostring(inventory and inventory:GetID())))
	end

	for id, item in pairs(ix.item.instances) do
		if (item.uniqueID ~= ix.corpse.headItem) then continue end

		found = found + 1

		MsgC(plain, string.format("  item %-6s invID %-6s entity %-6s "
			.. "owner %s\n", tostring(id), tostring(item.invID),
			IsValid(item:GetEntity()) and "yes" or "no",
			tostring(item:GetData("owner", ""))))
	end

	if (found == 0) then MsgC(plain, "  none\n") end

	MsgC(accent, "\n")
end)

--------------------------------------------------------------------------------
-- Becoming somebody else
--------------------------------------------------------------------------------

--[[
	After a PK the character has to be renamed and re-described, and it is not
	optional.

	This is Phoenix's, and it is the other half of what the recognition wipe
	starts. Nobody knows them and they know nobody; a character who then walks
	back into the same bar under the same name has not stopped being the person
	they were, they have just lost their address book.

	FORCED MEANS FROZEN. A prompt that can be dismissed is a prompt somebody
	dismisses, and the flag lives on the CHARACTER, so relogging brings it back
	with them rather than shedding it. They move again when the server has
	accepted a name and a description - not when the panel closes.
]]
function ix.pk.NeedsRename(character)
	return character and character:GetData("pkRename", false) == true
end

function ix.pk.Prompt(client)
	if (not IsValid(client)) then return end

	local character = client:GetCharacter()

	if (not ix.pk.NeedsRename(character)) then return end

	client:Freeze(true)

	net.Start("ixPKRename")
	net.Send(client)
end

--[[
	Helix's own rules, applied here rather than through `OnValidate`.

	`ix.char.vars.name.OnValidate` takes a creation payload and a faction and
	hands back a default name for factions that impose one - none of which
	exists here, and calling it with a made-up payload would be inventing a
	character creation that is not happening. The two length rules ARE the
	validation, and they are read from the same configs the creation screen
	uses so the two can never disagree about what a name is.
]]
function ix.pk.ValidateName(value)
	value = string.Trim(string.gsub(tostring(value or ""), "[\r\n]", ""))

	local minimum = ix.config.Get("minNameLength", 4)
	local maximum = ix.config.Get("maxNameLength", 32)

	if (value:utf8len() < minimum) then
		return false, string.format("A name is at least %d characters.",
			minimum)
	end

	if (not string.find(value, "%S")) then
		return false, "A name has to have something in it."
	end

	if (string.gsub(value, "%s", ""):utf8len() > maximum) then
		return false, string.format("A name is at most %d characters.",
			maximum)
	end

	return true, value:utf8sub(1, 70)
end

function ix.pk.ValidateDescription(value)
	value = string.Trim(string.gsub(tostring(value or ""), "[\r\n]", ""))

	local minimum = ix.config.Get("minDescriptionLength", 16)

	if (value:utf8len() < minimum) then
		return false, string.format("A description is at least %d characters.",
			minimum)
	end

	--- Helix wants a space in it, which is its way of asking for a sentence.
	if (not string.find(value, "%s+") or not string.find(value, "%S")) then
		return false, "Describe them in a sentence, not a word."
	end

	return true, value
end

--[[
	The BODY as well as the name.

	A PK is a new person, and this schema asks a new person for their height,
	their weight and their age at creation - so a rename that changed only the
	name and the description left a character who was word for word somebody
	else and still 5ft 6in, 125lbs and nineteen years old, in the same body.

	Clamped with the same numbers `sh_biography.lua` validates creation
	against, read from the same constants, so the two cannot drift.
]]
local function ValidateBody(height, weight, age)
	height = math.floor(tonumber(height) or 0)
	weight = math.floor(tonumber(weight) or 0)
	age = math.floor(tonumber(age) or 0)

	if (height < ix.fallout.MIN_HEIGHT or height > ix.fallout.MAX_HEIGHT) then
		return nil, string.format("Height must be between %s and %s.",
			ix.fallout.FormatHeight(ix.fallout.MIN_HEIGHT),
			ix.fallout.FormatHeight(ix.fallout.MAX_HEIGHT))
	end

	if (weight < ix.fallout.MIN_WEIGHT or weight > ix.fallout.MAX_WEIGHT) then
		return nil, string.format("Weight must be between %d and %d lbs.",
			ix.fallout.MIN_WEIGHT, ix.fallout.MAX_WEIGHT)
	end

	--- The youngest is a config; see the note in `cl_pk.lua`.
	local youngest = ix.config.Get("minimumAge", 18)

	if (age < youngest or age > ix.fallout.MAX_AGE) then
		return nil, string.format("Age must be between %d and %d.", youngest,
			ix.fallout.MAX_AGE)
	end

	return {height = height, weight = weight, age = age}
end

net.Receive("ixPKRename", function(length, client)
	local character = client:GetCharacter()

	if (not ix.pk.NeedsRename(character)) then return end

	local name = net.ReadString()
	local description = net.ReadString()
	local height = net.ReadUInt(8)
	local weight = net.ReadUInt(10)
	local age = net.ReadUInt(8)

	local okName, resultName = ix.pk.ValidateName(name)

	if (not okName) then
		client:Notify(resultName)

		ix.pk.Prompt(client)

		return
	end

	local okDescription, resultDescription =
		ix.pk.ValidateDescription(description)

	if (not okDescription) then
		client:Notify(resultDescription)

		ix.pk.Prompt(client)

		return
	end

	local before = character:GetName()

	--[[
		THE BODY IS CHECKED WITH THE REST, and refused the same way: the window
		is re-opened rather than a half-renamed character being let go.
	]]
	local body, bodyFault = ValidateBody(height, weight, age)

	if (not body) then
		client:Notify(bodyFault)
		ix.pk.Prompt(client)

		return
	end

	character:SetName(resultName)
	character:SetDescription(resultDescription)
	character:SetHeight(body.height)
	character:SetWeight(body.weight)
	character:SetAge(body.age)
	character:SetData("pkRename", nil)

	client:Freeze(false)

	client:Notify("You are somebody else now.")

	ix.log.Add(client, "pkRename", before, resultName)
end)

--[[
	Asked again on load, because the flag came back with them.

	The delay is the same one the countdown uses: a character is not finished
	arriving on the frame `PlayerLoadedCharacter` fires, and a panel opened
	into that is a panel that appears behind the loading screen.
]]
hook.Add("PlayerLoadedCharacter", "ixPKRename", function(client)
	timer.Simple(2, function() ix.pk.Prompt(client) end)
end)

--------------------------------------------------------------------------------
-- Collecting
--------------------------------------------------------------------------------

--[[
	Everything a PK costs, in one place.

	Called from `PlayerDeath` and from nowhere else, but written as a function
	because "what a PK does" is the thing somebody will want to read.
]]
function ix.pk.Collect(client, attacker)
	local character = client:GetCharacter()

	if (not character) then return end

	local levels, caps = ix.pk.Cost(character)
	local level = character:GetLevel()

	--------------------------------------------------------------- levels ---

	local after = math.max(level - levels, 1)

	if (after < level) then
		character:SetLevel(after)

		--[[
			THE XP HAS TO COME DOWN WITH THE LEVEL.

			`CheckLevel` walks upwards while the XP total is enough for the
			next level, so dropping the level and leaving the XP alone means
			the very next kill puts it straight back. The floor for the new
			level is what "you are level 12 again" actually means.
		]]
		character:SetXP(ix.leveling.RequiredXP(after))

		--[[
			AND A RESPEC, because they have just lost the levels that paid for
			what they had spent.

			Subtracting the points those levels were worth is not enough: the
			points may already be IN attributes, and taking them off the unspent
			pile would leave somebody with five points of Strength bought with
			levels they no longer have and a negative balance clamped to zero.
			A respec is the only state that is consistent - attributes back to
			zero, points recomputed from the level they are now.

			It does not count against their respecs and does not cost them
			anything. Being killed is not spending your free one.
		]]
		ix.leveling.Respec(character, false)
	end

	----------------------------------------------------------------- caps ---

	local money = character:GetMoney()
	local lost = math.min(money, caps)

	--- Not enough is not a debt. It is everything they had.
	character:SetMoney(money - lost)

	---------------------------------------------------------- recognition ---

	--[[
		Both directions, and the second one is the one that needs the list.
		See the header.
	]]
	local id = character:GetID()

	character:SetData("rgn", "")

	local forgotten = {[id] = true}

	for _, other in pairs(ix.char.loaded) do
		if (other == character) then continue end

		Strip(other, forgotten)
	end

	ix.pk.forget[tostring(id)] = os.time()

	ix.pk.Save()

	----------------------------------------------------------------- head ---

	--[[
		Half a metre off the ground so it does not land inside the floor, and
		at the position rather than on the ragdoll - a ragdoll can slide a long
		way in the moment after a death.
	]]
	--[[
		THE HEAD IS NOT DROPPED. THE BODY IS NAMED.

		This used to spawn "<name>'s Head" on the floor at the moment of death,
		which gave the trophy to the ground rather than to anybody: it appeared
		whether or not a soul was there to see it, and could be picked up by
		somebody who had nothing to do with the kill.

		Now a permanent kill leaves a body that says whose it is, and the head
		has to be CUT OFF it like every other head - three seconds of standing
		over somebody you just killed, in a place where their friends know
		where to look. `ix.corpse.TakeHead` reads this and names the item.

		`ixPermakilled` is set on the PLAYER, synchronously, because
		`sv_dismember.lua` reads it to decide NOT to burst the head: a fatal
		headshot on a marked character must leave the head where it is, or the
		shot that earned the trophy destroys it.
	]]
	client.ixPermakilled = true

	--[[
		A frame later, because `sv_corpse.lua` makes the body in its own
		`PlayerDeath` listener and two listeners on one event run in `pairs`
		order - so "has the corpse been made yet" has no answer at this point
		and always does at the next.
	]]
	local name = character:GetName()
	local where = client:GetPos()

	timer.Simple(0, function()
		if (not IsValid(client)) then return end

		local corpse = client.ixCorpseBody

		if (IsValid(corpse) and ix.corpse.CanBehead(corpse)) then
			corpse:SetNWString("ixCorpsePK", name)

			ix.corpse.Keep(corpse, ix.config.Get("corpsePKLife", 300))

			return
		end

		--[[
			THE ONE EXCEPTION. A securitron has no head to cut off and a
			creature model may have no `Bip01 Head` to scale away - and a body
			that cannot give up its head, or no body at all, would make a
			permanent kill of one leave nothing. So the named head is left on
			the floor where they died, the way every kill used to.
		]]
		ix.corpse.DropHead(where, name)
	end)

	---------------------------------------------------------------- after ---

	character:SetData("pkUntil", 0)

	--[[
		And they have to become somebody else. Set before the message, so a
		player who reads it and immediately disconnects still comes back to
		the prompt.
	]]
	character:SetData("pkRename", true)

	--[[
		THE TRAINING GOES WITH THE LIFE. Power armour is learned from a
		manual and forgotten here, so a character back from a permanent kill
		reads the book again or stays out of the suit - and any powered suit
		they died in is taken off them now, before the respawn puts them
		back in it. Phoenix's rule.
	]]
	if (character:GetData("paTraining", false)) then
		character:SetData("paTraining", nil)

		if (ix.armor and ix.armor.StripPowerArmor) then
			ix.armor.StripPowerArmor(client)
		end

		client:Notify("You no longer know how to use power armour.")
	end

	Push(client)

	Say(client, "You were killed while marked.", string.format(
		" You lost %d level(s) and %s, your SPECIAL has been reset, and "
		.. "nobody knows you any more.", level - after,
		ix.points.FormatCaps(lost)))

	client:EmitSound("phoenix/ui/nv/ui_rep_bad.mp3", 80)

	--[[
		The prompt waits for the respawn. Asking somebody to write a
		description over their own death screen is asking at the one moment
		they are not looking at the game.
	]]
	timer.Simple(1, function() ix.pk.Prompt(client) end)

	ix.log.Add(client, "pkDeath",
		IsValid(attacker) and attacker:Name() or "something",
		level - after, lost)

	hook.Run("OnPlayerPK", client, attacker, level - after, lost)
end

hook.Add("PlayerDeath", "ixPK", function(client, inflictor, attacker)
	local character = client:GetCharacter()

	if (not character or not ix.pk.IsActive(character)) then return end

	ix.pk.Collect(client, attacker)
end)

--------------------------------------------------------------------------------
-- Logs
--------------------------------------------------------------------------------

ix.log.AddType("pkMark", function(client, name, steamID, seconds, reason)
	return string.format("%s marked %s (%s) for death for %d second(s) - %s",
		client and client:Name() or "the server", name, steamID, seconds,
		reason)
end, FLAG_DANGER)

ix.log.AddType("pkUnmark", function(client, name, steamID)
	return string.format("%s unmarked %s (%s).",
		client and client:Name() or "the server", name, steamID)
end, FLAG_WARNING)

ix.log.AddType("pkRename", function(client, before, after)
	return string.format("%s was renamed from '%s' to '%s' after a PK.",
		client:Name(), before, after)
end, FLAG_WARNING)

ix.log.AddType("pkDeath", function(client, killer, levels, caps)
	return string.format("%s was PK'd by %s - lost %d level(s) and %d caps.",
		client:Name(), killer, levels, caps)
end, FLAG_DANGER)
