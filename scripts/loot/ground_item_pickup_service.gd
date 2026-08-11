class_name GroundItemPickupService
extends RefCounted

const GroundItemPickupResult := preload("res://scripts/loot/ground_item_pickup_result.gd")

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

func collect(drop_id: StringName, input_run_player_id: StringName) -> GroundItemPickupResult:
	var record := _registry.record(drop_id) if _registry != null else null
	if record == null:
		return GroundItemPickupResult.new(GroundItemPickupResult.Code.MISSING)
	if record.run_player_id != input_run_player_id:
		return GroundItemPickupResult.new(GroundItemPickupResult.Code.NOT_OWNER)
	var context := _contexts.context_for(input_run_player_id) if _contexts != null else null
	if context == null:
		return GroundItemPickupResult.new(GroundItemPickupResult.Code.TRANSACTION_REJECTED)
	var leader_id := context.party.members[0].member_id if context.party != null and not context.party.members.is_empty() else -1
	var position := context.member_position(leader_id)
	if not bool(position.get("valid", false)):
		return GroundItemPickupResult.new(GroundItemPickupResult.Code.TRANSACTION_REJECTED)
	if (position.position as Vector3).distance_squared_to(record.world_position) > pickup_radius * pickup_radius:
		return GroundItemPickupResult.new(GroundItemPickupResult.Code.MOVE_CLOSER, "Move closer")
	var inventory := context.run_inventory()
	if inventory == null or inventory.first_empty_slot() < 0:
		return GroundItemPickupResult.new(GroundItemPickupResult.Code.INVENTORY_FULL, "Inventory full")
	var transaction_id := "ground-pickup:%s" % record.drop_id
	var transaction := context.collect_ground_item(record.item_id, transaction_id, _equipment, _foundation)
	if transaction == null or not transaction.ok():
		return GroundItemPickupResult.new(GroundItemPickupResult.Code.TRANSACTION_REJECTED)
	_registry.remove(record.drop_id)
	return GroundItemPickupResult.new(GroundItemPickupResult.Code.OK)
