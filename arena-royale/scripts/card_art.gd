class_name CardArt
## What each card's troops hold and how they swing, shared by the battlefield
## and the card portraits.

const KEEP := {
	"knight": ["1H_Sword", "Round_Shield", "Skeleton_Blade", "Skeleton_Shield_Small_A"],
	"archers": ["1H_Crossbow", "Skeleton_Crossbow"],
	"barbarian": ["2H_Axe", "Skeleton_Axe"],
	"mage": ["2H_Staff", "Skeleton_Staff"],
	"golem": ["Skeleton_Axe"],
	"rogue": ["Knife", "Knife_Offhand", "Skeleton_Blade"],
	"minions": ["Skeleton_Blade"],
}
const ATTACK := {
	"knight": "1H_Melee_Attack_Chop", "archers": "1H_Ranged_Shoot", "barbarian": "2H_Melee_Attack_Chop",
	"mage": "Spellcast_Shoot", "golem": "2H_Melee_Attack_Slice", "rogue": "Dualwield_Melee_Attack_Stab",
	"minions": "1H_Melee_Attack_Chop",
}


static func keep(card_id: String) -> Array:
	return KEEP.get(card_id, [])


static func attack(card_id: String) -> String:
	return ATTACK.get(card_id, "1H_Melee_Attack_Chop")
