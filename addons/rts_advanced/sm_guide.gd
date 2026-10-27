class_name SMGuide
extends RefCounted
## First-run copy: controls, the how-to panel, and the Kokang lesson.

static func controls_hint() -> String:
	return "Left-click select. Right-click ground to move, an enemy to attack. A ring marks the order. Click the minimap to jump. F ability. H guide."

static func howto_text() -> String:
	return "Left-click a unit, or drag a box around your company.\nRight-click open ground to move. Right-click an enemy to attack. A ring marks that spot, then fades.\nClick the minimap to jump the camera there.\nPress F, or Ability, to use the selected unit's power. Smart-cast fires only the closest ready unit.\nThe column on the right trains units and raises buildings. Walk onto a colored pad to claim it.\nBoats cross deep water. Tanks and infantry stay on land, and they use a shallow ford when one is open.\nThe status line reads Objective complete when you win, and Objective failed if your company dies."

static func tutorial_for(mission_id: String) -> String:
	if mission_id == "kokang":
		return "First mission. Select the company, right-click to move, and right-click the raiders to fight. Raise the yard, run the ruby night shift, and bring one rare-earth stock home. If the company dies, the raid fails."
	return ""

static func unit_tip(row: Dictionary) -> String:
	var name: String = str(row.get("display_name", row.get("id", "Unit")))
	var cost: int = int(row.get("cost", 0))
	var hp: int = int(row.get("hp", 0))
	var damage: int = int(row.get("weapon_damage", 0))
	var loco: String = str(row.get("locomotion", "ground"))
	var ability: String = str(row.get("ability", "ability"))
	return "%s. %d credits. HP %d. Damage %d. Moves on %s. F: %s." % [name, cost, hp, damage, loco, ability]

static func building_tip(row: Dictionary) -> String:
	var name: String = str(row.get("display_name", row.get("id", "Building")))
	var role: String = str(row.get("role", "structure"))
	var cost: int = int(row.get("cost", 0))
	var hp: int = int(row.get("hp", 0))
	return "%s. %s. %d credits. HP %d." % [name, role, cost, hp]

static func ability_tip() -> String:
	return "Ability (F). A toggle flips every selected toggle unit. Smart-cast fires only the closest ready unit. A finished beam freezes the nearest enemy."
