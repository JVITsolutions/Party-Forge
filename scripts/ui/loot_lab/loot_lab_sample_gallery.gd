class_name LootLabSampleGallery
extends GridContainer

signal sequence_selected(sequence: int)
signal inspection_started(detail: Dictionary, source: StorageSlotButton)
signal inspection_ended(source_id: String)

class PreviewTile extends StorageSlotButton:
	func _get_drag_data(_at_position: Vector2) -> Variant:
		return null

var _equipment: EquipmentCatalog
var _foundation: ItemFoundationCatalog
var _samples: Dictionary = {}

func configure(equipment: EquipmentCatalog, foundation: ItemFoundationCatalog) -> void:
	_equipment = equipment
	_foundation = foundation

func present(report: Dictionary) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()
	_samples.clear()
	var evidence := report.get("evidence", {}) as Dictionary
	var samples := evidence.get("samples", []) as Array
	for index: int in mini(samples.size(), LootLabBatchSpec.SAMPLE_LIMIT):
		var sample := (samples[index] as Dictionary).duplicate(true)
		var sequence := int(sample.get("generation_sequence", -1))
		_samples[sequence] = sample
		var tile: Button
		if String(sample.get("status", "")) == "succeeded" and sample.get("item") is Dictionary:
			tile = _successful_tile(sample, index)
		else:
			tile = _failure_tile(sample)
		tile.set_meta("generation_sequence", sequence)
		tile.pressed.connect(_emit_selection.bind(sequence))
		add_child(tile)

func select_sequence(sequence: int) -> bool:
	for child: Node in get_children():
		if int(child.get_meta("generation_sequence", -1)) == sequence:
			(child as Control).grab_focus()
			sequence_selected.emit(sequence)
			return true
	return false

func sample(sequence: int) -> Dictionary:
	return (_samples.get(sequence, {}) as Dictionary).duplicate(true)

func focus_controls() -> Array[Control]:
	var result: Array[Control] = []
	for child: Node in get_children():
		if child is Control:
			result.append(child as Control)
	return result

func _successful_tile(sample: Dictionary, index: int) -> PreviewTile:
	var tile := PreviewTile.new()
	tile.name = "Sample_%03d" % index
	tile.custom_minimum_size = Vector2(88, 88)
	var decoded := ItemInstanceCodec.decode(sample["item"], _equipment, _foundation)
	if decoded.ok():
		var fixture_class := GameCatalog.load_defaults().class_by_id(&"fighter")
		var detail := ItemPresentationProjector.project(decoded.item, _equipment, _foundation, GameCatalog.STAT_CATALOG, fixture_class)
		detail["source_id"] = "loot-lab-preview:%d" % int(sample["generation_sequence"])
		tile.bind_item(&"loot-lab-preview", index, decoded.item.instance_id, detail)
		tile.inspection_started.connect(func(source: StorageSlotButton) -> void: inspection_started.emit(source.detail(), source))
		tile.inspection_ended.connect(func(source: StorageSlotButton) -> void: inspection_ended.emit(source.source_id()))
	else:
		tile.bind_item(&"loot-lab-preview", index, "", {})
		tile.text = "Invalid"
	return tile

func _failure_tile(sample: Dictionary) -> Button:
	var tile := Button.new()
	tile.custom_minimum_size = Vector2(88, 88)
	tile.focus_mode = Control.FOCUS_ALL
	var failure := sample.get("failure", {}) as Dictionary
	tile.text = "FAILED\n%s/%s" % [failure.get("stage", "result"), failure.get("code", "invalid")]
	tile.tooltip_text = JSON.stringify(failure, "  ")
	return tile

func _emit_selection(sequence: int) -> void:
	sequence_selected.emit(sequence)
