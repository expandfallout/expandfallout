ITEM.name = "Chimera Enhanced Spore Suit"
ITEM.description = "A vault 22 jumpsuit enhanced with the Chimera FTO division's modified spore strain, intended to increase the physical mobility of the subject."
ITEM.model = "models/catmop/fallout/props/vaultjumpsuit_go.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/widowz/fallout/player/faction/chimeraco22.mdl"
ITEM.maleModel = "models/widowz/fallout/player/faction/chimeraco22.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 60
ITEM.speedBoost = 20
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 100

ITEM.faction = "CHIMERA"

ITEM.isPA = false
ITEM.noCore = false

ITEM.specialBonus = {
	intelligence = 2
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
