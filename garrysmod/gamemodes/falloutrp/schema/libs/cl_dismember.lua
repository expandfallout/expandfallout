--[[
	Dismemberment, client side: nothing but the report.

	THERE IS NO CLIENT-SIDE BONE MANIPULATION HERE ANY MORE, and that is a
	deliberate match to Phoenix rather than an omission.

	Every earlier version of this file re-applied the server's bone scaling on
	the client - from a net message at the moment of dismemberment, and again
	whenever a body's meshes were rebuilt - on the theory that a corpse one
	tick old might have missed it. It never needed to. A bone manipulation set
	on the server is carried by a `manipulate_bone` entity parented to the
	ragdoll, which is networked to every client including ones that arrive
	later, and a probe on a Phoenix corpse shows exactly one of those and no
	client-side manipulation at all. Ours showed TWO - the server's and one
	the client had made - and two writers to one bone table is one more
	variable than Phoenix have. It is gone.

	`ix.dismember` IS DECLARED HERE TOO. `libs/` is included alphabetically and
	`file.Find` puts every `cl_` file before every `sh_` one, so this runs
	BEFORE `sh_dismember.lua` - see gotcha 26.
]]

if (not CLIENT) then return end

ix.dismember = ix.dismember or {}

--------------------------------------------------------------------------------
-- The report
--------------------------------------------------------------------------------

--[[
	Every bone whose FINAL matrix is not at unit scale, by name.

	This is the line that reads the RESULT rather than the input.
	`GetManipulateBoneScale` says what an entity was told; `GetBoneMatrix`
	says what it ended up drawing with, after the merge has copied the
	parent's matrices in. A mesh that was never told anything but whose thigh
	matrix reads scale zero is a mesh the merge is collapsing correctly. A mesh
	whose thigh matrix reads scale one, on a body whose carrier reads zero, is
	a mesh the merge is NOT reaching - and that is the shard, named.
]]
local function DumpMatrices(entity)
	local count = entity:GetBoneCount() or 0
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
					MsgN(string.format("        RESULT %-3d %-24s scale %.3g "
						.. "%.3g %.3g  at %s", bone,
						entity:GetBoneName(bone) or "?", scale.x, scale.y,
						scale.z, tostring(matrix:GetTranslation())))
				end
			end
		end
	end

	MsgN(string.format("        %d bone(s) collapsed in the final matrices.",
		collapsed))
end

--[[
	Every bone whose manipulation is not the default, by name - scale and
	position both, because a removed limb now carries both: the non-physics
	bones are moved onto their joints before everything is scaled to nothing.
	See `ix.dismember.Gather`.
]]
local function DumpManipulations(entity)
	local count = entity:GetBoneCount() or 0
	local touched = 0

	for bone = 0, count - 1 do
		local scale = entity:GetManipulateBoneScale(bone)
		local offset = entity:GetManipulateBonePosition(bone)
		local scaled = scale and (scale.x ~= 1 or scale.y ~= 1 or scale.z ~= 1)
		local moved = offset and offset ~= vector_origin

		if (scaled or moved) then
			touched = touched + 1

			if (touched <= 64) then
				local position = entity:GetBonePosition(bone)

				MsgN(string.format("        MANIPULATED %-3d %-24s scale "
					.. "%.3g  offset %s  at %s", bone,
					entity:GetBoneName(bone) or "?", scale and scale.x or 1,
					moved and tostring(offset) or "none",
					position and tostring(position) or "?"))
			end
		end
	end

	MsgN(string.format("        %d bone(s) manipulated.", touched))
end

concommand.Add("fo_dismember_report", function()
	local corpse = LocalPlayer():GetEyeTrace().Entity

	if (not IsValid(corpse) or not corpse:IsRagdoll()) then
		--- A clientside model is not solid; fall back to the nearest body.
		local best, bestDistance
		local origin = LocalPlayer():GetPos()

		for _, entity in ipairs(ents.FindByClass("prop_ragdoll")) do
			local distance = entity:GetPos():DistToSqr(origin)

			if (not bestDistance or distance < bestDistance) then
				best, bestDistance = entity, distance
			end
		end

		corpse = best
	end

	if (not IsValid(corpse)) then
		print("Look at a body, or stand near one.")

		return
	end

	MsgN(string.format("\n%s  %s", tostring(corpse), corpse:GetModel() or "?"))
	MsgN(string.format("  label '%s'  gone %d  headless %s",
		corpse:GetNWString("ixCorpseLabel", ""),
		corpse:GetNWInt("ixCorpseGone", 0),
		tostring(corpse:GetNWBool("ixCorpseHeadless", false))))

	local targets, seen = {corpse}, {[corpse] = true}

	local function Add(part, source)
		if (IsValid(part) and not seen[part]) then
			seen[part] = true
			targets[#targets + 1] = {entity = part, source = source}
		end
	end

	for _, child in ipairs(corpse:GetChildren()) do Add(child, "child") end

	if (ix.corpse and ix.corpse.Parts) then
		for _, part in ipairs(ix.corpse.Parts(corpse)) do Add(part, "part") end
	end

	for index, entry in ipairs(targets) do
		local entity = index == 1 and corpse or entry.entity
		local source = index == 1 and "body" or entry.source

		local effects = {}

		for name, value in pairs({
			BONEMERGE = EF_BONEMERGE,
			FASTCULL = EF_BONEMERGE_FASTCULL,
			PARENT_ANIMATES = EF_PARENT_ANIMATES,
			NODRAW = EF_NODRAW
		}) do
			if (value and entity:IsEffectActive(value)) then
				effects[#effects + 1] = name
			end
		end

		MsgN(string.format("\n  [%s] %-22s %s  %d bones  idx %d  nodraw %s  "
			.. "override %s", source, entity:GetClass() or "?",
			entity:GetModel() or "?", entity:GetBoneCount() or 0,
			entity:EntIndex(), tostring(entity:GetNoDraw()),
			entity.RenderOverride and "yes" or "no"))

		MsgN(string.format("       effects %s",
			#effects > 0 and table.concat(effects, " ") or "none"))

		--- `manipulate_bone` has nothing to read; it is the engine's carrier.
		if ((entity:GetBoneCount() or 0) > 0) then
			DumpManipulations(entity)
			DumpMatrices(entity)
		end
	end

	--- And the gibs, so a chunk of meat is not mistaken for a mesh.
	local origin = LocalPlayer():GetPos()

	MsgN("\n  Within 400 units:")

	for _, entity in ipairs(ents.GetAll()) do
		if (IsValid(entity) and entity ~= LocalPlayer()
		and not entity:IsPlayer() and not entity:IsWeapon()
		and entity:GetPos():DistToSqr(origin) < 400 * 400) then
			MsgN(string.format("    %-22s %-46s idx %-6d parent %s%s",
				entity:GetClass() or "?", entity:GetModel() or "?",
				entity:EntIndex(),
				IsValid(entity:GetParent())
					and tostring(entity:GetParent()) or "none",
				entity.ixBodyPart and "  [body part]" or ""))
		end
	end

	MsgN("")
end)
