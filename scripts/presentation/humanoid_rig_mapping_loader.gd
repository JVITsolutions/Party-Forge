class_name HumanoidRigMappingLoader
extends RefCounted

var _exists_override: Callable
var _load_override: Callable

func _init(exists_override: Callable = Callable(), load_override: Callable = Callable()) -> void:
	_exists_override = exists_override
	_load_override = load_override

func exists_exact(resource_path: String) -> bool:
	if _exists_override.is_valid():
		return bool(_exists_override.call(resource_path))
	return ResourceLoader.exists(resource_path)

func load_exact(resource_path: String) -> Variant:
	if _load_override.is_valid():
		return _load_override.call(resource_path)
	return ResourceLoader.load(resource_path, "Resource", ResourceLoader.CACHE_MODE_REUSE)
