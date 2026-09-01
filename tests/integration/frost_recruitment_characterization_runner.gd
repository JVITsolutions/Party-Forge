extends SceneTree

const SCRIPT_ERROR_CAPTURE := preload("res://tests/support/test_script_error_capture.gd")
const ERROR_CAPTURE := preload("res://tests/support/test_error_capture.gd")
const SHORT_PARTY_PROBE_ENV := "PF_FROST_CHARACTERIZATION_FORCE_SHORT_PARTY"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _exercise_recruitment(&"ranger", "Ranger")
	await _exercise_recruitment(&"frost_mage", "Frost Mage")
	for failure: String in _failures:
		push_error("FROST_RECRUITMENT_CHARACTERIZATION_FAILURE: %s" % failure)
	print("FROST_RECRUITMENT_CHARACTERIZATION_SUMMARY: %s (%d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _exercise_recruitment(class_id: StringName, display_name: String) -> void:
	var profile_root := "user://tests/frost_recruitment_characterization/%s-%d-%d" % [class_id, OS.get_process_id(), Time.get_ticks_usec()]
	ProfileTestSupport.remove_tree(profile_root)
	var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate()
	main.set("profile_root", profile_root)
	root.add_child(main)
	main.call(&"_ready")
	var manager := main.get("profile_manager") as ProfileManager
	_assert(manager.create_profile("%s Recruitment" % display_name).ok(), "%s fixture creates a profile" % display_name)
	_assert(main.call("select_leader_class", &"fighter"), "%s fixture starts a Fighter-led run" % display_name)
	var panel := main.get_node("HUD/LevelUpPanel") as LevelUpPanel
	var experience := main.get_node("ExperienceSystem") as ExperienceSystem
	var game_run := main.get_node("GameRun") as GameRun
	var party := main.get_node("PartyManager") as PartyManager
	panel.configure_reduced_motion(true)
	experience.add_experience(experience.tuning.requirement_for_level(experience.level))
	game_run.begin_level_up()
	var gameplay_focus := Button.new()
	gameplay_focus.name = "%sRecruitGameplayFocus" % String(class_id).to_pascal_case()
	main.get_node("HUD").add_child(gameplay_focus)
	gameplay_focus.grab_focus()
	var recruit := UpgradeChoice.new(UpgradeChoice.Kind.RECRUIT, class_id, "Recruit %s" % display_name)
	panel.show_choices([recruit], party)
	var card := panel.get_node("Frame/Content/Offer/CardsScroll/Cards").get_child(0) as UpgradeCard
	var script_errors := SCRIPT_ERROR_CAPTURE.new()
	var errors := ERROR_CAPTURE.new()
	OS.add_logger(script_errors)
	OS.add_logger(errors)
	card.activated.emit(card.bound_choice_key())
	(panel.get_node("Frame/Content/Confirmation/Actions/Confirm") as Button).pressed.emit()
	await process_frame
	OS.remove_logger(errors)
	OS.remove_logger(script_errors)
	var captured_errors := errors.drain_after_detach()
	var captured_script_errors := script_errors.drain_after_detach()
	_assert(captured_script_errors.is_empty(), "%s recruitment emits no script error: %s" % [display_name, captured_script_errors])
	_assert(captured_errors.is_empty(), "%s recruitment emits no engine error: %s" % [display_name, captured_errors])
	_assert(not _contains_message(captured_errors, "COMBAT_HUD_UNAVAILABLE"), "%s recruitment emits no transient HUD-unavailable state: %s" % [display_name, captured_errors])
	if class_id == &"frost_mage" and OS.get_environment(SHORT_PARTY_PROBE_ENV) == "1":
		party.members.resize(1)
		print("FROST_RECRUITMENT_CHARACTERIZATION_PROBE: SHORT_PARTY")
	var recruited_member: PartyMemberState = party.members[1] if party.members.size() >= 2 else null
	_assert(party.members.size() == 2 and recruited_member != null and recruited_member.class_definition.id == class_id, "%s recruitment commits the exact class" % display_name)
	var context := main.get("active_run_context") as PlayerRunContext
	var actor := context.actor_for(recruited_member.member_id) if context != null and recruited_member != null else null
	var health := actor.get_node_or_null("HealthComponent") as HealthComponent if actor != null else null
	if recruited_member != null:
		_assert(actor != null and is_instance_valid(actor), "%s recruitment completes actor binding" % display_name)
		_assert(health != null and health.max_health > 0.0, "%s recruitment completes health binding" % display_name)
	_assert(root.gui_get_focus_owner() == gameplay_focus, "%s recruitment restores gameplay focus" % display_name)
	_assert(game_run.current_state() == RunStateMachine.State.RUNNING and not panel.visible, "%s recruitment closes level-up and resumes gameplay" % display_name)
	main.free()
	paused = false
	ProfileTestSupport.remove_tree(profile_root)
	await process_frame


func _contains_message(messages: PackedStringArray, marker: String) -> bool:
	for message: String in messages:
		if marker in message:
			return true
	return false


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
