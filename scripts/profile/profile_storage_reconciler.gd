class_name ProfileStorageReconciler
extends RefCounted

func reconcile(
	profile: ProfileState,
	tree: PassiveTreeDefinition,
	resolver: PassiveEffectResolver
) -> String:
	if profile == null:
		return _error("profile", "must not be null")
	if tree == null:
		return _error("tree", "must not be null")
	if resolver == null:
		return _error("resolver", "must not be null")
	if profile.stash_tabs.size() > ProfileState.MAX_STASH_TABS:
		return _error("stash_tabs", "existing tab count exceeds maximum %d" % ProfileState.MAX_STASH_TABS)

	var saved_allocations: Variant = profile.tree_allocations.get(String(tree.id), [])
	if not saved_allocations is Array:
		return _error("tree_allocations", "tree %s allocations must be an array" % tree.id)
	var allocations: Array[StringName] = []
	for index: int in (saved_allocations as Array).size():
		var allocation: Variant = (saved_allocations as Array)[index]
		if typeof(allocation) != TYPE_STRING:
			return _error("tree_allocations", "tree %s allocation %d must be a string" % [tree.id, index])
		allocations.append(StringName(allocation as String))

	var resolution := resolver.resolve(tree, allocations)
	if resolution == null:
		return _error("resolver", "returned no resolution")
	var resolved_columns := clampi(resolution.flat_value(&"inventory_columns", &"profile"), 0, 8)
	var proposed_columns := maxi(profile.inventory_columns, resolved_columns)
	if proposed_columns < 0 or proposed_columns > 8:
		return _error("inventory_columns", "proposed value must be in range 0..8")

	var resolved_tab_count := 0
	for contract: Dictionary in resolution.stash_tab_contracts():
		if String(contract.get("scope", "")) != "profile":
			continue
		var count_value: Variant = contract.get("count")
		if not _is_json_int(count_value) or int(count_value) <= 0:
			return _error("stash_tabs", "profile contract count must be a positive JSON-safe integer")
		var slots_value: Variant = contract.get("slotsPerTab")
		if not _is_json_int(slots_value) or int(slots_value) != ItemSlotContainer.STASH_CAPACITY:
			return _error("stash_tabs", "profile contract slotsPerTab must equal 100")
		var count := int(count_value)
		if count > ProfileState.MAX_STASH_TABS - resolved_tab_count:
			return _error("stash_tabs", "resolved tab count exceeds maximum %d" % ProfileState.MAX_STASH_TABS)
		resolved_tab_count += count

	var proposed_tabs: Array[Dictionary] = profile.stash_tabs.duplicate(true)
	var existing_ids: Dictionary = {}
	for index: int in proposed_tabs.size():
		var existing := proposed_tabs[index]
		var existing_id_value: Variant = existing.get("container_id")
		if typeof(existing_id_value) == TYPE_STRING:
			existing_ids[String(existing_id_value)] = index
	var target_count := maxi(proposed_tabs.size(), resolved_tab_count)
	while proposed_tabs.size() < target_count:
		var new_index := proposed_tabs.size()
		var stable_id := "stash-tab-%03d" % new_index
		if existing_ids.has(stable_id):
			return _error(
				"stash_tabs",
				"stable container ID %s collides with existing tab at index %d" % [stable_id, int(existing_ids[stable_id])]
			)
		proposed_tabs.append(ItemSlotContainer.create(
			StringName(stable_id),
			ItemSlotContainer.PROFILE_STASH_TAB,
			profile.profile_id,
			ItemSlotContainer.STASH_CAPACITY
		).to_dictionary())
		existing_ids[stable_id] = new_index

	var proposed_containers: Array = [profile.leader_loadout.duplicate(true)]
	proposed_containers.append_array(proposed_tabs.duplicate(true))
	var ownership_document := {
		"schema_version": ItemOwnershipState.SCHEMA_VERSION,
		"owner_id": profile.profile_id,
		"registry": profile.item_records.duplicate(true),
		"containers": proposed_containers,
	}
	var ownership := ItemOwnershipState.decode(
		ownership_document,
		GameCatalog.EQUIPMENT_CATALOG,
		GameCatalog.ITEM_FOUNDATION_CATALOG
	)
	if not ownership.ok():
		var field := "item_records"
		if ownership.error.contains("containers[0]"):
			field = "leader_loadout"
		elif ownership.error.contains("containers"):
			field = "stash_tabs"
		return _error(field, ownership.error)

	profile.inventory_columns = proposed_columns
	profile.stash_tabs = proposed_tabs
	return ""

static func _is_json_int(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return int(value) >= 0 and int(value) <= ProfileCodec.JSON_SAFE_INTEGER_MAX
	if typeof(value) != TYPE_FLOAT:
		return false
	var number := float(value)
	return (
		is_finite(number)
		and number == floor(number)
		and number >= 0.0
		and number <= float(ProfileCodec.JSON_SAFE_INTEGER_MAX)
	)

static func _error(field: String, reason: String) -> String:
	return "PARTY_FORGE_PROFILE_STORAGE_ERROR field=%s reason=%s" % [field, reason]
