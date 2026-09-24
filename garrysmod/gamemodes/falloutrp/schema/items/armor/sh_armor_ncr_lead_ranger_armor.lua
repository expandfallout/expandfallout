ITEM.name = "NCR Lead Combat Ranger Armor"
ITEM.description = "Armor worn by the leader of the NCR rangers, providing enhanced protection."
ITEM.model = "models/fallout/apparel/combatranger.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/galang/fallout/player/ranger/advancedriotgearf.mdl"
ITEM.maleModel = "models/galang/fallout/player/ranger/advancedriotgear.mdl"

ITEM.textureReplace = {
	["galang/fallout/player/ranger/riot/riotgearcoat"] = "galang/fallout/player/ranger/NCR/RiotGearCoatNCR",
	["galang/fallout/player/ranger/blackhorse/blackhorsecoat"] = "galang/fallout/player/ranger/vetranger/NCRCombatRanger",
	["galang/fallout/player/ranger/riot/riotgear"] = "galang/fallout/player/ranger/NCR/RiotGearNCR",
}

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 73
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "NCR"
ITEM.factionClass = "Lead - Rangers"

ITEM.specialBonus = {
	endurance = 4
}

ITEM.takesType = {
    hat = false,
    mask = false,
    eyes = false,
    helmet = false,
    body = false,
}

ITEM.takesBody = {
    hair = false,
    beard = false,
    head = false
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end
