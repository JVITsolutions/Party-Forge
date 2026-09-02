class_name LatticewrightRuntimeAdapterRegistry
extends RefCounted

const MAX_RUNTIME_JSON_BYTES := 64 * 1024 * 1024

var _adapters: Dictionary = {}

func register_adapter(format_version: int, adapter: Callable) -> bool:
	if format_version <= 0 or not adapter.is_valid() or _adapters.has(format_version):
		return false
	_adapters[format_version] = adapter
	return true

func load_path(path: String) -> PassiveTreeLoadResult:
	var source := StrictJsonDocumentReader.read(path, MAX_RUNTIME_JSON_BYTES)
	if not source.ok():
		return PassiveTreeLoadResult.failure(
			"PARTY_FORGE_PASSIVE_TREE_ADAPTER_ERROR path=%s stage=%s reason=%s" % [path, source.stage, source.reason]
		)
	return load_document(source.document, path, source.sha256)

func load_document(document: Dictionary, source_path: String, source_sha256: String) -> PassiveTreeLoadResult:
	var header := LatticewrightRuntimeHeader.validate(document)
	if not header.ok():
		return PassiveTreeLoadResult.failure(header.error)
	var adapter: Callable = _adapters.get(header.format_version, Callable())
	if not adapter.is_valid():
		return PassiveTreeLoadResult.failure(
			"PARTY_FORGE_PASSIVE_TREE_ADAPTER_ERROR format_version=%d reason=adapter unavailable" % header.format_version
		)
	var adapted: Variant = adapter.call(document.duplicate(true), source_path, source_sha256)
	if not adapted is PassiveTreeLoadResult:
		return PassiveTreeLoadResult.failure(
			"PARTY_FORGE_PASSIVE_TREE_ADAPTER_ERROR format_version=%d reason=adapter returned invalid result" % header.format_version
		)
	var result := adapted as PassiveTreeLoadResult
	var is_success := result.tree != null and result.errors.is_empty()
	var is_failure := result.tree == null and not result.errors.is_empty()
	if not is_success and not is_failure:
		return PassiveTreeLoadResult.failure(
			"PARTY_FORGE_PASSIVE_TREE_ADAPTER_ERROR format_version=%d reason=adapter returned inconsistent result" % header.format_version
		)
	result.source_document = document.duplicate(true)
	result.source_path = source_path
	result.source_sha256 = source_sha256
	return result
