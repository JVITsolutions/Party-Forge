extends SceneTree

const PANEL_SCENE := preload("res://scenes/ui/level_up_panel.tscn")
const SCRIPT_ERROR_CAPTURE := preload("res://tests/support/test_script_error_capture.gd")
const ERROR_CAPTURE := preload("res://tests/support/test_error_capture.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var probe := PANEL_SCENE.instantiate() as LevelUpPanel
	var typed_contract := (
		probe.has_signal(&"application_requested")
		and probe.has_signal(&"recovery_requested")
		and probe.has_method(&"accept_application")
		and probe.has_method(&"reject_application")
		and probe.get_node_or_null("Frame/Content/Pending") != null
	)
	probe.free()
	if not typed_contract:
		_failures.append("Unified direct, recipient, recruit, and pending flow is not implemented")
		for failure: String in _failures:
			push_error("LEVEL_UP_COMMIT_FLOW_FAILURE: %s" % failure)
		print("LEVEL_UP_COMMIT_FLOW_SUMMARY: FAIL (%d failures)" % _failures.size())
		quit(1)
		return
	await _exercise_panel_routes()
	await _exercise_main_result_and_queued_flow()
	for failure: String in _failures:
		push_error("LEVEL_UP_COMMIT_FLOW_FAILURE: %s" % failure)
	print("LEVEL_UP_COMMIT_FLOW_SUMMARY: %s (%d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _exercise_panel_routes() -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.configure_capacity(PartyCapacityPolicy.new(24))
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	party.members[0].character_name = "Member 1"
	for member_id: int in range(2, 25):
		party.recruit(catalog.class_by_id(&"fighter"))
		party.members[-1].character_name = "Member %d" % member_id
	var panel := PANEL_SCENE.instantiate() as LevelUpPanel
	root.add_child(panel)
	panel.configure(catalog, UpgradeApplicationService.new(), func(_member_id: int) -> Vector2: return Vector2(100.0, 100.0))
	panel.configure_reduced_motion(true)
	var intents: Array[Dictionary] = []
	panel.application_requested.connect(func(choice: UpgradeChoice, member_id: int) -> void: intents.append({"choice": choice, "member_id": member_id}))

	var direct := UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"damage", "Damage")
	panel.show_choices([direct], party)
	var direct_card := _card(panel)
	direct_card.activated.emit(direct_card.bound_choice_key())
	direct_card.activated.emit(direct_card.bound_choice_key())
	_assert(intents.size() == 1 and intents[0].choice == direct and intents[0].member_id == 0, "direct route emits one exact intent")
	_assert(not (panel.get_node("Frame/Content/Confirmation") as Control).visible, "direct route never opens Confirmation")
	_assert((panel.get_node("Frame/Content/Pending") as Control).visible and "Applying" in (panel.get_node("Frame/Content/Pending/Status") as Label).text, "direct route exposes a named Applying state")
	panel.reject_application("Direct application rejected.")
	_assert((panel.get_node("Frame/Content/ReadableError") as Label).text == "Direct application rejected.", "direct rejection preserves exact reason")
	_assert(direct_card.has_focus(), "direct rejection restores initiating card")

	var targeted := UpgradeChoice.authored(catalog.upgrade_by_id(&"vitality"))
	panel.show_choices([targeted], party)
	var targeted_card := _card(panel)
	targeted_card.activated.emit(targeted_card.bound_choice_key())
	var rows := panel.get_node("Frame/Content/Recipient/Content/RecipientsScroll/Rows") as VBoxContainer
	_assert(rows.get_child_count() == 24, "targeted route keeps all 24 recipients")
	(rows.get_node("Member_24") as Button).pressed.emit()
	_assert("Member 24" in (panel.get_node("Frame/Content/Confirmation/BodyScroll/Body/Recipient") as Label).text, "targeted confirmation retains exact recipient identity")
	_assert("->" in (panel.get_node("Frame/Content/Confirmation/BodyScroll/Body/Effect") as Label).text, "targeted confirmation retains exact before-to-after effect")
	(panel.get_node("Frame/Content/Confirmation/Actions/Cancel") as Button).pressed.emit()
	_assert(targeted_card.has_focus(), "targeted cancel restores initiating card")
	targeted_card.activated.emit(targeted_card.bound_choice_key())
	(rows.get_node("Member_24") as Button).pressed.emit()
	(panel.get_node("Frame/Content/Confirmation/Actions/Confirm") as Button).pressed.emit()
	(panel.get_node("Frame/Content/Confirmation/Actions/Confirm") as Button).pressed.emit()
	_assert(intents.size() == 2 and intents[-1].choice == targeted and intents[-1].member_id == 24, "targeted confirmation emits one exact member-24 intent")
	_assert(targeted_card.has_focus(), "targeted pending moves focus off hidden Confirm to the initiating card")
	panel.reject_application("Target changed.")
	_assert(targeted_card.has_focus() and (panel.get_node("Frame/Content/ReadableError") as Label).text == "Target changed.", "targeted failure restores exact card and reason")

	var recruit := UpgradeChoice.new(UpgradeChoice.Kind.RECRUIT, &"ranger", "Recruit Ranger")
	panel.show_choices([recruit], party)
	# Capacity is currently full, so use a fresh bounded party for the valid recruit route.
	var recruit_party := PartyManager.new()
	recruit_party.configure_capacity(PartyCapacityPolicy.new(24))
	recruit_party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	panel.show_choices([recruit], recruit_party)
	var recruit_card := _card(panel)
	recruit_card.activated.emit(recruit_card.bound_choice_key())
	_assert((panel.get_node("Frame/Content/Confirmation") as Control).visible and "Ranger" in (panel.get_node("Frame/Content/Confirmation/BodyScroll/Body/Effect") as Label).text, "recruit route presents class-specific context confirmation")
	(panel.get_node("Frame/Content/Confirmation/Actions/Cancel") as Button).pressed.emit()
	_assert(recruit_card.has_focus(), "recruit cancel restores initiating card")
	recruit_card.activated.emit(recruit_card.bound_choice_key())
	(panel.get_node("Frame/Content/Confirmation/Actions/Confirm") as Button).pressed.emit()
	_assert(intents.size() == 3 and intents[-1].choice == recruit and intents[-1].member_id == 0, "recruit confirmation emits one exact context intent")
	_assert(recruit_card.has_focus(), "recruit pending moves focus off hidden Confirm to the initiating card")
	panel.reject_application("Recruit changed.")

	var vitality := catalog.upgrade_by_id(&"vitality") as UpgradeDefinition
	var one_member := PartyManager.new()
	one_member.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	panel.show_choices([UpgradeChoice.authored(vitality)], one_member)
	for _rank: int in vitality.max_rank:
		UpgradeApplicationService.apply(vitality.id, catalog, one_member, one_member.members[0].member_id)
	var stale_card := _card(panel)
	stale_card.activated.emit(stale_card.bound_choice_key())
	var picker := panel.get_node("Frame/Content/Recipient") as UpgradeRecipientPicker
	_assert((picker.get_node("Content/Cancel") as Button).has_focus(), "no eligible recipient defaults focus to Cancel")
	_assert(not (picker.get_node("Content/EmptyReason") as Label).text.is_empty(), "no eligible recipient states a reason")

	var retries := [0]
	panel.recovery_requested.connect(func() -> void: retries[0] += 1)
	panel.show_choices([], one_member, {&"__empty__": "No eligible upgrades remain."})
	_assert(_visible_card_count(panel) == 0, "zero offers render no phantom disabled Card1")
	var retry := panel.get_node("Frame/Content/Offer/RetryOffers") as Button
	_assert(retry.visible and retry.has_focus(), "zero offers expose default-focused recovery")
	retry.pressed.emit()
	_assert(retries[0] == 1, "zero-offer recovery emits once")

	panel.free()
	party.free()
	recruit_party.free()
	one_member.free()
	await process_frame


func _exercise_main_result_and_queued_flow() -> void:
	var profile_root := "user://tests/living_forge_combat_loop/level_up_commit_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	ProfileTestSupport.remove_tree(profile_root)
	var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate()
	main.set("profile_root", profile_root)
	root.add_child(main)
	main.call(&"_ready")
	(main.get("profile_manager") as ProfileManager).create_profile("Task 6")
	_assert(main.call("select_leader_class", &"fighter"), "main fixture starts a run")
	var panel := main.get_node("HUD/LevelUpPanel") as LevelUpPanel
	var experience := main.get_node("ExperienceSystem") as ExperienceSystem
	var game_run := main.get_node("GameRun") as GameRun
	var party := main.get_node("PartyManager") as PartyManager
	panel.configure_reduced_motion(true)
	_queue_levels(experience, 2)
	game_run.begin_level_up()
	var gameplay_focus := Button.new()
	gameplay_focus.name = "GameplayFocus"
	main.get_node("HUD").add_child(gameplay_focus)
	gameplay_focus.grab_focus()
	var direct := UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"damage", "Damage")
	panel.show_choices([direct], party, {}, 2)
	var card := _card(panel)
	card.activated.emit(card.bound_choice_key())
	_assert(experience.pending_levels == 1, "accepted direct request consumes exactly one pending level")
	_assert(game_run.current_state() == RunStateMachine.State.LEVEL_UP and paused, "queued accepted level remains paused")
	_assert(panel.visible, "queued accepted level keeps the modal visible without battlefield flash")
	for _frame: int in 3:
		await process_frame
		_assert(paused and panel.visible, "queued transition remains paused and visible on frame %d" % _frame)

	# Present a deterministic final direct offer through the same unified Main seam.
	main.set("level_refresh_scheduled", false)
	var final_direct := UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"move_speed", "Move Speed")
	panel.show_choices([final_direct], party, {}, 1)
	card = _card(panel)
	card.activated.emit(card.bound_choice_key())
	await process_frame
	_assert(experience.pending_levels == 0, "final accepted request consumes only the final pending level")
	_assert(game_run.current_state() == RunStateMachine.State.RUNNING and not paused, "final accepted request resumes gameplay")
	_assert(not panel.visible, "final accepted request closes the modal")
	_assert(
		root.gui_get_focus_owner() == gameplay_focus,
		"final close restores deterministic gameplay focus (owner=%s expected=%s stored=%s)" % [
			root.gui_get_focus_owner(),
			gameplay_focus,
			panel.get("_gameplay_return_focus"),
		]
	)
	var accepted_move_speed_rank := party.party_stat_rank(&"move_speed")
	card.activated.emit(card.bound_choice_key())
	_assert(party.party_stat_rank(&"move_speed") == accepted_move_speed_rank, "hidden stale final card activation cannot apply a second mutation")
	_assert(experience.pending_levels == 0 and game_run.current_state() == RunStateMachine.State.RUNNING, "hidden stale final card activation cannot invent or consume a level")
	panel.application_requested.emit(final_direct, 0)
	_assert(party.party_stat_rank(&"move_speed") == accepted_move_speed_rank, "Main independently rejects a stale direct intent after final success")
	_assert(experience.pending_levels == 0 and game_run.current_state() == RunStateMachine.State.RUNNING, "Main stale-intent rejection preserves zero pending levels and running state")

	await _exercise_freed_focus_and_frost_recruitment(main, panel, experience, game_run, party)

	main.free()
	paused = false
	ProfileTestSupport.remove_tree(profile_root)
	await process_frame


func _exercise_freed_focus_and_frost_recruitment(
	main: Node,
	panel: LevelUpPanel,
	experience: ExperienceSystem,
	game_run: GameRun,
	party: PartyManager,
) -> void:
	_queue_levels(experience, 1)
	game_run.begin_level_up()
	var freed_focus := Button.new()
	freed_focus.name = "FreedGameplayFocus"
	main.get_node("HUD").add_child(freed_focus)
	freed_focus.grab_focus()
	var direct := UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"damage", "Damage")
	panel.show_choices([direct], party)
	var card := _card(panel)
	freed_focus.free()
	var script_errors := SCRIPT_ERROR_CAPTURE.new()
	OS.add_logger(script_errors)
	card.activated.emit(card.bound_choice_key())
	await process_frame
	OS.remove_logger(script_errors)
	_assert(
		script_errors.drain_after_detach().is_empty(),
		"closing a final level-up after its gameplay focus was freed produces no script error",
	)
	_assert(game_run.current_state() == RunStateMachine.State.RUNNING and not panel.visible, "freed return focus does not block the accepted level-up")

	_queue_levels(experience, 1)
	game_run.begin_level_up()
	var gameplay_focus := Button.new()
	gameplay_focus.name = "FrostRecruitGameplayFocus"
	main.get_node("HUD").add_child(gameplay_focus)
	gameplay_focus.grab_focus()
	var frost_recruit := UpgradeChoice.new(UpgradeChoice.Kind.RECRUIT, &"frost_mage", "Recruit Frost Mage")
	panel.show_choices([frost_recruit], party)
	card = _card(panel)
	var errors := ERROR_CAPTURE.new()
	OS.add_logger(errors)
	card.activated.emit(card.bound_choice_key())
	(panel.get_node("Frame/Content/Confirmation/Actions/Confirm") as Button).pressed.emit()
	await process_frame
	OS.remove_logger(errors)
	var captured := errors.drain_after_detach()
	_assert(not _contains_message(captured, "COMBAT_HUD_UNAVAILABLE"), "Frost Mage recruitment never publishes a transient HUD-unavailable state: %s" % captured)
	_assert(party.members.size() == 2 and party.members[1].class_definition.id == &"frost_mage", "real Main recruitment commits Frost Mage")
	var context := main.get("active_run_context") as PlayerRunContext
	var frost_actor := context.actor_for(party.members[1].member_id) if context != null else null
	var frost_health := frost_actor.get_node_or_null("HealthComponent") as HealthComponent if frost_actor != null else null
	_assert(frost_actor != null and is_instance_valid(frost_actor), "Frost Mage recruitment completes actor binding")
	_assert(frost_health != null and frost_health.max_health > 0.0, "Frost Mage recruitment completes health binding")
	_assert(root.gui_get_focus_owner() == gameplay_focus, "Frost Mage recruitment restores valid gameplay focus")
	_assert(game_run.current_state() == RunStateMachine.State.RUNNING and not panel.visible, "Frost Mage recruitment closes the final level-up and resumes gameplay")


func _contains_message(messages: PackedStringArray, marker: String) -> bool:
	for message: String in messages:
		if marker in message:
			return true
	return false


func _queue_levels(experience: ExperienceSystem, count: int) -> void:
	var amount := 0
	for offset: int in count:
		amount += experience.tuning.requirement_for_level(experience.level + offset)
	experience.add_experience(amount)


func _card(panel: LevelUpPanel) -> UpgradeCard:
	return panel.get_node("Frame/Content/Offer/CardsScroll/Cards").get_child(0) as UpgradeCard


func _visible_card_count(panel: LevelUpPanel) -> int:
	var count := 0
	for child: Node in panel.get_node("Frame/Content/Offer/CardsScroll/Cards").get_children():
		if child is Control and child.visible:
			count += 1
	return count


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
