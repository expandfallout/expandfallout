--[[
	Telling somebody they hit something.

	Phoenix rely on the weapon base for this: `ls_base.lua` sends
	`longsword_hitmarker` when a bullet lands on a player, an NPC or a nextbot.
	That covers the guns and nothing else - a pickaxe, a knife, a grenade and
	the melee weapons all land silently.

	So this is the same message from the other end: `EntityTakeDamage`, which
	every source of damage passes through. The client listens for both, so a
	gun marks once whichever arrives first.

	IT MAKES NO SOUND, here or on the client. That was asked for explicitly and
	it is also Phoenix's behaviour - theirs is four ticks and nothing else.
]]

if (not SERVER) then return end

util.AddNetworkString("ixHitMarker")
util.AddNetworkString("ixCrosshairOpen")

--[[
	`PostEntityTakeDamage` rather than `EntityTakeDamage`.

	The second one runs BEFORE the damage is applied and is where the rest of
	the schema scales it; a marker sent from there is a promise rather than a
	fact, and would flash for a hit that armour or a hook then cancelled
	entirely. This one runs after, with `bTook` saying whether anything
	actually landed.
]]
hook.Add("PostEntityTakeDamage", "ixHitMarker", function(target, damage, took)
	if (not took) then return end
	if (not IsValid(target)) then return end

	--[[
		Only things that can be hurt. A marker for hitting a door or a crate is
		a marker that means nothing, and the point of it is to tell you that a
		swing you were not sure about connected with a PERSON.
	]]
	if (not target:IsPlayer() and not target:IsNPC()
	and not target:IsNextBot()) then
		return
	end

	local client = damage:GetAttacker()

	if (not IsValid(client) or not client:IsPlayer()) then return end
	if (client == target) then return end

	net.Start("ixHitMarker")
	net.Send(client)
end)
