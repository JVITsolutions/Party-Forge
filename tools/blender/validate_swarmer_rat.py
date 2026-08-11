import bpy
import bmesh
import json
from mathutils import Vector


MESH_NAME = "MeshInstance3D"
RIG_NAME = "SwarmerRatRig"
EXPORT_COLLECTION = "PF_RAT_EXPORT"
REVIEW_COLLECTION = "PF_RAT_REVIEW"
EXPECTED_ACTIONS = {"idle_sniff", "scurry", "pounce_bite", "hit_react", "death_curl"}
EXPECTED_RANGES = {
    "idle_sniff": (1.0, 48.0),
    "scurry": (1.0, 16.0),
    "pounce_bite": (1.0, 24.0),
    "hit_react": (1.0, 12.0),
    "death_curl": (1.0, 36.0),
}
EXPECTED_LOOPS = {"idle_sniff": True, "scurry": True, "pounce_bite": False, "hit_react": False, "death_curl": False}
EXPECTED_BONE_PARENTS = {
    "root": None,
    "pelvis": "root",
    "spine_01": "pelvis",
    "spine_02": "spine_01",
    "shoulders": "spine_02",
    "neck": "shoulders",
    "head": "neck",
    "jaw": "head",
    "thigh.L": "pelvis",
    "shin.L": "thigh.L",
    "rear_paw.L": "shin.L",
    "thigh.R": "pelvis",
    "shin.R": "thigh.R",
    "rear_paw.R": "shin.R",
    "upper_arm.L": "shoulders",
    "forearm.L": "upper_arm.L",
    "front_paw.L": "forearm.L",
    "upper_arm.R": "shoulders",
    "forearm.R": "upper_arm.R",
    "front_paw.R": "forearm.R",
    "tail_01": "pelvis",
    "tail_02": "tail_01",
    "tail_03": "tail_02",
    "tail_04": "tail_03",
    "tail_05": "tail_04",
    "tail_06": "tail_05",
    "tail_07": "tail_06",
    "tail_08": "tail_07",
}
MAX_TRIANGLES = 3000
TARGET_LENGTH = 1.22
TARGET_HEIGHT = 0.61
TOLERANCE = 0.02

errors = []
mesh_object = bpy.data.objects.get(MESH_NAME)
rig_object = bpy.data.objects.get(RIG_NAME)
export_collection = bpy.data.collections.get(EXPORT_COLLECTION)

if mesh_object is None or mesh_object.type != "MESH":
    errors.append(f"missing mesh object {MESH_NAME}")
if rig_object is None or rig_object.type != "ARMATURE":
    errors.append(f"missing armature {RIG_NAME}")
if export_collection is None:
    errors.append(f"missing collection {EXPORT_COLLECTION}")


def iter_action_fcurves(action):
    """Yield F-curves from Blender 5.2 layered actions."""
    for layer in action.layers:
        for strip in layer.strips:
            for channelbag in getattr(strip, "channelbags", ()):
                yield from channelbag.fcurves

report = {}
if mesh_object is not None and mesh_object.type == "MESH":
    original_pose_position = None
    if rig_object is not None and rig_object.type == "ARMATURE":
        original_pose_position = rig_object.data.pose_position
        rig_object.data.pose_position = "REST"
        bpy.context.view_layer.update()
    evaluated = mesh_object.evaluated_get(bpy.context.evaluated_depsgraph_get())
    evaluated_mesh = evaluated.to_mesh()
    evaluated_mesh.calc_loop_triangles()
    triangles = len(evaluated_mesh.loop_triangles)
    corners = [evaluated.matrix_world @ Vector(corner) for corner in evaluated.bound_box]
    xs = [corner.x for corner in corners]
    ys = [corner.y for corner in corners]
    zs = [corner.z for corner in corners]
    length = max(ys) - min(ys)
    height = max(zs) - min(zs)
    ground = min(zs)
    report.update(triangles=triangles, length=length, height=height, ground=ground)
    if triangles > MAX_TRIANGLES:
        errors.append(f"triangle cap exceeded: {triangles} > {MAX_TRIANGLES}")
    if abs(length - TARGET_LENGTH) > TOLERANCE:
        errors.append(f"length out of tolerance: {length:.4f}")
    if abs(height - TARGET_HEIGHT) > TOLERANCE:
        errors.append(f"height out of tolerance: {height:.4f}")
    if abs(ground) > 0.002:
        errors.append(f"feet not grounded: min_z={ground:.5f}")
    if len(mesh_object.material_slots) > 2:
        errors.append(f"too many rendered surfaces: {len(mesh_object.material_slots)}")
    armature_modifiers = [modifier for modifier in mesh_object.modifiers if modifier.type == "ARMATURE"]
    if len(armature_modifiers) != 1 or armature_modifiers[0].object != rig_object:
        errors.append("mesh requires exactly one SwarmerRatRig armature modifier")
    bm = bmesh.new()
    bm.from_mesh(mesh_object.data)
    if any(not edge.is_manifold for edge in bm.edges):
        errors.append("non-manifold edge found")
    if any(face.calc_area() <= 1e-10 for face in bm.faces):
        errors.append("zero-area face found")
    bm.free()
    evaluated.to_mesh_clear()
    if original_pose_position is not None:
        rig_object.data.pose_position = original_pose_position
        bpy.context.view_layer.update()

action_names = {action.name for action in bpy.data.actions}
missing_actions = sorted(EXPECTED_ACTIONS - action_names)
if missing_actions:
    errors.append(f"missing actions: {missing_actions}")
for action_name, expected_range in EXPECTED_RANGES.items():
    action = bpy.data.actions.get(action_name)
    if action is None:
        continue
    actual_range = tuple(float(value) for value in action.frame_range)
    if any(abs(actual - expected) > 0.001 for actual, expected in zip(actual_range, expected_range)):
        errors.append(f"{action_name} frame range {actual_range} != {expected_range}")
    if bool(action.use_cyclic) != EXPECTED_LOOPS[action_name]:
        errors.append(f"{action_name} loop flag is {bool(action.use_cyclic)}")
    for fcurve in iter_action_fcurves(action):
        if fcurve.data_path != 'pose.bones["root"].location':
            continue
        if any(abs(point.co[1]) > 0.000001 for point in fcurve.keyframe_points):
            errors.append(f"{action_name} contains root translation")
            break
if mesh_object is not None:
    unweighted = [vertex.index for vertex in mesh_object.data.vertices if not vertex.groups]
    if unweighted:
        errors.append(f"unweighted vertices: {unweighted[:16]}")
    bad_weight_sums = []
    excessive_influences = []
    for vertex in mesh_object.data.vertices:
        positive_weights = [membership.weight for membership in vertex.groups if membership.weight > 0.000001]
        if positive_weights and abs(sum(positive_weights) - 1.0) > 0.001:
            bad_weight_sums.append(vertex.index)
        if len(positive_weights) > 4:
            excessive_influences.append(vertex.index)
    if bad_weight_sums:
        errors.append(f"non-normalized weights: {bad_weight_sums[:16]}")
    if excessive_influences:
        errors.append(f"more than four influences: {excessive_influences[:16]}")

if rig_object is not None and rig_object.type == "ARMATURE":
    actual_bones = set(rig_object.data.bones)
    missing_bones = sorted(set(EXPECTED_BONE_PARENTS) - {bone.name for bone in actual_bones})
    if missing_bones:
        errors.append(f"missing bones: {missing_bones}")
    for bone_name, expected_parent in EXPECTED_BONE_PARENTS.items():
        bone = rig_object.data.bones.get(bone_name)
        if bone is None:
            continue
        actual_parent = bone.parent.name if bone.parent else None
        if actual_parent != expected_parent:
            errors.append(f"{bone_name} parent {actual_parent} != {expected_parent}")

if export_collection is not None:
    unexpected = sorted(obj.name for obj in export_collection.objects if obj.name not in {MESH_NAME, RIG_NAME})
    if unexpected:
        errors.append(f"unexpected export objects: {unexpected}")

print(json.dumps({"report": report, "errors": errors}, sort_keys=True))
if errors:
    raise SystemExit(1)
print("SWARMER_RAT_BLENDER_VALIDATION_OK")
