--[[
	Container and pickup sounds.

	Phoenix put an `openSound` and a `closeSound` on every container, chosen by
	hand from a list of 64 in their GECK's container editor
	(`nut.geck.containerSounds`). All 64 are the New Vegas originals and all 64
	are on this server already, in `af_content_pack_5` - so the sounds are
	theirs, and only the way one gets picked is different.

	PICKED FROM THE MODEL, NOT BY HAND. Choosing a sound per container is a
	fourth thing to set on every crate you place, and it has one obviously
	right answer nearly every time: a locker sounds like a locker. So the model
	decides, and an override exists for the times it guesses wrong.

	That the sets come in open/close pairs is what makes this work at all -
	every one of the 31 has both halves, so a set is a single choice rather
	than two.

	TAKING is separate and category-based, the way the games do it: a rifle,
	a stimpak and a handful of caps make three different noises. Phoenix
	already does exactly this for ammunition, in `items/base/sh_clip.lua`:

	    item.player:EmitSound("phoenix/ui/nv/itm_ammunition_up_0"
	        .. math.random(3) .. ".mp3", 110)

	so this follows that file's lead and extends it to the other categories.
]]

ix.loot = ix.loot or {}

local CONTAINERS = "roadkill/fallout/containers/drs_"

--[[
	One entry per set. `open` and `close` are lists because six of the sets
	ship with two variants, and picking between them is free variety on a
	sound a player hears several hundred times an hour.
]]
local function Set(name, open, close)
	return {name = name, open = open, close = close}
end

local function Pair(prefix)
	return {CONTAINERS .. prefix .. "_open.mp3"},
		{CONTAINERS .. prefix .. "_close.mp3"}
end

--[[
	TWO NAMING PATTERNS, because the pack has two.

	    cardboardbox_open_01     number after the action
	    locker_01_open           number before it

	Nothing distinguishes them but the filename, so both forms exist here and
	every set names the one it uses. Guessing one form for all of them silently
	produces paths that do not resolve, and a missing sound in GMod is not an
	error - it is silence.
]]
local function Suffixed(prefix, count)
	local open, close = {}, {}

	for index = 1, count do
		open[index] = string.format("%s%s_open_%02d.mp3", CONTAINERS, prefix, index)
		close[index] = string.format("%s%s_close_%02d.mp3", CONTAINERS, prefix, index)
	end

	return open, close
end

local function Numbered(prefix, count)
	local open, close = {}, {}

	for index = 1, count do
		open[index] = string.format("%s%s_%02d_open.mp3", CONTAINERS, prefix, index)
		close[index] = string.format("%s%s_%02d_close.mp3", CONTAINERS, prefix, index)
	end

	return open, close
end

ix.loot.soundSets = {
	ammobox = Set("Ammo box", Pair("ammobox")),
	automat = Set("Automat", Pair("automat")),
	burialmound = Set("Burial mound", Pair("burialmound")),
	cabinetfile = Set("Filing cabinet", Pair("cabinetfile")),
	cardboardbox = Set("Cardboard box", Suffixed("cardboardbox", 2)),
	cashregister = Set("Cash register", Pair("cashregister")),
	deskdrawer = Set("Desk drawer", Pair("deskdrawer")),
	deskschool = Set("School desk", Pair("deskschool")),
	dresser = Set("Dresser", Suffixed("dresser", 2)),
	dumpster = Set("Dumpster", Pair("dumpster")),
	firstaidkit = Set("First aid kit", Pair("firstaidkit")),
	footlocker = Set("Footlocker", Pair("footlocker")),
	footlockerenclave = Set("Enclave footlocker", Pair("footlockerenclave")),
	footlockermetal = Set("Metal footlocker", Pair("footlockermetal")),
	gorebag = Set("Gore bag", Pair("gorebag")),
	guncase = Set("Gun case", Pair("guncase")),
	locker = Set("Locker", Numbered("locker", 2)),
	locker_enclave = Set("Enclave locker", Pair("locker_enclave")),
	lowerbar = Set("Bar", Pair("lowerbar")),
	mailbox = Set("Mailbox", Pair("mailbox")),
	maildropbox = Set("Mail drop box", Pair("maildropbox")),
	metalbox = Set("Metal box", Numbered("metalbox", 1)),
	nukacolamachine = Set("Nuka-Cola machine", Pair("nukacolamachine")),
	refrigerator = Set("Refrigerator", Pair("refrigerator")),
	safe = Set("Safe", Pair("safe")),
	trader = Set("Trader", Pair("trader")),
	trashcan = Set("Trash can", Pair("trashcan")),
	violincase = Set("Violin case", Pair("violincase"))
}

--[[
	Model keyword -> set, in order, first match wins.

	ORDERED, not a hash: "footlocker" contains "locker", so the more specific
	name has to be tested first or every footlocker gets a locker's sound. A
	hash gives no order and would pick whichever `pairs` happened to reach.
]]
ix.loot.soundMatches = {
	{"footlocker", "footlocker"},
	{"nuka", "nukacolamachine"},
	{"vending", "nukacolamachine"},
	{"ammo", "ammobox"},
	{"locker", "locker"},
	{"safe", "safe"},
	{"fridge", "refrigerator"},
	{"refriger", "refrigerator"},
	{"freezer", "refrigerator"},
	{"dumpster", "dumpster"},
	{"trash", "trashcan"},
	{"bin", "trashcan"},
	{"mailbox", "mailbox"},
	{"mail", "maildropbox"},
	{"cabinet", "cabinetfile"},
	{"filing", "cabinetfile"},
	{"desk", "deskdrawer"},
	{"drawer", "dresser"},
	{"dresser", "dresser"},
	{"register", "cashregister"},
	{"cash", "cashregister"},
	{"till", "cashregister"},
	{"toolbox", "metalbox"},
	{"metal", "metalbox"},
	{"suitcase", "guncase"},
	{"case", "guncase"},
	{"medkit", "firstaidkit"},
	{"medical", "firstaidkit"},
	{"firstaid", "firstaidkit"},
	{"health", "firstaidkit"},
	{"corpse", "gorebag"},
	{"gore", "gorebag"},
	{"body", "gorebag"},
	{"grave", "burialmound"},
	{"mound", "burialmound"},
	{"dirt", "burialmound"},
	{"counter", "lowerbar"},
	{"bar", "lowerbar"}
}

--[[
	The set a container should use.

	An explicit choice wins; otherwise the model decides; otherwise a cardboard
	box, which is the most neutral rummaging noise of the 31 and the right
	answer for the wooden crate everything defaults to.
]]
function ix.loot.GetSoundSet(model, override)
	if (override and override ~= "" and ix.loot.soundSets[override]) then
		return ix.loot.soundSets[override], override
	end

	local path = string.lower(model or "")

	for _, match in ipairs(ix.loot.soundMatches) do
		if (string.find(path, match[1], 1, true)) then
			return ix.loot.soundSets[match[2]], match[2]
		end
	end

	return ix.loot.soundSets.cardboardbox, "cardboardbox"
end

--- One sound from a set, or nil when there is nothing to play.
function ix.loot.GetContainerSound(model, override, bClosing)
	local set = ix.loot.GetSoundSet(model, override)

	if (not set) then return end

	local list = bClosing and set.close or set.open

	return list[math.random(#list)]
end

--- The set names, sorted, for the configurer and the tool.
function ix.loot.GetSoundSetNames()
	local names = {}

	for key in pairs(ix.loot.soundSets) do
		names[#names + 1] = key
	end

	table.sort(names)

	return names
end

--------------------------------------------------------------------------------
-- Picking things up
--------------------------------------------------------------------------------

--[[
	Item category -> the noise it makes coming off a shelf.

	Matched against the item's `category` first and then its uniqueID, because
	a category is what an item declares about itself and a uniqueID is what it
	actually is - `ammo_10mm` is in "Ammunition" either way, but a schema is
	free to file it somewhere else and the prefix still says what it is.
]]
ix.loot.pickupMatches = {
	{"ammunition", "phoenix/ui/nv/itm_ammunition_up_0%d.mp3", 3},
	{"ammo", "phoenix/ui/nv/itm_ammunition_up_0%d.mp3", 3},
	{"caps", "phoenix/ui/nv/ui_items_bottlecaps_0%d.mp3", 4},
	{"currency", "phoenix/ui/nv/ui_items_bottlecaps_0%d.mp3", 4},
	{"grenade", "phoenix/ui/nv/ui_items_grenade_up.mp3", 1},
	{"explosive", "phoenix/ui/nv/ui_items_grenade_up.mp3", 1},
	{"melee", "phoenix/ui/nv/ui_items_melee_up.mp3", 1},
	{"heavy", "phoenix/ui/nv/ui_items_gunsbig_up.mp3", 1},
	{"weapon", "phoenix/ui/nv/ui_items_gunssmall_up.mp3", 1},
	{"gun", "phoenix/ui/nv/ui_items_gunssmall_up.mp3", 1},
	{"armor", "phoenix/ui/nv/ui_items_clothing_up_0%d.mp3", 3},
	{"armour", "phoenix/ui/nv/ui_items_clothing_up_0%d.mp3", 3},
	{"clothing", "phoenix/ui/nv/ui_items_clothing_up_0%d.mp3", 3},
	{"apparel", "phoenix/ui/nv/ui_items_clothing_up_0%d.mp3", 3},
	{"drink", "phoenix/ui/nv/itm_bottle_up_0%d.mp3", 2},
	{"bottle", "phoenix/ui/nv/itm_bottle_up_0%d.mp3", 2}
}

ix.loot.pickupDefault = {"phoenix/ui/nv/ui_items_generic_up_0%d.mp3", 4}

function ix.loot.GetPickupSound(uniqueID)
	local itemTable = ix.item.list[uniqueID]
	local haystack = string.lower((itemTable and itemTable.category or "")
		.. " " .. (uniqueID or ""))

	for _, match in ipairs(ix.loot.pickupMatches) do
		if (string.find(haystack, match[1], 1, true)) then
			return string.format(match[2], math.random(match[3]))
		end
	end

	return string.format(ix.loot.pickupDefault[1],
		math.random(ix.loot.pickupDefault[2]))
end

--[[
	A FRESH container makes a different sound from a picked-over one.

	Two different sounds, not one: opening something nobody has been through is
	a find, and opening one that has already been emptied is just a lid. The
	first version played the container's own open sound in both cases, which
	made every discovery sound like a re-check.

	THE FIND'S SOUND IS THE XP CHIME, and it is not emitted from here.

	This briefly had its own `lootFreshSound` config, played server-side
	alongside a muted XP award. That was wrong in a way worth writing down: the
	XP panel plays its note CLIENT-SIDE the instant the message arrives, while
	a server `EmitSound` has to travel - so the panel's chime always landed
	first and the configured sound arrived a beat later as a thud. Asked to
	remove "the second sound", I muted the panel, which silenced the chime and
	left the thud.

	One sound, played where Phoenix plays it, from the panel in
	`libs/cl_leveling.lua`. See `ix.loot.Open`, which awards the XP unmuted and
	falls through to the lid sound when there is no reward to give.
]]

--[[
	The Luck sound.

	NOT PHOENIX'S. Theirs is emitted server-side and glua-steal only ever
	captured client files, so there is no way to know which one they used -
	this is a choice, made from the same sound pack, and it is called out
	rather than presented as a port. `ui_score_boost_01` is the Fallout 76 cue
	for a bonus taking effect, which is what a Luck proc is.
]]
ix.loot.luckSound = "phoenix/ui/76/ui_score_boost_01.mp3"
