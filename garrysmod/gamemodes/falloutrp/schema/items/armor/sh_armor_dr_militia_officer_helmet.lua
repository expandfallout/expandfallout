ITEM.name = "Militia Officer Combat Helmet"
ITEM.description = "A standardized ranger helmet used by the Militia. | Militia Officer Armor"
ITEM.model = "models/fallout/apparel/cowboyhat4.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "hat"

ITEM.femaleModel = "models/catmop/fallout/player/male/headware/advriothelmet.mdl"
ITEM.maleModel = "models/catmop/fallout/player/male/headware/advriothelmet.mdl"

ITEM.textureReplace = {
    ["galang/fallout/player/ranger/desert/deserthelmglow"] = "galang/fallout/player/roguerangers/roguerangerhelmet4blue",
}


ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 70
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 50
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Militia"

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
    beard = true,
    head = true
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end
