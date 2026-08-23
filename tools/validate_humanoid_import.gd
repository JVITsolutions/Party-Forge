extends SceneTree

const CONTRACT_SCRIPT := preload("res://scripts/presentation/humanoid_rig_contract.gd")
const DRIVER_SCRIPT := preload("res://scripts/presentation/legacy_pivot_skeleton_driver.gd")
const REGION_SCRIPT := preload("res://scripts/presentation/body_region_catalog.gd")
const ERROR_PREFIX := "PARTY_FORGE_HUMANOID_IMPORT_ERROR"
const OK_PREFIX := "PARTY_FORGE_HUMANOID_IMPORT_OK"
const MIN_HEIGHT := 1.60
const MAX_HEIGHT := 1.85
const GROUND_TOLERANCE := 0.001
const BODY_TRIANGLE_CAP := 10000
const BODY_MATERIAL_CAP := 4
const BODY_TEXTURE_SIZE_CAP := 2048
const MAX_TEXTURES_PER_MATERIAL := 4
const MAX_VERTEX_INFLUENCES := 4
const WEIGHT_TOLERANCE := 0.001
const MIN_INVERTIBLE_DETERMINANT := 0.000000000001
const SLOT_BONES := {
	&"helmet": &"Head",
	&"body_armour": &"Chest",
	&"legs": &"Hips",
	&"gloves": &"Hand.R",
	&"boots": &"Foot.R",
	&"amulet": &"Neck",
	&"ring_left": &"Hand.L",
	&"ring_right": &"Hand.R",
	&"belt": &"Hips",
	&"main_hand": &"Hand.R",
	&"off_hand": &"Hand.L",
}


class ImportReadinessService extends RefCounted:
	func validate_body_pair(masculine_scene: PackedScene, feminine_scene: PackedScene, rig: Resource) -> Dictionary:
		var errors: Array[String] = []
		if rig == null:
			errors.append(_error("request asset=rig reason=canonical rig resource is missing"))
			return _body_result(errors)
		var contract := CONTRACT_SCRIPT.new()
		for definition_error: String in contract.validate_definition(rig):
			errors.append(_error("canonical_resource asset=rig reason=%s" % definition_error))
		if not errors.is_empty():
			return _body_result(errors)

		var bodies := {}
		var scenes := {&"masculine": masculine_scene, &"feminine": feminine_scene}
		for body_id: StringName in [&"masculine", &"feminine"]:
			var scene := scenes[body_id] as PackedScene
			if scene == null:
				errors.append(_error("request asset=%s reason=scene is missing" % body_id))
				continue
			var instance := scene.instantiate()
			if not instance is Node3D:
				errors.append(_error("resource asset=%s reason=scene root must be Node3D" % body_id))
				if instance != null:
					instance.free()
				continue
			var body_errors: Array[String] = []
			var metrics := _validate_body(instance as Node3D, rig, body_id, body_errors)
			errors.append_array(body_errors)
			bodies[body_id] = metrics
			instance.free()

		if bodies.has(&"masculine") and bodies.has(&"feminine"):
			var masculine_signature := String((bodies[&"masculine"] as Dictionary).get(&"skin_bind_signature", ""))
			var feminine_signature := String((bodies[&"feminine"] as Dictionary).get(&"skin_bind_signature", ""))
			if not masculine_signature.is_empty() and not feminine_signature.is_empty() and masculine_signature != feminine_signature:
				errors.append(_error("signatures asset=bodies reason=masculine and feminine Skin bind signatures differ"))
		return _body_result(errors, bodies, rig)


	func validate_shared_item_scene(scene: PackedScene, rig: Resource, active_roots: Array, expected_bind_signature: String, budgets: Dictionary) -> Dictionary:
		var errors: Array[String] = []
		if scene == null:
			errors.append(_error("shared_item reason=scene is missing"))
		if rig == null:
			errors.append(_error("shared_item reason=canonical rig resource is missing"))
		if active_roots.is_empty():
			errors.append(_error("shared_item reason=active roots are empty"))
		if expected_bind_signature.is_empty():
			errors.append(_error("shared_item reason=expected Skin bind signature is missing"))
		var max_triangles := _positive_budget(budgets, &"max_triangles", errors)
		var max_materials := _positive_budget(budgets, &"max_materials", errors)
		var max_texture_size := _positive_budget(budgets, &"max_texture_size", errors)
		if not errors.is_empty():
			return _shared_result(errors)

		var instance := scene.instantiate()
		if not instance is Node3D:
			errors.append(_error("shared_item reason=scene root must be Node3D"))
			if instance != null:
				instance.free()
			return _shared_result(errors)
		var root := instance as Node3D
		var selected_roots: Array[Node3D] = []
		var normalized_paths: Array[NodePath] = []
		for path_value: Variant in active_roots:
			var path := path_value as NodePath if path_value is NodePath else NodePath(String(path_value))
			if not _is_safe_relative_node_path(path):
				errors.append(_error("shared_item root=%s reason=active root path must be normalized and relative" % path))
				continue
			if path in normalized_paths:
				errors.append(_error("shared_item root=%s reason=active root is duplicated" % path))
				continue
			normalized_paths.append(path)
			var selected := root.get_node_or_null(path)
			if not selected is Node3D:
				errors.append(_error("shared_item root=%s reason=active root is missing" % path))
				continue
			selected_roots.append(selected as Node3D)
		for left_index: int in selected_roots.size():
			for right_index: int in range(left_index + 1, selected_roots.size()):
				var left := selected_roots[left_index]
				var right := selected_roots[right_index]
				if left == right or left.is_ancestor_of(right) or right.is_ancestor_of(left):
					errors.append(_error("shared_item reason=active roots overlap"))
		if not errors.is_empty():
			root.free()
			return _shared_result(errors)

		var selected_meshes: Array[MeshInstance3D] = []
		var seen_meshes := {}
		for selected_root: Node3D in selected_roots:
			if _contains_type(selected_root, "Skeleton3D"):
				errors.append(_error("shared_item root=%s reason=installed active root contains Skeleton3D" % root.get_path_to(selected_root)))
			if _contains_type(selected_root, "AnimationPlayer"):
				errors.append(_error("shared_item root=%s reason=installed active root contains AnimationPlayer" % root.get_path_to(selected_root)))
			for mesh: MeshInstance3D in _meshes_including_root(selected_root):
				if not seen_meshes.has(mesh):
					seen_meshes[mesh] = true
					selected_meshes.append(mesh)
			if _meshes_including_root(selected_root).is_empty():
				errors.append(_error("shared_item root=%s reason=active root contains no MeshInstance3D" % root.get_path_to(selected_root)))

		var aggregate := _empty_metrics()
		var contract := CONTRACT_SCRIPT.new()
		for mesh: MeshInstance3D in selected_meshes:
			var source_skeleton := mesh.get_node_or_null(mesh.skeleton) as Skeleton3D if not mesh.skeleton.is_empty() else null
			if source_skeleton == null or not _skeleton_matches_rig(source_skeleton, rig):
				errors.append(_error("shared_item node=%s reason=source skeleton does not match canonical rig" % mesh.name))
			_validate_mesh(mesh, rig, expected_bind_signature, "shared_item", "", max_texture_size, aggregate, errors, contract)
		if int(aggregate[&"triangle_count"]) > max_triangles:
			errors.append(_error("shared_item reason=triangle count %d exceeds hard cap %d" % [int(aggregate[&"triangle_count"]), max_triangles]))
		if (aggregate[&"materials"] as Dictionary).size() > max_materials:
			errors.append(_error("shared_item reason=material count %d exceeds hard cap %d" % [(aggregate[&"materials"] as Dictionary).size(), max_materials]))
		root.free()
		return _shared_result(
			errors,
			selected_roots.size(),
			selected_meshes.size(),
			int(aggregate[&"triangle_count"]),
			(aggregate[&"materials"] as Dictionary).size(),
			(aggregate[&"textures"] as Dictionary).size(),
			expected_bind_signature
		)


	func _validate_body(root: Node3D, rig: Resource, body_id: StringName, errors: Array[String]) -> Dictionary:
		_validate_transforms(root, body_id, errors)
		var skeletons := _nodes_of_type(root, "Skeleton3D")
		var skeleton := skeletons[0] as Skeleton3D if skeletons.size() == 1 else null
		if skeletons.size() != 1:
			errors.append(_error("canonical_rig asset=%s reason=requires exactly one Skeleton3D" % body_id))
		if skeleton != null:
			var contract := CONTRACT_SCRIPT.new()
			for rig_error: String in contract.validate_rig(rig, skeleton, root):
				errors.append(_error("canonical_rig asset=%s reason=%s" % [body_id, rig_error]))
		_validate_driver(root, skeleton, rig, body_id, errors)
		_validate_semantic_sockets(root, skeleton, body_id, errors)
		var region_catalog := REGION_SCRIPT.new()
		for region_error: String in region_catalog.validate_body_root(root):
			errors.append(_error("body_regions asset=%s reason=%s" % [body_id, region_error]))
		var region_meshes: Array[MeshInstance3D] = region_catalog.region_nodes(root)
		var aggregate := _empty_metrics()
		var contract := CONTRACT_SCRIPT.new()
		var observed_skin_signatures := {}
		for mesh: MeshInstance3D in region_meshes:
			if skeleton != null and (mesh.skeleton.is_empty() or mesh.get_node_or_null(mesh.skeleton) != skeleton):
				errors.append(_error("skin asset=%s node=%s reason=mesh must target the body's canonical Skeleton3D" % [body_id, mesh.name]))
			var signature := ""
			if mesh.skin != null:
				signature = contract.skin_bind_signature(rig, mesh.skin)
				observed_skin_signatures[signature] = true
			_validate_mesh(mesh, rig, "", "body", String(body_id), BODY_TEXTURE_SIZE_CAP, aggregate, errors, contract)
		if observed_skin_signatures.size() > 1:
			errors.append(_error("signatures asset=%s reason=body regions do not share one exact Skin bind signature" % body_id))
		if int(aggregate[&"triangle_count"]) > BODY_TRIANGLE_CAP:
			errors.append(_error("geometry asset=%s reason=triangle count %d exceeds hard cap %d" % [body_id, int(aggregate[&"triangle_count"]), BODY_TRIANGLE_CAP]))
		if (aggregate[&"materials"] as Dictionary).size() > BODY_MATERIAL_CAP:
			errors.append(_error("materials asset=%s reason=material count %d exceeds hard cap %d" % [body_id, (aggregate[&"materials"] as Dictionary).size(), BODY_MATERIAL_CAP]))
		var min_y := float(aggregate[&"min_y"])
		var max_y := float(aggregate[&"max_y"])
		var height := max_y - min_y if bool(aggregate[&"has_vertex"]) else 0.0
		if not bool(aggregate[&"has_vertex"]):
			errors.append(_error("bounds asset=%s reason=body has no finite visible vertices" % body_id))
		else:
			if height < MIN_HEIGHT or height > MAX_HEIGHT:
				errors.append(_error("bounds asset=%s reason=visible height %.6f is outside %.6f..%.6f" % [body_id, height, MIN_HEIGHT, MAX_HEIGHT]))
			if absf(min_y) > GROUND_TOLERANCE:
				errors.append(_error("bounds asset=%s reason=ground Y %.6f exceeds tolerance %.6f" % [body_id, min_y, GROUND_TOLERANCE]))
		var skin_signature := ""
		if observed_skin_signatures.size() == 1:
			skin_signature = String(observed_skin_signatures.keys()[0])
		return {
			&"region_count": region_meshes.size(),
			&"triangle_count": int(aggregate[&"triangle_count"]),
			&"material_count": (aggregate[&"materials"] as Dictionary).size(),
			&"texture_count": (aggregate[&"textures"] as Dictionary).size(),
			&"height": height,
			&"ground_y": min_y,
			&"skin_bind_signature": skin_signature,
		}


	func _validate_driver(root: Node3D, skeleton: Skeleton3D, rig: Resource, body_id: StringName, errors: Array[String]) -> void:
		var drivers: Array[Node] = []
		for node: Node in _all_nodes(root):
			if node.get_script() == DRIVER_SCRIPT:
				drivers.append(node)
		if drivers.size() != 1:
			errors.append(_error("pivot_driver asset=%s reason=requires exactly one LegacyPivotSkeletonDriver" % body_id))
			return
		var driver := drivers[0]
		if skeleton == null or driver.get_parent() != skeleton:
			errors.append(_error("pivot_driver asset=%s reason=driver must be a direct child of the canonical Skeleton3D" % body_id))
		if driver.get("rig_definition") != rig:
			errors.append(_error("pivot_driver asset=%s reason=driver must reference the supplied canonical rig resource" % body_id))
		if driver.get("pivot_root") != root:
			errors.append(_error("pivot_driver asset=%s reason=pivot root must be the body scene root" % body_id))
		if not is_equal_approx(float(driver.get("influence")), 1.0):
			errors.append(_error("pivot_driver asset=%s reason=driver influence must be exactly 1" % body_id))


	func _validate_semantic_sockets(root: Node3D, skeleton: Skeleton3D, body_id: StringName, errors: Array[String]) -> void:
		var semantic_roots: Array[Node] = []
		for child: Node in root.get_children():
			if child.name == &"SemanticSockets":
				semantic_roots.append(child)
		if semantic_roots.size() != 1 or not semantic_roots[0] is Node3D:
			errors.append(_error("semantic_sockets asset=%s reason=requires one direct Node3D named SemanticSockets" % body_id))
			return
		var semantic_root := semantic_roots[0] as Node3D
		for slot_id: StringName in SLOT_BONES:
			var matches: Array[Node] = []
			for child: Node in semantic_root.get_children():
				if child.name == slot_id:
					matches.append(child)
			if matches.size() != 1 or not matches[0] is BoneAttachment3D:
				errors.append(_error("semantic_sockets asset=%s reason=socket %s must exist exactly once" % [body_id, slot_id]))
				continue
			var socket := matches[0] as BoneAttachment3D
			if socket.bone_name != SLOT_BONES[slot_id]:
				errors.append(_error("semantic_sockets asset=%s reason=socket %s must map to canonical bone %s" % [body_id, slot_id, SLOT_BONES[slot_id]]))
			if skeleton == null or not socket.use_external_skeleton or socket.get_node_or_null(socket.external_skeleton) != skeleton:
				errors.append(_error("semantic_sockets asset=%s reason=socket %s must target the body canonical Skeleton3D" % [body_id, slot_id]))


	func _validate_transforms(root: Node3D, body_id: StringName, errors: Array[String]) -> void:
		for node: Node in _all_nodes(root):
			if node is Node3D and not _transform_is_usable((node as Node3D).transform):
				errors.append(_error("transforms asset=%s node=%s reason=transform is non-finite or non-invertible" % [body_id, node.name]))


	func _validate_mesh(mesh_instance: MeshInstance3D, rig: Resource, expected_signature: String, stage: String, asset: String, max_texture_size: int, aggregate: Dictionary, errors: Array[String], contract: RefCounted) -> void:
		var identity := ""
		if not asset.is_empty():
			identity += " asset=%s" % asset
		identity += " node=%s" % mesh_instance.name
		if mesh_instance.skin == null:
			errors.append(_error("%s%s reason=Skin is missing" % [_mesh_stage(stage, "skin"), identity]))
		else:
			for skin_error: String in contract.call(&"validate_skin", rig, mesh_instance.skin):
				errors.append(_error("%s%s reason=%s" % [_mesh_stage(stage, "skin"), identity, skin_error]))
			if not expected_signature.is_empty() and contract.call(&"skin_bind_signature", rig, mesh_instance.skin) != expected_signature:
				errors.append(_error("%s%s reason=Skin bind signature mismatch" % [_mesh_stage(stage, "skin"), identity]))
		var mesh := mesh_instance.mesh
		if mesh == null or mesh.get_surface_count() == 0:
			errors.append(_error("%s%s reason=mesh has no surfaces" % [_mesh_stage(stage, "geometry"), identity]))
			return
		var mesh_transform := _node_world_transform(mesh_instance)
		for surface_index: int in mesh.get_surface_count():
			var surface_identity := "%s surface=%d" % [identity, surface_index]
			if mesh.surface_get_primitive_type(surface_index) != Mesh.PRIMITIVE_TRIANGLES:
				errors.append(_error("%s%s reason=surface primitive must be triangles" % [_mesh_stage(stage, "geometry"), surface_identity]))
				continue
			var arrays := mesh.surface_get_arrays(surface_index)
			if arrays.size() != Mesh.ARRAY_MAX:
				errors.append(_error("%s%s reason=surface arrays are malformed" % [_mesh_stage(stage, "geometry"), surface_identity]))
				continue
			var vertices_value: Variant = arrays[Mesh.ARRAY_VERTEX]
			var vertices: PackedVector3Array = vertices_value if vertices_value is PackedVector3Array else PackedVector3Array()
			var indices_value: Variant = arrays[Mesh.ARRAY_INDEX]
			var indices: PackedInt32Array = indices_value if indices_value is PackedInt32Array else PackedInt32Array()
			var triangle_count := indices.size() / 3 if not indices.is_empty() else vertices.size() / 3
			aggregate[&"triangle_count"] = int(aggregate[&"triangle_count"]) + triangle_count
			for vertex: Vector3 in vertices:
				var transformed := mesh_transform * vertex
				if not transformed.is_finite():
					errors.append(_error("%s%s reason=vertex position is non-finite" % [_mesh_stage(stage, "geometry"), surface_identity]))
					continue
				aggregate[&"has_vertex"] = true
				aggregate[&"min_y"] = minf(float(aggregate[&"min_y"]), transformed.y)
				aggregate[&"max_y"] = maxf(float(aggregate[&"max_y"]), transformed.y)
			var normals_value: Variant = arrays[Mesh.ARRAY_NORMAL]
			var normals: PackedVector3Array = normals_value if normals_value is PackedVector3Array else PackedVector3Array()
			if normals.size() != vertices.size():
				errors.append(_error("%s%s reason=normals are missing or malformed" % [_mesh_stage(stage, "geometry"), surface_identity]))
			else:
				for normal: Vector3 in normals:
					if not normal.is_finite():
						errors.append(_error("%s%s reason=normal is non-finite" % [_mesh_stage(stage, "geometry"), surface_identity]))
						break
			var tangents_value: Variant = arrays[Mesh.ARRAY_TANGENT]
			var tangents: PackedFloat32Array = tangents_value if tangents_value is PackedFloat32Array else PackedFloat32Array()
			if tangents.size() != vertices.size() * 4:
				errors.append(_error("%s%s reason=tangents are missing or malformed" % [_mesh_stage(stage, "geometry"), surface_identity]))
			else:
				for vertex_index: int in vertices.size():
					var tangent := Vector3(tangents[vertex_index * 4], tangents[vertex_index * 4 + 1], tangents[vertex_index * 4 + 2])
					var handedness := tangents[vertex_index * 4 + 3]
					if not tangent.is_finite() or not is_finite(handedness) or tangent.length_squared() <= 0.000000000001:
						errors.append(_error("%s%s reason=tangents are missing or malformed" % [_mesh_stage(stage, "geometry"), surface_identity]))
						break
			var uv_value: Variant = arrays[Mesh.ARRAY_TEX_UV]
			var uv: PackedVector2Array = uv_value if uv_value is PackedVector2Array else PackedVector2Array()
			if uv.size() != vertices.size():
				errors.append(_error("%s%s reason=UV0 is missing" % [_mesh_stage(stage, "geometry"), surface_identity]))
			_validate_weights(vertices, arrays, mesh_instance, stage, asset, errors)
			var material := _surface_material(mesh_instance, surface_index)
			if not material is StandardMaterial3D:
				errors.append(_error("%s%s reason=surface material must be StandardMaterial3D" % [_mesh_stage(stage, "materials"), surface_identity]))
				continue
			(aggregate[&"materials"] as Dictionary)[material.get_instance_id()] = true
			_validate_material_textures(material as StandardMaterial3D, stage, asset, max_texture_size, aggregate, errors)


	func _validate_weights(vertices: PackedVector3Array, arrays: Array, mesh_instance: MeshInstance3D, stage: String, asset: String, errors: Array[String]) -> void:
		var identity := ""
		if not asset.is_empty(): identity += " asset=%s" % asset
		identity += " node=%s" % mesh_instance.name
		var bones_value: Variant = arrays[Mesh.ARRAY_BONES]
		var bones: PackedInt32Array = bones_value if bones_value is PackedInt32Array else PackedInt32Array()
		var weights_value: Variant = arrays[Mesh.ARRAY_WEIGHTS]
		var weights: PackedFloat32Array = weights_value if weights_value is PackedFloat32Array else PackedFloat32Array()
		if vertices.is_empty() or bones.size() != weights.size() or weights.is_empty() or weights.size() % vertices.size() != 0:
			errors.append(_error("%s%s reason=vertex weights are missing or malformed" % [_mesh_stage(stage, "skinning"), identity]))
			return
		var influences_per_vertex := weights.size() / vertices.size()
		for vertex_index: int in vertices.size():
			var total := 0.0
			var positive_influences := 0
			var invalid := false
			for influence_index: int in influences_per_vertex:
				var array_index := vertex_index * influences_per_vertex + influence_index
				var weight := weights[array_index]
				if not is_finite(weight) or weight < 0.0:
					errors.append(_error("%s%s vertex=%d reason=weight is non-finite or negative" % [_mesh_stage(stage, "skinning"), identity, vertex_index]))
					invalid = true
					break
				if weight > 0.000001:
					positive_influences += 1
					if mesh_instance.skin == null or bones[array_index] < 0 or bones[array_index] >= mesh_instance.skin.get_bind_count():
						errors.append(_error("%s%s vertex=%d reason=weight references an unknown Skin bind" % [_mesh_stage(stage, "skinning"), identity, vertex_index]))
				total += weight
			if invalid:
				continue
			if positive_influences == 0:
				errors.append(_error("%s%s vertex=%d reason=vertex is unweighted" % [_mesh_stage(stage, "skinning"), identity, vertex_index]))
			elif positive_influences > MAX_VERTEX_INFLUENCES:
				errors.append(_error("%s%s vertex=%d reason=uses %d influences; maximum is %d" % [_mesh_stage(stage, "skinning"), identity, vertex_index, positive_influences, MAX_VERTEX_INFLUENCES]))
			if positive_influences > 0 and absf(total - 1.0) > WEIGHT_TOLERANCE:
				errors.append(_error("%s%s vertex=%d reason=weights total %.6f is not normalized" % [_mesh_stage(stage, "skinning"), identity, vertex_index, total]))


	func _validate_material_textures(material: StandardMaterial3D, stage: String, asset: String, max_texture_size: int, aggregate: Dictionary, errors: Array[String]) -> void:
		var texture_count := 0
		for texture_slot: int in BaseMaterial3D.TEXTURE_MAX:
			var texture := material.get_texture(texture_slot as BaseMaterial3D.TextureParam)
			if texture == null:
				continue
			texture_count += 1
			var textures := aggregate[&"textures"] as Dictionary
			if textures.has(texture.get_instance_id()):
				continue
			textures[texture.get_instance_id()] = true
			if texture.get_width() > max_texture_size or texture.get_height() > max_texture_size:
				var detail := _mesh_stage(stage, "materials")
				if not asset.is_empty():
					detail += " asset=%s" % asset
				errors.append(_error("%s reason=texture exceeds %dpx" % [detail, max_texture_size]))
		if texture_count > MAX_TEXTURES_PER_MATERIAL:
			var detail := _mesh_stage(stage, "materials")
			if not asset.is_empty():
				detail += " asset=%s" % asset
			errors.append(_error("%s reason=material uses %d textures; maximum is %d" % [detail, texture_count, MAX_TEXTURES_PER_MATERIAL]))


	func _skeleton_matches_rig(skeleton: Skeleton3D, rig: Resource) -> bool:
		if skeleton == null or skeleton.get_bone_count() != rig.bone_names.size():
			return false
		for index: int in rig.roles.size():
			var matches: Array[int] = []
			for bone_index: int in skeleton.get_bone_count():
				if skeleton.get_bone_name(bone_index) == rig.bone_names[index]:
					matches.append(bone_index)
			if matches.size() != 1:
				return false
			var actual_index := matches[0]
			var expected_parent := -1
			var parent_role: StringName = rig.parent_roles[index]
			if not parent_role.is_empty():
				expected_parent = rig.roles.find(parent_role)
			if skeleton.get_bone_parent(actual_index) != expected_parent:
				return false
			if not skeleton.get_bone_rest(actual_index).is_equal_approx(rig.canonical_rests[index]):
				return false
		return true


	func _mesh_stage(mode: String, category: String) -> String:
		return "shared_item" if mode == "shared_item" else category


	func _body_result(errors: Array[String], bodies: Dictionary = {}, rig: Resource = null) -> Dictionary:
		var unique := _ordered_errors(errors)
		var skin_signature := ""
		if bodies.has(&"masculine"):
			skin_signature = String((bodies[&"masculine"] as Dictionary).get(&"skin_bind_signature", ""))
		return {
			&"ok": unique.is_empty(),
			&"errors": unique,
			&"bodies": bodies,
			&"topology_signature": String(rig.topology_signature) if rig != null else "",
			&"canonical_rest_signature": String(rig.canonical_rest_signature) if rig != null else "",
			&"skin_bind_signature": skin_signature,
		}


	func _shared_result(errors: Array[String], active_root_count: int = 0, mesh_count: int = 0, triangle_count: int = 0, material_count: int = 0, texture_count: int = 0, skin_signature: String = "") -> Dictionary:
		var unique := _ordered_errors(errors)
		return {
			&"ok": unique.is_empty(),
			&"errors": unique,
			&"active_root_count": active_root_count,
			&"mesh_count": mesh_count,
			&"triangle_count": triangle_count,
			&"material_count": material_count,
			&"texture_count": texture_count,
			&"skin_bind_signature": skin_signature,
		}


	func _positive_budget(budgets: Dictionary, field: StringName, errors: Array[String]) -> int:
		var value: Variant = budgets.get(field)
		if typeof(value) != TYPE_INT or int(value) <= 0:
			errors.append(_error("shared_item budget=%s reason=must be a positive integer" % field))
			return 0
		return int(value)


	func _empty_metrics() -> Dictionary:
		return {
			&"triangle_count": 0,
			&"materials": {},
			&"textures": {},
			&"has_vertex": false,
			&"min_y": INF,
			&"max_y": -INF,
		}


	func _surface_material(mesh: MeshInstance3D, surface_index: int) -> Material:
		if mesh.material_override != null:
			return mesh.material_override
		var material := mesh.get_surface_override_material(surface_index)
		if material != null:
			return material
		return mesh.mesh.surface_get_material(surface_index)


	func _node_world_transform(node: Node3D) -> Transform3D:
		var result := Transform3D.IDENTITY
		var cursor: Node = node
		while cursor != null:
			if cursor is Node3D:
				result = (cursor as Node3D).transform * result
			cursor = cursor.get_parent()
		return result


	func _transform_is_usable(value: Transform3D) -> bool:
		return value.origin.is_finite() and value.basis.x.is_finite() and value.basis.y.is_finite() and value.basis.z.is_finite() and absf(value.basis.determinant()) > MIN_INVERTIBLE_DETERMINANT


	func _nodes_of_type(root: Node, type_name: String) -> Array[Node]:
		var result: Array[Node] = []
		for node: Node in _all_nodes(root):
			if node.is_class(type_name):
				result.append(node)
		return result


	func _all_nodes(root: Node) -> Array[Node]:
		var result: Array[Node] = [root]
		result.append_array(root.find_children("*", "", true, false))
		return result


	func _contains_type(root: Node, type_name: String) -> bool:
		for node: Node in _all_nodes(root):
			if node.is_class(type_name):
				return true
		return false


	func _meshes_including_root(root: Node) -> Array[MeshInstance3D]:
		var meshes: Array[MeshInstance3D] = []
		for node: Node in _all_nodes(root):
			if node is MeshInstance3D:
				meshes.append(node as MeshInstance3D)
		return meshes


	func _is_safe_relative_node_path(path: NodePath) -> bool:
		if path.is_empty() or path.is_absolute():
			return false
		for index: int in path.get_name_count():
			if String(path.get_name(index)) in ["", ".", ".."]:
				return false
		return true


	func _ordered_errors(errors: Array[String]) -> PackedStringArray:
		var sorted := errors.duplicate()
		sorted.sort()
		var unique := PackedStringArray()
		for value: String in sorted:
			if value not in unique:
				unique.append(value)
		return unique


	func _error(detail: String) -> String:
		return "%s stage=%s" % [ERROR_PREFIX, detail]


func _initialize() -> void:
	quit(run_cli(OS.get_cmdline_user_args(), Callable(self, &"_load_resource"), Callable(self, &"_print_line")))


func new_service() -> RefCounted:
	return ImportReadinessService.new()


func run_cli(arguments: PackedStringArray, loader: Callable, output: Callable) -> int:
	var parsed := parse_named_args(arguments)
	var errors := parsed.get(&"errors", PackedStringArray()) as PackedStringArray
	if not errors.is_empty():
		_emit(errors, output)
		return 1
	var masculine_path := String(parsed[&"masculine_scene"])
	var feminine_path := String(parsed[&"feminine_scene"])
	var rig_path := String(parsed[&"rig"])
	var masculine := loader.call(masculine_path) as PackedScene
	var feminine := loader.call(feminine_path) as PackedScene
	var rig := loader.call(rig_path) as Resource
	var load_errors := PackedStringArray()
	if masculine == null:
		load_errors.append("%s stage=resource asset=masculine path=%s reason=missing or unloadable PackedScene" % [ERROR_PREFIX, masculine_path])
	if feminine == null:
		load_errors.append("%s stage=resource asset=feminine path=%s reason=missing or unloadable PackedScene" % [ERROR_PREFIX, feminine_path])
	if rig == null:
		load_errors.append("%s stage=resource asset=rig path=%s reason=missing or unloadable Resource" % [ERROR_PREFIX, rig_path])
	if not load_errors.is_empty():
		_emit(load_errors, output)
		return 1
	var result := ImportReadinessService.new().validate_body_pair(masculine, feminine, rig)
	if not bool(result.get(&"ok", false)):
		_emit(result.get(&"errors", PackedStringArray()) as PackedStringArray, output)
		return 1
	var bodies := result[&"bodies"] as Dictionary
	var masculine_metrics := bodies[&"masculine"] as Dictionary
	var feminine_metrics := bodies[&"feminine"] as Dictionary
	output.call("%s masculine_regions=%d masculine_triangles=%d feminine_regions=%d feminine_triangles=%d topology_signature=%s canonical_rest_signature=%s skin_bind_signature=%s" % [
		OK_PREFIX,
		int(masculine_metrics[&"region_count"]),
		int(masculine_metrics[&"triangle_count"]),
		int(feminine_metrics[&"region_count"]),
		int(feminine_metrics[&"triangle_count"]),
		String(result[&"topology_signature"]),
		String(result[&"canonical_rest_signature"]),
		String(result[&"skin_bind_signature"]),
	])
	return 0


func parse_named_args(arguments: PackedStringArray) -> Dictionary:
	var values := {&"masculine_scene": "", &"feminine_scene": "", &"rig": ""}
	var names := {
		"--masculine-scene": &"masculine_scene",
		"--feminine-scene": &"feminine_scene",
		"--rig": &"rig",
	}
	var errors: Array[String] = []
	var index := 0
	while index < arguments.size():
		var argument := arguments[index]
		var name := argument.get_slice("=", 0) if "=" in argument else argument
		if not names.has(name):
			errors.append("%s stage=request argument=%s reason=unknown; validator is read-only" % [ERROR_PREFIX, name])
			index += 1
			continue
		var key: StringName = names[name]
		var value := argument.trim_prefix("%s=" % name) if argument.begins_with("%s=" % name) else ""
		if value.is_empty() and argument == name and index + 1 < arguments.size() and not arguments[index + 1].begins_with("--"):
			value = arguments[index + 1]
			index += 1
		if value.is_empty():
			errors.append("%s stage=request argument=%s reason=value required" % [ERROR_PREFIX, name])
		elif not String(values[key]).is_empty():
			errors.append("%s stage=request argument=%s reason=duplicate" % [ERROR_PREFIX, name])
		else:
			values[key] = value
		index += 1
	for name: String in names:
		var key: StringName = names[name]
		var value := String(values[key])
		if value.is_empty():
			errors.append("%s stage=request argument=%s reason=required" % [ERROR_PREFIX, name])
		elif not _is_normalized_res_path(value):
			errors.append("%s stage=request argument=%s reason=must be a normalized res:// path" % [ERROR_PREFIX, name])
	errors.sort()
	var unique := PackedStringArray()
	for error: String in errors:
		if error not in unique:
			unique.append(error)
	values[&"errors"] = unique
	return values


func _is_normalized_res_path(path: String) -> bool:
	if not path.begins_with("res://") or "\\" in path or _has_control_character(path):
		return false
	var relative := path.trim_prefix("res://")
	if relative.is_empty():
		return false
	var segments := relative.split("/", true)
	return not segments.has("") and not segments.has(".") and not segments.has("..")


func _has_control_character(value: String) -> bool:
	for index: int in value.length():
		var codepoint := value.unicode_at(index)
		if codepoint < 32 or (codepoint >= 127 and codepoint <= 159) or codepoint in [0x2028, 0x2029]:
			return true
	return false


func _load_resource(path: String) -> Resource:
	return ResourceLoader.load(path)


func _print_line(value: String) -> void:
	print(value)


func _emit(lines: PackedStringArray, output: Callable) -> void:
	for line: String in lines:
		output.call(line)
