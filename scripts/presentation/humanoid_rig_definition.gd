class_name HumanoidRigDefinition
extends Resource

@export var rig_id: StringName
@export var roles: Array[StringName] = []
@export var bone_names: Array[StringName] = []
@export var parent_roles: Array[StringName] = []
@export var pivot_paths: Array[NodePath] = []
@export var canonical_rests: Array[Transform3D] = []
@export var topology_signature: String
@export var canonical_rest_signature: String
