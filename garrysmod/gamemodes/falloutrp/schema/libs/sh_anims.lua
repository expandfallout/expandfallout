
--[[
	New Vegas player animation set.

	Ported from the Phoenix schema's animation data, rewritten against Helix's
	ix.anim API. Only the DATA is carried over - these are sequence names baked
	into models/phoenix/humans/animations.mdl, so they describe the model we're
	using rather than anyone's code.

	Structure (the "advanced" format, flagged by useADV):

	    ix.anim.<class>[<holdType>][<ACT_*>] = {lowered, raised, ironsights}

	holdType comes from SWEP.NVHoldType on the weapon ("1hp", "2ha", "2hr",
	"2hh", "2hl", "2hmo"), falling back to the regular GMod hold type. The three
	entries are picked by weapon state, so a lowered rifle, a shouldered rifle
	and an aimed rifle are all distinct poses - which is exactly what stock
	HL2 animations can't express, and why third person looked wrong.

	Non-activity keys (sprint / jump / land / attack / hurt) are handled
	explicitly by Schema:TranslateActivity.
]]

ix.anim = ix.anim or {}

ix.anim.falloutHuman = {
	useADV = true,
	normal = {
		[ACT_MP_STAND_IDLE] = {"mtidle", "mtidle"},
		[ACT_MP_CROUCH_IDLE] = {"sneakmtidle", "sneakmtidle"},
		[ACT_MP_WALK] = {"mtwalk", "mtwalk"},
		[ACT_MP_CROUCHWALK] = {"sneakmtwalk", "sneakmtwalk"},
		[ACT_MP_RUN] = {"mtrun", "mtrun"},
		sprint = {"sprint_mt","sprint_mt"},
		jump = {"mtjumpstart", "mtjumpstart"},
		land = {"mtjumpland", "mtjumpland"}
	},
	--[[
		EVERY TREE CARRIES A JUMP. `fist` did not, and `ix_hands` is hold type
		"fist": jumping with the hands out found no entry, fell through to
		Helix's HL2MP translation, and this model answers an activity it does
		not have with sequence 0 - the reference pose. That was "the T-pose
		only when jumping with hands out". The four gun trees below had the
		same hole and were spared only because Longsword weapons carry an
		`NVHoldType` and index the New Vegas trees further down instead.

		Each is the jump the tree's own raised set uses; `TranslateActivity`
		borrows from `normal` for any key a tree still lacks. Names are
		checked against the file with `mdlseq.py` - there is no `h2h_walk`
		and no `*_jumpend` on this model, only `h2haim_walk` and `*_jumpland`.
	]]
	fist = {
		[ACT_MP_STAND_IDLE] = {"mtidle", "h2haim"},
		[ACT_MP_CROUCH_IDLE] = {"sneakmtidle", "sneakh2haim"},
		[ACT_MP_WALK] = {"mtwalk", "h2haim_walk"},
		[ACT_MP_CROUCHWALK] = {"sneakmtwalk", "h2haim_sneak"},
		[ACT_MP_RUN] = {"mtrun", "h2haim_run"},
		sprint = {"sprint_mt","sprint_mt"},
		attack = {"h2hattackleft_a", "h2hattackright_a"},
		jump = {"mtjumpstart", "h2haim_jumpstart"},
		land = {"mtjumpland", "h2haim_jumpland"}
	},
	pistol = {
		[ACT_MP_STAND_IDLE] = {"mtidle", "1hpaim","1hpaimis"},
		[ACT_MP_CROUCH_IDLE] = {"sneakmtidle", "sneak1hpaim", "sneak1hpaimis"},
		[ACT_MP_WALK] = {"mtwalk", "1hpaim_walk", "1hpaimis_walk"},
		[ACT_MP_CROUCHWALK] = {"sneakmtwalk", "1hpaim_sneak", "1hpaimis_sneak"},
		[ACT_MP_RUN] = {"mtwalk", "1hpaim_run", "1hpaim_run"},
		sprint = {"sprint_1h","sprint_1h","sprint_1h"},
		jump = {"mtjumpstart", "1hpaim_jumpstart", "1hpaimis_jumpstart"},
		land = {"mtjumpland", "1hpaim_jumpland", "1hpaimis_jumpland"}
	},
	shotgun = {
		[ACT_MP_STAND_IDLE] = {"2hapassive", "2hraim","2hraimis"},
		[ACT_MP_CROUCH_IDLE] = {"s2hasneak_passive", "sneak2hraim","sneak2hraimis"},
		[ACT_MP_WALK] = {"2hr_walk", "2hraim_walk", "2hraimis_walk"},
		[ACT_MP_CROUCHWALK] = {"2hraim_sneak", "2hraim_sneak","2hraimis_sneak"},
		[ACT_MP_RUN] = {"2hr_run", "2hr_run","2hraimis_run"},
		sprint = {"sprint_2hr","sprint_2hr","sprint_2hr"},
		jump = {"2hraim_jumpstart", "2hraim_jumpstart", "2hraimis_jumpstart"},
		land = {"2hraim_jumpland", "2hraim_jumpland", "2hraimis_jumpland"}
	},
	smg = {
		[ACT_MP_STAND_IDLE] = {"2hapassive", "2haaim","2haaimis"},
		[ACT_MP_CROUCH_IDLE] = {"sneak2haaim", "sneak2haaim","sneak2haaimis"},
		[ACT_MP_WALK] = {"2haaim_walk", "2haaim_walk", "2haaimis_walk"},
		[ACT_MP_CROUCHWALK] = {"2haaim_sneak", "2haaim_sneak","2haaimis_sneak"},
		[ACT_MP_RUN] = {"2haaim_run", "2haaim_run","2haaimis_run"},
		sprint = {"sprint_2ha","sprint_2ha","sprint_2ha"},
		jump = {"2haaim_jumpstart", "2haaim_jumpstart", "2haaimis_jumpstart"},
		land = {"2haaim_jumpland", "2haaim_jumpland", "2haaimis_jumpland"}
	},
	ar2 = {
		[ACT_MP_STAND_IDLE] = {"2hrpassive", "2hraim","2hraimis"},
		[ACT_MP_CROUCH_IDLE] = {"s2hasneak_passive", "2hraim_sneak","2hraimis_sneak"},
		[ACT_MP_WALK] = {"2hraim_walk", "2hr_walk", "2hraimis_walk"},
		[ACT_MP_CROUCHWALK] = {"2hraim_sneak", "2hraim_sneak","2hraimis_sneak"},
		[ACT_MP_RUN] = {"2hr_run", "2hr_run","2hraimis_run"},
		sprint = {"sprint_2hr","sprint_2hr","sprint_2hr"},
		jump = {"2hraim_jumpstart", "2hraim_jumpstart", "2hraimis_jumpstart"},
		land = {"2hraim_jumpland", "2hraim_jumpland", "2hraimis_jumpland"}
	},
	["hurt"] = {
		[ACT_MP_STAND_IDLE] = "hurt_mtidle",
		["hurtPA"] = "hurt_pamtidle",
		[ACT_MP_CROUCH_IDLE] = "sneakmtidle",
		[ACT_MP_WALK] = "hurt_mtforward",
		[ACT_MP_CROUCHWALK] = "sneakmtwalk",
		[ACT_MP_RUN] = "hurt_mtfastforward",
		[ACT_MP_SWIM] = "swimm",
	},
	["h2h"] = {
		[ACT_MP_STAND_IDLE] = {"mtidle", "h2haim"},
		[ACT_MP_CROUCH_IDLE] = {"sneakmtidle", "sneakh2haim"},
		[ACT_MP_WALK] = {"mtwalk", "h2haim_walk"},
		[ACT_MP_CROUCHWALK] = {"sneakmtwalk", "h2haim_sneak"},
		[ACT_MP_RUN] = {"mtrun", "h2haim_run"},
		[ACT_MP_SWIM] = {"swimm"},
		sprint = {"sprint_mt","sprint_mt"},
		attack = {"h2hattackleft_a", "h2hattackright_a"},
		attack2 = {"h2hmblockidle", "h2hmblockidle"},
		jump = {"mtjumpstart", "h2haim_jumpstart"},
		land = {"mtjumpland", "h2haim_jumpland"},
		pa = "pamtidle_notdumb",
	},
	["1hp"] = {
		[ACT_MP_STAND_IDLE] = {"mtidle", "1hpaim","1hpaimis"},
		[ACT_MP_CROUCH_IDLE] = {"sneakmtidle", "sneak1hpaim", "sneak1hpaimis"},
		[ACT_MP_WALK] = {"mtwalk", "1hpaim_walk", "1hpaimis_walk"},
		[ACT_MP_CROUCHWALK] = {"sneakmtwalk", "1hpaim_sneak", "1hpaimis_sneak"},
		[ACT_MP_RUN] = {"mtrun", "1hpaim_run", "1hpaimis_run"},
		[ACT_MP_SWIM] = {"swimm"},
		sprint = {"sprint_1h","sprint_1h","sprint_1h"},
		jump = {"1hpaim_jumpstart", "1hpaimis_jumpstart"},
		land = {"1hpaim_jumpland", "1hpaim_jumpland"}
	},
	["2ha"] = {
		[ACT_MP_STAND_IDLE] = {"2hapassive", "2haaim","2haaimis"},
		[ACT_MP_CROUCH_IDLE] = {"s2hasneak_passive", "sneak2haaim","sneak2haaimis"},
		[ACT_MP_WALK] = {"2haforward_p", "2haaim_walk", "2haaimis_walk"},
		[ACT_MP_CROUCHWALK] = {"2haaim_sneak", "2haaim_sneak","2haaimis_sneak"},
		[ACT_MP_RUN] = {"2hafastforward_p", "2haaim_run","2haaimis_run"},
		[ACT_MP_SWIM] = {"swimm"},
		sprint = {"sprint_2ha","sprint_2ha","sprint_2ha"},
		jump = {"2haaim_jumpstart", "2haaimis_jumpstart"},
		land = {"2haaim_jumpland", "2haaimis_jumpland"}
	},
	["2hr"] = {
		[ACT_MP_STAND_IDLE] = {"2hraim_passive2", "2hraim","2hraimis"},
		[ACT_MP_CROUCH_IDLE] = {"s2hasneak_passive", "sneak2hraim","sneak2hraimis"},
		[ACT_MP_WALK] = {"2hraim_walk_passive3", "2hraim_walk", "2hraimis_walk"},
		[ACT_MP_CROUCHWALK] = {"2hraim_sneak", "2hraim_sneak","2hraimis_sneak"},
		[ACT_MP_RUN] = {"2hrrun_passive1", "2hrrun","2hraimis_run"},
		[ACT_MP_SWIM] = {"swimm"},
		sprint = {"sprint_2hr","sprint_2hr","sprint_2hr"},
		jump = {"2hraim_jumpstart", "2hraimis_jumpstart"},
		land = {"2hraim_jumpland", "2hraimis_jumpland"}
	},
	["2hh"] = {
		[ACT_MP_STAND_IDLE] = {"2hraim_passive2", "2hhaim","2hhaim"},
		[ACT_MP_CROUCH_IDLE] = {"2hraim_walk_passive3", "sneak2hhaim","sneak2hhaim"},
		[ACT_MP_WALK] = {"2hraim_walk_passive3", "2hhaim_walk", "2hhaim_walk"},
		[ACT_MP_CROUCHWALK] = {"2hhaim_sneak", "2hhaim_sneak","2hhaim_sneak"},
		[ACT_MP_RUN] = {"2hrrun_passive1", "2hhaim_run","2hhaim_run"},
		[ACT_MP_SWIM] = {"swimm"},
		sprint = {"sprint_2hh","sprint_2hh","sprint_2hh"},
		jump = {"2hhaim_jumpstart", "2hhaimis_jumpstart"},
		land = {"2hhaim_jumpland", "2hhaim_jumpland"}
	},
	["2hl"] = {
		[ACT_MP_STAND_IDLE] = {"2hlaim", "2hlaim","2hlaim"},
		[ACT_MP_CROUCH_IDLE] = {"sneak2hlaim", "sneak2hlaim","sneak2hlaim"},
		[ACT_MP_WALK] = {"2hlaim_walk", "2hlaim_walk", "2hlaim_walk"},
		[ACT_MP_CROUCHWALK] = {"2hlaim_sneak", "2hlaim_sneak","2hlaim_sneak"},
		[ACT_MP_RUN] = {"2hlaim_run", "2hlaim_run","2hlaim_run"},
		[ACT_MP_SWIM] = {"swimm"},
		sprint = {"sprint_2hl","sprint_2hl","sprint_2hl"},
		jump = {"2hlaim_jumpstart", "2hlaimis_jumpstart"},
		land = {"2hlaim_jumpland", "2hlaim_jumpland"}
	},
	["2hm"] = {
		[ACT_MP_STAND_IDLE] = {"2hmaim", "2hmaim","2hmaim"},
		[ACT_MP_CROUCH_IDLE] = {"sneak2hmaim", "sneak2hmaim","sneak2hmaim"},
		[ACT_MP_WALK] = {"2hmaim_walk", "2hmaim_walk", "2hmaim_walk"},
		[ACT_MP_CROUCHWALK] = {"2hmaim_sneak", "2hmaim_sneak","2hmaim_sneak"},
		[ACT_MP_RUN] = {"2hmaim_run", "2hmaim_run","2hmaim_run"},
		[ACT_HL2MP_FIST_BLOCK] = {"2hmrecoil", "2hmrecoil","2hmrecoil"},
		[ACT_LAND] = {"2hmaim_jumpland", "2hmaim_jumpland"},
		[ACT_MP_SWIM] = {"swimm"},
		sprint = {"sprint_2hm","sprint_2hm","sprint_2hm"},
		jump = {"2hmaim_jumpstart", "2hmaimis_jumpstart"},
		land = {"2hmaim_jumpland", "2hmaim_jumpland"},
		attack = {"2hmattackleft_a", "2hmattackright_a"},
		attack2 = {"2hmblockidle", "2hmblockidle"}
	},
	["2hmo"] = {
		[ACT_MP_STAND_IDLE] = {"2hmaim", "twohandidle","twohandidle"},
		[ACT_MP_CROUCH_IDLE] = {"twohand_sneakwalk", "twohand_sneakwalk","twohand_sneakwalk"},
		[ACT_MP_WALK] = {"2hmaim_walk", "twohand_walk", "twohand_walk"},
		[ACT_MP_CROUCHWALK] = {"twohand_sneakwalk", "twohand_sneakwalk","twohand_sneakwalk"},
		[ACT_MP_RUN] = {"2hmaim_run", "twohand_run","twohand_run"},
		[ACT_HL2MP_FIST_BLOCK] = {"2hmrecoil", "2hmrecoil","2hmrecoil"},
		[ACT_LAND] = {"twohand_run", "twohand_run"},
		[ACT_MP_SWIM] = {"swimm"},
		sprint = {"sprint_2hm","sprint_2hm","sprint_2hm"},
		jump = {"twohandjumpstart", "twohandjumpstart"},
		land = {"twohandjumpland", "twohandjumpland"},
		attack = {"twohandattackleft", "twohandattackright"},
		attack2 = {"h2hblockidle", "h2hblockidle"}
	},
	["1hm"] = {
		[ACT_MP_STAND_IDLE] = {"mtidle", "1hmaim","1hmaim"},
		[ACT_MP_CROUCH_IDLE] = {"sneakmtidle", "sneak1hmaim", "sneak1hmaim"},
		[ACT_MP_WALK] = {"mtwalk", "1hmwalk", "1hmwalk"},
		[ACT_MP_CROUCHWALK] = {"sneakmtwalk", "sneakmtwalk", "sneakmtwalk"},
		[ACT_MP_RUN] = {"mtrun", "1hmrun", "1hmrun"},
		[ACT_HL2MP_FIST_BLOCK] = {"1hmrecoil", "1hmrecoil","1hmrecoil"},
		[ACT_LAND] = {"1hmaim_jumpland", "1hmaim_jumpland"},
		[ACT_MP_SWIM] = {"swimm"},
		sprint = {"sprint_1hm","sprint_1hm","sprint_1hm"},
		attack = {"1hmattackleft_a", "1hmattackright_a"},
		attack2 = {"1hmblockidle", "1hmblockidle"},
		jump = {"1hmaim_jumpstart", "1hmaimis_jumpstart"},
		land = {"1hmaim_jumpland", "1hmaimis_jumpland"}
	},
	["1gt"] = {
		[ACT_MP_STAND_IDLE] = {"mtidle", "1gtaim","1gtaim"},
		[ACT_MP_CROUCH_IDLE] = {"sneakmtidle", "sneak1gtaim", "sneak1gtaim"},
		[ACT_MP_WALK] = {"mtwalk", "1gtaim_walk", "1gtaim_walk"},
		[ACT_MP_CROUCHWALK] = {"sneakmtwalk", "1gtaim_sneak", "1gtaim_sneak"},
		[ACT_MP_RUN] = {"mtrun", "1gtaim_run", "1gtaim_run"},
		[ACT_LAND] = {"1gtaim_jumpland", "1gtaim_jumpland"},
		[ACT_MP_SWIM] = {"swimm"},
		sprint = {"1gtaim_run","1gtaim_run","1gtaim_run"},
		jump = {"1gtaim_jumpstart", "1gtaim_jumpstart"},
		land = {"1gtaim_jumpland", "1gtaim_jumpland"}
	},
	--[[
		SEATED. Keyed by the seat's class, which is how Helix reads it: a
		player in a vehicle gets `vehicle[class]` = {sequence, fix offset},
		and anything else is the crouch idle - a driver standing up through
		the roof of the buggy. LVS seats are prisoner pods, so that is the
		one that matters; the jeep and the airboat are Sandbox's, and
		"chair" is whatever Helix calls a chair.
	]]
	vehicle = {
		["prop_vehicle_prisoner_pod"] = {"sit", false},
		["prop_vehicle_jeep"] = {"drive_jeep", false},
		["prop_vehicle_airboat"] = {"sit", false},
		["chair"] = {"sit", false}
	}
}

ix.anim.f4pa = {
	useADV = true,
	normal = {
		[ACT_MP_STAND_IDLE] = {"1hm.idlerelaxed", "h2h.idleready"},
		[ACT_MP_CROUCH_IDLE] = {"1hm.sneakidle", "1hm.sneakidlec"},
		[ACT_MP_WALK] = {"mt.walk", "h2h.walkready"},
		[ACT_MP_CROUCHWALK] = {"1hm.sneakwalk", "1hm.sneakwalk"},
		[ACT_MP_RUN] = {"mt.run", "h2h.run"},
		sprint = {"h2h.sprint","h2h.sprint"},
		attack = {"h2h.attackstandinga", "h2h.attackstandingb"},
		attack2 = {"h2h.block", "h2h.block"},
		jump = {"h2h.jump", "h2h.jump"},
		chadLand = {"h2h.jumpimpactland", "h2h.jumpimpactland"},
		land = {"h2h.jumpinplaceland", "h2h.jumpinplaceland"}
	},
	passive = {
		[ACT_MP_STAND_IDLE] = {"1hm.idlerelaxed", "h2h.idleready"},
		[ACT_MP_CROUCH_IDLE] = {"1hm.sneakidle", "1hm.sneakidlec"},
		[ACT_MP_WALK] = {"mt.walk", "h2h.walkready"},
		[ACT_MP_CROUCHWALK] = {"1hm.sneakwalk", "1hm.sneakwalk"},
		[ACT_MP_RUN] = {"mt.run", "h2h.run"},
		sprint = {"h2h.sprint","h2h.sprint"},
		attack = {"h2h.attackstandinga", "h2h.attackstandingb"},
		attack2 = {"h2h.block", "h2h.block"},
		jump = {"h2h.jump", "h2h.jump"},
		chadLand = {"h2h.jumpimpactland", "h2h.jumpimpactland"},
		land = {"h2h.jumpinplaceland", "h2h.jumpinplaceland"}
	},
	fist = {
		[ACT_MP_STAND_IDLE] = {"1hm.idlerelaxed", "h2h.idleready"},
		[ACT_MP_CROUCH_IDLE] = {"1hm.sneakidle", "1hm.sneakidlec"},
		[ACT_MP_WALK] = {"mt.walk", "h2h.walkready"},
		[ACT_MP_CROUCHWALK] = {"1hm.sneakwalk", "1hm.sneakwalk"},
		[ACT_MP_RUN] = {"mt.run", "h2h.run"},
		sprint = {"h2h.sprint","h2h.sprint"},
		attack = {"h2h.attackstandinga", "h2h.attackstandingb"},
		attack2 = {"h2h.block", "h2h.block"},
		jump = {"h2h.jump", "h2h.jump"},
		chadLand = {"h2h.jumpimpactland", "h2h.jumpimpactland"},
		land = {"h2h.jumpinplaceland", "h2h.jumpinplaceland"}
	},
	["h2h"] = {
		[ACT_MP_STAND_IDLE] = {"1hm.idlerelaxed", "h2h.idleready"},
		[ACT_MP_CROUCH_IDLE] = {"1hm.sneakidle", "1hm.sneakidlec"},
		[ACT_MP_WALK] = {"mt.walk", "h2h.walkready"},
		[ACT_MP_CROUCHWALK] = {"1hm.sneakwalk", "1hm.sneakwalk"},
		[ACT_MP_RUN] = {"mt.run", "h2h.run"},
		sprint = {"h2h.sprint","h2h.sprint"},
		attack = {"h2h.attackstandinga", "h2h.attackstandingb"},
		attack2 = {"h2h.block", "h2h.block"},
		jump = {"h2h.jump", "h2h.jump"},
		chadLand = {"h2h.jumpimpactland", "h2h.jumpimpactland"},
		land = {"h2h.jumpinplaceland", "h2h.jumpinplaceland"}
	},
	["1hp"] = {
		[ACT_MP_STAND_IDLE] = {"pistol.idlerelaxed", "pistol.idleready"},
		[ACT_MP_CROUCH_IDLE] = {"1hm.sneakidle", "pistol.idlesneak"},
		[ACT_MP_WALK] = {"pistol.walkrelaxed", "pistol.walkready"},
		[ACT_MP_CROUCHWALK] = {"1hm.sneakwalk", "pistol.sneakwalk"},
		[ACT_MP_RUN] = {"pistol.runrelaxed", "pistol.runready"},
		sprint = {"pistol.sprint","pistol.sprint"},
		attack = {"piperiflepistol.wpnfiresingleready", "piperiflepistol.wpnfiresingleready"},
		jump = {"pistol.jump", "pistol.jump"},
		chadLand = {"pistol.jumpimpactland", "pistol.jumpimpactland"},
		land = {"pistol.jumpinplaceland", "pistol.jumpinplaceland"}
	},
	["2ha"] = {
		[ACT_MP_STAND_IDLE] = {"rifle.idlerelaxed", "rifle.idleready","rifle.idleready"},
		[ACT_MP_CROUCH_IDLE] = {"rifle.idlesneak", "rifle.idlesneak","rifle.idlesneak"},
		[ACT_MP_WALK] = {"rifle.walkrelaxed", "rifle.walkready", "rifle.walkready"},
		[ACT_MP_CROUCHWALK] = {"rifle.sneakwalk", "rifle.sneakwalk","rifle.sneakwalk"},
		[ACT_MP_RUN] = {"rifle.runrelaxed", "rifle.runready","rifle.runready"},
		[ACT_MP_SWIM] = {"swimm"},
		sprint = {"rifle.sprint","rifle.sprint","rifle.sprint"},
		jump = {"rifle.jump", "rifle.jump"},
		chadLand = {"rifle.jumpimpactland", "rifle.jumpimpactland"},
		land = {"rifle.jumpinplaceland", "rifle.jumpinplaceland"}
	},
	["2hr"] = {
		[ACT_MP_STAND_IDLE] = {"rifle.idlerelaxed", "rifle.idleready","rifle.idleready"},
		[ACT_MP_CROUCH_IDLE] = {"rifle.idlesneak", "rifle.idlesneak","rifle.idlesneak"},
		[ACT_MP_WALK] = {"rifle.walkrelaxed", "rifle.walkready", "rifle.walkready"},
		[ACT_MP_CROUCHWALK] = {"rifle.sneakwalk", "rifle.sneakwalk","rifle.sneakwalk"},
		[ACT_MP_RUN] = {"rifle.runrelaxed", "rifle.runready","rifle.runready"},
		[ACT_MP_SWIM] = {"swimm"},
		sprint = {"rifle.sprint","rifle.sprint","rifle.sprint"},
		jump = {"rifle.jump", "rifle.jump"},
		chadLand = {"rifle.jumpimpactland", "rifle.jumpimpactland"},
		land = {"rifle.jumpinplaceland", "rifle.jumpinplaceland"}
	},
	["2hh"] = {
		[ACT_MP_STAND_IDLE] = {"heavy.idlerelaxed", "heavy.idleready","heavy.idleready"},
		[ACT_MP_CROUCH_IDLE] = {"heavy.idlesneak", "heavy.idlesneak","heavy.idlesneak"},
		[ACT_MP_WALK] = {"heavy.walkrelaxed", "heavy.walkready", "heavy.walkready"},
		[ACT_MP_CROUCHWALK] = {"heavy.sneakwalk", "heavy.sneakwalk","heavy.sneakwalk"},
		[ACT_MP_RUN] = {"heavy.runrelaxed", "heavy.runready","heavy.runready"},
		[ACT_MP_SWIM] = {"swimm"},
		sprint = {"heavy.sprint","heavy.sprint","heavy.sprint"},
		jump = {"heavy.jump", "heavy.jump"},
		chadLand = {"heavy.jumpimpactland", "heavy.jumpimpactland"},
		land = {"heavy.jumpinplaceland", "heavy.jumpinplaceland"}
	},
	["2hl"] = {
		[ACT_MP_STAND_IDLE] = {"2hlaim", "2hlaim","2hlaim"},
		[ACT_MP_CROUCH_IDLE] = {"sneak2hlaim", "sneak2hlaim","sneak2hlaim"},
		[ACT_MP_WALK] = {"2hlaim_walk", "2hlaim_walk", "2hlaim_walk"},
		[ACT_MP_CROUCHWALK] = {"2hlaim_sneak", "2hlaim_sneak","2hlaim_sneak"},
		[ACT_MP_RUN] = {"2hlaim_run", "2hlaim_run","2hlaim_run"},
		[ACT_MP_SWIM] = {"swimm"},
		sprint = {"sprint_2hl","sprint_2hl","sprint_2hl"},
		jump = {"2hlaim_jumpstart", "2hlaimis_jumpstart"},
		chadLand = {"h2h.jumpimpactland", "h2h.jumpimpactland"},
		land = {"2hlaim_jumpland", "2hlaim_jumpland"}
	},
	["2hm"] = {
		[ACT_MP_STAND_IDLE] = {"2hmaim", "2hmaim","2hmaim"},
		[ACT_MP_CROUCH_IDLE] = {"sneak2hmaim", "sneak2hmaim","sneak2hmaim"},
		[ACT_MP_WALK] = {"2hmaim_walk", "2hmaim_walk", "2hmaim_walk"},
		[ACT_MP_CROUCHWALK] = {"2hmaim_sneak", "2hmaim_sneak","2hmaim_sneak"},
		[ACT_MP_RUN] = {"2hmaim_run", "2hmaim_run","2hmaim_run"},
		[ACT_HL2MP_FIST_BLOCK] = {"2hmrecoil", "2hmrecoil","2hmrecoil"},
		[ACT_LAND] = {"2hmaim_jumpland", "2hmaim_jumpland"},
		[ACT_MP_SWIM] = {"swimm"},
		sprint = {"sprint_2hm","sprint_2hm","sprint_2hm"},
		jump = {"2hmaim_jumpstart", "2hmaimis_jumpstart"},
		land = {"2hmaim_jumpland", "2hmaim_jumpland"},
		chadLand = {"h2h.jumpimpactland", "h2h.jumpimpactland"},
		attack = {"2hmattackleft_a", "2hmattackright_a"},
		attack2 = {"2hmblockidle", "2hmblockidle"}
	},
	["2hmo"] = {
		[ACT_MP_STAND_IDLE] = {"2hmaim", "twohandidle","twohandidle"},
		[ACT_MP_CROUCH_IDLE] = {"twohand_sneakwalk", "twohand_sneakwalk","twohand_sneakwalk"},
		[ACT_MP_WALK] = {"2hmaim_walk", "twohand_walk", "twohand_walk"},
		[ACT_MP_CROUCHWALK] = {"twohand_sneakwalk", "twohand_sneakwalk","twohand_sneakwalk"},
		[ACT_MP_RUN] = {"2hmaim_run", "twohand_run","twohand_run"},
		[ACT_HL2MP_FIST_BLOCK] = {"2hmrecoil", "2hmrecoil","2hmrecoil"},
		[ACT_LAND] = {"twohand_run", "twohand_run"},
		[ACT_MP_SWIM] = {"swimm"},
		sprint = {"sprint_2hm","sprint_2hm","sprint_2hm"},
		jump = {"twohandjumpstart", "twohandjumpstart"},
		land = {"twohandjumpland", "twohandjumpland"},
		attack = {"twohandattackleft", "twohandattackright"},
		attack2 = {"h2hblockidle", "h2hblockidle"}
	},
	["1hm"] = {
		[ACT_MP_STAND_IDLE] = {"mtidle", "1hmaim","1hmaim"},
		[ACT_MP_CROUCH_IDLE] = {"sneakmtidle", "sneak1hmaim", "sneak1hmaim"},
		[ACT_MP_WALK] = {"mtwalk", "1hmwalk", "1hmwalk"},
		[ACT_MP_CROUCHWALK] = {"sneakmtwalk", "sneakmtwalk", "sneakmtwalk"},
		[ACT_MP_RUN] = {"mtrun", "1hmrun", "1hmrun"},
		[ACT_HL2MP_FIST_BLOCK] = {"1hmrecoil", "1hmrecoil","1hmrecoil"},
		[ACT_LAND] = {"1hmaim_jumpland", "1hmaim_jumpland"},
		[ACT_MP_SWIM] = {"swimm"},
		sprint = {"sprint_1hm","sprint_1hm","sprint_1hm"},
		attack = {"1hmattackleft_a", "1hmattackright_a"},
		attack2 = {"1hmblockidle", "1hmblockidle"},
		jump = {"1hmaim_jumpstart", "1hmaimis_jumpstart"},
		land = {"1hmaim_jumpland", "1hmaimis_jumpland"}
	},
}

ix.anim.supermutant = {
	useADV = true,
	normal = {
		[ACT_MP_STAND_IDLE] = {"idle", "idle", "idle"},
		[ACT_MP_CROUCH_IDLE] = {"idle", "idle", "idle"},
		[ACT_MP_WALK] = {"walk", "walk", "walk"},
		[ACT_MP_CROUCHWALK] = {"walk", "walk", "walk"},
		[ACT_MP_RUN] = {"run", "run", "run"},
		[ACT_MP_SWIM] = {"walk"},
		sprint = {"run","run","run"}
	},
	fist = {
		[ACT_MP_STAND_IDLE] = {"idle", "h2haim", "h2haim"},
		[ACT_MP_CROUCH_IDLE] = {"idle", "h2haim", "h2haim"},
		[ACT_MP_WALK] = {"walk", "h2haim_walk", "h2haim_walk"},
		[ACT_MP_CROUCHWALK] = {"walk", "h2haim_walk", "h2haim_walk"},
		[ACT_MP_RUN] = {"run", "h2haim_run", "h2haim_run"},
		[ACT_MP_SWIM] = {"walk"},
		attack = "h2hattackright_a",
		sprint = {"run","h2haim_run","h2haim_run"}
	},
	pistol = {
		[ACT_MP_STAND_IDLE] = {"idle", "2haaim", "2haaim"},
		[ACT_MP_CROUCH_IDLE] = {"idle", "2haaim", "2haaim"},
		[ACT_MP_WALK] = {"walk", "2haaim_walk", "2haaim_walk"},
		[ACT_MP_CROUCHWALK] = {"walk", "2haaim_walk", "2haaim_walk"},
		[ACT_MP_RUN] = {"run", "2haaim_run", "2haaim_run"},
		[ACT_MP_SWIM] = {"walk"},
		attack = "2hattackloop",
		reload = "2hareloada",
		sprint = {"2haaim_run","2haaim_run","2haaim_run"}
	},
	shotgun = {
		[ACT_MP_STAND_IDLE] = {"idle", "2haaim", "2haaim"},
		[ACT_MP_CROUCH_IDLE] = {"idle", "2haaim", "2haaim"},
		[ACT_MP_WALK] = {"walk", "2haaim_walk", "2haaim_walk"},
		[ACT_MP_CROUCHWALK] = {"walk", "2haaim_walk", "2haaim_walk"},
		[ACT_MP_RUN] = {"run", "2haaim_run", "2haaim_run"},
		[ACT_MP_SWIM] = {"walk"},
		attack = "2hattackloop",
		reload = "2hareloada",
		sprint = {"2haaim_run","2haaim_run","2haaim_run"}
	},
	smg = {
		[ACT_MP_STAND_IDLE] = {"idle", "2haaim", "2haaim"},
		[ACT_MP_CROUCH_IDLE] = {"idle", "2haaim", "2haaim"},
		[ACT_MP_WALK] = {"walk", "2haaim_walk", "2haaim_walk"},
		[ACT_MP_CROUCHWALK] = {"walk", "2haaim_walk", "2haaim_walk"},
		[ACT_MP_RUN] = {"run", "2haaim_run", "2haaim_run"},
		[ACT_MP_SWIM] = {"walk"},
		attack = "2hattackloop",
		reload = "2hareloada",
		sprint = {"2haaim_run","2haaim_run","2haaim_run"}
	},
	ar2 = {
		[ACT_MP_STAND_IDLE] = {"idle", "2haaim", "2haaim"},
		[ACT_MP_CROUCH_IDLE] = {"idle", "2haaim", "2haaim"},
		[ACT_MP_WALK] = {"walk", "2haaim_walk", "2haaim_walk"},
		[ACT_MP_CROUCHWALK] = {"walk", "2haaim_walk", "2haaim_walk"},
		[ACT_MP_RUN] = {"run", "2haaim_run", "2haaim_run"},
		[ACT_MP_SWIM] = {"walk"},
		attack = "2hattackloop",
		reload = "2hareloada",
		sprint = {"2haaim_run","2haaim_run","2haaim_run"}
	},
	revolver = {
		[ACT_MP_STAND_IDLE] = {"idle", "2haaim", "2haaim"},
		[ACT_MP_CROUCH_IDLE] = {"idle", "2haaim", "2haaim"},
		[ACT_MP_WALK] = {"walk", "2haaim_walk", "2haaim_walk"},
		[ACT_MP_CROUCHWALK] = {"walk", "2haaim_walk", "2haaim_walk"},
		[ACT_MP_RUN] = {"run", "2haaim_run", "2haaim_run"},
		[ACT_MP_SWIM] = {"walk"},
		attack = "2hattackloop",
		reload = "2hareloada",
		sprint = {"2haaim_run","2haaim_run","2haaim_run"}
	},
	grenade = {
		[ACT_MP_STAND_IDLE] = {"idle", "1gtaim", "1gtaim"},
		[ACT_MP_CROUCH_IDLE] = {"idle", "1gtaim", "1gtaim"},
		[ACT_MP_WALK] = {"walk", "1gtaim_walk", "1gtaim_walk"},
		[ACT_MP_CROUCHWALK] = {"walk", "1gtaim_walk", "1gtaim_walk"},
		[ACT_MP_RUN] = {"run", "1gtaim_run", "1gtaim_run"},
		[ACT_MP_SWIM] = {"walk"},
		attack = "1gtattackthrow",
		sprint = {"1gtaim_run","1gtaim_run","1gtaim_run"}
	},
	knife = {
		[ACT_MP_STAND_IDLE] = {"idle", "2hmaim", "2hmaim"},
		[ACT_MP_CROUCH_IDLE] = {"idle", "2hmaim", "2hmaim"},
		[ACT_MP_WALK] = {"walk", "2hmaim_walk", "2hmaim_walk"},
		[ACT_MP_CROUCHWALK] = {"walk", "2hmaim_walk", "2hmaim_walk"},
		[ACT_MP_RUN] = {"run", "2hmaim_run", "2hmaim_run"},
		[ACT_MP_SWIM] = {"walk"},
		attack = {"2hmattackleft_a","2hmattackright_a","2hmattackright_b"},
		sprint = {"2hmaim_run","2hmaim_run","2hmaim_run"}
	},
	melee = {
		[ACT_MP_STAND_IDLE] = {"idle", "2hmaim", "2hmaim"},
		[ACT_MP_CROUCH_IDLE] = {"idle", "2hmaim", "2hmaim"},
		[ACT_MP_WALK] = {"walk", "2hmaim_walk", "2hmaim_walk"},
		[ACT_MP_CROUCHWALK] = {"walk", "2hmaim_walk", "2hmaim_walk"},
		[ACT_MP_RUN] = {"run", "2hmaim_run", "2hmaim_run"},
		[ACT_MP_SWIM] = {"walk"},
		attack = {"2hmattackleft_a","2hmattackright_a","2hmattackright_b"},
		sprint = {"2hmaim_run","2hmaim_run","2hmaim_run"}
	},
	melee2 = {
		[ACT_MP_STAND_IDLE] = {"idle", "2hmaim", "2hmaim"},
		[ACT_MP_CROUCH_IDLE] = {"idle", "2hmaim", "2hmaim"},
		[ACT_MP_WALK] = {"walk", "2hmaim_walk", "2hmaim_walk"},
		[ACT_MP_CROUCHWALK] = {"walk", "2hmaim_walk", "2hmaim_walk"},
		[ACT_MP_RUN] = {"run", "2hmaim_run", "2hmaim_run"},
		[ACT_MP_SWIM] = {"walk"},
		attack = {"2hmattackleft_a","2hmattackright_a","2hmattackright_b"},
		sprint = {"2hmaim_run","2hmaim_run","2hmaim_run"}
	},
	rpg = {
		[ACT_MP_STAND_IDLE] = {"idle", "2hlaim", "2hlaim"},
		[ACT_MP_CROUCH_IDLE] = {"idle", "2hlaim", "2hlaim"},
		[ACT_MP_WALK] = {"walk", "2hlaim_walk", "2hlaim_walk"},
		[ACT_MP_CROUCHWALK] = {"walk", "2hlaim_walk", "2hlaim_walk"},
		[ACT_MP_RUN] = {"run", "2hlaim_run", "2hlaim_run"},
		[ACT_MP_SWIM] = {"walk"},
		attack = "2hlattackright",
		reload = "2hlreloada",
		sprint = {"2hlaim_run","2hlaim_run","2hlaim_run"}
	},
	heavy = {
		[ACT_MP_STAND_IDLE] = {"idle", "2hhaim", "2hhaim"},
		[ACT_MP_CROUCH_IDLE] = {"idle", "2hhaim", "2hhaim"},
		[ACT_MP_WALK] = {"walk", "2hhaim_walk", "2hhaim_walk"},
		[ACT_MP_CROUCHWALK] = {"walk", "2hhaim_walk", "2hhaim_walk"},
		[ACT_MP_RUN] = {"run", "2hhaim_run", "2hhaim_run"},
		[ACT_MP_SWIM] = {"walk"},
		attack = "2hhattackloop",
		reload = "2hhreloade",
		sprint = {"2hhaim_run","2hhaim_run","2hhaim_run"}
	},
	["h2h"] = {
		[ACT_MP_STAND_IDLE] = {"idle", "h2haim", "h2haim"},
		[ACT_MP_CROUCH_IDLE] = {"idle", "h2haim", "h2haim"},
		[ACT_MP_WALK] = {"walk", "h2haim_walk", "h2haim_walk"},
		[ACT_MP_CROUCHWALK] = {"walk", "h2haim_walk", "h2haim_walk"},
		[ACT_MP_RUN] = {"run", "h2haim_run", "h2haim_run"},
		[ACT_MP_SWIM] = {"walk"},
		attack = "h2hattackright_a",
		sprint = {"run","h2haim_run","h2haim_run"}
	},
	["1hm"] = {
		[ACT_MP_STAND_IDLE] = {"idle", "2hmaim", "2hmaim"},
		[ACT_MP_CROUCH_IDLE] = {"idle", "2hmaim", "2hmaim"},
		[ACT_MP_WALK] = {"walk", "2hmaim_walk", "2hmaim_walk"},
		[ACT_MP_CROUCHWALK] = {"walk", "2hmaim_walk", "2hmaim_walk"},
		[ACT_MP_RUN] = {"run", "2hmaim_run", "2hmaim_run"},
		[ACT_MP_SWIM] = {"walk"},
		attack = {"2hmattackleft_a","2hmattackright_a","2hmattackright_b"},
		sprint = {"2hmaim_run","2hmaim_run","2hmaim_run"}
	},
	["2hm"] = {
		[ACT_MP_STAND_IDLE] = {"idle", "2hmaim", "2hmaim"},
		[ACT_MP_CROUCH_IDLE] = {"idle", "2hmaim", "2hmaim"},
		[ACT_MP_WALK] = {"walk", "2hmaim_walk", "2hmaim_walk"},
		[ACT_MP_CROUCHWALK] = {"walk", "2hmaim_walk", "2hmaim_walk"},
		[ACT_MP_RUN] = {"run", "2hmaim_run", "2hmaim_run"},
		[ACT_MP_SWIM] = {"walk"},
		attack = {"2hmattackleft_a","2hmattackright_a","2hmattackright_b"},
		sprint = {"2hmaim_run","2hmaim_run","2hmaim_run"}
	},
	["2hmo"] = {
		[ACT_MP_STAND_IDLE] = {"idle", "2hmaim", "2hmaim"},
		[ACT_MP_CROUCH_IDLE] = {"idle", "2hmaim", "2hmaim"},
		[ACT_MP_WALK] = {"walk", "2hmaim_walk", "2hmaim_walk"},
		[ACT_MP_CROUCHWALK] = {"walk", "2hmaim_walk", "2hmaim_walk"},
		[ACT_MP_RUN] = {"run", "2hmaim_run", "2hmaim_run"},
		[ACT_MP_SWIM] = {"walk"},
		attack = {"2hmattackleft_a","2hmattackright_a","2hmattackright_b"},
		sprint = {"2hmaim_run","2hmaim_run","2hmaim_run"}
	},
	["1hp"] = {
		[ACT_MP_STAND_IDLE] = {"idle", "2haaim", "2haaim"},
		[ACT_MP_CROUCH_IDLE] = {"idle", "2haaim", "2haaim"},
		[ACT_MP_WALK] = {"walk", "2haaim_walk", "2haaim_walk"},
		[ACT_MP_CROUCHWALK] = {"walk", "2haaim_walk", "2haaim_walk"},
		[ACT_MP_RUN] = {"run", "2haaim_run", "2haaim_run"},
		[ACT_MP_SWIM] = {"walk"},
		attack = "2hattackloop",
		reload = "2hareloada",
		sprint = {"2haaim_run","2haaim_run","2haaim_run"}
	},
	["2hr"] = {
		[ACT_MP_STAND_IDLE] = {"idle", "2haaim", "2haaim"},
		[ACT_MP_CROUCH_IDLE] = {"idle", "2haaim", "2haaim"},
		[ACT_MP_WALK] = {"walk", "2haaim_walk", "2haaim_walk"},
		[ACT_MP_CROUCHWALK] = {"walk", "2haaim_walk", "2haaim_walk"},
		[ACT_MP_RUN] = {"run", "2haaim_run", "2haaim_run"},
		[ACT_MP_SWIM] = {"walk"},
		attack = "2hattackloop",
		reload = "2hareloada",
		sprint = {"2haaim_run","2haaim_run","2haaim_run"}
	},
	["2ha"] = {
		[ACT_MP_STAND_IDLE] = {"idle", "2haaim", "2haaim"},
		[ACT_MP_CROUCH_IDLE] = {"idle", "2haaim", "2haaim"},
		[ACT_MP_WALK] = {"walk", "2haaim_walk", "2haaim_walk"},
		[ACT_MP_CROUCHWALK] = {"walk", "2haaim_walk", "2haaim_walk"},
		[ACT_MP_RUN] = {"run", "2haaim_run", "2haaim_run"},
		[ACT_MP_SWIM] = {"walk"},
		attack = "2hattackloop",
		reload = "2hareloada",
		sprint = {"2haaim_run","2haaim_run","2haaim_run"}
	},
	["2hl"] = {
		[ACT_MP_STAND_IDLE] = {"idle", "2hlaim", "2hlaim"},
		[ACT_MP_CROUCH_IDLE] = {"idle", "2hlaim", "2hlaim"},
		[ACT_MP_WALK] = {"walk", "2hlaim_walk", "2hlaim_walk"},
		[ACT_MP_CROUCHWALK] = {"walk", "2hlaim_walk", "2hlaim_walk"},
		[ACT_MP_RUN] = {"run", "2hlaim_run", "2hlaim_run"},
		[ACT_MP_SWIM] = {"walk"},
		attack = "2hlattackright",
		reload = "2hlreloada",
		sprint = {"2hlaim_run","2hlaim_run","2hlaim_run"}
	},
	["2hh"] = {
		[ACT_MP_STAND_IDLE] = {"idle", "2hhaim", "2hhaim"},
		[ACT_MP_CROUCH_IDLE] = {"idle", "2hhaim", "2hhaim"},
		[ACT_MP_WALK] = {"walk", "2hhaim_walk", "2hhaim_walk"},
		[ACT_MP_CROUCHWALK] = {"walk", "2hhaim_walk", "2hhaim_walk"},
		[ACT_MP_RUN] = {"run", "2hhaim_run", "2hhaim_run"},
		[ACT_MP_SWIM] = {"walk"},
		attack = "2hhattackloop",
		reload = "2hhreloade",
		sprint = {"2hhaim_run","2hhaim_run","2hhaim_run"}
	}
}

ix.anim.securitron = {
	useADV = true,
	normal = {
		[ACT_MP_STAND_IDLE] = {"mtidle", "mtidle", "mtidle"},
		[ACT_MP_CROUCH_IDLE] = {"mtidle", "mtidle", "mtidle"},
		[ACT_MP_WALK] = {"walk", "walk", "walk"},
		[ACT_MP_CROUCHWALK] = {"walk", "walk", "walk"},
		[ACT_MP_RUN] = {"mtrun", "mtrun", "mtrun"},
		[ACT_MP_SWIM] = {"walk"},
		sprint = {"mtrun","mtrun","mtrun"}
	},
	fist = {
		[ACT_MP_STAND_IDLE] = {"mtidle", "h2haim", "h2haim"},
		[ACT_MP_CROUCH_IDLE] = {"mtidle", "h2haim", "h2haim"},
		[ACT_MP_WALK] = {"walk", "walk_h2haim", "walk_h2haim"},
		[ACT_MP_CROUCHWALK] = {"walk", "walk_h2haim", "walk_h2haim"},
		[ACT_MP_RUN] = {"mtrun", "walk_h2haim", "walk_h2haim"},
		[ACT_MP_SWIM] = {"walk"},
		attack = "h2hattackleft",
		sprint = {"run","walk_h2haim","walk_h2haim"}
	},
	pistol = {
		[ACT_MP_STAND_IDLE] = {"mtidle", "1hpaim", "1hpaim"},
		[ACT_MP_CROUCH_IDLE] = {"mtidle", "1hpaim", "1hpaim"},
		[ACT_MP_WALK] = {"walk", "walk_1hp", "walk_1hp"},
		[ACT_MP_CROUCHWALK] = {"walk", "walk_1hp", "walk_1hp"},
		[ACT_MP_RUN] = {"mtrun", "walk_1hp", "walk_1hp"},
		[ACT_MP_SWIM] = {"walk"},
		attack = "1hpattack",
		reload = "1hpreload",
		sprint = {"run","walk_1hp","walk_1hp"}
	},
	["h2h"] = {
		[ACT_MP_STAND_IDLE] = {"mtidle", "h2haim", "h2haim"},
		[ACT_MP_CROUCH_IDLE] = {"mtidle", "h2haim", "h2haim"},
		[ACT_MP_WALK] = {"walk", "walk_h2haim", "walk_h2haim"},
		[ACT_MP_CROUCHWALK] = {"walk", "walk_h2haim", "walk_h2haim"},
		[ACT_MP_RUN] = {"mtrun", "walk_h2haim", "walk_h2haim"},
		[ACT_MP_SWIM] = {"walk"},
		attack = "h2hattackleft",
		sprint = {"run","walk_h2haim","walk_h2haim"}
	},
	["1hp"] = {
		[ACT_MP_STAND_IDLE] = {"mtidle", "1hpaim", "1hpaim"},
		[ACT_MP_CROUCH_IDLE] = {"mtidle", "1hpaim", "1hpaim"},
		[ACT_MP_WALK] = {"walk", "walk_1hp", "walk_1hp"},
		[ACT_MP_CROUCHWALK] = {"walk", "walk_1hp", "walk_1hp"},
		[ACT_MP_RUN] = {"mtrun", "walk_1hp", "walk_1hp"},
		[ACT_MP_SWIM] = {"walk"},
		attack = "1hpattack",
		reload = "1hpreload",
		sprint = {"run","walk_1hp","walk_1hp"}
	}
}
ix.anim.securitron.shotgun = ix.anim.securitron.pistol
ix.anim.securitron.smg = ix.anim.securitron.pistol
ix.anim.securitron.ar2 = ix.anim.securitron.pistol
ix.anim.securitron.revolver = ix.anim.securitron.pistol
ix.anim.securitron.grenade = ix.anim.securitron.fist
ix.anim.securitron.knife = ix.anim.securitron.fist
ix.anim.securitron.melee = ix.anim.securitron.fist
ix.anim.securitron.melee2 = ix.anim.securitron.fist
ix.anim.securitron.rpg = ix.anim.securitron.pistol
ix.anim.securitron.heavy = ix.anim.securitron.pistol
ix.anim.securitron["1hm"] = ix.anim.securitron["h2h"]
ix.anim.securitron["2hm"] = ix.anim.securitron["h2h"]
ix.anim.securitron["2hr"] = ix.anim.securitron["1hp"]
ix.anim.securitron["2ha"] = ix.anim.securitron["1hp"]
ix.anim.securitron["2hl"] = ix.anim.securitron["1hp"]
ix.anim.securitron["2hh"] = ix.anim.securitron["1hp"]

-- Bind the animation model to its class. Any player using this model gets the
-- New Vegas set; everything else falls through to Helix's stock behaviour.
ix.anim.SetModelClass("models/phoenix/humans/animations.mdl", "falloutHuman")
