--[[
	Armour.

	Fourteen slots, one item each, with damage resistance split between the
	head and the body. Ported from Phoenix's Armor V2 - the biggest system in
	their codebase - but the storage and the naming are ours, for reasons set
	out below.

	WHAT AN ARMOUR ITEM IS

	A worn armour is not a model swap on the player. The character is COMPOSED
	from bone-merged meshes on an animation-only skeleton (see
	`cl_bodyparts.lua`), so an armour is one more mesh in that list, plus a
	statement about which body parts it replaces. That is why a single armour
	works on every race and both genders without a model per combination.

	WHERE THE EQUIPPED STATE LIVES

	On the ITEM, as `item:SetData("equip", true)` - the same flag weapons use.
	Not on the character, which is what Phoenix did:

	    char:getData("equippedArmor:" .. slot)   -- a uniqueID string

	Two reasons. Their version stores a uniqueID, so it cannot tell two
	instances of the same armour apart and loses per-instance data - the
	fusion core charge of the specific suit you are wearing. And `equip` is
	already understood by the rest of this schema: `sv_death.lua` preserves it
	through death, so armour comes back on respawn with no extra code.

	WHY RENDER STATE IS NETWORKED SEPARATELY

	`character:SetData` is registered `isLocal = true` in Helix, so it reaches
	the owning client and nobody else - fine for authority, useless for
	drawing, since everyone needs to see what you are wearing. So the server
	derives a render set from the inventory and broadcasts it on the player
	entity. The item data stays authoritative; the networked copy is a
	consequence of it, never the source of truth.

	THE THREE NAMING CONVENTIONS, UNIFIED

	Phoenix expresses one concept three ways: `specialBonus` keys are
	`STR/PER/END/CHR/INT/AGL/LCK`, `attributes` are `Strength/Perception/...`,
	and the attribute registry keys off lowercase filenames. Two of those
	silently return nothing when read, which is why some of their armour
	bonuses do nothing at all.

	Here there is one convention - the lowercase attribute keys in
	`ix.special.order` - and the converter rewrites the short codes on the way
	in. `ix.armor.specialMap` is kept only to read their data, never to write.
]]

ix.armor = ix.armor or {}

--[[
	The fourteen slots, in the order they are presented.

	`f4_*` are the Fallout 4 style piecemeal pieces - a helmet and five limb
	plates worn OVER a body armour rather than instead of it.
]]
ix.armor.slots = {
	"hat", "mask", "eyes", "helmet",
	"body", "backpack", "bodyAccessory",
	"neck",
	"f4_helm", "f4_torso", "f4_larm", "f4_lleg", "f4_rarm", "f4_rleg"
}

ix.armor.slotNames = {
	hat = "Hat",
	mask = "Mask",
	eyes = "Eyes",
	helmet = "Helmet",
	body = "Body",
	backpack = "Backpack",
	bodyAccessory = "Body Accessory",
	neck = "Neck",
	f4_helm = "Helm Plate",
	f4_torso = "Torso Plate",
	f4_larm = "Left Arm Plate",
	f4_lleg = "Left Leg Plate",
	f4_rarm = "Right Arm Plate",
	f4_rleg = "Right Leg Plate"
}

--[[
	Which slots count toward which resistance pool. A hat protects your head
	and does nothing for a shot to the chest.
]]
ix.armor.headSlots = {
	hat = true, mask = true, eyes = true, helmet = true, f4_helm = true
}

ix.armor.bodySlots = {
	body = true, bodyAccessory = true, backpack = true,
	f4_torso = true, f4_larm = true, f4_lleg = true,
	f4_rarm = true, f4_rleg = true
}

ix.armor.isSlot = {}

for _, slot in ipairs(ix.armor.slots) do
	ix.armor.isSlot[slot] = true
end

--[[
	Read-only: their short codes to our attribute keys.

	The converter uses this once, on the way in. Nothing at runtime should
	need it - if it does, an armour was written with the wrong convention.
]]
ix.armor.specialMap = {
	STR = "strength",
	PER = "perception",
	END = "endurance",
	CHR = "charisma",
	INT = "intelligence",
	AGL = "agility",
	LCK = "luck"
}

--[[
	The ceiling on total resistance.

	Phoenix clamps the summed DR to 100, which is literal immunity - a full
	set of their heavier armour reaches it. Their own base item documents
	`ITEM.resistance` as "Max of 90", so the clamp and the contract disagree,
	and the clamp is the one that runs.

	Defaulted to 90 here, matching what the contract says, so a complete set
	is very strong without making damage stop existing. Raise it to 100 for
	their exact behaviour.
]]
ix.config.Add("armorMaxResistance", 90,
	"The highest total damage resistance armour can reach, as a percentage.",
	nil, {
	data = {min = 0, max = 100},
	category = "Armor"
})

--[[
	How long a slave collar runs before it stops, in seconds. Read by
	`sh_armor_misc_slavecollar.lua`, which is the only item with a timer.
]]
ix.config.Add("slaveCollarMaxTime", 300,
	"How long a slave collar stays active, in seconds.", nil, {
	data = {min = 30, max = 3600},
	category = "Armor"
})

--[[
	Drawing anything not on this list breaks stealth.

	Phoenix's list, by their uniqueIDs; ours differ, so it is keyed by both.
	Hands and keys are the two things you can hold without giving yourself
	away.
]]
ix.armor.validStealthWeapons = {
	ix_hands = true,
	ix_keys = true,
	nut_hands = true,
	nut_keys = true
}

--[[
	STEALTH: CAPABILITY AND STATE ARE DIFFERENT THINGS.

	Phoenix separate them, and the distinction is easy to lose in the port.
	Their stealth suits call `giveStealth` when equipped, which grants the
	ABILITY; actually going invisible is a separate toggle the player binds a
	key to. Equipping a courser suit does not make you vanish on the spot.

	So:
	    GiveStealth  - this armour can cloak. Recomputed by Refresh from what
	                   is worn, so taking the suit off withdraws it.
	    SetStealth   - you are cloaked right now.

	The visual is in `cl_bodyparts.lua` and is a material swap, not an alpha
	fade - `cpthazama/cloak` while moving, `phoenix/shared/invis` while still.
]]
--[[
	1 IS OFF AND 2 IS ON, AND NEITHER IS 0. This is not a style choice.

	This was `SetNW2Bool("ixStealth", bEnabled)` read back with a `false`
	fallback, and it is why a Stealth Boy left people permanently invisible
	through three attempted fixes. Writing an NW2 var with the SAME VALUE AS
	ITS DEFAULT does not network a change - it removes the var - and that
	removal does not reliably reach clients that already hold a value. So
	turning stealth ON networked fine, and turning it OFF changed the server
	and left every client still believing the field was up.

	Everything downstream then behaved perfectly on wrong input: the client
	kept painting the cloak material because its `ixStealth` still said true,
	and the server-side reconcile skipped the player because its own copy
	already said false. Both halves agreed with themselves and not with each
	other, which is exactly the failure no amount of reading one realm shows.

	An integer whose two real values are both non-default cannot hit that case:
	1 and 2 always network. 0 means "never set", which reads as off.
]]
local STEALTH_OFF, STEALTH_ON = 1, 2

function ix.armor.SetStealth(client, bEnabled)
	if (not IsValid(client)) then return end

	bEnabled = bEnabled and true or false

	client:SetNW2Int("ixStealthState", bEnabled and STEALTH_ON or STEALTH_OFF)

	--[[
		ENDING A CHEM'S FIELD EARLY SPENDS THE CHEM.

		Without this the Stealth Boy's buff keeps running after the field is
		broken - by drawing a weapon, by dying, by `/stealth` - and two things
		go wrong. The visible one is the HUD, which correctly shows STEALTH +1
		with thirty seconds left on a character who is plainly not cloaked,
		because the buff really is still there.

		The other is worse and was only ever a matter of time: `CanStealth`
		reads that buff, so a broken field would come BACK the next time
		anything called `ix.buff.Refresh` - `SyncStealth` would see a live
		buff and no cloak and switch it on again. Drawing a weapon would have
		un-cloaked you until you next took a chem or one wore off.

		`ixStealthFromBuff` is what makes this only apply to a chem's field. A
		suit's is not spent by being switched off, and it has no buff to clear.

		AFTER the var is written, not before: `ix.buff.Clear` runs a refresh,
		which re-enters `SyncStealth`, and that has to see the field already
		down or it would treat this as a cloak that needs turning on.
	]]
	if (SERVER and not bEnabled and client.ixStealthFromBuff) then
		client.ixStealthFromBuff = nil

		if (ix.buff) then
			ix.buff.Clear(client, "STEALTH")
		end
	end

	hook.Run("PlayerStealthChanged", client, bEnabled)
end

--[[
	The one place anything asks. Shared, so both realms read the same var the
	same way - the previous nine call sites each spelled out the NW2 read and
	its fallback, which is nine chances to get the fallback wrong.
]]
function ix.armor.IsStealthed(client)
	return IsValid(client)
		and client:GetNW2Int("ixStealthState", 0) == STEALTH_ON
end

--[[
	A STEALTH BOY CLOAKS YOU. A SUIT ONLY LETS YOU.

	This is what was missing, and it is why "stealth boys do not work": the
	Stealth Boy grants a `STEALTH` buff, `CanStealth` then answers true, and
	nothing anywhere turned stealth ON. The only route was the `toggleStealth`
	concommand, which has no default key - so unless the player had already
	bound it, using a Stealth Boy did nothing observable at all.

	A Stealth Boy in Fallout is not a permission slip, it is a device you
	switch on. A suit is the other thing: it lets you cloak when you choose,
	which is what the bind and `/stealth` are for.

	Called from `ix.buff.Refresh`, which runs after every add, remove and
	expiry - so the field comes up when the chem is used and drops when it runs
	out, without a second timer that could disagree with the buff's own.
]]
--[[
	Is the field a chem's doing?

	A Stealth Boy runs on its own clock and switches itself off; letting the
	player toggle on top of that gives two things driving one switch, and they
	disagree the moment the timings cross. Turning it off manually would also
	be free invisibility later - the buff is still running, so the next
	`ix.buff.Refresh` would put it straight back on, which is a way to spend
	one Stealth Boy on several cloaks.

	So while the chem is up, the chem decides. Both `/stealth` and the
	`toggleStealth` bind ask this first.
]]
function ix.armor.IsChemStealth(client)
	return ix.buff and IsValid(client) and ix.buff.Get(client, "STEALTH") > 0
end

function ix.armor.SyncStealth(client)
	if (not SERVER or not IsValid(client) or not ix.buff) then return end

	local buffed = ix.buff.Get(client, "STEALTH") > 0
	local cloaked = ix.armor.IsStealthed(client)

	if (buffed and not cloaked) then
		--[[
			Remembered so the drop knows this was the chem's doing. Somebody
			who cloaked with a suit and then took a Stealth Boy should not be
			uncloaked when the chem wears off - they were already hidden and
			nothing about their suit changed.
		]]
		client.ixStealthFromBuff = true
		ix.armor.SetStealth(client, true)

		return
	end

	if (not buffed and cloaked and client.ixStealthFromBuff) then
		client.ixStealthFromBuff = nil

		--[[
			Unless a suit is holding it up. Losing the chem does not have to
			mean losing the field, and `CanStealth` is the one function that
			knows whether anything else is providing it.
		]]
		if (not ix.armor.CanStealth(client:GetCharacter())) then
			ix.armor.SetStealth(client, false)
		end
	end
end

--[[
	Grant the ability. Called from a stealth armour's OnEquip.

	Deliberately does NOT enable stealth - see above. The flag it sets is
	recomputed from the equipped set on every Refresh, so this is really only
	the item announcing itself; the authoritative answer is
	`ix.armor.CanStealth`.
]]
function ix.armor.GiveStealth(client)
	if (not IsValid(client)) then return end

	client:SetNW2Bool("ixStealthCapable", true)
end

--[[
	Does anything currently worn provide stealth?

	Read from the items rather than a flag, so it cannot outlive the suit -
	dropping a courser suit while cloaked has to withdraw the ability, and a
	flag set at equip time would not know.
]]
function ix.armor.CanStealth(character)
	--[[
		A Stealth Boy grants it without a suit.

		The `STEALTH` buff is the one buff whose VALUE does not matter - it is
		a yes or no, and it is expressed as a buff purely so that it expires by
		itself. Writing it as a flag with a timer would be a second piece of
		timing machinery doing what this library already does.
	]]
	if (ix.buff) then
		local client = character and character:GetPlayer()

		if (IsValid(client) and ix.buff.Get(client, "STEALTH") > 0) then
			return true
		end
	end

	for _, item in pairs(ix.armor.GetEquipped(character)) do
		if (item.hasStealth or item.requestStealth) then return true end
	end

	return false
end

--[[
	Every equipped armour on a character, keyed by slot.

	Walks the inventory rather than reading a cached table, because the
	inventory is the only thing that cannot go stale - an item dropped,
	transferred or destroyed is gone from it immediately, while a cache would
	still name it.

	Callers that run per damage event should NOT use this; read the networked
	DR instead.
]]
function ix.armor.GetEquipped(character)
	local equipped = {}

	if (not character) then return equipped end

	local inventory = character:GetInventory()

	if (not inventory) then return equipped end

	for item in ix.inventory.Each(inventory) do
		if (item.isArmor and item:GetData("equip") and item.bodyType) then
			equipped[item.bodyType] = item
		end
	end

	return equipped
end

--[[
	Sum a numeric armour field across a set of slots.

	MODULATORS ARE ADDED HERE, which is what makes one indistinguishable from
	an armour that always had the stat: everything downstream - the networked
	DR, the rad pool, the damage path - reads these sums and needs to know
	nothing about them. See `sh_modulator.lua`.
]]
local function SumField(character, slots, field)
	local total = 0

	for slot, item in pairs(ix.armor.GetEquipped(character)) do
		if (slots[slot]) then
			local own = tonumber(item[field]) or 0
			local fitted = ix.modulator
				and ix.modulator.Field(item, field) or 0

			total = total + own + fitted
		end
	end

	return total
end

--[[
	The two resistance pools, computed from the inventory.

	These are authoritative and they are not cheap - the server recomputes
	them when equipment changes and networks the result, and the damage path
	reads the networked number. Nothing should call these once per bullet.
]]
function ix.armor.GetHeadDR(character)
	return math.Clamp(SumField(character, ix.armor.headSlots, "resistance"),
		0, ix.config.Get("armorMaxResistance", 90))
end

function ix.armor.GetBodyDR(character)
	return math.Clamp(SumField(character, ix.armor.bodySlots, "resistance"),
		0, ix.config.Get("armorMaxResistance", 90))
end

--[[
	Resistance for a plain SET - a table of `slot -> uniqueID`.

	`GetHeadDR` and friends read a character's inventory, which a test dummy
	does not have. This takes the same sums from item TABLES instead, so a
	dummy resists damage with exactly the numbers a player wearing the same
	pieces would, rather than a second implementation that can drift from it.
]]
function ix.armor.GetSetDR(set)
	local head, body = 0, 0

	for slot, uniqueID in pairs(set or {}) do
		local itemTable = ix.item.list[uniqueID]

		if (itemTable) then
			if (ix.armor.headSlots[slot]) then
				head = head + (itemTable.resistance or 0)
			elseif (ix.armor.bodySlots[slot]) then
				body = body + (itemTable.resistance or 0)
			end
		end
	end

	local cap = ix.config.Get("armorMaxResistance", 90)

	return math.Clamp(head, 0, cap), math.Clamp(body, 0, cap)
end

--[[
	A Power Armour suit that goes with a given helmet or plate.

	Needed because a PA helmet cannot be worn without its suit, so anything
	putting one on something - a test bot, a loadout - has to supply the suit
	too or the piece is simply refused.

	Matched on the shared leading part of the uniqueID, which is how the source
	names them: `armor_bos_t45_helmet` against `armor_bos_t45_armor`. The
	longest shared prefix wins, so a T-45 helmet prefers the T-45 suit over
	some other Brotherhood one, and any PA suit is better than none.
]]
function ix.armor.FindMatchingSuit(uniqueID)
	local best, bestScore

	for id, itemTable in pairs(ix.item.list) do
		if (not itemTable.isPA or itemTable.bodyType ~= "body") then continue end

		local score = 0

		while (score < #id and score < #uniqueID
		and string.sub(id, score + 1, score + 1) == string.sub(uniqueID, score + 1, score + 1)) do
			score = score + 1
		end

		if (not bestScore or score > bestScore) then
			best, bestScore = id, score
		end
	end

	return best
end

--[[
	The chems that work inside power armour.

	A sealed suit is the point of power armour, and a needle does not go
	through one. Phoenix gate the same way, with `nut.armor.paAllowedChems`,
	and what gets through is the same shape of thing: inhalers, and what the
	suit can feed you through its own systems.

	A WHITELIST rather than a blacklist, deliberately. A chem added later
	should not work in a suit until somebody has decided it does - a
	blacklist's failure is silent and in the player's favour, which is the
	wrong way round for a restriction.
]]
ix.armor.paAllowedChems = {
	aid_stimpak = true,
	aid_superstimpak = true,
	aid_stimpak_auto = true,
	aid_medx = true,
	aid_jet = true,
	aid_ultrajet = true,
	aid_turbo = true,
	aid_radx = true,
	aid_radaway = true,
	aid_fixer = true,
	aid_addictol = true,
	aid_stealthboy = true
}

--[[
	Radiation resistance is one pool - rads do not care where they land.

	Rad-X adds to the same pool, through the buff library, and the clamp is
	applied to the TOTAL rather than to each source. Clamping the armour first
	would silently discard a chem taken by somebody already in a good suit,
	which is exactly the moment they took it.
]]
function ix.armor.GetRadResistance(character)
	local slots = {neck = true}

	for slot in pairs(ix.armor.headSlots) do slots[slot] = true end
	for slot in pairs(ix.armor.bodySlots) do slots[slot] = true end

	local total = SumField(character, slots, "radResistance")

	if (ix.buff) then
		local client = character:GetPlayer()

		if (IsValid(client)) then
			total = total + ix.buff.Get(client, "RADRES")
		end
	end

	return math.Clamp(total, 0, 100)
end

--- Total fall damage reduction from worn armour.
function ix.armor.GetFallProtection(character)
	local slots = {neck = true}

	for slot in pairs(ix.armor.headSlots) do slots[slot] = true end
	for slot in pairs(ix.armor.bodySlots) do slots[slot] = true end

	return math.Clamp(SumField(character, slots, "fallProtection"), 0, 100)
end

--[[
	Movement modifiers from worn armour, summed across every slot.

	These are additive and frequently NEGATIVE - heavy plate costs you speed
	and jump height, which is most of what makes it a trade rather than a
	strict upgrade.

	Applied inside `ix.special.Apply`, not here. That function sets walk and
	run speed absolutely, so anything adding to speed elsewhere would be wiped
	the next time an attribute changed. One place decides how fast a player
	moves, and it reads this.
]]
function ix.armor.GetSpeedBoost(character)
	local slots = {neck = true}

	for slot in pairs(ix.armor.headSlots) do slots[slot] = true end
	for slot in pairs(ix.armor.bodySlots) do slots[slot] = true end

	return SumField(character, slots, "speedBoost")
end

function ix.armor.GetJumpBoost(character)
	local slots = {neck = true}

	for slot in pairs(ix.armor.headSlots) do slots[slot] = true end
	for slot in pairs(ix.armor.bodySlots) do slots[slot] = true end

	return SumField(character, slots, "jumpBoost")
end

--[[
	Height multiplier from worn armour.

	`ITEM.playerHeight` is a MULTIPLIER, not an offset - 35 of the 685 armours
	set it, all Power Armour, all at 1.1 or 1.2. It multiplies the race's own
	scale rather than replacing it, so a suit makes any race proportionally
	taller instead of making every race the same height.

	Multiple pieces multiply together, which in practice never happens: only
	body-slot suits declare it.
]]
function ix.armor.GetHeightMultiplier(character)
	local multiplier = 1

	for _, item in pairs(ix.armor.GetEquipped(character)) do
		if (isnumber(item.playerHeight) and item.playerHeight > 0) then
			multiplier = multiplier * item.playerHeight
		end
	end

	return multiplier
end

--[[
	The equipped Power Armour SUIT that needs a fusion core, if any.

	THE BODY SLOT ONLY. Power Armour helmets are also flagged `isPA` - that is
	what makes them seal against headshots - so searching every slot found the
	helmet as well and gave a player two independent cores to keep charged,
	one of which was a hat.

	The core belongs to the suit. `noCore` suits are excluded because nothing
	about them can run out.
]]
function ix.armor.GetPoweredArmor(character)
	local item = ix.armor.GetEquipped(character).body

	if (item and item.isPA and not item.noCore) then return item end
end

--[[
	Short codes for display, and for display only.

	`STR`/`PER`/`END`/... is how Phoenix label a SPECIAL modifier everywhere a
	player can see one - item descriptions and the top-left modifier list. The
	lowercase keys remain the only thing any code reads or writes; this is the
	last step before text hits the screen.
]]
ix.armor.specialCodes = {
	strength = "STR",
	perception = "PER",
	endurance = "END",
	charisma = "CHR",
	intelligence = "INT",
	agility = "AGL",
	luck = "LCK"
}

--- Total SPECIAL bonus from worn armour, keyed by the canonical attribute names.
function ix.armor.GetSpecialBonus(character)
	local bonus = {}

	for _, item in pairs(ix.armor.GetEquipped(character)) do
		for key, value in pairs(item.specialBonus or {}) do
			if (value ~= 0) then
				bonus[key] = (bonus[key] or 0) + value
			end
		end

		--[[
			AND WHATEVER IS FITTED TO IT.

			Per INSTANCE rather than per item type - `specialBonus` above is on
			the item table and is the same for every copy, while a modulator
			belongs to the one suit it was fitted to. See `sh_modulator.lua`.
		]]
		if (ix.modulator) then
			for key, value in pairs(ix.modulator.Special(item)) do
				bonus[key] = (bonus[key] or 0) + value
			end
		end
	end

	return bonus
end

--[[
	Is this character wearing Power Armour?

	Any equipped piece flagged `isPA` counts, which matches how the rest of
	the system reads it - the headshot and stamina exemptions are about being
	inside a suit, and the suit is the body piece.
]]
function ix.armor.IsWearingPA(character)
	for _, item in pairs(ix.armor.GetEquipped(character)) do
		if (item.isPA) then return true end
	end

	return false
end

--[[
	WHAT SHAPE A WEARER IS, and what shape an armour is cut for.

	Three kinds. A suit tailored for a person does not go onto a deathclaw and
	a securitron does not put on a duster - and until now nothing said so, so
	every armour in the schema fitted every one of the forty-four races.

	    human      people, and anything person-shaped enough to wear their
	               clothes: ghouls, the CIT generations, super mutants at a
	               push. THE DEFAULT for both armour and races, because
	               almost everything in the roster is one
	    robot      the chassis races. Bolted on rather than worn
	    creature   everything on four legs, or with a tail, or made of
	               radiation

	An armour says which it is with `ITEM.wearer`, or with `ITEM.isNonHuman`,
	which is the short way of saying "creature". A race says which it is here -
	races are generated files (`genraces.py`) and a field written into them by
	hand would be lost, which is the same reason karma's per-faction numbers
	live in the save rather than in the faction file.
]]
ix.armor.raceKinds = {
	eyebot = "robot",
	libertyprime = "robot",
	mistergutsy = "robot",
	protectron = "robot",
	robobrain = "robot",
	roboscorpion = "robot",
	securitron = "robot",
	securitronexecutive = "robot",
	sentrybot = "robot",

	behemoth = "creature",
	behemoth_unity = "creature",
	centaur = "creature",
	centaur_evolved = "creature",
	deathclaw = "creature",
	deathclaw_alpha = "creature",
	deathclaw_baby = "creature",
	deathclaw_matriarch = "creature",
	dog = "creature",
	feralghoul = "creature",
	feralghoul_armored = "creature",
	feralghoul_glowing = "creature",
	feralghoul_reaver = "creature",
	gecko = "creature",
	geckogreen = "creature",
	giantant = "creature",
	giantant_fire = "creature",
	legion_mongrel = "creature",
	radroach = "creature",
	radroach_glowing = "creature",
	radroach_nuka = "creature",
	radscorpion = "creature",
	radscorpion_baby = "creature",
	radscorpion_glowing = "creature",
	radscorpion_nuka = "creature",
	sporecarrier = "creature",
	zetan = "creature"
}

--[[
	Whether the rule is enforced at all.

	ON, and worth being able to turn off: it is a rule about a roster of 685
	armours that were written before it existed, and a server that finds it
	strands a race with nothing to wear should be able to switch it off rather
	than edit items.
]]
ix.config.Add("armorRaceKinds", true,
	"Whether armour cut for one kind of body refuses to go on another.", nil, {
	category = "Armor"
})

--- What kind of body a race has. Human unless it is listed above.
function ix.armor.RaceKind(race)
	return ix.armor.raceKinds[race] or "human"
end

--[[
	What kind of body an armour is cut for.

	`any` is honoured and is the escape hatch for the handful of things that
	genuinely go on anything - a collar, a pack strapped to a back.
]]
function ix.armor.WearerKind(itemTable)
	if (not itemTable) then return "human" end

	if (itemTable.wearer) then return itemTable.wearer end

	return itemTable.isNonHuman and "creature" or "human"
end

--[[
	May this race wear this armour?

	TWO QUESTIONS, and they are different. `armorRace` names the specific races
	an armour is for - a Legion helmet only for legionaries, say - and the KIND
	is about the shape of the body underneath. An armour may answer both.

	Absent `armorRace` means "anyone". Phoenix defaults the table to
	`{human = true}` with the rest false, so an armour that simply forgot to
	list a race excludes it - fine for their fixed roster, wrong here, where
	races are data and 42 of them are still to come. An unlisted race is
	allowed rather than silently barred.
]]
function ix.armor.CanRaceWear(itemTable, race)
	local races = itemTable and itemTable.armorRace

	--[[
		THE KIND IS ASKED FIRST, and an explicit `armorRace` entry OVERRIDES
		it: an armour that names a deathclaw is an armour somebody made for
		deathclaws, whatever kind it is otherwise cut for.
	]]
	if (race and ix.config.Get("armorRaceKinds", true)
	and not (istable(races) and races[race])) then
		local wanted = ix.armor.WearerKind(itemTable)

		if (wanted ~= "any" and wanted ~= ix.armor.RaceKind(race)) then
			return false
		end
	end

	if (not istable(races) or not race) then return true end

	local value = races[race]

	if (value == nil) then return true end

	return value and true or false
end

--[[
	MISSING CONTENT DOES NOT SHIP AN ERROR PROP.

	This schema defines 685 armours, drawn from 17 workshop content packs, and
	not all of those are installed - see `_docs/09-content-map.md`. An item
	whose `ITEM.model` is absent renders as the ERROR prop in the inventory and
	on the floor, which looks like a broken item rather than missing content.

	So the drop model is checked once at load and swapped for something that
	does exist. The armour still works: it equips, it resists damage, and the
	WORN model is checked separately in `cl_bodyparts.lua`, so installing the
	pack later brings both back with no edit here.

	The worn model is deliberately NOT substituted. A wrong drop model is a
	cosmetic placeholder; a wrong worn model would put the incorrect armour on
	the player, which is a lie about what they are protected by.
]]
local FALLBACK_MODELS = {
	"models/fallout/apparel/casualwear.mdl",
	"models/props_c17/suitcase_passenger_physics.mdl",
	"models/props_junk/cardboard_box004a.mdl"
}

ix.armor.missingModels = {}

hook.Add("InitializedSchema", "ixArmorModelFallback", function()
	local fallback

	for _, model in ipairs(FALLBACK_MODELS) do
		if (file.Exists(model, "GAME")) then
			fallback = model

			break
		end
	end

	ix.armor.missingModels = {}

	for uniqueID, itemTable in pairs(ix.item.list) do
		if (not itemTable.isArmor or not itemTable.model) then continue end

		if (not file.Exists(itemTable.model, "GAME")) then
			ix.armor.missingModels[uniqueID] = itemTable.model

			if (fallback) then
				itemTable.model = fallback
			end
		end
	end
end)

--[[
	What actually loaded, and what is missing.

	The content situation makes "is this armour broken or is its pack not
	installed?" the first question anyone will ask, and guessing at it from an
	inventory full of suitcases is not an answer.
]]
concommand.Add("fo_armor_report", function()
	local counts, total, worn = {}, 0, 0

	for _, itemTable in pairs(ix.item.list) do
		if (not itemTable.isArmor) then continue end

		total = total + 1
		counts[itemTable.bodyType or "?"] = (counts[itemTable.bodyType or "?"] or 0) + 1

		local model = itemTable.maleModel

		if (model and model ~= "" and file.Exists(model, "GAME")) then
			worn = worn + 1
		end
	end

	MsgC(Color(255, 200, 100), "[falloutrp] armour\n")
	MsgC(Color(200, 200, 200), string.format("  %d armour items registered\n", total))

	for _, slot in ipairs(ix.armor.slots) do
		if (counts[slot]) then
			MsgC(Color(170, 170, 170), string.format("      %-16s %d\n",
				ix.armor.slotNames[slot] or slot, counts[slot]))
		end
	end

	MsgC(Color(200, 200, 200), string.format(
		"  %d of %d have their worn model installed\n", worn, total))
	MsgC(Color(255, 160, 160), string.format(
		"  %d drop models missing, substituted at load\n",
		table.Count(ix.armor.missingModels)))

	--[[
		What is actually being applied to YOU, right now.

		Deliberately prints the NETWORKED resistance rather than recomputing
		it, because the networked value is the one the damage path reads. A
		disagreement between this and what you are wearing is precisely the bug
		worth finding, and recomputing here would hide it.
	]]
	local client = LocalPlayer()

	if (not IsValid(client) or not client:GetCharacter()) then return end

	MsgC(Color(255, 200, 100), "  worn right now\n")

	for _, slot in ipairs(ix.armor.slots) do
		local uniqueID = client:GetNW2String("ixArmor_" .. slot, "")

		if (uniqueID ~= "") then
			local itemTable = ix.item.list[uniqueID]

			MsgC(Color(170, 170, 170), string.format("      %-16s %s (DR %d)\n",
				ix.armor.slotNames[slot] or slot,
				itemTable and itemTable.name or uniqueID,
				itemTable and itemTable.resistance or 0))
		end
	end

	local head = client:GetNW2Int("ixHeadDR", 0)
	local body = client:GetNW2Int("ixBodyDR", 0)

	MsgC(Color(200, 200, 200), string.format(
		"      head DR %d%% - 100 damage becomes %.1f\n", head, 100 * (1 - head / 100)))
	MsgC(Color(200, 200, 200), string.format(
		"      body DR %d%% - 100 damage becomes %.1f\n", body, 100 * (1 - body / 100)))
	MsgC(Color(200, 200, 200), string.format(
		"      cap %d%%, power armour %s\n",
		ix.config.Get("armorMaxResistance", 90),
		client:GetNW2Bool("WearingPA", false)
			and "YES - head hits use the body pool" or "no"))
end)

--[[
	Which equipped slots would conflict with putting this item on.

	Two different things block a slot. `bodyType` is the slot the item
	occupies, so anything already there conflicts. `takesType` is the set of
	OTHER slots the item covers - a full helmet takes the hat and mask slots
	as well, so wearing one has to turn those out.

	Returns the items in the way, so the caller can say what to remove rather
	than only that it failed.
]]
function ix.armor.GetConflicts(character, itemTable)
	local conflicts = {}
	local taken = {[itemTable.bodyType] = true}

	for slot, wanted in pairs(itemTable.takesType or {}) do
		if (wanted) then taken[slot] = true end
	end

	for slot, item in pairs(ix.armor.GetEquipped(character)) do
		if (taken[slot]) then
			conflicts[#conflicts + 1] = item
		else
			--[[
				The other direction: something already worn may take the slot
				we want without occupying it. A helmet in the `helmet` slot
				that takes `hat` has to block a hat going on afterwards, or
				the order you equip in would decide whether the rule applies.
			]]
			for other, wanted in pairs(item.takesType or {}) do
				if (wanted and taken[other]) then
					conflicts[#conflicts + 1] = item

					break
				end
			end
		end
	end

	return conflicts
end
