--[[
	Noclip, not observer mode.

	Helix ships an `observer` plugin that turns noclip into something rather
	bigger. You DO noclip - the movetype is right - but it also:

	    client:SetNoDraw(true)        -- invisible
	    client:SetNotSolid(true)
	    client:DrawWorldModel(false)
	    client:GodEnable()
	    client:SetNoTarget(true)

	and, on exiting, teleports you back to where you started if the
	`observerTeleportBack` option is on - which it is by default. That last one
	is usually what makes it feel like noclip is "not working": you fly
	somewhere, turn noclip off, and get yanked back.

	That is a fine tool for spectating a scene. It is the wrong default for
	building or testing, so this makes it a choice.

	WHY THIS PATCHES A CACHE RATHER THAN ADDING A HOOK
	-------------------------------------------------
	Helix replaces `hook.Call`, and the order is not GMod's:

	    HOOKS_CACHE[name]   -- every PLUGIN hook, first
	    Schema[name]        -- the schema, second
	    hook.ixCall(...)    -- ordinary hook.Add listeners, last
	                                    -- core/libs/sh_plugin.lua

	each stage returning early on the first non-nil value. The observer plugin's
	`CanPlayerEnterObserver` returns `true` for anyone with the privilege - so a
	`hook.Add` listener, or even a `Schema:CanPlayerEnterObserver`, never runs at
	all. Neither of the two obvious ways to override this works.

	`HOOKS_CACHE` is a global, and it holds the function reference that stage
	actually calls, so replacing that entry is what changes the answer. The
	original is kept and still consulted when the config is on, which leaves
	observer mode fully intact rather than deleted.

	BOTH OF THE PLUGIN'S HOOKS ARE PATCHED, and that is the fix for this
	having come back twice.

	`CanPlayerEnterObserver` alone is enough IN THEORY - `PLUGIN:PlayerNoClip`
	guards its whole body with it - but it is enough only for as long as our
	entry is the one in the cache, and the cache is rebuilt from the plugin
	table by `ix.plugin.Load` on every reload. Patching `PlayerNoClip` as well
	means the teleport has two independent things to get past rather than one,
	and the second one reads the config at the moment noclip is toggled rather
	than at load.
]]

ix.config.Add("observerOnNoclip", false,
	"Whether noclip puts you in observer mode - invisible, godmode, and " ..
	"teleported back on exit - instead of plain noclip.", nil, {
	category = "Server"
})

if (not SERVER) then return end

ix.observer = ix.observer or {}

--- The functions we have installed. See `Apply` for why it is a set.
ix.observer.patches = ix.observer.patches or {}

--- Whether the last attempt got both hooks in, for `fo_observer`.
ix.observer.state = ix.observer.state or "not attempted yet"

--[[
	Put our version of one plugin hook into the cache, keeping theirs.

	`wrap(original)` builds the replacement. Returns true if the cache now
	holds one of ours, whether this call is what put it there or a previous one
	did.
]]
local function Patch(plugin, name, wrap)
	local cache = HOOKS_CACHE and HOOKS_CACHE[name]
	local original = cache and cache[plugin]

	if (not original) then return false end

	--[[
		IS THE ENTRY OURS? - which is the only question that answers itself
		correctly after a reload.

		This used to be a flag on the PLUGIN TABLE, and the plugin table
		survives a reload while the cache does not: `ix.plugin.Load` rewrites

		    HOOKS_CACHE[k][PLUGIN] = v          -- core/libs/sh_plugin.lua

		from the plugin's own table every time it runs, and `GM:OnReloaded`
		calls `ix.plugin.Initialize()` again. So the flag said "already
		patched" while the cache held the plugin's original function, we
		returned early, and noclip quietly went back to teleporting people.

		A set of our own functions cannot outlive what it describes. It is a
		table keyed by the function rather than a field on it because a
		function cannot carry fields in Lua.
	]]
	if (ix.observer.patches[original]) then return true end

	local patched = wrap(original)

	ix.observer.patches[patched] = true
	cache[plugin] = patched

	return true
end

--[[
	Install both patches. Safe to call at any time and as often as you like.

	Called from three places rather than one, because "the cache was rebuilt
	and nothing told us" is precisely how this broke before:

	    InitializedPlugins   the normal path, at startup
	    OnReloaded           a `lua_refresh` or an auto-refresh
	    PlayerInitialSpawn   anything else at all, before it can matter

	The last one is the belt: whatever rebuilt the cache, the next person to
	join puts it right, and nobody can noclip before they have joined.
]]
function ix.observer.Apply()
	local plugin = ix.plugin.list and ix.plugin.list["observer"]

	if (not plugin) then
		ix.observer.state = "observer plugin not found"

		return false
	end

	--[[
		FIRST GATE: the plugin is asked whether this player may observe, and
		answering no makes `PlayerNoClip` do nothing and return nil - which
		falls through to `GM:PlayerNoClip`, and that is `return
		client:IsAdmin()`. Plain admin noclip.
	]]
	local first = Patch(plugin, "CanPlayerEnterObserver", function(original)
		return function(self, client)
			if (not ix.config.Get("observerOnNoclip", false)) then
				--- False, not nil: nil would let a later stage answer.
				return false
			end

			return original(self, client)
		end
	end)

	--[[
		SECOND GATE: the handler itself. Even if something else answers the
		question above with a yes - another plugin, or our entry having been
		overwritten between reloads - the plugin's own noclip handling is
		skipped entirely while the config is off, which is where the invisible,
		godmoded, teleported-back behaviour all lives.

		`ixObsData` is cleared as well. It is the position it would return you
		to, and a stale one left over from before the config was turned off
		would be used the moment it was turned back on.
	]]
	local second = Patch(plugin, "PlayerNoClip", function(original)
		return function(self, client, state)
			if (not ix.config.Get("observerOnNoclip", false)) then
				if (IsValid(client)) then client.ixObsData = nil end

				return
			end

			return original(self, client, state)
		end
	end)

	ix.observer.state = (first and second) and "both hooks patched"
		or string.format("CanPlayerEnterObserver %s, PlayerNoClip %s",
			first and "patched" or "NOT CACHED",
			second and "patched" or "NOT CACHED")

	if (not first and not second) then
		ErrorNoHalt("[falloutrp] the observer plugin is loaded but neither of "
			.. "its hooks is cached - noclip left as Helix has it\n")
	end

	return first and second
end

--[[
	RETURNING NOTHING, WHICH IS THE WHOLE POINT OF THE WRAPPERS.

	`ix.observer.Apply` answers true or false so that `fo_observer` can report
	what it managed to patch - and a hook.Add listener that returns a value
	STOPS THE HOOK. GMod's `hook.Call` returns the first non-nil answer and
	never calls the gamemode's own function, so passing `Apply` directly as a
	`PlayerInitialSpawn` listener meant `GM:PlayerInitialSpawn` never ran.

	That function is the one that calls `client:LoadData` and sends
	`ixDataSync`, which is what ends the client's loading screen. So everybody
	who joined sat on a black "Loading" forever, and their `ixData` stayed nil
	- which is the `TableToJSON (table expected, got nil)` the server threw
	when they gave up and disconnected.

	A listener that is only doing housekeeping must return nothing at all.
]]
hook.Add("InitializedPlugins", "ixFalloutObserverMode", function()
	ix.observer.Apply()
end)

hook.Add("OnReloaded", "ixFalloutObserverMode", function()
	ix.observer.Apply()
end)

hook.Add("PlayerInitialSpawn", "ixFalloutObserverMode", function()
	ix.observer.Apply()
end)

--[[
	Say so, out loud, because "did the patch apply" is otherwise unanswerable
	from a console and it is the question worth asking when somebody reports
	being teleported back.
]]
concommand.Add("fo_observer", function(client)
	if (IsValid(client) and not client:IsSuperAdmin()) then return end

	ix.observer.Apply()

	local text = string.format("[falloutrp] observer: %s. observerOnNoclip is "
		.. "%s, so noclip is %s.\n", ix.observer.state,
		tostring(ix.config.Get("observerOnNoclip", false)),
		ix.config.Get("observerOnNoclip", false) and "observer mode"
			or "plain noclip - no godmode, no invisibility, no teleport back")

	MsgC(Color(255, 200, 60), text)

	if (IsValid(client)) then client:ChatPrint(text) end
end)
