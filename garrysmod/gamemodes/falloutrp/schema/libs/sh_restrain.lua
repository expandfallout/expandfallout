--[[
	Zip ties and handcuffs.

	Phoenix's zip tie is an item you Use while looking at somebody: it traces 96
	units, plays a neck-snap, puts a progress bar on both of you, and if you are
	still looking at them when it finishes they are `setRestricted(true)` and the
	tie is consumed. Everything you can then do to them - untie, search, check
	caps, mug - is an entry in the hold-E menu.

	THIS IS THAT, ON HELIX'S RESTRAINT RATHER THAN A NEW ONE.

	`Player:SetRestricted` already exists in Helix and already does the hard
	half: it strips and REMEMBERS the weapons (with their item and their clip),
	blocks `PlayerUse`, blocks every item interaction, and hands them all back
	on release. NutScript's `setRestricted` does the same job, so the port is
	the verbs around it rather than the state itself.

	WHAT IS ADDED ON TOP:

	    the kind        `restraint` netvar, "ziptie" or "cuffs", because
	                    Helix's `restricted` is a bool and the menu needs to
	                    say "Untie" or "Uncuff" and take the right time over it
	    who did it      so a cuff can be a thing only its owner - or somebody
	                    else holding cuffs - can take off
	    the speed       a tied person walks, and this is the only part that has
	                    to be shared code: movement is predicted

	CUFFS ARE NOT A SECOND SYSTEM. Phoenix's cuffs come from a separate paid
	addon (`Cuffs_DragPlayer`, `IsHandcuffed`) whose code is not in the scrape;
	what their menu shows of it is drag, uncuff, gag and blind. Here a cuff is
	the same restraint as a tie with different numbers and one rule of its own -
	you need cuffs in hand to take cuffs off - which is what makes it the
	stronger of the two rather than a duplicate.
]]

ix.restrain = ix.restrain or {}

--[[
	The two kinds, and everything that differs between them.

	A third would be a table entry: the item, the menu and the server all read
	this rather than testing for "ziptie" anywhere.
]]
ix.restrain.kinds = {
	ziptie = {
		name = "Zip Tie",
		item = "zipties",

		--- What the tooltip over a person in them says.
		label = "ZIP TIED",

		--- What the menu entry that removes it says.
		release = "Untie",
		applyKey = "ziptieTime",
		releaseKey = "ziptieReleaseTime",

		--- Anybody may cut a tie off; that is what makes it the weak one.
		releaseNeedsItem = false,

		--- Cut off and thrown away, so a tie is a supply you run out of.
		consumed = true,

		--[[
			PHOENIX USE HL2 SOUNDS HERE and this server has no HL2 content -
			`resolve_asset.py` finds nothing at `npc/barnacle/`, so theirs
			played silence. These two resolve.
		]]
		applySound = "phoenix/ui/nv/ui_items_clothing_up_01.mp3",
		doneSound = "phoenix/ui/nv/ui_items_clothing_up_03.mp3",
		applyText = "ties the persons hands together with a zip tie.",
		releaseText = "cuts the zip tie from the persons wrists."
	},

	cuffs = {
		name = "Cuffs",
		item = "cuffs",
		label = "CUFFED",
		release = "Uncuff",
		applyKey = "cuffTime",
		releaseKey = "cuffReleaseTime",

		--[[
			CUFFS COME OFF WITH CUFFS. Not a key item - a key is one more thing
			to lose and it would mean a cuffed person is cuffed forever the
			moment the only key is dropped in a river. Holding a pair is the
			same idea and cannot be permanently lost.
		]]
		releaseNeedsItem = true,

		--- A pair of cuffs is a THING. It stays in the pocket it came from.
		consumed = false,

		applySound = "phoenix/ui/nv/ui_items_clothing_up_02.mp3",
		doneSound = "weapons/reload/357revolver/wpn_357revolver_reloadclick.mp3",
		applyText = "locks a pair of cuffs around the persons wrists.",
		releaseText = "unlocks the cuffs from the persons wrists."
	},

	--[[
		AND THE ONE THIS SCHEMA DOES NOT OWN.

		Elastic restraints are the `cuffs` addon's - a licensed SWEP with its
		own state, its own struggling, its own gag and blindfold and its own
		rope. Nothing here applies or removes them; this entry exists so that
		everything which asks "is this person restrained" gets the right answer
		for somebody wearing them, because the search, the caps check and the
		tooltip all ask exactly that.

		`external` is what says so. See `sh_cuffs.lua`.
	]]
	handcuffed = {
		name = "Restraints",
		label = "RESTRAINED",
		external = true
	}
}

ix.config.Add("ziptieTime", 5,
	"Seconds it takes to zip tie somebody.", nil, {
	data = {min = 1, max = 30},
	category = "Restraints"
})

ix.config.Add("ziptieReleaseTime", 5,
	"Seconds it takes to cut somebody's zip ties off.", nil, {
	data = {min = 1, max = 30},
	category = "Restraints"
})

ix.config.Add("cuffTime", 8,
	"Seconds it takes to handcuff somebody.", nil, {
	data = {min = 1, max = 30},
	category = "Restraints"
})

ix.config.Add("cuffReleaseTime", 5,
	"Seconds it takes to unlock somebody's handcuffs.", nil, {
	data = {min = 1, max = 30},
	category = "Restraints"
})

ix.config.Add("restrainSearchTime", 3,
	"Seconds it takes to search a restrained person.", nil, {
	data = {min = 0, max = 30},
	category = "Restraints"
})

ix.config.Add("restrainSpeed", 60,
	"How fast a restrained person moves, as a percentage.", nil, {
	data = {min = 10, max = 100},
	category = "Restraints"
})

--------------------------------------------------------------------------------
-- Reading the state
--------------------------------------------------------------------------------

--[[
	Which kind of restraint somebody is in, or nil.

	A netvar rather than character data, deliberately: everybody in the room can
	see that somebody's hands are tied, and the menu's `canSee` runs on THEIR
	machine.
]]
function ix.restrain.Kind(target)
	if (not IsValid(target) or not target:IsPlayer()) then return end

	local kind = target:GetNetVar("restraint")

	if (kind ~= "" and ix.restrain.kinds[kind]) then return kind end

	--[[
		THE ADDON IS ASKED SECOND, and it is asked at all because a person in
		elastic restraints is restrained by every meaning of the word that
		matters here - they can be searched, their caps can be checked, and the
		tooltip over them should say so - while none of that state is ours.

		`IsHandcuffed` is the addon's own player method and is only there when
		the addon is installed, which is why it is tested rather than called.
	]]
	if (target.IsHandcuffed and target:IsHandcuffed()) then
		return "handcuffed"
	end
end

--- Is this person tied up at all.
function ix.restrain.Is(target)
	return ix.restrain.Kind(target) ~= nil
end

--[[
	Can this person use this kind of restraint RIGHT NOW.

	Two different questions behind one name, which is the point of it
	being a function: a zip tie or a pair of cuffs only has to be
	somewhere in your bag, and elastic restraints have to be the thing in
	your hands. Every check in this file and both items go through here,
	so the two rules cannot drift apart.
]]
function ix.restrain.Holding(client, kind)
	if (not IsValid(client) or not kind) then return false end

	if (kind.needsHeld) then
		local weapon = client:GetActiveWeapon()

		return IsValid(weapon) and weapon:GetClass() == kind.needsHeld
	end

	return ix.restrain.FindItem(client, kind.item) ~= nil
end

--[[
	The first item of a uniqueID somebody is carrying.

	`ix.inventory.Each`, NOT `Iter` - a one-square zip tie would be fine either
	way, but the habit is the point. See gotcha 14.
]]
function ix.restrain.FindItem(client, uniqueID)
	local character = client:GetCharacter()
	local inventory = character and character:GetInventory()

	if (not inventory) then return end

	for item in ix.inventory.Each(inventory) do
		if (item.uniqueID == uniqueID) then return item end
	end
end

--------------------------------------------------------------------------------
-- Moving while tied up
--------------------------------------------------------------------------------

--[[
	SHARED, because movement is predicted.

	Setting the speed on the server alone gives the client a different answer
	to the one the server keeps and the player rubber-bands. `SetupMove` runs
	on both ends off a netvar both ends have.
]]
hook.Add("SetupMove", "ixRestrain", function(client, moveData)
	if (not ix.restrain.Is(client)) then return end

	local speed = client:GetWalkSpeed()
		* (ix.config.Get("restrainSpeed", 60) / 100)

	moveData:SetMaxSpeed(speed)
	moveData:SetMaxClientSpeed(speed)
end)

--------------------------------------------------------------------------------
-- The menu entries
--------------------------------------------------------------------------------

--[[
	Tying somebody up is one entry per kind, built from the table above rather
	than written twice.

	The entry exists on the CLIENT's reading of its own inventory, which is
	honest - it has the inventory - and is checked again on the server, which
	is what matters.
]]
for id, kind in pairs(ix.restrain.kinds) do
	--- Nothing to register for a restraint this schema does not apply.
	if (kind.external) then continue end

	ix.interact.Add("restrain" .. id, {
		name = kind.name,
		order = 20,

		canSee = function(target)
			if (ix.restrain.Is(target)) then return false end
			if (ix.restrain.Is(LocalPlayer())) then return false end

			return ix.restrain.Holding(LocalPlayer(), kind)
		end,

		OnCanRun = function(client, target)
			if (ix.restrain.Is(target)) then
				return false, "They are already restrained."
			end

			if (ix.restrain.Is(client)) then
				return false, "Your own hands are tied."
			end

			if (not ix.restrain.Holding(client, kind)) then
				return false, kind.needsHeld
					and "You need those in your hands."
					or "You do not have any."
			end

			return true
		end,

		OnRun = function(client, target)
			ix.restrain.Begin(client, target, id)
		end
	})
end

ix.interact.Add("restrainRelease", {
	--[[
		"Untie" or "Uncuff" - the menu says which, because walking up to
		somebody in handcuffs and being offered "Untie" reads as a bug.
	]]
	name = function(target)
		local kind = ix.restrain.kinds[ix.restrain.Kind(target)]

		return kind and not kind.external and kind.release
	end,

	order = 21,

	canSee = function(target)
		local id = ix.restrain.Kind(target)

		if (not id) then return false end
		if (ix.restrain.Is(LocalPlayer())) then return false end

		local kind = ix.restrain.kinds[id]

		--- The addon has its own Uncuff entry; see `sh_cuffs.lua`.
		if (kind.external) then return false end

		if (kind.releaseNeedsItem
		and not ix.restrain.Holding(LocalPlayer(), kind)) then
			return false
		end

		return true
	end,

	OnCanRun = function(client, target)
		local id = ix.restrain.Kind(target)

		if (not id) then return false end

		if (ix.restrain.Is(client)) then
			return false, "Your own hands are tied."
		end

		local kind = ix.restrain.kinds[id]

		if (kind.external) then return false end

		if (kind.releaseNeedsItem
		and not ix.restrain.Holding(client, kind)) then
			return false, string.format("You need %s to do that.",
				kind.needsHeld and (kind.name:lower() .. " in your hands")
					or ("a pair of " .. kind.name:lower()))
		end

		return true
	end,

	OnRun = function(client, target)
		ix.restrain.BeginRelease(client, target)
	end
})

ix.interact.Add("restrainSearch", {
	name = "Search Inventory",
	order = 22,

	canSee = function(target)
		return ix.restrain.Is(target) and not ix.restrain.Is(LocalPlayer())
	end,

	OnCanRun = function(client, target)
		if (not ix.restrain.Is(target)) then return false end

		if (ix.restrain.Is(client)) then
			return false, "Your own hands are tied."
		end

		return true
	end,

	OnRun = function(client, target)
		ix.restrain.Search(client, target)
	end
})

ix.interact.Add("restrainCheckCaps", {
	name = "Check Caps",
	order = 23,

	canSee = function(target)
		return ix.restrain.Is(target) and not ix.restrain.Is(LocalPlayer())
	end,

	OnCanRun = function(client, target)
		if (not ix.restrain.Is(target)) then return false end

		if (ix.restrain.Is(client)) then
			return false, "Your own hands are tied."
		end

		return true
	end,

	OnRun = function(client, target)
		local money = target:GetCharacter():GetMoney()

		client:Notify(string.format("%s is carrying %s.",
			target:GetCharacter():GetName(), ix.points.FormatCaps(money)))
	end
})
