class_name StorageSlotButton
extends Button

signal item_dropped(source_container_id: StringName, source_slot: int, item_id: String, destination_container_id: StringName, destination_slot: int)

var container_id: StringName
var slot := -1
var item_id := ""

func bind(container_id_value: StringName, slot_value: int, item_id_value: String, label: String) -> void:
	container_id = container_id_value
	slot = slot_value
	item_id = item_id_value
	text = label
	tooltip_text = label
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _get_drag_data(_position: Vector2) -> Variant:
	if item_id.is_empty():
		return null
	var preview := Label.new()
	preview.text = text
	set_drag_preview(preview)
	return {"container_id": String(container_id), "slot": slot, "item_id": item_id}

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and not String((data as Dictionary).get("item_id", "")).is_empty()

func _drop_data(_position: Vector2, data: Variant) -> void:
	var source := data as Dictionary
	item_dropped.emit(StringName(String(source["container_id"])), int(source["slot"]), String(source["item_id"]), container_id, slot)
