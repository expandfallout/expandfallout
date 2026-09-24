--[[
	Helix's tool base is an incomplete copy. This completes it.

	`ix.meta.tool` says at the top of itself that it is "code replicated from
	gamemodes/sandbox/entities/weapons/gmod_tool/stool.lua". It is a PARTIAL
	copy: it defines 19 of the 42 methods `ToolObj` has, and its own `Think`
	calls one of the 23 it does not. So a Helix tool errors several times a
	second for as long as anybody holds it:

	    sandbox/.../gmod_tool/cl_init.lua:61   attempt to call 'DrawHUD'
	    helix/.../sh_tool.lua:117              attempt to call 'ReleaseGhostEntity'
	    sandbox/.../gmod_tool/object.lua:163   attempt to call 'GetStage'

	This is almost certainly why nothing else in Helix uses its tool system.

	NO LIST OF METHODS. This is the fourth version of this file and the third
	mechanism. Why each was replaced is worth keeping:

	  1. Rebuild each tool from `ToolObj` in the tool's own file. Depended on
	     `ToolObj` existing at include time, and only ever fixed the tools that
	     remembered to do it.
	  2. Patch the metatable from a `hook.Add("Initialize")` listener. Never
	     ran - Helix loads the schema DURING gamemode initialisation, so the
	     event had already fired.
	  3. Patch the metatable at file scope with a hand-written list of the
	     missing methods, each delegating to `ToolObj[name]`. Two faults. The
	     lookup never resolved, because the last line of `stool.lua` is
	     `ToolObj = nil` - so all 18 were filled in and silently did nothing.
	     And the list was wrong anyway: the real gap is 23, and the five it
	     omitted included `GetStage`, which sandbox's own `GetHelpText` calls.

	The list was the mistake, not its contents. A hand-written enumeration of
	somebody else's class is wrong the moment they add a method, and it is
	wrong quietly. So this sets a METATABLE on `ix.meta.tool` whose `__index`
	is the real base: every method Helix does not define resolves to the
	sandbox one - the 23 missing today and any that appear later, without this
	file being told about them.

	    tool:GetStage()
	      -> not on the instance
	      -> ix.meta.tool                                   (its own __index)
	      -> not there either
	      -> getmetatable(ix.meta.tool).__index = ToolObj   (added here)
	      -> found

	FINDING THE REAL BASE. `ToolObj` is nil by the time anything here runs, but
	the table is still alive: `ToolObj:Create` does `setmetatable(o, self)`, so
	every sandbox tool object carries it as its metatable. It is recovered from
	one of those, which is the only route to it that still exists:

	    weapons.GetStored("gmod_tool").Tool -> a sandbox tool -> getmetatable

	The search skips `ix.meta.tool`, which is essential rather than tidy:
	Helix's tools are in that same list, their metatable is the table being
	patched, and pointing a table's `__index` at itself makes every miss loop
	forever.

	NOTHING HELIX DEFINES IS OVERWRITTEN. A metatable is consulted only after a
	lookup on the table itself has missed, so this cannot shadow anything - a
	stronger guarantee than the `if (not meta[name])` guard the previous
	version needed, and one made by the mechanism rather than by care.
]]

--[[
	Used only when the sandbox base cannot be found at all.

	Not a reimplementation. These are the methods the toolgun calls every
	frame, and their only job is to stop a console flooding at 60 Hz from being
	the way that failure presents. Everything else stays nil, which is the
	honest state: the method genuinely is not there.

	`FreezeMovement` must answer false rather than nothing, because the toolgun
	uses it to decide whether to lock the player's view, and a nil is read as
	"no" by luck rather than by intent.
]]
local FALLBACKS = {
	DrawHUD = function() end,
	FreezeMovement = function() return false end,
	GetHelpText = function() return "" end,
	GetOperation = function(self) return self.Operation or 0 end,
	GetStage = function(self) return self.Stage or 0 end,
	NumObjects = function() return 0 end,
	ReleaseGhostEntity = function() end,
	UpdateData = function() end
}

local realBase
local warned

--[[
	Recover `ToolObj` from a live sandbox tool.

	Identified by what it HAS rather than by name: the real base is the one
	that already implements the methods this file exists to supply. Two are
	checked rather than one because `ix.meta.tool` would pass a single-method
	test once anything had been added to it.
]]
local function FindBase()
	--[[
		The global is still checked first. An addon that restores it should be
		believed over a metatable dug out of somebody else's tool.
	]]
	if (istable(ToolObj)) then return ToolObj end

	local swep = weapons.GetStored("gmod_tool")
	local tools = swep and swep.Tool

	if (not istable(tools)) then return end

	for _, tool in pairs(tools) do
		local meta = getmetatable(tool)

		if (istable(meta) and meta ~= (ix.meta and ix.meta.tool)
		and isfunction(meta.ReleaseGhostEntity)
		and isfunction(meta.SetObject)) then
			return meta
		end
	end
end

--[[
	Resolved on first use and kept.

	Deliberately NOT latched on failure: the sandbox tools have to be
	registered first, and a lookup that happens before that should retry rather
	than decide forever. The WARNING is latched, so a server where the base is
	genuinely unreachable says so once instead of every frame.
]]
local function GetBase()
	if (realBase) then return realBase end

	realBase = FindBase()

	if (realBase) then
		MsgC(Color(255, 200, 100),
			"[falloutrp] tool base: delegating to the sandbox implementation.\n")
	elseif (not warned) then
		warned = true

		MsgC(Color(255, 160, 160),
			"[falloutrp] tool base: sandbox base NOT reachable - only the " ..
			"per-frame methods are stubbed, the rest are absent.\n")
	end

	return realBase
end

--[[
	The metatable itself.

	`__index` starts as a FUNCTION because the base cannot be resolved this
	early. Once it has been, the function replaces itself with the table, so
	every later miss is a plain table lookup rather than a Lua call.
]]
local fallbackMeta = {}

fallbackMeta.__index = function(_, key)
	local base = GetBase()

	if (base) then
		fallbackMeta.__index = base

		return base[key]
	end

	return FALLBACKS[key]
end

--[[
	RUN AT LOAD, NOT FROM A HOOK - see the note about attempt 2 above.

	`ix.meta.tool` exists well before this: Helix loads `core/meta/` before it
	touches the schema. The hooks below only cover a Lua refresh, where the
	meta is rebuilt.
]]
local function ApplyToolFix()
	local meta = ix.meta and ix.meta.tool

	if (not istable(meta)) then return false end

	local existing = getmetatable(meta)

	if (existing == fallbackMeta) then return true end

	--[[
		Helix sets no metatable on this table - checked, in
		`core/meta/sh_tool.lua`, where the only `setmetatable` is the one
		`Create` puts on each instance. If some addon adds one later it is
		chained rather than discarded, because silently dropping somebody
		else's inheritance is the same class of bug this whole file is about.
	]]
	if (istable(existing)) then
		local previous = existing.__index

		fallbackMeta.__index = function(target, key)
			local inherited

			if (istable(previous)) then
				inherited = previous[key]
			elseif (isfunction(previous)) then
				inherited = previous(target, key)
			end

			if (inherited ~= nil) then return inherited end

			local base = GetBase()

			return base and base[key] or FALLBACKS[key]
		end
	end

	setmetatable(meta, fallbackMeta)

	return true
end

local applied = ApplyToolFix()

MsgC(Color(255, 200, 100), applied
	and "[falloutrp] tool base: completed by metatable fallback.\n"
	or "[falloutrp] tool base: ix.meta.tool WAS MISSING - not patched.\n")

--[[
	Re-applied on a refresh. Idempotent: the guard above returns early when the
	metatable is already ours, and Helix reuses the same table across a reload
	(`local TOOL = ix.meta.tool or {}`) so the patch usually survives anyway.
]]
--[[
	WRAPPED SO THE LISTENER RETURNS NOTHING.

	`ApplyToolFix` answers true or false for the caller below, and a hook.Add
	listener that returns a value STOPS THE HOOK: GMod's `hook.Call` takes the
	first non-nil answer, returns it, and never runs the remaining listeners or
	the gamemode's own function. Several things listen to `InitPostEntity` -
	and one of them returning true would silently cancel the rest.

	This cost a whole evening once already: `PlayerInitialSpawn` wired the same
	way meant `GM:PlayerInitialSpawn` never ran, nobody's data ever loaded, and
	every client sat on a black "Loading" screen for ever. See gotcha 27.
]]
hook.Add("OnReloaded", "ixToolBaseFix", function()
	ApplyToolFix()
end)

hook.Add("InitPostEntity", "ixToolBaseFix", function()
	ApplyToolFix()
end)
