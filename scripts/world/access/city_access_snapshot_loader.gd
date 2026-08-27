class_name CityAccessSnapshotLoader
extends RefCounted

const FORMAT := "party-forge-access-snapshot"
const VERSION := 1
const MAX_BYTES := 1024 * 1024
const MAX_LOCATIONS := 256
const MAX_CONDITIONS := 8
const MAX_TEXT_UNITS := 128
const CONDITION_KINDS := [&"always", &"prologue_state", &"permanent_unlock", &"discovered_building", &"discovered_tree"]
const ROOT_KEYS := ["format", "version", "source", "locations"]
const SOURCE_KEYS := ["adapter", "format", "formatVersion", "sha256"]
const LOCATION_KEYS := ["id", "destinationId", "visibleWhen", "availableWhen"]
const CONDITION_KEYS := ["kind", "value"]
const PROLOGUE_STATES := ["not_started", "in_progress", "completed"]

static func load_bytes(bytes: PackedByteArray) -> CityAccessLoadResult:
	if bytes.size() > MAX_BYTES: return _failure("document exceeds byte limit")
	var text: String = bytes.get_string_from_utf8()
	if text.contains("\uFEFF") or text.contains("\uFFFD") or text.to_utf8_buffer() != bytes: return _failure("document must be strict UTF-8")
	var parser := JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary: return _failure("document must contain one JSON object")
	var document := parser.data as Dictionary
	if not _keys(document, ROOT_KEYS): return _failure("root keys are invalid")
	if typeof(document["format"]) != TYPE_STRING or document["format"] != FORMAT: return _failure("root format is invalid")
	if not _integer(document["version"]) or int(document["version"]) != VERSION: return _failure("root version is invalid")
	if not document["source"] is Dictionary or not document["locations"] is Array: return _failure("root types are invalid")
	var source := document["source"] as Dictionary
	if not _keys(source, SOURCE_KEYS): return _failure("source keys are invalid")
	if typeof(source["adapter"]) != TYPE_STRING or source["adapter"] != "latticewright-runtime-v3-city-access": return _failure("source adapter is invalid")
	if not _stable(source["format"]) or not _integer(source["formatVersion"]) or int(source["formatVersion"]) != 3 or typeof(source["sha256"]) != TYPE_STRING or not _sha(source["sha256"] as String): return _failure("source values are invalid")
	var values := document["locations"] as Array
	if values.size() > MAX_LOCATIONS: return _failure("location limit exceeded")
	var locations: Array[CityAccessLocation] = []
	var ids: Dictionary = {}; var destinations: Dictionary = {}
	for index: int in values.size():
		var entry: Variant = values[index]
		if not entry is Dictionary: return _failure("location must be object")
		var location_document := entry as Dictionary
		if not _keys(location_document, LOCATION_KEYS) or not _stable(location_document["id"]) or not _stable(location_document["destinationId"]): return _failure("location fields are invalid")
		if not location_document["visibleWhen"] is Array or not location_document["availableWhen"] is Array: return _failure("condition lists must be arrays")
		var id := StringName(location_document["id"] as String); var destination := StringName(location_document["destinationId"] as String)
		if ids.has(id) or destinations.has(destination): return _failure("duplicate location or destination ID")
		var visible := _conditions(location_document["visibleWhen"] as Array)
		var available := _conditions(location_document["availableWhen"] as Array)
		if (visible.is_empty() and not (location_document["visibleWhen"] as Array).is_empty()) or (available.is_empty() and not (location_document["availableWhen"] as Array).is_empty()): return _failure("conditions are invalid")
		var location := CityAccessLocation.create(id, destination, visible, available)
		if location == null: return _failure("location cannot be constructed")
		ids[id] = true; destinations[destination] = true; locations.append(location)
	locations.sort_custom(func(left: CityAccessLocation, right: CityAccessLocation) -> bool: return String(left.id) < String(right.id))
	var snapshot := CityAccessSnapshot.create(StringName(source["adapter"] as String), StringName(source["format"] as String), int(source["formatVersion"]), source["sha256"] as String, locations)
	return CityAccessLoadResult.success(snapshot) if snapshot != null else _failure("snapshot cannot be constructed")

static func load_path(path: String) -> CityAccessLoadResult:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return _failure("could not read snapshot path")
	var bytes := file.get_buffer(file.get_length()); file.close()
	return load_bytes(bytes)

static func _conditions(values: Array) -> Array[CityAccessCondition]:
	if values.size() > MAX_CONDITIONS: return []
	var result: Array[CityAccessCondition] = []; var always := false
	for entry: Variant in values:
		if not entry is Dictionary: return []
		var document := entry as Dictionary
		if not _keys(document, CONDITION_KEYS) or typeof(document["kind"]) != TYPE_STRING or typeof(document["value"]) != TYPE_STRING: return []
		var kind := StringName(document["kind"] as String); var value := document["value"] as String
		if not CONDITION_KINDS.has(kind): return []
		if kind == &"always":
			if not value.is_empty(): return []
			always = true
		elif not _stable(value) or (kind == &"prologue_state" and value not in PROLOGUE_STATES): return []
		var condition := CityAccessCondition.create(kind, value)
		if condition == null: return []
		result.append(condition)
	if always and result.size() > 1: return []
	result.sort_custom(func(left: CityAccessCondition, right: CityAccessCondition) -> bool: return String(left.kind) < String(right.kind) or (left.kind == right.kind and left.value < right.value))
	return result

static func _keys(document: Dictionary, expected: Array) -> bool:
	if document.size() != expected.size(): return false
	for key: String in expected:
		if not document.has(key): return false
	return true

static func _stable(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and not (value as String).is_empty() and (value as String).to_utf16_buffer().size() / 2 <= MAX_TEXT_UNITS

static func _integer(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT and is_finite(value as float) and floorf(value as float) == value)

static func _sha(value: String) -> bool:
	if value.length() != 64: return false
	for character: String in value:
		if not (character >= "0" and character <= "9") and not (character >= "a" and character <= "f"): return false
	return true

static func _failure(message: String) -> CityAccessLoadResult:
	return CityAccessLoadResult.failure("PARTY_FORGE_CITY_ACCESS_SNAPSHOT_ERROR %s" % message)
