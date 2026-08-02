extends SceneTree

const PROJECTILE_SCRIPT := preload("res://scripts/combat/projectile.gd")
const EFFECT_SCRIPT := preload("res://scripts/combat/presentation_effect.gd")
const PROJECTILE_ROOT := "res://scenes/combat/presentation/projectiles"
const EFFECT_ROOT := "res://scenes/combat/presentation/effects"
const PROJECTILE_RECIPES := {
	&"ranger_arrow": {&"shape": &"arrow", &"length": 0.90, &"radius": 0.025, &"color": Color("b9a06c")},
	&"marksman_heavy_arrow": {&"shape": &"arrow", &"length": 1.35, &"radius": 0.045, &"color": Color("88734f")},
	&"mage_fire_orb": {&"shape": &"orb", &"radius": 0.18, &"color": Color("ff6b35"), &"emission": 1.4},
	&"frost_shard": {&"shape": &"shard", &"length": 0.62, &"radius": 0.11, &"color": Color("8ee8ff"), &"emission": 1.0},
	&"cleric_lightning_bolt": {&"shape": &"bolt", &"length": 0.72, &"radius": 0.06, &"color": Color("fff08a"), &"emission": 1.5},
	&"warlock_chaos_bolt": {&"shape": &"orb", &"radius": 0.22, &"color": Color("8c45c9"), &"emission": 1.2},
}
const EFFECT_RECIPES := {
	&"fire_impact": {&"color": Color("ff6b35"), &"radius": 0.70, &"duration": 0.32},
	&"frost_impact": {&"color": Color("8ee8ff"), &"radius": 0.85, &"duration": 0.38},
	&"lightning_impact": {&"color": Color("fff08a"), &"radius": 0.55, &"duration": 0.24},
	&"healing_blessing": {&"color": Color("ffe891"), &"radius": 0.80, &"duration": 0.45},
	&"chaos_impact": {&"color": Color("8c45c9"), &"radius": 0.72, &"duration": 0.50},
}

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PROJECTILE_ROOT))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EFFECT_ROOT))
	for id: StringName in PROJECTILE_RECIPES:
		if not _save_scene(_build_projectile(id, PROJECTILE_RECIPES[id]), "%s/%s.tscn" % [PROJECTILE_ROOT, id]):
			return
	for id: StringName in EFFECT_RECIPES:
		if not _save_scene(_build_effect(id, EFFECT_RECIPES[id]), "%s/%s.tscn" % [EFFECT_ROOT, id]):
			return
	print("COMBAT_PRESENTATION_BUILD_OK projectiles=%d effects=%d" % [PROJECTILE_RECIPES.size(), EFFECT_RECIPES.size()])
	quit(0)

func _build_projectile(id: StringName, recipe: Dictionary) -> Node3D:
	var root := PROJECTILE_SCRIPT.new() as Node3D
	root.name = StringName(String(id).to_pascal_case())
	var material := _material(recipe[&"color"], float(recipe.get(&"emission", 0.0)))
	match recipe[&"shape"]:
		&"arrow":
			_add_arrow(root, float(recipe[&"length"]), float(recipe[&"radius"]), material)
		&"orb":
			_add_orb(root, float(recipe[&"radius"]), material)
		&"shard":
			_add_shard(root, float(recipe[&"length"]), float(recipe[&"radius"]), material)
		&"bolt":
			_add_bolt(root, float(recipe[&"length"]), float(recipe[&"radius"]), material)
	return root

func _build_effect(id: StringName, recipe: Dictionary) -> Node3D:
	var root := EFFECT_SCRIPT.new() as PresentationEffect
	root.name = StringName(String(id).to_pascal_case())
	root.effect_color = recipe[&"color"]
	root.duration = float(recipe[&"duration"])
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = &"EffectMesh"
	var sphere := SphereMesh.new()
	sphere.radius = float(recipe[&"radius"])
	sphere.height = float(recipe[&"radius"]) * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	mesh_instance.mesh = sphere
	mesh_instance.material_override = _material(recipe[&"color"], 1.25, 0.68)
	root.add_child(mesh_instance)
	return root

func _add_arrow(root: Node3D, length: float, radius: float, material: StandardMaterial3D) -> void:
	var shaft := MeshInstance3D.new()
	shaft.name = &"Shaft"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = length * 0.78
	cylinder.radial_segments = 8
	shaft.mesh = cylinder
	shaft.material_override = material
	shaft.rotation.x = PI / 2.0
	root.add_child(shaft)
	var tip := MeshInstance3D.new()
	tip.name = &"Tip"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = radius * 2.2
	cone.height = length * 0.22
	cone.radial_segments = 8
	tip.mesh = cone
	tip.material_override = material
	tip.position.z = -length * 0.5
	tip.rotation.x = -PI / 2.0
	root.add_child(tip)

func _add_orb(root: Node3D, radius: float, material: StandardMaterial3D) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = &"Orb"
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	mesh_instance.mesh = sphere
	mesh_instance.material_override = material
	root.add_child(mesh_instance)

func _add_shard(root: Node3D, length: float, radius: float, material: StandardMaterial3D) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = &"Shard"
	var prism := PrismMesh.new()
	prism.size = Vector3(radius * 2.0, radius * 2.0, length)
	mesh_instance.mesh = prism
	mesh_instance.material_override = material
	root.add_child(mesh_instance)

func _add_bolt(root: Node3D, length: float, radius: float, material: StandardMaterial3D) -> void:
	for index: int in 3:
		var segment := MeshInstance3D.new()
		segment.name = StringName("Segment%d" % index)
		var box := BoxMesh.new()
		box.size = Vector3(radius, radius, length / 3.0)
		segment.mesh = box
		segment.material_override = material
		segment.position = Vector3(radius * (1.0 if index % 2 == 0 else -1.0), 0.0, -length * (float(index) / 3.0 - 0.33))
		segment.rotation.y = 0.28 * (1.0 if index % 2 == 0 else -1.0)
		root.add_child(segment)

func _material(color: Color, emission: float = 0.0, alpha: float = 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	var albedo := color
	albedo.a = alpha
	material.albedo_color = albedo
	material.roughness = 0.72
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	return material

func _save_scene(root: Node3D, path: String) -> bool:
	_set_owners(root, root)
	var packed := PackedScene.new()
	if packed.pack(root) != OK or ResourceSaver.save(packed, path) != OK:
		root.free()
		_fail("save failed path=%s" % path)
		return false
	root.free()
	return _stabilize(path)

func _set_owners(node: Node, root: Node) -> void:
	for child: Node in node.get_children():
		child.owner = root
		_set_owners(child, root)

func _stabilize(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("read failed path=%s" % path)
		return false
	var text := file.get_as_text()
	var expression := RegEx.new()
	if expression.compile(" (unique_id=[0-9]+|uid=\"uid://[^\"]+\")") != OK:
		_fail("stabilize regex failed")
		return false
	text = expression.sub(text, "", true)
	file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("write failed path=%s" % path)
		return false
	file.store_string(text)
	return file.get_error() == OK

func _fail(reason: String) -> void:
	push_error("COMBAT_PRESENTATION_BUILD_ERROR reason=%s" % reason)
	quit(1)
