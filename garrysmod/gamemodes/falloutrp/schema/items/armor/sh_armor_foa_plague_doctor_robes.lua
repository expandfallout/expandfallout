ITEM.name = "FoA Plague Doctor Robes"
ITEM.description = "A set of plague doctor robes worn by the Followers of the Apocalypse. | Faction Lead"
ITEM.model = "models/catmop/fallout/props/plaguedoctorarmor_go.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/catmop/fallout/player/female/armor/plaguedoctorarmor.mdl"
ITEM.maleModel = "models/catmop/fallout/player/male/armor/plaguedoctorarmor.mdl"

ITEM.skin = 1
ITEM.bodyGroups = {}

ITEM.resistance = 75
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 50
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "FOA"

ITEM.specialBonus = {
	intelligence = 6
}

ITEM.takesType = {
    hat = false,
    mask = false,
    eyes = false,
    helmet = false,
    body = true,
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
