class_name GeneratedJsonDocumentWriter
extends RefCounted

const TARGET := "res://data/world/access/party-forge-city-access.snapshot.json"
const STAGING_ROOT := "res://.party-forge-tools/latticewright-city-access"

var _documents: AtomicJsonStore
var _target: String
var _staging_root: String

func _init(documents: AtomicJsonStore = null, target: String = TARGET, staging_root: String = STAGING_ROOT) -> void:
	_documents = documents if documents != null else AtomicJsonStore.new()
	_target = target
	_staging_root = staging_root

func recover() -> Dictionary:
	return _documents.recover_generated_document(
		_target,
		Callable(CityAccessSnapshotLoader, "validate_document"),
		_staging_root,
	)

func write(document: Dictionary) -> Dictionary:
	return _documents.save_generated_document(
		_target,
		document,
		Callable(CityAccessSnapshotLoader, "validate_document"),
		_staging_root,
		Callable(CityAccessSnapshotCodec, "encode_document"),
	)
