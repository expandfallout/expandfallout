--[[
	Where this schema meets the `cuffs` addon.

	`addons/cuffs` is my_hat_stinks' Cuffs - the same licensed addon Phoenix
	use, which is why their hold-E menu has entries calling `Cuffs_DragPlayer`
	and `Cuffs_FreePlayer`. None of it is ported or modified: the addon owns
	the restraint entirely - applying it, the struggle that breaks out of it,
	the gag, the blindfold and the rope you drag somebody along by - and this
	file is the three things that have to exist on OUR side of that line.

	    the entries    Drag, Uncuff, Gag and Blindfold in the hold-E menu,
	                   which is exactly Phoenix's set, and each one sends the
	                   addon's own net message so the addon does the checking
	    the config     the elastic restraint's numbers, in the dev terminal,
	                   because they are SWEP fields and a SWEP field is not
	                   something an admin can reach in game
	    the rules      who may cuff whom, through `CuffsCanHandcuff`

	WHY THE ENTRIES ARE CLIENT CALLBACKS. Every other entry in the interaction
	menu sends `ixInteract` and is checked by `ix.interact.Run`; these send the
	addon's messages instead, because the addon re-checks everything itself -
	it traces 100 units from the sender, confirms the target is cuffed, and
	confirms the sender is not. Routing them through our server first would
	mean two sets of rules for one action, and the addon's would still be the
	one that decided.
]]

ix.cuffs = ix.cuffs or {}

--- The one the item hands out. The addon ships several; this is Phoenix's.
ix.cuffs.class = "weapon_cuff_elastic"

--------------------------------------------------------------------------------
-- The numbers
--------------------------------------------------------------------------------

--[[
	These are SWEP FIELDS, which is the whole problem they solve.

	`weapon_cuff_elastic.lua` sets `SWEP.CuffTime = 0.9` and so on, and a field
	in an addon's source is not something anybody can change without editing a
	licensed addon - which would be lost on its next update and is not ours to
	edit anyway. So the values are configs, and `ix.cuffs.Apply` writes them
	onto the stored weapon table instead.

	The defaults are the addon's own, so a server that never touches these
	behaves exactly as the addon intends.
]]
local FIELDS = {
	{key = "restraintTime", field = "CuffTime", default = 0.9,
		min = 0.1, max = 30, decimals = 1,
		description = "Seconds of holding click it takes to restrain "
			.. "somebody."},

	{key = "restraintStrength", field = "CuffStrength", default = 1.0,
		min = 0.1, max = 10, decimals = 1,
		description = "How hard elastic restraints are to break out of."},

	{key = "restraintRegen", field = "CuffRegen", default = 1.6,
		min = 0, max = 10, decimals = 1,
		description = "How fast elastic restraints recover while somebody "
			.. "struggles."},

	{key = "restraintRope", field = "RopeLength", default = 100,
		min = 0, max = 512,
		description = "How far somebody can be dragged by their restraints. "
			.. "Zero means they cannot be dragged."}
}

local FLAGS = {
	{key = "restraintGag", field = "CuffGag", default = true,
		description = "Whether a restrained person can be gagged."},

	{key = "restraintBlind", field = "CuffBlindfold", default = true,
		description = "Whether a restrained person can be blindfolded."}
}

for _, entry in ipairs(FIELDS) do
	ix.config.Add(entry.key, entry.default, entry.description, function()
		ix.cuffs.Apply()
	end, {
		data = {min = entry.min, max = entry.max, decimals = entry.decimals},
		category = "Restraints"
	})
end

for _, entry in ipairs(FLAGS) do
	ix.config.Add(entry.key, entry.default, entry.description, function()
		ix.cuffs.Apply()
	end, {category = "Restraints"})
end

--[[
	Write the configured numbers onto the weapon.

	BOTH THE STORED TABLE AND EVERY LIVE ONE. `weapons.Register` keeps the
	table a new weapon is built from, so changing it alone would leave anybody
	already carrying a pair on the old numbers until they dropped them - which
	is exactly the sort of half-applied setting that gets reported as "the
	config does nothing".
]]
function ix.cuffs.Apply()
	local stored = weapons.GetStored(ix.cuffs.class)

	if (not stored) then return false end

	local values = {}

	for _, entry in ipairs(FIELDS) do
		values[entry.field] = ix.config.Get(entry.key, entry.default)
	end

	for _, entry in ipairs(FLAGS) do
		values[entry.field] = ix.config.Get(entry.key, entry.default) and true
			or false
	end

	--[[
		The variance goes to zero along with it. The addon randomises each pair
		by up to a tenth, which is a nice touch on a server that never tunes
		them and a source of "why did that one break instantly" on one that
		does.
	]]
	values.CuffStrengthVariance = 0
	values.CuffRegenVariance = 0

	for field, value in pairs(values) do
		stored[field] = value
	end

	for _, weapon in ipairs(ents.FindByClass(ix.cuffs.class)) do
		if (not IsValid(weapon)) then continue end

		for field, value in pairs(values) do
			weapon[field] = value
		end
	end

	return true
end

--[[
	Applied once everything is registered, and again on a delay.

	`InitializedPlugins` runs after the schema's own files but the addon is an
	`autorun`, which is earlier - so the weapon is there by then. The timer is
	the belt and braces this codebase uses everywhere for load order it does
	not control.
]]
hook.Add("InitializedPlugins", "ixCuffs", function()
	if (not ix.cuffs.Apply()) then
		timer.Create("ixCuffsApply", 1, 10, function()
			if (ix.cuffs.Apply()) then timer.Remove("ixCuffsApply") end
		end)
	end
end)

--------------------------------------------------------------------------------
-- Who may cuff whom
--------------------------------------------------------------------------------

--[[
	The addon asks before it cuffs anybody, which is the one hook it needs from
	us. Everything here is a rule this schema has and the addon cannot know
	about.
]]
hook.Add("CuffsCanHandcuff", "ixCuffs", function(client, target)
	if (not IsValid(client) or not IsValid(target)) then return end
	if (not target:IsPlayer()) then return end

	if (not client:GetCharacter() or not target:GetCharacter()) then
		return false
	end

	--- Somebody already tied with a zip tie is not cuffed on top of it.
	if (ix.restrain.Kind(target)) then
		client:Notify("They are already restrained.")

		return false
	end

	if (ix.restrain.Is(client)) then
		client:Notify("Your own hands are tied.")

		return false
	end
end)

--------------------------------------------------------------------------------
-- Taking the addon's key prompts down
--------------------------------------------------------------------------------

--[[
	THE ADDON BINDS E, AND E IS THE INTERACTION MENU NOW.

	`sh_handcuffs.lua` adds a `PlayerBindPress` listener that turns `+use` on a
	cuffed player into `Cuffs_FreePlayer` and returns true to swallow the bind -
	so holding E on somebody restrained both fought the menu for the key and
	started releasing them without being asked. Its HUD prompt then advertised
	that key, along with three more for gag, blindfold and drag.

	All four of those are entries in the menu now, so the prompts are noise and
	the E binding is a conflict.

	WRAPPED BY NAME, NOT DELETED. `hook.Add` with an existing name replaces
	that one listener and leaves the rest of the addon alone, which matters for
	a licensed addon we do not modify: `+attack`, `+attack2` and `+reload` still
	reach their original handler, so tying somebody to a hook - the one thing
	with no menu entry - still works exactly as it did.
]]
local function TakeOverBinds()
	local listeners = hook.GetTable().PlayerBindPress

	local original = listeners and listeners["Cuffs CuffedInteract"]

	if (not original) then return false end
	if (ix.cuffs.wrappedBinds) then return true end

	ix.cuffs.wrappedBinds = true

	hook.Add("PlayerBindPress", "Cuffs CuffedInteract",
		function(client, bind, pressed)
			if (string.lower(bind or "") == "+use") then return end

			return original(client, bind, pressed)
		end)

	return true
end

--[[
	And their prompt, replaced with the only part of it worth keeping.

	The key hints go; the PROGRESS BAR stays, because releasing somebody is a
	thing that takes time and the addon gives no other sign of how far along it
	is. Same trick, same reason: register over their name.
]]
local COLOR_BAR_BACK = Color(20, 22, 20, 200)
local COLOR_BAR_EDGE = Color(0, 0, 0, 220)

local function TakeOverPrompt()
	local listeners = hook.GetTable().HUDPaint

	if (not listeners or not listeners["Cuffs CuffedInteractPrompt"]) then
		return false
	end

	if (ix.cuffs.wrappedPrompt) then return true end

	ix.cuffs.wrappedPrompt = true

	hook.Add("HUDPaint", "Cuffs CuffedInteractPrompt", function()
		local client = LocalPlayer()

		if (not IsValid(client) or client:IsHandcuffed()) then return end

		local trace = util.TraceLine({
			start = client:EyePos(),
			endpos = client:EyePos() + client:GetAimVector() * 100,
			filter = client
		})

		local target = trace.Entity

		if (not IsValid(target) or not target:IsPlayer()) then return end

		local cuffed, weapon = target:IsHandcuffed()

		if (not cuffed or not IsValid(weapon)) then return end

		local progress = math.Clamp(weapon:GetCuffBroken() / 100, 0, 1)

		if (progress <= 0) then return end

		local width, height = ScrW() * 0.11, ScrH() * 0.018
		local x, y = (ScrW() - width) * 0.5, ScrH() * 0.5 - height * 3

		surface.SetDrawColor(COLOR_BAR_BACK)
		surface.DrawRect(x, y, width, height)

		surface.SetDrawColor(ix.fallout.GetPalette().color_primary)
		surface.DrawRect(x, y, width * progress, height)

		surface.SetDrawColor(COLOR_BAR_EDGE)
		surface.DrawOutlinedRect(x, y, width, height, 1)
	end)

	return true
end

if (CLIENT) then
	local function TakeOver()
		local binds = TakeOverBinds()
		local prompt = TakeOverPrompt()

		return binds and prompt
	end

	--[[
		The addon is an `autorun`, so its listeners exist before the schema
		loads - but a retry costs nothing and covers a load order this file does
		not control. Ten seconds, then it gives up quietly: the menu still works
		either way, there would just be a stale prompt under it.
	]]
	if (not TakeOver()) then
		timer.Create("ixCuffsTakeOver", 1, 10, function()
			if (TakeOver()) then timer.Remove("ixCuffsTakeOver") end
		end)
	end
end

--------------------------------------------------------------------------------
-- The menu entries
--------------------------------------------------------------------------------

--[[
	Phoenix's four - Drag, Uncuff, Gag, Blindfold - done on the SERVER.

	THEY WERE CLIENT CALLBACKS SENDING THE ADDON'S OWN NET MESSAGES, which was
	the tidier idea and does not work here. Every one of those receivers ends
	with the same test:

	    local tr = GetTrace(ply)
	    if not (tr and tr.Entity==target) then return end

	a 100-unit trace that has to land on the target - and by the time you click
	a menu entry you are looking at the ENTRY, which hangs beside their head.
	The trace misses, the addon returns silently, and nothing happens.

	So these call the addon's own accessors directly, which is exactly what its
	receivers do once they are satisfied, and `ix.interact.Run` does the
	checking instead: alive, playing a character, and within reach. Their hooks
	are called with the same arguments so anything listening still hears.
]]
local function Cuffs(target)
	if (not IsValid(target) or not target.IsHandcuffed) then return end

	local cuffed, weapon = target:IsHandcuffed()

	if (not cuffed or not IsValid(weapon)) then return end

	return weapon
end

--- Only somebody who is not restrained themselves can do any of this.
local function Free(client)
	if (not IsValid(client)) then return false end

	if (client.IsHandcuffed and client:IsHandcuffed()) then return false end

	return not ix.restrain.Is(client)
end

local function Register()
	ix.interact.Add("cuffsDrag", {
		name = function(target)
			local weapon = Cuffs(target)

			if (not weapon) then return end

			return IsValid(weapon:GetKidnapper()) and "Let Go" or "Drag"
		end,

		order = 24,

		canSee = function(target)
			local weapon = Cuffs(target)

			--- No rope, no dragging - the addon refuses it anyway.
			return weapon ~= nil and weapon:GetRopeLength() > 0
				and Free(LocalPlayer())
		end,

		OnCanRun = function(client, target)
			local weapon = Cuffs(target)

			if (not weapon or weapon:GetRopeLength() <= 0) then return false end
			if (not Free(client)) then return false, "Your hands are tied." end

			return true
		end,

		OnRun = function(client, target)
			local weapon = Cuffs(target)
			local kidnapper = weapon:GetKidnapper()

			if (kidnapper == client) then
				weapon:SetKidnapper(nil)

				hook.Call("OnHandcuffStopDragging", GAMEMODE, client, target,
					weapon)

				client:Notify("You let go of them.")

				return
			end

			if (IsValid(kidnapper)) then
				client:Notify("Somebody else has hold of them.")

				return
			end

			weapon:SetKidnapper(client)

			hook.Call("OnHandcuffStartDragging", GAMEMODE, client, target,
				weapon)

			client:Notify("You take hold of them.")
		end
	})

	ix.interact.Add("cuffsRelease", {
		name = "Uncuff",
		order = 25,

		canSee = function(target)
			return Cuffs(target) ~= nil and Free(LocalPlayer())
		end,

		OnCanRun = function(client, target)
			if (not Cuffs(target)) then return false end
			if (not Free(client)) then return false, "Your hands are tied." end

			return true
		end,

		--[[
			SETTING THE RELEASE GOING IS ALL THIS DOES. The addon's own
			`BreakThink` runs it down and CANCELS IT IF YOU LOOK AWAY, which is
			its design and worth keeping - so the notification says so, because
			otherwise "I clicked Uncuff and nothing happened" is the obvious
			reading of walking off mid-release.
		]]
		OnRun = function(client, target)
			local weapon = Cuffs(target)

			if (IsValid(weapon:GetFriendBreaking())) then
				client:Notify("Somebody is already working on those.")

				return
			end

			weapon:SetFriendBreaking(client)

			client:Notify("Keep looking at them to cut them free.")
		end
	})

	ix.interact.Add("cuffsGag", {
		name = function(target)
			local weapon = Cuffs(target)

			if (not weapon) then return end

			return weapon:GetIsGagged() and "Ungag" or "Gag"
		end,

		order = 26,

		canSee = function(target)
			local weapon = Cuffs(target)

			return weapon ~= nil and weapon:GetCanGag() and Free(LocalPlayer())
		end,

		OnCanRun = function(client, target)
			local weapon = Cuffs(target)

			if (not weapon or not weapon:GetCanGag()) then return false end
			if (not Free(client)) then return false, "Your hands are tied." end

			return true
		end,

		OnRun = function(client, target)
			local weapon = Cuffs(target)
			local gagged = not weapon:GetIsGagged()

			weapon:SetIsGagged(gagged)

			hook.Call(gagged and "OnHandcuffGag" or "OnHandcuffUnGag",
				GAMEMODE, client, target, weapon)
		end
	})

	ix.interact.Add("cuffsBlind", {
		name = function(target)
			local weapon = Cuffs(target)

			if (not weapon) then return end

			return weapon:GetIsBlind() and "Remove Blindfold" or "Blindfold"
		end,

		order = 27,

		canSee = function(target)
			local weapon = Cuffs(target)

			return weapon ~= nil and weapon:GetCanBlind()
				and Free(LocalPlayer())
		end,

		OnCanRun = function(client, target)
			local weapon = Cuffs(target)

			if (not weapon or not weapon:GetCanBlind()) then return false end
			if (not Free(client)) then return false, "Your hands are tied." end

			return true
		end,

		OnRun = function(client, target)
			local weapon = Cuffs(target)
			local blind = not weapon:GetIsBlind()

			weapon:SetIsBlind(blind)

			hook.Call(blind and "OnHandcuffBlindfold"
				or "OnHandcuffUnBlindfold", GAMEMODE, client, target, weapon)
		end
	})
end

--[[
	Now if the interaction library is already there, and on the plugin hook if
	it is not - `libs/` is included alphabetically and `sh_cuffs` comes before
	`sh_interact`, so on a cold load it is not. Both, so that a `lua_refresh` of
	this file alone puts the entries back.
]]
if (ix.interact and ix.interact.Add) then
	Register()
else
	hook.Add("InitializedPlugins", "ixCuffsInteract", Register)
end
