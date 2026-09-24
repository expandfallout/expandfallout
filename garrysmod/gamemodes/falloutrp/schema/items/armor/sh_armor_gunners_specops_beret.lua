ITEM.name = "Gunners Spec-Ops Beret"
ITEM.description = "A set of spec-ops armor worn by the Gunners. | OFFICER"
ITEM.model = "models/catmop/fallout/props/vg_beret_go.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/widowz/fallout/player/faction/gunners/gunnersspecopsberet.mdl"
ITEM.maleModel = "models/widowz/fallout/player/faction/gunners/gunnersspecopsberet.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 70
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Gunners"
ITEM.factionClass = "OFFICER"

ITEM.specialBonus = {}

ITEM.takesType = {
    hat = true,
    mask = false,
    eyes = false,
    helmet = false,
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
