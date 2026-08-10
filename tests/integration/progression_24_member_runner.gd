extends SceneTree

const TARGET_SIZES: Array[int] = [1, 6, 12, 24]
const PHYSICS_FRAMES := 120
const MEMBERS_PER_FULL_CONTEXT := 6
const CLASS_IDS: Array[StringName] = [
	&"fighter", &"ranger", &"mage", &"cleric", &"paladin", &"rogue",
	&"frost_mage", &"warlock", &"marksman",
]
const LEADER_SCENE: PackedScene = preload("res://scenes/characters/leader.tscn")
const COMPANION_SCENE: PackedScene = preload("res://scenes/characters/companion.tscn")
const LEDGER_SCENE: PackedScene = preload("res://scenes/ui/ledger/character_ledger.tscn")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var user_args := OS.get_cmdline_user_args()
	var single_size_index := user_args.find("--single-size")
	if single_size_index >= 0 and single_size_index + 1 < user_args.size():
		var single_size := int(user_args[single_size_index + 1])
		if single_size not in TARGET_SIZES:
			push_error("PROGRESSION_24_MEMBER_FAILURE: unsupported single size %d" % single_size)
			quit(1)
			return
		await _exercise_size(single_size)
		quit(0 if _failures.is_empty() else 1)
		return

	var project_path := ProjectSettings.globalize_path("res://")
	var executable := OS.get_executable_path()
	for target_size: int in TARGET_SIZES:
		var child_output: Array = []
		var child_code := OS.execute(executable, [
			"--headless",
			"--path", project_path,
			"--quit-after", "300",
			"--script", "res://tests/integration/progression_24_member_runner.gd",
			"--", "--single-size", str(target_size),
		], child_output, true)
		var combined_output := "\n".join(child_output)
		if not combined_output.is_empty():
			print(combined_output.trim_suffix("\n"))
		var expected_marker := "PROGRESSION_LOAD_SIZE_PASS members=%d " % target_size
		_assert(child_code == 0, "%d members child exits zero (actual %d)" % [target_size, child_code])
		_assert(expected_marker in combined_output, "%d members child emits its exact size marker" % target_size)
	if _failures.is_empty():
		print("PROGRESSION_24_MEMBER_SUMMARY: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error("PROGRESSION_24_MEMBER_FAILURE: %s" % failure)
	print("PROGRESSION_24_MEMBER_SUMMARY: FAIL failures=%d" % _failures.size())
	quit(1)


func _exercise_size(target_size: int) -> void:
	var failure_count_before := _failures.size()
	paused = false
	var scenario := Node.new()
	scenario.name = "ProgressionLoad%d" % target_size
	root.add_child(scenario)
	var actor_container := Node3D.new()
	actor_container.name = "Actors"
	scenario.add_child(actor_container)
	var effects := Node3D.new()
	effects.name = "Effects"
	scenario.add_child(effects)

	var catalog := GameCatalog.load_defaults()
	if target_size == 24:
		_exercise_single_party_snapshot_isolation(catalog)
		_exercise_distinct_weapon_isolation(catalog)
	var registry := RunContextRegistry.new()
	var contexts: Array[PlayerRunContext] = []
	var profiles_before: Array[Dictionary] = []
	var actors: Array[PartyActor] = []
	var expected_awards: Dictionary = {}
	var context_count := _context_count_for(target_size)
	var remaining := target_size
	for context_index: int in context_count:
		var member_count := mini(MEMBERS_PER_FULL_CONTEXT, remaining)
		remaining -= member_count
		var party := PartyManager.new()
		party.name = "Party%d" % context_index
		party.configure_capacity(PartyCapacityPolicy.new(member_count))
		party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
		for member_offset: int in range(1, member_count):
			var class_id := CLASS_IDS[(context_index * MEMBERS_PER_FULL_CONTEXT + member_offset) % CLASS_IDS.size()]
			_assert(party.recruit(catalog.class_by_id(class_id)), "%d members context %d recruits member %d" % [target_size, context_index, member_offset + 1])
		scenario.add_child(party)
		var profile := ProfileState.new_profile(
			"profile-load-%02d-%02d" % [target_size, context_index],
			"Load %d Context %d" % [target_size, context_index + 1],
			1000 + context_index,
		)
		profiles_before.append(profile.to_dictionary())
		var context := PlayerRunContext.new()
		var configure_errors := context.configure(
			StringName("load_player_%02d_%02d" % [target_size, context_index]),
			context_index,
			profile,
			1337 + target_size * 100 + context_index,
			party,
			100,
		)
		_assert(configure_errors.is_empty(), "%d members context %d configures" % [target_size, context_index])
		_assert(registry.register_context(context, context_index).ok(), "%d members context %d registers" % [target_size, context_index])
		contexts.append(context)
		var leader: PartyActor
		for member: PartyMemberState in party.members:
			var actor := (LEADER_SCENE.instantiate() if member.is_leader else COMPANION_SCENE.instantiate()) as PartyActor
			if member.is_leader:
				leader = actor
			else:
				actor.set("leader", leader)
			actor.position = Vector3(float(context_index) * 24.0 + float(member.member_id - 1), 0.0, float(member.member_id % 2))
			actor_container.add_child(actor)
			actor.configure(member)
			actor.configure_combat(party, effects)
			_assert(context.bind_actor(member.member_id, actor), "%d members context %d binds member %d" % [target_size, context_index, member.member_id])
			actors.append(actor)

	_assert(remaining == 0, "%d members fixture allocates every requested member" % target_size)
	_assert(contexts.size() == context_count, "%d members fixture uses %d contexts" % [target_size, context_count])
	_assert(actors.size() == target_size, "%d members fixture binds %d live actors" % [target_size, target_size])
	_assert(_party_member_count(contexts) == target_size, "%d members fixture owns %d party members" % [target_size, target_size])
	for context_index: int in contexts.size():
		_assert(contexts[context_index].profile_snapshot.to_dictionary() == profiles_before[context_index], "%d members context %d owns an unchanged profile snapshot" % [target_size, context_index])
		if context_index > 0:
			_assert(contexts[context_index].party != contexts[context_index - 1].party, "%d members adjacent contexts own distinct parties" % target_size)
			_assert(not is_same(contexts[context_index].get("_progression_by_member"), contexts[context_index - 1].get("_progression_by_member")), "%d members adjacent contexts own distinct progression dictionaries" % target_size)

	var process_total := 0.0
	var process_maximum := 0.0
	var physics_total := 0.0
	var physics_maximum := 0.0
	for _frame_index: int in PHYSICS_FRAMES:
		await physics_frame
		var process_seconds := Performance.get_monitor(Performance.TIME_PROCESS)
		var physics_seconds := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		process_total += process_seconds
		physics_total += physics_seconds
		process_maximum = maxf(process_maximum, process_seconds)
		physics_maximum = maxf(physics_maximum, physics_seconds)
	var process_average := process_total / float(PHYSICS_FRAMES)
	var physics_average := physics_total / float(PHYSICS_FRAMES)

	var progression_started := Time.get_ticks_usec()
	var global_member_index := 0
	for context_index: int in contexts.size():
		var context := contexts[context_index]
		for member: PartyMemberState in context.party.members:
			global_member_index += 1
			var amount := 156 + global_member_index - 1
			var award := context.award_experience(member.member_id, amount)
			_assert(award.ok(), "%d members context %d member %d progression award succeeds" % [target_size, context_index, member.member_id])
			if award.ok():
				expected_awards[_member_key(context_index, member.member_id)] = award.next_state.to_snapshot()
	var progression_usec := Time.get_ticks_usec() - progression_started

	var run := GameRun.new()
	scenario.add_child(run)
	run.start_run()
	var ledger := LEDGER_SCENE.instantiate() as CharacterLedger
	scenario.add_child(ledger)
	var ledger_usec := 0
	for context_index: int in contexts.size():
		var context := contexts[context_index]
		ledger.configure(
			run,
			context.party,
			catalog,
			Callable(),
			[],
			null,
			Callable(context, "progression_for"),
			context,
		)
		_assert(ledger.open_for_player(), "%d members context %d production ledger opens" % [target_size, context_index])
		var ledger_started := Time.get_ticks_usec()
		ledger.refresh()
		ledger_usec += Time.get_ticks_usec() - ledger_started
		var rows_by_member: Dictionary = {}
		for row: Dictionary in ledger.provider.member_rows():
			rows_by_member[int(row.get("member_id", 0))] = row
		_assert(rows_by_member.size() == context.party.members.size(), "%d members context %d ledger contains every member row" % [target_size, context_index])
		for member: PartyMemberState in context.party.members:
			var member_key := _member_key(context_index, member.member_id)
			var state := context.progression_for(member.member_id)
			var expected := expected_awards.get(member_key, {}) as Dictionary
			_assert(state != null and state.to_snapshot() == expected, "%d members context %d member %d state matches committed award" % [target_size, context_index, member.member_id])
			_assert(state != null and state.level >= 5 and state.guaranteed_growth_history.size() >= 4 and state.milestone_outcomes.size() >= 1, "%d members context %d member %d reaches multiple levels with milestone growth" % [target_size, context_index, member.member_id])
			_assert(context.member_is_available(member.member_id), "%d members context %d member %d remains live and available" % [target_size, context_index, member.member_id])
			var row := rows_by_member.get(member.member_id, {}) as Dictionary
			_assert(not row.is_empty() and int(row.get("character_level", 0)) == state.level and int(row.get("experience", -1)) == state.experience, "%d members context %d member %d ledger row matches progression" % [target_size, context_index, member.member_id])
			var gained_attribute := _first_gained_attribute(state)
			var detail := ledger.provider.stat_detail(member.member_id, gained_attribute)
			_assert(_has_growth_source(detail), "%d members context %d member %d ledger detail uses production Class Growth source" % [target_size, context_index, member.member_id])
		_assert(context.pending_leader_levels().size() == 4, "%d members context %d queues only its leader's four earned levels" % [target_size, context_index])
		ledger.close()
		paused = false

	var static_memory := Performance.get_monitor(Performance.MEMORY_STATIC)
	var static_memory_max := Performance.get_monitor(Performance.MEMORY_STATIC_MAX)
	var metrics: Array[float] = [process_average, process_maximum, physics_average, physics_maximum, static_memory, static_memory_max]
	_assert(metrics.all(func(value: float) -> bool: return is_finite(value)), "%d members monitor metrics are finite" % target_size)
	_assert(progression_usec >= 0 and ledger_usec >= 0, "%d members elapsed measurements are nonnegative" % target_size)
	_assert(static_memory >= 0.0 and static_memory_max >= 0.0, "%d members memory measurements are nonnegative" % target_size)
	var marker := "PROGRESSION_LOAD_SIZE_PASS members=%d contexts=%d actors=%d party_members=%d physics_frames=%d progression_usec=%d ledger_usec=%d process_avg_ms=%.6f process_max_ms=%.6f physics_avg_ms=%.6f physics_max_ms=%.6f static_memory_bytes=%d static_memory_max_bytes=%d" % [
			target_size,
			contexts.size(),
			actors.size(),
			_party_member_count(contexts),
			PHYSICS_FRAMES,
			progression_usec,
			ledger_usec,
			process_average * 1000.0,
			process_maximum * 1000.0,
			physics_average * 1000.0,
			physics_maximum * 1000.0,
			int(static_memory),
			int(static_memory_max),
		]

	paused = false
	if _failures.size() == failure_count_before:
		print(marker)
	else:
		for index: int in range(failure_count_before, _failures.size()):
			push_error("PROGRESSION_LOAD_SIZE_FAILURE members=%d reason=%s" % [target_size, _failures[index]])


func _context_count_for(target_size: int) -> int:
	match target_size:
		1, 6:
			return 1
		12:
			return 2
		24:
			return 4
		_:
			return 0


func _party_member_count(contexts: Array[PlayerRunContext]) -> int:
	var total := 0
	for context: PlayerRunContext in contexts:
		total += context.party.members.size() if context.party != null else 0
	return total


func _member_key(context_index: int, member_id: int) -> String:
	return "%d:%d" % [context_index, member_id]


func _first_gained_attribute(state: CharacterProgressionState) -> StringName:
	for attribute_id: StringName in ClassGrowthDefinition.CORE_ATTRIBUTE_IDS:
		if int(state.core_attribute_gains.get(attribute_id, 0)) > 0:
			return attribute_id
	return &""


func _has_growth_source(detail: Dictionary) -> bool:
	return Array(detail.get("sources", [])).any(
		func(source: Dictionary) -> bool: return String(source.get("source_label", "")) == "Class Growth"
	)


func _exercise_single_party_snapshot_isolation(catalog: GameCatalog) -> void:
	var party := PartyManager.new()
	party.configure_capacity(PartyCapacityPolicy.new(24))
	party.initialize(catalog.class_by_id(&"mage"), catalog.traits)
	for _member_index: int in range(1, 24):
		_assert(party.recruit(catalog.class_by_id(&"mage")), "single-party isolation recruits member %d" % (_member_index + 1))
	_assert(party.members.size() == 24, "single-party isolation reaches the developer capacity")
	var action_tags := DamageResolver.action_tags_for(catalog.class_by_id(&"mage").primary_attack)
	var snapshots: Dictionary = {}
	for member_id: int in range(2, 25):
		var base := party.stats_for(member_id)
		var action := party.stats_for_action(member_id, action_tags)
		snapshots[member_id] = {
			"base": base,
			"base_revision": base.revision,
			"action": action,
			"action_revision": action.revision,
		}
	var changed_members: Array[int] = []
	party.stats_changed.connect(func(member_id: int) -> void: changed_members.append(member_id))
	var revision_before := party.stat_revision()
	var source := StatModifierSource.create(
		&"progression_24_member_isolation",
		&"test",
		"24-member isolation",
		1,
		[StatModifier.create(&"constitution", StatModifier.Operation.FLAT, 1.0, &"progression_24_member_isolation_constitution", "24-member isolation")],
	)
	_assert(party.replace_member_source(1, source), "single-party member-one source replacement succeeds")
	_assert(changed_members == [1], "single-party replacement emits only member one")
	_assert(party.stat_revision() == revision_before + 1, "single-party replacement advances one revision")
	for member_id: int in range(2, 25):
		var record := snapshots[member_id] as Dictionary
		var base := party.stats_for(member_id)
		var action := party.stats_for_action(member_id, action_tags)
		_assert(is_same(base, record["base"]), "single-party member %d base snapshot identity is preserved" % member_id)
		_assert(base.revision == int(record["base_revision"]), "single-party member %d base snapshot revision is preserved" % member_id)
		_assert(is_same(action, record["action"]), "single-party member %d action snapshot identity is preserved" % member_id)
		_assert(action.revision == int(record["action_revision"]), "single-party member %d action snapshot revision is preserved" % member_id)
	if changed_members == [1]:
		print("PROGRESSION_24_MEMBER_ISOLATION_PASS members=24 untouched=23")
	party.free()


func _exercise_distinct_weapon_isolation(catalog: GameCatalog) -> void:
	var party := PartyManager.new()
	party.configure_capacity(PartyCapacityPolicy.new(24))
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	for member_index: int in range(1, 24):
		_assert(party.recruit(catalog.class_by_id(&"fighter")), "distinct-weapon isolation recruits member %d" % (member_index + 1))
	var profile := ProfileState.new_profile("profile-progression-weapons", "Progression Weapons", 1000)
	profile.inventory_columns = 5
	var context := PlayerRunContext.new()
	var configure_errors := context.configure(&"progression_weapon_player", 0, profile, 2424, party, 100)
	_assert(configure_errors.is_empty(), "distinct-weapon isolation context configures")
	if not configure_errors.is_empty():
		party.free()
		return
	var issuer_namespace := "run:%s:%s:%s" % [profile.profile_id, 2424, context.run_player_id]
	var item_ids: Array[String] = []
	for index: int in 24:
		var request := ItemGenerationRequest.create(2500 + index, index, 20 + index, &"ordinary_enemy", &"ordinary_drop", [&"common"])
		request.forced_base_id = &"forge_vanguard_sword"
		request.forced_rarity_id = &"common"
		var generated := ItemGenerationService.generate(
			request, issuer_namespace, index,
			GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG,
		)
		_assert(generated.ok(), "distinct-weapon member %d generates through the production service" % (index + 1))
		if not generated.ok():
			party.free()
			return
		item_ids.append(generated.item.instance_id)
		var created := context.apply_item_transaction(
			ItemTransactionRequest.create("progression-weapon-create-%02d" % index, String(context.run_player_id), &"run-inventory", index, generated.item),
			GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG,
		)
		_assert(created.ok(), "distinct-weapon member %d item enters run ownership" % (index + 1))
		var equipped := context.assign_equipment(index + 1, generated.item.instance_id, &"main_hand", GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
		_assert(equipped.ok(), "distinct-weapon member %d equips its main hand" % (index + 1))
	var distinct: Dictionary = {}
	for member_id: int in range(1, 25):
		distinct[context.equipment_for(member_id).item_id_at(EquipmentSlotIndex.index_for(&"main_hand"))] = true
	_assert(distinct.size() == 24 and not distinct.has(""), "distinct-weapon fixture owns 24 unique nonempty main hands")

	var actors: Array[Node3D] = []
	var health_by_member: Dictionary = {}
	for member_id: int in range(1, 25):
		var actor := Node3D.new()
		var health := HealthComponent.new()
		health.name = "HealthComponent"
		health.configure(party.stats_for(member_id).value(&"max_health", 100.0), true, 8.0, 0.5, true)
		actor.add_child(health)
		_assert(context.bind_actor(member_id, actor), "distinct-weapon member %d binds runtime health" % member_id)
		actors.append(actor)
		health_by_member[member_id] = health

	var attack := party.member_by_id(1).class_definition.primary_attack
	var records: Dictionary = {}
	for member_id: int in range(2, 25):
		var activation := context.equipment_activation(member_id)
		var action_tags := DamageResolver.action_tags_for(attack, activation.weapon_snapshot())
		var base_snapshot := party.stats_for(member_id)
		var action_snapshot := party.stats_for_action(member_id, action_tags)
		records[member_id] = {
			"equipment": context.equipment_for(member_id).to_dictionary(),
			"activation": _activation_document(activation),
			"sources": _source_document(party.member_by_id(member_id).modifier_sources),
			"base": base_snapshot,
			"base_revision": base_snapshot.revision,
			"action": action_snapshot,
			"action_revision": action_snapshot.revision,
			"estimate": _combat_estimate_document(ActionCombatEstimateService.estimate(attack, member_id, party, GameCatalog.DAMAGE_TYPES)),
			"health": _health_document(health_by_member[member_id]),
		}
	var item_bytes := _ownership_item_bytes(context.item_state())
	var changed_members: Array[int] = []
	party.stats_changed.connect(func(member_id: int) -> void: changed_members.append(member_id))
	var revision_before := party.stat_revision()
	var transition := context.assign_equipment(1, item_ids[0], &"", GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	_assert(transition.ok(), "distinct-weapon member-one transition succeeds")
	_assert(changed_members == [1], "distinct-weapon transition signals only member one")
	_assert(party.stat_revision() == revision_before + 1, "distinct-weapon transition advances one shared revision")
	_assert(_ownership_item_bytes(context.item_state()) == item_bytes, "distinct-weapon transition preserves every immutable item byte")
	for member_id: int in range(2, 25):
		var record := records[member_id] as Dictionary
		var activation := context.equipment_activation(member_id)
		var action_tags := DamageResolver.action_tags_for(attack, activation.weapon_snapshot())
		var base_snapshot := party.stats_for(member_id)
		var action_snapshot := party.stats_for_action(member_id, action_tags)
		_assert(context.equipment_for(member_id).to_dictionary() == record["equipment"], "distinct-weapon transition preserves member %d ownership" % member_id)
		_assert(_activation_document(activation) == record["activation"], "distinct-weapon transition preserves member %d activation" % member_id)
		_assert(_source_document(party.member_by_id(member_id).modifier_sources) == record["sources"], "distinct-weapon transition preserves member %d sources" % member_id)
		_assert(is_same(base_snapshot, record["base"]) and base_snapshot.revision == int(record["base_revision"]), "distinct-weapon transition preserves member %d base cache identity/revision" % member_id)
		_assert(is_same(action_snapshot, record["action"]) and action_snapshot.revision == int(record["action_revision"]), "distinct-weapon transition preserves member %d action cache identity/revision" % member_id)
		_assert(_combat_estimate_document(ActionCombatEstimateService.estimate(attack, member_id, party, GameCatalog.DAMAGE_TYPES)) == record["estimate"], "distinct-weapon transition preserves member %d estimate" % member_id)
		_assert(_health_document(health_by_member[member_id]) == record["health"], "distinct-weapon transition preserves member %d health" % member_id)

	var health_before: Dictionary = {}
	for member_id: int in range(1, 25):
		health_before[member_id] = _health_document(health_by_member[member_id])
	var attacker_activation := context.equipment_activation(2)
	var attacker_stats := party.stats_for_action(2, DamageResolver.action_tags_for(attack, attacker_activation.weapon_snapshot()))
	var attacker := CombatantAdapter.new(null, &"party:2", 1, health_by_member[2], attacker_stats, true, Callable(), attacker_activation.weapon_snapshot())
	var target := CombatantAdapter.new(null, &"party:3", 2, health_by_member[3], party.stats_for(3))
	var packet := DamageResolver.prepare(attack, attacker, CombatRng.new(2601, [0.99, 0.5]), GameCatalog.DAMAGE_TYPES)
	var damage := DamageResolver.resolve(packet, target, CombatRng.new(2602, [0.99, 0.99]), GameCatalog.DAMAGE_TYPES)
	_assert(packet.valid and damage.valid and damage.actual_health_removed > 0.0, "distinct-weapon member two attacks member three with its weapon range")
	for member_id: int in range(1, 25):
		var health_changed: bool = _health_document(health_by_member[member_id]) != health_before[member_id]
		_assert(health_changed == (member_id == 3), "distinct-weapon attack isolates health at member %d" % member_id)
	if changed_members == [1] and distinct.size() == 24:
		print("PROGRESSION_24_MEMBER_WEAPON_ISOLATION_PASS members=24 untouched=23 distinct_main_hands=24")
	for actor: Node3D in actors:
		actor.free()
	party.free()


func _activation_document(activation: EquipmentActivationResult) -> Dictionary:
	var weapon := activation.weapon_snapshot() if activation != null else null
	var components: Array[Dictionary] = []
	if weapon != null:
		for component: ItemBaseDamageComponent in weapon.components:
			components.append(component.to_dictionary())
	return {
		"error": activation.error if activation != null else "missing",
		"active": activation.active_item_ids if activation != null else [],
		"weapon": {} if weapon == null else {"member_id": weapon.member_id, "item_id": weapon.item_id, "base_id": String(weapon.base_id), "revision": weapon.revision, "components": components},
	}


func _source_document(sources: Array[StatModifierSource]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for source: StatModifierSource in sources:
		var modifiers: Array[Dictionary] = []
		for modifier: StatModifier in source.modifiers:
			modifiers.append({"stat_id": String(modifier.stat_id), "operation": modifier.operation, "value": modifier.value, "source_id": String(modifier.source_id), "required_tags": modifier.required_tags})
		result.append({"id": String(source.id), "type": String(source.source_type), "label": source.label, "owner": source.owner_member_id, "modifiers": modifiers})
	return result


func _combat_estimate_document(estimate: ActionCombatEstimate) -> Dictionary:
	return {
		"available": estimate.available, "reason": estimate.unavailable_reason,
		"normal_hit": estimate.normal_hit, "critical_hit": estimate.critical_hit,
		"average_hit": estimate.average_hit, "aps": estimate.attacks_per_second,
		"dps": estimate.estimated_dps, "components": estimate.component_rows.duplicate(true),
	}


func _health_document(health: HealthComponent) -> Vector2:
	return Vector2(health.current_health, health.max_health)


func _ownership_item_bytes(state: ItemOwnershipState) -> Dictionary:
	var result: Dictionary = {}
	var registry := state.registry()
	for item_id: String in registry.ids():
		result[item_id] = ItemInstanceCodec.encode(registry.item(item_id))
	return result


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
