--[[
	A person who is not a player.

	A VJ Base human on the schema's own animation model, dressed by the
	body-part recipes players and corpses are drawn with, holding a VJ
	weapon generated from one of the schema's weapon items. What it is -
	name, race, armour, guns, side - is a preset; see `libs/sh_npc.lua`.
]]

ENT.Base = "npc_vj_human_base"
ENT.Type = "ai"

ENT.PrintName = "Wastelander"
ENT.Author = "Fallout RP"
ENT.Category = "Fallout RP"

--- Made by spawners and `/npcspawn`, never the spawn menu: it needs a preset.
ENT.Spawnable = false
ENT.AdminSpawnable = false

--- Helix draws the name over it; see `cl_npc.lua`.
ENT.DrawEntityInfo = true
