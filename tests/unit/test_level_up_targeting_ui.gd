extends RefCounted

const REVEALING := 0
const CHOOSING := 1
const CHOOSING_RECIPIENT := 2
const CONFIRMING := 3
const PENDING := 4


func run() -> Array[String]:
	var failures: Array[String] = []
	var probe := (load("res://scenes/ui/level_up_panel.tscn") as PackedScene).instantiate() as LevelUpPanel
	var typed_api := (
		probe.has_signal(&"application_requested")
		and probe.has_signal(&"recovery_requested")
		and probe.has_method(&"accept_application")
		and probe.has_method(&"reject_application")
		and probe.has_method(&"configure_visual_settings")
		and probe.get_node_or_null("Frame/Content/Offer/CardsScroll/Cards") != null
		and probe.get_node_or_null("Frame/Content/Confirmation") != null
		and probe.get_node_or_null("Frame/Content/ReadableError") != null
	)
	probe.free()
	TestAssertions.truthy(typed_api, "LevelUpPanel exposes the unified Living Forge state-machine contract", failures)
	if not typed_api:
		return failures
	_test_direct_route_pending_failure_and_exact_focus(failures)
	_test_targeted_confirmation_uses_exact_member_and_preview(failures)
	_test_recruit_context_confirmation_and_cancel(failures)
	_test_no_eligible_recipient_defaults_to_cancel(failures)
	_test_empty_offer_has_reason_and_recovery(failures)
	_test_pre_layout_reveal_skip_is_consumed_once(failures)
	_test_compact_cards_keep_semantic_content(failures)
	_test_tooltip_mouse_keyboard_controller_parity(failures)
	_test_shared_visual_settings(failures)
	return failures


func _test_direct_route_pending_failure_and_exact_focus(failures: Array[String]) -> void:
	var fixture := _fixture()
	var panel: LevelUpPanel = fixture.panel
	var party: PartyManager = fixture.party
	var direct := UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"damage", "Damage")
	var targeted := UpgradeChoice.authored(fixture.catalog.upgrade_by_id(&"vitality"))
	panel.show_choices([direct, targeted], party)
	var first := _card(panel, 0)
	var intents: Array[Dictionary] = []
	panel.application_requested.connect(func(choice: UpgradeChoice, member_id: int) -> void:
		intents.append({"choice": choice, "member_id": member_id})
	)

	first.activated.emit(first.bound_choice_key())
	first.activated.emit(first.bound_choice_key())
	TestAssertions.equal(intents.size(), 1, "direct activation emits exactly one application intent", failures)
	if not intents.is_empty():
		TestAssertions.equal(intents[0].choice, direct, "direct intent retains the exact UpgradeChoice object", failures)
		TestAssertions.equal(intents[0].member_id, 0, "direct intent invents no recipient", failures)
	TestAssertions.equal(panel.get("_state"), PENDING, "direct activation enters PENDING", failures)
	TestAssertions.truthy(not (panel.get_node("Frame/Content/Confirmation") as Control).visible, "direct activation skips confirmation", failures)

	panel.reject_application("Selection is no longer available.")
	TestAssertions.equal(panel.get("_state"), CHOOSING, "failure returns to CHOOSING", failures)
	TestAssertions.equal((panel.get_node("Frame/Content/ReadableError") as Label).text, "Selection is no longer available.", "failure preserves the exact readable reason", failures)
	TestAssertions.equal(panel.get("_initial_focus_card"), first, "failure restores the exact initiating card", failures)
	_cleanup(fixture)


func _test_targeted_confirmation_uses_exact_member_and_preview(failures: Array[String]) -> void:
	var fixture := _fixture(24)
	var panel: LevelUpPanel = fixture.panel
	var party: PartyManager = fixture.party
	var targeted := UpgradeChoice.authored(fixture.catalog.upgrade_by_id(&"vitality"))
	panel.show_choices([targeted], party)
	var card := _card(panel, 0)
	card.activated.emit(card.bound_choice_key())
	TestAssertions.equal(panel.get("_state"), CHOOSING_RECIPIENT, "targeted activation enters CHOOSING_RECIPIENT", failures)
	var picker := panel.get_node("Frame/Content/Recipient") as UpgradeRecipientPicker
	var rows := picker.get_node("Content/RecipientsScroll/Rows") as VBoxContainer
	TestAssertions.equal(rows.get_child_count(), 24, "recipient picker retains all 24 ordered party members", failures)
	var member_24 := rows.get_node("Member_24") as Button
	member_24.pressed.emit()
	TestAssertions.equal(panel.get("_state"), CONFIRMING, "recipient choice enters CONFIRMING", failures)
	TestAssertions.truthy((panel.get_node("Frame/Content/Confirmation") as Control).visible, "targeted confirmation is visible", failures)
	var exact_effect := (panel.get_node("Frame/Content/Confirmation/BodyScroll/Body/Effect") as Label).text
	TestAssertions.truthy("->" in exact_effect, "targeted confirmation shows exact before-to-after preview", failures)
	TestAssertions.truthy("Member 24" in (panel.get_node("Frame/Content/Confirmation/BodyScroll/Body/Recipient") as Label).text, "confirmation names the exact recipient", failures)

	(panel.get_node("Frame/Content/Confirmation/Actions/Cancel") as Button).pressed.emit()
	TestAssertions.equal(panel.get("_state"), CHOOSING, "confirmation cancel returns to CHOOSING", failures)
	TestAssertions.equal(panel.get("_initial_focus_card"), card, "confirmation cancel restores initiating card", failures)

	card.activated.emit(card.bound_choice_key())
	(rows.get_node("Member_24") as Button).pressed.emit()
	var intents: Array[Dictionary] = []
	panel.application_requested.connect(func(choice: UpgradeChoice, member_id: int) -> void: intents.append({"choice": choice, "member_id": member_id}))
	(panel.get_node("Frame/Content/Confirmation/Actions/Confirm") as Button).pressed.emit()
	(panel.get_node("Frame/Content/Confirmation/Actions/Confirm") as Button).pressed.emit()
	TestAssertions.equal(intents.size(), 1, "targeted confirmation emits once while pending", failures)
	if not intents.is_empty():
		TestAssertions.equal(intents[0].choice, targeted, "targeted intent retains exact UpgradeChoice", failures)
		TestAssertions.equal(intents[0].member_id, 24, "targeted intent retains stable member ID 24", failures)
	_cleanup(fixture)


func _test_recruit_context_confirmation_and_cancel(failures: Array[String]) -> void:
	var fixture := _fixture()
	var panel: LevelUpPanel = fixture.panel
	var recruit := UpgradeChoice.new(UpgradeChoice.Kind.RECRUIT, &"ranger", "Recruit Ranger")
	panel.show_choices([recruit], fixture.party)
	var card := _card(panel, 0)
	card.activated.emit(card.bound_choice_key())
	TestAssertions.equal(panel.get("_state"), CONFIRMING, "recruit enters context confirmation directly", failures)
	TestAssertions.truthy("Ranger" in (panel.get_node("Frame/Content/Confirmation/BodyScroll/Body/Effect") as Label).text, "recruit confirmation retains authoritative context", failures)
	(panel.get_node("Frame/Content/Confirmation/Actions/Cancel") as Button).pressed.emit()
	TestAssertions.equal(panel.get("_state"), CHOOSING, "recruit cancel returns to CHOOSING", failures)
	TestAssertions.equal(panel.get("_initial_focus_card"), card, "recruit cancel restores exact initiating card", failures)
	_cleanup(fixture)


func _test_no_eligible_recipient_defaults_to_cancel(failures: Array[String]) -> void:
	var fixture := _fixture()
	var panel: LevelUpPanel = fixture.panel
	var vitality := fixture.catalog.upgrade_by_id(&"vitality") as UpgradeDefinition
	var targeted := UpgradeChoice.authored(vitality)
	panel.show_choices([targeted], fixture.party)
	for _rank: int in vitality.max_rank:
		UpgradeApplicationService.apply(vitality.id, fixture.catalog, fixture.party, 1)
	var card := _card(panel, 0)
	card.activated.emit(card.bound_choice_key())
	var picker := panel.get_node("Frame/Content/Recipient") as UpgradeRecipientPicker
	var cancel := picker.get_node("Content/Cancel") as Button
	TestAssertions.equal(panel.get("_state"), CHOOSING_RECIPIENT, "stale no-eligible choice still presents a recoverable recipient state", failures)
	TestAssertions.equal(cancel.focus_mode, Control.FOCUS_ALL, "no eligible recipient leaves Cancel as the only focusable recovery action", failures)
	TestAssertions.equal(picker.call(&"_first_enabled_button"), null, "no eligible recipient exposes no false eligible focus target", failures)
	TestAssertions.truthy(not (picker.get_node("Content/EmptyReason") as Label).text.is_empty(), "no eligible recipient shows a readable reason", failures)
	_cleanup(fixture)


func _test_empty_offer_has_reason_and_recovery(failures: Array[String]) -> void:
	var fixture := _fixture()
	var panel: LevelUpPanel = fixture.panel
	var retries := [0]
	panel.recovery_requested.connect(func() -> void: retries[0] += 1)
	panel.show_choices([], fixture.party, {&"__empty__": "No eligible upgrades remain."})
	var error := panel.get_node("Frame/Content/ReadableError") as Label
	var recovery := panel.get_node("Frame/Content/Offer/RetryOffers") as Button
	TestAssertions.equal(error.text, "No eligible upgrades remain.", "empty offer shows the authoritative reason", failures)
	TestAssertions.truthy(error.visible and recovery.visible, "empty offer exposes recovery instead of an inert panel", failures)
	panel.call(&"_on_recovery_pressed")
	TestAssertions.equal(retries[0], 1, "empty-offer recovery emits once", failures)
	_cleanup(fixture)


func _test_pre_layout_reveal_skip_is_consumed_once(failures: Array[String]) -> void:
	var fixture := _fixture()
	var panel: LevelUpPanel = fixture.panel
	panel.configure_reduced_motion(false)
	panel.show_choices([UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"damage", "Damage")], fixture.party)
	var skip := InputEventAction.new()
	skip.action = &"ui_cancel"
	skip.pressed = true
	panel.call(&"_unhandled_input", skip)
	(panel.get_node("Frame/Content/Offer/CardsScroll/Cards") as HBoxContainer).notification(Container.NOTIFICATION_SORT_CHILDREN)
	TestAssertions.equal(panel.get("_state"), CHOOSING, "a pre-layout reveal skip resolves the reveal once layout becomes ready", failures)
	TestAssertions.truthy(not (panel.get_node("RevealController") as LevelUpRevealController).is_revealing(), "pre-layout skip cannot leave a delayed reveal active", failures)
	_cleanup(fixture)


func _test_compact_cards_keep_semantic_content(failures: Array[String]) -> void:
	var fixture := _fixture()
	var panel: LevelUpPanel = fixture.panel
	var choices: Array[UpgradeChoice] = [
		UpgradeChoice.authored(fixture.catalog.upgrade_by_id(&"vitality")),
		UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"damage", "Damage"),
	]
	panel.show_choices(choices, fixture.party)
	panel.call(&"_apply_card_face_density", 1280.0)
	for card_node: Node in panel.get_node("Frame/Content/Offer/CardsScroll/Cards").get_children():
		if not (card_node is UpgradeCard) or not card_node.visible:
			continue
		for label_name: String in ["Eligibility", "Scope", "Rank", "Summary"]:
			var semantic := card_node.find_child(label_name, true, false) as Control
			TestAssertions.truthy(semantic != null and semantic.visible, "compact card retains semantic %s" % label_name, failures)
	_cleanup(fixture)


func _test_tooltip_mouse_keyboard_controller_parity(failures: Array[String]) -> void:
	var fixture := _fixture()
	var panel: LevelUpPanel = fixture.panel
	var choice := UpgradeChoice.authored(fixture.catalog.upgrade_by_id(&"vitality"))
	panel.show_choices([choice], fixture.party)
	var card := _card(panel, 0)
	var tooltip := panel.get_node("TooltipPanel") as UpgradeTooltipPanel
	card.focus_exited.emit()
	card.mouse_exited.emit()
	panel.call(&"_on_card_detail_requested", card.bound_choice_key(), card)
	TestAssertions.truthy(tooltip.visible, "mouse hover opens offer detail", failures)
	panel.call(&"_on_card_detail_dismissed", card.bound_choice_key())
	TestAssertions.truthy(not tooltip.visible, "mouse exit dismisses offer detail", failures)
	panel.call(&"_on_card_detail_requested", card.bound_choice_key(), card)
	TestAssertions.truthy(tooltip.visible, "keyboard/controller focus opens the same offer detail", failures)
	TestAssertions.equal((tooltip.get_node("Content/Header/Title") as Label).text, "Vitality", "all input modes share exact tooltip content", failures)
	_cleanup(fixture)


func _test_shared_visual_settings(failures: Array[String]) -> void:
	var fixture := _fixture()
	var settings := PartyForgeSettings.new()
	settings.high_contrast = true
	settings.ui_scale_percent = 150
	settings.text_scale_percent = 150
	settings.reduced_motion = true
	fixture.panel.configure_visual_settings(settings)
	TestAssertions.equal(fixture.panel.theme, LivingForgeThemeCatalog.resolve(true, 150, 150), "level-up panel reuses shared Living Forge theme catalog", failures)
	TestAssertions.truthy(bool(fixture.panel.get("_reduced_motion")), "visual settings carry reduced-motion truth", failures)
	_cleanup(fixture)


func _fixture(party_size: int = 1) -> Dictionary:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.configure_capacity(PartyCapacityPolicy.new(24))
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	party.members[0].character_name = "Member 1"
	for member_id: int in range(2, party_size + 1):
		party.recruit(catalog.class_by_id(&"fighter"))
		party.members[-1].character_name = "Member %d" % member_id
	var panel := (load("res://scenes/ui/level_up_panel.tscn") as PackedScene).instantiate() as LevelUpPanel
	(Engine.get_main_loop() as SceneTree).root.add_child(panel)
	panel.configure(catalog, UpgradeApplicationService.new(), func(_member_id: int) -> Vector2: return Vector2(100.0, 100.0))
	panel.configure_reduced_motion(true)
	return {"catalog": catalog, "party": party, "panel": panel}


func _card(panel: LevelUpPanel, index: int) -> UpgradeCard:
	return panel.get_node("Frame/Content/Offer/CardsScroll/Cards").get_child(index) as UpgradeCard


func _cleanup(fixture: Dictionary) -> void:
	(fixture.panel as LevelUpPanel).free()
	(fixture.party as PartyManager).free()
