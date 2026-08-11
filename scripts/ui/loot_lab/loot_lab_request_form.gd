class_name LootLabRequestForm
extends VBoxContainer

signal batch_requested(spec: LootLabBatchSpec)

const ARRAY_FIELDS: Array[String] = [
	"permitted_rarity_ids", "party_archetype_tags", "unlock_tags",
	"required_base_tags", "excluded_base_tags", "required_affix_tags", "excluded_affix_tags",
]
const NUMERIC_FIELDS: Array[String] = [
	"seed", "generation_sequence", "item_level", "heat", "charisma_value", "custom_batch_count",
]

var _equipment: EquipmentCatalog
var _foundation: ItemFoundationCatalog
var _preferences_store: DeveloperLootLabPreferencesStore
var _controls: Dictionary = {}
var _built := false

func _ready() -> void:
	_ensure_controls()

func configure(
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	preferences_store: DeveloperLootLabPreferencesStore
) -> void:
	_equipment = equipment
	_foundation = foundation
	_preferences_store = preferences_store
	_ensure_controls()
	_populate_options()
	var loaded := _preferences_store.load() if _preferences_store != null else null
	var document := loaded.document if loaded != null and loaded.ok() else _preferences_store.defaults() if _preferences_store != null else {}
	if not document.is_empty():
		apply_preferences(document)

func build_batch_spec() -> LootLabBatchSpec:
	if _foundation == null or _preferences_store == null:
		return null
	var document := preferences_document()
	var validation := _preferences_store.validate(document)
	if not validation.is_empty():
		_set_error(validation)
		return null
	var request := _request_from_document(document)
	var count := int(document["custom_batch_count"]) if int(document["batch_preset"]) == 0 else int(document["batch_preset"])
	var spec := LootLabBatchSpec.create(request, count, _foundation)
	_set_error(spec.error if not spec.ok() else "")
	return spec

func preferences_document() -> Dictionary:
	_ensure_controls()
	var document := _preferences_store.defaults() if _preferences_store != null else {}
	if document.is_empty():
		return document
	for field: String in NUMERIC_FIELDS:
		var spin := _controls[field] as SpinBox
		document[field] = int(spin.value) if field in ["seed", "generation_sequence", "item_level", "custom_batch_count"] else spin.value
	for field: String in ARRAY_FIELDS:
		document[field] = _parse_names((_controls[field] as LineEdit).text)
	for field: String in ["source_id", "generation_domain", "difficulty_id", "forced_base_id", "forced_rarity_id", "batch_preset"]:
		document[field] = _selected_value(_controls[field] as OptionButton)
	document["batch_preset"] = int(document["batch_preset"])
	return document

func apply_preferences(document: Dictionary) -> String:
	if _preferences_store == null:
		return "PARTY_FORGE_LOOT_LAB_FORM_ERROR reason=preferences store is missing"
	var validation := _preferences_store.validate(document)
	if not validation.is_empty():
		_set_error(validation)
		return validation
	_ensure_controls()
	for field: String in NUMERIC_FIELDS:
		(_controls[field] as SpinBox).value = float(document[field])
	for field: String in ARRAY_FIELDS:
		(_controls[field] as LineEdit).text = ", ".join(document[field] as Array)
	for field: String in ["source_id", "generation_domain", "difficulty_id", "forced_base_id", "forced_rarity_id", "batch_preset"]:
		_select_value(_controls[field] as OptionButton, document[field])
	_set_error("")
	return ""

func focus_controls() -> Array[Control]:
	_ensure_controls()
	var result: Array[Control] = []
	for key: Variant in _controls:
		var control := _controls[key] as Control
		if control != null and control.focus_mode != Control.FOCUS_NONE:
			result.append(control)
	return result

func _ensure_controls() -> void:
	if _built:
		return
	_built = true
	add_theme_constant_override("separation", 6)
	var title := Label.new()
	title.text = "Request"
	title.add_theme_font_size_override("font_size", 22)
	add_child(title)
	var grid := GridContainer.new()
	grid.name = "Fields"
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(grid)
	_add_spin(grid, "seed", "Seed", -float(ItemInstanceCodec.JSON_SAFE_INTEGER_MAX), float(ItemInstanceCodec.JSON_SAFE_INTEGER_MAX), 1.0)
	_add_spin(grid, "generation_sequence", "Start sequence", 0.0, float(ItemInstanceCodec.JSON_SAFE_INTEGER_MAX), 1.0)
	_add_spin(grid, "item_level", "Item level", 1.0, 1000.0, 1.0)
	_add_option(grid, "source_id", "Source")
	_add_option(grid, "generation_domain", "Domain")
	_add_option(grid, "difficulty_id", "Difficulty")
	_add_spin(grid, "heat", "Heat", 0.0, 1000000.0, 0.1)
	_add_spin(grid, "charisma_value", "Charisma", 0.0, 1000000.0, 0.1)
	_add_option(grid, "forced_base_id", "Forced base")
	_add_option(grid, "forced_rarity_id", "Forced rarity")
	for field: String in ARRAY_FIELDS:
		_add_line(grid, field, field.replace("_", " ").capitalize())
	_add_option(grid, "batch_preset", "Batch preset")
	_add_spin(grid, "custom_batch_count", "Custom count", 1.0, float(LootLabBatchSpec.MAX_ATTEMPTS), 1.0)
	var generate := Button.new()
	generate.name = "Generate"
	generate.text = "Generate"
	generate.focus_mode = Control.FOCUS_ALL
	generate.pressed.connect(_on_generate)
	add_child(generate)
	_controls["generate"] = generate
	var error_label := Label.new()
	error_label.name = "ValidationError"
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(error_label)
	_controls["validation_error"] = error_label

func _populate_options() -> void:
	if _foundation == null or _equipment == null:
		return
	_populate(_controls["source_id"] as OptionButton, _foundation.known_source_ids)
	_populate(_controls["generation_domain"] as OptionButton, ItemGenerationVocabulary.DOMAINS)
	_populate(_controls["difficulty_id"] as OptionButton, [&"normal"] as Array[StringName])
	var base_ids: Array[StringName] = [&""]
	for definition: EquipmentBaseDefinition in _equipment.definitions:
		if definition != null:
			base_ids.append(definition.id)
	_populate(_controls["forced_base_id"] as OptionButton, base_ids, "Random eligible")
	var rarity_ids: Array[StringName] = [&""]
	rarity_ids.append_array(_foundation.supported_rarity_ids())
	_populate(_controls["forced_rarity_id"] as OptionButton, rarity_ids, "Weighted eligible")
	var preset := _controls["batch_preset"] as OptionButton
	preset.clear()
	for value: int in DeveloperLootLabPreferencesStore.BATCH_PRESETS:
		preset.add_item("Custom" if value == 0 else "%s" % value)
		preset.set_item_metadata(preset.item_count - 1, value)

func _add_spin(parent: GridContainer, field: String, label: String, minimum: float, maximum: float, step: float) -> void:
	_add_label(parent, label)
	var spin := SpinBox.new()
	spin.name = field.to_pascal_case()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.allow_greater = false
	spin.allow_lesser = false
	spin.focus_mode = Control.FOCUS_ALL
	parent.add_child(spin)
	_controls[field] = spin

func _add_option(parent: GridContainer, field: String, label: String) -> void:
	_add_label(parent, label)
	var option := OptionButton.new()
	option.name = field.to_pascal_case()
	option.focus_mode = Control.FOCUS_ALL
	option.fit_to_longest_item = false
	parent.add_child(option)
	_controls[field] = option

func _add_line(parent: GridContainer, field: String, label: String) -> void:
	_add_label(parent, label)
	var line := LineEdit.new()
	line.name = field.to_pascal_case()
	line.placeholder_text = "comma-separated IDs"
	line.focus_mode = Control.FOCUS_ALL
	parent.add_child(line)
	_controls[field] = line

func _add_label(parent: GridContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	parent.add_child(label)

func _populate(option: OptionButton, values: Array[StringName], empty_label := "") -> void:
	option.clear()
	for value: StringName in values:
		var text := empty_label if value.is_empty() and not empty_label.is_empty() else String(value)
		option.add_item(text)
		option.set_item_metadata(option.item_count - 1, String(value))

func _selected_value(option: OptionButton) -> Variant:
	return option.get_item_metadata(option.selected) if option != null and option.selected >= 0 else ""

func _select_value(option: OptionButton, value: Variant) -> void:
	for index: int in option.item_count:
		if option.get_item_metadata(index) == value or str(option.get_item_metadata(index)) == str(value):
			option.select(index)
			return

func _parse_names(text: String) -> Array[String]:
	var result: Array[String] = []
	for part: String in text.split(",", false):
		var value := part.strip_edges()
		if not value.is_empty():
			result.append(value)
	result.sort()
	return result

func _request_from_document(document: Dictionary) -> ItemGenerationRequest:
	var request := ItemGenerationRequest.create(int(document["seed"]), int(document["generation_sequence"]), int(document["item_level"]), StringName(str(document["source_id"])), StringName(str(document["generation_domain"])), _names(document["permitted_rarity_ids"]))
	request.difficulty_id = StringName(str(document["difficulty_id"]))
	request.heat = float(document["heat"])
	request.charisma_value = float(document["charisma_value"])
	request.party_archetype_tags = _names(document["party_archetype_tags"])
	request.unlock_tags = _names(document["unlock_tags"])
	request.required_base_tags = _names(document["required_base_tags"])
	request.excluded_base_tags = _names(document["excluded_base_tags"])
	request.required_affix_tags = _names(document["required_affix_tags"])
	request.excluded_affix_tags = _names(document["excluded_affix_tags"])
	request.forced_base_id = StringName(str(document["forced_base_id"]))
	request.forced_rarity_id = StringName(str(document["forced_rarity_id"]))
	return request

func _names(values: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for value: Variant in values:
		result.append(StringName(String(value)))
	return result

func _on_generate() -> void:
	var spec := build_batch_spec()
	if spec != null and spec.ok():
		batch_requested.emit(spec)

func _set_error(value: String) -> void:
	if _controls.has("validation_error"):
		(_controls["validation_error"] as Label).text = value
