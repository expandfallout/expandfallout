--[[
	"Introduce Yourself", in the hold-E menu.

	Helix ships recognition already: a character keeps a list of the character
	ids it knows in `rgn` data, and anybody it does not know is shown by their
	description instead of their name. What it does NOT ship is a way to reach
	it that anybody finds. Theirs is `ShowSpare1` - a bind almost nobody has -
	which opens a four-option menu covering looking-at, whisper, talk and yell
	range.

	THIS IS THE LOOKING-AT ONE, and only that one, because it is the only one
	of the four that is about a PERSON rather than a radius. The other three
	still work from the bind they always did.

	THE DIRECTION IS THE THING PEOPLE GET WRONG. Recognising is not something
	you do TO someone: you tell them who you are and THEIR character learns YOUR
	name. So the entry is on the menu you open on them, and what it writes is
	your id into their list. There is deliberately no "recognise them" action -
	being able to learn a name without being told one is the whole system
	undone.
]]

ix.interact.Add("recognizeIntroduce", {
	name = "Introduce Yourself",
	order = 10,

	--[[
		Always offered, because the question it would be conditional on -
		"do they already know me?" - is THEIR character's data and is networked
		to them alone. Guessing at it here would hide the entry from people it
		works for.
	]]
	canSee = function(target)
		local character = LocalPlayer():GetCharacter()

		return character ~= nil and target:GetCharacter() ~= nil
	end,

	OnRun = function(client, target)
		local character = client:GetCharacter()
		local other = target:GetCharacter()

		--[[
			`Recognize` answers false when the id is already in their list,
			which is the only way this end can know - see `canSee` above.
		]]
		if (not other:Recognize(character:GetID())) then
			client:Notify("They already know who you are.")

			return false
		end

		--[[
			Helix's own message, sent the way Helix sends it. `ixRecognizeDone`
			is their net string and their client runs `CharacterRecognized` off
			it, which is what plays the sound - so this sounds exactly like
			introducing yourself through their menu, because it is.
		]]
		net.Start("ixRecognizeDone")
		net.Send(client)

		hook.Run("CharacterRecognized", client, character:GetID())

		--[[
			THE NOTIFICATION IS THE WHOLE OF IT. There was a `/me` here as
			well - "Vault Dweller introduces themselves." - and it is noise: the
			two people involved both know what just happened, one from the
			sound and one from this line, and everybody else in the room gets
			a chat message about a handshake they did not need to hear about.
		]]
		target:Notify(character:GetName() .. " introduces themselves.")
	end
})

--------------------------------------------------------------------------------
-- A stranger still has a description
--------------------------------------------------------------------------------

--[[
	YOU CAN READ SOMEBODY YOU HAVE NEVER MET.

	Helix's recognition plugin replaces the description of anybody you do not
	know with "You do not recognize this person", which is the wrong way round
	for this schema: the NAME is the thing you have to be told, and the
	description is what you can see with your own eyes. Hiding it leaves a
	stranger as a blank label with nothing to roleplay against - no gas mask,
	no scars, no Legion armour - and the only way to refer to somebody you have
	not been introduced to is to describe them.

	So the plugin's override is removed and Helix's own behaviour underneath -
	show the description - is what runs. `GetCharacterName` is untouched, so a
	stranger is still "Unknown".

	HOW: `HOOKS_CACHE` is the table `hook.Call` walks BEFORE the schema and
	before ordinary `hook.Add` listeners, so a schema function cannot override
	a plugin's - the plugin returns first and a non-nil return wins. It is a
	global, and it maps `[hookName][pluginTable] = function`, so the entry can
	be replaced by name. That is the same "wrap by name" this schema uses for
	Helix's panels and the cuffs addon.

	Wrapped rather than deleted, so anything else the plugin's version might do
	in a later Helix version still runs - it is only its RETURN that is
	dropped.
]]
--[[
	Which replacements are ours, as a SET OF FUNCTIONS.

	A function cannot carry a field in Lua - `Allow.ixDescriptions = true` is an
	"attempt to index a function value", and so is reading one back. That is
	what this table is for: it answers "have we already replaced this" without
	writing anything onto the function itself.
]]
local ours = {}

local function AllowDescriptions()
	local plugin = ix.plugin and ix.plugin.list and ix.plugin.list.recognition
	local cache = HOOKS_CACHE and HOOKS_CACHE.GetCharacterDescription

	if (not plugin or not cache or not cache[plugin]) then return false end
	if (ours[cache[plugin]]) then return true end

	local original = cache[plugin]

	local function Allow(self, client)
		original(self, client)
	end

	ours[Allow] = true
	cache[plugin] = Allow

	return true
end

--[[
	`InitializedPlugins` rather than file scope: the recognition plugin is one
	of Helix's own and they are loaded BEFORE the schema, so it is normally
	already there - but the cache entry only exists once that plugin has been
	through `ix.plugin.Load`, and this costs nothing to be sure about.
]]
--[[
	WRAPPED SO THE LISTENER RETURNS NOTHING.

	`AllowDescriptions` answers true or false for the caller below, and a hook.Add
	listener that returns a value STOPS THE HOOK: GMod's `hook.Call` takes the
	first non-nil answer, returns it, and never runs the remaining listeners or
	the gamemode's own function. Several things listen to `InitializedPlugins` -
	and one of them returning true would silently cancel the rest.

	This cost a whole evening once already: `PlayerInitialSpawn` wired the same
	way meant `GM:PlayerInitialSpawn` never ran, nobody's data ever loaded, and
	every client sat on a black "Loading" screen for ever. See gotcha 27.
]]
hook.Add("InitializedPlugins", "ixRecogniseDescriptions", function()
	AllowDescriptions()
end)

AllowDescriptions()
