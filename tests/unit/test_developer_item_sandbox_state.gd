extends RefCounted

const STATE_PATH := "res://scripts/dev/developer_item_sandbox_state.gd"
const STORE_PATH := "res://scripts/dev/developer_item_sandbox_store.gd"
const FIXTURE_ISSUER_PATH := "res://scripts/dev/developer_item_fixture_issuer.gd"
const LOOT_ISSUER_PATH := "res://scripts/dev/developer_loot_lab_item_issuer.gd"
const DOCUMENT_PATH := "user://developer_item_sandbox/sandbox.json"
const SANDBOX_ROOT := "user://developer_item_sandbox"
const OWNER_ID := "developer-item-sandbox"
const INVENTORY_ID := &"developer-inventory"
const STASH_ID := &"developer-stash-000"
const ISSUER_NAMESPACE := "sandbox:developer-item-sandbox"

var _state_script: Script
var _store_script: Script

func run() -> Array[String]:
	var failures: Array[String] = []
	var required_paths: Array[String] = [FIXTURE_ISSUER_PATH, LOOT_ISSUER_PATH, STATE_PATH, STORE_PATH]
	for path: String in required_paths:
		TestAssertions.truthy(ResourceLoader.exists(path), "Task 8 resource exists: %s" % path, failures)
	if not failures.is_empty():
		return failures
	_state_script = load(STATE_PATH) as Script
	_store_script = load(STORE_PATH) as Script
	TestAssertions.truthy(_state_script != null, "sandbox state script loads", failures)
	TestAssertions.truthy(_store_script != null, "sandbox store script loads", failures)
	if _state_script == null or _store_script == null:
		return failures

	_cleanup_sandbox_files()
	_assert_deterministic_fixture(failures)
	_assert_schema_one_migrates_to_schema_two(failures)
	_assert_schema_two_generated_journal_replays(failures)
	_assert_explicit_affixes_survive_reload(failures)
	_assert_movement_replay_collision_and_reset(failures)
	_assert_public_slot_transactions_and_integrity(failures)
	_assert_forged_journal_documents_fail_atomically(failures)
	_assert_strict_reload_is_failure_atomic(failures)
	_assert_corrupt_generations_reset_recovery(failures)
	_assert_atomic_save_failure_and_profile_isolation(failures)
	_cleanup_sandbox_files()
	return failures

func _assert_schema_one_migrates_to_schema_two(failures: Array[String]) -> void:
	_cleanup_sandbox_files()
	var seed: Variant = _state_script.new()
	TestAssertions.equal(seed.reset(), "", "migration fixture reset succeeds", failures)
	var schema_one: Dictionary = seed.to_dictionary()
	var original_ownership: Dictionary = schema_one["ownership_state"].duplicate(true)
	schema_one["schema_version"] = 1
	schema_one["issuance_metadata"]["schema_version"] = 1
	schema_one["issuance_metadata"].erase("next_generated_item_sequence")
	_write_text(DOCUMENT_PATH, JSON.stringify(schema_one, "\t", false))

	var migrated: Variant = _state_script.new()
	TestAssertions.equal(migrated.reload(), "", "schema-one sandbox reload migrates atomically", failures)
	var migrated_document: Dictionary = migrated.to_dictionary()
	TestAssertions.equal(int(migrated_document.get("schema_version", -1)), 2, "migration publishes schema two", failures)
	TestAssertions.equal(int(migrated_document["issuance_metadata"].get("next_generated_item_sequence", -1)), 0, "schema one migrates generated sequence zero", failures)
	TestAssertions.equal(migrated.registry().size(), 99, "migration preserves exact fixture count", failures)
	TestAssertions.equal(migrated_document["ownership_state"], original_ownership, "migration preserves exact fixture items and placements", failures)
	var persisted := JSON.parse_string(FileAccess.get_file_as_string(DOCUMENT_PATH)) as Dictionary
	TestAssertions.equal(int(persisted.get("schema_version", -1)), 2, "migration promotes schema two before publishing state", failures)

func _assert_schema_two_generated_journal_replays(failures: Array[String]) -> void:
	_cleanup_sandbox_files()
	var seed: Variant = _state_script.new()
	TestAssertions.equal(seed.reset(), "", "schema-two generated replay fixture resets", failures)
	var base_document: Dictionary = seed.to_dictionary()
	var decoded: Dictionary = (_store_script.new() as DeveloperItemSandboxStore).decode_document(base_document)
	var candidate := decoded["state"] as ItemOwnershipState
	var journal := ItemTransactionJournal.new()
	var preview := _generated_preview(failures)
	if preview == null:
		return
	var issued := DeveloperLootLabItemIssuer.reissue(preview, 0, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	TestAssertions.truthy(issued.ok(), "schema-two replay fixture reissues preview", failures)
	if not issued.ok():
		return
	var transactions := ItemContainerTransactionService.new()
	var created := transactions.apply(
		candidate,
		ItemTransactionRequest.create("sandbox-transaction-%016d" % 0, OWNER_ID, STASH_ID, 99, issued.item),
		journal,
		GameCatalog.EQUIPMENT_CATALOG,
		GameCatalog.ITEM_FOUNDATION_CATALOG
	)
	TestAssertions.equal(created.code, ItemTransactionResult.Code.OK, "generated create transaction applies", failures)
	if created.code != ItemTransactionResult.Code.OK:
		return
	candidate = created.next_state
	var moved := transactions.apply(
		candidate,
		ItemTransactionRequest.move("sandbox-transaction-%016d" % 1, OWNER_ID, STASH_ID, 99, issued.item.instance_id, INVENTORY_ID, 0),
		journal,
		GameCatalog.EQUIPMENT_CATALOG,
		GameCatalog.ITEM_FOUNDATION_CATALOG
	)
	TestAssertions.equal(moved.code, ItemTransactionResult.Code.OK, "generated move transaction applies", failures)
	if moved.code != ItemTransactionResult.Code.OK:
		return
	var metadata: Dictionary = base_document["issuance_metadata"].duplicate(true)
	metadata["next_transaction_sequence"] = 2
	metadata["next_generated_item_sequence"] = 1
	var store := _store_script.new() as DeveloperItemSandboxStore
	var document := store.document_for(moved.next_state, metadata, journal)
	TestAssertions.equal(store.validate_document(document), "", "schema-two create-then-move journal validates exactly", failures)
	TestAssertions.equal(store.save_document(document), "", "schema-two generated journal saves", failures)
	var reloaded: Variant = _state_script.new()
	TestAssertions.equal(reloaded.reload(), "", "schema-two generated journal reloads", failures)
	TestAssertions.equal(reloaded.inventory().item_id_at(0), issued.item.instance_id, "replay preserves generated item placement", failures)
	TestAssertions.equal(reloaded.registry().size(), 100, "replay preserves 99 fixtures plus generated item", failures)

func _generated_preview(failures: Array[String]) -> ItemInstance:
	var request := ItemGenerationRequest.create(101, 4, 500, &"ordinary_enemy", &"ordinary_drop", [&"rare"] as Array[StringName])
	request.forced_base_id = &"forge_vanguard_sword"
	request.forced_rarity_id = &"rare"
	request.unlock_tags = [&"rarity_rare_unlocked"]
	var generated := ItemGenerationService.generate(request, "loot-lab-preview:test", 4, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	TestAssertions.truthy(generated.ok(), "generated journal preview fixture succeeds", failures)
	return generated.item if generated.ok() else null

func _assert_deterministic_fixture(failures: Array[String]) -> void:
	_cleanup_sandbox_files()
	var first: Variant = _state_script.new()
	var first_reset_error: String = first.reset()
	TestAssertions.equal(first_reset_error, "", "first sandbox reset succeeds", failures)
	if not first_reset_error.is_empty():
		return
	var first_document: Dictionary = first.to_dictionary()
	var first_bytes := JSON.stringify(first_document)
	var first_hash := first_bytes.sha256_text()

	var second: Variant = _state_script.new()
	var second_reset_error: String = second.reset()
	TestAssertions.equal(second_reset_error, "", "second independent sandbox reset succeeds", failures)
	if not second_reset_error.is_empty():
		return
	var second_document: Dictionary = second.to_dictionary()
	var second_hash := JSON.stringify(second_document).sha256_text()
	print("DEVELOPER_ITEM_SANDBOX_SHA256: %s" % second_hash)

	TestAssertions.equal(first_document, second_document, "independent resets are byte-equivalent", failures)
	TestAssertions.equal(first_hash, second_hash, "independent resets print the same deterministic hash", failures)
	TestAssertions.equal(first.integrity_error(), "", "canonical reset has no integrity error", failures)
	TestAssertions.equal(first.registry().size(), 99, "sandbox issues all 99 equipment bases", failures)
	TestAssertions.equal(first.inventory().container_id, INVENTORY_ID, "sandbox inventory id is exact", failures)
	TestAssertions.equal(first.inventory().capacity, 5, "sandbox inventory is five slots", failures)
	TestAssertions.equal(first.inventory().occupied_slots(), [], "sandbox inventory begins empty", failures)
	TestAssertions.equal(first.stash().container_id, STASH_ID, "sandbox stash id is exact", failures)
	TestAssertions.equal(first.stash().capacity, 100, "sandbox stash is 100 slots", failures)
	TestAssertions.equal(first.stash().occupied_slots().size(), 99, "sandbox fills 99 stash slots", failures)
	TestAssertions.equal(first.stash().first_empty_slot(), 99, "last stash slot remains empty", failures)

	var equipment := GameCatalog.EQUIPMENT_CATALOG
	var foundation := GameCatalog.ITEM_FOUNDATION_CATALOG
	var registry: ItemRegistry = first.registry()
	var seen_bases: Dictionary = {}
	var seen_rarities: Dictionary = {}
	for index: int in equipment.definitions.size():
		var definition: Variant = equipment.definitions[index]
		TestAssertions.truthy(definition != null, "catalog definition %d exists" % index, failures)
		if definition == null:
			continue
		var expected_issue := ItemInstanceIssuer.issue(
			ISSUER_NAMESPACE,
			index,
			"developer_item_fixture",
			index,
			{
				"affixes": [],
				"base_definition_id": String(definition.id),
				"base_damage_components": [],
				"item_level": 1 + (index % 100),
				"rarity_id": "common",
			},
			equipment,
			foundation
		)
		TestAssertions.truthy(expected_issue.ok(), "expected issuer id derives for catalog index %d" % index, failures)
		if not expected_issue.ok():
			continue
		var expected_id: String = expected_issue.item.instance_id
		TestAssertions.truthy(registry.has(expected_id), "issuer-derived id exists for %s" % definition.id, failures)
		var actual := registry.item(expected_id)
		if actual == null:
			continue
		seen_bases[String(actual.base_definition_id)] = int(seen_bases.get(String(actual.base_definition_id), 0)) + 1
		seen_rarities[String(actual.rarity_id)] = true
		TestAssertions.equal(actual.base_definition_id, definition.id, "catalog order maps to issued base at %d" % index, failures)
		TestAssertions.equal(actual.item_level, 1 + (index % 100), "catalog order maps to explicit item level at %d" % index, failures)
		TestAssertions.equal(first.stash().item_id_at(index), expected_id, "catalog order maps to exact stash slot %d" % index, failures)
	for definition: Variant in equipment.definitions:
		TestAssertions.equal(int(seen_bases.get(String(definition.id), 0)), 1, "equipment base %s appears exactly once" % definition.id, failures)
	for rarity_id: StringName in foundation.ordinary_rarity_ids():
		TestAssertions.truthy(seen_rarities.has(String(rarity_id)), "ordinary rarity %s appears" % rarity_id, failures)
	TestAssertions.truthy(not seen_rarities.has("mythic"), "Mythic is never issued", failures)
	TestAssertions.truthy(not seen_rarities.has("eternal"), "Eternal is never issued", failures)

	var escaped: Dictionary = first.to_dictionary()
	escaped["owner_id"] = "mutated-owner"
	escaped["issuance_metadata"]["issued_count"] = 0
	escaped["ownership_state"]["containers"][0]["capacity"] = 0
	TestAssertions.equal(first.to_dictionary(), first_document, "sandbox public document is defensive", failures)

func _assert_explicit_affixes_survive_reload(failures: Array[String]) -> void:
	_cleanup_sandbox_files()
	var state: Variant = _state_script.new()
	var reset_error: String = state.reset()
	TestAssertions.equal(reset_error, "", "affix fixture reset succeeds", failures)
	if not reset_error.is_empty():
		return
	var equipment := GameCatalog.EQUIPMENT_CATALOG
	var foundation := GameCatalog.ITEM_FOUNDATION_CATALOG
	var registry_before: Dictionary = state.registry().to_dictionary()
	for item_document: Dictionary in registry_before["items"]:
		var decoded := ItemInstanceCodec.decode(item_document, equipment, foundation)
		TestAssertions.truthy(decoded.ok(), "fixture item %s validates" % item_document["instance_id"], failures)
		if not decoded.ok():
			continue
		var item := decoded.item
		if item.rarity_id == &"common":
			TestAssertions.equal(item.affixes.size(), 0, "Common fixture has no affixes", failures)
			continue
		TestAssertions.truthy(not item.affixes.is_empty(), "non-Common fixture has explicit affixes", failures)
		for affix: ItemAffixInstance in item.affixes:
			var definition := foundation.affix(affix.definition_id)
			TestAssertions.truthy(definition != null, "fixture affix definition exists", failures)
			if definition == null:
				continue
			TestAssertions.truthy(definition.tier_definition(affix.tier) != null, "fixture affix tier is authored", failures)
			TestAssertions.equal(affix.affix_kind, definition.affix_kind, "fixture affix kind is explicit", failures)
			TestAssertions.equal(affix.rolls.size(), definition.effects.size(), "fixture affix has one roll per effect", failures)
			if affix.rolls.is_empty():
				continue
			for effect_index: int in affix.rolls.size():
				var roll: ItemModifierRoll = affix.rolls[effect_index]
				var effect := definition.effects[effect_index]
				var bounds: Vector2 = definition.roll_bounds(affix.tier, effect_index)
				TestAssertions.equal(roll.operation, effect.operation, "fixture roll operation is explicit", failures)
				TestAssertions.truthy(roll.value >= bounds.x and roll.value <= bounds.y, "fixture roll remains inside authored bounds", failures)
	TestAssertions.equal(state.save(), "", "explicit fixture saves", failures)
	var reloaded: Variant = _state_script.new()
	TestAssertions.equal(reloaded.reload(), "", "explicit fixture reloads", failures)
	TestAssertions.equal(reloaded.registry().to_dictionary(), registry_before, "reload preserves exact issued affixes without recalculation", failures)

func _assert_movement_replay_collision_and_reset(failures: Array[String]) -> void:
	_cleanup_sandbox_files()
	var state: Variant = _state_script.new()
	var reset_error: String = state.reset()
	TestAssertions.equal(reset_error, "", "movement fixture reset succeeds", failures)
	if not reset_error.is_empty():
		return
	var canonical: Dictionary = state.to_dictionary()
	var first_item_id: String = state.stash().item_id_at(0)
	TestAssertions.equal(state.move_to_first_empty_inventory(first_item_id), "", "move to first empty inventory succeeds", failures)
	TestAssertions.equal(state.inventory().item_id_at(0), first_item_id, "move uses exact first inventory slot", failures)
	TestAssertions.equal(state.stash().item_id_at(0), "", "move clears exact stash source", failures)
	TestAssertions.equal(state.move_to_first_empty_stash(first_item_id), "", "move back to first empty stash succeeds", failures)
	TestAssertions.equal(state.stash().item_id_at(0), first_item_id, "move back restores exact first empty stash slot", failures)
	TestAssertions.equal(state.inventory().item_id_at(0), "", "move back clears exact inventory source", failures)
	var moved_document: Dictionary = state.to_dictionary()
	var strict_store: Variant = _store_script.new()
	var sequence_mismatch := moved_document.duplicate(true)
	sequence_mismatch["issuance_metadata"]["next_transaction_sequence"] = 0
	TestAssertions.truthy(
		not String(strict_store.validate_document(sequence_mismatch)).is_empty(),
		"journal length must match next transaction sequence",
		failures
	)
	var rewound := moved_document.duplicate(true)
	rewound["ownership_state"] = rewound["transaction_journal"][0]["state"].duplicate(true)
	TestAssertions.truthy(
		not String(strict_store.validate_document(rewound)).is_empty(),
		"current ownership must match the final serialized journal entry",
		failures
	)
	var unjournaled_move := moved_document.duplicate(true)
	unjournaled_move["ownership_state"] = unjournaled_move["transaction_journal"][0]["state"].duplicate(true)
	unjournaled_move["issuance_metadata"]["next_transaction_sequence"] = 0
	unjournaled_move["transaction_journal"] = []
	TestAssertions.truthy(
		not String(strict_store.validate_document(unjournaled_move)).is_empty(),
		"empty journal must retain exact canonical reset placement",
		failures
	)
	TestAssertions.equal(state.save(), "", "moved sandbox saves", failures)
	var reloaded: Variant = _state_script.new()
	TestAssertions.equal(reloaded.reload(), "", "moved sandbox reloads", failures)
	TestAssertions.equal(reloaded.to_dictionary(), moved_document, "save/reload preserves exact moved placement and journal", failures)

	var request := ItemTransactionRequest.move(
		"sandbox-transaction-%016d" % 2,
		OWNER_ID,
		STASH_ID,
		1,
		reloaded.stash().item_id_at(1),
		INVENTORY_ID,
		0
	)
	var first: Variant = reloaded._apply_transaction(request)
	TestAssertions.equal(first.code, ItemTransactionResult.Code.OK, "explicit sandbox transaction succeeds", failures)
	var state_after_first: Dictionary = reloaded.to_dictionary()
	var bytes_after_first: PackedByteArray = FileAccess.get_file_as_bytes(DOCUMENT_PATH)
	var replay: Variant = reloaded._apply_transaction(request)
	TestAssertions.equal(replay.code, ItemTransactionResult.Code.TRANSACTION_REPLAY, "duplicate sandbox transaction preserves Task 4 replay code", failures)
	TestAssertions.truthy(replay.duplicate, "duplicate sandbox transaction is marked replay", failures)
	TestAssertions.equal(reloaded.to_dictionary(), state_after_first, "duplicate replay preserves sandbox state", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(DOCUMENT_PATH), bytes_after_first, "duplicate replay preserves storage bytes", failures)
	var collision_request := ItemTransactionRequest.move(
		"sandbox-transaction-%016d" % 2,
		OWNER_ID,
		STASH_ID,
		2,
		reloaded.stash().item_id_at(2),
		INVENTORY_ID,
		1
	)
	var collision: Variant = reloaded._apply_transaction(collision_request)
	TestAssertions.equal(collision.code, ItemTransactionResult.Code.TRANSACTION_COLLISION, "sandbox transaction id collision preserves Task 4 code", failures)
	TestAssertions.equal(reloaded.to_dictionary(), state_after_first, "transaction collision preserves sandbox state", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(DOCUMENT_PATH), bytes_after_first, "transaction collision preserves storage bytes", failures)

	TestAssertions.equal(reloaded.reset(), "", "reset after mutations succeeds", failures)
	TestAssertions.equal(reloaded.to_dictionary(), canonical, "reset after mutations reproduces canonical document", failures)
	TestAssertions.equal(JSON.stringify(reloaded.to_dictionary()).sha256_text(), JSON.stringify(canonical).sha256_text(), "reset after mutations reproduces canonical hash", failures)

func _assert_public_slot_transactions_and_integrity(failures: Array[String]) -> void:
	_cleanup_sandbox_files()
	var state: Variant = _state_script.new()
	TestAssertions.equal(state.reset(), "", "public slot transaction fixture resets", failures)
	var has_transfer: bool = state.has_method(&"transfer_slots")
	var has_scan: bool = state.has_method(&"scan_integrity")
	TestAssertions.truthy(has_transfer, "sandbox exposes a public slot transaction method", failures)
	TestAssertions.truthy(has_scan, "sandbox exposes a public read-only integrity scan", failures)
	if not has_transfer or not has_scan:
		return
	var first_item_id: String = state.stash().item_id_at(0)
	var second_item_id: String = state.stash().item_id_at(1)
	TestAssertions.equal(
		state.call(&"transfer_slots", STASH_ID, 0, INVENTORY_ID, 3),
		"",
		"public slot move accepts an explicit empty destination",
		failures
	)
	TestAssertions.equal(state.inventory().item_id_at(3), first_item_id, "public slot move preserves the exact destination", failures)
	TestAssertions.equal(state.stash().item_id_at(0), "", "public slot move clears the exact source", failures)
	TestAssertions.equal(
		state.call(&"transfer_slots", INVENTORY_ID, 3, STASH_ID, 1),
		"",
		"public slot transaction swaps with an occupied destination",
		failures
	)
	TestAssertions.equal(state.inventory().item_id_at(3), second_item_id, "public swap returns the destination item to the source slot", failures)
	TestAssertions.equal(state.stash().item_id_at(1), first_item_id, "public swap places the source item in the destination slot", failures)
	var valid_document: Dictionary = state.to_dictionary()
	var valid_bytes: PackedByteArray = FileAccess.get_file_as_bytes(DOCUMENT_PATH)
	TestAssertions.equal((_store_script.new()).validate_document(valid_document), "", "strict store accepts exact public move and swap journal entries", failures)
	TestAssertions.equal(state.call(&"scan_integrity"), "", "read-only integrity scan accepts the usable state", failures)
	TestAssertions.equal(state.to_dictionary(), valid_document, "integrity scan preserves in-memory state", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(DOCUMENT_PATH), valid_bytes, "integrity scan preserves persisted bytes", failures)
	var invalid_error: String = state.call(&"transfer_slots", STASH_ID, 99, INVENTORY_ID, 0)
	TestAssertions.truthy(not invalid_error.is_empty(), "invalid public slot transaction reports an exact domain error", failures)
	TestAssertions.equal(state.to_dictionary(), valid_document, "failed public slot transaction preserves usable state", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(DOCUMENT_PATH), valid_bytes, "failed public slot transaction preserves persisted bytes", failures)
	var reloaded: Variant = _state_script.new()
	TestAssertions.equal(reloaded.reload(), "", "public move and swap journal reloads", failures)
	TestAssertions.equal(reloaded.to_dictionary(), valid_document, "reload preserves exact public move and swap placement", failures)

func _assert_strict_reload_is_failure_atomic(failures: Array[String]) -> void:
	var store: Variant = _store_script.new()
	var unknown := _minimal_unknown_document()
	TestAssertions.truthy(not String(store.validate_document(unknown)).is_empty(), "unknown sandbox fields fail strict validation", failures)
	var corrupt := unknown.duplicate(true)
	corrupt.erase("unknown")
	corrupt["ownership_state"] = {"corrupt": true}
	TestAssertions.truthy(not String(store.validate_document(corrupt)).is_empty(), "corrupt ownership document fails strict validation", failures)

	var malformed_cases: Array[String] = ["{ malformed", JSON.stringify(unknown), JSON.stringify(corrupt)]
	for index: int in malformed_cases.size():
		_cleanup_sandbox_files()
		var state: Variant = _state_script.new()
		var reset_error: String = state.reset()
		TestAssertions.equal(reset_error, "", "strict reload fixture reset %d succeeds" % index, failures)
		if not reset_error.is_empty():
			continue
		var before: Dictionary = state.to_dictionary()
		_write_text(DOCUMENT_PATH, malformed_cases[index])
		_write_text("%s.bak" % DOCUMENT_PATH, malformed_cases[index])
		var reload_error: String = state.reload()
		TestAssertions.truthy(not reload_error.is_empty(), "malformed sandbox document %d is rejected" % index, failures)
		TestAssertions.equal(state.to_dictionary(), before, "failed reload %d preserves usable in-memory state" % index, failures)

func _assert_forged_journal_documents_fail_atomically(failures: Array[String]) -> void:
	_cleanup_sandbox_files()
	var seed_state: Variant = _state_script.new()
	var reset_error: String = seed_state.reset()
	TestAssertions.equal(reset_error, "", "forgery fixture reset succeeds", failures)
	if not reset_error.is_empty():
		return
	var canonical: Dictionary = seed_state.to_dictionary()
	var moved_item_id: String = seed_state.stash().item_id_at(0)
	TestAssertions.equal(seed_state.move_to_first_empty_inventory(moved_item_id), "", "forgery fixture move succeeds", failures)
	var valid_moved: Dictionary = seed_state.to_dictionary()
	TestAssertions.equal((valid_moved["transaction_journal"] as Array).size(), 1, "forgery fixture has one journal entry", failures)

	var forged_fingerprint := valid_moved.duplicate(true)
	forged_fingerprint["transaction_journal"][0]["fingerprint"] = "0".repeat(64)
	var forged_rewind := valid_moved.duplicate(true)
	forged_rewind["ownership_state"] = canonical["ownership_state"].duplicate(true)
	forged_rewind["transaction_journal"][0]["state"] = canonical["ownership_state"].duplicate(true)
	var forged_item_level := valid_moved.duplicate(true)
	_change_item_level(forged_item_level["ownership_state"] as Dictionary, moved_item_id, 100)
	_change_item_level(forged_item_level["transaction_journal"][0]["state"] as Dictionary, moved_item_id, 100)
	var forged_identity := valid_moved.duplicate(true)
	var replaced_item_id := String(_container_document(forged_identity["ownership_state"] as Dictionary, STASH_ID)["slots"]["1"])
	var replacement_item_id := "%s-forged" % replaced_item_id
	_change_item_identity(forged_identity["ownership_state"] as Dictionary, replaced_item_id, replacement_item_id)
	_change_item_identity(forged_identity["transaction_journal"][0]["state"] as Dictionary, replaced_item_id, replacement_item_id)

	var cases: Array[Dictionary] = [
		{"label": "forged fingerprint", "document": forged_fingerprint},
		{"label": "rewound successful move", "document": forged_rewind},
		{"label": "mutated item level", "document": forged_item_level},
		{"label": "missing canonical and extra forged item id", "document": forged_identity},
	]
	var store: Variant = _store_script.new()
	var non_first_empty := valid_moved.duplicate(true)
	var non_first_state: Dictionary = canonical["ownership_state"].duplicate(true)
	var non_first_inventory := _container_document(non_first_state, INVENTORY_ID)
	var non_first_stash := _container_document(non_first_state, STASH_ID)
	non_first_inventory["slots"]["1"] = moved_item_id
	non_first_stash["slots"].erase("0")
	non_first_empty["ownership_state"] = non_first_state
	non_first_empty["transaction_journal"][0]["state"] = non_first_state.duplicate(true)
	non_first_empty["transaction_journal"][0]["fingerprint"] = ItemTransactionRequest.move(
		"sandbox-transaction-%016d" % 0,
		OWNER_ID,
		STASH_ID,
		0,
		moved_item_id,
		INVENTORY_ID,
		1
	).fingerprint()
	var multiple_move := valid_moved.duplicate(true)
	var multiple_state: Dictionary = valid_moved["ownership_state"].duplicate(true)
	var second_item_id: String = String(_container_document(multiple_state, STASH_ID)["slots"]["1"])
	_container_document(multiple_state, INVENTORY_ID)["slots"]["1"] = second_item_id
	_container_document(multiple_state, STASH_ID)["slots"].erase("1")
	multiple_move["ownership_state"] = multiple_state
	multiple_move["transaction_journal"][0]["state"] = multiple_state.duplicate(true)
	var swap_document := valid_moved.duplicate(true)
	var swap_state: Dictionary = valid_moved["ownership_state"].duplicate(true)
	_container_document(swap_state, INVENTORY_ID)["slots"]["0"] = second_item_id
	_container_document(swap_state, STASH_ID)["slots"]["1"] = moved_item_id
	swap_document["ownership_state"] = swap_state
	swap_document["issuance_metadata"]["next_transaction_sequence"] = 2
	swap_document["transaction_journal"].append({
		"transaction_id": "sandbox-transaction-%016d" % 1,
		"fingerprint": ItemTransactionRequest.swap(
			"sandbox-transaction-%016d" % 1,
			OWNER_ID,
			INVENTORY_ID,
			0,
			moved_item_id,
			STASH_ID,
			1
		).fingerprint(),
		"code": ItemTransactionResult.Code.OK,
		"state": swap_state.duplicate(true),
	})
	TestAssertions.equal(store.validate_document(non_first_empty), "", "exact non-first-empty move is a valid selected-slot transition", failures)
	TestAssertions.equal(store.validate_document(swap_document), "", "exact occupied-destination swap is a valid selected-slot transition", failures)
	var forged_swap := swap_document.duplicate(true)
	forged_swap["transaction_journal"][1]["fingerprint"] = "0".repeat(64)
	var transition_forgeries: Array[Dictionary] = [
		{"label": "multiple-item move", "document": multiple_move},
		{"label": "forged swap fingerprint", "document": forged_swap},
	]
	for test_case: Dictionary in transition_forgeries:
		TestAssertions.truthy(
			not String(store.validate_document(test_case["document"] as Dictionary)).is_empty(),
			"%s fails strict sandbox validation" % String(test_case["label"]),
			failures
		)
	for test_case: Dictionary in cases:
		var label := String(test_case["label"])
		var forged := test_case["document"] as Dictionary
		TestAssertions.truthy(
			not String(store.validate_document(forged)).is_empty(),
			"%s fails strict sandbox validation" % label,
			failures
		)
		_cleanup_sandbox_files()
		var state: Variant = _state_script.new()
		TestAssertions.equal(state.reset(), "", "%s reload fixture reset succeeds" % label, failures)
		TestAssertions.equal(state.move_to_first_empty_inventory(state.stash().item_id_at(0)), "", "%s reload fixture move succeeds" % label, failures)
		var before_memory: Dictionary = state.to_dictionary()
		var forged_text := JSON.stringify(forged, "\t", false)
		_write_text(DOCUMENT_PATH, forged_text)
		_write_text("%s.bak" % DOCUMENT_PATH, forged_text)
		var before_primary: PackedByteArray = FileAccess.get_file_as_bytes(DOCUMENT_PATH)
		var before_backup: PackedByteArray = FileAccess.get_file_as_bytes("%s.bak" % DOCUMENT_PATH)
		var reload_error: String = state.reload()
		TestAssertions.truthy(not reload_error.is_empty(), "%s reload is rejected" % label, failures)
		TestAssertions.equal(state.to_dictionary(), before_memory, "%s reload preserves usable in-memory state" % label, failures)
		TestAssertions.equal(FileAccess.get_file_as_bytes(DOCUMENT_PATH), before_primary, "%s reload preserves primary bytes" % label, failures)
		TestAssertions.equal(FileAccess.get_file_as_bytes("%s.bak" % DOCUMENT_PATH), before_backup, "%s reload preserves backup bytes" % label, failures)

func _assert_atomic_save_failure_and_profile_isolation(failures: Array[String]) -> void:
	_cleanup_sandbox_files()
	var profile_sentinel := ProfileStore.DEFAULT_ROOT.path_join(
		"task-8-isolation-sentinel-%d.json" % OS.get_process_id()
	)
	_write_text(profile_sentinel, "task-8-profile-bytes")
	var profile_bytes := FileAccess.get_file_as_bytes(profile_sentinel)
	var healthy: Variant = _state_script.new()
	var reset_error: String = healthy.reset()
	TestAssertions.equal(reset_error, "", "atomic failure fixture reset succeeds", failures)
	if not reset_error.is_empty():
		_remove_file(profile_sentinel)
		return
	TestAssertions.equal(FileAccess.get_file_as_bytes(profile_sentinel), profile_bytes, "sandbox reset preserves normal profile bytes", failures)
	TestAssertions.truthy(not DOCUMENT_PATH.begins_with(ProfileStore.DEFAULT_ROOT), "sandbox path is outside normal profile root", failures)

	var failing_atomic := AtomicJsonStore.new(func(_temporary: String, _target: String) -> Error: return ERR_CANT_CREATE)
	var failing_store: Variant = _store_script.new(failing_atomic)
	var failing_state: Variant = _state_script.new(failing_store)
	var reload_error: String = failing_state.reload()
	TestAssertions.equal(reload_error, "", "failing-save sandbox first reloads usable state", failures)
	if not reload_error.is_empty():
		_remove_file(profile_sentinel)
		return
	var before_document: Dictionary = failing_state.to_dictionary()
	var before_bytes: PackedByteArray = FileAccess.get_file_as_bytes(DOCUMENT_PATH)
	var item_id: String = failing_state.stash().item_id_at(0)
	var save_error: String = failing_state.move_to_first_empty_inventory(item_id)
	TestAssertions.truthy(save_error.contains("stage=promote"), "injected atomic save failure reports promotion stage", failures)
	TestAssertions.equal(failing_state.to_dictionary(), before_document, "failed atomic save preserves placements registry journal and issuance metadata", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(DOCUMENT_PATH), before_bytes, "failed atomic save preserves previous loadable bytes", failures)
	var recovered: Variant = _state_script.new()
	TestAssertions.equal(recovered.reload(), "", "previous sandbox bytes remain loadable after failed save", failures)
	TestAssertions.equal(recovered.to_dictionary(), before_document, "previous sandbox document remains exact after failed save", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(profile_sentinel), profile_bytes, "failed sandbox save preserves normal profile bytes", failures)
	_remove_file(profile_sentinel)

func _assert_corrupt_generations_reset_recovery(failures: Array[String]) -> void:
	_cleanup_sandbox_files()
	var profile_sentinel := ProfileStore.DEFAULT_ROOT.path_join(
		"task-11-reset-isolation-sentinel-%d.json" % OS.get_process_id()
	)
	_write_text(profile_sentinel, "task-11-active-profile-bytes")
	var profile_bytes := FileAccess.get_file_as_bytes(profile_sentinel)
	var seed: Variant = _state_script.new()
	TestAssertions.equal(seed.reset(), "", "corrupt-reset fixture first creates a canonical sandbox", failures)
	var canonical: Dictionary = seed.to_dictionary()
	var corrupt_primary := "task-11 corrupt sandbox primary"
	var corrupt_backup := "task-11 corrupt sandbox backup"
	_write_text(DOCUMENT_PATH, corrupt_primary)
	_write_text("%s.bak" % DOCUMENT_PATH, corrupt_backup)

	var recovered: Variant = _state_script.new()
	TestAssertions.equal(recovered.reset(), "", "reset replaces corrupt primary and corrupt backup", failures)
	TestAssertions.equal(recovered.to_dictionary(), canonical, "corrupt-generation reset restores the exact canonical 99-item document", failures)
	TestAssertions.equal(recovered.registry().size() if recovered.registry() != null else -1, 99, "corrupt-generation reset restores all 99 items", failures)
	TestAssertions.equal((recovered.to_dictionary()["transaction_journal"] as Array).size(), 0, "corrupt-generation reset clears the transaction journal", failures)
	TestAssertions.equal(int(recovered.to_dictionary()["issuance_metadata"]["next_transaction_sequence"]), 0, "corrupt-generation reset rewinds the transaction sequence", failures)
	var quarantined_primary := _sandbox_artifact_with_bytes("sandbox.json.corrupt-", corrupt_primary.to_utf8_buffer())
	var quarantined_backup := _sandbox_artifact_with_bytes("sandbox.json.bak.corrupt-", corrupt_backup.to_utf8_buffer())
	TestAssertions.truthy(not quarantined_primary.is_empty(), "reset quarantines the exact corrupt primary bytes inside the sandbox root", failures)
	TestAssertions.truthy(not quarantined_backup.is_empty(), "reset quarantines the exact corrupt backup bytes inside the sandbox root", failures)
	TestAssertions.truthy(not FileAccess.file_exists("%s.tmp" % DOCUMENT_PATH), "successful corrupt reset leaves no temporary generation", failures)
	TestAssertions.truthy(not FileAccess.file_exists("%s.bak.previous" % DOCUMENT_PATH), "successful corrupt reset leaves no displaced generation", failures)
	var first_item_id: String = recovered.stash().item_id_at(0)
	TestAssertions.equal(recovered.move_to_first_empty_inventory(first_item_id), "", "first move after corrupt reset succeeds", failures)
	var moved: Dictionary = recovered.to_dictionary()
	TestAssertions.equal(String(moved["transaction_journal"][0]["transaction_id"]), "sandbox-transaction-%016d" % 0, "first move after corrupt reset resumes journal sequence zero", failures)
	TestAssertions.equal(int(moved["issuance_metadata"]["next_transaction_sequence"]), 1, "first move after corrupt reset advances sequence once", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(profile_sentinel), profile_bytes, "corrupt-primary and corrupt-backup reset preserves active-profile sentinel bytes", failures)

	_cleanup_sandbox_files()
	_write_text(DOCUMENT_PATH, corrupt_primary)
	var missing_backup_recovery: Variant = _state_script.new()
	TestAssertions.equal(missing_backup_recovery.reset(), "", "reset replaces a corrupt primary when backup is missing", failures)
	TestAssertions.equal(missing_backup_recovery.to_dictionary(), canonical, "missing-backup reset restores the exact canonical 99-item document", failures)
	TestAssertions.truthy(not FileAccess.file_exists("%s.bak" % DOCUMENT_PATH), "missing-backup reset does not invent a prior backup generation", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(profile_sentinel), profile_bytes, "corrupt-primary and missing-backup reset preserves active-profile sentinel bytes", failures)

	_cleanup_sandbox_files()
	_write_text(DOCUMENT_PATH, corrupt_primary)
	_write_text("%s.bak" % DOCUMENT_PATH, corrupt_backup)
	var before_names := _sandbox_file_names()
	var before_primary_bytes := FileAccess.get_file_as_bytes(DOCUMENT_PATH)
	var before_backup_bytes := FileAccess.get_file_as_bytes("%s.bak" % DOCUMENT_PATH)
	var failing_atomic := AtomicJsonStore.new(func(_temporary: String, _target: String) -> Error: return ERR_CANT_CREATE)
	var failing_state: Variant = _state_script.new(_store_script.new(failing_atomic))
	var reset_error: String = failing_state.reset()
	TestAssertions.truthy(reset_error.contains("stage=promote"), "injected corrupt-reset promotion failure reports the promotion stage", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(DOCUMENT_PATH), before_primary_bytes, "failed corrupt reset restores exact primary bytes", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes("%s.bak" % DOCUMENT_PATH), before_backup_bytes, "failed corrupt reset restores exact backup bytes", failures)
	TestAssertions.equal(_sandbox_file_names(), before_names, "failed corrupt reset restores the exact prior sandbox generation set", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(profile_sentinel), profile_bytes, "failed corrupt reset preserves active-profile sentinel bytes", failures)
	_remove_file(profile_sentinel)

func _minimal_unknown_document() -> Dictionary:
	return {
		"schema_version": 1,
		"owner_id": OWNER_ID,
		"ownership_state": {},
		"issuance_metadata": {},
		"transaction_journal": [],
		"unknown": true,
	}

func _change_item_level(ownership_document: Dictionary, item_id: String, item_level: int) -> void:
	for item: Dictionary in ownership_document["registry"]["items"]:
		if String(item["instance_id"]) == item_id:
			item["item_level"] = item_level
			return

func _change_item_identity(ownership_document: Dictionary, old_id: String, new_id: String) -> void:
	for item: Dictionary in ownership_document["registry"]["items"]:
		if String(item["instance_id"]) == old_id:
			item["instance_id"] = new_id
	for container: Dictionary in ownership_document["containers"]:
		for slot: String in container["slots"]:
			if String(container["slots"][slot]) == old_id:
				container["slots"][slot] = new_id

func _container_document(ownership_document: Dictionary, container_id: StringName) -> Dictionary:
	for container: Dictionary in ownership_document["containers"]:
		if String(container["container_id"]) == String(container_id):
			return container
	return {}

func _cleanup_sandbox_files() -> void:
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SANDBOX_ROOT)):
		for name: String in DirAccess.get_files_at(SANDBOX_ROOT):
			if name.begins_with("sandbox.json"):
				_remove_file(SANDBOX_ROOT.path_join(name))
	var absolute_root := ProjectSettings.globalize_path(SANDBOX_ROOT)
	if DirAccess.dir_exists_absolute(absolute_root):
		DirAccess.remove_absolute(absolute_root)

func _sandbox_file_names() -> PackedStringArray:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SANDBOX_ROOT)):
		return PackedStringArray()
	var names := DirAccess.get_files_at(SANDBOX_ROOT)
	names.sort()
	return names

func _sandbox_artifact_with_bytes(prefix: String, expected: PackedByteArray) -> String:
	for name: String in _sandbox_file_names():
		if name.begins_with(prefix):
			var path := SANDBOX_ROOT.path_join(name)
			if FileAccess.get_file_as_bytes(path) == expected:
				return path
	return ""

func _write_text(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(text)
	file.close()

func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
