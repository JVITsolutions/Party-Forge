class_name ProfileTestSupport
extends RefCounted

static func remove_tree(user_path: String) -> void:
	var absolute := ProjectSettings.globalize_path(user_path)
	if DirAccess.dir_exists_absolute(absolute):
		_remove_absolute_tree(absolute)

static func _remove_absolute_tree(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory != null:
		for name: String in directory.get_files():
			DirAccess.remove_absolute(path.path_join(name))
		for name: String in directory.get_directories():
			_remove_absolute_tree(path.path_join(name))
	DirAccess.remove_absolute(path)
