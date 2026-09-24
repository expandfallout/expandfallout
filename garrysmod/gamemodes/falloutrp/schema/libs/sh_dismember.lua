--[[
	Taking people apart.

	Phoenix's dismemberment plugin, on this schema's bones. A killing blow to a
	limb has a chance - set by the CALIBRE that fired it - of removing that
	limb from the corpse: the bones are scaled to nothing so the arm is gone
	rather than limp, gibs are thrown out of the wound, and what is left can be
	picked up.

	    a head        comes OFF - and is gone. A head you can carry is one you
	                  cut off a whole body by hand; see `sh_corpse.lua`
	    an arm or leg drops a piece of Human Flesh
	    a torso hit   spills organs and nothing survives to carry

	THE CHANCE IS ON THE HITGROUP PROFILE, not here. A profile is already this
	schema's word for a calibre - see `sh_hitgroup.lua` - and Phoenix keep the
	multipliers and the dismemberment chance on one table for the same reason:
	they are two halves of one fact about a weapon. This library reads
	`profile.dismember` and never writes it.

	WHY IT NEVER FIRES ON A DEATHCLAW. The bone names are the Valve human
	skeleton (`Bip01 Head`, `Bip01 L Forearm`), and `LookupBone` answers nil on
	a model that does not have them. That is the whole of the creature check:
	anything wearing a human skeleton comes apart and anything else does not,
	without a list of races to keep in step with `races/`. Robots are excluded
	on their blood colour instead, because a synth wearing a human skeleton
	still should not spray meat.
]]

ix.dismember = ix.dismember or {}

--------------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------------

ix.config.Add("dismemberEnabled", true,
	"Whether killing blows can take limbs off.", nil,
	{category = "Dismemberment"})

--[[
	A SCALE ON EVERY CHANCE, not a chance of its own.

	The per-calibre numbers are the balance and they are worth keeping; what a
	server owner actually wants to say is "less of this than Phoenix" or "none
	at all", and one number that multiplies all ten says that without editing
	ten. 100 is Phoenix's numbers exactly, 0 turns it off as surely as the
	switch above, 200 doubles everything and caps at certain.
]]
ix.config.Add("dismemberScale", 100,
	"Percentage scale applied to every calibre's dismemberment chance.", nil, {
	data = {min = 0, max = 200}, category = "Dismemberment"})

ix.config.Add("dismemberGibLife", 30,
	"Seconds before gibs are removed from the world.", nil, {
	data = {min = 1, max = 300}, category = "Dismemberment"})

--[[
	ONE BURST PER PERSON PER TEN SECONDS. Every death leaves a body, but the
	gibs, the blood and the limbs are thrown only if this person has not just
	died - killing the same player over and over on a spawn is otherwise a
	gib fountain, and a cheap one to run.
]]
ix.config.Add("dismemberCooldown", 10,
	"Seconds after somebody's death before another death of theirs can take "
	.. "limbs or throw gibs.", nil, {
	data = {min = 0, max = 120}, category = "Dismemberment"})

--[[
	A MACHINE IS HARDER TO BLOW UP THAN A TORSO IS TO BURST. A securitron has
	five hundred hit points alive; a body that goes up at the torso's 120 is
	a body the burst that killed it finishes off, which is "it just explodes".
]]
ix.config.Add("dismemberRobotDamage", 250,
	"How much damage a robot's body must take before it blows up.", nil, {
	data = {min = 1, max = 2000}, category = "Dismemberment"})

--[[
	HOW MUCH A LIMB HAS TO TAKE BEFORE IT CAN COME OFF.

	Phoenix roll on the hitgroup of the KILLING BLOW and nothing else, which
	reads well and is almost never seen: an arm does reduced damage, so an arm
	shot is the least likely shot to be the one that kills. Three evenings of
	testing produced no limbs at all, and the conclusion was that dismemberment
	was broken rather than that it was rare.

	So damage to each limb is remembered while somebody is alive, and on death
	any limb that took this much is a candidate - which is Fallout's own rule
	(limbs are crippled by what they have taken) and it means emptying a
	magazine into somebody's legs does what everybody expects it to.

	The calibre's chance still decides; this only decides what it is rolled
	against.
]]
ix.config.Add("dismemberLimbDamage", 40,
	"Damage one limb must take before it can be blown off.", nil, {
	data = {min = 1, max = 500}, category = "Dismemberment"})

--- A body's head, shot where it lies. No roll; see `sv_dismember.lua`.
ix.config.Add("dismemberHeadDamage", 50,
	"Damage a body's head must take before it bursts.", nil, {
	data = {min = 1, max = 500}, category = "Dismemberment"})

--[[
	WHAT IT TAKES TO DESTROY A BODY OUTRIGHT.

	Higher than a limb, because this removes the corpse entirely - the head
	that could have been taken off it goes with it, and so does anything else
	anybody was going to do with it. Keeping shooting a body you have already
	taken apart is the way to make it stop existing.
]]
ix.config.Add("dismemberGibDamage", 120,
	"Damage to a body's torso before it comes apart entirely.", nil, {
	data = {min = 1, max = 1000}, category = "Dismemberment"})

--[[
	HEADPOP: the head comes apart on a fatal headshot.

	Separate from the rest because it is the one everybody knows, and because
	it has to be switchable on its own - a server can want limbs without
	wanting heads bursting.

	IT NEVER HAPPENS TO A PERMANENT KILL. A PK'd body has to keep its head, or
	the head worth taking - the one with a name on it - could be destroyed by
	the shot that earned it. See `sv_pk.lua`.
]]
ix.config.Add("headpopEnabled", true,
	"Whether a fatal headshot bursts the head.", nil,
	{category = "Dismemberment"})

--------------------------------------------------------------------------------
-- Noise
--------------------------------------------------------------------------------

--[[
	VJ Base's gib set, which the server already mounts for the gib MODELS - so
	the sounds a limb makes come from the same pack as the pieces it leaves.
	`_docs/tools/resolve_asset.py` confirms all seven.
]]
ix.dismember.sounds = {
	snap = {
		"vj_base/gib/bone_snap1.wav", "vj_base/gib/bone_snap2.wav",
		"vj_base/gib/bone_snap3.wav"
	},
	tear = {
		"vj_base/gib/break1.wav", "vj_base/gib/break2.wav",
		"vj_base/gib/break3.wav"
	},
	splat = {"vj_base/gib/splat.wav"}
}

--- One of a set, or nothing if the set is unknown.
function ix.dismember.Sound(kind)
	local list = ix.dismember.sounds[kind]

	return list and list[math.random(#list)]
end

--[[
	Whether a severed limb leaves anything behind.

	There is no matching switch for heads, and that is the point: a headshot
	DESTROYS the head, and the only head anybody can carry is one cut off a
	whole body by hand. `corpseHeadTime` in `sh_corpse.lua` is that side of it.
]]
ix.config.Add("dismemberFlesh", true,
	"Whether a severed arm or leg drops Human Flesh.", nil,
	{category = "Dismemberment"})

--------------------------------------------------------------------------------
-- What comes off, and what comes out
--------------------------------------------------------------------------------

--[[
	Bones to hide, and gibs to throw, per hitgroup.

	`bones` are scaled to nothing on the corpse. Every bone BELOW the joint has
	to be listed - scaling a forearm does not scale the hand hanging off it -
	which is why the arms carry eighteen entries and the head carries one.

	`gibs` are models spawned at a named bone. The models are VJ Base's human
	gib set, which the server already mounts; `_docs/tools/resolve_asset.py`
	confirms all eight.

	THESE ARE THE RIGHT MODELS AND WERE BRIEFLY CHANGED FOR NOTHING. A
	proximity scan found nothing near a corpse except these gibs, and the
	conclusion drawn - that they were therefore the "fragments" being reported -
	was wrong: the fragments were the limb mesh itself, and the reason is four
	files away in `cl_bodyparts.lua`. gib1 and gib3 were huge in their place.
	Changing what a thing looks like because it is the only thing you can see
	is not a diagnosis.

	`hitBones` are bones that BELONG to the limb but are never scaled - they
	exist only so a shot that lands on one can be traced back to the limb it is
	part of. The torso uses them for its whole definition: a chest cannot be
	removed and still leave a body to look at, but it can certainly be shot.

	THE TWIST BONES ARE THE REASON ARMS STRETCHED AND LEGS DID NOT.

	`Bip01 LUpArmTwistBone` and `Bip01 L ForeTwist` are children of the upper
	arm and the forearm, and a great many of an arm's vertices are weighted to
	them. Phoenix's own limb table leaves them out - so an arm scaled away left
	every twist-weighted vertex exactly where it was, and the mesh stretched
	between a collapsed shoulder and geometry that had not moved. A leg has no
	twist bones, which is precisely why legs looked right the whole time.

	Both spellings are listed. The dump in Phoenix's plugin gives
	`Bip01 LUpArmTwistBone` with no space and `Bip01 L ForeTwist` with one,
	which is the sort of inconsistency that survives a decade of model
	exports; `LookupBone` answers nil for the ones a model does not have, so
	listing both costs nothing.
]]
ix.dismember.limbs = {
	[HITGROUP_HEAD] = {
		name = "head",
		bones = {"Bip01 Head"},
		gibs = {
			{model = "models/vj_base/gibs/human/eye.mdl", bone = "Bip01 Head"},
			{model = "models/vj_base/gibs/human/brain.mdl", bone = "Bip01 Head"}
		}
	},

	[HITGROUP_LEFTARM] = {
		name = "left arm",
		bones = {
			"Bip01 L UpperArm", "Bip01 L Forearm", "Bip01 L Hand",
			"Bip01 LUpArmTwistBone", "Bip01 L UpArmTwistBone",
			"Bip01 L ForeTwist", "Bip01 LForeTwist",
			"Bip01 L Thumb1", "Bip01 L Thumb11", "Bip01 L Thumb12",
			"Bip01 L Finger0", "Bip01 L Finger01", "Bip01 L Finger02",
			"Bip01 L Finger1", "Bip01 L Finger11", "Bip01 L Finger12",
			"Bip01 L Finger2", "Bip01 L Finger21", "Bip01 L Finger22",
			"Bip01 L Finger3", "Bip01 L Finger31", "Bip01 L Finger32",
			"Bip01 L Finger4", "Bip01 L Finger41", "Bip01 L Finger42"
		},
		gibs = {
			{model = "models/vj_base/gibs/human/gib6.mdl",
				bone = "Bip01 L UpperArm"},
			{model = "models/vj_base/gibs/human/gib7.mdl",
				bone = "Bip01 L Forearm"}
		}
	},

	[HITGROUP_RIGHTARM] = {
		name = "right arm",
		bones = {
			"Bip01 R UpperArm", "Bip01 R Forearm", "Bip01 R Hand",
			"Bip01 RUpArmTwistBone", "Bip01 R UpArmTwistBone",
			"Bip01 R ForeTwist", "Bip01 RForeTwist",
			"Bip01 R Thumb1", "Bip01 R Thumb11", "Bip01 R Thumb12",
			"Bip01 R Finger0", "Bip01 R Finger01", "Bip01 R Finger02",
			"Bip01 R Finger1", "Bip01 R Finger11", "Bip01 R Finger12",
			"Bip01 R Finger2", "Bip01 R Finger21", "Bip01 R Finger22",
			"Bip01 R Finger3", "Bip01 R Finger31", "Bip01 R Finger32",
			"Bip01 R Finger4", "Bip01 R Finger41", "Bip01 R Finger42"
		},
		gibs = {
			{model = "models/vj_base/gibs/human/gib6.mdl",
				bone = "Bip01 R UpperArm"},
			{model = "models/vj_base/gibs/human/gib7.mdl",
				bone = "Bip01 R Forearm"}
		}
	},

	[HITGROUP_LEFTLEG] = {
		name = "left leg",
		bones = {"Bip01 L Thigh", "Bip01 L Calf", "Bip01 L Foot",
			"Bip01 L Toe0"},
		gibs = {
			{model = "models/vj_base/gibs/human/gib6.mdl",
				bone = "Bip01 L Thigh"},
			{model = "models/vj_base/gibs/human/gib7.mdl",
				bone = "Bip01 L Calf"}
		}
	},

	[HITGROUP_RIGHTLEG] = {
		name = "right leg",
		bones = {"Bip01 R Thigh", "Bip01 R Calf", "Bip01 R Foot",
			"Bip01 R Toe0"},
		gibs = {
			{model = "models/vj_base/gibs/human/gib6.mdl",
				bone = "Bip01 R Thigh"},
			{model = "models/vj_base/gibs/human/gib7.mdl",
				bone = "Bip01 R Calf"}
		}
	},

	[HITGROUP_STOMACH] = {
		name = "stomach",
		hitBones = {"Bip01 Spine", "Bip01 Pelvis", "Bip01"},
		gibs = {
			{model = "models/vj_base/gibs/human/gib2.mdl",
				bone = "Bip01 Spine"}
		}
	},

	[HITGROUP_CHEST] = {
		name = "chest",
		hitBones = {
			"Bip01 Spine1", "Bip01 Spine2", "Bip01 Neck", "Bip01 Neck1",
			"Bip01 L Clavicle", "Bip01 R Clavicle"
		},
		gibs = {
			{model = "models/vj_base/gibs/human/heart.mdl",
				bone = "Bip01 Spine1"},
			{model = "models/vj_base/gibs/human/liver.mdl",
				bone = "Bip01 Spine1"},
			{model = "models/vj_base/gibs/human/lung.mdl",
				bone = "Bip01 Spine1"}
		}
	}
}

--- The two that leave something behind, as a set rather than a chain of ors.
ix.dismember.fleshLimbs = {
	[HITGROUP_LEFTARM] = true, [HITGROUP_RIGHTARM] = true,
	[HITGROUP_LEFTLEG] = true, [HITGROUP_RIGHTLEG] = true
}

--------------------------------------------------------------------------------
-- Asking
--------------------------------------------------------------------------------

--[[
	How likely this weapon is to take a limb, 0-100.

	`uniqueID` is an ITEM's, the same thing `ix.hitgroup.Profile` wants - a
	weapon with no item behind it (an admin's spawned SWEP, an NPC's) falls
	through to the default profile, which is what an unlisted calibre already
	does everywhere else in this schema.
]]
function ix.dismember.Chance(uniqueID)
	local profile = ix.hitgroup.Profile(uniqueID)
	local chance = profile.dismember or 0

	return math.Clamp(chance * (ix.config.Get("dismemberScale", 100) / 100),
		0, 100)
end

--- Whether this hitgroup is one that can come apart at all.
function ix.dismember.Limb(hitgroup)
	return ix.dismember.limbs[hitgroup]
end

--[[
	HOW SMALL A REMOVED LIMB IS, AND WHY IT IS NOT ZERO.

	This is the answer to the sliver, and it took an embarrassing number of
	rounds to reach because every other explanation was about WHICH bones.

	`ManipulateBoneScale(bone, vector_origin)` writes a scale of exactly zero
	into the bone's local matrix, which makes that matrix SINGULAR - its basis
	collapses to nothing and it can no longer be inverted or meaningfully
	concatenated with its parent. Source does not check for this. What comes
	out the other side of the bone-chain maths is not "the limb, very small at
	the joint"; it is garbage, and the geometry ends up smeared between the
	joint and the model's own origin. That smear is the thin pale spike that
	has been photographed six times.

	A thousandth is not zero. The matrix stays invertible, the arithmetic stays
	sane, and an arm ends up six thousandths of an inch long at the shoulder -
	which is to say inside the shoulder, invisible, and gone.

	It also makes applying the collapse twice harmless: a thousandth of a
	thousandth is still a well-formed matrix at the same place, where zero
	times zero was two lots of garbage. The "hand hanging in the air off the
	end of the arm" was that, and it is why this is now applied to the body AND
	to every mesh merged onto it without having to know which of them the merge
	would have covered.

	AND A LIMB'S GEOMETRY IS NOT HIDDEN. See `dismemberHideLimbs` below for the
	whole of why; the short version is that a limb shares its vertices with the
	torso and a head does not.

	TWO REAL FAULTS WERE FOUND ON THE WAY and both are fixed regardless:
	`animations.mdl` has a 385 KB mesh that this schema had recorded as empty
	and that nothing was hiding, and merged meshes were missing
	`EF_PARENT_ANIMATES`. Neither was the artifact. Both were worth having.
]]
--[[
	EXACTLY ZERO, WHICH IS WHAT PHOENIX USE.

	Read off a Phoenix corpse with both legs gone, with a clientside probe:

	    [BODY] prop_ragdoll  animations.mdl
	      MANIPULATED  Bip01 L Thigh   scale 0 0 0
	      MANIPULATED  Bip01 L Calf    scale 0 0 0
	      MANIPULATED  Bip01 L Foot    scale 0 0 0
	      MANIPULATED  Bip01 L Toe0    scale 0 0 0
	      ... and the same four on the right
	      8 bone(s) manipulated in total.

	    [child] defaultbody.mdl
	      left leg   Bip01 L Thigh     scale 1 1 1
	      0 bone(s) manipulated in total.

	Zero, every bone of the limb, ON THE CARRIER ONLY - and the visible body
	mesh is not touched at all. The legs were gone and there was no shard. A
	thousandth was an invention of mine to dodge a singular matrix that was
	never the problem.
]]
ix.dismember.gone = vector_origin

--[[
	WHETHER A REMOVED LIMB'S GEOMETRY IS HIDDEN AT ALL.

	ON, and it works the way Phoenix's does because it now IS the way Phoenix's
	does. A probe run on their server settled every question this had been
	guessed at for nine rounds:

	    the bones are scaled to EXACTLY ZERO
	    on the CARRIER RAGDOLL ONLY - the merged meshes are never touched
	    every bone of the limb, not just its root
	    and the carrier is left drawn, with no render override on it

	The meshes follow because they carry `EF_PARENT_ANIMATES`, which this
	schema was missing until recently and which is what makes a parent's bone
	SETUP - manipulations and all - drive a bone-merged child.

	A HEAD IS EXEMPT FROM THE SWITCH either way; it is its own model and it has
	worked since the first attempt.
]]
ix.config.Add("dismemberHideLimbs", true,
	"Whether a removed limb's geometry is hidden.", nil,
	{category = "Dismemberment"})

--- Whether this hitgroup's geometry should be collapsed at all.
function ix.dismember.ShouldHide(hitgroup)
	if (hitgroup == HITGROUP_HEAD) then return true end

	return ix.config.Get("dismemberHideLimbs", false)
end

--------------------------------------------------------------------------------
-- Collapsing one
--------------------------------------------------------------------------------

--[[
	EVERY BONE HANGING OFF A JOINT, asked of the skeleton rather than listed.

	The bone lists above were written from Phoenix's dump and were wrong twice:
	first they missed the arm twist bones, and after those were added there were
	still fragments of mesh left floating where some OTHER bone nobody had named
	held a handful of vertices. Every model in this schema is a different
	export, so the list was never going to be finished - there is always one
	more helper bone.

	So the names stop here. The root of the limb is looked up once, and every
	bone whose parent chain passes through it is collapsed with it. That is
	exhaustive by construction: twist bones, finger bones, helper bones, face
	bones on a head, and whatever the next model happens to carry.

	Per entity, because a body and each mesh bone-merged onto it have their own
	bone indices for the same names.
]]
function ix.dismember.Descendants(entity, rootName)
	if (not IsValid(entity) or not rootName) then return nil end

	local root = entity:LookupBone(rootName)

	if (not root) then return nil end

	local out = {[root] = true}
	local count = entity:GetBoneCount() or 0

	for bone = 0, count - 1 do
		if (not out[bone]) then
			local parent = entity:GetBoneParent(bone)

			--- Deeper than any human skeleton; a stop, not a limit.
			for _ = 1, 32 do
				if (not parent or parent < 0) then break end

				if (parent == root) then
					out[bone] = true

					break
				end

				parent = entity:GetBoneParent(parent)
			end
		end
	end

	return out, root
end

--[[
	WHY A LIMB SCALED TO NOTHING WAS STILL A SHAPE, and what is done about it.

	Scaling a bone to zero does not move it. Its basis goes to nothing, so
	every vertex weighted to it lands ON the bone's origin - and the origin
	stays exactly where the bone was. Read straight off a body with a leg
	gone, on this server and on Phoenix alike:

	    RESULT  Bip01 L Foot   scale 0 0 0  at 7307.2 6659.8 1291.8
	    RESULT  Bip01 L Toe0   scale 0 0 0  at 7313.5 6665.5 1291.1

	The toe is still eight units past the foot. `Bip01 L Toe0` has no physics
	object - `animations.phy` names fifteen solids and it is not one - so it
	is placed by the ordinary hierarchy from its parent, and it is STILL not
	on the parent's origin: bone scale in this engine is applied to each
	bone's own matrix after the hierarchy is built, and children do not
	inherit it.

	So a "collapsed" limb is not a point. It is a skeleton of points, one per
	bone, with every triangle that spanned two of them stretched between them.
	For a leg that is four points nearly in a line, and nearly nothing. For a
	hand it is a wrist and fifteen finger joints spread across where the hand
	was, with every palm triangle still spanning them: a pale fan with five
	spikes - which is what every screenshot of "the fragment" shows, and why
	it was worst on hands and feet.

	THE PHYSICS BONES CANNOT BE MOVED. A ragdoll's thigh, calf, foot, upper
	arm, forearm and hand are placed by their physics objects and a bone
	manipulation does not reach them. Everything else in the limb hangs off
	one of those through the hierarchy, and `ManipulateBonePosition` IS
	honoured there - it is how a ragdoll's fingers get posed. It is an offset
	in the parent's frame, so each such bone is told to sit exactly on its
	parent's origin: fingers onto the wrist, toes onto the ankle, twist bones
	onto the shoulder and elbow. What is left is one point per physics
	object - three for an arm, three for a leg - and triangles between points
	on a line have no area to draw.

	THE OFFSETS COME FROM THE MODEL FILE, not from the ragdoll. The first
	version read each bone's position off the ragdoll's own bone matrices,
	and on the server those are not to be trusted for a bone with no physics
	object: a corpse answered for its toe with the reference pose at the
	entity's origin, 38 units from the foot the toe hangs off, and the toe
	was duly moved 38 units the wrong way. The client's matrices are right,
	but the manipulation has to be written on the server.

	What the client actually uses for such a bone is its local position in
	the sequence the ragdoll is playing, and a ragdoll plays sequence 0 - the
	reference pose - which is the bind pose the model file stores for every
	bone. A position manipulation is added to that in the PARENT'S frame.
	Checked against a live report: the toe's bind position plus the offset
	that had been written came to 42.96 units, and the toe was 42.96 units
	from the foot. So the offset is the negative of the bind position, and
	nothing is read off the ragdoll at all.
]]
function ix.dismember.Gather(entity, set)
	local count = entity.GetPhysicsObjectCount
		and entity:GetPhysicsObjectCount() or 0

	--- Only a ragdoll has joints to gather onto; a bare mesh has no physics.
	if (count == 0) then return 0 end

	local bind = ix.dismember.BindPose(entity:GetModel())

	if (not bind) then return 0 end

	local physical = {}

	for index = 0, count - 1 do
		local bone = entity:TranslatePhysBoneToBone(index)

		if (bone and bone >= 0) then physical[bone] = true end
	end

	local moved = 0

	for bone in pairs(set) do
		if (not physical[bone]) then
			local entry = bind[entity:GetBoneName(bone) or ""]

			if (entry and entry.parent >= 0) then
				entity:ManipulateBonePosition(bone, -entry.pos)

				moved = moved + 1
			end
		end
	end

	return moved
end

--[[
	The bind pose of a model, by bone name, read straight out of the .mdl.

	Once per model, cached. The layout is `studiohdr_t` / `mstudiobone_t` for
	versions 44 through 49, which is every model this schema loads: magic at
	0, bone count at 156, bone table offset at 160, and per 216-byte bone a
	name index at +0 (relative to the bone), a parent index at +4 and the
	local position at +32. A file that does not read as one answers nil, and
	a limb on it is scaled without gathering - which is what it was before.

	`file.Open` in the GAME path reads out of mounted workshop content and
	legacy addon folders alike; the bone table is a few kilobytes at the
	front of a file that is otherwise all animation, so the seek is cheap.
]]
local bindPoses = {}

function ix.dismember.BindPose(model)
	if (not isstring(model) or model == "") then return nil end

	local cached = bindPoses[model]

	if (cached ~= nil) then return cached or nil end

	bindPoses[model] = false

	local handle = file.Open(model, "rb", "GAME")

	if (not handle) then return nil end

	local ok, bones = pcall(function()
		if (handle:Read(4) ~= "IDST") then return nil end

		handle:Seek(156)

		local count = handle:ReadLong()
		local index = handle:ReadLong()

		if (count <= 0 or count > 512 or index <= 0) then return nil end

		local out = {}

		for i = 0, count - 1 do
			local start = index + i * 216

			handle:Seek(start)

			local nameIndex = handle:ReadLong()
			local parent = handle:ReadLong()

			handle:Seek(start + 32)

			local x = handle:ReadFloat()
			local y = handle:ReadFloat()
			local z = handle:ReadFloat()

			handle:Seek(start + nameIndex)

			local raw = handle:Read(64) or ""
			local stop = string.find(raw, "\0", 1, true)
			local name = stop and string.sub(raw, 1, stop - 1) or raw

			out[name] = {parent = parent, pos = Vector(x, y, z)}
		end

		return out
	end)

	handle:Close()

	if (ok and bones) then
		bindPoses[model] = bones

		return bones
	end

	--- Said once, so a report showing `offset none` has an explanation waiting.
	print(string.format("[Fallout] The bone table of %s could not be read; "
		.. "removed limbs on it are scaled without gathering.", model))

	return nil
end

--[[
	Scale a limb away on one entity, whichever part of it that entity has.

	A GLOVE HAS NO SHOULDER, and that was the last of the leftovers: the meshes
	that make up a body are separate models, and an armour piece for the hands
	carries `Bip01 L Hand` and the finger bones and NOTHING ABOVE THEM. Looking
	up `Bip01 L UpperArm` on it answers nil, the collapse found no root and did
	nothing, and a pair of hands and feet stayed floating where the arms and
	legs used to be - which is exactly what was left after everything else was
	fixed.

	So every name in the limb's list is tried, most proximal first, and each one
	the entity actually has is collapsed along with its descendants. On a whole
	body the first name catches everything and the rest are already done; on a
	glove the first two are missing and the hand is where it starts.

	Returns the set of bone indices it collapsed, which the server needs to
	find the physics objects underneath them.
]]
function ix.dismember.CollapseLimb(entity, limb, hitgroup)
	if (not IsValid(entity) or not limb or not limb.bones) then return end

	--[[
		A LIMB IS LEFT ALONE UNLESS SOMEBODY ASKED FOR IT - but the bones are
		still WALKED, because the set they produce is also the creature check:
		"does this model have a human skeleton" is what tells a person from a
		deathclaw, and refusing to answer it would stop the gibs and the blood
		as well as the geometry. Only the scaling is skipped.
	]]
	local hide = not hitgroup or ix.dismember.ShouldHide(hitgroup)

	--- Everything below the cut, on this entity's own skeleton.
	local done, any

	for _, name in ipairs(limb.bones) do
		local index = entity:LookupBone(name)

		if (index and not (done and done[index])) then
			local bones = ix.dismember.Descendants(entity, name)

			if (bones) then
				done = done or {}
				any = true

				for bone in pairs(bones) do done[bone] = true end
			end
		end
	end

	if (not any) then return nil end

	if (hide) then
		--- Onto the joints first, then to nothing. See `Gather` for why.
		ix.dismember.Gather(entity, done)

		for bone in pairs(done) do
			entity:ManipulateBoneScale(bone, ix.dismember.gone)
		end
	end

	return done
end

--[[
	`[bone name] = hitgroup`, built from the tables above.

	A RAGDOLL HAS NO HITGROUPS. `LastHitGroup` is a player thing; a corpse is a
	`prop_ragdoll`, and all a shot at one gives you is a position. So the limb
	is found from the BONE nearest that position instead, and this is what
	turns a bone name back into the limb it belongs to.

	Every bone of a limb is listed, not just the one that gets scaled, because
	a shot to the forearm and a shot to the hand are both shots to the arm.
]]
ix.dismember.boneGroups = {}

for hitgroup, limb in pairs(ix.dismember.limbs) do
	for _, name in ipairs(limb.bones or {}) do
		ix.dismember.boneGroups[name] = hitgroup
	end

	--- Bones that identify the limb without being part of what comes off.
	for _, name in ipairs(limb.hitBones or {}) do
		ix.dismember.boneGroups[name] = hitgroup
	end
end

--[[
	WHERE A SHOT LANDED, on a model that may not say.

	A hitgroup is a number written on each hitbox when the model was compiled,
	and the creature models were compiled for NPCs by people who had no reason
	to fill it in: every one of a super mutant's fifty-three hitboxes is group
	0, so a bullet in its head was a bullet in "generic", it never counted as
	a headshot and it could never pop the head. The gecko's are numbered from
	101, which is how VJ Base models write the standard seven.

	So a generic hit is placed by the nearest bone this library knows about -
	the same walk `HitgroupAt` does on a corpse, from the bone list rather
	than the physics - and the 101-107 numbering is folded back onto 1-7. A
	hitgroup the model did name is left exactly as it was; this only speaks
	where the model is silent.
]]
function ix.dismember.Hitgroup(entity, hitgroup, position)
	hitgroup = hitgroup or HITGROUP_GENERIC

	if (hitgroup >= 101 and hitgroup <= 107) then return hitgroup - 100 end
	if (hitgroup ~= HITGROUP_GENERIC or not IsValid(entity)) then
		return hitgroup
	end

	if (not position or position == vector_origin
	or position:DistToSqr(entity:GetPos()) > 200 * 200) then
		return hitgroup
	end

	local best, bestDistance

	for name, group in pairs(ix.dismember.boneGroups) do
		local bone = entity:LookupBone(name)

		if (bone) then
			local at = entity:GetBonePosition(bone)
			local distance = at and at:DistToSqr(position)

			if (distance and (not bestDistance or distance < bestDistance)) then
				best, bestDistance = group, distance
			end
		end
	end

	return best or hitgroup
end
