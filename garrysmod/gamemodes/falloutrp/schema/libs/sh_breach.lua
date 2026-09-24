--[[
	Blowing a door open.

	Phoenix's Doorbuster: a charge item that traces 96 units, sticks a
	`nut_dbuster` to whatever it hit, beeps for five seconds and then blasts
	every door within 32 units off its hinges for thirty. The rules of what may
	be blown are one function and one blacklist:

	    nut.doorBreach.blacklist = {["*289"] = true, ...}

	which is four brush models on THEIR map - the doors nobody was meant to get
	through. That list cannot be ported, because a brush model index means a
	different door on a different map, so this keeps the mechanism and starts
	the list empty. `fo_breach_block` fills it in, and it is saved with the rest
	of the world data.

	WHAT A BREACH DOES HERE, which is more than theirs:

	    an ordinary door    unlocked and blown off, exactly as theirs
	    an owned door       ownership is NOT touched. A blown door swings open;
	                        it does not change hands
	    a teleport          `ix.doors.Breach` - the lock is blown off and the
	                        teleport is released, which is this schema's
	                        equivalent of their `RecentlyPicked` unlock and is
	                        the only reason a raid on a base ever ends
]]

ix.breach = ix.breach or {}
ix.breach.blacklist = ix.breach.blacklist or {}

ix.config.Add("breachTime", 5,
	"Seconds a breaching charge beeps before it goes off.", nil, {
	data = {min = 1, max = 60},
	category = "Restraints"
})

ix.config.Add("breachDoorRestore", 30,
	"Seconds a blown door stays off its hinges.", nil, {
	data = {min = 5, max = 3600},
	category = "Restraints"
})

ix.config.Add("breachDamage", 80,
	"Damage a breaching charge does to anybody standing near it.", nil, {
	data = {min = 0, max = 500},
	category = "Restraints"
})

ix.config.Add("breachDamageRadius", 220,
	"How far the blast from a breaching charge hurts people.", nil, {
	data = {min = 0, max = 1024},
	category = "Restraints"
})

ix.config.Add("breachRadius", 48,
	"How far from the charge a door is still blown open.", nil, {
	data = {min = 8, max = 256},
	category = "Restraints"
})

--[[
	May this be blown?

	Three answers, in order: the blacklist, whether it is a door at all, and
	then anything a plugin wants to say through the hook. The hook is last so
	that a "yes" from it cannot get around the blacklist.
]]
function ix.breach.CanBreach(client, entity)
	if (not IsValid(entity)) then return false end

	local model = entity:GetModel()

	if (model and ix.breach.blacklist[model]) then return false end

	--[[
		A PROP TELEPORT IS A DOOR FOR THIS PURPOSE. `ix.doors.Link` answers for
		the crates and lockers this schema hangs teleports on, which are not
		doors by `IsDoor` and are exactly the things people build bases out of.
	]]
	if (not entity:IsDoor() and not ix.doors.Link(entity)) then return false end

	return hook.Run("CanBreachDoor", client, entity) ~= false
end
