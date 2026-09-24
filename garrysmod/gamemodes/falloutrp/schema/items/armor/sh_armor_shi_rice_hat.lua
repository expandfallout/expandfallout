ITEM.name = "Shi Rice Hat"
ITEM.description = "A rice hat worn by the Shi."
ITEM.model = "models/fallout/apparel/cowboyhat4.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "hat"

ITEM.femaleModel = "models/catmop/fallout/player/male/headware/chinesemerchelmet.mdl"
ITEM.maleModel = "models/catmop/fallout/player/male/headware/chinesemerchelmet.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 65
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false
ITEM.hasStealth = true

ITEM.faction = "SHI"

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
    head = false
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    ix.armor.SetStealth(client, false)
    return true
end
