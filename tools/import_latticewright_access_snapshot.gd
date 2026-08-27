extends SceneTree

const ADAPTER := "latticewright-runtime-v3-city-access"
const MAX_SOURCE_BYTES := 64 * 1024 * 1024

class CityAccessImportCliService extends RefCounted:
	var _reader: Callable
	var _translator: Callable
	var _validator: Callable
	var _encoder: Callable
	var _writer: Callable
	var _target_reader: Callable
	var _target_restorer: Callable
	var last_cleanup_debt := false

	func _init(dependencies: Dictionary) -> void:
		_reader = dependencies.get("reader", Callable(StrictJsonDocumentReader, "read")) as Callable
		_translator = dependencies.get("translator", Callable(LatticewrightRuntimeV3CityAccessImporter, "translate")) as Callable
		_validator = dependencies.get("validator", Callable(CityAccessSnapshotLoader, "validate_document")) as Callable
		_encoder = dependencies.get("encoder", Callable(CityAccessSnapshotCodec, "encode_document")) as Callable
		_writer = dependencies.get("writer", Callable(GeneratedJsonDocumentWriter.new(), "write")) as Callable
		_target_reader = dependencies.get("target_reader", Callable(self, "_default_target_reader")) as Callable
		_target_restorer = dependencies.get("target_restorer", Callable(self, "_default_target_restore")) as Callable

	func run(arguments: PackedStringArray, emit: Callable = Callable()) -> int:
		last_cleanup_debt = false
		var source_path := _parse_source(arguments)
		if source_path.is_empty(): return _reject("request", emit)
		var source: Variant = _reader.call(source_path, MAX_SOURCE_BYTES)
		if not _ok(source): return _reject(_stage(source, "read"), emit)
		var translated: Variant = _translator.call(_value(source, "document", {}), _value(source, "sha256", ""))
		if not _ok(translated): return _reject(_stage(translated, "translate"), emit)
		var candidate: Dictionary = _value(translated, "candidate", {}) as Dictionary
		var validation: Variant = _validator.call(candidate)
		if not _ok(validation): return _reject(_stage(validation, "validate"), emit)
		var canonical: Variant = _encoder.call(candidate)
		if not canonical is PackedByteArray or (canonical as PackedByteArray).is_empty(): return _reject("canonicalize", emit)
		var before: Variant = _target_reader.call()
		if not _ok(before): return _reject(_stage(before, "compare"), emit)
		if _value(before, "bytes", PackedByteArray()) == canonical:
			_marker("UNCHANGED", "compare", emit)
			return 0
		var written: Variant = _writer.call(candidate)
		if not _write_ok(written):
			_target_restorer.call(before)
			return _reject(_stage(written, "write"), emit)
		last_cleanup_debt = bool(_value(written, "cleanupDebt", false))
		var verified: Variant = _target_reader.call()
		if not _ok(verified) or _value(verified, "bytes", PackedByteArray()) != canonical:
			_target_restorer.call(before)
			return _reject("verified", emit)
		_marker("IMPORTED", "verified", emit)
		return 0

	func _parse_source(arguments: PackedStringArray) -> String:
		if arguments.size() != 2 or arguments[0] != "--source" or arguments[1].is_empty(): return ""
		return arguments[1]

	func _reject(stage: String, emit: Callable) -> int:
		_marker("REJECTED", _sanitize_stage(stage), emit)
		return 1

	func _marker(status: String, stage: String, emit: Callable) -> void:
		var line := "PARTY_FORGE_CITY_ACCESS_IMPORT status=%s adapter=%s stage=%s" % [status, ADAPTER, stage]
		if emit.is_valid(): emit.call(line)
		else: print(line)

	func _ok(value: Variant) -> bool:
		if value is Dictionary: return bool((value as Dictionary).get("ok", false))
		return value != null and value.has_method("ok") and bool(value.call("ok"))

	func _write_ok(value: Variant) -> bool:
		if not value is Dictionary: return false
		var outcome := value as Dictionary
		if outcome.size() != 5 or not outcome.has_all(["ok", "committed", "cleanupDebt", "stage", "reason"]): return false
		if not outcome["ok"] is bool or not outcome["committed"] is bool or not outcome["cleanupDebt"] is bool: return false
		if not outcome["stage"] is String or not outcome["reason"] is String: return false
		return outcome["ok"] and outcome["committed"]

	func _value(value: Variant, key: String, fallback: Variant) -> Variant:
		if value is Dictionary: return (value as Dictionary).get(key, fallback)
		return value.get(key) if value != null and key in value else fallback

	func _stage(value: Variant, fallback: String) -> String:
		var supplied := str(_value(value, "stage", ""))
		return supplied if not supplied.is_empty() else fallback

	func _sanitize_stage(value: String) -> String:
		return value if value in ["request", "open", "size", "read", "decode", "duplicate-key", "scan", "parse", "translate", "validate", "canonicalize", "compare", "write", "promote", "verified"] else "unknown"

	func _default_target_reader() -> Dictionary:
		var target := GeneratedJsonDocumentWriter.TARGET
		if not FileAccess.file_exists(target): return {"ok": true, "exists": false, "bytes": PackedByteArray()}
		var bytes := FileAccess.get_file_as_bytes(target)
		return {"ok": FileAccess.get_open_error() == OK, "exists": true, "bytes": bytes}

	func _default_target_restore(before: Dictionary) -> Dictionary:
		var target := GeneratedJsonDocumentWriter.TARGET
		if not bool(before.get("exists", false)):
			var remove_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(target)) if FileAccess.file_exists(target) else OK
			return {"ok": remove_error == OK}
		var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target).get_base_dir())
		if directory_error not in [OK, ERR_ALREADY_EXISTS]: return {"ok": false}
		var file := FileAccess.open(target, FileAccess.WRITE)
		if file == null: return {"ok": false}
		file.store_buffer(before.get("bytes", PackedByteArray()) as PackedByteArray)
		var write_error := file.get_error(); file.close()
		return {"ok": write_error == OK and FileAccess.get_file_as_bytes(target) == before.get("bytes", PackedByteArray())}

static func new_service(dependencies: Dictionary = {}) -> CityAccessImportCliService:
	return CityAccessImportCliService.new(dependencies)

func _initialize() -> void:
	var service := new_service()
	quit(service.run(OS.get_cmdline_user_args()))
