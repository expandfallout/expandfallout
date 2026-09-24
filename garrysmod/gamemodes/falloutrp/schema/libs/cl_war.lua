--[[
	Wars, client side: the box staff see when one is declared.

	A declaration is not an announcement - see `sv_war.lua`. The only people
	told are the ones who can do something about it, and what they get is the
	reason and two buttons.
]]

ix.war = ix.war or {}

if (not CLIENT) then return end

--- What staff know about the queue, for the placer tool's panel.
ix.war.queue = ix.war.queue or {}

--- `[faction uniqueID] = true` for the ones that have ground. Not where it is.
ix.war.hasPoint = ix.war.hasPoint or {}

net.Receive("ixWarQueue", function()
	ix.war.queue = net.ReadTable()
	ix.war.hasPoint = net.ReadTable()
end)

--[[
	A declaration, in chat, with the two lines that answer it.

	NOT A WINDOW. A box over whatever staff are doing gets dismissed by
	whoever happened to be moving their mouse - and a war can wait. This says
	what was declared and what to type; `/warlist` finds it again later.
]]
net.Receive("ixWarDeclared", function()
	local attacker = ix.faction.indices[net.ReadUInt(8)]
	local defender = ix.faction.indices[net.ReadUInt(8)]
	local reason = net.ReadString()
	local who = net.ReadString()
	local bStarted = net.ReadBool()

	if (not attacker or not defender) then return end

	local colour = Color(255, 150, 0)

	chat.AddText(colour, "[WAR] ", color_white, string.format(
		bStarted and "%s's war on %s has STARTED."
			or "%s has declared war on %s.", attacker.name, defender.name))

	chat.AddText(Color(190, 190, 180),
		(bStarted and "Reason: " or ("Declared by " .. who .. ": ")),
		color_white, reason)

	--- Only the declaration needs answering; the started one is a record.
	if (not bStarted) then
		chat.AddText(colour, string.format(
			"/warreason %s approve   or   /warreason %s deny",
			attacker.uniqueID, attacker.uniqueID))
	end

	surface.PlaySound("phoenix/ui/76/ui_discover_region_01.mp3")
end)

--[[
	The markers the placer tool asks for.

	Drawn for fifteen seconds and then gone, because they are an answer to
	"where are they" rather than a permanent feature - a war point is meant to
	be invisible until there is a war.
]]
local markers, markerUntil = {}, 0

net.Receive("ixWarPoints", function()
	local count = net.ReadUInt(8)

	markers = {}

	for index = 1, count do
		markers[index] = {
			name = net.ReadString(),
			position = net.ReadVector()
		}
	end

	markerUntil = CurTime() + 15
end)

hook.Add("PostDrawTranslucentRenderables", "ixWarPoints", function()
	if (CurTime() > markerUntil) then return end

	local palette = ix.fallout.GetPalette()

	for _, marker in ipairs(markers) do
		render.DrawWireframeBox(marker.position, angle_zero,
			Vector(-200, -200, -8), Vector(200, 200, 192),
			palette.color_primary, true)
	end
end)

hook.Add("HUDPaint", "ixWarPoints", function()
	if (CurTime() > markerUntil) then return end

	local palette = ix.fallout.GetPalette()

	for _, marker in ipairs(markers) do
		local screen = (marker.position + Vector(0, 0, 96)):ToScreen()

		if (not screen.visible) then continue end

		draw.SimpleTextOutlined(marker.name, "ixLootRow", screen.x, screen.y,
			palette.color_primary, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1,
			color_black)
	end
end)
