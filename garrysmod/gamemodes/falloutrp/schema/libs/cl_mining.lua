--[[
	The soft spot, and the noise a swing makes.

	Phoenix draw their "G spot" as a yellow glow sprite from the mining content
	addon and play a concrete impact on every hit. The glow is the same material
	and the same idea; the sounds are not theirs, because theirs are Half-Life 2
	paths and this server has no HL2 content (gotcha 16).
]]

if (not CLIENT) then return end

ix.mining = ix.mining or {}
ix.mining.ores = ix.mining.ores or {}

net.Receive("ixMiningOres", function()
	local count = net.ReadUInt(8)
	local list = {}

	for _ = 1, count do
		list[#list + 1] = {
			id = net.ReadString(),
			name = net.ReadString(),
			item = net.ReadString(),
			strength = net.ReadFloat(),
			skin = net.ReadUInt(8),
			yield = net.ReadUInt(8),
			soft = net.ReadFloat(),
			colour = {net.ReadUInt(8), net.ReadUInt(8), net.ReadUInt(8)}
		}
	end

	ix.mining.ores = list

	--- The config window redraws itself if it happens to be open.
	if (IsValid(ix.gui.miningConfig)) then
		ix.gui.miningConfig:Refresh()
	end
end)

--[[
	A hit landed. Particles from the mining addon, and a sound that exists.

	`zrms_pickaxe_vfx` and `zrms_ore_vfx` are the addon's own particle files;
	the soft spot gets the ore burst as well, so a good hit looks different
	from a poor one without anybody having to read a number.
]]
net.Receive("ixMiningEffect", function()
	local node = net.ReadEntity()
	local position = net.ReadVector()
	local soft = net.ReadBool()

	ParticleEffect("pickaxe_hit01", position, Angle(0, 0, 0), nil)

	if (soft and IsValid(node)) then
		ParticleEffect("zrms_ore_mine", position, Angle(0, 0, 0), node)
	end

	sound.Play(soft and "phoenix/ui/nv/ui_items_bottlecaps_01.mp3"
		or "zrms/machine_crush.wav", position, 70,
		soft and 120 or math.random(90, 110), soft and 1 or 0.6)
end)

--- `/MiningConfig` asks the server, which asks back. See `cl_miningconfig.lua`.
net.Receive("ixMiningOpen", function()
	vgui.Create("ixFOMiningConfig")
end)

--------------------------------------------------------------------------------
-- The soft spot
--------------------------------------------------------------------------------

local GLOW = Material("zerochain/zrms/particles/zrms_glow")

--[[
	Drawn for every node near you, in its ore's colour, pulsing.

	NOT ONLY THE ONE YOU ARE LOOKING AT. The whole point of it is that you can
	see where to hit before you start swinging, and a spot that only appears
	once you are already aimed at the rock is a spot you have to hunt for
	twice.
]]
hook.Add("PostDrawTranslucentRenderables", "ixMining", function(depth, sky)
	if (depth or sky) then return end

	local client = LocalPlayer()

	if (not IsValid(client)) then return end

	local origin = client:GetPos()

	for _, node in ipairs(ents.FindByClass("ix_orenode")) do
		if (not IsValid(node)) then continue end
		if (origin:DistToSqr(node:GetPos()) > 640000) then continue end

		local spot = node:GetSoftSpot()

		if (spot:IsZero()) then continue end

		--[[
			ORANGE, not the ore's colour. Iron's was white on grey rock and
			could not be seen at all; the spot means one thing, so it is one
			colour. The ore's own colour is on its name over the node.
		]]
		local size = 14 + math.sin(CurTime() * 4) * 4

		render.SetMaterial(GLOW)
		render.DrawSprite(spot, size, size, ix.mining.softColour)
	end
end)
