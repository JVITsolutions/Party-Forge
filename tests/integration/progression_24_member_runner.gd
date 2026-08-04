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


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
