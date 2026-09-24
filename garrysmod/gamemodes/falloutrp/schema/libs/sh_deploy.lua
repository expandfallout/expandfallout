--[[
	Deploying things into the world.

	Phoenix's placement flow, which is the same one for everything they let you
	put down: a translucent ghost of the thing follows your aim, J and K turn
	it, left click places it and right click gives up. What you place is frozen
	where you put it.

	THE GHOST IS THE POINT. A prop that appears already placed gives you one
	chance to get the angle right and no way to see what you are about to get;
	the ghost makes placing something a thing you can aim rather than a thing
	you undo.

	SHARED because both realms need the same limits - the client will not let
	you place beyond the range, and the server refuses it again anyway. The
	client half is a courtesy and the server half is the rule.
]]

ix.deploy = ix.deploy or {}

--[[
	How far from your feet you can put something.

	Deliberately short. It is a placement tool, not a way to build across a
	room, and the ghost has to be somewhere you can see properly to be worth
	having.
]]
ix.deploy.range = 200

--- Degrees per step while a rotate key is held, and how often a step happens.
ix.deploy.rotateStep = 5
ix.deploy.rotateInterval = 0.05

--[[
	Is this a legal place to put something, for this player?

	Returns `true`, or `false, reason`. Asked by the ghost every frame so the
	preview can turn red, and asked again by the server before anything is
	created - one function, so the preview cannot promise something the server
	will refuse.
]]
function ix.deploy.CanPlace(client, position)
	if (not IsValid(client) or not client:Alive()) then
		return false, "You cannot do that right now."
	end

	if (position:Distance(client:GetPos()) > ix.deploy.range) then
		return false, "Too far away."
	end

	--[[
		Nothing solid where it is going. `TraceHull` rather than a point trace,
		because a point trace is happy to put a locker inside a wall as long as
		the exact origin is clear.
	]]
	local trace = util.TraceHull({
		start = position + Vector(0, 0, 8),
		endpos = position + Vector(0, 0, 8),
		mins = Vector(-8, -8, 0),
		maxs = Vector(8, 8, 16),
		filter = client,
		mask = MASK_SOLID
	})

	if (trace.Hit) then
		return false, "There is something in the way."
	end

	return true
end
