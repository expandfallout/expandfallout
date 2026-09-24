
-- Here is where you can define your own phrases to use with the language system. You can define phrases in different languages
-- by creating a file called sh_<language name>.lua (e.g sh_french.lua) in the languages/ folder.

-- You are encouraged to avoid using hardcoded strings when displaying any sort of text on the client. You should instead define
-- these phrases here, and use the L() function to return the text in the proper language. For example, L("serverWelcome") would
-- return a string with the text "Welcome to the server, <name>!" as defined below.

-- You can also use formatted strings in phrases. This will make the phrase require additional parameters to display correctly.
-- In the case of serverWelcome, it requires another string which should be the character's name. An example:
-- L("serverWelcome", "John Lua") would return a string with the text "Welcome to the server, John Lua!".

LANGUAGE = {
	--- Lockpicking. See `libs/sh_lockpick.lua`.
	lockpickNotLootable = "You are not looking at a lootable container.",

	--- Implants. The action bar while somebody is being operated on.
	implanting = "Implanting...",

	serverWelcome = "Welcome to the server, %s!",

	-- Character biography. These are the fault messages the creation screen
	-- shows when height, weight or age fall outside their range.
	height = "Height",
	weight = "Weight",
	age = "Age",

	heightRequired = "You need to enter your height.",
	weightRequired = "You need to enter your weight.",
	ageRequired = "You need to enter your age.",

	-- Developer terminal.
	devTerminalDenied = "That terminal is for administrators.",
	devTerminalNoItem = "No item is registered as '%s'.",
	devTerminalNoRoom = "There is no room in your inventory for the %s.",
	devTerminalGave = "Added %sx %s to your inventory.",
	heightRange = "Your height must be between %s and %s.",
	weightRange = "Your weight must be between %s and %s pounds.",
	ageTooYoung = "Your character must be at least %s years old.",
	ageTooOld = "Your character cannot be older than %s.",

	-- Options menu category for the Fallout UI settings.
	appearance = "Appearance",

	optFalloutTheme = "Pip-Boy Colour",
	optdFalloutTheme = "The colour the HUD and every menu are tinted with.",

	optFalloutHud = "HUD Style",
	optdFalloutHud = "New Vegas uses the bracketed plates with tick meters. Fallout 4 uses flat labelled bars.",

	optFalloutCompass = "Show Compass",
	optdFalloutCompass = "Draw the directional compass along the top of the screen.",

	optFalloutScanlines = "Menu Scanlines",
	optdFalloutScanlines = "Overlay faint horizontal lines on menus, like a CRT terminal.",

	-- Menu tabs.
	special = "SPECIAL",
	radio = "RADIO",
	perks = "PERKS",

	--[[
		The tab a `CreateMenuButtons` key gets its label from. Without this the
		tab reads as the raw key - "quality" in lower case beside SPECIAL and
		INVENTORY, which looks like something half-finished rather than a tab.
	]]
	quality = "QUALITY",

	--[[
		The faction shop tab. Helix's `L()` falls back to the key itself, so
		without this the button reads "shop" in lower case next to SPECIAL and
		INVENTORY.
	]]
	shop = "SHOP",

	-- S.P.E.C.I.A.L.
	strength = "Strength",
	perception = "Perception",
	endurance = "Endurance",
	charisma = "Charisma",
	intelligence = "Intelligence",
	agility = "Agility",
	luck = "Luck",

	-- Shown when character creation is rejected for unspent or overspent
	-- points. The argument is the difference: positive means points remain.
	specialPointsRemaining = "You must spend all of your SPECIAL points. %d remaining.",

	-- Armour. Every one of these is a reason ix.armor.Equip refused; the item
	-- base strips the leading "@" and passes the rest to NotifyLocalized.
	armorNoItem = "That item no longer exists.",
	armorNotArmor = "That is not a piece of armour.",
	armorBadSlot = "That armour has an invalid slot and cannot be worn.",
	armorAlreadyEquipped = "You are already wearing that.",
	armorNotEquipped = "You are not wearing that.",
	armorWrongRace = "Your kind cannot wear that.",
	armorCannotEquip = "You cannot wear that right now.",
	-- The argument is the name of the piece already in the way.
	armorSlotTaken = "You must remove your %s first.",

	-- Fusion cores and Power Armour.
	replaceCore = "Replace Core",
	armorNotPowered = "That is not powered armour.",
	armorCoreFull = "That suit's core is already full.",
	armorNoCore = "You have no fusion core.",
	armorCoreEmpty = "Your fusion core is dead. The suit is dead weight.",

	-- Stealth.
	armorStealthBroken = "Drawing that broke your stealth.",
	armorNoStealth = "Nothing you are wearing can cloak you.",
	-- A power armour helmet or plate without the suit it belongs to.
	armorNeedsPowerArmor = "You must be wearing power armour first.",
	armorNeedsTraining = "You do not know how to use power armour. Read a Power Armor Training Manual.",

	-- Armour test bots.
	dummyNoSlots = "No free player slots for a bot. Raise -maxplayers.",
	dummyNoSpot = "Look at where you want the bot to stand.",
	-- The argument is how many were removed.
	dummyCleared = "Removed %d test bots.",

	-- Hunger and thirst. Shown only when the TIER changes, not every tick.
	hungerTier = "You are now: %s",
	thirstTier = "You are now: %s",

	-- Levelling.
	levelNoPoints = "You have no points to spend.",
	levelAttributeMaxed = "That attribute is already at its maximum.",
	-- The argument is how many points the respec handed back.
	levelRespecDone = "Respec complete. You have %d points to spend.",

	-- Looting.
	lootNoRoom = "You have no room for that."
}
