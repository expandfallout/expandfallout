ITEM.name = "NCR Dust Mask"
ITEM.description = "A dust mask worn by soldiers in the NCR."
ITEM.model = "models/catmop/fallout/props/damwarmask_go.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "mask"

ITEM.femaleModel = "models/catmop/fallout/player/male/headware/damwarmask.mdl"
ITEM.maleModel = "models/catmop/fallout/player/male/headware/damwarmask.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 0
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 20
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "NCR"

ITEM.specialBonus = {
	endurance = 1
}

ITEM.takesType = {
    hat = false,
    mask = true,
    eyes = true,
    helmet = false,
    body = false,
}

ITEM.takesBody = {
    hair = false,
    beard = true,
    head = false
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end
