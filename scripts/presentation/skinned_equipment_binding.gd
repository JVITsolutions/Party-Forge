class_name SkinnedEquipmentBinding
extends RefCounted

const HumanoidRigContractScript := preload("res://scripts/presentation/humanoid_rig_contract.gd")
const CANONICAL_RIG := preload("res://data/presentation/humanoid_rigs/pf_humanoid_v1.tres")
const CANDIDATE_META: StringName = &"shared_skin_candidate"
const MIN_WEIGHT := 0.000001

func stage_candidate(actor_root: Node3D, actor_skeleton: Skeleton3D, definition: EquipmentVisualDefinition, descriptor: EquipmentBodyFitDescriptor) -> Dictionary:
	var errors := PackedStringArray()
	_validate_actor_contract(actor_root, actor_skeleton, definition, descriptor, errors)
	if not errors.is_empty():
		return _failure(errors)
	var source_root := descriptor.presentation_scene.instantiate() as Node3D
	if source_root == null:
		errors.append("shared-skinned equipment scene did not instance as Node3D")
		return _failure(errors)
	var candidate := Node3D.new()
	candidate.name = StringName("SharedSkin_%s" % definition.id)
	candidate.visible = false
	candidate.set_meta(CANDIDATE_META, true)
	var staged_source_meshes: Dictionary = {}
	for root_path: NodePath in descriptor.mesh_root_paths:
		var selected_root := source_root.get_node_or_null(root_path) as Node3D
		if selected_root == null:
			errors.append("shared-skinned equipment mesh root %s is missing" % root_path)
			continue
		if _contains_skeleton(selected_root):
			errors.append("shared-skinned equipment mesh root %s contains a residual duplicate rig" % root_path)
			continue
		var source_meshes := _meshes_including_root(selected_root)
		if source_meshes.is_empty():
			errors.append("shared-skinned equipment mesh root %s contains no MeshInstance3D" % root_path)
			continue
		var stage_parent := candidate
		if not selected_root is MeshInstance3D:
			stage_parent = Node3D.new()
			stage_parent.name = selected_root.name
			stage_parent.transform = _relative_transform(source_root, selected_root)
			candidate.add_child(stage_parent)
		for source_mesh: MeshInstance3D in source_meshes:
			if staged_source_meshes.has(source_mesh):
				errors.append("shared-skinned equipment descriptor mesh roots overlap at %s" % source_root.get_path_to(source_mesh))
				continue
			staged_source_meshes[source_mesh] = true
			_validate_source_mesh(source_mesh, definition, errors)
			if not errors.is_empty():
				continue
			var staged_mesh := _duplicate_mesh_instance(source_mesh)
			staged_mesh.transform = _relative_transform(selected_root, source_mesh) if stage_parent != candidate else _relative_transform(source_root, source_mesh)
			stage_parent.add_child(staged_mesh)
	source_root.free()
	if not errors.is_empty() or candidate.find_children("*", "MeshInstance3D", true, false).is_empty():
		candidate.free()
		if errors.is_empty():
			errors.append("shared-skinned equipment staged no meshes")
		return _failure(errors)
	actor_root.add_child(candidate)
	for node: Node in candidate.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.skeleton = mesh.get_path_to(actor_skeleton)
		if mesh.get_node_or_null(mesh.skeleton) != actor_skeleton:
			errors.append("shared-skinned equipment mesh %s does not resolve to actor canonical Skeleton3D" % mesh.name)
	if _contains_skeleton(candidate) or not candidate.find_children("*", "AnimationPlayer", true, false).is_empty():
		errors.append("shared-skinned equipment candidate retains a duplicate rig or animation")
	if not errors.is_empty():
		candidate.free()
		return _failure(errors)
	return {&"ok": true, &"root": candidate, &"errors": PackedStringArray()}

func _validate_actor_contract(actor_root: Node3D, actor_skeleton: Skeleton3D, definition: EquipmentVisualDefinition, descriptor: EquipmentBodyFitDescriptor, errors: PackedStringArray) -> void:
	if actor_root == null:
		errors.append("shared-skinned equipment actor root is missing")
		return
	if actor_skeleton == null or not actor_root.is_ancestor_of(actor_skeleton):
		errors.append("shared-skinned equipment actor canonical Skeleton3D is missing")
		return
	if definition == null or definition.attachment_mode != &"shared_skin":
		errors.append("shared-skinned equipment definition is missing or has the wrong attachment mode")
		return
	if descriptor == null or descriptor.presentation_scene == null or descriptor.mesh_root_paths.is_empty():
		errors.append("shared-skinned equipment active fit descriptor is incomplete")
		return
	var contract := HumanoidRigContractScript.new()
	errors.append_array(contract.validate_rig(CANONICAL_RIG, actor_skeleton, actor_root))
	if definition.rig_id != CANONICAL_RIG.rig_id:
		errors.append("shared-skinned equipment rig ID does not match canonical rig")
	if definition.skeleton_topology_signature != CANONICAL_RIG.topology_signature:
		errors.append("shared-skinned equipment topology signature mismatch")
	if definition.canonical_rest_signature != CANONICAL_RIG.canonical_rest_signature:
		errors.append("shared-skinned equipment canonical rest signature mismatch")
	if definition.skin_bind_signature.is_empty():
		errors.append("shared-skinned equipment Skin bind signature is missing")

func _validate_source_mesh(mesh: MeshInstance3D, definition: EquipmentVisualDefinition, errors: PackedStringArray) -> void:
	if mesh.skin == null:
		errors.append("shared-skinned equipment mesh %s is missing Skin" % mesh.name)
		return
	var contract := HumanoidRigContractScript.new()
	errors.append_array(contract.validate_skin(CANONICAL_RIG, mesh.skin))
	if contract.skin_bind_signature(CANONICAL_RIG, mesh.skin) != definition.skin_bind_signature:
		errors.append("shared-skinned equipment mesh %s Skin bind signature mismatch" % mesh.name)
	_validate_vertex_weights(mesh, errors)

func _validate_vertex_weights(mesh_instance: MeshInstance3D, errors: PackedStringArray) -> void:
	var mesh := mesh_instance.mesh
	if mesh == null or mesh.get_surface_count() == 0:
		errors.append("shared-skinned equipment mesh %s has no skinned mesh surfaces" % mesh_instance.name)
		return
	for surface_index: int in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface_index)
		if arrays.size() != Mesh.ARRAY_MAX:
			errors.append("shared-skinned equipment mesh %s surface %d has invalid arrays" % [mesh_instance.name, surface_index])
			continue
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		if vertices.is_empty() or bones.size() != weights.size() or weights.is_empty() or weights.size() % vertices.size() != 0:
			errors.append("shared-skinned equipment mesh %s surface %d has missing or malformed vertex weights" % [mesh_instance.name, surface_index])
			continue
		var influences_per_vertex := weights.size() / vertices.size()
		for vertex_index: int in vertices.size():
			var total_weight := 0.0
			for influence_index: int in influences_per_vertex:
				var array_index := vertex_index * influences_per_vertex + influence_index
				var weight := weights[array_index]
				if not is_finite(weight) or weight < 0.0:
					errors.append("shared-skinned equipment mesh %s vertex %d has an invalid weight" % [mesh_instance.name, vertex_index])
					break
				if weight > MIN_WEIGHT and (bones[array_index] < 0 or bones[array_index] >= mesh_instance.skin.get_bind_count()):
					errors.append("shared-skinned equipment mesh %s vertex %d references an unknown Skin bind" % [mesh_instance.name, vertex_index])
				total_weight += weight
			if total_weight <= MIN_WEIGHT:
				errors.append("shared-skinned equipment mesh %s vertex %d is unweighted" % [mesh_instance.name, vertex_index])

func _duplicate_mesh_instance(source: MeshInstance3D) -> MeshInstance3D:
	var duplicate := MeshInstance3D.new()
	duplicate.name = source.name
	duplicate.mesh = source.mesh.duplicate(true) as Mesh
	duplicate.skin = source.skin.duplicate(true) as Skin
	duplicate.visible = source.visible
	duplicate.cast_shadow = source.cast_shadow
	duplicate.layers = source.layers
	duplicate.extra_cull_margin = source.extra_cull_margin
	duplicate.ignore_occlusion_culling = source.ignore_occlusion_culling
	duplicate.visibility_range_begin = source.visibility_range_begin
	duplicate.visibility_range_end = source.visibility_range_end
	duplicate.visibility_range_begin_margin = source.visibility_range_begin_margin
	duplicate.visibility_range_end_margin = source.visibility_range_end_margin
	duplicate.visibility_range_fade_mode = source.visibility_range_fade_mode
	for meta_name: StringName in source.get_meta_list():
		duplicate.set_meta(meta_name, source.get_meta(meta_name))
	if source.material_override != null:
		duplicate.material_override = source.material_override.duplicate(true) as Material
	for surface_index: int in source.mesh.get_surface_count():
		var material := source.get_surface_override_material(surface_index)
		if material == null:
			material = source.mesh.surface_get_material(surface_index)
		if material != null:
			duplicate.set_surface_override_material(surface_index, material.duplicate(true) as Material)
	return duplicate

func _contains_skeleton(root: Node) -> bool:
	if root is Skeleton3D:
		return true
	return not root.find_children("*", "Skeleton3D", true, false).is_empty()

func _meshes_including_root(root: Node3D) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		meshes.append(root as MeshInstance3D)
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		meshes.append(node as MeshInstance3D)
	return meshes

func _relative_transform(root: Node3D, node: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var cursor: Node = node
	while cursor != null and cursor != root:
		if cursor is Node3D:
			result = (cursor as Node3D).transform * result
		cursor = cursor.get_parent()
	return result

func _failure(errors: PackedStringArray) -> Dictionary:
	return {&"ok": false, &"root": null, &"errors": errors}
