class_name CityAccessSnapshot
extends RefCounted

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

static func create(adapter_value: StringName, source_format_value: StringName, source_format_version_value: int, source_sha256_value: String, locations_value: Array[CityAccessLocation]) -> CityAccessSnapshot:
	if adapter_value.is_empty() or source_format_value.is_empty() or source_sha256_value.is_empty():
		return null
	var snapshot := CityAccessSnapshot.new()
	snapshot._adapter = adapter_value
	snapshot._source_format = source_format_value
	snapshot._source_format_version = source_format_version_value
	snapshot._source_sha256 = source_sha256_value
	snapshot._locations = _location_copies(locations_value)
	return snapshot

func copy() -> CityAccessSnapshot:
	return create(_adapter, _source_format, _source_format_version, _source_sha256, _locations)

static func _location_copies(source: Array[CityAccessLocation]) -> Array[CityAccessLocation]:
	var copies: Array[CityAccessLocation] = []
	for location: CityAccessLocation in source:
		if location != null:
			copies.append(location.copy())
	return copies
