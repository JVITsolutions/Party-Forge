extends SceneTree

const PROFILE_ROOT := "user://task10_item_storage_profiles"
const SANDBOX_ROOT := "user://developer_item_sandbox"
const SANDBOX_PATH := "user://developer_item_sandbox/sandbox.json"
const PROFILE_IDS: Array[String] = ["profile-task10-alpha", "profile-task10-beta"]

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_cleanup()
	var id_index := [0]
	var manager := ProfileManager.new(
		ProfileStore.new(),
		ProfileIndexStore.new(),
		func() -> String:
			var result := PROFILE_IDS[int(id_index[0])]
			id_index[0] = int(id_index[0]) + 1
			return result
	)
	_assert(manager.bootstrap(PROFILE_ROOT).is_empty(), "profile manager bootstraps its task-specific root")
	for index: int in PROFILE_IDS.size():
		var created := manager.create_profile("Task 10 Profile %d" % (index + 1), 1000 + index)
		_assert(created.ok() and created.profile.profile_id == PROFILE_IDS[index], "normal profile %d is created with its fixed identity" % (index + 1))
		var mutation := ProfileMutationService.new(ProfileStore.new()).grant_gold(
			PROFILE_IDS[index],
			"task10-profile-mutation-%d" % index,
			10 + index,
			PROFILE_ROOT
		)
		_assert(mutation.ok(), "normal profile %d receives a durable journal mutation" % (index + 1))
		_assert(manager.refresh_profile(PROFILE_IDS[index]).is_empty(), "normal profile %d refreshes after its mutation" % (index + 1))
	_assert(manager.select_profile(PROFILE_IDS[0]).is_empty(), "active profile selection is fixed before sandbox work")

	var store := ProfileStore.new()
	var semantic_before: Dictionary = {}
	var journals_before: Dictionary = {}
	var bytes_before: Dictionary = {}
	var hashes_before: Dictionary = {}
	for profile_id: String in PROFILE_IDS:
		var loaded := store.load_profile(profile_id, PROFILE_ROOT)
		_assert(loaded.ok(), "normal profile %s loads before sandbox work" % profile_id)
		if not loaded.ok():
			continue
		semantic_before[profile_id] = loaded.profile.to_dictionary()
		journals_before[profile_id] = loaded.profile.applied_transactions.duplicate(true)
		var path := store.profile_path(profile_id, PROFILE_ROOT)
		bytes_before[profile_id] = FileAccess.get_file_as_bytes(path)
		hashes_before[profile_id] = _sha256(bytes_before[profile_id] as PackedByteArray)
	var index_path := PROFILE_ROOT.path_join(ProfileIndexStore.FILE_NAME)
	var index_bytes_before := FileAccess.get_file_as_bytes(index_path)
	var index_hash_before := _sha256(index_bytes_before)
	var active_before := manager.active_profile()
	var active_id_before := active_before.profile_id if active_before != null else ""
	var globalized_profile_root_before := ProjectSettings.globalize_path(PROFILE_ROOT)
	var globalized_sandbox_root_before := ProjectSettings.globalize_path(SANDBOX_ROOT)
	_assert(not globalized_sandbox_root_before.begins_with(globalized_profile_root_before), "sandbox root is outside the normal profile root")

	var sandbox := DeveloperItemSandboxState.new()
	_assert(sandbox.reset().is_empty(), "isolated sandbox reset succeeds")
	_assert(sandbox.registry() != null and sandbox.registry().size() == 99, "isolated sandbox owns all 99 items")
	_assert(sandbox.save().is_empty(), "isolated sandbox save succeeds")
	_assert(sandbox.reload().is_empty(), "isolated sandbox reload succeeds")
	var first_item_id := sandbox.stash().item_id_at(0)
	var second_item_id := sandbox.stash().item_id_at(1)
	_assert(sandbox.transfer_slots(DeveloperItemSandboxState.STASH_ID, 0, DeveloperItemSandboxState.INVENTORY_ID, 2).is_empty(), "sandbox selected-slot move succeeds")
	_assert(sandbox.transfer_slots(DeveloperItemSandboxState.INVENTORY_ID, 2, DeveloperItemSandboxState.STASH_ID, 1).is_empty(), "sandbox occupied-slot swap succeeds")
	_assert(sandbox.move_to_first_empty_stash(second_item_id).is_empty(), "sandbox first-empty stash operation succeeds")
	var next_inventory_item := sandbox.stash().item_id_at(2)
	_assert(sandbox.move_to_first_empty_inventory(next_inventory_item).is_empty(), "sandbox first-empty inventory operation succeeds")
	_assert(sandbox.scan_integrity().is_empty(), "sandbox integrity scan succeeds")
	_assert(sandbox.reload().is_empty(), "mutated sandbox reload succeeds")
	_assert(sandbox.reset().is_empty(), "sandbox reset restores the deterministic fixture")
	_assert(sandbox.registry() != null and sandbox.registry().size() == 99, "sandbox reset retains exactly 99 items")
	var sandbox_item_ids := sandbox.registry().ids() if sandbox.registry() != null else [] as Array[String]

	var reloaded_manager := ProfileManager.new()
	_assert(reloaded_manager.bootstrap(PROFILE_ROOT).is_empty(), "normal profile root reloads after sandbox work")
	var reloaded_active := reloaded_manager.active_profile()
	_assert(reloaded_active != null and reloaded_active.profile_id == active_id_before, "active-profile selection remains exact")
	_assert(ProjectSettings.globalize_path(PROFILE_ROOT) == globalized_profile_root_before, "normal profile root identity remains exact")
	_assert(ProjectSettings.globalize_path(SANDBOX_ROOT) == globalized_sandbox_root_before, "sandbox root identity remains exact")
	_assert(FileAccess.file_exists(SANDBOX_PATH), "sandbox work remains persisted only in its isolated root")
	for profile_id: String in PROFILE_IDS:
		var loaded_after := store.load_profile(profile_id, PROFILE_ROOT)
		_assert(loaded_after.ok(), "normal profile %s loads after sandbox work" % profile_id)
		if not loaded_after.ok():
			continue
		var path := store.profile_path(profile_id, PROFILE_ROOT)
		var after_bytes := FileAccess.get_file_as_bytes(path)
		_assert(loaded_after.profile.to_dictionary() == semantic_before.get(profile_id, {}), "normal profile %s semantic value remains exact" % profile_id)
		_assert(loaded_after.profile.applied_transactions == journals_before.get(profile_id, {}), "normal profile %s mutation journal remains exact" % profile_id)
		_assert(after_bytes == bytes_before.get(profile_id, PackedByteArray()), "normal profile %s primary bytes remain exact" % profile_id)
		_assert(_sha256(after_bytes) == String(hashes_before.get(profile_id, "")), "normal profile %s SHA-256 remains exact" % profile_id)
		var profile_text := JSON.stringify(loaded_after.profile.to_dictionary())
		_assert(not profile_text.contains(DeveloperItemSandboxState.OWNER_ID), "normal profile %s contains no sandbox owner reference" % profile_id)
		for sandbox_item_id: String in sandbox_item_ids:
			if profile_text.contains(sandbox_item_id):
				_failures.append("normal profile %s contains sandbox item reference %s" % [profile_id, sandbox_item_id])
				break
	var index_bytes_after := FileAccess.get_file_as_bytes(index_path)
	_assert(index_bytes_after == index_bytes_before, "active-profile index bytes remain exact")
	_assert(_sha256(index_bytes_after) == index_hash_before, "active-profile index SHA-256 remains exact")

	if _failures.is_empty():
		print("ITEM_STORAGE_PROFILE_ISOLATION_SUMMARY: PASS profiles=2 items=99")
		_cleanup()
		quit(0)
		return
	for failure: String in _failures:
		push_error("ITEM_STORAGE_PROFILE_ISOLATION_FAILURE: %s" % failure)
	print("ITEM_STORAGE_PROFILE_ISOLATION_SUMMARY: FAIL (%d failures)" % _failures.size())
	_cleanup()
	quit(1)


func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _cleanup() -> void:
	ProfileTestSupport.remove_tree(PROFILE_ROOT)
	ProfileTestSupport.remove_tree(SANDBOX_ROOT)
