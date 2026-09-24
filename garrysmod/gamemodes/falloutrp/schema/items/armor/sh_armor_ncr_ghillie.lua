ITEM.name = "NCR Ghillie"
ITEM.description = "A Ghillie attachment, worn by snipers and scouts of the New California Republic."
ITEM.model = "models/galang/fallout/player/accessories/capego.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "bodyAccessory"

ITEM.femaleModel = "models/galang/fallout/player/accessories/ghillie.mdl"
ITEM.maleModel = "models/galang/fallout/player/accessories/ghillie.mdl"

ITEM.skin = 3
ITEM.bodyGroups = {}

ITEM.resistance = 0
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "NCR"
ITEM.factionClass = "Officer - First Recon"

ITEM.specialBonus = {
	perception = 1,
	endurance = 1
}

ITEM.takesType = {
    hat = false,
    mask = true,
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
