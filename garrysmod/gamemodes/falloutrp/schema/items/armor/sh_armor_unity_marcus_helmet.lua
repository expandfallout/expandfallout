ITEM.name = "Unity Marcus Headset"
ITEM.description = "A headset worn by the 2ic of the Unity"
ITEM.model = "models/fallout/apparel/raiderarmorhelmet.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "eyes"

ITEM.femaleModel = "models/roadkill/fallout/player/supermutant/marcusheadset.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/supermutant/marcusheadset.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 50
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Unity"

ITEM.specialBonus = {
	perception = 2
}

ITEM.armorRace = {
    ["human"] = false,
    ["supermutant"] = true,
    ["nightkin"] = true,
    ["securitron"] = false
}

ITEM.takesType = {
    hat = true,
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
