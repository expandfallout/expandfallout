--[[
	Picking people up with the physics gun, and leaving them there.

	Helix already lets staff pick a player up - `GM:PhysgunPickup` sets
	`MOVETYPE_NONE` while they are held and puts it back on the drop - and that
	half is fine. Two things were missing:

	    WHO MAY DO IT was `client:IsSuperAdmin() or client:IsAdmin()`, which is
	    Garry's Mod's own ladder rather than this schema's. A moderator could
	    not do it however their rank was set up, and anybody the server had
	    made a GMod admin could do it to anybody below superadmin regardless of
	    what their rank in the rank editor says.

	    THE FREEZE did not exist. Right-clicking a held player froze their
	    PHYSICS OBJECT, which a walking player does not use, and then the drop
	    handed them `MOVETYPE_WALK` back and they fell out of the air.

	THE FREEZE IS `FL_FROZEN` PLUS `MOVETYPE_NONE`, and it is caught on the
	DROP rather than on `OnPhysgunFreeze`.

	The first version hooked `OnPhysgunFreeze`, which is the obvious hook and
	the wrong one: the engine physgun only raises it for something it considers
	freezable, and a player - whose movement is not simulated by the physics
	object the beam is holding - is not. It never fired once, so right-clicking
	a held player simply dropped them and they fell, which is exactly what was
	reported.

	`PhysgunDrop` always fires. Asking `client:KeyDown(IN_ATTACK2)` there is
	asking "did they let go, or did they right-click", which is the actual
	question - and `KeyPress` catches the same gesture a frame earlier for the
	case where the drop happens first.

	`FL_FROZEN` is the same flag `!freeze` sets, so `!unfreeze` releases
	somebody frozen this way. `MOVETYPE_NONE` is what actually holds them in
	the air.

	AND PICKING SOMEBODY UP AGAIN RELEASES THEM. The beam has them, so the
	freeze has nothing left to do - see `PhysgunPickup` below.

	AND THE DROP PUTS `MOVETYPE_WALK` BACK, WHENEVER IT HAPPENS. That was the
	second bug and it is why the freeze looked like it still did nothing.

	Right-clicking freezes but does NOT make the physgun let go - the engine
	only drops what it managed to freeze, and a player is not something it
	considers freezable. So the beam keeps them, the admin carries on holding
	left-click, and the drop arrives SECONDS later - long after the one-shot
	timer that set `MOVETYPE_NONE` has fired. `GM:PhysgunDrop` then hands the
	player `MOVETYPE_WALK` and they fall out of the air, exactly as if nothing
	had been frozen at all.

	So the movetype is re-applied from the DROP as well, a frame after it, for
	anybody still in `held`. Setting it once at freeze time was only ever right
	if the drop happened first.

	THEY ARE RELEASED IF THE PERSON HOLDING THEM LEAVES. Somebody frozen in the
	air by an admin who then disconnects is stuck there for the rest of the
	map, and the only person who could have known is gone.
]]

ix.physgun = ix.physgun or {}

ix.config.Add("physgunPlayers", true,
	"Whether staff may pick players up with the physics gun.", nil,
	{category = "Staff"})

if (ix.admin and ix.admin.RegisterPermission) then
	ix.admin.RegisterPermission("player.physgun",
		"Pick players up and freeze them with the physics gun", "People")
end

if (not SERVER) then return end

--[[
	`[victim SteamID] = the SteamID of whoever froze them`.

	SteamIDs rather than the players themselves, because the point of the table
	is to survive one of them being invalid - a frozen player who disconnects
	and reconnects is a different entity with the same id, and the entry should
	not keep a dead reference alive.
]]
local held = {}

--------------------------------------------------------------------------------
-- Asking
--------------------------------------------------------------------------------

--[[
	Both halves of the question, once.

	`Outranks` is strictly greater, so equals cannot pick each other up - the
	same rule every admin verb uses, and the reason two moderators cannot spend
	an evening throwing one another off a roof.
]]
local function Allowed(client, target)
	if (not ix.config.Get("physgunPlayers", true)) then return false end
	if (not ix.admin.Can(client, "player.physgun")) then return false end

	return ix.admin.Outranks(client, target)
end

--------------------------------------------------------------------------------
-- Holding
--------------------------------------------------------------------------------

--[[
	RETURNING HERE STOPS `GM:PhysgunPickup`, which is where Helix sets
	`MOVETYPE_NONE` - see gotcha 27. So that line is copied rather than left to
	the framework: a player picked up without it walks around inside the beam.

	Only players are answered. Everything else falls through untouched, to
	`sv_sandbox.lua`'s `spawn.physgun` check and then to Helix's own.
]]
hook.Add("PhysgunPickup", "ixPhysgunPlayer", function(client, entity)
	if (not IsValid(entity) or not entity:IsPlayer()) then return end

	if (not Allowed(client, entity)) then return false end

	--[[
		PICKING SOMEBODY UP LETS THEM GO, and the beam takes over.

		They stay exactly where they were until you move them - the physics gun
		is holding them - so this reads as "grab a frozen person and reposition
		them", not as dropping them. Right-click freezes them again wherever
		they now are.

		The beam has them now, so the freeze has nothing left to do - and
		leaving it on made the physics gun the one tool that could not undo its
		own work: you could lift a frozen player, move them, drop them, and
		they would snap back to frozen because they were never released. Worse,
		`FreezePlayer` refuses somebody already in `held`, so right-clicking
		again did nothing at all.

		Now a pickup is a release. Right-click freezes them where they are,
		picking them up again frees them, and `r` on the physics gun still
		releases everybody at once from a distance.
	]]
	ix.physgun.Release(entity)

	entity:SetMoveType(MOVETYPE_NONE)

	--- Who the beam has, so the right-click below knows what it is freezing.
	client.ixPhysgunHeld = entity

	return true
end)

--------------------------------------------------------------------------------
-- Freezing
--------------------------------------------------------------------------------

--[[
	Leave them where they are.

	Idempotent: the two hooks below both call it for one right-click, and
	freezing somebody who is already frozen is not an event.
]]
function ix.physgun.FreezePlayer(client, target)
	if (not IsValid(target) or not target:IsPlayer()) then return end
	if (not Allowed(client, target)) then return end
	if (held[target:SteamID()]) then return end

	target:Freeze(true)

	held[target:SteamID()] = client:SteamID()

	--[[
		A FRAME LATER, because `GM:PhysgunDrop` has not run yet and it sets
		`MOVETYPE_WALK`. Setting the movetype now would be setting it before
		the thing that overwrites it.
	]]
	timer.Simple(0, function()
		if (not IsValid(target)) then return end
		if (not held[target:SteamID()]) then return end

		target:SetMoveType(MOVETYPE_NONE)
	end)

	target:Notify(client:Name() .. " froze you.")

	ix.log.Add(client, "physgunFreeze", target:Name(), target:SteamID())
end

--[[
	Right-click while the beam has somebody.

	`KeyPress` is the moment the button went down. It is not enough on its own -
	the physgun may have let go before this runs, and then `ixPhysgunHeld` is
	already nil - which is why the drop below asks the same question again.
]]
hook.Add("KeyPress", "ixPhysgunPlayer", function(client, key)
	if (key ~= IN_ATTACK2) then return end

	local target = client.ixPhysgunHeld

	if (not IsValid(target)) then return end

	ix.physgun.FreezePlayer(client, target)
end)

--[[
	And on the way out of the beam, whichever button caused it.

	`GM:PhysgunDrop` runs after this and puts `MOVETYPE_WALK` back, which is
	correct for somebody who was simply let go and is undone a frame later for
	somebody who was frozen.

	Nothing is returned, so that method still runs.
]]
hook.Add("PhysgunDrop", "ixPhysgunPlayer", function(client, entity)
	if (client.ixPhysgunHeld == entity) then
		client.ixPhysgunHeld = nil
	end

	if (not IsValid(entity) or not entity:IsPlayer()) then return end

	if (client:KeyDown(IN_ATTACK2)) then
		ix.physgun.FreezePlayer(client, entity)
	end

	--[[
		AND THE MOVETYPE BACK OFF, a frame after `GM:PhysgunDrop` has put it
		on. This is the line the freeze was missing: the drop can arrive long
		after the right-click that froze them, so re-applying it once at freeze
		time was only correct if the drop happened first - and it usually does
		not, because the beam keeps hold of a player it could not freeze.
	]]
	timer.Simple(0, function()
		if (not IsValid(entity)) then return end
		if (not held[entity:SteamID()]) then return end

		entity:SetMoveType(MOVETYPE_NONE)
	end)
end)

--[[
	AND IT KEEPS ITSELF ON.

	The freeze is two flags on a player - `FL_FROZEN` and `MOVETYPE_NONE` - and
	a great many things in this game set a movetype: the physics gun itself
	while it carries somebody, `GM:PhysgunDrop` on the way out, a respawn, an
	addon nobody remembered. Each of those has been chased individually and
	each time something else turned out to do it too.

	So it is asserted rather than set. Four times a second, everybody in `held`
	is put back the way they are meant to be, and the loop is over a table that
	is empty on almost every server almost all of the time.
]]
timer.Create("ixPhysgunHold", 0.25, 0, function()
	for steamID in pairs(held) do
		local target = player.GetBySteamID(steamID)

		if (IsValid(target)) then
			if (target:GetMoveType() ~= MOVETYPE_NONE) then
				target:SetMoveType(MOVETYPE_NONE)
			end

			if (not target:IsFlagSet(FL_FROZEN)) then
				target:Freeze(true)
			end
		end
	end
end)

--------------------------------------------------------------------------------
-- Letting go
--------------------------------------------------------------------------------

--- Release one, and forget it. Safe to call for somebody who is not frozen.
function ix.physgun.Release(target)
	if (not IsValid(target)) then return end

	held[target:SteamID()] = nil

	target:Freeze(false)

	--[[
		AND THE MOVETYPE BACK. A player left on `MOVETYPE_NONE` is unfrozen and
		still cannot move, which is worse than being frozen because nothing on
		screen says so - `!unfreeze` goes through here for that reason.
	]]
	if (target:GetMoveType() == MOVETYPE_NONE) then
		target:SetMoveType(MOVETYPE_WALK)
	end
end

--- Everybody one person froze.
function ix.physgun.ReleaseAll(client)
	local key = client:SteamID()
	local count = 0

	for steamID, by in pairs(held) do
		if (by == key) then
			local target = player.GetBySteamID(steamID)

			held[steamID] = nil

			if (IsValid(target)) then
				ix.physgun.Release(target)
				target:Notify(client:Name() .. " let you go.")
			end
			count = count + 1
		end
	end

	return count
end

--[[
	RELOAD ON THE PHYSGUN IS ALREADY "UNFREEZE EVERYTHING I FROZE" - sandbox's
	`GM:OnPhysgunReload` calls `Player:PhysgunUnfreeze` and tells you how many
	props it released. People frozen the same way belong in the same gesture.

	Nothing is returned, so that method still runs and the props are released
	too.
]]
hook.Add("OnPhysgunReload", "ixPhysgunPlayer", function(weapon, client)
	local count = ix.physgun.ReleaseAll(client)

	if (count > 0) then
		client:Notify(string.format("Unfroze %d player(s).", count))
	end
end)

--[[
	AND WHOEVER LEFT TAKES THEIR FREEZES WITH THEM.

	Both directions: a frozen player who disconnects leaves an entry pointing
	at nobody, and an admin who disconnects leaves people hanging in the air
	with no way to find out who did it.
]]
hook.Add("PlayerDisconnected", "ixPhysgunPlayer", function(client)
	held[client:SteamID()] = nil

	ix.physgun.ReleaseAll(client)
end)

--[[
	A NEW BODY IS NOT A FROZEN ONE. `FL_FROZEN` is on the player rather than on
	the character, so somebody killed while frozen would respawn unable to
	move - which reads as the server being broken rather than as a punishment
	still running.
]]
hook.Add("PlayerSpawn", "ixPhysgunPlayer", function(client)
	if (not held[client:SteamID()]) then return end

	ix.physgun.Release(client)
end)

--[[
	`fo_physgun` - is any of this switched on, and who is frozen.

	Written because the freeze failed twice for two different reasons and both
	looked identical from in front of the screen: nothing happened. A permission
	nobody granted and a hook that never fires produce the same silence.
]]
concommand.Add("fo_physgun", function(client)
	local function Say(text)
		if (IsValid(client)) then client:ChatPrint(text) else print(text) end
	end

	Say(string.format("physgunPlayers: %s",
		tostring(ix.config.Get("physgunPlayers", true))))

	if (IsValid(client)) then
		Say(string.format("you have player.physgun: %s",
			tostring(ix.admin.Can(client, "player.physgun"))))
		Say(string.format("you have admin.silent: %s",
			tostring(ix.admin.Can(client, "admin.silent"))))
		Say(string.format("holding: %s",
			IsValid(client.ixPhysgunHeld)
				and client.ixPhysgunHeld:Name() or "nobody"))
	end

	local count = 0

	for steamID, by in pairs(held) do
		local target = player.GetBySteamID(steamID)

		Say(string.format("  frozen: %s by %s (movetype %s)",
			IsValid(target) and target:Name() or steamID, by,
			IsValid(target) and target:GetMoveType() or "?"))

		count = count + 1
	end

	Say(string.format("%d frozen.", count))
end)

ix.log.AddType("physgunFreeze", function(client, name, steamID)
	return string.format("%s froze %s (%s) with the physics gun.",
		client:Name(), name, steamID)
end, FLAG_WARNING)
