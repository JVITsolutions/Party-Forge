class_name RunPauseLease
extends RefCounted

const TREE_STATE_META := &"_party_forge_run_pause_lease_state"

var _active := false
var _tree_ref: WeakRef

func acquire(tree: SceneTree) -> void:
	if _active or tree == null:
		return
	var state: Dictionary = tree.get_meta(TREE_STATE_META, {})
	if state.is_empty():
		state = {
			"original_paused": tree.paused,
			"lease_count": 0,
		}
	state["lease_count"] = int(state["lease_count"]) + 1
	tree.set_meta(TREE_STATE_META, state)
	_active = true
	_tree_ref = weakref(tree)
	tree.paused = true

func release(_tree: SceneTree) -> void:
	_release_owned_tree()

func _release_owned_tree() -> void:
	if not _active:
		return
	var tree := _tree_ref.get_ref() as SceneTree if _tree_ref != null else null
	if tree != null:
		var state: Dictionary = tree.get_meta(TREE_STATE_META, {})
		if not state.is_empty():
			var remaining := int(state["lease_count"]) - 1
			if remaining <= 0:
				tree.paused = bool(state["original_paused"])
				tree.remove_meta(TREE_STATE_META)
			else:
				state["lease_count"] = remaining
				tree.set_meta(TREE_STATE_META, state)
				tree.paused = true
	_active = false
	_tree_ref = null

func is_active() -> bool:
	return _active
