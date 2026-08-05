extends RefCounted

const STATE_PATH := "res://scripts/dev/developer_item_sandbox_state.gd"
const STORE_PATH := "res://scripts/dev/developer_item_sandbox_store.gd"
const FIXTURE_ISSUER_PATH := "res://scripts/dev/developer_item_fixture_issuer.gd"
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
	var required_paths: Array[String] = [FIXTURE_ISSUER_PATH, STATE_PATH, STORE_PATH]
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
	_assert_explicit_affixes_survive_reload(failures)
	_assert_movement_replay_collision_and_reset(failures)
	_assert_strict_reload_is_failure_atomic(failures)
	_assert_atomic_save_failure_and_profile_isolation(failures)
	_cleanup_sandbox_files()
	return failures

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
	for rarity_id: StringName in foundation.functional_rarity_ids():
		TestAssertions.truthy(seen_rarities.has(String(rarity_id)), "functional rarity %s appears" % rarity_id, failures)
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
			TestAssertions.truthy(affix.tier >= definition.minimum_tier and affix.tier <= definition.maximum_tier, "fixture affix tier is bounded", failures)
			TestAssertions.equal(affix.affix_kind, definition.affix_kind, "fixture affix kind is explicit", failures)
			TestAssertions.equal(affix.rolls.size(), 1, "fixture affix has one explicit roll", failures)
			if affix.rolls.is_empty():
				continue
			var roll: ItemModifierRoll = affix.rolls[0]
			var bounds: Vector2 = definition.roll_bounds(affix.tier)
			TestAssertions.equal(roll.operation, definition.operation, "fixture roll operation is explicit", failures)
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
		"sandbox-move-%016d" % 2,
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
		"sandbox-move-%016d" % 2,
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

func _minimal_unknown_document() -> Dictionary:
	return {
		"schema_version": 1,
		"owner_id": OWNER_ID,
		"ownership_state": {},
		"issuance_metadata": {},
		"transaction_journal": [],
		"unknown": true,
	}

func _cleanup_sandbox_files() -> void:
	for suffix: String in ["", ".bak", ".tmp", ".bak.previous"]:
		_remove_file("%s%s" % [DOCUMENT_PATH, suffix])
	var absolute_root := ProjectSettings.globalize_path(SANDBOX_ROOT)
	if DirAccess.dir_exists_absolute(absolute_root):
		DirAccess.remove_absolute(absolute_root)

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
