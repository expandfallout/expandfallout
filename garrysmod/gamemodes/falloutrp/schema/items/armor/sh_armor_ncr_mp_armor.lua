ITEM.name = "NCR MP Armor"
ITEM.description = "Armor worn by NCR Military Police officers."
ITEM.model = "models/thespireroleplay/items/clothes/group055.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill/fallout/player/female/armor/ncr_mp.mdl"
ITEM.maleModel = "models/catmop/fallout/player/male/armor/ncr_male_mp.mdl"

ITEM.skin = 0
ITEM.bodyGroups = {}

ITEM.resistance = 67
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "NCR"
ITEM.factionClass = "NCO - Shock"

ITEM.specialBonus = {
	endurance = 3
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
