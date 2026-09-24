--[[
	fo_phoenix_probe.lua - find out how Phoenix removes a limb.

	WHERE IT GOES

	    garrysmod/lua/autorun/client/fo_phoenix_probe.lua

	on YOUR machine. It is clientside and it runs on whatever server you join,
	including Phoenix. It reads only what your own client already has in memory
	to draw the scene - models, bodygroups, materials, bone manipulations - and
	changes nothing, sends nothing and touches no other player.

	WHAT TO DO

	    1. join Phoenix
	    2. find a body that has visibly lost a limb - shoot one apart if you
	       have to, or wait for a fight
	    3. stand near it and run:  fo_probe
	    4. paste the console output, or send the file it writes:
	           garrysmod/data/fo_probe.txt

	It also helps to run it on an INTACT body, so the two can be compared - the
	difference between them is the answer. `fo_probe` writes each run to the
	same file, so do the intact one first and copy it out before the second.

	WHAT IT IS LOOKING FOR

	There are only four ways to make part of a model stop being drawn, and this
	prints the state of all four so we can see which one Phoenix use:

	    BONES        a limb scaled or moved to nothing
	    BODYGROUPS   a limb that is its own submodel, switched off
	    MATERIALS    a limb with its own material, made invisible
	    MESHES       a limb that is its own model, not created at all

	This schema has been assuming the first for nine attempts and it leaves a
	visible shard, because a limb shares its vertices with the torso. If
	Phoenix use any of the other three, that is the whole answer.
]]

if (not CLIENT) then return end

local LIMBS = {
	{name = "head", bone = "Bip01 Head"},
	{name = "left arm", bone = "Bip01 L UpperArm"},
	{name = "right arm", bone = "Bip01 R UpperArm"},
	{name = "left leg", bone = "Bip01 L Thigh"},
	{name = "right leg", bone = "Bip01 R Thigh"}
}

local lines = {}

local function Say(text)
	lines[#lines + 1] = text or ""

	MsgN(text or "")
end

--- A vector printed short, and marked when it is not the default.
local function Vec(value, default)
	if (not value) then return "nil" end

	local text = string.format("%.4g %.4g %.4g", value.x, value.y, value.z)

	if (default and math.abs(value.x - default) < 0.0001
	and math.abs(value.y - default) < 0.0001
	and math.abs(value.z - default) < 0.0001) then
		return text
	end

	return text .. "   <-- CHANGED"
end

--------------------------------------------------------------------------------
-- One entity, in as much detail as matters
--------------------------------------------------------------------------------

local function Describe(entity, label)
	if (not IsValid(entity)) then return end

	Say("")
	Say(string.format("[%s] %s", label, tostring(entity)))
	Say(string.format("    class    %s", entity:GetClass() or "?"))
	Say(string.format("    model    %s", entity:GetModel() or "?"))
	Say(string.format("    index    %d   parent %s", entity:EntIndex(),
		IsValid(entity:GetParent()) and tostring(entity:GetParent()) or "none"))

	---------------------------------------------------------------- drawing ---

	Say(string.format("    nodraw   %s   rendermode %d   colour %s",
		tostring(entity:GetNoDraw()), entity:GetRenderMode() or 0,
		tostring(entity:GetColor())))

	Say(string.format("    renderoverride %s   material '%s'",
		entity.RenderOverride and "YES" or "no",
		entity:GetMaterial() or ""))

	--[[
		THE EFFECT FLAGS. `EF_BONEMERGE` merges the skeleton;
		`EF_PARENT_ANIMATES` is what makes the parent's bone SETUP - including
		manipulations - drive the child. Whether Phoenix set the second is
		worth knowing on its own.
	]]
	local effects = {}

	for name, value in pairs({
		EF_BONEMERGE = EF_BONEMERGE,
		EF_BONEMERGE_FASTCULL = EF_BONEMERGE_FASTCULL,
		EF_PARENT_ANIMATES = EF_PARENT_ANIMATES,
		EF_NODRAW = EF_NODRAW
	}) do
		if (value and entity:IsEffectActive(value)) then
			effects[#effects + 1] = name
		end
	end

	Say(string.format("    effects  %s",
		#effects > 0 and table.concat(effects, " ") or "none"))

	------------------------------------------------------------- bodygroups ---

	--[[
		IF A LIMB IS ITS OWN SUBMODEL, this is where it shows: a group called
		something like "larm" with two options, set to the empty one. That
		would be the clean way to remove a limb and the one this schema's
		models do not offer.
	]]
	local groups = entity:GetNumBodyGroups() or 0

	if (groups > 0) then
		local out = {}

		for index = 0, groups - 1 do
			out[#out + 1] = string.format("%d:%s=%d/%d", index,
				entity:GetBodygroupName(index) or "?",
				entity:GetBodygroup(index),
				entity:GetBodygroupCount(index) or 0)
		end

		Say("    bodygroups " .. table.concat(out, "  "))
	else
		Say("    bodygroups none")
	end

	Say(string.format("    skin     %d of %d", entity:GetSkin() or 0,
		entity:SkinCount() or 0))

	-------------------------------------------------------------- materials ---

	--[[
		AND IF A LIMB HAS ITS OWN MATERIAL, an invisible one would be set here
		as a sub-material override. An empty override is the normal state.
	]]
	local materials = entity:GetMaterials() or {}

	for index, path in ipairs(materials) do
		local override = entity:GetSubMaterial(index - 1)

		Say(string.format("    mat %d    %s%s", index - 1, path,
			(override and override ~= "")
				and ("   OVERRIDDEN -> " .. override) or ""))
	end

	------------------------------------------------------------------ bones ---

	local count = entity:GetBoneCount() or 0

	Say(string.format("    bones    %d", count))

	--- The named limb roots, whether or not they have been touched.
	for _, limb in ipairs(LIMBS) do
		local bone = entity:LookupBone(limb.bone)

		if (bone) then
			Say(string.format("      %-10s %-20s scale %s", limb.name,
				limb.bone,
				Vec(entity:GetManipulateBoneScale(bone), 1)))
		else
			Say(string.format("      %-10s %-20s NO SUCH BONE", limb.name,
				limb.bone))
		end
	end

	--[[
		AND EVERY BONE THAT HAS BEEN MANIPULATED AT ALL, by name. This is the
		single most useful line in the file: if Phoenix remove a limb with
		bones, every bone of it appears here with what it was set to. If
		NOTHING appears here on a body with a missing limb, they do not use
		bones at all and the answer is one of the other three.
	]]
	local touched = 0

	for bone = 0, count - 1 do
		local scale = entity:GetManipulateBoneScale(bone)
		local position = entity:GetManipulateBonePosition(bone)
		local angles = entity:GetManipulateBoneAngles(bone)

		local moved = (scale and (scale.x ~= 1 or scale.y ~= 1 or scale.z ~= 1))
			or (position and position ~= vector_origin)
			or (angles and (angles.p ~= 0 or angles.y ~= 0 or angles.r ~= 0))

		if (moved) then
			touched = touched + 1

			if (touched <= 40) then
				Say(string.format("      MANIPULATED %-3d %-24s scale %s  "
					.. "pos %s  ang %s", bone,
					entity:GetBoneName(bone) or "?",
					Vec(scale, 1), Vec(position, 0),
					position and tostring(angles) or "nil"))
			end
		end
	end

	Say(string.format("      %d bone(s) manipulated in total.", touched))

	--[[
		AND WHERE THE PHYSICS IS. A ragdoll's animation bones are placed by its
		physics objects, not by the bone hierarchy, so a collapsed limb's
		geometry gathers wherever its physics objects are. If a Phoenix corpse
		has moved or frozen the physics of a removed limb, this is where it
		shows - and it is the one thing the first probe could not see.
	]]
	if (entity.GetPhysicsObjectCount and entity:GetPhysicsObjectCount() > 0)
	then
		for index = 0, entity:GetPhysicsObjectCount() - 1 do
			local physics = entity:GetPhysicsObjectNum(index)

			if (IsValid(physics)) then
				local bone = entity:TranslatePhysBoneToBone(index)

				Say(string.format("      phys %-2d %-24s %s  %s", index,
					(bone and entity:GetBoneName(bone)) or "?",
					tostring(physics:GetPos()),
					physics:IsMoveable() and "moving" or "FROZEN"))
			end
		end
	end

	--[[
		THE RESULT, NOT THE INPUT. `GetManipulateBoneScale` says what an entity
		was told; `GetBoneMatrix` says what it ended up drawing with, after the
		merge copied the parent's matrices in. A mesh that was never told
		anything but whose thigh matrix reads scale zero is a mesh the merge is
		collapsing. Every bone whose final scale is not one is listed.
	]]
	local collapsed = 0

	for bone = 0, count - 1 do
		local matrix = entity:GetBoneMatrix(bone)

		if (matrix) then
			local scale = matrix:GetScale()

			if (scale and (math.abs(scale.x - 1) > 0.01
			or math.abs(scale.y - 1) > 0.01 or math.abs(scale.z - 1) > 0.01))
			then
				collapsed = collapsed + 1

				if (collapsed <= 40) then
					Say(string.format("      RESULT %-3d %-24s scale %.3g %.3g "
						.. "%.3g  at %s", bone, entity:GetBoneName(bone) or "?",
						scale.x, scale.y, scale.z,
						tostring(matrix:GetTranslation())))
				end
			end
		end
	end

	Say(string.format("      %d bone(s) collapsed in the final matrices.",
		collapsed))

	--- Where each limb root actually is, so carrier and mesh can be compared.
	for _, limb in ipairs(LIMBS) do
		local bone = entity:LookupBone(limb.bone)

		if (bone) then
			local position = entity:GetBonePosition(bone)

			Say(string.format("      %-10s at %s", limb.name,
				position and tostring(position) or "?"))
		end
	end
end

--------------------------------------------------------------------------------
-- The command
--------------------------------------------------------------------------------

--[[
	A clientside model is not solid, so an eye trace goes through one and finds
	the world. The body you are looking at is found by trace where possible and
	by proximity otherwise, and everything attached to it is described whether
	the trace could see it or not.
]]
concommand.Add("fo_probe", function()
	lines = {}

	Say("================================================================")
	Say("fo_probe  -  " .. os.date("%Y-%m-%d %H:%M:%S"))
	Say("map " .. game.GetMap() .. "   gamemode "
		.. (engine.ActiveGamemode() or "?"))
	Say("================================================================")

	local client = LocalPlayer()
	local target = client:GetEyeTrace().Entity
	local origin = client:GetPos()

	--- Prefer a ragdoll you are looking at; otherwise the nearest one.
	if (not IsValid(target) or not target:IsRagdoll()) then
		local best, bestDistance

		for _, entity in ipairs(ents.FindByClass("prop_ragdoll")) do
			local distance = entity:GetPos():DistToSqr(origin)

			if (not bestDistance or distance < bestDistance) then
				best, bestDistance = entity, distance
			end
		end

		target = best
	end

	if (not IsValid(target)) then
		Say("No ragdoll found. Stand near a body and try again.")
	else
		Describe(target, "BODY")

		for _, child in ipairs(target:GetChildren()) do
			Describe(child, "child")
		end
	end

	--[[
		AND EVERYTHING ELSE NEARBY, briefly - the point is to see whether a
		Phoenix body is made of MORE PARTS than this schema's two. If their
		arms and legs are separate models, removing one is just not creating
		it, and that is the whole answer.
	]]
	Say("")
	Say("Everything within 400 units:")

	for _, entity in ipairs(ents.GetAll()) do
		if (IsValid(entity) and entity ~= client
		and entity:GetPos():DistToSqr(origin) < 400 * 400) then
			Say(string.format("    %-22s %-52s idx %-6d parent %s",
				entity:GetClass() or "?", entity:GetModel() or "?",
				entity:EntIndex(),
				IsValid(entity:GetParent())
					and tostring(entity:GetParent()) or "none"))
		end
	end

	Say("")
	Say("================================ end ===========================")

	file.Write("fo_probe.txt", table.concat(lines, "\n"))

	MsgN("\nWritten to garrysmod/data/fo_probe.txt\n")
end)

--[[
	The same, for a LIVING player - so an intact body and a broken one can be
	compared without waiting for somebody to die twice.
]]
concommand.Add("fo_probe_player", function()
	lines = {}

	local target = LocalPlayer():GetEyeTrace().Entity

	if (not IsValid(target) or not target:IsPlayer()) then
		target = LocalPlayer()
	end

	Say("================================================================")
	Say("fo_probe_player  -  " .. tostring(target))
	Say("================================================================")

	Describe(target, "PLAYER")

	for _, child in ipairs(target:GetChildren()) do
		Describe(child, "child")
	end

	file.Write("fo_probe_player.txt", table.concat(lines, "\n"))

	MsgN("\nWritten to garrysmod/data/fo_probe_player.txt\n")
end)

MsgN("[fo_probe] loaded - run 'fo_probe' next to a body, "
	.. "or 'fo_probe_player' looking at somebody.")
