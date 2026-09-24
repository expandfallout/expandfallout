--[[
	Doing it: tying, cutting free, searching.

	`sh_restrain.lua` describes the two kinds and registers the menu entries;
	this is what happens when one is chosen. The order of the checks is the same
	everywhere - the interaction library has already established that these two
	people are alive, near each other and playing characters, so nothing here
	repeats that.

	EVERY ONE OF THESE IS A STARED ACTION. `DoStaredAction` re-traces every
	tenth of a second and cancels the moment you look away, which is Helix's own
	and is what Phoenix used too. It is the difference between tying somebody up
	and clicking a button at them.
]]

if (not SERVER) then return end

util.AddNetworkString("ixRestrainSearch")

--------------------------------------------------------------------------------
-- The state
--------------------------------------------------------------------------------

--[[
	Put somebody in restraints. No timing, no checks - the callers do those.

	`SetRestricted` is Helix's and does the heavy half: it strips the weapons,
	remembers each one with its item and its clip, and blocks item use and
	`PlayerUse` until it is turned off.
]]
function ix.restrain.Apply(target, kindID, client)
	local kind = ix.restrain.kinds[kindID]

	if (not kind) then return false end

	target:SetNetVar("restraint", kindID)
	target:SetRestricted(true)

	--[[
		WHO, as a character id rather than the player.

		A player reference here would be a reference held past a disconnect,
		and the question it answers - "are these your cuffs?" - is about the
		character anyway.
	]]
	local character = IsValid(client) and client:GetCharacter()

	target.ixRestrainedBy = character and character:GetID() or nil

	hook.Run("PlayerRestrained", client, target, kindID)

	if (IsValid(client)) then
		ix.log.Add(client, "restrain", target:Name(), kind.name)
	end

	return true
end

--[[
	The state, and nothing but the state.

	NO WEAPON RESTORE, which is the whole reason this is separate from
	`Release`. `SetRestricted(false)` hands the stripped weapons back with
	`client:Give`, and giving a weapon to somebody who has just died - or just
	disconnected - is at best pointless and at worst a `SetClip1` on a nil
	weapon. Death and disconnect come through here; a person being cut free
	goes through `Release`.
]]
function ix.restrain.Clear(target)
	if (not IsValid(target)) then return end

	ix.restrain.CloseSearch(target)

	target:SetNetVar("restraint", nil)
	target:SetNetVar("restricted", nil)
	target:SetLocalVar("restrictNoMsg", nil)

	target.ixRestrictWeps = nil
	target.ixRestrainedBy = nil
end

--- Free somebody properly, weapons and all.
function ix.restrain.Release(target, client)
	if (not ix.restrain.Is(target)) then return false end

	ix.restrain.CloseSearch(target)

	target:SetNetVar("restraint", nil)
	target:SetRestricted(false)
	target.ixRestrainedBy = nil

	hook.Run("PlayerUnrestrained", client, target)

	if (IsValid(client)) then
		ix.log.Add(client, "restrainRelease", target:Name())
	end

	return true
end

--------------------------------------------------------------------------------
-- Tying somebody up
--------------------------------------------------------------------------------

--[[
	Start tying. Shared by the menu entry and by the item's own Use, because
	they are the same act reached two ways and only one of them should own the
	rules.
]]
function ix.restrain.Begin(client, target, kindID)
	local kind = ix.restrain.kinds[kindID]

	if (not kind) then return false end
	if (client.ixRestrainBusy) then return false end

	if (not ix.restrain.Holding(client, kind)) then
		client:Notify(kind.needsHeld and "You need those in your hands."
			or "You do not have any.")

		return false
	end

	local time = ix.config.Get(kind.applyKey, 5)

	client.ixRestrainBusy = true

	target:EmitSound(kind.applySound)
	target:Notify("[ ! ] You are being restrained!")
	target:EmitSound("phoenix/ui/nv/ui_popup_messagewindow.mp3", 60)

	--[[
		"me" rather than Phoenix's "it". Theirs reads "** takes the persons
		hands and starts tying them together", with no subject at all; "me"
		puts the actor in front of it through the recognition system, so
		somebody you have not met is described rather than named.
	]]
	ix.chat.Send(client, "me", "takes the person's hands and starts tying "
		.. "them together . . .")

	client:SetAction("Restraining", time)
	target:SetAction("You are being restrained", time)

	client:DoStaredAction(target, function()
		client.ixRestrainBusy = nil

		--[[
			EVERYTHING IS RE-CHECKED HERE. Five seconds is long enough for the
			item to have been dropped, for them to have been tied by somebody
			else, or for either of them to have died - and `DoStaredAction`
			only promises that the two of you are still looking at each other.
		]]
		if (not IsValid(client) or not IsValid(target)) then return end
		if (not client:Alive() or not target:Alive()) then return end
		if (ix.restrain.Is(target)) then return end

		if (not ix.restrain.Holding(client, kind)) then
			client:Notify("You no longer have those.")

			return
		end

		client:SetAction()
		target:SetAction()

		target:EmitSound(kind.doneSound, 100, 140)
		ix.chat.Send(client, "me", kind.applyText)

		ix.restrain.Apply(target, kindID, client)

		--[[
			A TIE IS SPENT AND A PAIR OF CUFFS IS NOT, which is the whole
			difference in cost between them: ties are cheap and gone, cuffs are
			expensive and yours.
		]]
		if (kind.consumed) then
			local held = ix.restrain.FindItem(client, kind.item)

			if (held) then held:Remove() end
		end
	end, time, function()
		client.ixRestrainBusy = nil

		if (IsValid(client)) then
			client:Notify("[ ! ] Restraining failed.")
			client:SetAction()
		end

		if (IsValid(target)) then target:SetAction() end
	end)

	return true
end

--------------------------------------------------------------------------------
-- Cutting somebody free
--------------------------------------------------------------------------------

function ix.restrain.BeginRelease(client, target)
	local kindID = ix.restrain.Kind(target)
	local kind = kindID and ix.restrain.kinds[kindID]

	if (not kind) then return false end
	if (client.ixRestrainBusy) then return false end

	local time = ix.config.Get(kind.releaseKey, 5)

	client.ixRestrainBusy = true

	client:SetAction(kind.release .. "ing", time)
	target:SetAction("You are being freed", time)

	client:DoStaredAction(target, function()
		client.ixRestrainBusy = nil

		if (not IsValid(client) or not IsValid(target)) then return end
		if (not ix.restrain.Is(target)) then return end

		--[[
			The cuffs must still be in hand at the END of it as well as at the
			start, for the same reason the tie must be: a check that only runs
			when the bar starts is a check you can walk out of.
		]]
		if (kind.releaseNeedsItem
		and not ix.restrain.Holding(client, kind)) then
			client:Notify("You no longer have " .. kind.name:lower() .. ".")

			return
		end

		client:SetAction()
		target:SetAction()

		ix.chat.Send(client, "me", kind.releaseText)
		target:EmitSound(kind.doneSound, 80, 110)
		target:Notify("You have been freed.")

		ix.restrain.Release(target, client)
	end, time, function()
		client.ixRestrainBusy = nil

		if (IsValid(client)) then client:SetAction() end
		if (IsValid(target)) then target:SetAction() end
	end)

	return true
end

--------------------------------------------------------------------------------
-- Searching them
--------------------------------------------------------------------------------

--[[
	Shut a search window, whoever has it open.

	Called when the restraint ends, when either of them dies, and when either
	of them leaves - a window onto somebody's pockets that outlives the reason
	you were allowed to look in them is a duplication bug waiting to happen.
]]
function ix.restrain.CloseSearch(target)
	if (not IsValid(target)) then return end

	local character = target:GetCharacter()
	local inventory = character and character:GetInventory()

	if (not inventory or not inventory.storageInfo) then return end
	if (not inventory.storageInfo.ixSearch) then return end

	ix.storage.Close(inventory)
end

--[[
	Open somebody's pockets.

	`ix.storage` is Helix's own container plumbing and this is an ordinary use
	of it: the target is the "entity", so the stared action that gates the
	search is against the person, and walking away closes the window.

	THE CAPS ROW IS SUPPRESSED. `ix.storage.Sync` fills `info.data.money` from
	the entity's character, and the panel that shows it will also let you take
	it - which would make searching a mugging, and mugging is its own system
	with its own limits. `cl_restrain.lua` no-ops the money rows for exactly
	this inventory, the same way the bin does.
]]
function ix.restrain.Search(client, target)
	local character = target:GetCharacter()
	local inventory = character and character:GetInventory()

	if (not inventory) then return false end

	if (ix.storage.InUse(inventory)) then
		client:Notify("Somebody is already searching them.")

		return false
	end

	net.Start("ixRestrainSearch")
		net.WriteUInt(inventory:GetID(), 32)
	net.Send(client)

	ix.storage.Open(client, inventory, {
		name = character:GetName(),
		entity = target,
		searchTime = ix.config.Get("restrainSearchTime", 3),
		searchText = "Searching...",
		bMultipleUsers = false,

		--- Read back by `CloseSearch`; nothing else marks a context as ours.
		ixSearch = true
	})

	ix.log.Add(client, "restrainSearch", target:Name())

	return true
end

--[[
	THE CAPS ARE STOPPED HERE, NOT IN THE PANEL.

	`cl_restrain.lua` hides the money row, and hiding a row is worth exactly
	nothing: `ixStorageMoneyTake` is a net message, and a client that sends one
	by hand while a search is open empties the searched character's pockets
	however the panel is drawn. Helix's own receiver checks that the inventory
	is the one you have open and takes the money from whoever the storage
	entity's character is - which, for a search, is the person being searched.

	So the two receivers are WRAPPED and refuse while the open storage is a
	search. Wrapped rather than replaced: everything Helix does for an ordinary
	container - the rate limit, the clamp, the log, the update to the other
	receivers - is theirs and still runs.

	`net.Receivers` is the same trick `sv_sandbox.lua` uses on
	`concommand.GetTable()`, and it is checked rather than assumed: if it is
	ever not there, the search still works and the console says plainly that
	the hole is open.
]]
local function WrapStorageMoney()
	if (ix.restrain.wrappedMoney) then return true end
	if (not net.Receivers) then return false end

	local names = {"ixstoragemoneytake", "ixstoragemoneygive"}

	for _, name in ipairs(names) do
		if (not net.Receivers[name]) then return false end
	end

	for _, name in ipairs(names) do
		local original = net.Receivers[name]

		net.Receivers[name] = function(length, client)
			local inventory = client.ixOpenStorage

			if (inventory and inventory.storageInfo
			and inventory.storageInfo.ixSearch) then
				return
			end

			return original(length, client)
		end
	end

	ix.restrain.wrappedMoney = true

	return true
end

if (not WrapStorageMoney()) then
	timer.Create("ixRestrainMoneyGuard", 1, 10, function()
		if (WrapStorageMoney()) then
			timer.Remove("ixRestrainMoneyGuard")

			return
		end

		if (timer.RepsLeft("ixRestrainMoneyGuard") == 0) then
			ErrorNoHalt("[falloutrp] could not guard storage money: caps "
				.. "can be taken out of a searched inventory\n")
		end
	end)
end

--------------------------------------------------------------------------------
-- Ending it for reasons nobody chose
--------------------------------------------------------------------------------

hook.Add("PlayerDeath", "ixRestrain", function(client)
	if (ix.restrain.Is(client)) then ix.restrain.Clear(client) end

	--- Their searcher loses the window whether or not THEY were the one tied.
	ix.restrain.CloseSearch(client)
end)

hook.Add("PlayerDisconnected", "ixRestrain", function(client)
	ix.restrain.CloseSearch(client)
end)

--[[
	A restraint does not survive a character swap or a relog.

	Helix's `restricted` is a netvar and netvars do not persist, so half of the
	state would come back cleared and the other half - our own netvar - would
	come back with it. Clearing on load makes that one answer.
]]
hook.Add("PlayerLoadedCharacter", "ixRestrain", function(client)
	ix.restrain.Clear(client)
end)

ix.log.AddType("restrain", function(client, name, kind)
	return string.format("%s restrained %s with %s.", client:Name(), name, kind)
end, FLAG_WARNING)

ix.log.AddType("restrainRelease", function(client, name)
	return string.format("%s freed %s.", client:Name(), name)
end)

ix.log.AddType("restrainSearch", function(client, name)
	return string.format("%s searched %s.", client:Name(), name)
end, FLAG_WARNING)
