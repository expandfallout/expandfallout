--[[
	The chat types this schema adds, and the switches for the ones it does not.

	ONLY `advert` IS NEW. Helix already ships `/w` `/whisper`, `/y` `/yell`,
	`/me`, `/it`, `//` `/ooc`, `[[` `/looc` and `/roll` - they are registered
	in `core/libs/sh_chatbox.lua` under the `InitializedConfig` hook, and every
	one of them already answers to both `/` and `!` because
	`libs/sh_adminverbs.lua` rewrites the prefix. Writing our own would mean
	two chat types with the same name and the second one winning, which is a
	worse outcome than reading the framework.

	    /w, /whisper     quarter of the normal range
	    /y, /yell        twice the normal range
	    //, /ooc         everybody, and switchable - see below
	    /advert          everybody, ours

	THE SWITCHES ARE CONFIGS, not permissions, because "is this server the kind
	that has adverts" is a decision made once and left alone:

	    advertEnabled    ours, added here
	    allowGlobalOOC   HELIX'S OWN, already in the config menu

	`allowGlobalOOC` is not re-declared here. Adding a second config that also
	turned OOC off would leave a server owner with two switches for one thing
	and no way to tell which one is being obeyed - Helix's `ooc` class reads
	its own, so its own is the one that must be set.
]]

--------------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------------

ix.config.Add("advertEnabled", true,
	"Whether players may use /advert.", nil, {category = "Chat"})

--[[
	A COOLDOWN, because an advert is heard by everybody.

	OOC has one for exactly this reason (`oocDelay`) and an advert is louder:
	it is in character, so people answer it. Phoenix have no delay and a length
	cap instead; this has both, because the cap only stops one message being
	long and the delay is what stops there being forty of them.
]]
ix.config.Add("advertDelay", 60,
	"Seconds a player must wait between adverts.", nil, {
	data = {min = 0, max = 3600}, category = "Chat"})

ix.config.Add("advertMaxLength", 512,
	"The longest an advert may be, in characters.", nil, {
	data = {min = 32, max = 1024}, category = "Chat"})

--- Phoenix's amber. Loud enough to find in a busy chatbox, not an alarm.
ix.chat.advertColour = Color(255, 193, 71)

--[[
	THE TICK, QUIETER. `surface.PlaySound` has no volume, so the base game's
	chat tick came out at full; it is played through the player instead,
	at `fo_advert_volume`, which each player can turn down further or off.
	Level 0 is "everywhere, no attenuation", so it does not get quieter
	still for being in the wrong place.
]]
if (CLIENT) then
	local tickVolume = CreateClientConVar("fo_advert_volume", "0.35", true,
		false, "How loud the /advert chat tick is, 0 to 1.")

	function ix.chat.Tick()
		local client = LocalPlayer()
		local level = math.Clamp(tickVolume:GetFloat(), 0, 1)

		if (not IsValid(client) or level <= 0) then return end

		client:EmitSound("common/talk.wav", 0, 100, level, CHAN_STATIC)
	end
end

--------------------------------------------------------------------------------
-- /advert
--------------------------------------------------------------------------------

--[[
	Broadcast, in character.

	`CanHear` is left off entirely, which is how a chat class says "everybody":
	`ix.chat.Register` supplies a `CanHear` that answers true when there is
	none, and a range of `math.huge` would be a number the chatbox then tries
	to square.

	WHETHER YOUR NAME IS ON IT DEPENDS ON WHETHER THEY KNOW YOU. That is
	Phoenix's rule and it is the right one for a radio broadcast in a game with
	recognition: a stranger's advert is a voice, and a friend's advert is a
	friend. The two lines the server owner asked for, exactly:

	    [GLOBAL]: I have water to trade
	    [GLOBAL] Vault Dweller says: I have water to trade
]]
--[[
	STAFF SKIP THE WAITS. `chat.bypass` lifts the /advert delay above and
	Helix's own OOC delay below. Helix gates its OOC timer on a CAMI
	privilege this schema's ranks do not grant, so its `CanSay` is wrapped:
	for somebody with the permission the last-OOC stamp is cleared before
	Helix looks at it, and Helix then sees no wait to enforce.
]]
if (ix.admin and ix.admin.RegisterPermission) then
	ix.admin.RegisterPermission("chat.bypass",
		"Skip the /advert and /ooc cooldowns", "Staff")
end

do
	local ooc = ix.chat.classes.ooc

	if (ooc and ooc.CanSay and not ooc.ixBypassWrapped) then
		local canSay = ooc.CanSay

		ooc.ixBypassWrapped = true
		ooc.CanSay = function(self, speaker, text, ...)
			if (SERVER and ix.admin and ix.admin.Can(speaker, "chat.bypass")) then
				speaker.ixLastOOC = nil
			end

			return canSay(self, speaker, text, ...)
		end
	end
end

ix.chat.Register("advert", {
	description = "Broadcast a message to everybody on the server.",
	prefix = {"/Advert", "/Global"},
	indicator = "chatTalking",

	CanSay = function(self, speaker, text)
		if (not ix.config.Get("advertEnabled", true)) then
			speaker:Notify("Adverts are disabled on this server.")

			return false
		end

		--[[
			DEAD IS NOT ON THE RADIO. `deadCanChat` is off, so Helix's own
			default would already refuse this - but its message is the generic
			"you do not have permission", which is not what happened.
		]]
		if (not speaker:Alive()) then
			speaker:Notify("You cannot advertise while you are dead.")

			return false
		end

		local limit = ix.config.Get("advertMaxLength", 512)

		if ((utf8.len(text) or #text) > limit) then
			speaker:Notify(string.format(
				"An advert can only be %d characters.", limit))

			return false
		end

		--[[
			THE DELAY IS THE SERVER'S, AND SO IS THE CLOCK IT IS MEASURED ON.

			`CanSay` is only ever called from the server half of
			`ix.chat.Send`, so the guard is not what makes this server-side -
			it is what makes that obvious to the next person, who would
			otherwise read `speaker.ixLastAdvert` and go looking for where the
			client sets it. `CurTime` is a different clock in each realm and
			this field only exists in one of them.
		]]
		if (SERVER) then
			local delay = ix.config.Get("advertDelay", 60)

			--- Staff skip the wait; see `chat.bypass` below.
			if (ix.admin and ix.admin.Can(speaker, "chat.bypass")) then
				delay = 0
			end

			if (delay > 0 and speaker.ixLastAdvert) then
				local since = CurTime() - speaker.ixLastAdvert

				if (since <= delay) then
					speaker:Notify(string.format(
						"You can advertise again in %d second(s).",
						math.ceil(delay - since)))

					return false
				end
			end

			speaker.ixLastAdvert = CurTime()
		end

		return true
	end,

	OnChatAdd = function(self, speaker, text)
		--[[
			RECOGNITION IS ASKED THE WAY THE RECOGNITION PLUGIN ASKS IT -
			`character:DoesRecognize`, plus the `IsPlayerRecognized` hook that
			lets anything else override it. `cl_karma.lua` says why at length,
			including why `GetCharacterName` is the wrong hook to test.

			A server with the recognition plugin off recognises everybody,
			which is what it means for recognition not to be in use - so the
			absence of `DoesRecognize` counts as knowing them.
		]]
		local client = LocalPlayer()
		local known = speaker == client

		if (not known and IsValid(speaker)) then
			local ours = client:GetCharacter()
			local theirs = speaker:GetCharacter()

			known = not ours or not theirs or not ours.DoesRecognize
				or ours:DoesRecognize(theirs)
				or hook.Run("IsPlayerRecognized", speaker) == true
		end

		--[[
			ONE COLOUR FOR THE WHOLE LINE, which is Phoenix's. An advert is
			read as a single announcement rather than as somebody speaking, and
			colouring the name differently would make it look like local chat
			that happened to carry a tag.
		]]
		if (known and IsValid(speaker)) then
			chat.AddText(ix.chat.advertColour, string.format(
				"[GLOBAL] %s says: %s", speaker:Name(), text))
		else
			chat.AddText(ix.chat.advertColour, "[GLOBAL]: " .. text)
		end

		--- The base game's chat tick, for whoever sent it and whoever
		--- received it alike, and nothing else; quieter, see above.
		ix.chat.Tick()
	end
})
