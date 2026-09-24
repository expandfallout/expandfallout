ITEM.name = "NCR First Recon Mantle Armor"
ITEM.description = "A light armor used by Officers of the New California Republic's First Recon unit."
ITEM.model = "models/catmop/fallout/props/1streconarmor_go.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/catmop/fallout/player/female/armor/1streconmantle.mdl"
ITEM.maleModel = "models/catmop/fallout/player/male/armor/1streconmantle.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 70
ITEM.speedBoost = 10
ITEM.jumpBoost = 0
ITEM.radResistance = 20
ITEM.fallProtection = 25

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "NCR"
ITEM.factionClass = "Officer - First Recon"

ITEM.specialBonus = {
	perception = 4,
	endurance = 2
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
