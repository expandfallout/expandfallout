--[[
	Lockpicking, the New Vegas way.

	A locked container shows the lock interface rather than its contents: a
	cylinder you turn with the mouse and a bobby pin you rotate to find the
	spot where it will turn all the way. Phoenix's plugin is the reference and
	the models and sounds are the same ones - `lockpickinterface.mdl` and
	`bobbypin01.mdl` from `af_content_pack_1`, which this schema already
	mounts.

	WHERE THE ANSWER LIVES: on the SERVER.

	The client never learns where the sweet spot is. It sends the angle the pin
	is at and the server replies with ONE NUMBER - how far the cylinder may
	turn from there, 0 to 1 - which is the same shape Phoenix use and the only
	shape that cannot be read out of a client's memory. A client that knew the
	answer would be a lock that opens itself.

	LOOTERS ONLY, for now. `ix.lockpick.canPick` is the list of classes a lock
	may be put on, and doors, workbenches and teleports are deliberately not in
	it yet - each of those has its own idea of what "locked" means and adding
	them is a decision about those systems rather than about this one.
]]

ix.lockpick = ix.lockpick or {}

--[[
	The five locks, in the game's own words.

	`tolerance` is the half-width of the sweet spot in DEGREES, and it is the
	whole of the difficulty: the pin can be anywhere within that many degrees
	of the answer and the cylinder will turn. Very Easy is a fifth of the dial
	and Very Hard is a sliver.

	Stated in degrees rather than as the 0.9-1.0 thresholds Phoenix use because
	degrees are the thing being aimed at - "you must be within four degrees" is
	a sentence somebody balancing this can check with a protractor, and a
	threshold of 0.98 is not.
]]
ix.lockpick.levels = {
	{id = 1, name = "Very Easy", tolerance = 20},
	{id = 2, name = "Easy", tolerance = 14},
	{id = 3, name = "Average", tolerance = 9},
	{id = 4, name = "Hard", tolerance = 6},
	{id = 5, name = "Very Hard", tolerance = 3}
}

--- `[level] = entry`, for the lookups that do not want to walk the list.
ix.lockpick.byLevel = {}

for _, level in ipairs(ix.lockpick.levels) do
	ix.lockpick.byLevel[level.id] = level
end

--- The name of a lock level, or "None" for 0.
function ix.lockpick.Name(level)
	local entry = ix.lockpick.byLevel[tonumber(level) or 0]

	return entry and entry.name or "None"
end

--- Which entity classes may carry a lock. See the note at the top.
ix.lockpick.canPick = {
	["ix_lootable"] = true
}

--- The item a pick attempt spends. One item, one pin, one snap.
ix.lockpick.pinItem = "equipment_lockpick"

--[[
	HOW FAR THE CYLINDER TURNS, given where the pin is.

	Returns 0 to 1. **1 means the lock opens** - anything less is how far it
	gets before it jams, which is the feedback the whole minigame is made of:
	a cylinder that barely moves says "nowhere near", one that almost goes
	round says "a hair to the left".

	Inside the tolerance the answer is 1 and the lock opens, which is what
	makes an easy lock easy. Outside it, the turn falls away with the distance
	and is capped below 1 so that no amount of persistence at the wrong angle
	can ever open it.

	Shared because the server answers with it and the client's own preview -
	`fo_lockpick` - checks itself against the same function.
]]
function ix.lockpick.Difference(angle, sweetSpot, level)
	local entry = ix.lockpick.byLevel[tonumber(level) or 1]

	if (not entry) then return 0 end

	local delta = math.abs(math.AngleDifference(angle or 0, sweetSpot or 0))

	if (delta <= entry.tolerance) then return 1 end

	--[[
		Beyond the sweet spot: 0.95 right at its edge down to almost nothing at
		the far side of the dial. Capped at 0.95 rather than 0.99 so the
		difference between "close" and "open" is visible in the animation
		rather than being a pixel of cylinder travel.
	]]
	local reach = math.max(90 - entry.tolerance, 1)
	local fraction = math.Clamp((delta - entry.tolerance) / reach, 0, 1)

	return math.max(0.95 - fraction * 0.95, 0)
end

ix.config.Add("lockpickXP", 5, "Experience for picking a lock.", nil, {
	data = {min = 0, max = 500},
	category = "Lockpicking"
})

--[[
	HOW LONG A PICKED CONTAINER STAYS OPEN.

	It relocks itself afterwards, which is the difference between picking a
	lock and breaking one. Phoenix relock their workbenches on a timer for the
	same reason: a container that stayed open for ever would be picked once,
	on the day the map was made, and never again.
]]
ix.config.Add("lockpickOpenTime", 300,
	"Seconds a picked container stays unlocked before it relocks.", nil, {
	data = {min = 0, max = 86400},
	category = "Lockpicking"
})

ix.config.Add("lockpickBreakChance", 0, "Extra percent chance a pin snaps on "
	.. "any failed turn, on top of holding the turn too long.", nil, {
	data = {min = 0, max = 100},
	category = "Lockpicking"
})
