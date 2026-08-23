class_name BodyRegionCatalog
extends RefCounted

const REGION_PREFIX := "BodyRegion__"
const REGION_IDS: Array[StringName] = [
	&"head", &"hair", &"neck", &"torso", &"upper_arm_left", &"upper_arm_right",
	&"forearm_left", &"forearm_right", &"hand_left", &"hand_right", &"hips",
	&"thigh_left", &"thigh_right", &"shin_left", &"shin_right", &"foot_left", &"foot_right",
]
const MAX_BODY_MATERIALS := 4

func canonical_region_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(REGION_IDS)
	return result

func has_imported_regions(body_root: Node) -> bool:
	if body_root == null:
		return false
	if String(body_root.name).begins_with(REGION_PREFIX):
		return true
	return not body_root.find_children("%s*" % REGION_PREFIX, "", true, false).is_empty()

func region_nodes(body_root: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if body_root == null:
		return result
	var candidates: Array[Node] = [body_root]
	candidates.append_array(body_root.find_children("%s*" % REGION_PREFIX, "", true, false))
	for node: Node in candidates:
		if String(node.name).begins_with(REGION_PREFIX) and node is MeshInstance3D:
			result.append(node as MeshInstance3D)
	return result

func region_id(node: Node) -> StringName:
	if node == null:
		return &""
	var node_name := String(node.name)
	if not node_name.begins_with(REGION_PREFIX):
		return &""
	return StringName(node_name.trim_prefix(REGION_PREFIX))

func validate_body_root(body_root: Node) -> PackedStringArray:
	var errors := PackedStringArray()
	if body_root == null:
		errors.append("body root is missing")
		return errors
	var prefixed_nodes: Array[Node] = []
	if String(body_root.name).begins_with(REGION_PREFIX):
		prefixed_nodes.append(body_root)
	prefixed_nodes.append_array(body_root.find_children("%s*" % REGION_PREFIX, "", true, false))
	var counts: Dictionary = {}
	var source_materials: Dictionary = {}
	for node: Node in prefixed_nodes:
		var id := region_id(node)
		if id not in REGION_IDS:
			errors.append("body region node %s has unknown region ID %s" % [node.name, id])
			continue
		counts[id] = int(counts.get(id, 0)) + 1
		if not node is MeshInstance3D:
			errors.append("body region %s is not MeshInstance3D" % id)
			continue
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.skin == null:
			errors.append("body region %s is not skinned" % id)
		if mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() == 0:
			errors.append("body region %s has no mesh surfaces" % id)
			continue
		for surface_index: int in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.material_override
			if material == null:
				material = mesh_instance.get_surface_override_material(surface_index)
			if material == null:
				material = mesh_instance.mesh.surface_get_material(surface_index)
			if material == null:
				errors.append("body region %s surface %d has no material" % [id, surface_index])
			elif not material is StandardMaterial3D:
				errors.append("body region %s surface %d uses unsupported material type" % [id, surface_index])
			else:
				source_materials[material.get_instance_id()] = true
	for id: StringName in REGION_IDS:
		var count := int(counts.get(id, 0))
		if count == 0:
			errors.append("body region %s is missing" % id)
		elif count > 1:
			errors.append("body region %s is duplicated" % id)
	if prefixed_nodes.size() != REGION_IDS.size():
		errors.append("body requires exactly %d named region nodes; found %d" % [REGION_IDS.size(), prefixed_nodes.size()])
	if source_materials.size() > MAX_BODY_MATERIALS:
		errors.append("body regions use %d source materials; maximum is %d" % [source_materials.size(), MAX_BODY_MATERIALS])
	return errors
