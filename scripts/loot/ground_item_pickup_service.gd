class_name GroundItemPickupService
extends RefCounted

const GroundItemPickupResult := preload("res://scripts/loot/ground_item_pickup_result.gd")

var pickup_radius := 3.0
var _registry: GroundItemRegistry
var _contexts: RunContextRegistry
var _equipment: EquipmentCatalog
var _foundation: ItemFoundationCatalog
var _successful_results: Dictionary = {}

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
	var owner_results := _successful_results.get(input_run_player_id, {}) as Dictionary
	var prior := owner_results.get(drop_id) as GroundItemPickupResult
	if prior != null:
		return prior.copy()
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
	var item := context.item_state().registry().item(record.item_id)
	var base := _equipment.definition(item.base_definition_id) if _equipment != null and item != null else null
	var rarity := _foundation.rarity(item.rarity_id) if _foundation != null and item != null else null
	var item_name := base.display_name if base != null else "Item"
	var rarity_name := rarity.display_name if rarity != null else String(record.rarity_id).capitalize()
	var transaction := context.collect_ground_item(record.item_id, transaction_id, _equipment, _foundation)
	if transaction == null or not transaction.ok():
		return GroundItemPickupResult.new(GroundItemPickupResult.Code.TRANSACTION_REJECTED)
	_registry.remove(record.drop_id)
	var success := GroundItemPickupResult.new(GroundItemPickupResult.Code.OK, "Picked up %s %s" % [rarity_name, item_name], item_name, rarity_name)
	owner_results[drop_id] = success.copy()
	_successful_results[input_run_player_id] = owner_results
	return success
