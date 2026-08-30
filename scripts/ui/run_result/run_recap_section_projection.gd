class_name RunRecapSectionProjection
extends RefCounted

enum SemanticKind { OUTCOME, PARTY, BUILD, LOOT, CONSEQUENCE, HIGHLIGHT }

var _section_id: StringName = &""
var section_id: StringName:
	get: return _section_id
var _title := ""
var title: String:
	get: return _title
var _semantic_kind := SemanticKind.OUTCOME
var semantic_kind: SemanticKind:
	get: return _semantic_kind
var _entries: Array[RunRecapEntryProjection] = []
var entries: Array[RunRecapEntryProjection]:
	get:
		var result: Array[RunRecapEntryProjection] = []
		for entry: RunRecapEntryProjection in _entries:
			result.append(entry.copy() if entry != null else null)
		return result
var _summary := ""
var summary: String:
	get: return _summary
var _construction_error := ""

static func create(
	section_id_value: StringName,
	title_value: String,
	semantic_kind_value: int,
	entry_values: Array,
	summary_value: String = "",
) -> RunRecapSectionProjection:
	var result := RunRecapSectionProjection.new()
	result._section_id = section_id_value
	result._title = title_value.strip_edges()
	result._semantic_kind = semantic_kind_value as SemanticKind
	result._summary = summary_value.strip_edges()
	for value: Variant in entry_values:
		if value is RunRecapEntryProjection:
			result._entries.append((value as RunRecapEntryProjection).copy())
		else:
			result._construction_error = "entry must be a RunRecapEntryProjection"
	return result

func valid() -> bool:
	if String(_section_id).strip_edges().is_empty() or _title.is_empty() or not _construction_error.is_empty():
		return false
	if int(_semantic_kind) < SemanticKind.OUTCOME or int(_semantic_kind) > SemanticKind.HIGHLIGHT or _entries.is_empty():
		return false
	for entry: RunRecapEntryProjection in _entries:
		if entry == null or not entry.valid():
			return false
	return true

func copy() -> RunRecapSectionProjection:
	return create(_section_id, _title, _semantic_kind, _entries, _summary)
