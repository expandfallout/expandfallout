ITEM.name = "NCR First Recon Bandoleer Armor"
ITEM.description = "A light armor used by the NCOs of the First Recon unit."
ITEM.model = "models/catmop/fallout/props/1streconarmor_go.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/catmop/fallout/player/female/armor/1streconbandoleer.mdl"
ITEM.maleModel = "models/catmop/fallout/player/male/armor/1streconbandoleer.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 65
ITEM.speedBoost = 10
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 25

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "NCR"
ITEM.factionClass = "NCO - First Recon"

ITEM.specialBonus = {
	perception = 3,
	endurance = 1
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
