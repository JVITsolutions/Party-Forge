extends SceneTree

const PROFILE_ROOT := "user://task12_weighted_loot_profiles"
const PROFILE_ID := "task12-weighted-loot-profile"
const LEGACY_PROFILE_ID := "task12-legacy-profile"
const RUN_ID := &"task12-weighted-loot-run"
const RUN_PLAYER_ID := &"task12_weighted_player"
const RUN_SEED := 121212
const STASH_ID := &"stash-tab-000"
const LEADER_ID := 1
const WEAPON_BASE_ID := &"forge_vanguard_sword"
const SUPPORT_BASE_ID := &"forge_vanguard_helmet"
const LEGACY_SCHEMA_ONE_ITEM := "{\"affixes\":[{\"affix_kind\":\"prefix\",\"definition_id\":\"stout\",\"rolls\":[{\"operation\":0,\"required_tags\":[],\"stat_id\":\"constitution\",\"value\":3.0}],\"tier\":1},{\"affix_kind\":\"suffix\",\"definition_id\":\"of_reach\",\"rolls\":[{\"operation\":1,\"required_tags\":[],\"stat_id\":\"attack_range\",\"value\":0.2}],\"tier\":2}],\"base_definition_id\":\"forge_vanguard_sword\",\"instance_id\":\"task12-legacy-sword\",\"item_level\":28,\"origin\":{\"issuer_namespace\":\"profile:task12-legacy-profile\",\"seed\":4402,\"sequence\":0,\"source\":\"historical_profile\"},\"rarity_id\":\"legendary\",\"schema_version\":1}"

var _failures: Array[String] = []
var _parties: Array[PartyManager] = []
var _nodes: Array[Node] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	ProfileTestSupport.remove_tree(PROFILE_ROOT)
	_verify_schema_migration_and_fallback()
	_verify_generate_store_equip_attack_extract()
	_verify_twenty_four_member_isolation()
	_finish()


func _verify_schema_migration_and_fallback() -> void:
	var equipment := GameCatalog.EQUIPMENT_CATALOG
	var foundation := GameCatalog.ITEM_FOUNDATION_CATALOG
	var literal_document: Variant = JSON.parse_string(LEGACY_SCHEMA_ONE_ITEM)
	var decoded := ItemInstanceCodec.decode(literal_document, equipment, foundation)
	_assert(decoded.ok(), "TASK1 codec: literal schema-1 fixture decodes through ItemInstanceCodec")
	if not decoded.ok():
		return
	var legacy_item := decoded.item
	_assert(legacy_item.schema_version == ItemInstance.SCHEMA_VERSION, "TASK1 codec: schema-1 fixture migrates to schema 2")
	_assert(legacy_item.base_damage_components.is_empty(), "TASK1 codec: migration invents no weapon base damage")
	var encoded := JSON.parse_string(ItemInstanceCodec.encode(legacy_item)) as Dictionary
	_assert(int(encoded.get("schema_version", 0)) == 2 and Array(encoded.get("base_damage_components", [])).is_empty(), "TASK1 codec: migrated fixture re-encodes with explicit schema-2 fallback state")

	var store := ProfileStore.new()
	var profile := ProfileState.new_profile(LEGACY_PROFILE_ID, "Task 12 Legacy", 1000)
	profile.inventory_columns = 2
	profile.stash_tabs = [ItemSlotContainer.create(STASH_ID, ItemSlotContainer.PROFILE_STASH_TAB, LEGACY_PROFILE_ID, 100).to_dictionary()]
	_assert(store.save_profile(profile, PROFILE_ROOT).is_empty(), "TASK1 profile: legacy fixture profile saves")
	var stored := ProfileItemStorageService.new(ProfileMutationService.new(store)).apply(
		LEGACY_PROFILE_ID,
		ItemTransactionRequest.create("legacy-store", LEGACY_PROFILE_ID, STASH_ID, 0, legacy_item),
		PROFILE_ROOT,
	)
	_assert(stored.ok(), "TASK1 profile: migrated fixture enters profile through durable storage service detail=%s" % stored.error)
	if not stored.ok():
		return
	var assigned := _assign_profile_item(store, LEGACY_PROFILE_ID, legacy_item.instance_id, STASH_ID, 0, &"main_hand", "legacy-equip")
	_assert(assigned.ok(), "TASK7 activation: migrated fixture equips through profile loadout assignment")
	if not assigned.ok():
		return
	var checkout := RunLoadoutCheckoutService.new(ProfileMutationService.new(store)).checkout(
		LEGACY_PROFILE_ID,
		RunLoadoutCheckoutRequest.create("legacy-checkout", LEGACY_PROFILE_ID, &"task12-legacy-run", 1213, &"task12_legacy_player", 1, &"fighter", true),
		PROFILE_ROOT,
	)
	_assert(checkout.ok(), "TASK8 ownership: migrated fixture checks out through the run service")
	if not checkout.ok():
		return
	var loaded := store.load_profile(LEGACY_PROFILE_ID, PROFILE_ROOT)
	var bootstrap := RunLoadoutCheckoutService.new().bootstrap_from(loaded.profile) if loaded.ok() else null
	_assert(bootstrap != null and ResumableRunItemCodec.decode(ResumableRunItemCodec.encode(bootstrap), equipment, foundation) != null, "TASK1 codec: legacy bootstrap survives canonical encode/decode")
	var party := _fighter_party(1)
	var context := PlayerRunContext.new()
	var errors := context.configure(&"task12_legacy_player", 0, loaded.profile if loaded.ok() else null, 1213, party, 100, bootstrap)
	_assert(errors.is_empty(), "TASK8 ownership: migrated fixture resumes in a configured run context detail=%s" % " | ".join(errors))
	if not errors.is_empty():
		return
	var activation := context.equipment_activation(1)
	_assert(activation.ok() and activation.is_active(legacy_item.instance_id), "TASK7 activation: migrated weapon remains active")
	_assert(activation.weapon_snapshot() == null, "TASK1 codec: schema-1 weapon exposes no invented active-weapon snapshot")
	var fighter := party.member_by_id(1).class_definition
	var fallback := ActionDamageComponentProjection.resolve(fighter.primary_attack, activation.weapon_snapshot())
	_assert(String(fallback.get("error", "")).is_empty() and bool(fallback.get("used_fallback", false)), "TASK9 combat: migrated schema-1 weapon selects authored fallback components")
	var stats := party.stats_for_action(1, DamageResolver.action_tags_for(fighter.primary_attack, null))
	var source := CombatantAdapter.new(null, &"party:1", 1, null, stats, true, Callable(), null)
	var packet := DamageResolver.prepare(fighter.primary_attack, source, CombatRng.new(1213, [0.99]), GameCatalog.DAMAGE_TYPES)
	_assert(packet.valid and packet.components.size() == fighter.primary_attack.damage_components.size(), "TASK9 combat: authored fallback prepares a valid attack packet")


func _verify_generate_store_equip_attack_extract() -> void:
	var store := ProfileStore.new()
	var profile := ProfileState.new_profile(PROFILE_ID, "Task 12 Weighted Loot", 1000)
	profile.inventory_columns = 5
	profile.extraction_capacity = 1
	profile.permanent_feature_unlocks = [RunExtractionPolicy.AUTOMATIC_LEADER_UNLOCK]
	profile.stash_tabs = [ItemSlotContainer.create(STASH_ID, ItemSlotContainer.PROFILE_STASH_TAB, PROFILE_ID, 100).to_dictionary()]
	_assert(store.save_profile(profile, PROFILE_ROOT).is_empty(), "TASK1 profile: production-flow profile saves")
	var path := store.profile_path(PROFILE_ID, PROFILE_ROOT)
	var baseline_bytes := FileAccess.get_file_as_bytes(path)

	var failed_request := _generation_request(9001, 0, 28, WEAPON_BASE_ID)
	failed_request.required_base_tags = [&"weapon"]
	failed_request.excluded_base_tags = [&"weapon"]
	var failed_generation := ItemGenerationService.generate(
		failed_request, "profile:%s" % PROFILE_ID, 0,
		GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG,
	)
	_assert(not failed_generation.ok() and failed_generation.failure.stage == &"request", "TASK3 generation: invalid deterministic request fails at the owning request contract")
	_assert(FileAccess.get_file_as_bytes(path) == baseline_bytes, "TASK3 generation: failed generation mutates no profile bytes")
	_assert(store.load_profile(PROFILE_ID, PROFILE_ROOT).profile.next_item_sequence == 0, "TASK3 generation: failed generation consumes no profile sequence")

	var weapon_result := ItemGenerationService.generate(
		_generation_request(9001, 0, 28, WEAPON_BASE_ID), "profile:%s" % PROFILE_ID, 0,
		GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG,
	)
	_assert(weapon_result.ok(), "TASK3-6 generation: fixed schema-2 profile weapon generates and issues")
	if not weapon_result.ok():
		return
	var weapon := weapon_result.item
	_assert(weapon.schema_version == 2 and not weapon.base_damage_components.is_empty(), "TASK3 weapon damage: generated profile weapon owns schema-2 damage ranges")
	var support_issue := _issue_support_item(1)
	_assert(support_issue.ok(), "TASK1 issuance: fixed attribute-support item issues through ItemInstanceIssuer detail=%s" % support_issue.error)
	if not support_issue.ok():
		return
	var support := support_issue.item

	var invalid_storage := ProfileItemStorageService.new(ProfileMutationService.new(store)).apply(
		PROFILE_ID,
		ItemTransactionRequest.create("profile-store-invalid", PROFILE_ID, STASH_ID, 100, weapon),
		PROFILE_ROOT,
	)
	_assert(not invalid_storage.ok(), "TASK8 ownership: invalid persistent destination is rejected")
	_assert(FileAccess.get_file_as_bytes(path) == baseline_bytes, "TASK8 ownership: rejected persistent placement preserves exact profile bytes")
	_assert(store.load_profile(PROFILE_ID, PROFILE_ROOT).profile.next_item_sequence == 0, "TASK8 ownership: rejected persistent placement consumes no sequence")
	var failing_store := ProfileStore.new(AtomicJsonStore.new(func(_temporary: String, _target: String) -> Error: return ERR_CANT_CREATE))
	var persistence_failure := ProfileItemStorageService.new(ProfileMutationService.new(failing_store)).apply(
		PROFILE_ID,
		ItemTransactionRequest.create("profile-store-save-failure", PROFILE_ID, STASH_ID, 0, weapon),
		PROFILE_ROOT,
	)
	_assert(not persistence_failure.ok() and persistence_failure.error.contains("JSON_STORE_SAVE_ERROR"), "TASK1 persistence: injected profile save failure is stable")
	_assert(FileAccess.get_file_as_bytes(path) == baseline_bytes, "TASK1 persistence: failed save preserves exact profile bytes")
	_assert(store.load_profile(PROFILE_ID, PROFILE_ROOT).profile.next_item_sequence == 0, "TASK1 persistence: failed save consumes no sequence")

	var storage := ProfileItemStorageService.new(ProfileMutationService.new(store))
	var stored_weapon := storage.apply(PROFILE_ID, ItemTransactionRequest.create("profile-store-weapon", PROFILE_ID, STASH_ID, 0, weapon), PROFILE_ROOT)
	_assert(stored_weapon.ok(), "TASK8 ownership: generated weapon enters the profile stash")
	var stored_support := storage.apply(PROFILE_ID, ItemTransactionRequest.create("profile-store-support", PROFILE_ID, STASH_ID, 1, support), PROFILE_ROOT)
	_assert(stored_support.ok(), "TASK8 ownership: issued support item enters the profile stash")
	var after_store := store.load_profile(PROFILE_ID, PROFILE_ROOT)
	_assert(after_store.ok() and after_store.profile.next_item_sequence == 2, "TASK8 ownership: two successful creations consume exactly two sequences")
	if not after_store.ok():
		return

	var equipment_bytes_before := FileAccess.get_file_as_bytes(path)
	var stale_request := ProfileLoadoutAssignmentRequest.create(
		"profile-equip-stale", PROFILE_ID, &"fighter", weapon.instance_id,
		STASH_ID, 99, &"leader-loadout", EquipmentSlotIndex.index_for(&"main_hand"), "",
		ProfileLoadoutAssignmentRequest.fingerprint_for(after_store.profile),
	)
	var stale_assignment := ProfileLoadoutAssignmentService.new(ProfileMutationService.new(store)).apply(PROFILE_ID, stale_request, PROFILE_ROOT)
	_assert(not stale_assignment.ok() and stale_assignment.error.contains("stale source"), "TASK7 equipment: stale profile source is rejected diagnostically")
	_assert(FileAccess.get_file_as_bytes(path) == equipment_bytes_before, "TASK7 equipment: failed profile assignment preserves exact bytes")
	_assert(store.load_profile(PROFILE_ID, PROFILE_ROOT).profile.next_item_sequence == 2, "TASK7 equipment: failed profile assignment consumes no generation sequence")

	var equipped_support := _assign_profile_item(store, PROFILE_ID, support.instance_id, STASH_ID, 1, &"helmet", "profile-equip-support")
	_assert(equipped_support.ok(), "TASK7 equipment: support item assigns through the profile service")
	var equipped_weapon := _assign_profile_item(store, PROFILE_ID, weapon.instance_id, STASH_ID, 0, &"main_hand", "profile-equip-weapon")
	_assert(equipped_weapon.ok(), "TASK7 equipment: generated weapon assigns through the profile service")
	if not equipped_support.ok() or not equipped_weapon.ok():
		return

	var checkout := RunLoadoutCheckoutService.new(ProfileMutationService.new(store)).checkout(
		PROFILE_ID,
		RunLoadoutCheckoutRequest.create("task12-checkout", PROFILE_ID, RUN_ID, RUN_SEED, RUN_PLAYER_ID, LEADER_ID, &"fighter", true),
		PROFILE_ROOT,
	)
	_assert(checkout.ok(), "TASK8 ownership: leader loadout checks out through the production run service")
	var checked_out := store.load_profile(PROFILE_ID, PROFILE_ROOT)
	var bootstrap := RunLoadoutCheckoutService.new().bootstrap_from(checked_out.profile) if checked_out.ok() else null
	_assert(checked_out.ok() and bootstrap != null, "TASK1 persistence: checked-out schema-2 ownership reloads through the run codec")
	_assert(bootstrap != null and ResumableRunItemCodec.decode(ResumableRunItemCodec.encode(bootstrap), GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG) != null, "TASK1 codec: schema-2 bootstrap survives canonical encode/decode")
	if not checked_out.ok() or bootstrap == null:
		return
	var party := PartyManager.new()
	party.configure_capacity(PartyCapacityPolicy.new(2))
	party.initialize(GameCatalog.load_defaults().class_by_id(&"fighter"), GameCatalog.load_defaults().traits)
	_parties.append(party)
	var context := PlayerRunContext.new()
	var configure_errors := context.configure(RUN_PLAYER_ID, 0, checked_out.profile, RUN_SEED, party, 100, bootstrap)
	_assert(configure_errors.is_empty(), "TASK8 ownership: checked-out profile configures a two-member run detail=%s" % " | ".join(configure_errors))
	if not configure_errors.is_empty():
		return
	_assert(party.recruit(GameCatalog.load_defaults().class_by_id(&"fighter")), "TASK8 ownership: normal member-added flow creates the follower")
	_assert(context.equipment_for(2) != null, "TASK8 ownership: member-added flow creates follower equipment ownership")
	_assert(context.equipment_for(1).item_id_at(EquipmentSlotIndex.index_for(&"main_hand")) == weapon.instance_id, "TASK8 ownership: leader retains the generated main hand")

	var requirement_catalog := _catalog_requiring_support(party.member_by_id(1).class_definition)
	var changed_members: Array[int] = []
	party.stats_changed.connect(func(member_id: int) -> void: changed_members.append(member_id))
	var disabled := context.assign_equipment(1, support.instance_id, &"", requirement_catalog, GameCatalog.ITEM_FOUNDATION_CATALOG)
	_assert(disabled.ok(), "TASK7 activation: removing support performs a normal equipment transition")
	var disabled_activation := context.equipment_activation(1)
	_assert(not disabled_activation.is_active(weapon.instance_id) and not disabled_activation.disabled_reasons(weapon.instance_id).is_empty(), "TASK7 activation: unmet attribute disables the equipped weapon")
	var reenabled := context.assign_equipment(1, support.instance_id, &"helmet", requirement_catalog, GameCatalog.ITEM_FOUNDATION_CATALOG)
	_assert(reenabled.ok() and context.equipment_activation(1).is_active(weapon.instance_id), "TASK7 activation: restoring support re-enables the equipped weapon")
	_assert(changed_members == [1, 1], "TASK7 activation: disable and re-enable signal only the intended member")

	var run_namespace := "run:%s:%s:%s" % [PROFILE_ID, RUN_SEED, RUN_PLAYER_ID]
	var follower_result := ItemGenerationService.generate(
		_generation_request(9011, 0, 34, WEAPON_BASE_ID), run_namespace, 0,
		GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG,
	)
	_assert(follower_result.ok(), "TASK3-6 generation: fixed follower schema-2 weapon generates")
	if not follower_result.ok():
		return
	var follower_weapon := follower_result.item
	var created_follower := context.apply_item_transaction(
		ItemTransactionRequest.create("run-create-follower", String(RUN_PLAYER_ID), &"run-inventory", 0, follower_weapon),
		GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG,
	)
	_assert(created_follower.ok(), "TASK8 ownership: follower weapon issues into run inventory through the context transaction API")
	var follower_equipped := context.assign_equipment(2, follower_weapon.instance_id, &"main_hand", GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	_assert(follower_equipped.ok(), "TASK7 equipment: follower receives the distinct generated main hand")

	var leader_presentation := ItemPresentationProjector.project(weapon, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG, GameCatalog.STAT_CATALOG, party.member_by_id(1).class_definition)
	var follower_presentation := ItemPresentationProjector.project(follower_weapon, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG, GameCatalog.STAT_CATALOG, party.member_by_id(2).class_definition)
	_assert(not leader_presentation.is_empty() and not follower_presentation.is_empty(), "TASK10 presentation: generated weapon records project through the production presenter")
	_assert(not Array(leader_presentation.get("base_damage_lines", [])).is_empty() and not Array(follower_presentation.get("base_damage_lines", [])).is_empty(), "TASK10 presentation: both schema-2 weapons expose damage range lines")
	var comparisons := ItemComparisonResolver.resolve(
		follower_presentation,
		[{"slot_id": "main_hand", "instance_id": weapon.instance_id}],
		{weapon.instance_id: leader_presentation},
	)
	_assert(comparisons.size() == 1 and not Array(comparisons[0].get("delta_lines", [])).is_empty(), "TASK10 presentation: follower weapon compares against the equipped leader weapon")

	var health_by_member := _bind_health(context, party, 2)
	var leader_health := health_by_member[1] as HealthComponent
	var follower_health := health_by_member[2] as HealthComponent
	var follower_health_before := follower_health.current_health
	var leader_activation := context.equipment_activation(1)
	var leader_attack := party.member_by_id(1).class_definition.primary_attack
	var leader_stats := party.stats_for_action(1, DamageResolver.action_tags_for(leader_attack, leader_activation.weapon_snapshot()))
	var source := CombatantAdapter.new(null, &"party:1", 1, leader_health, leader_stats, true, Callable(), leader_activation.weapon_snapshot())
	var target := CombatantAdapter.new(null, &"party:2", 2, follower_health, party.stats_for(2))
	var attack_rng := CombatRng.new(12001, [0.99, 0.25])
	var packet := DamageResolver.prepare(leader_attack, source, attack_rng, GameCatalog.DAMAGE_TYPES)
	var damage := DamageResolver.resolve(packet, target, CombatRng.new(12002, [0.99, 0.99]), GameCatalog.DAMAGE_TYPES)
	_assert(packet.valid and damage.valid and damage.actual_health_removed > 0.0, "TASK9 combat: equipped schema-2 weapon attacks through runtime damage resolution")
	_assert(_packet_uses_weapon_ranges(packet, leader_activation.weapon_snapshot()), "TASK9 combat: runtime packet samples the equipped weapon ranges")
	_assert(follower_health.current_health < follower_health_before and is_equal_approx(leader_health.current_health, leader_health.max_health), "TASK9 combat: attack changes only the intended target health")

	var save_profile := store.load_profile(PROFILE_ID, PROFILE_ROOT)
	_assert(save_profile.ok(), "TASK1 persistence: active run profile reloads before checkpoint")
	if not save_profile.ok():
		return
	var checkpoint := RunItemBootstrap.create(RUN_ID, RUN_SEED, RUN_PLAYER_ID, LEADER_ID, context.item_state())
	save_profile.profile.resumable_run = ResumableRunItemCodec.encode(checkpoint)
	_assert(store.save_profile(save_profile.profile, PROFILE_ROOT).is_empty(), "TASK1 persistence: live schema-2 ownership saves")
	var reloaded := store.load_profile(PROFILE_ID, PROFILE_ROOT)
	var resumed_bootstrap := RunLoadoutCheckoutService.new().bootstrap_from(reloaded.profile) if reloaded.ok() else null
	_assert(reloaded.ok() and resumed_bootstrap != null, "TASK1 persistence: saved live ownership reloads and decodes")
	if not reloaded.ok() or resumed_bootstrap == null:
		return
	var resumed_party := _fighter_party(2)
	var resumed := PlayerRunContext.new()
	var resume_errors := resumed.configure(RUN_PLAYER_ID, 0, reloaded.profile, RUN_SEED, resumed_party, 100, resumed_bootstrap)
	_assert(resume_errors.is_empty(), "TASK8 ownership: saved run resumes through PlayerRunContext")
	if not resume_errors.is_empty():
		return
	_assert(resumed.equipment_activation(1).is_active(weapon.instance_id) and resumed.equipment_activation(2).is_active(follower_weapon.instance_id), "TASK7 activation: resumed leader and follower weapons are active")

	_verify_failure_atomicity(store, path, resumed, resumed_party, follower_weapon.instance_id)

	var follower_slot := EquipmentSlotIndex.index_for(&"main_hand")
	var selections: Array[ExtractionSelection] = [ExtractionSelection.create(follower_weapon.instance_id, &"run-equipment-002", follower_slot)]
	var projection := RunExtractionPolicy.project(resumed, reloaded.profile, selections)
	_assert(projection.valid, "TASK8 extraction: leader/follower projection is valid")
	_assert(weapon.instance_id in projection.automatic_item_ids and support.instance_id in projection.automatic_item_ids, "TASK8 extraction: full leader loadout is automatic under the authored unlock")
	_assert(projection.selected_item_ids == [follower_weapon.instance_id], "TASK8 extraction: follower main hand consumes the one personal selection")
	_assert(follower_weapon.instance_id not in projection.automatic_item_ids, "TASK8 extraction: follower equipment remains personal rather than automatic")

	var valid_request := RunResolutionRequest.create("task12-resolution", PROFILE_ID, RUN_ID, RUN_SEED, RUN_PLAYER_ID, LEADER_ID, selections)
	var pre_resolution_bytes := FileAccess.get_file_as_bytes(path)
	var pre_resolution_state := JSON.stringify(resumed.item_state().to_dictionary())
	var failing_resolution_store := ProfileStore.new(AtomicJsonStore.new(func(_temporary: String, _target: String) -> Error: return ERR_CANT_CREATE))
	var persistence_resolution := RunResolutionService.new(ProfileMutationService.new(failing_resolution_store)).resolve(PROFILE_ID, resumed, valid_request, PROFILE_ROOT)
	_assert(not persistence_resolution.ok() and persistence_resolution.error.contains("JSON_STORE_SAVE_ERROR"), "TASK1 persistence: extraction save failure is stable")
	_assert(FileAccess.get_file_as_bytes(path) == pre_resolution_bytes and JSON.stringify(resumed.item_state().to_dictionary()) == pre_resolution_state, "TASK1 persistence: failed extraction save mutates no profile or live ownership")
	_assert(resumed.item_resolution_error("task12-resolution-retry").is_empty(), "TASK8 extraction: failed persistence leaves resolution retryable")

	var resolved := RunResolutionService.new(ProfileMutationService.new(store)).resolve(PROFILE_ID, resumed, valid_request, PROFILE_ROOT)
	_assert(resolved.ok(), "TASK8 extraction: automatic leader and selected follower items resolve")
	var final_load := store.load_profile(PROFILE_ID, PROFILE_ROOT)
	_assert(final_load.ok() and final_load.profile.resumable_run.is_empty(), "TASK1 persistence: successful resolution reloads with no resumable run")
	if final_load.ok():
		var final_registry := _profile_registry(final_load.profile)
		_assert(final_registry != null and final_registry.has(weapon.instance_id) and final_registry.has(support.instance_id) and final_registry.has(follower_weapon.instance_id), "TASK8 extraction: resolved profile owns automatic leader and selected follower records")
		_assert(final_load.profile.leader_loadout["slots"].get(str(EquipmentSlotIndex.index_for(&"main_hand")), "") == weapon.instance_id, "TASK8 extraction: leader main hand returns to its loadout slot")
		_assert(_profile_stash_contains(final_load.profile, follower_weapon.instance_id), "TASK8 extraction: selected follower main hand returns to personal stash")


func _verify_failure_atomicity(store: ProfileStore, path: String, context: PlayerRunContext, party: PartyManager, follower_item_id: String) -> void:
	var changed_members: Array[int] = []
	party.stats_changed.connect(func(member_id: int) -> void: changed_members.append(member_id))
	var health_by_member := _bind_health(context, party, 2)
	var before := _runtime_observation(store, path, context, party, health_by_member, changed_members)
	var bad_generation := _generation_request(9021, 1, 35, WEAPON_BASE_ID)
	bad_generation.required_affix_tags = [&"weapon"]
	bad_generation.excluded_affix_tags = [&"weapon"]
	var generation_result := ItemGenerationService.generate(
		bad_generation, "run:%s:%s:%s" % [PROFILE_ID, RUN_SEED, RUN_PLAYER_ID], 1,
		GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG,
	)
	_assert(not generation_result.ok(), "TASK3 generation: failed run generation is rejected")
	_assert_runtime_unchanged(before, store, path, context, party, health_by_member, changed_members, "TASK3 generation")

	var valid_generation := ItemGenerationService.generate(
		_generation_request(9021, 1, 35, WEAPON_BASE_ID), "run:%s:%s:%s" % [PROFILE_ID, RUN_SEED, RUN_PLAYER_ID], 1,
		GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG,
	)
	_assert(valid_generation.ok(), "TASK3 generation: same unconsumed sequence remains usable")
	if not valid_generation.ok():
		return
	var ownership_before := _runtime_observation(store, path, context, party, health_by_member, changed_members)
	var bad_owner := context.apply_item_transaction(
		ItemTransactionRequest.create("run-create-wrong-owner", "other-owner", &"run-inventory", 0, valid_generation.item),
		GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG,
	)
	_assert(not bad_owner.ok(), "TASK8 ownership: wrong-owner run issuance is rejected")
	_assert_runtime_unchanged(ownership_before, store, path, context, party, health_by_member, changed_members, "TASK8 ownership")
	var accepted := context.apply_item_transaction(
		ItemTransactionRequest.create("run-create-sequence-one", String(RUN_PLAYER_ID), &"run-inventory", 0, valid_generation.item),
		GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG,
	)
	_assert(accepted.ok(), "TASK8 ownership: sequence remains available after failed generation and ownership")

	var equipment_before := _runtime_observation(store, path, context, party, health_by_member, changed_members)
	var bad_equipment := context.assign_equipment(1, "missing-task12-item", &"main_hand", GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	_assert(not bad_equipment.ok() and bad_equipment.error.contains("unknown item"), "TASK7 equipment: missing-item transition is rejected diagnostically")
	_assert_runtime_unchanged(equipment_before, store, path, context, party, health_by_member, changed_members, "TASK7 equipment")

	var extraction_before := _runtime_observation(store, path, context, party, health_by_member, changed_members)
	var wrong_source: Array[ExtractionSelection] = [ExtractionSelection.create(follower_item_id, &"run-equipment-002", 0)]
	var request := RunResolutionRequest.create("task12-invalid-extraction", PROFILE_ID, RUN_ID, RUN_SEED, RUN_PLAYER_ID, LEADER_ID, wrong_source)
	var rejected := RunResolutionService.new(ProfileMutationService.new(store)).resolve(PROFILE_ID, context, request, PROFILE_ROOT)
	_assert(not rejected.ok() and rejected.error.contains("expected run-equipment-002[0]"), "TASK8 extraction: stale follower source is rejected diagnostically")
	_assert_runtime_unchanged(extraction_before, store, path, context, party, health_by_member, changed_members, "TASK8 extraction")
	_assert(context.item_resolution_error("task12-valid-after-rejection").is_empty(), "TASK8 extraction: rejected selection leaves context unresolved")


func _verify_twenty_four_member_isolation() -> void:
	var party := _fighter_party(24)
	var profile := ProfileState.new_profile("task12-isolation-profile", "Task 12 Isolation", 1000)
	profile.inventory_columns = 5
	var context := PlayerRunContext.new()
	var errors := context.configure(&"task12_isolation_player", 0, profile, 242424, party, 100)
	_assert(errors.is_empty(), "TASK8 ownership: 24-member public run context configures")
	if not errors.is_empty():
		return
	var issuer_namespace := "run:%s:%s:%s" % [profile.profile_id, 242424, context.run_player_id]
	var item_ids: Array[String] = []
	for index: int in 24:
		var generated := ItemGenerationService.generate(
			_generation_request(242500 + index, index, 20 + index, WEAPON_BASE_ID), issuer_namespace, index,
			GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG,
		)
		_assert(generated.ok(), "TASK3-6 generation: isolation weapon %d generates" % (index + 1))
		if not generated.ok():
			return
		var item := generated.item
		item_ids.append(item.instance_id)
		var created := context.apply_item_transaction(
			ItemTransactionRequest.create("isolation-create-%02d" % index, String(context.run_player_id), &"run-inventory", index, item),
			GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG,
		)
		_assert(created.ok(), "TASK8 ownership: isolation weapon %d enters run inventory" % (index + 1))
		var equipped := context.assign_equipment(index + 1, item.instance_id, &"main_hand", GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
		_assert(equipped.ok(), "TASK7 equipment: isolation member %d equips its own main hand" % (index + 1))
	var distinct: Dictionary = {}
	for member_id: int in range(1, 25):
		var item_id := context.equipment_for(member_id).item_id_at(EquipmentSlotIndex.index_for(&"main_hand"))
		distinct[item_id] = true
	_assert(distinct.size() == 24 and distinct.keys().all(func(value: Variant) -> bool: return not String(value).is_empty()), "TASK8 ownership: 24 members own 24 distinct main hands")

	var health_by_member := _bind_health(context, party, 24)
	var action := party.member_by_id(1).class_definition.primary_attack
	var snapshots: Dictionary = {}
	for member_id: int in range(2, 25):
		var weapon := context.equipment_activation(member_id).weapon_snapshot()
		var tags := DamageResolver.action_tags_for(action, weapon)
		snapshots[member_id] = {
			"equipment": context.equipment_for(member_id).to_dictionary(),
			"activation": _activation_document(context.equipment_activation(member_id)),
			"sources": _source_document(party.member_by_id(member_id).modifier_sources),
			"base": party.stats_for(member_id),
			"base_revision": party.stats_for(member_id).revision,
			"action": party.stats_for_action(member_id, tags),
			"action_revision": party.stats_for_action(member_id, tags).revision,
			"estimate": _estimate_document(ActionCombatEstimateService.estimate(action, member_id, party, GameCatalog.DAMAGE_TYPES)),
			"health": _health_document(health_by_member[member_id]),
		}
	var immutable_bytes := _item_bytes(context.item_state())
	var changed: Array[int] = []
	party.stats_changed.connect(func(member_id: int) -> void: changed.append(member_id))
	var revision_before := party.stat_revision()
	var transitioned := context.assign_equipment(1, item_ids[0], &"", GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	_assert(transitioned.ok(), "TASK7 equipment: member one isolation transition succeeds")
	_assert(changed == [1] and party.stat_revision() == revision_before + 1, "TASK7 equipment: member one transition emits and revises exactly once")
	_assert(_item_bytes(context.item_state()) == immutable_bytes, "TASK8 ownership: member one transition preserves all 24 immutable item bytes")
	for member_id: int in range(2, 25):
		var record := snapshots[member_id] as Dictionary
		var activation := context.equipment_activation(member_id)
		var tags := DamageResolver.action_tags_for(action, activation.weapon_snapshot())
		var base := party.stats_for(member_id)
		var action_snapshot := party.stats_for_action(member_id, tags)
		_assert(context.equipment_for(member_id).to_dictionary() == record["equipment"], "TASK8 ownership: transition preserves member %d owned equipment" % member_id)
		_assert(_activation_document(activation) == record["activation"], "TASK7 activation: transition preserves member %d activation snapshot" % member_id)
		_assert(_source_document(party.member_by_id(member_id).modifier_sources) == record["sources"], "TASK7 activation: transition preserves member %d owned sources" % member_id)
		_assert(is_same(base, record["base"]) and base.revision == int(record["base_revision"]), "TASK7 cache: transition preserves member %d base cache identity and revision" % member_id)
		_assert(is_same(action_snapshot, record["action"]) and action_snapshot.revision == int(record["action_revision"]), "TASK9 cache: transition preserves member %d action cache identity and revision" % member_id)
		_assert(_estimate_document(ActionCombatEstimateService.estimate(action, member_id, party, GameCatalog.DAMAGE_TYPES)) == record["estimate"], "TASK9 estimate: transition preserves member %d action estimate" % member_id)
		_assert(_health_document(health_by_member[member_id]) == record["health"], "TASK9 health: transition preserves member %d health" % member_id)

	var health_before: Dictionary = {}
	for member_id: int in range(1, 25):
		health_before[member_id] = _health_document(health_by_member[member_id])
	var attacker_activation := context.equipment_activation(2)
	var attacker_stats := party.stats_for_action(2, DamageResolver.action_tags_for(action, attacker_activation.weapon_snapshot()))
	var attacker := CombatantAdapter.new(null, &"party:2", 1, health_by_member[2], attacker_stats, true, Callable(), attacker_activation.weapon_snapshot())
	var target := CombatantAdapter.new(null, &"party:3", 2, health_by_member[3], party.stats_for(3))
	var packet := DamageResolver.prepare(action, attacker, CombatRng.new(242601, [0.99, 0.5]), GameCatalog.DAMAGE_TYPES)
	var result := DamageResolver.resolve(packet, target, CombatRng.new(242602, [0.99, 0.99]), GameCatalog.DAMAGE_TYPES)
	_assert(packet.valid and result.valid and result.actual_health_removed > 0.0, "TASK9 combat: member two weapon attack resolves against member three")
	for member_id: int in range(1, 25):
		var changed_health: bool = _health_document(health_by_member[member_id]) != health_before[member_id]
		_assert(changed_health == (member_id == 3), "TASK9 health: attack changes only intended target member 3 (checked member %d)" % member_id)


func _generation_request(seed: int, sequence: int, level: int, base_id: StringName) -> ItemGenerationRequest:
	var request := ItemGenerationRequest.create(seed, sequence, level, &"ordinary_enemy", &"ordinary_drop", [&"common"])
	request.forced_base_id = base_id
	request.forced_rarity_id = &"common"
	return request


func _issue_support_item(sequence: int) -> ItemIssueResult:
	return ItemInstanceIssuer.issue(
		"profile:%s" % PROFILE_ID,
		sequence,
		{"task": 12, "purpose": "attribute_support"},
		9101,
		{
			"affixes": [{
				"definition_id": "stout",
				"affix_kind": "prefix",
				"tier": 1,
				"rolls": [{"stat_id": "constitution", "operation": StatModifier.Operation.FLAT, "value": 3.0, "required_tags": []}],
			}],
			"base_definition_id": String(SUPPORT_BASE_ID),
			"base_damage_components": [],
			"item_level": 28,
			"rarity_id": "uncommon",
		},
		GameCatalog.EQUIPMENT_CATALOG,
		GameCatalog.ITEM_FOUNDATION_CATALOG,
	)


func _assign_profile_item(store: ProfileStore, profile_id: String, item_id: String, source_id: StringName, source_slot: int, slot_id: StringName, transaction_id: String) -> ProfileMutationResult:
	var loaded := store.load_profile(profile_id, PROFILE_ROOT)
	if not loaded.ok():
		var failed := ProfileMutationResult.new()
		failed.error = loaded.error
		return failed
	var request := ProfileLoadoutAssignmentRequest.create(
		transaction_id, profile_id, &"fighter", item_id,
		source_id, source_slot, &"leader-loadout", EquipmentSlotIndex.index_for(slot_id), "",
		ProfileLoadoutAssignmentRequest.fingerprint_for(loaded.profile),
	)
	return ProfileLoadoutAssignmentService.new(ProfileMutationService.new(store)).apply(profile_id, request, PROFILE_ROOT)


func _catalog_requiring_support(class_definition: ClassDefinition) -> EquipmentCatalog:
	var catalog := GameCatalog.EQUIPMENT_CATALOG.duplicate(true) as EquipmentCatalog
	for index: int in catalog.definitions.size():
		var definition := catalog.definitions[index]
		if definition != null and definition.id == WEAPON_BASE_ID:
			var required := definition.duplicate(true) as EquipmentBaseDefinition
			required.attribute_requirements = {&"constitution": float(class_definition.stat_base_values().get(&"constitution", 0.0)) + 1.0}
			catalog.definitions[index] = required
			break
	return catalog


func _fighter_party(member_count: int) -> PartyManager:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.configure_capacity(PartyCapacityPolicy.new(member_count))
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	for _index: int in range(1, member_count):
		_assert(party.recruit(catalog.class_by_id(&"fighter")), "TASK8 party: recruits fixture member %d" % (_index + 1))
	_parties.append(party)
	return party


func _bind_health(context: PlayerRunContext, party: PartyManager, member_count: int) -> Dictionary:
	var result: Dictionary = {}
	for member_id: int in range(1, member_count + 1):
		var actor := Node3D.new()
		var health := HealthComponent.new()
		health.name = "HealthComponent"
		health.configure(party.stats_for(member_id).value(&"max_health", 100.0), true, 8.0, 0.5, true)
		actor.add_child(health)
		root.add_child(actor)
		_nodes.append(actor)
		_assert(context.bind_actor(member_id, actor), "TASK9 health: binds member %d runtime health" % member_id)
		result[member_id] = health
	return result


func _packet_uses_weapon_ranges(packet: DamagePacket, weapon: ActiveWeaponDamageSnapshot) -> bool:
	if packet == null or weapon == null or packet.components.size() != weapon.components.size():
		return false
	var bounds: Dictionary = {}
	for component: ItemBaseDamageComponent in weapon.components:
		bounds[component.damage_type_id] = Vector2(component.minimum_damage, component.maximum_damage)
	for component: PreparedDamageComponent in packet.components:
		if not bounds.has(component.damage_type_id):
			return false
		var range := bounds[component.damage_type_id] as Vector2
		if component.authored_amount < range.x or component.authored_amount > range.y:
			return false
	return true


func _runtime_observation(store: ProfileStore, path: String, context: PlayerRunContext, party: PartyManager, health_by_member: Dictionary, changed_members: Array[int]) -> Dictionary:
	var activation_documents: Dictionary = {}
	var source_documents: Dictionary = {}
	var base_snapshots: Dictionary = {}
	var action_snapshots: Dictionary = {}
	var estimates: Dictionary = {}
	var health: Dictionary = {}
	for member: PartyMemberState in party.members:
		var activation := context.equipment_activation(member.member_id)
		var attack := member.class_definition.primary_attack
		var tags := DamageResolver.action_tags_for(attack, activation.weapon_snapshot())
		activation_documents[member.member_id] = _activation_document(activation)
		source_documents[member.member_id] = _source_document(member.modifier_sources)
		base_snapshots[member.member_id] = party.stats_for(member.member_id)
		action_snapshots[member.member_id] = party.stats_for_action(member.member_id, tags)
		estimates[member.member_id] = _estimate_document(ActionCombatEstimateService.estimate(attack, member.member_id, party, GameCatalog.DAMAGE_TYPES))
		health[member.member_id] = _health_document(health_by_member[member.member_id])
	return {
		"profile_bytes": FileAccess.get_file_as_bytes(path),
		"profile": store.load_profile(PROFILE_ID, PROFILE_ROOT).profile.to_dictionary(),
		"state": JSON.stringify(context.item_state().to_dictionary()),
		"item_bytes": _item_bytes(context.item_state()),
		"activations": activation_documents,
		"sources": source_documents,
		"base": base_snapshots,
		"action": action_snapshots,
		"estimates": estimates,
		"revision": party.stat_revision(),
		"health": health,
		"signals": changed_members.duplicate(),
	}


func _assert_runtime_unchanged(before: Dictionary, store: ProfileStore, path: String, context: PlayerRunContext, party: PartyManager, health_by_member: Dictionary, changed_members: Array[int], owner: String) -> void:
	_assert(FileAccess.get_file_as_bytes(path) == before["profile_bytes"], "%s atomicity: profile bytes unchanged" % owner)
	_assert(store.load_profile(PROFILE_ID, PROFILE_ROOT).profile.to_dictionary() == before["profile"], "%s atomicity: profile projection unchanged" % owner)
	_assert(JSON.stringify(context.item_state().to_dictionary()) == before["state"], "%s atomicity: run ownership unchanged" % owner)
	_assert(_item_bytes(context.item_state()) == before["item_bytes"], "%s atomicity: immutable item bytes unchanged" % owner)
	_assert(party.stat_revision() == int(before["revision"]), "%s atomicity: revision unchanged" % owner)
	_assert(changed_members == before["signals"], "%s atomicity: signal state unchanged" % owner)
	for member: PartyMemberState in party.members:
		var member_id := member.member_id
		var activation := context.equipment_activation(member_id)
		var tags := DamageResolver.action_tags_for(member.class_definition.primary_attack, activation.weapon_snapshot())
		_assert(_activation_document(activation) == (before["activations"] as Dictionary)[member_id], "%s atomicity: member %d activation unchanged" % [owner, member_id])
		_assert(_source_document(member.modifier_sources) == (before["sources"] as Dictionary)[member_id], "%s atomicity: member %d sources unchanged" % [owner, member_id])
		_assert(is_same(party.stats_for(member_id), (before["base"] as Dictionary)[member_id]), "%s atomicity: member %d base cache identity unchanged" % [owner, member_id])
		_assert(is_same(party.stats_for_action(member_id, tags), (before["action"] as Dictionary)[member_id]), "%s atomicity: member %d action cache identity unchanged" % [owner, member_id])
		_assert(_estimate_document(ActionCombatEstimateService.estimate(member.class_definition.primary_attack, member_id, party, GameCatalog.DAMAGE_TYPES)) == (before["estimates"] as Dictionary)[member_id], "%s atomicity: member %d estimate unchanged" % [owner, member_id])
		_assert(_health_document(health_by_member[member_id]) == (before["health"] as Dictionary)[member_id], "%s atomicity: member %d health unchanged" % [owner, member_id])


func _activation_document(activation: EquipmentActivationResult) -> Dictionary:
	if activation == null:
		return {}
	var disabled: Dictionary = {}
	var state_ids := activation.active_item_ids.duplicate()
	var weapon := activation.weapon_snapshot()
	return {
		"error": activation.error,
		"active": state_ids,
		"weapon": _weapon_document(weapon),
		"source": _source_document([activation.source] if activation.source != null else []),
		"disabled": disabled,
	}


func _weapon_document(weapon: ActiveWeaponDamageSnapshot) -> Dictionary:
	if weapon == null:
		return {}
	var components: Array[Dictionary] = []
	for component: ItemBaseDamageComponent in weapon.components:
		components.append(component.to_dictionary())
	return {"member_id": weapon.member_id, "item_id": weapon.item_id, "base_id": String(weapon.base_id), "revision": weapon.revision, "components": components}


func _source_document(sources: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for source: StatModifierSource in sources:
		if source == null:
			result.append({})
			continue
		var modifiers: Array[Dictionary] = []
		for modifier: StatModifier in source.modifiers:
			modifiers.append({
				"stat_id": String(modifier.stat_id), "operation": modifier.operation, "value": modifier.value,
				"source_id": String(modifier.source_id), "source_label": modifier.source_label,
				"required_tags": modifier.required_tags.map(func(tag: StringName) -> String: return String(tag)),
			})
		result.append({"id": String(source.id), "source_type": String(source.source_type), "label": source.label, "owner_member_id": source.owner_member_id, "modifiers": modifiers})
	return result


func _estimate_document(estimate: ActionCombatEstimate) -> Dictionary:
	if estimate == null:
		return {}
	return {
		"available": estimate.available, "reason": estimate.unavailable_reason,
		"normal_hit": estimate.normal_hit, "critical_hit": estimate.critical_hit,
		"average_hit": estimate.average_hit, "aps": estimate.attacks_per_second,
		"dps": estimate.estimated_dps, "components": estimate.component_rows.duplicate(true),
	}


func _health_document(health: HealthComponent) -> Vector2:
	return Vector2(health.current_health, health.max_health) if health != null else Vector2(-1.0, -1.0)


func _item_bytes(state: ItemOwnershipState) -> Dictionary:
	var result: Dictionary = {}
	if state == null:
		return result
	var registry := state.registry()
	for item_id: String in registry.ids():
		result[item_id] = ItemInstanceCodec.encode(registry.item(item_id))
	return result


func _profile_registry(profile: ProfileState) -> ItemRegistry:
	var container_documents: Array = [profile.leader_loadout.duplicate(true)]
	container_documents.append_array(profile.stash_tabs.duplicate(true))
	var decoded := ItemOwnershipState.decode(
		{
			"schema_version": ItemOwnershipState.SCHEMA_VERSION,
			"owner_id": profile.profile_id,
			"registry": profile.item_records.duplicate(true),
			"containers": container_documents,
		},
		GameCatalog.EQUIPMENT_CATALOG,
		GameCatalog.ITEM_FOUNDATION_CATALOG
	)
	return decoded.state.registry() if decoded.ok() else null


func _profile_stash_contains(profile: ProfileState, item_id: String) -> bool:
	for tab: Dictionary in profile.stash_tabs:
		if item_id in (tab.get("slots", {}) as Dictionary).values():
			return true
	return false


func _finish() -> void:
	for party: PartyManager in _parties:
		if is_instance_valid(party):
			party.free()
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	ProfileTestSupport.remove_tree(PROFILE_ROOT)
	if _failures.is_empty():
		print("WEIGHTED_LOOT_PRODUCTION_INTEGRATION: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error("WEIGHTED_LOOT_PRODUCTION_INTEGRATION: %s" % failure)
	quit(1)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
