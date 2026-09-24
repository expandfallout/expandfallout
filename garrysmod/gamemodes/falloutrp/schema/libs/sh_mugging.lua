--[[
	Mugging.

	Phoenix's, and it is the reason the zip tie exists: somebody restrained can
	be robbed. Their configs are the shape of it -

	    Mugging Time         seconds it takes
	    Mugging cooldown     before the MUGGER can do it again
	    Mugged cooldown      before the VICTIM can be done again
	    level - 10..50 Mug amount   how much comes out, by the victim's level
	    Mug PK Time          how long the mugger is marked for death afterwards

	- and all of them are in the dev terminal.

	THE MUGGER IS THE ONE WHO IS MARKED. That is the part people get backwards.
	Robbing somebody at knifepoint does not make THEM killable; it makes YOU
	killable, by them, for a while - and this schema already has the machinery
	for that in `ix.pk`. The victim is told so in as many words, in blue, and
	only to them: the whole point of a PK reason is that it is something you
	know and the person who robbed you does not know you know.

	CHARISMA LOWERS THE TAKE, which is this schema's own rule rather than
	Phoenix's - it is in the SPECIAL contract ("Charisma lowers mugging caps")
	and this is the only system that can honour it. Talking somebody down while
	they are going through your pockets is exactly what the attribute is for.
]]

ix.mugging = ix.mugging or {}

ix.config.Add("mugTime", 5,
	"Seconds it takes to mug somebody.", nil, {
	data = {min = 1, max = 60},
	category = "Mugging"
})

ix.config.Add("mugCooldown", 60,
	"Seconds before somebody can mug again.", nil, {
	data = {min = 0, max = 3000},
	category = "Mugging"
})

ix.config.Add("muggedCooldown", 60,
	"Seconds before somebody can be mugged again.", nil, {
	data = {min = 0, max = 3000},
	category = "Mugging"
})

ix.config.Add("mugPKTime", 30,
	"Seconds the MUGGER is marked for death after a mugging.", nil, {
	data = {min = 0, max = 3000},
	category = "Mugging"
})

--[[
	The bands, by the VICTIM's level, exactly as Phoenix name them.

	Their descriptions say "a player with level 10-19", so the number is what
	that person is worth rather than what the robber is owed - a level 50
	character is carrying a level 50 character's money.
]]
ix.mugging.bands = {
	{level = 50, key = "mugCaps50", default = 500},
	{level = 40, key = "mugCaps40", default = 400},
	{level = 30, key = "mugCaps30", default = 300},
	{level = 20, key = "mugCaps20", default = 200},
	{level = 0, key = "mugCaps10", default = 100}
}

for _, band in ipairs(ix.mugging.bands) do
	ix.config.Add(band.key, band.default, string.format(
		"Caps taken from somebody at level %d or above.", band.level), nil, {
		data = {min = 0, max = 100000},
		category = "Mugging"
	})
end

ix.config.Add("mugCharismaPercent", 2,
	"Percent less taken per point of the victim's Charisma.", nil, {
	data = {min = 0, max = 10},
	category = "Mugging"
})

--------------------------------------------------------------------------------
-- What a mugging is worth
--------------------------------------------------------------------------------

--[[
	How much would come out of this person, before the check against what they
	actually have.

	Shared, so the menu entry can say the number out loud on the client without
	asking the server - and so there is one answer rather than a client guess
	and a server total that disagree.
]]
function ix.mugging.Amount(character)
	if (not character) then return 0 end

	local level = character:GetLevel()
	local amount = 0

	for _, band in ipairs(ix.mugging.bands) do
		if (level >= band.level) then
			amount = ix.config.Get(band.key, band.default)

			break
		end
	end

	--[[
		Charisma comes off the top. Two percent a point by default, so a very
		charming character keeps a fifth of what a blunt one loses - noticeable
		without making Charisma the only attribute that matters to a robber.
	]]
	local charisma = ix.special.Get(character, "charisma")
	local reduction = charisma * (ix.config.Get("mugCharismaPercent", 2) / 100)

	return math.max(math.floor(amount * (1 - math.Clamp(reduction, 0, 0.9))), 0)
end

--------------------------------------------------------------------------------
-- The menu entry
--------------------------------------------------------------------------------

ix.interact.Add("mug", {
	name = "Mug",

	--- Between Check Caps and the cuff entries, where the rest of it lives.
	order = 23.5,

	canSee = function(target)
		if (not ix.restrain.Is(target)) then return false end

		return not ix.restrain.Is(LocalPlayer())
	end,

	OnCanRun = function(client, target)
		return ix.mugging.CanMug(client, target)
	end,

	OnRun = function(client, target)
		ix.mugging.Begin(client, target)
	end
})

if (CLIENT) then
	--[[
		The blue line, and only the victim ever sees it.

		A message of its own rather than a colour on `ixPKChat`, because the two
		say opposite things: that one is "you are in trouble", red, to everybody
		nearby; this is "you are owed", blue, to one person.

		The sentence is built HERE so the mugger is named by whatever name this
		player knows them by - `GetCharacterName` is the recognition hook and it
		only answers on the client.
	]]
	net.Receive("ixMugged", function()
		local mugger = net.ReadEntity()
		local taken = net.ReadUInt(32)

		local name = "somebody"

		if (IsValid(mugger)) then
			local character = mugger:GetCharacter()

			name = hook.Run("GetCharacterName", mugger)
				or (character and character:GetName())
				or mugger:Name()
		end

		chat.AddText(Color(90, 160, 255), "[PK] ", Color(150, 200, 255),
			string.format("You have a PK reason on %s for robbing you%s.",
				name, taken > 0
					and (" of " .. ix.points.FormatCaps(taken)) or ""))

		surface.PlaySound("phoenix/ui/nv/ui_popup_messagewindow.mp3")
	end)
end
