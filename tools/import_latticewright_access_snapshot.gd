extends SceneTree

const ADAPTER := "latticewright-runtime-v3-city-access"
const MAX_SOURCE_BYTES := 64 * 1024 * 1024

class CityAccessImportCliService extends RefCounted:
	var _reader: Callable
	var _translator: Callable
	var _validator: Callable
	var _encoder: Callable
	var _recovery: Callable
	var _writer: Callable
	var _default_writer: GeneratedJsonDocumentWriter
	var last_cleanup_debt := false

	func _init(dependencies: Dictionary) -> void:
		_reader = dependencies.get("reader", Callable(StrictJsonDocumentReader, "read")) as Callable
		_translator = dependencies.get("translator", Callable(LatticewrightRuntimeV3CityAccessImporter, "translate")) as Callable
		_validator = dependencies.get("validator", Callable(CityAccessSnapshotLoader, "validate_document")) as Callable
		_encoder = dependencies.get("encoder", Callable(CityAccessSnapshotCodec, "encode_document")) as Callable
		var injected_writer := dependencies.get("writer", Callable()) as Callable
		var injected_recovery := dependencies.get("recovery", Callable()) as Callable
		if injected_writer.is_valid():
			_writer = injected_writer
		else:
			_default_writer = GeneratedJsonDocumentWriter.new()
			_writer = Callable(_default_writer, "write")
		if injected_recovery.is_valid():
			_recovery = injected_recovery
		else:
			if _default_writer == null:
				_default_writer = GeneratedJsonDocumentWriter.new()
			_recovery = Callable(_default_writer, "recover")

	func run(arguments: PackedStringArray, emit: Callable = Callable()) -> int:
		last_cleanup_debt = false
		var recovered: Variant = _recovery.call()
		if not _write_outcome_valid(recovered): return _indeterminate("recovery", emit)
		last_cleanup_debt = bool(_value(recovered, "cleanupDebt", false))
		if not bool(_value(recovered, "ok", false)):
			return _indeterminate(_stage(recovered, "recovery"), emit)
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
		var written: Variant = _writer.call(candidate)
		if not _write_outcome_valid(written): return _indeterminate("write", emit)
		last_cleanup_debt = last_cleanup_debt or bool(_value(written, "cleanupDebt", false))
		var state := str(_value(written, "state", ""))
		var stage := _stage(written, "write")
		if state == "committed":
			_marker("IMPORTED", _sanitize_stage(stage), emit)
			return 0
		if state == "unchanged":
			_marker("UNCHANGED", _sanitize_stage(stage), emit)
			return 0
		if state == "rejected": return _reject(stage, emit)
		return _indeterminate(stage, emit)

	func _parse_source(arguments: PackedStringArray) -> String:
		if arguments.size() != 2 or arguments[0] != "--source" or arguments[1].is_empty(): return ""
		return arguments[1]

	func _reject(stage: String, emit: Callable) -> int:
		_marker("REJECTED", _sanitize_stage(stage), emit)
		return 1

	func _indeterminate(stage: String, emit: Callable) -> int:
		_marker("INDETERMINATE", _sanitize_stage(stage), emit)
		return 1

	func _marker(status: String, stage: String, emit: Callable) -> void:
		var line := "PARTY_FORGE_CITY_ACCESS_IMPORT status=%s adapter=%s stage=%s" % [status, ADAPTER, stage]
		if emit.is_valid(): emit.call(line)
		else: print(line)

	func _ok(value: Variant) -> bool:
		if value is Dictionary: return bool((value as Dictionary).get("ok", false))
		return value != null and value.has_method("ok") and bool(value.call("ok"))

	func _write_outcome_valid(value: Variant) -> bool:
		if not value is Dictionary: return false
		var outcome := value as Dictionary
		if outcome.size() != 5 or not outcome.has_all(["ok", "state", "cleanupDebt", "stage", "reason"]): return false
		if not outcome["ok"] is bool or not outcome["state"] is String or not outcome["cleanupDebt"] is bool: return false
		if not outcome["stage"] is String or not outcome["reason"] is String: return false
		var state := outcome["state"] as String
		if state not in ["unchanged", "rejected", "committed", "indeterminate"]: return false
		return (outcome["ok"] as bool) == (state in ["unchanged", "committed"])

	func _value(value: Variant, key: String, fallback: Variant) -> Variant:
		if value is Dictionary: return (value as Dictionary).get(key, fallback)
		return value.get(key) if value != null and key in value else fallback

	func _stage(value: Variant, fallback: String) -> String:
		var supplied := str(_value(value, "stage", ""))
		return supplied if not supplied.is_empty() else fallback

	func _sanitize_stage(value: String) -> String:
		return value if value in ["request", "open", "size", "read", "decode", "duplicate-key", "scan", "parse", "translate", "validate", "canonicalize", "compare", "write", "encode", "confinement", "mkdir", "mkdir-target", "verify-temporary", "snapshot-target", "stage-previous", "verify-previous", "record-recovery", "verify-recovery", "replace-target", "promote", "verify-promoted", "verified", "restore", "recovery", "cleanup"] else "unknown"

static func new_service(dependencies: Dictionary = {}) -> CityAccessImportCliService:
	return CityAccessImportCliService.new(dependencies)

func _initialize() -> void:
	var service := new_service()
	quit(service.run(OS.get_cmdline_user_args()))
