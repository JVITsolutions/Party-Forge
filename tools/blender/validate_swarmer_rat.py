import bpy
import bmesh
import json


MESH_NAME = "MeshInstance3D"
RIG_NAME = "SwarmerRatRig"
EXPORT_COLLECTION = "PF_RAT_EXPORT"
REVIEW_COLLECTION = "PF_RAT_REVIEW"
EXPECTED_ACTIONS = {"idle_sniff", "scurry", "pounce_bite", "hit_react", "death_curl"}
MAX_TRIANGLES = 3000
TARGET_LENGTH = 0.91
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

report = {}
if mesh_object is not None and mesh_object.type == "MESH":
    evaluated = mesh_object.evaluated_get(bpy.context.evaluated_depsgraph_get())
    evaluated_mesh = evaluated.to_mesh()
    evaluated_mesh.calc_loop_triangles()
    triangles = len(evaluated_mesh.loop_triangles)
    corners = [evaluated.matrix_world @ corner for corner in evaluated.bound_box]
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

action_names = {action.name for action in bpy.data.actions}
missing_actions = sorted(EXPECTED_ACTIONS - action_names)
if missing_actions:
    errors.append(f"missing actions: {missing_actions}")
if mesh_object is not None:
    unweighted = [vertex.index for vertex in mesh_object.data.vertices if not vertex.groups]
    if unweighted:
        errors.append(f"unweighted vertices: {unweighted[:16]}")

if export_collection is not None:
    unexpected = sorted(obj.name for obj in export_collection.objects if obj.name not in {MESH_NAME, RIG_NAME})
    if unexpected:
        errors.append(f"unexpected export objects: {unexpected}")

print(json.dumps({"report": report, "errors": errors}, sort_keys=True))
if errors:
    raise SystemExit(1)
print("SWARMER_RAT_BLENDER_VALIDATION_OK")
