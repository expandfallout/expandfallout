--[[
	Bodies that stay where they fell.

	WHY THIS EXISTS AT ALL: Garry's Mod deletes the death ragdoll the moment
	the player respawns. `GM:DoPlayerDeath` calls `client:CreateRagdoll()` and
	the engine removes that entity on the next `Player:Spawn`, so with a five
	second `spawnTime` - and this schema's spawn-point menu, which can respawn
	you the instant you pick one - a corpse is gone before anybody has walked
	over to it. "No body appears when you kill people" is not a bug in the
	dismemberment; it is what the engine's corpse is for, which is a death
	animation rather than a thing in the world.

	So the engine's is suppressed and this schema makes its OWN, which belongs
	to nobody, survives the respawn, and lasts `corpseLife` seconds.

	THE BODY IS THE ONLY WAY TO GET A HEAD. Phoenix have a "Head Collection
	Time" config and this is what it is for: you hold E on a corpse for three
	seconds and cut the head off. Shooting somebody in the head DECAPITATES
	them - the head is gone from the body, and with it any chance of taking
	one. A head is a trophy you had to walk over and take, not loot that falls
	out of a headshot.

	AND IT IS UNMARKED. The head says what the body WAS - "NCR - Trooper Head"
	- and never who. A severed head that names its owner is a piece of evidence
	that identifies itself; one that names a faction and a rank is a message,
	which is the thing people actually put on a spike.
]]

ix.corpse = ix.corpse or {}

--------------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------------

ix.config.Add("corpseEnabled", true,
	"Whether bodies stay in the world after somebody dies.", nil,
	{category = "Dismemberment"})

--[[
	HOW LONG A BODY LASTS, and this is the performance dial.

	Every corpse is a `prop_ragdoll` with a full physics skeleton, and a busy
	firefight makes them faster than anybody picks them up. Thirty seconds is
	long enough to walk over to somebody you just shot and short enough that a
	raid does not leave forty of them lying about.

	IT IS EXTENDED WHILE SOMEBODY IS CUTTING THE HEAD OFF. A three second job
	on a body with two seconds left is a job that cannot be finished, and the
	failure is invisible - the body simply vanishes mid-action. Reaching for a
	corpse pushes its clock out past the end of the job.

	`dismemberGibLife` is the same dial for the gibs, which are cheaper but far
	more numerous.
]]
ix.config.Add("corpseLife", 30,
	"Seconds a body stays in the world before it disappears.", nil, {
	data = {min = 5, max = 3600}, category = "Dismemberment"})

--[[
	A LIMIT AS WELL AS A CLOCK, because the clock alone does not bound anything.

	Thirty people dying in ninety seconds is thirty bodies regardless of how
	long each one was going to last. When the limit is reached the OLDEST goes,
	which is the one somebody is least likely to still be walking towards.
]]
ix.config.Add("corpseMax", 24,
	"How many bodies may exist at once. The oldest goes first.", nil, {
	data = {min = 1, max = 128}, category = "Dismemberment"})

--[[
	A PERMANENTLY KILLED BODY LASTS LONGER, and it has to.

	Thirty seconds is right for the forty bodies a firefight leaves and wrong
	for the one that matters: a permanent kill is the rarest thing that happens
	on this server, and the named head is the whole of what the killer gets for
	it. Losing that to a timer while somebody runs back for a knife would be a
	reward the game took away again.
]]
ix.config.Add("corpsePKLife", 300,
	"Seconds a permanently killed body stays, so its head can be taken.", nil, {
	data = {min = 30, max = 3600}, category = "Dismemberment"})

ix.config.Add("corpseHeadTime", 3,
	"Seconds of holding E on a body to take its head.", nil, {
	data = {min = 1, max = 60}, category = "Dismemberment"})

--------------------------------------------------------------------------------
-- What a body is called
--------------------------------------------------------------------------------

--[[
	The item a head is. One uniqueID; the name comes from its data.

	It lives here rather than in `sh_pk.lua`, where it started, because the
	corpse is now the only thing that makes one - a permanent kill no longer
	drops a head, it leaves a body with a NAME on it and somebody has to come
	and take it.
]]
ix.corpse.headItem = "playerhead"

--[[
	"NCR - Trooper", or just "NCR" for somebody with no class.

	Built from the character rather than stored per corpse so a faction renamed
	in `/liveedit` renames the bodies too - and read here, in a shared file, so
	the tooltip and the item name cannot disagree about what a body is.
]]
function ix.corpse.Label(character)
	if (not character) then return "Unknown" end

	local faction = ix.faction.indices[character:GetFaction()]
	local name = faction and faction.name or "Wastelander"

	local class = ix.class.list[character:GetClass()]
	local rank = class and class.name

	--[[
		A CREATURE'S DEFAULT CLASS SAYS NOTHING. Every creature and machine
		in the Creatures faction starts as a "Wasteland Creature", which on a
		body reads as a label that forgot to say what it was. The race is the
		useful word there - "Creatures - Super Mutant" - and a creature that
		has been put in a real faction and given a real class keeps that,
		because then the class is the rank and the rank is the point.
	]]
	if (class and class.isDefault and ix.armor and ix.armor.raceKinds
	and ix.armor.raceKinds[character:GetRace()] and ix.races) then
		local race = ix.races.Get(character:GetRace())

		rank = race and race.name or rank
	end

	if (rank and rank ~= "") then
		return name .. " - " .. rank
	end

	return name
end
