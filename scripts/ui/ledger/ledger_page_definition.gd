class_name LedgerPageDefinition
extends Resource

enum State { HIDDEN, COMING_SOON, DEVELOPER_PREVIEW, AVAILABLE }

@export var id: StringName
@export var label: String
@export var page_scene: PackedScene
@export var display_order := 0
@export var feature_id: StringName
@export var unlock_id: StringName
@export var unavailable_text := ""
@export var development_state := State.HIDDEN

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty():
		errors.append("PARTY_FORGE_LEDGER_ERROR page=<empty> reason=id is empty")
	if label.strip_edges().is_empty():
		errors.append("PARTY_FORGE_LEDGER_ERROR page=%s reason=label is empty" % id)
	if development_state in [State.AVAILABLE, State.DEVELOPER_PREVIEW] and page_scene == null:
		var source_path := resource_path if not resource_path.is_empty() else "<runtime>"
		errors.append("PARTY_FORGE_LEDGER_ERROR page=%s resource=%s reason=implemented page scene is missing" % [id, source_path])
	if development_state == State.COMING_SOON and unavailable_text.strip_edges().is_empty():
		errors.append("PARTY_FORGE_LEDGER_ERROR page=%s reason=coming soon explanation is empty" % id)
	return errors
