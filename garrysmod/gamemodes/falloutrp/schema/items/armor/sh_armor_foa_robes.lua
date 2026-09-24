ITEM.name = "Followers Of the Apocalypse Robes"
ITEM.description = "A set of white robes worn by the highest amongst the Followers of the Apocalypse. | High Command"
ITEM.model = "models/fallout/apparel/bosscribe.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/catmop/fallout/player/female/armor/plaguedoctorarmor.mdl"
ITEM.maleModel = "models/catmop/fallout/player/male/armor/plaguedoctorarmor.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 70
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 40
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "FOA"

ITEM.textureReplace = {
    ["catmop/fallout/player/male/clothing/plaguedoctor/pdoutfit_f"] = "catmop/fallout/player/female/clothing/foarobe/outfit_f",
    ["catmop/fallout/player/male/clothing/plaguedoctor/pdoutfit"] = "catmop/fallout/player/male/clothing/foarobe/outfit_m",
    ["catmop/fallout/player/male/clothing/plaguedoctor/pdgloves"] = "catmop/fallout/player/male/clothing/plaguedoctor/pdgloveswhite"
}

ITEM.specialBonus = {
	intelligence = 5
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
