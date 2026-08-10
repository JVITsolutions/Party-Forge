class_name EquipmentActivationResult
extends RefCounted

var error := ""
var raw_attributes: ResolvedStatSnapshot
var source: StatModifierSource
var _weapon_snapshot: ActiveWeaponDamageSnapshot
var _active_item_ids: Array[String] = []
var _disabled_reasons_by_item: Dictionary = {}
var active_item_ids: Array[String]:
	get:
		return _active_item_ids.duplicate()

static func success(
	active_ids: Array[String],
	disabled_reasons_by_item: Dictionary,
	raw: ResolvedStatSnapshot,
	equipment_source: StatModifierSource,
	weapon_snapshot: ActiveWeaponDamageSnapshot = null,
) -> EquipmentActivationResult:
	var result := EquipmentActivationResult.new()
	result._active_item_ids = active_ids.duplicate()
	result._active_item_ids.sort()
	for item_id: Variant in disabled_reasons_by_item:
		var reasons := PackedStringArray(disabled_reasons_by_item[item_id])
		reasons.sort()
		result._disabled_reasons_by_item[String(item_id)] = reasons
	result.raw_attributes = raw
	result.source = equipment_source
	result._weapon_snapshot = weapon_snapshot.copy() if weapon_snapshot != null else null
	return result

static func failure(message: String) -> EquipmentActivationResult:
	var result := EquipmentActivationResult.new()
	result.error = message
	return result

func ok() -> bool:
	return error.is_empty() and raw_attributes != null and source != null

func is_active(item_id: String) -> bool:
	return item_id in _active_item_ids

func disabled_reasons(item_id: String) -> PackedStringArray:
	return PackedStringArray(_disabled_reasons_by_item.get(item_id, PackedStringArray()))

func weapon_snapshot() -> ActiveWeaponDamageSnapshot:
	return _weapon_snapshot.copy() if _weapon_snapshot != null else null

func copy() -> EquipmentActivationResult:
	if not ok():
		return EquipmentActivationResult.failure(error)
	var disabled_copy: Dictionary = {}
	for item_id: Variant in _disabled_reasons_by_item:
		disabled_copy[String(item_id)] = PackedStringArray(_disabled_reasons_by_item[item_id])
	return EquipmentActivationResult.success(
		_active_item_ids,
		disabled_copy,
		_copy_raw_attributes(raw_attributes),
		source.duplicate(true) as StatModifierSource,
		_weapon_snapshot,
	)

static func _copy_raw_attributes(value: ResolvedStatSnapshot) -> ResolvedStatSnapshot:
	if value == null:
		return null
	var result := ResolvedStatSnapshot.new()
	result.revision = value.revision
	result.capabilities = value.capabilities
	for attribute_id: StringName in ClassGrowthDefinition.CORE_ATTRIBUTE_IDS:
		result.set_resolved(attribute_id, value.value(attribute_id), value.breakdown(attribute_id))
	return result
