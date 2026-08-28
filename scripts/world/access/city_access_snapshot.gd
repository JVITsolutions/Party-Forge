class_name CityAccessSnapshot
extends RefCounted

const MAX_TEXT_UNITS := 128
const MAX_PROVENANCE_VERSION := 2147483647

var _adapter: StringName
var _source_format: StringName
var _source_format_version: int
var _source_sha256: String
var _locations: Array[CityAccessLocation] = []

var adapter: StringName:
	get: return _adapter
	set(_next): pass
var source_format: StringName:
	get: return _source_format
	set(_next): pass
var source_format_version: int:
	get: return _source_format_version
	set(_next): pass
var source_sha256: String:
	get: return _source_sha256
	set(_next): pass
var locations: Array[CityAccessLocation]:
	get: return _location_copies(_locations)
	set(_next): pass

static func create(adapter_value: StringName, source_format_value: StringName, source_format_version_value: Variant, source_sha256_value: String, locations_value: Array[CityAccessLocation]) -> CityAccessSnapshot:
	if not _stable(adapter_value) or not _stable(source_format_value) or not _provenance_version(source_format_version_value) or not _sha(source_sha256_value) or not _locations_are_valid(locations_value):
		return null
	var snapshot := CityAccessSnapshot.new()
	snapshot._adapter = adapter_value
	snapshot._source_format = source_format_value
	snapshot._source_format_version = int(source_format_version_value)
	snapshot._source_sha256 = source_sha256_value
	snapshot._locations = _location_copies(locations_value)
	return snapshot

func copy() -> CityAccessSnapshot:
	return create(_adapter, _source_format, _source_format_version, _source_sha256, _locations)

static func _location_copies(source: Array[CityAccessLocation]) -> Array[CityAccessLocation]:
	var copies: Array[CityAccessLocation] = []
	for location: CityAccessLocation in source:
		copies.append(location.copy())
	return copies

static func _stable(value: StringName) -> bool:
	return not value.is_empty() and String(value).to_utf16_buffer().size() / 2 <= MAX_TEXT_UNITS

static func _provenance_version(value: Variant) -> bool:
	var is_integer: bool = typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT and is_finite(value as float) and floorf(value as float) == value)
	return is_integer and int(value) > 0 and int(value) <= MAX_PROVENANCE_VERSION

static func _sha(value: String) -> bool:
	if value.length() != 64:
		return false
	for character: String in value:
		if not (character >= "0" and character <= "9") and not (character >= "a" and character <= "f"):
			return false
	return true

static func _locations_are_valid(values: Array[CityAccessLocation]) -> bool:
	if values.size() > 256:
		return false
	var ids: Dictionary = {}
	var destinations: Dictionary = {}
	for location: CityAccessLocation in values:
		if location == null or ids.has(location.id) or destinations.has(location.destination_id):
			return false
		ids[location.id] = true
		destinations[location.destination_id] = true
	return true
