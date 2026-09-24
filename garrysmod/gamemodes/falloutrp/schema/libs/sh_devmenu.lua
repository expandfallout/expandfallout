--[[
	Every value the developer terminal may change.

	A CLOSED LIST. The key arrives from the client, so anything not named here
	cannot be written - which matters more for a config than for an action:
	`ix.config.Set` will happily write any key in the registry, including
	Helix's own, and the terminal is not a general config editor.

	SHARED, so that the window can be built from it. Knowing which dials exist
	is not a permission - the client already holds every config value, because
	Helix networks them - and the alternative was a list written out twice, one
	on each realm, which is a list that silently disagrees with itself: a row
	the terminal offers and the server then ignores looks exactly like a broken
	button. `sv_devmenu.lua` still does the enforcing.
]]

ix.devmenu = ix.devmenu or {}

ix.devmenu.configurable = {
	--[[
		LOCKPICKING, AMBUSHES AND RAIDS. Every dial the three fighting systems
		have, so the terminal is where a conflict is tuned rather than the
		config menu - see `sh_raid.lua`.
	]]
	implantMax = true,
	implantTime = true,
	implantRange = true,

	hungerDrainIdle = true,
	hungerDrainMoving = true,
	hungerDrainRunning = true,
	hungerTickRate = true,
	thirstDrainIdle = true,
	thirstDrainMoving = true,
	thirstDrainRunning = true,

	warMultiCap = true,
	warCapPlayers = true,

	lockpickXP = true,
	lockpickOpenTime = true,
	lockpickBreakChance = true,

	ambushDuration = true,
	ambushCooldown = true,
	ambushNoticeDelay = true,
	ambushMinRank = true,

	raidTime = true,
	raidCooldown = true,
	raidMinPlayers = true,
	hostilitiesTime = true,
	hostilitiesCooldown = true,
	hostilitiesMinPlayers = true,
	warTime = true,
	warCooldown = true,
	warMinPlayers = true,
	raidShieldDuration = true,
	raidShieldCooldown = true,
	raidShieldRank = true,
	warPointCapture = true,

	orbitalEnabled = true,
	orbitalInterval = true,
	orbitalBeaconTime = true,
	orbitalDespawn = true,
	orbitalMinPlayers = true,
	orbitalLootTable = true,
	orbitalAnnounce = true,
	pkDuration = true,
	pkMuggingDuration = true,
	pkLevelsAbove = true,
	pkLevelsBelow = true,
	pkCapsAbove = true,
	pkCapsBelow = true,
	pkNotifyRange = true,
	ziptieTime = true,
	ziptieReleaseTime = true,
	cuffTime = true,
	cuffReleaseTime = true,
	restraintTime = true,
	restraintStrength = true,
	restraintRegen = true,
	restraintRope = true,
	restraintGag = true,
	restraintBlind = true,
	restrainSearchTime = true,
	restrainSpeed = true,
	breachTime = true,
	breachDoorRestore = true,
	breachRadius = true,
	slaveCollarMaxTime = true,
	slaveCollarExplodeTime = true,
	slaveCollarDamage = true,
	slaveCollarDisarmIntelligence = true,
	slaveCollarDisarmTime = true,
	slaveLocateCooldown = true,
	slaveLocateTime = true,
	slaveProximity = true,
	backpackSmallWidth = true,
	backpackSmallHeight = true,
	backpackMediumWidth = true,
	backpackMediumHeight = true,
	backpackLargeWidth = true,
	backpackLargeHeight = true,
	marketTax = true,
	marketDayTax = true,
	marketSlots = true,
	marketMinPrice = true,
	marketMaxPrice = true,
	marketMaxDays = true,
	plantXP = true,
	mugTime = true,
	mugPKTime = true,
	mugCooldown = true,
	muggedCooldown = true,
	mugCaps10 = true,
	mugCaps20 = true,
	mugCaps30 = true,
	mugCaps40 = true,
	mugCaps50 = true,
	mugCharismaPercent = true,
	farmPersist = true,
	farmGrowTime = true,
	farmYield = true,
	farmXP = true,
	farmWaterMax = true,
	farmWaterRefill = true,
	farmWaterDrain = true,
	miningXP = true,
	miningKgPerHit = true,
	miningSoftMultiplier = true,
	miningSoftRadius = true,
	miningKgPerOre = true,
	miningOrePerDrop = true,
	miningRespawn = true,
	miningStrength = true,
	miningTool = true,
	stashWidth = true,
	stashHeight = true,
	stashOpenTime = true,
	tradeupAmount = true,
	tradeupMaxRarity = true,

	weaponBrandCost = true,

	thirdperson = true,

	injectorTransformTime = true,
	injectorDuration = true,
	injectorNeedsRestrained = true,

	karmaEnabled = true,
	karmaTimer = true,
	karmaNeedsRecognition = true,
	karmaNotify = true,
	karmaIconVeryGood = true,
	karmaIconGood = true,
	karmaIconBad = true,
	karmaIconVeryBad = true,

	armorRaceKinds = true,

	chatMax = true,
	maxCharacters = true
}
