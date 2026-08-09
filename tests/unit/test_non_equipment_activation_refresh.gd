extends RefCounted

const MEMBER_COUNT := 24
const REQUIRED_STRENGTH := 1.0
const ITEM_CONSTITUTION := 3.0
const ITEM_ID := "task10a-required-sword"
const BASE_ID := &"forge_vanguard_sword"
const SLOT_ID := &"main_hand"
const ACTION_ONLY_TAG := &"task10d_action_only"


class RejectingRefreshPartyManager extends PartyManager:
	var reject_refreshed_equipment_source := false

	func _commit_member_source_without_invalidation(member_id: int, source: StatModifierSource) -> bool:
		if reject_refreshed_equipment_source and source != null and source.source_type == &"equipment":
			return false
		return super._commit_member_source_without_invalidation(member_id, source)


class ResumeOverflowPartyManager extends PartyManager:
	func install_source_without_invalidation(member_id: int, source: StatModifierSource) -> bool:
		return _commit_member_source_without_invalidation(member_id, source)


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_growth_reactivates_and_requirement_loss_disables(failures)
	_test_personal_attribute_upgrade_and_direct_source_replacement(failures)
	_test_refresh_commit_failure_rolls_back_exact_state(failures)
	_test_action_overflow_refresh_is_rejected_atomically(failures)
	_test_resume_action_overflow_is_rejected_atomically(failures)
	_test_resume_geometry_overflow_is_rejected_atomically(failures)
	_test_aggregate_stat_overflow_refresh_is_rejected_atomically(failures)
	_test_resume_aggregate_stat_overflow_is_rejected_atomically(failures)
	return failures


func _test_growth_reactivates_and_requirement_loss_disables(failures: Array[String]) -> void:
	var definition_fixture := _install_required_sword_definition()
	var original_definition := definition_fixture["original"] as EquipmentBaseDefinition
	var party := _party(MEMBER_COUNT)
	var fixture := _configured_equipped_fixture(party, "growth", 10101)
	var context := fixture["context"] as PlayerRunContext
	var item := fixture["item"] as ItemInstance
	var fighter := party.member_by_id(1).class_definition
	var item_bytes_before := JSON.stringify(item.to_dictionary())
	var ownership_before := JSON.stringify(context.item_state().to_dictionary())
	var class_base_before := JSON.stringify(fighter.stat_base_values())
	var growth_cycle_before := fighter.growth_definition.guaranteed_cycle.duplicate()
	var base_maximum := party.stats_for(1).value(&"max_health")
	var initial_activation := context.equipment_activation(1)
	TestAssertions.truthy(not initial_activation.is_active(item.instance_id), "requirement item starts disabled before growth", failures)
	TestAssertions.equal(context.equipment_for(1).item_id_at(EquipmentSlotIndex.index_for(SLOT_ID)), item.instance_id, "disabled requirement item starts equipped", failures)

	var action_tags := DamageResolver.action_tags_for(fighter.primary_attack)
	var member_one_base_before := party.stats_for(1)
	var member_one_action_before := party.stats_for_action(1, action_tags)
	var untouched := _capture_untouched(party, action_tags)
	var actor_scene := load("res://scenes/characters/leader.tscn") as PackedScene
	var actor := actor_scene.instantiate() as PartyActor
	actor.configure(party.member_by_id(1))
	actor.configure_combat(party)
	var health := actor.get_node("HealthComponent") as HealthComponent
	health.apply_damage(40.0)
	var current_before_growth := health.current_health

	var changed: Array[int] = []
	var observations: Array[Dictionary] = []
	party.stats_changed.connect(func(member_id: int) -> void:
		changed.append(member_id)
		if member_id == 1:
			observations.append({
				"active": context.equipment_activation(1).is_active(item.instance_id),
				"equipped": context.equipment_for(1).item_id_at(EquipmentSlotIndex.index_for(SLOT_ID)),
				"growth_source": _has_source(party.member_by_id(1), &"character_growth_1"),
				"maximum": party.stats_for(1).value(&"max_health"),
				"health_maximum": health.max_health,
			})
	)
	var level_events: Array[int] = []
	var progression_events: Array[int] = []
	context.member_level_ready.connect(func(_member_id: int, level: int) -> void: level_events.append(level))
	context.progression_changed.connect(func(member_id: int) -> void: progression_events.append(member_id))
	var revision_before_growth := party.stat_revision()
	var growth := context.award_experience(1, 20)
	TestAssertions.truthy(growth.ok() and growth.gained_levels == [2], "fighter growth reaches the requirement-restoring level", failures)
	TestAssertions.equal(changed, [1], "growth refresh emits exactly one member-local stat signal", failures)
	TestAssertions.equal(level_events, [2], "growth retains the exact level-ready signal", failures)
	TestAssertions.equal(progression_events, [1], "growth retains the exact progression signal", failures)
	TestAssertions.equal(party.stat_revision(), revision_before_growth + 1, "growth refresh advances the shared revision once", failures)
	TestAssertions.equal(observations.size(), 1, "growth has one synchronous stat observation", failures)
	if observations.size() == 1:
		TestAssertions.truthy(bool(observations[0]["active"]), "growth observer sees reactivated equipment", failures)
		TestAssertions.equal(observations[0]["equipped"], item.instance_id, "growth observer sees unchanged equipment ownership", failures)
		TestAssertions.truthy(bool(observations[0]["growth_source"]), "growth observer sees the committed growth source", failures)
		TestAssertions.near(float(observations[0]["maximum"]), base_maximum + ITEM_CONSTITUTION * 3.0, 0.0001, "growth observer sees final equipment-derived health", failures)
		TestAssertions.near(float(observations[0]["health_maximum"]), base_maximum + ITEM_CONSTITUTION * 3.0, 0.0001, "growth observer sees refreshed runtime maximum health", failures)
	TestAssertions.truthy(context.equipment_activation(1).is_active(item.instance_id), "growth automatically reactivates equipped gear", failures)
	TestAssertions.near(health.current_health, current_before_growth, 0.0001, "growth reactivation raises maximum health without healing", failures)
	TestAssertions.truthy(not is_same(party.stats_for(1), member_one_base_before), "growth replaces the affected member base snapshot", failures)
	TestAssertions.truthy(not is_same(party.stats_for_action(1, action_tags), member_one_action_before), "growth replaces the affected member action snapshot", failures)
	_assert_untouched(party, action_tags, untouched, "growth", failures)

	changed.clear()
	observations.clear()
	health.current_health = base_maximum + 5.0
	var revision_before_loss := party.stat_revision()
	var respec_source := StatModifierSource.create(&"character_growth_1", &"character_growth", "Class Growth", 1, [])
	TestAssertions.truthy(party.replace_member_source(1, respec_source), "direct respec source replacement succeeds", failures)
	TestAssertions.equal(changed, [1], "requirement-loss refresh emits exactly one member-local stat signal", failures)
	TestAssertions.equal(party.stat_revision(), revision_before_loss + 1, "requirement-loss refresh advances the revision once", failures)
	TestAssertions.truthy(not context.equipment_activation(1).is_active(item.instance_id), "requirement loss disables the dependent item", failures)
	TestAssertions.equal(context.equipment_activation(1).disabled_reasons(item.instance_id), PackedStringArray([
		"PARTY_FORGE_EQUIPMENT_ERROR item=forge_vanguard_sword reason=attribute strength",
	]), "requirement loss retains the exact unmet-Strength reason", failures)
	TestAssertions.equal(context.equipment_for(1).item_id_at(EquipmentSlotIndex.index_for(SLOT_ID)), item.instance_id, "requirement loss does not unequip the dependent item", failures)
	TestAssertions.near(party.stats_for(1).value(&"max_health"), base_maximum, 0.0001, "disabled dependent item contributes no Constitution health", failures)
	TestAssertions.near(health.max_health, base_maximum, 0.0001, "requirement loss lowers runtime maximum health", failures)
	TestAssertions.near(health.current_health, base_maximum, 0.0001, "requirement loss clamps current health without percentage preservation", failures)
	_assert_untouched(party, action_tags, untouched, "requirement loss", failures)
	TestAssertions.equal(JSON.stringify(item.to_dictionary()), item_bytes_before, "growth and respec preserve immutable item bytes", failures)
	TestAssertions.equal(JSON.stringify(context.item_state().to_dictionary()), ownership_before, "growth and respec preserve exact run ownership", failures)
	TestAssertions.equal(JSON.stringify(fighter.stat_base_values()), class_base_before, "growth and respec preserve class base values", failures)
	TestAssertions.equal(fighter.growth_definition.guaranteed_cycle, growth_cycle_before, "growth and respec preserve the class growth Resource", failures)
	TestAssertions.equal(original_definition.attribute_requirements, definition_fixture["original_requirements"], "test requirement copy leaves the original item definition immutable", failures)
	actor.free()
	party.free()
	_restore_definition(definition_fixture)


func _test_personal_attribute_upgrade_and_direct_source_replacement(failures: Array[String]) -> void:
	var definition_fixture := _install_required_sword_definition()
	var catalog := GameCatalog.load_defaults()
	var party := _party(1, catalog)
	var fixture := _configured_equipped_fixture(party, "upgrade", 10201)
	var context := fixture["context"] as PlayerRunContext
	var item := fixture["item"] as ItemInstance
	var upgrade := UpgradeDefinition.new()
	upgrade.id = &"task10a_strength_upgrade"
	upgrade.display_name = "Task 10A Strength"
	upgrade.summary = "Fixture"
	upgrade.description = "Fixture"
	upgrade.tooltip_keyword_ids = [&"strength"]
	upgrade.max_rank = 1
	var effect := StatUpgradeEffect.new()
	effect.stat_id = &"strength"
	effect.operation = StatModifier.Operation.FLAT
	effect.value_per_rank = REQUIRED_STRENGTH
	effect.source_label = "Task 10A Strength"
	upgrade.effects = [effect]
	catalog.upgrades.append(upgrade)
	var item_bytes_before := JSON.stringify(item.to_dictionary())
	var base_maximum := party.stats_for(1).value(&"max_health")
	var changed: Array[int] = []
	var active_during_signal: Array[bool] = []
	party.stats_changed.connect(func(member_id: int) -> void:
		changed.append(member_id)
		if member_id == 1:
			active_during_signal.append(context.equipment_activation(1).is_active(item.instance_id))
	)
	var revision_before := party.stat_revision()
	TestAssertions.truthy(UpgradeApplicationService.apply(upgrade.id, catalog, party, 1), "personal core-attribute upgrade applies", failures)
	TestAssertions.equal(party.upgrade_rank(upgrade.id, 1), 1, "personal core-attribute upgrade commits its rank", failures)
	TestAssertions.equal(changed, [1], "personal upgrade refresh emits one stat signal", failures)
	TestAssertions.equal(active_during_signal, [true], "personal upgrade observer sees reactivated equipment", failures)
	TestAssertions.equal(party.stat_revision(), revision_before + 1, "personal upgrade refresh advances one revision", failures)
	TestAssertions.truthy(context.equipment_activation(1).is_active(item.instance_id), "personal upgrade reactivates requirement gear", failures)
	TestAssertions.near(party.stats_for(1).value(&"max_health"), base_maximum + ITEM_CONSTITUTION * 3.0, 0.0001, "personal upgrade includes the reactivated equipment source", failures)

	changed.clear()
	active_during_signal.clear()
	revision_before = party.stat_revision()
	var empty_upgrade := StatModifierSource.create(&"upgrade:task10a_strength_upgrade:member:1", &"authored_upgrade", "Respec", 1, [])
	TestAssertions.truthy(party.replace_member_source(1, empty_upgrade), "direct upgrade source replacement succeeds", failures)
	TestAssertions.equal(changed, [1], "direct upgrade source replacement emits one stat signal", failures)
	TestAssertions.equal(active_during_signal, [false], "direct source replacement observer sees disabled equipment", failures)
	TestAssertions.equal(party.stat_revision(), revision_before + 1, "direct source replacement advances one revision", failures)
	TestAssertions.truthy(not context.equipment_activation(1).is_active(item.instance_id), "direct source replacement disables requirement gear", failures)
	TestAssertions.equal(context.equipment_for(1).item_id_at(EquipmentSlotIndex.index_for(SLOT_ID)), item.instance_id, "direct source replacement retains equipped ownership", failures)
	TestAssertions.equal(JSON.stringify(item.to_dictionary()), item_bytes_before, "upgrade and direct replacement preserve immutable item bytes", failures)
	party.free()
	_restore_definition(definition_fixture)


func _test_refresh_commit_failure_rolls_back_exact_state(failures: Array[String]) -> void:
	var definition_fixture := _install_required_sword_definition()
	var party := _party(2, GameCatalog.load_defaults(), RejectingRefreshPartyManager.new()) as RejectingRefreshPartyManager
	var fixture := _configured_equipped_fixture(party, "failure", 10301)
	var context := fixture["context"] as PlayerRunContext
	var item := fixture["item"] as ItemInstance
	var action_tags := DamageResolver.action_tags_for(party.member_by_id(1).class_definition.primary_attack)
	var activation_before := context.equipment_activation(1)
	var sources_before := _source_documents(party.member_by_id(1))
	var ownership_before := JSON.stringify(context.item_state().to_dictionary())
	var item_before := JSON.stringify(item.to_dictionary())
	var base_before := party.stats_for(1)
	var action_before := party.stats_for_action(1, action_tags)
	var member_two_base_before := party.stats_for(2)
	var member_two_action_before := party.stats_for_action(2, action_tags)
	var revision_before := party.stat_revision()
	var changed: Array[int] = []
	party.stats_changed.connect(func(member_id: int) -> void: changed.append(member_id))
	party.reject_refreshed_equipment_source = true
	var candidate := StatModifierSource.create(&"task10a_rejected_growth", &"character_growth", "Rejected Growth", 1, [
		StatModifier.create(&"strength", StatModifier.Operation.FLAT, REQUIRED_STRENGTH, &"task10a_rejected_strength", "Rejected Growth"),
	])
	TestAssertions.truthy(not party.replace_member_source(1, candidate), "equipment-source commit rejection fails the source refresh", failures)
	TestAssertions.equal(_source_documents(party.member_by_id(1)), sources_before, "failed refresh restores the exact member source documents", failures)
	TestAssertions.equal(context.equipment_activation(1).active_item_ids, activation_before.active_item_ids, "failed refresh restores exact activation IDs", failures)
	TestAssertions.equal(context.equipment_activation(1).disabled_reasons(item.instance_id), activation_before.disabled_reasons(item.instance_id), "failed refresh restores exact disabled reasons", failures)
	TestAssertions.equal(JSON.stringify(context.item_state().to_dictionary()), ownership_before, "failed refresh preserves exact ownership", failures)
	TestAssertions.equal(JSON.stringify(item.to_dictionary()), item_before, "failed refresh preserves immutable item bytes", failures)
	TestAssertions.equal(party.stat_revision(), revision_before, "failed refresh preserves the exact revision", failures)
	TestAssertions.equal(changed, [], "failed refresh emits no stat signal", failures)
	TestAssertions.truthy(is_same(party.stats_for(1), base_before), "failed refresh preserves affected base cache identity", failures)
	TestAssertions.truthy(is_same(party.stats_for_action(1, action_tags), action_before), "failed refresh preserves affected action cache identity", failures)
	TestAssertions.truthy(is_same(party.stats_for(2), member_two_base_before), "failed refresh preserves unrelated base cache identity", failures)
	TestAssertions.truthy(is_same(party.stats_for_action(2, action_tags), member_two_action_before), "failed refresh preserves unrelated action cache identity", failures)
	party.free()
	_restore_definition(definition_fixture)


func _test_action_overflow_refresh_is_rejected_atomically(failures: Array[String]) -> void:
	var party := _party_with_action_only_tag(2)
	var profile := ProfileState.new_profile("task10d-refresh-profile", "Task 10D Refresh", 1000)
	profile.inventory_columns = 1
	var context := PlayerRunContext.new()
	TestAssertions.equal(context.configure(&"task10d-refresh-player", 0, profile, 10401, party, 100), PackedStringArray(), "action-overflow refresh fixture configures", failures)
	var action_tags := DamageResolver.action_tags_for(party.member_by_id(1).class_definition.primary_attack)
	var actor_scene := load("res://scenes/characters/leader.tscn") as PackedScene
	var actor := actor_scene.instantiate() as PartyActor
	actor.configure(party.member_by_id(1))
	actor.configure_combat(party)
	var health := actor.get_node("HealthComponent") as HealthComponent
	health.apply_damage(40.0)
	var health_before := Vector2(health.current_health, health.max_health)
	var sources_before := _source_documents(party.member_by_id(1))
	var activation_before := context.equipment_activation(1)
	var base_before := party.stats_for(1)
	var action_before := party.stats_for_action(1, action_tags)
	var member_two_base_before := party.stats_for(2)
	var member_two_action_before := party.stats_for_action(2, action_tags)
	var revision_before := party.stat_revision()
	var changed: Array[int] = []
	party.stats_changed.connect(func(member_id: int) -> void: changed.append(member_id))

	TestAssertions.truthy(not party.add_member_source(1, _action_overflow_source()), "non-equipment action overflow rejects the coordinated refresh", failures)
	TestAssertions.equal(_source_documents(party.member_by_id(1)), sources_before, "action-overflow refresh preserves exact sources", failures)
	TestAssertions.equal(context.equipment_activation(1).active_item_ids, activation_before.active_item_ids, "action-overflow refresh preserves activation", failures)
	TestAssertions.equal(party.stat_revision(), revision_before, "action-overflow refresh preserves revision", failures)
	TestAssertions.equal(changed, [], "action-overflow refresh emits no stat signal", failures)
	TestAssertions.truthy(is_same(party.stats_for(1), base_before), "action-overflow refresh preserves affected base cache identity", failures)
	TestAssertions.truthy(is_same(party.stats_for_action(1, action_tags), action_before), "action-overflow refresh preserves affected action cache identity", failures)
	TestAssertions.truthy(is_same(party.stats_for(2), member_two_base_before), "action-overflow refresh preserves unrelated base cache identity", failures)
	TestAssertions.truthy(is_same(party.stats_for_action(2, action_tags), member_two_action_before), "action-overflow refresh preserves unrelated action cache identity", failures)
	TestAssertions.equal(Vector2(health.current_health, health.max_health), health_before, "action-overflow refresh preserves runtime health", failures)
	actor.free()
	party.free()


func _test_resume_action_overflow_is_rejected_atomically(failures: Array[String]) -> void:
	var party := _party_with_action_only_tag(2)
	TestAssertions.truthy(party.add_member_source(1, _action_overflow_source()), "resume overflow fixture installs its preexisting source", failures)
	var owner := "task10d-resume-player"
	var seed := 10402
	var containers: Array[ItemSlotContainer] = [
		ItemSlotContainer.create(&"run-inventory", ItemSlotContainer.RUN_INVENTORY, owner, 5),
		ItemSlotContainer.create(&"run-equipment-001", ItemSlotContainer.RUN_MEMBER_EQUIPMENT, owner, EquipmentSlotIndex.capacity()),
		ItemSlotContainer.create(&"run-equipment-002", ItemSlotContainer.RUN_MEMBER_EQUIPMENT, owner, EquipmentSlotIndex.capacity()),
	]
	var state := ItemOwnershipState.create(owner, ItemRegistry.new(), containers)
	var bootstrap := RunItemBootstrap.create(&"task10d-resume-run", seed, StringName(owner), 1, state)
	var profile := ProfileState.new_profile("task10d-resume-profile", "Task 10D Resume", 1000)
	profile.inventory_columns = 1
	profile.resumable_run = ResumableRunItemCodec.encode(bootstrap)
	var context := PlayerRunContext.new()
	var action_tags := DamageResolver.action_tags_for(party.member_by_id(1).class_definition.primary_attack)
	var actor_scene := load("res://scenes/characters/leader.tscn") as PackedScene
	var actor := actor_scene.instantiate() as PartyActor
	actor.configure(party.member_by_id(1))
	actor.configure_combat(party)
	var health := actor.get_node("HealthComponent") as HealthComponent
	health.apply_damage(40.0)
	var health_before := Vector2(health.current_health, health.max_health)
	var sources_before := _source_documents(party.member_by_id(1))
	var activation_before := context.equipment_activation(1)
	var base_before := party.stats_for(1)
	var action_before := party.stats_for_action(1, action_tags)
	var member_two_base_before := party.stats_for(2)
	var member_two_action_before := party.stats_for_action(2, action_tags)
	var revision_before := party.stat_revision()
	var changed: Array[int] = []
	party.stats_changed.connect(func(member_id: int) -> void: changed.append(member_id))

	var errors := context.configure(StringName(owner), 0, profile, seed, party, 100, bootstrap)
	TestAssertions.truthy(not errors.is_empty() and String(errors[0]).contains("action=fighter_cleave"), "resume reconstruction rejects the preexisting action overflow", failures)
	TestAssertions.truthy(not context.is_configured(), "rejected resume remains unconfigured", failures)
	TestAssertions.equal(_source_documents(party.member_by_id(1)), sources_before, "rejected resume preserves exact sources", failures)
	TestAssertions.equal(context.equipment_activation(1).error, activation_before.error, "rejected resume preserves activation state", failures)
	TestAssertions.equal(party.stat_revision(), revision_before, "rejected resume preserves revision", failures)
	TestAssertions.equal(changed, [], "rejected resume emits no stat signal", failures)
	TestAssertions.truthy(is_same(party.stats_for(1), base_before), "rejected resume preserves affected base cache identity", failures)
	TestAssertions.truthy(is_same(party.stats_for_action(1, action_tags), action_before), "rejected resume preserves affected action cache identity", failures)
	TestAssertions.truthy(is_same(party.stats_for(2), member_two_base_before), "rejected resume preserves unrelated base cache identity", failures)
	TestAssertions.truthy(is_same(party.stats_for_action(2, action_tags), member_two_action_before), "rejected resume preserves unrelated action cache identity", failures)
	TestAssertions.equal(Vector2(health.current_health, health.max_health), health_before, "rejected resume preserves runtime health", failures)
	actor.free()
	party.free()


func _test_resume_geometry_overflow_is_rejected_atomically(failures: Array[String]) -> void:
	var party := _party_with_action_only_tag(2)
	party.member_by_id(1).class_definition.primary_attack.range = 1.0e308
	TestAssertions.truthy(party.add_member_source(1, _geometry_overflow_source()), "resume geometry fixture installs its finite preexisting source", failures)
	var owner := "task10j-resume-player"
	var seed := 10403
	var containers: Array[ItemSlotContainer] = [
		ItemSlotContainer.create(&"run-inventory", ItemSlotContainer.RUN_INVENTORY, owner, 5),
		ItemSlotContainer.create(&"run-equipment-001", ItemSlotContainer.RUN_MEMBER_EQUIPMENT, owner, EquipmentSlotIndex.capacity()),
		ItemSlotContainer.create(&"run-equipment-002", ItemSlotContainer.RUN_MEMBER_EQUIPMENT, owner, EquipmentSlotIndex.capacity()),
	]
	var state := ItemOwnershipState.create(owner, ItemRegistry.new(), containers)
	var bootstrap := RunItemBootstrap.create(&"task10j-resume-run", seed, StringName(owner), 1, state)
	var profile := ProfileState.new_profile("task10j-resume-profile", "Task 10J Resume", 1000)
	profile.inventory_columns = 1
	profile.resumable_run = ResumableRunItemCodec.encode(bootstrap)
	var context := PlayerRunContext.new()
	var action_tags := DamageResolver.action_tags_for(party.member_by_id(1).class_definition.primary_attack)
	var sources_before := _source_documents(party.member_by_id(1))
	var base_before := party.stats_for(1)
	var action_before := party.stats_for_action(1, action_tags)
	var member_two_base_before := party.stats_for(2)
	var member_two_action_before := party.stats_for_action(2, action_tags)
	var revision_before := party.stat_revision()
	var changed: Array[int] = []
	party.stats_changed.connect(func(member_id: int) -> void: changed.append(member_id))
	var errors := context.configure(StringName(owner), 0, profile, seed, party, 100, bootstrap)
	TestAssertions.truthy(not errors.is_empty() and String(errors[0]).contains("action=fighter_cleave") and String(errors[0]).contains("range"), "resume reconstruction rejects non-finite effective range", failures)
	TestAssertions.truthy(not context.is_configured(), "geometry-rejected resume remains unconfigured", failures)
	TestAssertions.equal(_source_documents(party.member_by_id(1)), sources_before, "geometry-rejected resume preserves sources", failures)
	TestAssertions.equal(party.stat_revision(), revision_before, "geometry-rejected resume preserves revision", failures)
	TestAssertions.equal(changed, [], "geometry-rejected resume emits no stat signal", failures)
	TestAssertions.truthy(is_same(party.stats_for(1), base_before), "geometry-rejected resume preserves affected base cache", failures)
	TestAssertions.truthy(is_same(party.stats_for_action(1, action_tags), action_before), "geometry-rejected resume preserves affected action cache", failures)
	TestAssertions.truthy(is_same(party.stats_for(2), member_two_base_before), "geometry-rejected resume preserves unrelated base cache", failures)
	TestAssertions.truthy(is_same(party.stats_for_action(2, action_tags), member_two_action_before), "geometry-rejected resume preserves unrelated action cache", failures)
	party.free()


func _test_aggregate_stat_overflow_refresh_is_rejected_atomically(failures: Array[String]) -> void:
	var party := _party(2)
	var profile := ProfileState.new_profile("task10i-refresh-profile", "Task 10I Refresh", 1000)
	profile.inventory_columns = 1
	var context := PlayerRunContext.new()
	TestAssertions.equal(context.configure(&"task10i-refresh-player", 0, profile, 10501, party, 100), PackedStringArray(), "aggregate-overflow refresh fixture configures", failures)
	var action_tags := DamageResolver.action_tags_for(party.member_by_id(1).class_definition.primary_attack)
	var actor_scene := load("res://scenes/characters/leader.tscn") as PackedScene
	var actor := actor_scene.instantiate() as PartyActor
	actor.configure(party.member_by_id(1))
	actor.configure_combat(party)
	var health := actor.get_node("HealthComponent") as HealthComponent
	health.apply_damage(40.0)
	var health_before := Vector2(health.current_health, health.max_health)
	var sources_before := _source_documents(party.member_by_id(1))
	var activation_before := context.equipment_activation(1)
	var base_before := party.stats_for(1)
	var action_before := party.stats_for_action(1, action_tags)
	var member_two_base_before := party.stats_for(2)
	var member_two_action_before := party.stats_for_action(2, action_tags)
	var revision_before := party.stat_revision()
	var changed: Array[int] = []
	party.stats_changed.connect(func(member_id: int) -> void: changed.append(member_id))

	TestAssertions.truthy(not party.add_member_source(1, _aggregate_overflow_source()), "aggregate stat overflow rejects the coordinated refresh", failures)
	TestAssertions.equal(_source_documents(party.member_by_id(1)), sources_before, "aggregate-overflow refresh preserves exact sources", failures)
	TestAssertions.equal(context.equipment_activation(1).active_item_ids, activation_before.active_item_ids, "aggregate-overflow refresh preserves activation", failures)
	TestAssertions.equal(party.stat_revision(), revision_before, "aggregate-overflow refresh preserves revision", failures)
	TestAssertions.equal(changed, [], "aggregate-overflow refresh emits no stat signal", failures)
	TestAssertions.truthy(is_same(party.stats_for(1), base_before), "aggregate-overflow refresh preserves affected base cache identity", failures)
	TestAssertions.truthy(is_same(party.stats_for_action(1, action_tags), action_before), "aggregate-overflow refresh preserves affected action cache identity", failures)
	TestAssertions.truthy(is_same(party.stats_for(2), member_two_base_before), "aggregate-overflow refresh preserves unrelated base cache identity", failures)
	TestAssertions.truthy(is_same(party.stats_for_action(2, action_tags), member_two_action_before), "aggregate-overflow refresh preserves unrelated action cache identity", failures)
	TestAssertions.equal(Vector2(health.current_health, health.max_health), health_before, "aggregate-overflow refresh preserves runtime health", failures)
	actor.free()
	party.free()


func _test_resume_aggregate_stat_overflow_is_rejected_atomically(failures: Array[String]) -> void:
	var party := _party(2, null, ResumeOverflowPartyManager.new()) as ResumeOverflowPartyManager
	var owner := "task10i-resume-player"
	var seed := 10502
	var containers: Array[ItemSlotContainer] = [
		ItemSlotContainer.create(&"run-inventory", ItemSlotContainer.RUN_INVENTORY, owner, 5),
		ItemSlotContainer.create(&"run-equipment-001", ItemSlotContainer.RUN_MEMBER_EQUIPMENT, owner, EquipmentSlotIndex.capacity()),
		ItemSlotContainer.create(&"run-equipment-002", ItemSlotContainer.RUN_MEMBER_EQUIPMENT, owner, EquipmentSlotIndex.capacity()),
	]
	var state := ItemOwnershipState.create(owner, ItemRegistry.new(), containers)
	var bootstrap := RunItemBootstrap.create(&"task10i-resume-run", seed, StringName(owner), 1, state)
	var profile := ProfileState.new_profile("task10i-resume-profile", "Task 10I Resume", 1000)
	profile.inventory_columns = 1
	profile.resumable_run = ResumableRunItemCodec.encode(bootstrap)
	var context := PlayerRunContext.new()
	var action_tags := DamageResolver.action_tags_for(party.member_by_id(1).class_definition.primary_attack)
	var actor_scene := load("res://scenes/characters/leader.tscn") as PackedScene
	var actor := actor_scene.instantiate() as PartyActor
	actor.configure(party.member_by_id(1))
	actor.configure_combat(party)
	var health := actor.get_node("HealthComponent") as HealthComponent
	health.apply_damage(40.0)
	var health_before := Vector2(health.current_health, health.max_health)
	var activation_before := context.equipment_activation(1)
	var base_before := party.stats_for(1)
	var action_before := party.stats_for_action(1, action_tags)
	var member_two_base_before := party.stats_for(2)
	var member_two_action_before := party.stats_for_action(2, action_tags)
	var revision_before := party.stat_revision()
	var changed: Array[int] = []
	party.stats_changed.connect(func(member_id: int) -> void: changed.append(member_id))
	TestAssertions.truthy(party.install_source_without_invalidation(1, _aggregate_overflow_source()), "resume aggregate-overflow fixture installs its preexisting source without observable mutation", failures)
	var sources_before := _source_documents(party.member_by_id(1))

	var errors := context.configure(StringName(owner), 0, profile, seed, party, 100, bootstrap)
	TestAssertions.truthy(not errors.is_empty() and String(errors[0]).contains("stat=max_health stage=raw"), "resume reconstruction rejects the preexisting aggregate stat overflow", failures)
	TestAssertions.truthy(not context.is_configured(), "aggregate-overflow resume remains unconfigured", failures)
	TestAssertions.equal(_source_documents(party.member_by_id(1)), sources_before, "aggregate-overflow resume preserves exact sources", failures)
	TestAssertions.equal(context.equipment_activation(1).error, activation_before.error, "aggregate-overflow resume preserves activation state", failures)
	TestAssertions.equal(party.stat_revision(), revision_before, "aggregate-overflow resume preserves revision", failures)
	TestAssertions.equal(changed, [], "aggregate-overflow resume emits no stat signal", failures)
	TestAssertions.truthy(is_same(party.stats_for(1), base_before), "aggregate-overflow resume preserves affected base cache identity", failures)
	TestAssertions.truthy(is_same(party.stats_for_action(1, action_tags), action_before), "aggregate-overflow resume preserves affected action cache identity", failures)
	TestAssertions.truthy(is_same(party.stats_for(2), member_two_base_before), "aggregate-overflow resume preserves unrelated base cache identity", failures)
	TestAssertions.truthy(is_same(party.stats_for_action(2, action_tags), member_two_action_before), "aggregate-overflow resume preserves unrelated action cache identity", failures)
	TestAssertions.equal(Vector2(health.current_health, health.max_health), health_before, "aggregate-overflow resume preserves runtime health", failures)
	actor.free()
	party.free()


func _party(member_count: int, catalog: GameCatalog = null, manager: PartyManager = null) -> PartyManager:
	var owned_catalog := catalog if catalog != null else GameCatalog.load_defaults()
	var party := manager if manager != null else PartyManager.new()
	party.configure_capacity(PartyCapacityPolicy.new(member_count))
	party.initialize(owned_catalog.class_by_id(&"fighter"), owned_catalog.traits)
	for _index: int in range(1, member_count):
		assert(party.recruit(owned_catalog.class_by_id(&"fighter")))
	return party


func _party_with_action_only_tag(member_count: int) -> PartyManager:
	var catalog := GameCatalog.load_defaults()
	var fighter := catalog.class_by_id(&"fighter").duplicate(true) as ClassDefinition
	fighter.primary_attack = fighter.primary_attack.duplicate(true) as AttackDefinition
	fighter.primary_attack.action_tags = fighter.primary_attack.action_tags.duplicate()
	fighter.primary_attack.action_tags.append(ACTION_ONLY_TAG)
	var party := PartyManager.new()
	party.configure_capacity(PartyCapacityPolicy.new(member_count))
	party.initialize(fighter, catalog.traits)
	for _index: int in range(1, member_count):
		assert(party.recruit(fighter))
	return party


func _action_overflow_source() -> StatModifierSource:
	var modifiers: Array[StatModifier] = []
	for index: int in 4:
		modifiers.append(StatModifier.create(
			&"cooldown_rate", StatModifier.Operation.MORE, 1.0e100,
			StringName("task10d_refresh_overflow_%d" % index), "Task 10D Refresh Overflow", [ACTION_ONLY_TAG],
		))
	return StatModifierSource.create(&"task10d_refresh_overflow", &"character_growth", "Task 10D Refresh Overflow", 1, modifiers)


func _geometry_overflow_source() -> StatModifierSource:
	return StatModifierSource.create(&"task10j_refresh_geometry", &"character_growth", "Task 10J Geometry Overflow", 1, [
		StatModifier.create(
			&"attack_range", StatModifier.Operation.INCREASED, 1.0,
			&"task10j_refresh_geometry_roll", "Task 10J Geometry Overflow", [ACTION_ONLY_TAG],
		),
	])


func _aggregate_overflow_source() -> StatModifierSource:
	var modifiers: Array[StatModifier] = []
	for index: int in 4:
		modifiers.append(StatModifier.create(
			&"max_health", StatModifier.Operation.MORE, 1.0e100,
			StringName("task10i_refresh_aggregate_%d" % index), "Task 10I Aggregate Overflow",
		))
	return StatModifierSource.create(&"task10i_refresh_aggregate", &"character_growth", "Task 10I Aggregate Overflow", 1, modifiers)


func _configured_equipped_fixture(party: PartyManager, label: String, seed: int) -> Dictionary:
	var owner := "task10a_%s_player" % label
	var profile_id := "task10a-%s-profile" % label
	var item_document := {
		"schema_version": ItemInstance.SCHEMA_VERSION,
		"instance_id": "%s-%s" % [ITEM_ID, label],
		"base_definition_id": String(BASE_ID),
		"item_level": 1,
		"rarity_id": "common",
		"affixes": [{
			"definition_id": "stout",
			"affix_kind": "prefix",
			"tier": 1,
			"rolls": [{
				"stat_id": "constitution",
				"operation": StatModifier.Operation.FLAT,
				"value": ITEM_CONSTITUTION,
				"required_tags": [],
			}],
		}],
		"origin": {"issuer_namespace": "run:%s:%d:%s" % [profile_id, seed, owner], "seed": seed, "sequence": 0, "source": "task10a"},
	}
	var decoded := ItemInstanceCodec.decode(item_document, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	assert(decoded.ok())
	var item := decoded.item
	var containers: Array[ItemSlotContainer] = [
		ItemSlotContainer.create(&"run-inventory", ItemSlotContainer.RUN_INVENTORY, owner, 5),
	]
	for member_id: int in range(1, party.members.size() + 1):
		containers.append(ItemSlotContainer.create(
			StringName("run-equipment-%03d" % member_id),
			ItemSlotContainer.RUN_MEMBER_EQUIPMENT,
			owner,
			EquipmentSlotIndex.capacity(),
			{EquipmentSlotIndex.index_for(SLOT_ID): item.instance_id} if member_id == 1 else {},
		))
	var state := ItemOwnershipState.create(owner, ItemRegistry.new([item]), containers)
	assert(state.validate(GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG).is_empty())
	var bootstrap := RunItemBootstrap.create(StringName("task10a-%s-run" % label), seed, StringName(owner), 1, state)
	var profile := ProfileState.new_profile(profile_id, "Task 10A %s" % label.capitalize(), 1000)
	profile.inventory_columns = 1
	profile.resumable_run = ResumableRunItemCodec.encode(bootstrap)
	var context := PlayerRunContext.new()
	var errors := context.configure(StringName(owner), 0, profile, seed, party, 100, bootstrap)
	assert(errors.is_empty())
	return {"context": context, "item": item}


func _install_required_sword_definition() -> Dictionary:
	var equipment := GameCatalog.EQUIPMENT_CATALOG
	for index: int in equipment.definitions.size():
		var definition := equipment.definitions[index]
		if definition != null and definition.id == BASE_ID:
			var candidate := definition.duplicate(true) as EquipmentBaseDefinition
			candidate.attribute_requirements = {&"strength": REQUIRED_STRENGTH}
			equipment.definitions[index] = candidate
			return {
				"catalog": equipment,
				"index": index,
				"original": definition,
				"original_requirements": definition.attribute_requirements.duplicate(true),
			}
	assert(false, "required sword fixture base is missing")
	return {}


func _restore_definition(fixture: Dictionary) -> void:
	(fixture["catalog"] as EquipmentCatalog).definitions[int(fixture["index"])] = fixture["original"] as EquipmentBaseDefinition


func _capture_untouched(party: PartyManager, action_tags: Array[StringName]) -> Dictionary:
	var result: Dictionary = {}
	for member_id: int in range(2, party.members.size() + 1):
		var base := party.stats_for(member_id)
		var action := party.stats_for_action(member_id, action_tags)
		result[member_id] = {
			"base": base,
			"base_revision": base.revision,
			"action": action,
			"action_revision": action.revision,
		}
	return result


func _assert_untouched(party: PartyManager, action_tags: Array[StringName], before: Dictionary, phase: String, failures: Array[String]) -> void:
	for member_id: int in before:
		var record := before[member_id] as Dictionary
		var base := party.stats_for(member_id)
		var action := party.stats_for_action(member_id, action_tags)
		TestAssertions.truthy(is_same(base, record["base"]), "%s preserves member %d base cache identity" % [phase, member_id], failures)
		TestAssertions.equal(base.revision, int(record["base_revision"]), "%s preserves member %d base revision" % [phase, member_id], failures)
		TestAssertions.truthy(is_same(action, record["action"]), "%s preserves member %d action cache identity" % [phase, member_id], failures)
		TestAssertions.equal(action.revision, int(record["action_revision"]), "%s preserves member %d action revision" % [phase, member_id], failures)


func _has_source(member: PartyMemberState, source_id: StringName) -> bool:
	return member != null and member.modifier_sources.any(func(source: StatModifierSource) -> bool: return source != null and source.id == source_id)


func _source_documents(member: PartyMemberState) -> String:
	var documents: Array[Dictionary] = []
	for source: StatModifierSource in member.modifier_sources:
		var modifiers: Array[Dictionary] = []
		for modifier: StatModifier in source.modifiers:
			modifiers.append({
				"stat_id": String(modifier.stat_id),
				"operation": modifier.operation,
				"value": modifier.value,
				"source_id": String(modifier.source_id),
				"source_label": modifier.source_label,
				"required_tags": modifier.required_tags,
				"excluded_tags": modifier.excluded_tags,
				"required_capability_tags": modifier.required_capability_tags,
				"excluded_capability_tags": modifier.excluded_capability_tags,
				"required_action_tags": modifier.required_action_tags,
				"excluded_action_tags": modifier.excluded_action_tags,
			})
		documents.append({
			"id": String(source.id),
			"source_type": String(source.source_type),
			"label": source.label,
			"owner_member_id": source.owner_member_id,
			"modifiers": modifiers,
		})
	return JSON.stringify(documents)
