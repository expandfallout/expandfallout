--[[
	Karma, client side: the title under somebody's name.

	Phoenix draw it in `DrawCharInfo` and gate it on `doesRecognize`; this is
	the same line in Helix's equivalent hook, gated on the same question
	through the same accessor the rest of this schema uses.

	See `sh_karma.lua` for what the numbers mean.
]]

if (not CLIENT) then return end

ix.karma = ix.karma or {}

--- Every faction's total, as the server last sent it. See `ix.karma.Sync`.
net.Receive("ixKarmaFactions", function()
	local count = net.ReadUInt(8)
	local list = {}

	for _ = 1, count do
		local uniqueID = net.ReadString()

		list[uniqueID] = {net.ReadUInt(32), net.ReadUInt(32)}
	end

	ix.karma.factions = list

	if (IsValid(ix.gui.factionManage)) then
		ix.gui.factionManage:Rebuild()
	end
end)

--- What each faction hands out, for the developer terminal to draw.
net.Receive("ixKarmaSettings", function()
	local count = net.ReadUInt(8)
	local list = {}

	for _ = 1, count do
		local uniqueID = net.ReadString()

		list[uniqueID] = {
			passive = {net.ReadInt(16), net.ReadInt(16)},
			kill = {net.ReadInt(16), net.ReadInt(16)}
		}
	end

	ix.karma.settings = list

	if (IsValid(ix.gui.devMenu)) then
		ix.gui.devMenu:Populate()
	end
end)

--[[
	THE TITLE, UNDER THEIR NAME.

	`PopulateCharacterInfo` is Helix's hook for the panel that appears when you
	look at somebody, and it is a `hook.Add` on a `GM:` method that already
	exists - so this must NOT return anything, or the description row their own
	method adds never runs (gotcha 9). `cl_restrain.lua` says the same thing
	four lines above its own version of this.

	RECOGNITION IS ASKED THE WAY THE RECOGNITION PLUGIN ASKS IT -
	`character:DoesRecognize`, plus the `IsPlayerRecognized` hook that lets
	anything else override it.

	NOT `GetCharacterName`, which looks like the obvious way and is backwards:
	that hook returns a name only when somebody is NOT recognised ("Unknown"),
	and returns nil when they are, so testing it for truth hides the title from
	exactly the people who should see it.

	`DoesRecognize` is added by Helix's recognition plugin, so it is tested for
	rather than assumed - a server with that plugin off recognises everybody,
	which is what it means for recognition not to be in use.
]]
hook.Add("PopulateCharacterInfo", "ixKarma", function(client, character,
	container)
	if (not ix.config.Get("karmaEnabled", true)) then return end

	local good, bad = ix.karma.OfPlayer(client)

	--- Nothing earned is nothing to say. A blank title is not a title.
	if (good + bad <= 0) then return end

	if (ix.config.Get("karmaNeedsRecognition", true)
	and client ~= LocalPlayer()) then
		local ours = LocalPlayer():GetCharacter()
		local known = not ours or not ours.DoesRecognize
			or ours:DoesRecognize(character)
			or hook.Run("IsPlayerRecognized", client) == true

		if (not known) then return end
	end

	local title, level, colour = ix.karma.Describe(good, bad)
	local row = container:AddRow("karma")

	row:SetText(string.format("%s (Karma %d)", title, level))

	--[[
		THE TEXT IS COLOURED, not the background behind it.

		A background band the colour of somebody's alignment reads as a
		highlight rather than as information - and worse, it was the only
		coloured thing in the box, so a saint and a monster looked equally
		alarming. The TEXT carries the colour instead, which is how the rarity
		of a weapon and the name of a faction are already drawn, and the box
		stays a box.

		`SetTextColor` on an `ixTooltipRow` sticks because the row is a DLabel
		underneath; `SizeToContents` afterwards is what makes the row as wide
		as the title, which changes with the level.
	]]
	row:SetTextColor(colour)
	row:SetExpensiveShadow(1, color_black)
	row:SizeToContents()
end)
