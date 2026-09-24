ITEM.name = "NCR First Recon Beret"
ITEM.description = "A beret worn by the New California Republic's First Recon unit."
ITEM.model = "models/fallout/apparel/red_beret.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "hat"

ITEM.femaleModel = "models/roadkill/fallout/player/male/headgear/red_beret.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/headgear/red_beret.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 67
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "NCR"
ITEM.factionClass = "NCO - First Recon"

ITEM.specialBonus = {
	perception = 2
}

ITEM.takesType = {
    hat = false,
    mask = false,
    eyes = false,
    helmet = true,
    body = false,
}

ITEM.takesBody = {
    hair = true,
    beard = false,
    head = false
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end
