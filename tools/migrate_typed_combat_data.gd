extends SceneTree

const ROWS: Array[Dictionary] = [
	{"path":"res://data/attacks/fighter_cleave.tres", "id":&"fighter_cleave", "kind":AttackDefinition.Kind.MELEE_CLEAVE, "type":&"physical", "amount":18.0, "power":0.0, "cooldown":0.8, "range":2.2, "speed":0.0, "area":1.6, "tags":[&"melee", &"area"], "crit":true},
	{"path":"res://data/attacks/ranger_shot.tres", "id":&"ranger_shot", "kind":AttackDefinition.Kind.PROJECTILE, "type":&"physical", "amount":11.0, "power":0.0, "cooldown":0.55, "range":11.0, "speed":16.0, "area":0.0, "tags":[&"projectile", &"ranged"], "crit":true},
	{"path":"res://data/attacks/mage_burst.tres", "id":&"mage_burst", "kind":AttackDefinition.Kind.AREA_PROJECTILE, "type":&"fire", "amount":24.0, "power":0.0, "cooldown":1.5, "range":12.0, "speed":11.0, "area":2.5, "tags":[&"projectile", &"area", &"fire"], "crit":true},
	{"path":"res://data/attacks/cleric_bolt.tres", "id":&"cleric_bolt", "kind":AttackDefinition.Kind.PROJECTILE, "type":&"lightning", "amount":8.0, "power":0.0, "cooldown":1.0, "range":10.0, "speed":13.0, "area":0.0, "tags":[&"projectile", &"lightning"], "crit":true},
	{"path":"res://data/attacks/cleric_heal.tres", "id":&"cleric_heal", "kind":AttackDefinition.Kind.HEAL, "type":&"", "amount":0.0, "power":18.0, "cooldown":3.0, "range":9.0, "speed":0.0, "area":0.0, "tags":[&"healing"], "crit":false},
	{"path":"res://data/attacks/swarmer_contact.tres", "id":&"swarmer_contact", "kind":AttackDefinition.Kind.DIRECT, "type":&"physical", "amount":8.0, "power":0.0, "cooldown":0.8, "range":0.9, "speed":0.0, "area":0.0, "tags":[&"melee", &"contact"], "crit":false},
	{"path":"res://data/attacks/spitter_projectile.tres", "id":&"spitter_projectile", "kind":AttackDefinition.Kind.PROJECTILE, "type":&"physical", "amount":10.0, "power":0.0, "cooldown":2.2, "range":18.0, "speed":6.0, "area":0.0, "tags":[&"projectile", &"ranged"], "crit":false},
	{"path":"res://data/attacks/guardian_charge.tres", "id":&"guardian_charge", "kind":AttackDefinition.Kind.DIRECT, "type":&"physical", "amount":22.0, "power":0.0, "cooldown":1.0, "range":2.4, "speed":0.0, "area":0.0, "tags":[&"melee", &"charge"], "crit":false},
	{"path":"res://data/attacks/guardian_shockwave.tres", "id":&"guardian_shockwave", "kind":AttackDefinition.Kind.AREA, "type":&"physical", "amount":22.0, "power":0.0, "cooldown":1.0, "range":6.0, "speed":0.0, "area":6.0, "tags":[&"area", &"shockwave"], "crit":false},
]

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/attacks"))
	for row: Dictionary in ROWS:
		var attack: AttackDefinition
		if ResourceLoader.exists(row["path"]):
			attack = load(row["path"]) as AttackDefinition
		else:
			attack = AttackDefinition.new()
		attack.id = row["id"]
		attack.kind = row["kind"]
		attack.power = row["power"]
		attack.cooldown = row["cooldown"]
		attack.range = row["range"]
		attack.projectile_speed = row["speed"]
		attack.area_radius = row["area"]
		attack.action_tags.assign(row["tags"])
		attack.can_crit = row["crit"]
		attack.damage_components.clear()
		if not StringName(row["type"]).is_empty():
			var component := AttackDamageComponent.new()
			component.damage_type_id = row["type"]
			component.base_amount = row["amount"]
			attack.damage_components.append(component)
		var error := ResourceSaver.save(attack, row["path"])
		if error != OK:
			push_error("PARTY_FORGE_DAMAGE_ERROR path=%s reason=save failed code=%d" % [row["path"], error])
			quit(1)
			return
	print("PARTY_FORGE_TYPED_ATTACK_DATA_SAVED count=%d" % ROWS.size())
	quit(0)
