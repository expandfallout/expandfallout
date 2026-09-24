--[[
	Armour - the server half.

	WRITTEN, NOT PORTED. Phoenix's `sv_plugin.lua` for Armor V2 does not exist
	in any scrape: glua-steal only ever retrieves what the server sends to a
	client, and server files are never sent. Everything here is reconstructed
	from the contract the base item and `sh_plugin.lua` imply - the functions
	they call (`nut.armor:equip`, `nut.armor:unEquip`), the data they read, and
	the behaviour `_docs/reference/03_armor_and_survival.md` records.

	So this is the one part of the armour system with no reference to check
	against. It is deliberately conservative: every rule it enforces is one the
	client half already assumes.
]]

if (not SERVER) then return end

--[[
	Push the derived state out to the network.

	Three separate things are broadcast, all of them CONSEQUENCES of the
	inventory rather than state in their own right:

	    ixArmor_<slot>   what to draw, read by cl_bodyparts.lua
	    ixHeadDR/BodyDR  the resistance pools, read by the damage path
	    WearingPA        Phoenix's own flag name, kept because their animation
	                     code in sh_anims.lua reads exactly this

	NW2 rather than character vars because `character:SetData` is registered
	`isLocal = true` in Helix - it reaches the owning client only, and every
	player needs to see what everyone else is wearing. NW2 also re-sends to
	late joiners on its own, which a net message would not.
]]
function ix.armor.Refresh(client)
	if (not IsValid(client)) then return end

	local character = client:GetCharacter()

	if (not character) then return end

	local equipped = ix.armor.GetEquipped(character)

	--[[
		Every slot is written, including the empty ones. Writing only the
		occupied slots would leave the last value of a slot you just emptied
		standing, and the armour would keep rendering after it came off.
	]]
	for _, slot in ipairs(ix.armor.slots) do
		local item = equipped[slot]

		client:SetNW2String("ixArmor_" .. slot, item and item.uniqueID or "")
	end

	client:SetNW2Int("ixHeadDR", ix.armor.GetHeadDR(character))
	client:SetNW2Int("ixBodyDR", ix.armor.GetBodyDR(character))
	client:SetNW2Bool("WearingPA", ix.armor.IsWearingPA(character))

	--[[
		Stealth capability is recomputed from what is worn, and losing it drops
		you out of stealth immediately. Otherwise dropping a courser suit while
		cloaked would leave you invisible with nothing providing it.
	]]
	local canStealth = ix.armor.CanStealth(character)

	client:SetNW2Bool("ixStealthCapable", canStealth)

	if (not canStealth and ix.armor.IsStealthed(client)) then
		ix.armor.SetStealth(client, false)
	end

	--[[
		Speed and jump live in `ix.special.Apply`, which reads the armour
		boosts itself. Calling it here is what makes taking a heavy suit off
		give you your legs back immediately rather than on your next spawn.
	]]
	if (ix.special and ix.special.Apply) then
		ix.special.Apply(client)
	end

	--[[
		Height, for the Power Armour suits that set `playerHeight`. Re-applied
		here so putting a suit on changes your height immediately rather than
		on your next spawn - and, more importantly, so taking one off does not
		leave you tall.
	]]
	if (ix.fallout and ix.fallout.ApplyProportions) then
		ix.fallout.ApplyProportions(client)
	end
end

--[[
	Put an armour on.

	Returns `false, reason` rather than notifying directly, so the caller
	decides how the failure is presented - the item's Equip function shows it
	to the player, but a command or a loadout may want to log it instead.
]]
function ix.armor.Equip(client, item)
	if (not IsValid(client) or not item) then
		return false, "@armorNoItem"
	end

	local character = client:GetCharacter()

	if (not character) then return false, "@armorNoItem" end

	if (not item.isArmor or not item.bodyType) then
		return false, "@armorNotArmor"
	end

	if (not ix.armor.isSlot[item.bodyType]) then
		--[[
			A typo in an item's `bodyType` would otherwise create a slot that
			exists only for that item - equippable, never conflicting with
			anything, and contributing to neither resistance pool.
		]]
		return false, "@armorBadSlot"
	end

	if (item:GetData("equip")) then
		return false, "@armorAlreadyEquipped"
	end

	if (not ix.armor.CanRaceWear(item, character:GetRace())) then
		return false, "@armorWrongRace"
	end

	--[[
		POWER ARMOUR HAS TO BE LEARNED. `paTraining` is written on the
		character by the Power Armor Training Manual and taken off it by a
		permanent kill - see `sv_pk.lua` - so a character who has died for
		good reads the book again or stays out of the suit. This is
		Phoenix's rule to the letter.

		SALVAGED SUITS ARE THE EXCEPTION. A frame somebody has stripped the
		fusion systems out of is worn like heavy armour, and `isSalvagedPA`
		says so - on the item, and in the live editor's ARMOUR section.
	]]
	if (item.isPA and not item.isSalvagedPA
	and not character:GetData("paTraining", false)) then
		return false, "@armorNeedsTraining"
	end

	--[[
		A POWER ARMOUR PIECE THAT IS NOT THE SUIT NEEDS THE SUIT ON.

		A T-45 helmet is part of a sealed system - it is not a hat you can put
		on over ordinary clothes, and wearing one alone previously granted the
		whole suit's headshot immunity for the price of a helmet.

		Written against `bodyType ~= "body"` rather than naming helmets, so the
		f4_* Power Armour plates are covered by the same rule.
	]]
	if (item.isPA and item.bodyType ~= "body") then
		local suit = ix.armor.GetEquipped(character).body

		if (not suit or not suit.isPA) then
			return false, "@armorNeedsPowerArmor"
		end
	end

	--[[
		Conflicts are reported, not resolved.

		Taking the blocking piece off automatically would be friendlier right
		up to the point where it silently removes a full helmet to put a hat
		on, and the player finds out when something shoots them in the head.
	]]
	local conflicts = ix.armor.GetConflicts(character, item)

	if (#conflicts > 0) then
		return false, "@armorSlotTaken", conflicts[1].name
	end

	if (item.OnEquip and item:OnEquip(client) == false) then
		return false, "@armorCannotEquip"
	end

	item:SetData("equip", true)
	ix.armor.Refresh(client)

	return true
end

--- Take an armour off. Always allowed; nothing should be able to trap a player in a suit.
function ix.armor.Unequip(client, item)
	if (not IsValid(client) or not item) then
		return false, "@armorNoItem"
	end

	if (not item:GetData("equip")) then
		return false, "@armorNotEquipped"
	end

	if (item.OnUnequip) then
		item:OnUnequip(client)
	end

	item:SetData("equip", nil)

	--[[
		Taking the SUIT off takes its helmet and plates with it.

		Without this the equip rule above is bypassed in three clicks: put the
		suit on, add the helmet, take the suit off - and the helmet stays,
		which is the exact state that rule exists to prevent.

		Done after the suit's own flag is cleared, so the recursive call sees a
		character that is genuinely no longer wearing Power Armour.
	]]
	if (item.isPA and item.bodyType == "body") then
		local character = client:GetCharacter()

		if (character) then
			for _, worn in pairs(ix.armor.GetEquipped(character)) do
				if (worn.isPA and worn.bodyType ~= "body") then
					ix.armor.Unequip(client, worn)
				end
			end
		end
	end

	ix.armor.Refresh(client)

	return true
end

--[[
	Rebuild on spawn and on character load.

	`PostPlayerLoadout` is the point Helix has finished handing out weapons and
	running `OnLoadout` on inventory items, so the equipped set is settled and
	the derived state can be computed once rather than per item.

	Deferred a frame on character load because the inventory is not guaranteed
	to have arrived at the moment the hook runs.
]]
hook.Add("PostPlayerLoadout", "ixArmorRefresh", function(client)
	ix.armor.Refresh(client)
end)

hook.Add("PlayerLoadedCharacter", "ixArmorRefresh", function(client)
	timer.Simple(0, function()
		ix.armor.Refresh(client)
	end)
end)

--[[
	Damage resistance.

	`ScalePlayerDamage` rather than `EntityTakeDamage`, because it is the only
	one of the two that says WHERE you were hit, and the whole point of this
	system is that a hat does not protect your chest.

	Fall damage is excluded here and handled separately below. It can arrive
	through both hooks depending on how it was inflicted, and applying the
	reduction in both would square it.
]]
--[[
	Outgoing damage, from chems like Psycho.

	`EntityTakeDamage` rather than `ScalePlayerDamage`, because the attacker is
	what matters here and `ScalePlayerDamage` only ever fires on the victim -
	so it cannot tell you whether the person who pulled the trigger was on
	anything. This fires for damage to NPCs too, which is where most of it
	lands.
]]
hook.Add("EntityTakeDamage", "ixBuffDamage", function(target, dmginfo)
	local attacker = dmginfo:GetAttacker()

	if (not IsValid(attacker) or not attacker:IsPlayer()) then return end

	local bonus = ix.buff and ix.buff.Get(attacker, "DMG") or 0

	if (bonus ~= 0) then
		dmginfo:ScaleDamage(math.max(1 + bonus / 100, 0))
	end
end)

hook.Add("ScalePlayerDamage", "ixArmorResistance", function(client, hitgroup, dmginfo)
	if (dmginfo:IsDamageType(DMG_FALL)) then return end

	local character = client:GetCharacter()

	if (not character) then return end

	--[[
		Read from the network rather than recomputing.

		`GetHeadDR` walks the whole inventory, which is fine when equipment
		changes and wrong once per bullet. The networked value is written by
		`Refresh` at exactly the moments it can change.
	]]
	--[[
		WHERE IT LANDED, on a model that may not say. A creature's hitboxes
		are often all group 0 - every super mutant hitbox is - so
		`ix.dismember.Hitgroup` places a generic hit by the nearest known
		bone. A head the engine did not call a head also gets the base
		game's own headshot doubling here, because `GM:ScalePlayerDamage`
		will not see one to double.
	]]
	local placed = ix.dismember and ix.dismember.Hitgroup
		and ix.dismember.Hitgroup(client, hitgroup, dmginfo:GetDamagePosition())
		or hitgroup
	local isHead = placed == HITGROUP_HEAD

	if (isHead and hitgroup ~= HITGROUP_HEAD) then
		dmginfo:ScaleDamage(ix.hitgroup and ix.hitgroup.baseHead or 2)
	end

	--[[
		POWER ARMOUR AND HEADSHOTS.

		Two separate things happen, and only the first was here originally.

		1. The head is resisted with the BODY pool. A sealed helmet is the
		   point of the suit, and it stops a helmet's smaller pool being the
		   weak spot on the heaviest armour in the game.

		2. The headshot MULTIPLIER is capped, which needs doing explicitly.
		   The base gamemode's own `GM:ScalePlayerDamage` runs AFTER this hook
		   - `hook.Add` listeners first, then the gamemode method - and it does:

		       if (hitgroup == HITGROUP_HEAD) then dmginfo:ScaleDamage(2) end
		                        -- gamemodes/base/gamemode/player.lua

		   so swapping the resistance pool alone still left a full x2 landing
		   on a suit that is supposed to be sealed. Pre-scaling by cap/2 here
		   makes the net multiplier equal the cap once the gamemode has had its
		   turn. Phoenix express the same number as a config named
		   "Power Armor Max Headshot Mult", default 1.75.

		This is order-dependent on the base gamemode, which is worth knowing if
		anything ever overrides `ScalePlayerDamage` - at present nothing does.
	]]
	if (isHead and client:GetNW2Bool("WearingPA", false)) then
		isHead = false

		dmginfo:ScaleDamage(ix.config.Get("powerArmorHeadshotMult", 1.75) / 2)
	end

	local resistance = isHead and client:GetNW2Int("ixHeadDR", 0)
		or client:GetNW2Int("ixBodyDR", 0)

	--[[
		Med-X and the rest add flat DR on top of the armour's.

		Added rather than networked with the armour value because a chem
		expires on a timer of its own and rewriting the armour's networked
		number every time one did would make the two impossible to tell apart -
		and the inventory would then show a suit's DR that included a chem.
	]]
	resistance = resistance + (ix.buff and ix.buff.Get(client, "DR") or 0)

	--[[
		AND THE RACE'S OWN HIDE.

		`RACE.naturalResistance` is a percentage every member of that race has
		before any armour - a deathclaw is hard to hurt with a pistol whatever
		it is wearing, which on a creature race is usually nothing at all. It
		is added into the same pool as the armour and the chems and clamped
		once with them, so three sources cannot stack past immunity.

		Read off the race rather than networked: it changes only when the live
		editor changes it, and the table is on both realms already.
	]]
	local race = ix.races.Get(character:GetRace())

	resistance = resistance + math.max(tonumber(race and race.naturalResistance)
		or 0, 0)

	if (resistance > 0) then
		dmginfo:ScaleDamage(1 - math.Clamp(resistance, 0, 100) / 100)
	end
end)

--[[
	Fall protection.

	In `EntityTakeDamage` because fall damage does not reliably carry a
	hitgroup, and because reducing it in `GetFallDamage` would mean guessing
	the base damage the gamemode was about to produce rather than scaling the
	one it did.
]]
hook.Add("EntityTakeDamage", "ixArmorFallProtection", function(target, dmginfo)
	if (not IsValid(target) or not target:IsPlayer()) then return end
	if (not dmginfo:IsDamageType(DMG_FALL)) then return end

	local character = target:GetCharacter()

	if (not character) then return end

	local protection = ix.armor.GetFallProtection(character)

	if (protection > 0) then
		dmginfo:ScaleDamage(1 - math.Clamp(protection, 0, 100) / 100)
	end
end)

--[[
	FUSION CORES.

	A Power Armour suit that is not `noCore` holds a `core` charge, 0-100, on
	the item instance - so the charge belongs to the specific suit, not to the
	armour type. That is the whole reason equipped state lives on the item here
	rather than on the character as a uniqueID string, as Phoenix stored it:
	their version could not tell one suit from another.

	Drain is `Core Drain Rate` per second WHILE MOVING, defaulting to 0.01.
	That is 0.01 percentage points, so a full core lasts a long time on foot -
	it is a slow running cost, not a fuel gauge.
]]
--[[
	The headshot multiplier while in Power Armour.

	Phoenix's "Power Armor Max Headshot Mult", same default. The base gamemode
	multiplies headshots by 2; this is the number the suit brings that down to.
]]
ix.config.Add("powerArmorHeadshotMult", 1.75,
	"Headshot damage multiplier while wearing Power Armour.", nil, {
	form = "Float",
	data = {min = 0.01, max = 10, decimals = 2},
	category = "Armor"
})

ix.config.Add("coreDrainRate", 0.01,
	"Fusion core charge drained per second while moving in Power Armour.",
	nil, {
	form = "Float",
	data = {min = 0.01, max = 1, decimals = 2},
	category = "Armor"
})

--[[
	Put a fusion core into the suit being worn.

	Searches the inventory for anything flagged `isFusionCore` rather than for
	a uniqueID, so a variant core works without editing this.
]]
function ix.armor.EquipFusionCore(client, armorItem)
	if (not IsValid(client)) then return false, "@armorNoItem" end

	local character = client:GetCharacter()
	local inventory = character and character:GetInventory()

	if (not inventory) then return false, "@armorNoItem" end

	--[[
		Body slot only, re-checked here because the item's OnCanRun is a
		client-side affordance and this is the rule.
	]]
	if (not armorItem or not armorItem.isPA or armorItem.noCore
	or armorItem.bodyType ~= "body") then
		return false, "@armorNotPowered"
	end

	--[[
		Refuses a suit that is already full. Otherwise a misclick silently
		destroys a core for no gain, which is the kind of thing a player only
		notices once they need it.
	]]
	if (armorItem:GetData("core", 0) >= 100) then
		return false, "@armorCoreFull"
	end

	for item in ix.inventory.Each(inventory) do
		if (not item.isFusionCore) then continue end

		local charge = item:GetData("charge", item.charge or 100)

		--[[
			The core is consumed BEFORE the charge is written. If removal
			fails, nothing has been granted; doing it the other way round
			would hand out charge from a core that never left the inventory.
		]]
		if (not item:Remove()) then return false, "@armorNoItem" end

		armorItem:SetData("core", math.Clamp(
			armorItem:GetData("core", 0) + charge, 0, 100))

		client.noCoreCharge = nil

		ix.armor.Refresh(client)

		return true
	end

	return false, "@armorNoCore"
end

--[[
	The drain itself.

	One timer for every player rather than a think hook per player: this runs
	once a second, and a think would run it sixty-odd times for a value that
	changes by a hundredth.
]]
timer.Create("ixArmorCoreDrain", 1, 0, function()
	local rate = ix.config.Get("coreDrainRate", 0.01)

	for _, client in ipairs(player.GetAll()) do
		if (not IsValid(client) or not client:Alive()) then continue end

		local character = client:GetCharacter()

		if (not character) then continue end

		local armorItem = ix.armor.GetPoweredArmor(character)

		if (not armorItem) then
			--[[
				Cleared when the suit comes off, or a player who ran a core
				flat would keep the walk-speed penalty out of armour.
			]]
			if (client.noCoreCharge) then
				client.noCoreCharge = nil
				ix.special.Apply(client)
			end

			continue
		end

		local charge = armorItem:GetData("core", 0)

		if (charge <= 0) then
			--[[
				A dead core does not immobilise you, it takes your run away -
				the suit becomes a burden you are carrying rather than a
				machine helping you carry it.

				The flag is what matters; `ix.special.Apply` reads it and pins
				run speed to walk speed. Setting the speed here directly - which
				is what this used to do - held only until the next spawn or
				attribute change, and then handed the sprint back.
			]]
			if (not client.noCoreCharge) then
				client.noCoreCharge = true
				client:NotifyLocalized("armorCoreEmpty")
				ix.special.Apply(client)
			end

			continue
		end

		--[[
			Charge is back, so the run is back. `EquipFusionCore` clears the
			flag itself, but this catches every other way a suit can end up
			charged - an admin setting the data, a swapped suit, a load - so
			the penalty cannot outlive the empty core that caused it.
		]]
		if (client.noCoreCharge) then
			client.noCoreCharge = nil
			ix.special.Apply(client)
		end

		-- Only while moving. Standing in a suit costs nothing.
		if (client:GetVelocity():Length2D() < 5) then continue end

		armorItem:SetData("core", math.max(charge - rate, 0))
	end
end)

--[[
	STEALTH.

	Phoenix's rules, from `_docs/reference/03_armor_and_survival.md`: drawing
	anything outside `ix.armor.validStealthWeapons` breaks stealth outright,
	and moving faster than `Stealth Shimmer Velocity` makes you shimmer rather
	than hiding you completely.

	The shimmer itself is drawn client-side in `cl_bodyparts.lua`; this half
	only decides whether you are stealthed at all.
]]
ix.config.Add("stealthShimmerVelocity", 5,
	"The speed above which a stealthed player shimmers.", nil, {
	data = {min = 5, max = 500},
	category = "Armor"
})

ix.config.Add("stealthDescriptionDistance", 50,
	"How close you must be to read a stealthed player's description.", nil, {
	data = {min = 10, max = 500},
	category = "Armor"
})

timer.Create("ixArmorStealthWeapon", 0.5, 0, function()
	for _, client in ipairs(player.GetAll()) do
		if (not IsValid(client) or not ix.armor.IsStealthed(client)) then
			continue
		end

		local weapon = client:GetActiveWeapon()
		local class = IsValid(weapon) and weapon:GetClass() or "ix_hands"

		if (not ix.armor.validStealthWeapons[class]) then
			ix.armor.SetStealth(client, false)
			client:NotifyLocalized("armorStealthBroken")
		end
	end
end)

--[[
	Stealth does not survive death or taking the suit off. `Refresh` is the one
	place that knows what is currently worn, so it is the one place that can
	answer whether stealth should still be on.
]]
--[[
	And a check on the way back in, which is what unsticks anybody already
	wrong.

	`ixStealth` is persisted on the player entity for the session, so a
	character left cloaked by a bug stays cloaked through every respawn until
	something asks whether they should be. This asks.
]]
hook.Add("PlayerSpawn", "ixArmorStealth", function(client)
	timer.Simple(0, function()
		if (not IsValid(client)) then return end
		if (not ix.armor.IsStealthed(client)) then return end

		if (not ix.armor.CanStealth(client:GetCharacter())) then
			ix.armor.SetStealth(client, false)
		end
	end)
end)

hook.Add("PlayerDeath", "ixArmorStealth", function(client)
	ix.armor.SetStealth(client, false)
end)

--[[
	The stealth toggle.

	Phoenix expose this as a bindable command rather than something that
	happens on equip - `nut.settings:register("stealthBind", ...)` binds a key
	to a `toggleStealth` concommand, which asks the server. Same shape here.

	Every check is re-run server-side. The client sending the message proves
	nothing about whether it is wearing a suit.
]]
util.AddNetworkString("ixArmorStealthToggle")

local nextToggle = {}

net.Receive("ixArmorStealthToggle", function(length, client)
	if (not IsValid(client) or not client:Alive()) then return end

	-- A held bind should not toggle sixty times a second.
	if ((nextToggle[client] or 0) > RealTime()) then return end

	nextToggle[client] = RealTime() + 0.5

	local character = client:GetCharacter()

	if (not character or not ix.armor.CanStealth(character)) then
		client:NotifyLocalized("armorNoStealth")
		return
	end

	--[[
		The chem is not yours to switch. See `ix.armor.IsChemStealth`.
	]]
	if (ix.armor.IsChemStealth(client)) then
		client:Notify("The Stealth Boy is running. Wait for it to wear off.")
		return
	end

	local enabled = ix.armor.IsStealthed(client)

	if (enabled) then
		ix.armor.SetStealth(client, false)
		return
	end

	--[[
		`requestStealth` is the item's own veto, and six of the suits define
		one - it is where "you need your hands free" lives. Asked before
		cloaking, never after.
	]]
	for _, item in pairs(ix.armor.GetEquipped(character)) do
		if (item.requestStealth and item.requestStealth(item, client, true) == false) then
			return
		end
	end

	ix.armor.SetStealth(client, true)
end)

hook.Add("PlayerDisconnected", "ixArmorStealth", function(client)
	nextToggle[client] = nil
end)

--[[
	Death takes the field with it.

	Nothing else does: `ixStealth` is a networked bool on the player and it
	survives dying, so a cloaked character killed mid-field respawned still
	cloaked, without the suit or the chem that was paying for it. The chem's
	buff is cleared on death by `sv_buff.lua`, which would eventually notice -
	but only on its next expiry pass, and only if the buff had not already been
	the thing that was cleared.
]]
hook.Add("PlayerDeath", "ixArmorStealth", function(client)
	--[[
		The flag is NOT cleared first any more. `SetStealth` reads it to decide
		whether a chem is what was paying for the field, and spends the chem if
		so - clearing it here would hide that from the one function that acts
		on it, and leave a dead character's Stealth Boy still ticking down on
		the HUD of the one they respawn as.
	]]
	if (ix.armor.IsStealthed(client)) then
		ix.armor.SetStealth(client, false)
	end
end)

--[[
	THE FIELD IS DERIVED, NOT LATCHED.

	`ixStealth` is a bool on the player, and everything up to now has been "turn
	it off at the right moment" - when the buff expires, when the armour
	refreshes, on death, on spawn. Every one of those is a moment that can be
	missed, and missing ONE leaves a character cloaked for ever with nothing
	that will ever ask again. That is what "still invisible after the Stealth
	Boy wore off" was, twice.

	So the question is asked continuously instead. Once a second, anybody
	cloaked is checked against `ix.armor.CanStealth` - which reads the buff and
	the equipped armour, the two things that actually pay for a stealth field -
	and if nothing is paying, it goes off. Whatever event was missed, this
	catches it within a second, and it cannot be missed itself because it is
	not driven by an event.

	The `SyncStealth` call in `ix.buff.Refresh` is still there and still does
	the turning ON: a Stealth Boy should cloak you the instant you use it, not
	up to a second later. Only the OFF is made unconditional here.
]]
timer.Create("ixArmorStealthReconcile", 1, 0, function()
	for _, client in player.Iterator() do
		if (not ix.armor.IsStealthed(client)) then continue end

		local character = client:GetCharacter()

		if (not character or not client:Alive()
		or not ix.armor.CanStealth(character)) then
			--[[
				`SetStealth` clears the flag itself, and spends any chem still
				running while it is there. Nothing is left to do here: this
				branch is only reached when `CanStealth` already said nothing
				is paying for the field, so there is usually no buff left to
				spend anyway.
			]]
			ix.armor.SetStealth(client, false)
		end
	end
end)

--[[
	What BOTH sides think, from one command.

	This bug has now survived four fixes, and each one was a theory about which
	half was wrong: the client's material loop, the server's expiry handling,
	the networking. Every theory read correctly on the realm it was about,
	because the failure is a DISAGREEMENT and reading one side cannot show one.

	So this prints both. `fo_stealth` on its own asks the server for its half
	and then asks the client for the other, in one paste.
]]
util.AddNetworkString("ixStealthReport")

concommand.Add("fo_stealth", function(client)
	if (not IsValid(client)) then return end

	local character = client:GetCharacter()
	local worn = {}

	for slot, item in pairs(character and ix.armor.GetEquipped(character) or {}) do
		if (item.hasStealth or item.requestStealth) then
			worn[#worn + 1] = slot .. "/" .. item.uniqueID
		end
	end

	--[[
		Every buff is listed, not just STEALTH. A permanent buff (`endTime` 0)
		of that stat would make `CanStealth` true for ever and is the one shape
		of this that would explain the server never turning the field off - so
		the list has to show endTime, not just the total.
	]]
	local buffs = {}

	for id, buff in pairs(client.ixBuffs or {}) do
		if (buff.stat == "STEALTH") then
			buffs[#buffs + 1] = string.format("%s=%s endTime=%s (now %s)",
				id, tostring(buff.value), tostring(buff.endTime),
				string.format("%.0f", CurTime()))
		end
	end

	client:ChatPrint(string.format(
		"[server] stealthState=%d  IsStealthed=%s  fromChem=%s",
		client:GetNW2Int("ixStealthState", 0),
		tostring(ix.armor.IsStealthed(client)),
		tostring(client.ixStealthFromBuff == true)))

	client:ChatPrint(string.format(
		"[server] STEALTH total=%s  CanStealth=%s  reconcile timer=%s",
		tostring(ix.buff and ix.buff.Get(client, "STEALTH")),
		tostring(character and ix.armor.CanStealth(character)),
		tostring(timer.Exists("ixArmorStealthReconcile"))))

	client:ChatPrint("[server] STEALTH buffs: "
		.. (#buffs > 0 and table.concat(buffs, " | ") or "none"))

	client:ChatPrint("[server] stealth armour worn: "
		.. (#worn > 0 and table.concat(worn, ", ") or "none"))

	net.Start("ixStealthReport")
	net.Send(client)
end)

--[[
	Force it off, everywhere, whatever anything believes.

	An escape hatch rather than a fix: somebody stuck invisible should be able
	to carry on playing while the cause is still being found.
]]
concommand.Add("fo_unstealth", function(client)
	if (not IsValid(client)) then return end

	client.ixStealthFromBuff = nil

	if (ix.buff) then
		ix.buff.Clear(client, "STEALTH")
	end

	ix.armor.SetStealth(client, false)

	client:ChatPrint("Stealth forced off, and any STEALTH buff cleared. "
		.. "Run fo_unstealth_client too if you are still invisible.")
end)

--[[
	Every powered suit off somebody, at once. A permanent kill takes the
	training with the life, and a character standing in a suit they no longer
	know how to run is a character who has to be taken out of it. Salvaged
	frames stay on; they never needed the training.
]]
function ix.armor.StripPowerArmor(client)
	local character = IsValid(client) and client:GetCharacter()

	if (not character) then return 0 end

	local count = 0

	for _, item in pairs(ix.armor.GetEquipped(character)) do
		if (item.isPA and not item.isSalvagedPA) then
			ix.armor.Unequip(client, item)

			count = count + 1
		end
	end

	return count
end
