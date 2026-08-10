class_name ActiveWeaponDamageSnapshot
extends RefCounted

var _member_id := 0
var member_id: int:
	get:
		return _member_id
var _item_id := ""
var item_id: String:
	get:
		return _item_id
var _base_id: StringName
var base_id: StringName:
	get:
		return _base_id
var _components: Array[ItemBaseDamageComponent] = []
var components: Array[ItemBaseDamageComponent]:
	get:
		return _copy_components(_components)
var _revision := 0
var revision: int:
	get:
		return _revision

static func create(
	member_id: int,
	item_id: String,
	base_id: StringName,
	components: Array[ItemBaseDamageComponent],
	revision: int,
) -> ActiveWeaponDamageSnapshot:
	var result := ActiveWeaponDamageSnapshot.new()
	result._member_id = member_id
	result._item_id = item_id
	result._base_id = base_id
	result._components = _copy_components(components)
	result._components.sort_custom(func(left: ItemBaseDamageComponent, right: ItemBaseDamageComponent) -> bool:
		if left == null:
			return right != null
		if right == null:
			return false
		return String(left.damage_type_id) < String(right.damage_type_id)
	)
	result._revision = revision
	return result

func copy() -> ActiveWeaponDamageSnapshot:
	return create(_member_id, _item_id, _base_id, _components, _revision)

static func _copy_components(values: Array[ItemBaseDamageComponent]) -> Array[ItemBaseDamageComponent]:
	var result: Array[ItemBaseDamageComponent] = []
	for component: ItemBaseDamageComponent in values:
		result.append(component.copy() if component != null else null)
	return result
