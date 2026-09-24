--[[
	Jumping costs stamina, and running out means running out.

	Helix's stamina plugin charges for sprinting and nothing else, so jumping
	is free and bunny-hopping across the map is faster than running and costs
	nothing. This makes a jump cost stamina, and adds the rule that actually
	stops the spam:

	    ONCE THE BAR IS EMPTY, YOU CANNOT JUMP OR SPRINT UNTIL IT IS HALF
	    FULL AGAIN.

	Without that second half a player simply waits for one jump's worth to
	regenerate and carries on hopping, slower but forever. With it, running out
	is a real interruption - you are walking until you have got your breath
	back.

	Sprinting is included for free: the gate is Helix's own `brth` flag, and
	Helix already caps a winded player to walk speed. Nothing here has to block
	sprinting because the same flag already does.

	FOUR AND A HALF JUMPS is the figure, so the cost is 100/4.5. The half is
	deliberate rather than a rounding artefact: at exactly four the fourth jump
	empties the bar precisely and whether it is allowed depends on floating
	point. At four and a half the fifth is unambiguously refused with 11
	stamina still showing, which reads as "not enough" rather than as a bug.

	SHARED, because movement is predicted. The client has to reach the same
	decision as the server or the player's own jumps stutter - they would jump
	locally, the server would refuse, and the position would snap back.
]]

ix.jump = ix.jump or {}

ix.config.Add("jumpStaminaCost", math.Round(100 / 4.5, 2),
	"Stamina one jump costs. 100 divided by this is how many jumps you get.",
	nil, {data = {min = 0, max = 100}, category = "Movement"})

--[[
	WHAT A JUMP COSTS THIS PLAYER, in the units the bar is kept in.

	`jumpStaminaCost` is the cost for somebody with NO ENDURANCE, and Endurance
	buys more jumps out of the same bar - which needs saying because the bar
	does not grow. Helix's stamina is hardcoded 0-100 everywhere, so a bigger
	pool cannot be a bigger bar: `AdjustStaminaOffset` already makes the same
	bar drain more slowly instead, and a flat jump cost was the one thing left
	that ignored the pool entirely. An Endurance 10 character had a bar that
	lasted twice as long at a sprint and exactly four and a half jumps.

	Scaled the same way the drain is, so the two agree: cost times 100 over the
	effective pool. At the defaults that is 22.2 of the bar at Endurance 0 and
	13.9 at Endurance 10, which is four and a half jumps and a little over
	seven.

	Guarded, because `sh_special.lua` is a separate library - without it this is
	exactly the flat cost it always was.
]]
function ix.jump.Cost(client)
	local cost = ix.config.Get("jumpStaminaCost", 22.22)
	local character = IsValid(client) and client:GetCharacter()

	if (not character or not ix.special or not ix.special.GetMaxStamina) then
		return cost
	end

	local maximum = ix.special.GetMaxStamina(character)

	if (maximum <= 0) then return cost end

	return cost * (100 / maximum)
end

--[[
	Can this player jump right now?

	Shared and read-only, so the HUD or anything else can ask without changing
	anything.
]]
function ix.jump.CanJump(client)
	if (not IsValid(client)) then return false end

	local character = client:GetCharacter()

	if (not character) then return true end

	--[[
		Power armour does not tire you, and it does not tire you here either -
		`sh_special.lua` removes the sprint drain for the same reason. A suit
		that carries its own weight is not going to be winded by a hop.
	]]
	if (client:GetNW2Bool("WearingPA", false)) then return true end

	--[[
		HELIX'S OWN WINDED FLAG, not one of ours.

		The first version kept `ixWinded` and a timer to clear it at 99. That
		was a second, slightly different definition of the same idea, and Helix
		already has one:

		    if (value == 0 and !client:GetNetVar("brth", false)) then
		        client:SetNetVar("brth", true)
		    elseif (value >= 50 and client:GetNetVar("brth", false)) then
		        client:SetNetVar("brth", nil)
		                -- helix/plugins/stamina/sh_plugin.lua:55

		Set when the bar empties, cleared at HALF - which is what "until it
		regens at least half way" means - and Helix already caps you to walk
		speed while it is set, so sprinting is refused by the same flag without
		anything here touching it. One flag, one rule, and jumping and
		sprinting come back at the same moment.
	]]
	if (client:GetNetVar("brth", false)) then return false end

	return client:GetLocalVar("stm", 100) >= ix.jump.Cost(client)
end

if (SERVER) then
	--[[
		Charge for a jump, and raise the winded flag if that emptied the bar.

		The flag has to be set HERE rather than left to Helix. Its own check is
		`value == 0` inside its regeneration tick, comparing a number it just
		computed - a jump that takes the bar to zero between two of those ticks
		is never seen by it, because by the next tick the bar is already
		regenerating and is no longer zero.

		Clearing it is still Helix's, at half.
	]]
	function ix.jump.Charge(client)
		local cost = ix.jump.Cost(client)
		local value = math.max(client:GetLocalVar("stm", 100) - cost, 0)

		client:SetLocalVar("stm", value)

		--[[
			Winded at anything under one more jump, not at zero exactly. The
			last affordable jump leaves a fraction behind, and waiting for a
			true zero means the flag never sets at all.
		]]
		if (value < cost) then
			client:SetNetVar("brth", true)
		end
	end
end

--[[
	Take the jump away before the engine sees it.

	`SetupMove` is the only place a jump can be stopped without the player
	having already left the ground - `KeyPress` fires after the move is built,
	and cancelling there produces a hop that is undone a tick later.

	THE RISING EDGE COMES FROM THE ENGINE, NOT FROM A FLAG.

	The first version kept `client.ixJumpHeld` to spot the tick the key went
	down, which is wrong in a way that only shows up in motion: `SetupMove` is
	predicted, so the client runs it many times over for the same tick during a
	correction, and a field set on one of those passes makes the client and the
	server disagree about whether a jump happened. `GetOldButtons` is the
	engine's own previous-tick state and is rolled back with everything else.

	Sandbox does exactly this for its own jump handling:

	    if bit.band( move:GetButtons(), IN_JUMP ) ~= 0
	    and bit.band( move:GetOldButtons(), IN_JUMP ) == 0
	    and self.Player:OnGround() then
	                -- sandbox/gamemode/player_class/player_sandbox.lua:155

	Runs on both realms so prediction agrees. The charge is server-only, which
	is why that is guarded rather than the whole hook.
]]
hook.Add("SetupMove", "ixJump", function(client, moveData, cmd)
	local buttons = moveData:GetButtons()

	--[[
		Pressed this tick, not held. Charging per tick would empty the bar in a
		third of a second of holding space.
	]]
	if (bit.band(buttons, IN_JUMP) == 0) then return end
	if (bit.band(moveData:GetOldButtons(), IN_JUMP) ~= 0) then return end

	--[[
		ONLY SOMEBODY WALKING IS JUMPING.

		In noclip the up key is `IN_JUMP`, and `FL_ONGROUND` is not cleared the
		instant the movetype changes - so for the first moment after switching
		to noclip, a player standing on the floor still answers `OnGround()`
		and this hook ran on their attempt to rise. Moving forward cleared the
		flag and it started working, which is exactly the symptom: you could
		not go straight up until you had gone forwards first.

		A player who is not walking is not jumping, whatever the button says.
	]]
	if (client:GetMoveType() ~= MOVETYPE_WALK) then return end

	if (not client:Alive() or not client:OnGround()) then return end

	if (ix.jump.CanJump(client)) then
		if (SERVER) then
			ix.jump.Charge(client)
		end

		return
	end

	--[[
		Refused. The button is stripped from this move so the engine never sees
		it, which is what makes the player simply not leave the ground rather
		than jumping and being corrected.
	]]
	moveData:SetButtons(bit.band(buttons, bit.bnot(IN_JUMP)))
end)
