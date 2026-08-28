class_name GeneratedJsonDocumentWriter
extends RefCounted

const TARGET := "res://data/world/access/party-forge-city-access.snapshot.json"
const STAGING_ROOT := "res://.party-forge-tools/latticewright-city-access"

var _documents: AtomicJsonStore

func _init(documents: AtomicJsonStore = null) -> void:
	_documents = documents if documents != null else AtomicJsonStore.new()

func recover() -> Dictionary:
	return _documents.recover_generated_document(
		TARGET,
		Callable(CityAccessSnapshotLoader, "validate_document"),
		STAGING_ROOT,
	)

func write(document: Dictionary) -> Dictionary:
	return _documents.save_generated_document(
		TARGET,
		document,
		Callable(CityAccessSnapshotLoader, "validate_document"),
		STAGING_ROOT,
		Callable(CityAccessSnapshotCodec, "encode_document"),
	)
