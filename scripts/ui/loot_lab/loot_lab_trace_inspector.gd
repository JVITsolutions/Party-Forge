class_name LootLabTraceInspector
extends VBoxContainer

signal regenerate_requested(sequence: int)
signal issue_requested(item: ItemInstance)

var _result: ItemGenerationResult
var _request_document: Dictionary = {}
var _built := false

func _ready() -> void:
	_ensure_controls()

func present_result(result: ItemGenerationResult, request_document: Dictionary) -> void:
	_ensure_controls()
	_result = result
	_request_document = request_document.duplicate(true)
	var sequence := int(_request_document.get("generation_sequence", 0))
	(get_node("Sequence") as SpinBox).value = sequence
	var body := get_node("Body") as RichTextLabel
	if result == null:
		body.text = "No result selected."
	elif result.ok():
		body.text = "[b]%s[/b]\n\nRequest\n%s\n\nTrace\n%s" % [result.item.instance_id, JSON.stringify(_request_document, "  "), JSON.stringify(result.trace.stages if result.trace != null else [], "  ")]
	else:
		body.text = "[b]Generation failed[/b]\n\n%s\n\nTrace\n%s" % [JSON.stringify(_failure_document(result.failure), "  "), JSON.stringify(result.trace.stages if result.trace != null else [], "  ")]
	(get_node("Issue") as Button).disabled = result == null or not result.ok()

func result() -> ItemGenerationResult:
	return _result

func focus_controls() -> Array[Control]:
	_ensure_controls()
	return [get_node("Sequence") as Control, get_node("Regenerate") as Control, get_node("Issue") as Control]

func _ensure_controls() -> void:
	if _built:
		return
	_built = true
	var title := Label.new()
	title.text = "Trace Inspector"
	title.add_theme_font_size_override("font_size", 22)
	add_child(title)
	var sequence := SpinBox.new()
	sequence.name = "Sequence"
	sequence.min_value = 0
	sequence.max_value = float(ItemInstanceCodec.JSON_SAFE_INTEGER_MAX)
	sequence.step = 1
	sequence.focus_mode = Control.FOCUS_ALL
	add_child(sequence)
	var regenerate := Button.new()
	regenerate.name = "Regenerate"
	regenerate.text = "Regenerate exact sequence"
	regenerate.focus_mode = Control.FOCUS_ALL
	regenerate.pressed.connect(func() -> void: regenerate_requested.emit(int(sequence.value)))
	add_child(regenerate)
	var issue := Button.new()
	issue.name = "Issue"
	issue.text = "Issue to Sandbox"
	issue.disabled = true
	issue.focus_mode = Control.FOCUS_ALL
	issue.pressed.connect(func() -> void:
		if _result != null and _result.ok():
			issue_requested.emit(_result.item)
	)
	add_child(issue)
	var body := RichTextLabel.new()
	body.name = "Body"
	body.bbcode_enabled = true
	body.fit_content = true
	body.text = "No result selected."
	body.selection_enabled = true
	add_child(body)

func _failure_document(failure: ItemGenerationFailure) -> Dictionary:
	if failure == null:
		return {}
	return {
		"generator_version": failure.generator_version,
		"stage": String(failure.stage),
		"code": String(failure.code),
		"source_id": String(failure.source_id),
		"seed": failure.seed,
		"generation_sequence": failure.generation_sequence,
		"details": failure.details.duplicate(true),
	}
