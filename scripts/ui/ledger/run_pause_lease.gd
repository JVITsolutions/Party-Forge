class_name RunPauseLease
extends RefCounted

var _active := false
var _was_paused := false

func acquire(tree: SceneTree) -> void:
	if _active or tree == null:
		return
	_active = true
	_was_paused = tree.paused
	tree.paused = true

func release(tree: SceneTree) -> void:
	if not _active or tree == null:
		return
	tree.paused = _was_paused
	_active = false

func is_active() -> bool:
	return _active
