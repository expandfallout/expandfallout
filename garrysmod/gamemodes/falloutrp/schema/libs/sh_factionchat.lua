--[[
	Faction chat and officer chat: `/f` and `/o`.

	A RADIO, NOT A WHISPER. `/f hold the gate` reaches every member of the
	speaker's faction wherever they are - and it is also SAID, out loud, into
	a handset: anybody stood near the speaker hears it, and anybody stood
	near a member whose radio just answered hears it there too. `/o` is the
	same on the officers' channel: members below `officerChatRank` neither
	receive it nor send on it, but they can stand next to somebody who does.

	ENCRYPTED COMMS is a switch on the faction, in the live editor. Off, a
	bystander hears the words. On, a bystander hears static - the same line,
	with every character replaced - and only the faction reads it. The
	scrambling is done on the SERVER before anything is sent, so a client
	that is not in the faction never has the real text to un-scramble.

	Phoenix's version is server-side and not in the scrape, so this is built
	from what it does rather than from how: two channels, overheard nearby,
	and a faction that can lock them.

	HOW THE OVERHEARING WORKS. The two classes below carry the real text to
	the people entitled to it, through `CanHear`. `PostPlayerSay` then runs
	once for the line and sends a second message - class `comms`, plain or
	scrambled - to everybody within talking range of the speaker or of any
	receiver who did not already get the real one. Two sends, one line, and
	the second never contains the words when the faction has locked them.
]]

ix.factionchat = ix.factionchat or {}

--------------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------------

ix.config.Add("factionChatEnabled", true,
	"Whether /f and /o work at all.", nil, {category = "Chat"})

ix.config.Add("officerChatRank", 3,
	"The class rank /o needs: 1 enlisted, 2 NCO, 3 officer, 4 lead.", nil,
	{data = {min = 1, max = 4}, category = "Chat"})

--------------------------------------------------------------------------------
-- Who is who
--------------------------------------------------------------------------------

--- A player's faction index, or nil.
function ix.factionchat.FactionOf(client)
	if (not IsValid(client) or not client:IsPlayer()) then return nil end

	local character = client:GetCharacter()

	return character and character:GetFaction() or nil
end

--- Whether a player's class is high enough for the officers' channel.
function ix.factionchat.IsOfficer(client)
	return ix.factionmgmt and ix.factionmgmt.GetRank(client)
		>= ix.config.Get("officerChatRank", 3)
end

--- Whether a faction has locked its channels.
function ix.factionchat.IsEncrypted(faction)
	local info = faction and ix.faction.indices[faction]

	return info ~= nil and info.encryptedComms == true
end

--- Whether a listener gets the REAL line on a channel, radio in hand.
function ix.factionchat.Hears(chatType, speaker, listener)
	local faction = ix.factionchat.FactionOf(speaker)

	if (not faction or faction ~= ix.factionchat.FactionOf(listener)) then
		return false
	end

	if (chatType == "officer") then return ix.factionchat.IsOfficer(listener) end

	return true
end

--[[
	What static sounds like written down: every character that is not a
	space becomes one from this set, so the line keeps its shape - you can
	tell how much was said - and none of its words. Random per line, because
	a fixed substitution is a cipher and somebody would break it.
]]
local GLYPHS = "ABCDEFGHJKLMNPQRSTUVWXYZ0123456789#%&*+=?"

function ix.factionchat.Scramble(text)
	return (string.gsub(tostring(text or ""), "%S", function()
		local index = math.random(#GLYPHS)

		return string.sub(GLYPHS, index, index)
	end))
end

--------------------------------------------------------------------------------
-- The channels
--------------------------------------------------------------------------------

local function CanSay(chatType, speaker)
	if (not ix.config.Get("factionChatEnabled", true)) then
		if (SERVER) then speaker:Notify("The radio is off.") end

		return false
	end

	if (not ix.factionchat.FactionOf(speaker)) then
		if (SERVER) then speaker:Notify("You are not in a faction.") end

		return false
	end

	if (chatType == "officer" and not ix.factionchat.IsOfficer(speaker)) then
		if (SERVER) then speaker:Notify("That channel is for officers.") end

		return false
	end

	return true
end

--- The faction's colour, from the team - which a bot's speaker has too.
local function FactionColor(speaker)
	if (IsValid(speaker) and speaker:IsPlayer()) then
		return team.GetColor(speaker:Team())
	end

	return color_white
end

--[[
	THE HANDSET CLICKS. A line you sent opens with the transmit chirp, one
	you received closes with the answer chirp, and one you only overheard
	from somebody else's radio is the same chirp, quieter. The metropolice
	radio chirps are base Half-Life 2 content, so every client has them.
]]
local SEND = "npc/metropolice/vo/on2.wav"
local RECEIVE = "npc/metropolice/vo/off4.wav"

function ix.factionchat.Chirp(speaker, bOverheard)
	if (not CLIENT) then return end

	local me = LocalPlayer()

	if (not IsValid(me)) then return end

	if (bOverheard) then
		me:EmitSound(RECEIVE, 50, 90, 0.3)

		return
	end

	me:EmitSound(speaker == me and SEND or RECEIVE, 60, 100, 0.55)
end

ix.chat.Register("faction", {
	prefix = {"/f", "/faction"},
	indicator = "chatTalking",

	CanSay = function(self, speaker, text)
		return CanSay("faction", speaker)
	end,

	CanHear = function(self, speaker, listener)
		return ix.factionchat.Hears("faction", speaker, listener)
	end,

	OnChatAdd = function(self, speaker, text)
		ix.factionchat.Chirp(speaker, false)

		chat.AddText(FactionColor(speaker), "[FACTION] ", color_white,
			(IsValid(speaker) and speaker:Name() or "Someone") .. ": " .. text)
	end
})

ix.chat.Register("officer", {
	prefix = {"/o", "/officer"},
	indicator = "chatTalking",

	CanSay = function(self, speaker, text)
		return CanSay("officer", speaker)
	end,

	CanHear = function(self, speaker, listener)
		return ix.factionchat.Hears("officer", speaker, listener)
	end,

	OnChatAdd = function(self, speaker, text)
		ix.factionchat.Chirp(speaker, false)

		chat.AddText(FactionColor(speaker), "[OFFICERS] ", color_white,
			(IsValid(speaker) and speaker:Name() or "Someone") .. ": " .. text)
	end
})

--[[
	What a bystander hears: somebody's handset, nearby. The name goes through
	recognition like a spoken line does - you know a voice you know - and the
	words are whatever the server sent, which for a locked faction is static.
	Never typed; `PostPlayerSay` below is the only sender.
]]
local COMMS = Color(150, 160, 150)
local STATIC = Color(120, 130, 120)

ix.chat.Register("comms", {
	OnChatAdd = function(self, speaker, text, anonymous, data)
		local name = hook.Run("GetDisplayedName", speaker, "ic")
			or (IsValid(speaker) and speaker:Name()) or "Someone"

		ix.factionchat.Chirp(speaker, true)

		chat.AddText(COMMS, data and data.officer and "[COMMS, OFFICERS] "
			or "[COMMS] ", color_white, name .. ": ",
			data and data.encrypted and STATIC or color_white, text)
	end
})

--------------------------------------------------------------------------------
-- The people stood nearby
--------------------------------------------------------------------------------

if (SERVER) then
	--[[
		Everybody within talking range of the speaker or of any receiver,
		who did not already receive the real line. `chatRange` is the IC
		range, because a handset is spoken into and answers at speaking
		volume.
	]]
	function ix.factionchat.Overhear(speaker, chatType, text)
		if (not ix.config.Get("factionChatEnabled", true)) then return end

		local faction = ix.factionchat.FactionOf(speaker)

		if (not faction) then return end

		local range = ix.config.Get("chatRange", 280)
		local rangeSq = range * range
		local heard, sources = {[speaker] = true}, {speaker}

		for _, client in player.Iterator() do
			if (client:GetCharacter()
			and ix.factionchat.Hears(chatType, speaker, client)) then
				heard[client] = true
				sources[#sources + 1] = client
			end
		end

		local receivers = {}

		for _, client in player.Iterator() do
			if (not heard[client] and client:GetCharacter()) then
				for _, source in ipairs(sources) do
					if (client:GetPos():DistToSqr(source:GetPos()) <= rangeSq) then
						receivers[#receivers + 1] = client

						break
					end
				end
			end
		end

		if (#receivers == 0) then return end

		local encrypted = ix.factionchat.IsEncrypted(faction)

		ix.chat.Send(speaker, "comms",
			encrypted and ix.factionchat.Scramble(text) or text, false,
			receivers, {encrypted = encrypted, officer = chatType == "officer"})
	end

	--- After the real line has gone out; the arguments are Helix's order.
	hook.Add("PostPlayerSay", "ixFactionChat", function(client, chatType,
		message)
		if (chatType ~= "faction" and chatType ~= "officer") then return end
		if (not CanSay(chatType, client)) then return end

		ix.factionchat.Overhear(client, chatType, message)
	end)
end
