class_name GroundItemPickupService
extends RefCounted

const RESULT := preload("res://scripts/loot/ground_item_pickup_result.gd")

var pickup_radius := 3.0
var _registry: GroundItemRegistry
var _contexts: RunContextRegistry
var _equipment: EquipmentCatalog
var _foundation: ItemFoundationCatalog

func _init(
	registry: GroundItemRegistry = null,
	contexts: RunContextRegistry = null,
	equipment: EquipmentCatalog = null,
	foundation: ItemFoundationCatalog = null,
	pickup_radius_value: float = 3.0,
) -> void:
	_registry = registry
	_contexts = contexts
	_equipment = equipment
	_foundation = foundation
	pickup_radius = maxf(pickup_radius_value, 0.0)

func collect(drop_id: StringName, input_run_player_id: StringName) -> RefCounted:
	var record := _registry.record(drop_id) if _registry != null else null
	if record == null:
		return RESULT.new(RESULT.Code.MISSING)
	if record.run_player_id != input_run_player_id:
		return RESULT.new(RESULT.Code.NOT_OWNER)
	var context := _contexts.context_for(input_run_player_id) if _contexts != null else null
	if context == null:
		return RESULT.new(RESULT.Code.TRANSACTION_REJECTED)
	var leader_id := context.party.members[0].member_id if context.party != null and not context.party.members.is_empty() else -1
	var position := context.member_position(leader_id)
	if not bool(position.get("valid", false)):
		return RESULT.new(RESULT.Code.TRANSACTION_REJECTED)
	if (position.position as Vector3).distance_squared_to(record.world_position) > pickup_radius * pickup_radius:
		return RESULT.new(RESULT.Code.MOVE_CLOSER, "Move closer")
	var inventory := context.run_inventory()
	if inventory == null or inventory.first_empty_slot() < 0:
		return RESULT.new(RESULT.Code.INVENTORY_FULL, "Inventory full")
	var transaction_id := "ground-pickup:%s" % record.drop_id
	var transaction := context.collect_ground_item(record.item_id, transaction_id, _equipment, _foundation)
	if transaction == null or not transaction.ok():
		return RESULT.new(RESULT.Code.TRANSACTION_REJECTED)
	_registry.remove(record.drop_id)
	return RESULT.new(RESULT.Code.OK)
