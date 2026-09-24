--[[
	NPCs on the client: their bodies, their names, and the spawners' marks.

	BODIES. An NPC's model is the schema's animation skeleton, a body with
	nothing on it; what a player sees is bone-merged onto it from a recipe
	the server composed - the same `BuildRecipe` a living player and a
	corpse are drawn with. The recipe arrives as a net var, so it is there
	for a client that connects after the NPC did.

	SPAWNERS are invisible pods. With the NPC Spawner tool out, staff see
	each one as a ring at its spawn radius and a line saying what it is
	set to and how it is doing.

	`ix.npc` is declared here too: `cl_` loads before `sh_`.
]]

if (not CLIENT) then return end

ix.npc = ix.npc or {}
ix.npc.presets = ix.npc.presets or {}

net.Receive("ixNPCPresets", function()
	ix.npc.presets = net.ReadTable() or {}

	hook.Run("NPCPresetsChanged")
end)

net.Receive("ixNPCEditor", function()
	if (IsValid(ix.gui.npcPresets)) then ix.gui.npcPresets:Remove() end

	ix.gui.npcPresets = vgui.Create("ixFONPCPresets")
end)

concommand.Add("fo_npcpresets", function()
	local client = LocalPlayer()

	if (not ix.admin or not ix.admin.Can(client, "npc.manage")) then return end

	if (IsValid(ix.gui.npcPresets)) then ix.gui.npcPresets:Remove() end

	ix.gui.npcPresets = vgui.Create("ixFONPCPresets")
end)

--------------------------------------------------------------------------------
-- Bodies
--------------------------------------------------------------------------------

-- [npc] = {parts}
local rendered = {}
-- [npc] = the recipe table it was built from
local built = {}

-- [npc] = {model = path, entity = the clientside model of its gun}
local guns = {}

local function ClearGun(npc)
	local gun = guns[npc]

	if (gun and IsValid(gun.entity)) then gun.entity:Remove() end

	guns[npc] = nil
end

local function Clear(npc)
	for _, part in ipairs(rendered[npc] or {}) do
		if (IsValid(part)) then part:Remove() end
	end

	rendered[npc] = nil
	built[npc] = nil

	ClearGun(npc)
end

timer.Create("ixNPCBodies", 0.5, 0, function()
	for npc in pairs(rendered) do
		if (not IsValid(npc)) then Clear(npc) end
	end

	for _, npc in ipairs(ents.FindByClass("npc_fo_human")) do
		if (npc:IsDormant()) then continue end

		local recipe = npc:GetNetVar("ixRecipe")

		if (not istable(recipe)) then continue end

		local ok = built[npc] == recipe and rendered[npc] ~= nil

		if (ok) then
			for _, part in ipairs(rendered[npc]) do
				if (not IsValid(part)) then ok = false break end
			end
		end

		if (not ok) then
			Clear(npc)

			rendered[npc] = ix.fallout.BuildRecipe(npc, recipe, false)
			built[npc] = recipe
		end

		--- The gun: a clientside model of the weapon, drawn in the hand below.
		local model = npc:GetNetVar("ixWeaponModel", "")
		local gun = guns[npc]

		if ((gun and gun.model or "") ~= model or (gun and not IsValid(gun.entity))) then
			ClearGun(npc)

			if (isstring(model) and model ~= "") then
				local entity = ClientsideModel(model, RENDERGROUP_OPAQUE)

				if (IsValid(entity)) then
					entity:SetNoDraw(true)
					guns[npc] = {model = model, entity = entity}
				end
			end
		end
	end
end)

--[[
	THE GUN, DRAWN BY HAND. The engine attaches an NPC's weapon to an
	`anim_attachment_RH` this skeleton does not have and bone-merges it
	against bones it does not share, and every way of drawing that entity
	put the gun in the ground or flickering at the hip. This is a plain
	clientside model of the weapon, placed at the `weapon` attachment the
	way a player's gun is (`ix.npc.HandPose`), every frame, nothing merged.
]]
hook.Add("PostDrawOpaqueRenderables", "ixNPCGuns", function(depth, skybox)
	if (skybox or not ix.npc.HandPose) then return end

	for npc, gun in pairs(guns) do
		if (not IsValid(npc) or not IsValid(gun.entity)) then continue end
		if (npc:IsDormant() or npc:GetNoDraw()) then continue end

		local pos, ang, scale = ix.npc.HandPose(npc)

		if (not pos) then continue end

		local entity = gun.entity

		entity:SetRenderOrigin(pos)
		entity:SetRenderAngles(ang)
		entity:SetModelScale(scale)
		entity:SetupBones()
		entity:DrawModel()
	end
end)

hook.Add("EntityRemoved", "ixNPCBodies", function(entity)
	if (rendered[entity]) then Clear(entity) end
	if (guns[entity]) then ClearGun(entity) end
end)

--------------------------------------------------------------------------------
-- Names
--------------------------------------------------------------------------------

hook.Add("PopulateEntityInfo", "ixNPC", function(entity, container)
	if (entity:GetClass() ~= "npc_fo_human") then return end

	local title = container:AddRow("name")

	title:SetImportant()
	title:SetText(entity:GetNetVar("ixNPCName", "Wastelander"))
	title:SizeToContents()

	local side = entity:GetNetVar("ixNPCSide", "hostile")
	local row = container:AddRow("npcside")

	row:SetText(ix.npc.SideName and ix.npc.SideName(side) or side)
	row:SizeToContents()
end)

--------------------------------------------------------------------------------
-- The spawners' marks
--------------------------------------------------------------------------------

local function ToolOut()
	local client = LocalPlayer()

	if (not IsValid(client)) then return false end

	local weapon = client:GetActiveWeapon()

	if (not IsValid(weapon) or weapon:GetClass() ~= "gmod_tool") then return false end

	return client:GetInfo("gmod_toolmode") == "fo_npcspawn"
end

local RING = Color(255, 150, 60, 255)
local RING_DIM = Color(255, 150, 60, 90)

hook.Add("PostDrawTranslucentRenderables", "ixNPCSpawners", function(depth, skybox)
	if (skybox or not ToolOut()) then return end

	for _, pod in ipairs(ents.FindByClass("ix_npcspawner")) do
		local pos = pod:GetPos()
		local radius = pod:GetNetVar("ixNPCSpawnerRadius", 128)

		render.SetColorMaterial()
		render.DrawWireframeSphere(pos + Vector(0, 0, 8), 12, 8, 8, RING, true)
		render.DrawLine(pos, pos + Vector(0, 0, 72), RING, true)

		--- The spawn radius, as a ring on the ground.
		local last

		for step = 0, 32 do
			local angle = step / 32 * math.pi * 2
			local point = pos + Vector(math.cos(angle) * radius, math.sin(angle) * radius, 6)

			if (last) then render.DrawLine(last, point, RING_DIM, true) end

			last = point
		end
	end
end)

hook.Add("HUDPaint", "ixNPCSpawners", function()
	if (not ToolOut()) then return end

	for _, pod in ipairs(ents.FindByClass("ix_npcspawner")) do
		local screen = (pod:GetPos() + Vector(0, 0, 80)):ToScreen()

		if (not screen.visible) then continue end

		draw.SimpleTextOutlined("NPC spawner #" .. tostring(pod:GetNetVar("ixNPCSpawner", "?")),
			"DermaDefaultBold", screen.x, screen.y, RING, TEXT_ALIGN_CENTER,
			TEXT_ALIGN_BOTTOM, 1, Color(0, 0, 0, 220))
		draw.SimpleTextOutlined(pod:GetNetVar("ixNPCSpawnerInfo", ""), "DermaDefault",
			screen.x, screen.y + 2, Color(255, 255, 255), TEXT_ALIGN_CENTER,
			TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 220))
	end
end)

--------------------------------------------------------------------------------
-- For looking at one from this side
--------------------------------------------------------------------------------

concommand.Add("fo_npc_client", function()
	local npc = LocalPlayer():GetEyeTrace().Entity

	if (not IsValid(npc) or npc:GetClass() ~= "npc_fo_human") then
		print("[falloutrp] look at one of the NPCs first")

		return
	end

	local weapon = npc:GetActiveWeapon()

	print(string.format("== %s  dormant %s  parts %d", npc:GetNetVar("ixNPCName", "?"),
		tostring(npc:IsDormant()), #(rendered[npc] or {})))
	print(string.format("  weapon %s  model %s  nodraw %s  owner %s  drawn by ours %s",
		IsValid(weapon) and weapon:GetClass() or "none",
		IsValid(weapon) and weapon:GetModel() or "-",
		IsValid(weapon) and tostring(weapon:GetNoDraw()) or "-",
		IsValid(weapon) and tostring(weapon:GetOwner()) or "-",
		IsValid(weapon) and tostring(weapon.ixNPCWeapon) or "-"))

	local id = npc:LookupAttachment("weapon")
	local attachment = (id and id > 0) and npc:GetAttachment(id) or nil

	print(string.format("  attachment 'weapon' %s  at %s", tostring(id),
		attachment and tostring(npc:WorldToLocal(attachment.Pos)) or "-"))
end)
