ITEM.name = "Vault Security Officer Armor"
ITEM.description = "A set of Vault Tec security armor, fitted with camo patterns worn by Officers of the Vaults."
ITEM.model = "models/fallout/apparel/vaultsecurity.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill/fallout/player/female/armor/vault_security.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/armor/vault_security.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.textureReplace = {
	["roadkill/fallout/player/male/armor/vault_security/outfitm"] = "galang/fallout/player/vaultcamo/vaultsecuritycamo",
	["roadkill/fallout/player/female/armor/vault_security/outfitf"] = "galang/fallout/player/vaultcamo/vaultsecuritycamof"
}

ITEM.resistance = 70
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "VT"

ITEM.specialBonus = {
	intelligence = 3
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
    beard = true,
    head = false
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end
