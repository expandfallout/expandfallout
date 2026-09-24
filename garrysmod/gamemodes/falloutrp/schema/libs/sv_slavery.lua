--[[
	Putting a collar on somebody, and taking it off them one way or another.

	The rule that makes the whole thing work is Phoenix's and is worth stating
	plainly: HANDING SOMEBODY AN ARMED COLLAR IS ENSLAVING THEM. There is no
	"put collar on" verb - you arm it, you give it to them, and it locks itself
	around their neck on the way in. That is why the interesting code here is a
	transfer hook rather than a command.
]]

if (not SERVER) then return end

util.AddNetworkString("ixSlaveBoyOpen")
util.AddNetworkString("ixSlaveBoyAction")
util.AddNetworkString("ixSlaveLocate")

--------------------------------------------------------------------------------
-- Wearing one
--------------------------------------------------------------------------------

--[[
	The collar item somebody is wearing, or nil.

	Read from the inventory every time rather than cached on the player: a
	cached item reference survives a character swap, and this question is only
	ever asked a handful of times a second.
]]
function ix.slavery.GetCollar(target)
	if (not IsValid(target)) then return end

	local character = target:GetCharacter()
	local inventory = character and character:GetInventory()

	if (not inventory) then return end

	for item in ix.inventory.Each(inventory) do
		if (item.uniqueID == ix.slavery.item and item:GetData("equip")) then
			return item
		end
	end
end

--[[
	Lock it on.

	`ix.armor.Equip` is asked first and is allowed to refuse - it knows about
	races, slots and Power Armour. If it refuses because the neck is taken then
	so be it; if it refuses for any other reason the collar goes on ANYWAY,
	because "the slave collar could not be fitted" is not a sentence this
	system is allowed to say. That is the one place armour rules are overruled
	in this schema, and it is deliberate.
]]
function ix.slavery.Wear(target, item, ownerID)
	if (not IsValid(target) or not item) then return false end
	if (ix.slavery.Is(target)) then return false end

	if (not item:GetData("equip")) then
		local ok = ix.armor.Equip(target, item)

		if (not ok) then
			item:SetData("equip", true)
			ix.armor.Refresh(target)
		end
	end

	local duration = item:GetData("time")
		or ix.config.Get("slaveCollarMaxTime", 1200)

	--[[
		A DEADLINE, not a countdown. `os.time` because a collar is meant to
		outlive a map change and `CurTime` restarts at zero on every one of
		them - gotcha 11, and the reason the PK timer is written the same way.
	]]
	local expireAt = item:GetData("expireAt") or (os.time() + duration)

	item:SetData("expireAt", expireAt)
	item:SetData("arm", false)
	item:SetData("owner", ownerID)

	target:SetNetVar("enslaved", true)
	target:SetNetVar("collarUntil", expireAt)
	target:SetNetVar("collarOwner", ownerID or 0)
	target:SetNetVar("collarFuse", 0)

	target:EmitSound("weapons/mine/wpn_mine_arm.wav", 60)

	hook.Run("PlayerEnslaved", target, ownerID)

	return true
end

--[[
	Take it off. `bDestroy` is the difference between the count running out -
	the collar is spent - and somebody being freed by hand.
]]
function ix.slavery.Free(target, bDestroy)
	if (not IsValid(target)) then return false end

	local item = ix.slavery.GetCollar(target)

	target:SetNetVar("enslaved", false)
	target:SetNetVar("collarUntil", 0)
	target:SetNetVar("collarOwner", 0)
	target:SetNetVar("collarFuse", 0)

	if (item) then
		if (item:GetData("equip")) then
			ix.armor.Unequip(target, item)
		end

		item:SetData("expireAt", nil)
		item:SetData("time", nil)
		item:SetData("owner", nil)

		if (bDestroy) then item:Remove() end
	end

	hook.Run("PlayerFreed", target)

	return true
end

--------------------------------------------------------------------------------
-- Setting one off
--------------------------------------------------------------------------------

--[[
	Start the fuse.

	The wearer is told, loudly, because the ten seconds are the point: a
	triggered collar is a threat first and a weapon second, and somebody who
	does not know it is counting cannot do as they are told.
]]
function ix.slavery.Trigger(target, client)
	if (not ix.slavery.Is(target)) then return false end
	if (ix.slavery.Fuse(target)) then return false end

	local fuse = ix.config.Get("slaveCollarExplodeTime", 10)

	target:SetNetVar("collarFuse", os.time() + fuse)

	target:EmitSound("weapons/mine/wpn_mine_arm.wav", 75)
	target:Notify("[ ! ] YOUR COLLAR IS COUNTING DOWN.")
	target:EmitSound("phoenix/ui/nv/ui_popup_messagewindow.mp3", 70)

	if (IsValid(client)) then
		ix.log.Add(client, "collarTrigger", target:Name())
	end

	return true
end

--- What the fuse reaches.
function ix.slavery.Detonate(target)
	if (not IsValid(target)) then return false end

	local position = target:GetPos() + Vector(0, 0, 60)
	local damage = ix.config.Get("slaveCollarDamage", 50)

	--- Read BEFORE the collar comes off, because that is what clears it.
	local ownerID = ix.slavery.OwnerID(target)

	ix.slavery.Free(target, true)

	local effect = EffectData()
	effect:SetOrigin(position)
	util.Effect("Explosion", effect)

	target:EmitSound("weapons/explosion/fx_explosion_grenade_frag_high_0"
		.. math.random(3) .. ".mp3", 110, 200)

	--[[
		DAMAGE TO THE WEARER ONLY.

		A real radius here would make a collar a grenade you can walk into a
		crowd, and the fifty points that Phoenix set it to are plainly meant
		for one neck. Anybody stood next to it gets the noise and the flash.

		ATTRIBUTED TO WHOEVER OWNS THE COLLAR when they are online, so the
		death reads as theirs in the logs and to every system that asks who
		killed somebody. Failing that it is the wearer, which is the honest
		answer for a collar whose owner has logged off.
	]]
	local owner = ownerID and ix.char.loaded[ownerID]
	local attacker = owner and owner:GetPlayer()

	if (not IsValid(attacker)) then attacker = target end

	local info = DamageInfo()
	info:SetDamage(damage)
	info:SetDamageType(DMG_BLAST)
	info:SetAttacker(attacker)
	info:SetInflictor(attacker)

	target:TakeDamageInfo(info)

	--[[
		AND THEN IT KILLS THEM ANYWAY.

		The configured damage is what the explosion IS - it feeds the damage
		hooks, the armour, the hitgroup code and the kill feed - but a collar
		going off is not a wound, it is an execution, and fifty points against
		a suit of Power Armour is a scratch. Anybody still standing after the
		damage is killed outright.
	]]
	if (target:Alive()) then target:Kill() end

	for _, other in ipairs(ents.FindInSphere(position, 600)) do
		if (other:IsPlayer() and other:Alive() and other ~= target) then
			other:ScreenFade(SCREENFADE.IN, Color(255, 225, 225, 60), 0.4, 0)
		end
	end

	return true
end

--------------------------------------------------------------------------------
-- Getting one off somebody
--------------------------------------------------------------------------------

--[[
	Defusing, which is an Intelligence check with teeth.

	Phoenix keep the required Intelligence in a config (`15` of a possible 30)
	and nothing in the scrape says what failing does. Failing STARTS THE FUSE
	here, which is the only reading that makes the number matter - if a failed
	attempt cost nothing, everybody would try it every time and the config
	would be a delay rather than a decision.
]]
function ix.slavery.BeginDiffuse(client, target)
	if (client.ixDiffusing) then return false end

	local time = ix.config.Get("slaveCollarDisarmTime", 10)

	client.ixDiffusing = true

	client:SetAction("Defusing", time)
	target:SetAction("Somebody is at your collar", time)

	ix.chat.Send(client, "me", "starts carefully working at the collar . . .")

	client:DoStaredAction(target, function()
		client.ixDiffusing = nil

		if (not IsValid(client) or not IsValid(target)) then return end
		if (not ix.slavery.Is(target)) then return end

		client:SetAction()
		target:SetAction()

		local needed = ix.config.Get("slaveCollarDisarmIntelligence", 15)
		local intelligence = ix.special.Get(client:GetCharacter(),
			"intelligence")

		if (intelligence >= needed) then
			ix.chat.Send(client, "me", "eases the collar open and lifts it "
				.. "clear.")

			target:Notify("Your collar has been removed.")
			client:Notify("The collar comes away in your hands.")

			ix.slavery.Free(target, true)
			ix.log.Add(client, "collarDiffuse", target:Name(), "defused")

			return
		end

		ix.chat.Send(client, "me", "fumbles the collar, and it starts to "
			.. "beep.")

		client:Notify("You are not clever enough for this. It is counting.")

		ix.slavery.Trigger(target, client)
		ix.log.Add(client, "collarDiffuse", target:Name(), "failed")
	end, time, function()
		client.ixDiffusing = nil

		if (IsValid(client)) then client:SetAction() end
		if (IsValid(target)) then target:SetAction() end
	end)

	return true
end

--------------------------------------------------------------------------------
-- The clock
--------------------------------------------------------------------------------

--[[
	ONE TIMER FOR EVERY COLLAR ON THE SERVER, at one second.

	Phoenix create a timer per collar with `time` repetitions and write the
	remaining seconds back to the item on each one - a database write and a
	network message per collar per second. Both questions here are a
	subtraction against a deadline, so the work does not grow with how long
	anybody has left.
]]
timer.Create("ixSlaveryTick", 1, 0, function()
	local now = os.time()

	for _, client in ipairs(player.GetAll()) do
		if (not ix.slavery.Is(client)) then continue end

		local fuse = client:GetNetVar("collarFuse", 0)

		if (fuse > 0) then
			--- The beep, every second, so the countdown is audible.
			client:EmitSound("phoenix/ui/nv/menu_beep.mp3", 70, 140)

			if (now >= fuse) then ix.slavery.Detonate(client) end

			continue
		end

		if (now >= client:GetNetVar("collarUntil", 0)) then
			--[[
				TOLD THREE WAYS, because the one thing a slave is counting is
				this moment and a notification that scrolls past while they are
				looking at something else is the same as no notification. The
				chat line is the one that is still there afterwards.
			]]
			client:Notify("[ ! ] Your collar has run out.")
			client:EmitSound("weapons/mine/wpn_mine_disarm.wav", 70)
			client:EmitSound("phoenix/ui/nv/ui_popup_messagewindow.mp3", 70)

			client:ChatPrint("[Collar] The timer has run out. The collar "
				.. "clicks open and falls away - you are no longer enslaved.")

			ix.slavery.Free(client, true)
		end
	end
end)

--------------------------------------------------------------------------------
-- Giving somebody a collar
--------------------------------------------------------------------------------

--[[
	An armed collar cannot be given to somebody already wearing one.

	Phoenix's rule, and it is not politeness: two collars on one neck means two
	deadlines, two owners and a `GetCollar` that answers whichever it finds
	first.
]]
hook.Add("CanTransferItem", "ixSlavery", function(item, curInv, inventory)
	if (item.uniqueID ~= ix.slavery.item) then return end
	if (not item:GetData("arm", false)) then return end

	local target = inventory and inventory.GetOwner and inventory:GetOwner()

	if (IsValid(target) and ix.slavery.Is(target)) then
		return false
	end
end)

--[[
	THE ACT OF ENSLAVING SOMEBODY.

	An armed collar arriving in a character's inventory from somebody else's
	locks itself on. Everything else - dropping one, picking one up, tidying it
	between your own bags - leaves it alone.
]]
hook.Add("OnItemTransferred", "ixSlavery", function(item, curInv, inventory)
	if (item.uniqueID ~= ix.slavery.item) then return end
	if (not item:GetData("arm", false)) then return end

	local target = inventory and inventory.GetOwner and inventory:GetOwner()

	if (not IsValid(target) or ix.slavery.Is(target)) then return end

	local character = target:GetCharacter()

	if (not character) then return end

	--[[
		Who owns them. The collar's own `owner` data if it has been armed by
		somebody, and failing that whoever the collar came from - an armed
		collar always has one, but a collar that has changed hands twice may
		not have been re-armed.
	]]
	local ownerID = item:GetData("owner")

	if (not ownerID and curInv and curInv.owner) then ownerID = curInv.owner end
	if (ownerID == character:GetID()) then return end

	ix.slavery.Wear(target, item, ownerID)

	target:Notify("[ ! ] You have been enslaved.")
	target:EmitSound("phoenix/ui/nv/ui_karma_down.mp3", 70)

	target:ChatPrint("[NOTICE] As a slave you are under the orders of "
		.. "whoever holds your collar. Disobeying them is a rules matter, "
		.. "not a fight you can pick.")

	local owner = ownerID and ix.char.loaded[ownerID]
	local ownerPlayer = owner and owner:GetPlayer()

	if (IsValid(ownerPlayer)) then
		ownerPlayer:Notify("[ ! ] Successfully enslaved.")
		ownerPlayer:EmitSound("phoenix/ui/nv/ui_karma_down.mp3", 70)

		ix.log.Add(ownerPlayer, "collarEnslave", target:Name())
	end
end)

--------------------------------------------------------------------------------
-- Coming back to a collar you were already wearing
--------------------------------------------------------------------------------

--[[
	The netvars are rebuilt from the item, which is where the truth is.

	Netvars do not survive a disconnect and item data does, so a collar is
	still on and still counting when somebody comes back - including through
	the time they were not here, which is the point of a deadline.
]]
hook.Add("PlayerLoadedCharacter", "ixSlavery", function(client)
	timer.Simple(1, function()
		if (not IsValid(client)) then return end

		local item = ix.slavery.GetCollar(client)

		if (not item) then return end

		local expireAt = item:GetData("expireAt")

		if (not expireAt) then return end

		if (os.time() >= expireAt) then
			ix.slavery.Free(client, true)

			return
		end

		client:SetNetVar("enslaved", true)
		client:SetNetVar("collarUntil", expireAt)
		client:SetNetVar("collarOwner", item:GetData("owner") or 0)
		client:SetNetVar("collarFuse", 0)
	end)
end)

--------------------------------------------------------------------------------
-- The SlaveBoy 2000
--------------------------------------------------------------------------------

--[[
	Everybody whose collar you own, and how long they have left.

	COLLAR OWNERSHIP IS THE ONLY QUESTION ASKED. Not who enslaved them, not who
	they follow - the person holding the transmitter is whoever armed the thing
	around their neck, and that is a fact on the collar rather than a
	relationship anybody has to maintain.
]]
function ix.slavery.GetSlaves(client)
	local character = client:GetCharacter()

	if (not character) then return {} end

	local id = character:GetID()
	local slaves = {}

	for _, other in ipairs(player.GetAll()) do
		if (other == client or not ix.slavery.Is(other)) then continue end
		if (ix.slavery.OwnerID(other) ~= id) then continue end

		slaves[#slaves + 1] = other
	end

	return slaves
end

--- Is there one of these in their pockets. The item is never used up.
function ix.slavery.HasSlaveBoy(client)
	local character = client:GetCharacter()
	local inventory = character and character:GetInventory()

	if (not inventory) then return false end

	for item in ix.inventory.Each(inventory) do
		if (item.isSlaveBoy) then return true end
	end

	return false
end

--[[
	Send the list. The client opens the screen when it arrives, so this is both
	"open it" and "refresh it" - there is no second message for the second one.

	The DEADLINE is sent, not the time left, for the reason the netvar is a
	deadline: a number that is true when it is sent and false a second later
	needs re-sending, and one that says WHEN needs nothing.
]]
function ix.slavery.SendList(client)
	if (not IsValid(client)) then return false end

	if (not ix.slavery.HasSlaveBoy(client)) then
		client:Notify("You do not have a SlaveBoy.")

		return false
	end

	local slaves = ix.slavery.GetSlaves(client)

	net.Start("ixSlaveBoyOpen")
		net.WriteUInt(#slaves, 8)

		for _, other in ipairs(slaves) do
			local character = other:GetCharacter()

			net.WriteUInt(character:GetID(), 32)
			net.WriteString(character:GetName())
			net.WriteUInt(other:GetNetVar("collarUntil", 0), 32)
			net.WriteUInt(other:GetNetVar("collarFuse", 0), 32)
		end
	net.Send(client)

	return true
end

--[[
	Trigger or disarm one of yours, from anywhere on the map.

	EVERY CHECK IS DONE AGAIN HERE. The screen only shows people you own, and
	the screen is on the client - so the character id in this message is
	whatever somebody wanted to send, and ownership, the item and the collar
	are all confirmed before anything happens.
]]
net.Receive("ixSlaveBoyAction", function(length, client)
	if ((client.ixSlaveBoyNext or 0) > CurTime()) then return end

	client.ixSlaveBoyNext = CurTime() + 0.25

	local action = net.ReadString()
	local id = net.ReadUInt(32)

	if (not IsValid(client) or not client:GetCharacter()) then return end
	if (not ix.slavery.HasSlaveBoy(client)) then return end

	local character = ix.char.loaded[id]
	local target = character and character:GetPlayer()

	if (not IsValid(target) or not ix.slavery.Is(target)) then return end

	if (ix.slavery.OwnerID(target) ~= client:GetCharacter():GetID()) then
		client:Notify("That is not your collar.")

		return
	end

	if (action == "locate") then
		--[[
			THE TRACKER. A mark on the owner's screen for `slaveLocateTime`
			seconds, once per `slaveLocateCooldown`. Nothing changes on the
			list, so it is not re-sent.
		]]
		if ((client.ixSlaveLocateNext or 0) > CurTime()) then
			client:Notify(string.format("The tracker is recharging: %ds.",
				math.ceil(client.ixSlaveLocateNext - CurTime())))

			return
		end

		client.ixSlaveLocateNext = CurTime()
			+ ix.config.Get("slaveLocateCooldown", 30)

		net.Start("ixSlaveLocate")
			net.WriteEntity(target)
			net.WriteUInt(ix.config.Get("slaveLocateTime", 30), 16)
		net.Send(client)

		client:Notify("Tracking " .. target:Name() .. ".")

		return
	elseif (action == "trigger") then
		if (ix.slavery.Fuse(target)) then
			client:Notify("It is already counting down.")

			return
		end

		ix.slavery.Trigger(target, client)
		client:Notify("The collar is counting down.")
	elseif (action == "disarm") then
		--[[
			DISARMING FREES THEM. There is no middle state where a collar is
			on somebody but off - the collar comes away and is destroyed, which
			is the same thing that happens when its timer runs out.
		]]
		target:Notify("[ ! ] Your collar has been released.")
		target:EmitSound("weapons/mine/wpn_mine_disarm.wav", 70)
		target:ChatPrint("[Collar] Your owner has released you.")

		ix.slavery.Free(target, true)

		client:Notify("Released.")

		ix.log.Add(client, "collarRelease", target:Name())
	else
		return
	end

	ix.slavery.SendList(client)
end)

ix.log.AddType("collarRelease", function(client, name)
	return string.format("%s released %s from their collar.", client:Name(),
		name)
end)

ix.log.AddType("collarEnslave", function(client, name)
	return string.format("%s enslaved %s with a collar.", client:Name(), name)
end, FLAG_DANGER)

ix.log.AddType("collarTrigger", function(client, name)
	return string.format("%s triggered %s's collar.", client:Name(), name)
end, FLAG_DANGER)

ix.log.AddType("collarDiffuse", function(client, name, result)
	return string.format("%s tried to defuse %s's collar: %s.", client:Name(),
		name, result)
end, FLAG_WARNING)

--------------------------------------------------------------------------------
-- The leash
--------------------------------------------------------------------------------

--[[
	A collar within range of its owner is quiet. Past `slaveProximity` units
	it counts down on its own, exactly as if the owner had triggered it - and
	the owner is told, because a slave who ran is something the owner wants to
	know. A warning goes out at eighty per cent of the range, once, so the
	first sign is not the fuse.

	Only while the owner is ONLINE and playing that character. A leash to
	somebody who is not here is a collar nobody can answer for, and a slave
	whose owner logs off should not die of it.
]]
timer.Create("ixSlaveProximity", 2, 0, function()
	local limit = ix.config.Get("slaveProximity", 4000)

	if (limit <= 0) then return end

	local limitSq = limit * limit

	for _, target in player.Iterator() do
		if (not ix.slavery.Is(target) or ix.slavery.Fuse(target)) then
			continue
		end

		local ownerID = ix.slavery.OwnerID(target)
		local character = ownerID and ix.char.loaded[ownerID]
		local owner = character and character:GetPlayer()

		if (not IsValid(owner) or owner == target) then continue end

		local distanceSq = owner:GetPos():DistToSqr(target:GetPos())

		if (distanceSq > limitSq) then
			ix.slavery.Trigger(target, nil)

			target:Notify("[ ! ] YOU ARE OUT OF RANGE OF YOUR OWNER.")
			owner:Notify(target:Name()
				.. " went out of range. Their collar is counting down.")
			owner:EmitSound("phoenix/ui/nv/ui_popup_messagewindow.mp3", 70)

			ix.log.Add(owner, "collarProximity", target:Name())

			target.ixCollarWarned = nil
		elseif (distanceSq > limitSq * 0.64 and not target.ixCollarWarned) then
			target.ixCollarWarned = true

			target:Notify("[ ! ] Your collar is warning you: you are straying "
				.. "too far from your owner.")
			target:EmitSound("weapons/mine/wpn_mine_tick.wav", 70)
		elseif (distanceSq <= limitSq * 0.5) then
			target.ixCollarWarned = nil
		end
	end
end)

ix.log.AddType("collarProximity", function(client, name)
	return string.format("%s's collar triggered: they went out of range of "
		.. "%s.", name, client:Name())
end, FLAG_DANGER)
