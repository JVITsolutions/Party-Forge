class_name CityAccessSnapshotCodec
extends RefCounted

static func encode_document(document: Dictionary) -> PackedByteArray:
	var result := CityAccessSnapshotLoader.load_bytes(JSON.stringify(document).to_utf8_buffer())
	if not result.ok(): return PackedByteArray()
	var snapshot := result.snapshot
	var locations: Array = []
	for location: CityAccessLocation in snapshot.locations:
		locations.append({"id": String(location.id), "destinationId": String(location.destination_id), "visibleWhen": _conditions(location.visible_when), "availableWhen": _conditions(location.available_when)})
	return (JSON.stringify({"format": CityAccessSnapshotLoader.FORMAT, "version": CityAccessSnapshotLoader.VERSION, "source": {"adapter": String(snapshot.adapter), "format": String(snapshot.source_format), "formatVersion": snapshot.source_format_version, "sha256": snapshot.source_sha256}, "locations": locations}, "  ", false) + "\n").to_utf8_buffer()

static func _conditions(values: Array[CityAccessCondition]) -> Array:
	var result: Array = []
	for condition: CityAccessCondition in values:
		result.append({"kind": String(condition.kind), "value": condition.value})
	return result
