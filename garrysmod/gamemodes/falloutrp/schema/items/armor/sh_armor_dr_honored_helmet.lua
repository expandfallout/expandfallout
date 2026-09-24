ITEM.name = "Desert Ranger Honored Helmet"
ITEM.description = "The honored helmet of the Desert Rangers."
ITEM.model = "models/fallout/apparel/cowboyhat4.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "hat"

ITEM.femaleModel = "models/roadkill/fallout/player/male/nvdlc02/headgear/desert_ranger_combat_helmet.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/nvdlc02/headgear/desert_ranger_combat_helmet.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 73
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 60
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "DR"

ITEM.specialBonus = {}

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
