extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_exact_offer_target_cancel_and_confirmation(failures)
	_test_dynamic_card_count_and_focus(failures)
	_test_duplicate_class_recipients_keep_identity(failures)
	_test_non_personal_confirmation_uses_zero(failures)
	_test_production_card_tooltip_composition(failures)
	_test_tooltip_forced_lifecycle_cleanup(failures)
	_test_pending_level_indicator(failures)
	_test_reveal_gating_skip_focus_and_lifecycle(failures)
	_test_pending_label_motion_policy(failures)
	_test_run_snapshots_reduced_motion_for_reveals(failures)
	return failures

func _test_pending_level_indicator(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var choices: Array[UpgradeChoice] = [
		UpgradeChoice.authored(catalog.upgrade_by_id(&"vanguard_wall")),
		UpgradeChoice.authored(catalog.upgrade_by_id(&"vitality")),
		UpgradeChoice.authored(catalog.upgrade_by_id(&"precision")),
	]
	var panel := _attached_panel()
	panel.show_choices(choices, party, {}, 3)
	var pending_label := panel.get_node_or_null("ContentPanel/OfferView/Content/PendingLevels") as Label
	TestAssertions.truthy(pending_label != null, "offer owns a pending-level indicator", failures)
	if pending_label == null:
		panel.free()
		party.free()
		return
	TestAssertions.truthy(pending_label.visible, "pending-level indicator is visible with queued upgrades", failures)
	TestAssertions.equal(pending_label.text, "3 upgrades ready", "pending-level indicator pluralizes queued upgrades", failures)
	TestAssertions.equal(pending_label.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER, "pending-level indicator is centered", failures)
	TestAssertions.equal(pending_label.get_theme_color("font_color"), Color(1.0, 0.78, 0.18, 1.0), "pending-level indicator uses the gold accent", failures)
	TestAssertions.equal(pending_label.get_theme_font_size("font_size"), 22, "pending-level indicator uses responsive readable type", failures)
	var title := panel.get_node("ContentPanel/OfferView/Content/Title") as Label
	TestAssertions.equal(pending_label.get_index() + 1, title.get_index(), "pending-level indicator sits directly above the title", failures)

	panel.show_choices(choices, party, {}, 1)
	TestAssertions.equal(pending_label.text, "1 upgrade ready", "pending-level indicator uses singular upgrade text", failures)

	panel.complete_selection()
	panel.show_choices(choices, party, {}, 2)
	TestAssertions.equal(pending_label.text, "2 upgrades ready", "next queued offer updates the indicator immediately", failures)
	TestAssertions.equal(panel.find_children("PendingLevels", "Label", true, false).size(), 1, "queued offers reuse one pending-level indicator", failures)
	panel.free()
	party.free()

func _test_reveal_gating_skip_focus_and_lifecycle(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var choices: Array[UpgradeChoice] = [
		UpgradeChoice.authored(catalog.upgrade_by_id(&"vanguard_wall")),
		UpgradeChoice.authored(catalog.upgrade_by_id(&"vitality")),
		UpgradeChoice.authored(catalog.upgrade_by_id(&"precision")),
		UpgradeChoice.authored(catalog.upgrade_by_id(&"tempered_armor")),
		UpgradeChoice.authored(catalog.upgrade_by_id(&"deadeye")),
	]
	var panel := _attached_panel()
	TestAssertions.truthy(panel.has_method(&"configure_reduced_motion"), "panel accepts snapshotted reduced-motion policy", failures)
	if not panel.has_method(&"configure_reduced_motion"):
		_free_panel(panel)
		party.free()
		return
	panel.call(&"configure_reduced_motion", false)
	panel.show_choices(choices, party, {choices[0].key(): "At maximum rank."})
	var controller := panel.get_node_or_null("RevealController")
	TestAssertions.truthy(controller != null, "level-up scene composes reveal controller", failures)
	if controller == null:
		_free_panel(panel)
		party.free()
		return
	var cards := panel.get_node("ContentPanel/OfferView/Content/Cards").get_children()
	TestAssertions.truthy(controller.call(&"is_revealing"), "panel starts animated reveal", failures)
	TestAssertions.equal(panel.get("_initial_focus_card"), null, "panel defers focus during reveal", failures)
	for index: int in choices.size():
		TestAssertions.truthy((cards[index] as UpgradeCard).disabled, "panel gates card %d during reveal" % index, failures)
	panel.call(&"_on_card_activated", choices[1])
	TestAssertions.equal(panel.get("_pending_choice"), null, "direct activation is gated during reveal", failures)

	panel.call(&"_unhandled_input", _action_event(&"ui_accept"))
	TestAssertions.truthy(not controller.call(&"is_revealing"), "ui_accept skips reveal", failures)
	TestAssertions.equal(panel.get("_pending_choice"), null, "skip event cannot also activate a card", failures)
	TestAssertions.equal(panel.get("_initial_focus_card"), cards[1], "resolve focuses first finally enabled card", failures)
	TestAssertions.truthy((cards[0] as UpgradeCard).disabled, "resolve restores supplied disabled reason", failures)
	TestAssertions.truthy(not (cards[1] as UpgradeCard).disabled, "resolve enables eligible card", failures)

	panel.show_choices(choices, party)
	TestAssertions.truthy(controller.call(&"is_revealing"), "next offer starts a fresh reveal", failures)
	panel.call(&"_unhandled_input", _action_event(&"ui_cancel"))
	TestAssertions.truthy(not controller.call(&"is_revealing"), "ui_cancel also skips reveal", failures)
	TestAssertions.equal(panel.get("_pending_choice"), null, "cancel skip does not enter another view", failures)

	panel.show_choices(choices, party)
	panel.complete_selection()
	TestAssertions.truthy(not controller.call(&"is_revealing"), "selection completion resets reveal lifecycle", failures)
	controller.call(&"advance", 2.0)
	TestAssertions.truthy(not panel.visible, "stale controller advance cannot reopen completed panel", failures)
	_free_panel(panel)
	party.free()

func _test_pending_label_motion_policy(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var choices: Array[UpgradeChoice] = [
		UpgradeChoice.authored(catalog.upgrade_by_id(&"vanguard_wall")),
		UpgradeChoice.authored(catalog.upgrade_by_id(&"vitality")),
		UpgradeChoice.authored(catalog.upgrade_by_id(&"precision")),
		UpgradeChoice.authored(catalog.upgrade_by_id(&"tempered_armor")),
		UpgradeChoice.authored(catalog.upgrade_by_id(&"deadeye")),
	]
	var panel := _attached_panel()
	if not panel.has_method(&"configure_reduced_motion"):
		TestAssertions.truthy(false, "pending pulse panel supports reduced motion", failures)
		_free_panel(panel)
		party.free()
		return
	var label := panel.get_node("ContentPanel/OfferView/Content/PendingLevels") as Label
	panel.call(&"configure_reduced_motion", false)
	panel.show_choices(choices, party, {}, 2)
	(panel.get_node("RevealController") as Node).call(&"skip")
	panel.call(&"_process", 0.2)
	var first_alpha := label.modulate.a
	panel.call(&"_process", 0.2)
	var second_alpha := label.modulate.a
	TestAssertions.truthy(first_alpha >= 0.75 and first_alpha <= 1.0, "pending pulse stays within approved alpha range", failures)
	TestAssertions.truthy(second_alpha >= 0.75 and second_alpha <= 1.0 and not is_equal_approx(first_alpha, second_alpha), "pending pulse oscillates after resolve", failures)

	panel.call(&"configure_reduced_motion", true)
	panel.show_choices(choices, party, {}, 2)
	panel.call(&"_process", 0.4)
	TestAssertions.near(label.modulate.a, 1.0, 0.001, "reduced motion keeps pending label fully opaque", failures)
	_free_panel(panel)
	party.free()

func _test_run_snapshots_reduced_motion_for_reveals(failures: Array[String]) -> void:
	var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate()
	main.call(&"_ready")
	var settings := PartyForgeSettings.new()
	settings.reduced_motion = false
	main.set("saved_settings", settings)
	TestAssertions.truthy(main.call(&"select_leader_class", &"fighter"), "reduced-motion run fixture starts", failures)
	var panel := main.get_node("HUD/LevelUpPanel") as LevelUpPanel
	TestAssertions.equal(panel.get("_reduced_motion"), false, "run start configures reveal motion from snapshot", failures)
	settings.reduced_motion = true
	TestAssertions.equal(panel.get("_reduced_motion"), false, "reveal motion ignores later settings mutation", failures)
	main.free()

func _test_exact_offer_target_cancel_and_confirmation(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	party.recruit(catalog.class_by_id(&"marksman"))
	party.members[0].character_name = "Brann"
	party.members[1].character_name = "Hawke"
	var choices: Array[UpgradeChoice] = [
		UpgradeChoice.authored(catalog.upgrade_by_id(&"deadeye")),
		UpgradeChoice.authored(catalog.upgrade_by_id(&"vanguard_wall")),
		UpgradeChoice.authored(catalog.upgrade_by_id(&"vitality")),
		UpgradeChoice.authored(catalog.upgrade_by_id(&"precision")),
		UpgradeChoice.authored(catalog.upgrade_by_id(&"tempered_armor")),
	]
	var original_keys := choices.map(func(choice: UpgradeChoice) -> String: return choice.key())
	var panel := _attached_panel()
	panel.configure(
		catalog,
		UpgradeApplicationService.new(),
		func(member_id: int) -> Vector2:
			return Vector2(91.0, 260.0) if member_id == 1 else Vector2(63.0, 80.0),
	)
	panel.show_choices(choices, party, {choices[0].key(): true})
	var cards := panel.get_node("ContentPanel/OfferView/Content/Cards").get_children()
	TestAssertions.truthy((cards[0] as Button).disabled, "explicitly invalid first card is disabled", failures)
	TestAssertions.equal(panel.get("_initial_focus_card"), cards[1], "focus skips to first enabled card", failures)
	panel.show_choices(choices, party)
	cards = panel.get_node("ContentPanel/OfferView/Content/Cards").get_children()
	TestAssertions.equal(cards.size(), 5, "production offer renders exactly five reusable cards", failures)
	for index: int in mini(cards.size(), choices.size()):
		TestAssertions.truthy(cards[index] is UpgradeCard, "offer card %d uses UpgradeCard" % index, failures)
		TestAssertions.equal(cards[index].get("_choice"), choices[index], "offer card %d keeps exact choice instance" % index, failures)
		TestAssertions.truthy(not (cards[index] as UpgradeCard).disabled, "offer card %d is enabled" % index, failures)
	TestAssertions.equal(
		panel.get("_initial_focus_card"),
		cards[0],
		"first enabled offer card receives focus",
		failures,
	)

	(cards[0] as Button).pressed.emit()
	var offer_view := panel.get_node("ContentPanel/OfferView") as Control
	var recipient_view := panel.get_node("ContentPanel/RecipientView") as UpgradeRecipientPicker
	var confirmation_view := panel.get_node("ContentPanel/ConfirmationView") as Control
	TestAssertions.truthy(not offer_view.visible and recipient_view.visible and not confirmation_view.visible, "character card opens only recipient view", failures)
	var rows := recipient_view.get_node("Content/RecipientsScroll/Rows").get_children()
	TestAssertions.equal(rows.size(), 2, "recipient picker keeps every party member visible", failures)
	var fighter_row := _row_for_member(rows, 1)
	var marksman_row := _row_for_member(rows, 2)
	TestAssertions.truthy(fighter_row != null and fighter_row.disabled, "ineligible fighter row remains disabled", failures)
	TestAssertions.truthy(fighter_row != null and "Class is not eligible." in fighter_row.text, "disabled row displays its reason", failures)
	TestAssertions.truthy(marksman_row != null and not marksman_row.disabled, "eligible marksman row is enabled", failures)
	TestAssertions.truthy(marksman_row != null and "Hawke" in marksman_row.text, "recipient row uses stored character name", failures)

	(recipient_view.get_node("Content/Cancel") as Button).pressed.emit()
	TestAssertions.truthy(offer_view.visible and not recipient_view.visible and not confirmation_view.visible, "cancel restores only offer view", failures)
	var restored_cards := panel.get_node("ContentPanel/OfferView/Content/Cards").get_children()
	for index: int in 3:
		var restored_choice := restored_cards[index].get("_choice") as UpgradeChoice
		TestAssertions.equal(restored_choice, choices[index], "cancel preserves choice instance %d" % index, failures)
		TestAssertions.equal(restored_choice.key(), original_keys[index], "cancel preserves choice key %d" % index, failures)

	(restored_cards[0] as Button).pressed.emit()
	rows = recipient_view.get_node("Content/RecipientsScroll/Rows").get_children()
	marksman_row = _row_for_member(rows, 2)
	marksman_row.pressed.emit()
	TestAssertions.truthy(not offer_view.visible and not recipient_view.visible and confirmation_view.visible, "recipient selection opens only confirmation view", failures)
	var requests: Array[Dictionary] = []
	panel.confirmation_requested.connect(func(choice: UpgradeChoice, member_id: int) -> void:
		requests.append({"choice": choice, "member_id": member_id, "visible": panel.visible})
	)
	var confirm := confirmation_view.get_node("Content/Actions/Confirm") as Button
	confirm.pressed.emit()
	confirm.pressed.emit()
	TestAssertions.equal(requests.size(), 1, "confirmation emits once while awaiting application", failures)
	if not requests.is_empty():
		TestAssertions.equal(requests[0].choice, choices[0], "confirmation keeps exact selected choice", failures)
		TestAssertions.equal(requests[0].member_id, 2, "confirmation keeps stable recipient member id", failures)
		TestAssertions.truthy(requests[0].visible, "panel stays visible through confirmation request", failures)
	TestAssertions.truthy(panel.visible, "panel does not hide before completion", failures)

	panel.reject_selection("Target became unavailable.")
	TestAssertions.truthy(panel.visible and confirmation_view.visible, "rejection remains visible on confirmation", failures)
	TestAssertions.truthy(not confirm.disabled, "rejection restores usable confirmation control", failures)
	TestAssertions.equal((confirmation_view.get_node("Content/Error") as Label).text, "Target became unavailable.", "rejection displays central reason", failures)
	panel.complete_selection()
	TestAssertions.truthy(not panel.visible, "successful completion hides modal", failures)
	_free_panel(panel)
	party.free()

func _test_dynamic_card_count_and_focus(failures: Array[String]) -> void:
	var panel := _attached_panel()
	var cards := panel.get_node("ContentPanel/OfferView/Content/Cards") as HBoxContainer
	TestAssertions.truthy(panel.has_method("_ensure_card_count"), "level-up panel exposes dynamic card count support", failures)
	if not panel.has_method("_ensure_card_count"):
		_free_panel(panel)
		return
	for requested: int in range(1, 9):
		panel.call("_ensure_card_count", requested)
		var visible_cards: Array[Control] = []
		for child: Node in cards.get_children():
			if child is Control and child.visible:
				visible_cards.append(child as Control)
		TestAssertions.equal(visible_cards.size(), requested, "developer count %d exposes exactly that many cards" % requested, failures)
		for index: int in visible_cards.size():
			var card := visible_cards[index]
			if index > 0:
				TestAssertions.equal(card.get_node(card.focus_neighbor_left), visible_cards[index - 1], "card %d left focus reaches its adjacent card at count %d" % [index + 1, requested], failures)
			if index + 1 < visible_cards.size():
				TestAssertions.equal(card.get_node(card.focus_neighbor_right), visible_cards[index + 1], "card %d right focus reaches its adjacent card at count %d" % [index + 1, requested], failures)
	panel.call("_ensure_card_count", 0)
	TestAssertions.equal(_visible_card_count(cards), 1, "developer card count clamps to one", failures)
	panel.call("_ensure_card_count", 99)
	TestAssertions.equal(_visible_card_count(cards), 8, "developer card count clamps to eight", failures)
	TestAssertions.truthy(panel.has_method("_apply_card_face_density"), "level-up panel exposes responsive card-face density", failures)
	if panel.has_method("_apply_card_face_density"):
		panel.call("_apply_card_face_density", 1280.0)
		for card_node: Node in cards.get_children():
			if card_node is UpgradeCard and card_node.visible:
				for label_name: String in ["Eligibility", "Recipient", "Inheritance"]:
					TestAssertions.truthy(not card_node.get_node("Content/%s" % label_name).visible, "%s hides on a narrow card face" % label_name, failures)
				for label_name: String in ["Name", "Scope", "Rank", "Summary"]:
					TestAssertions.truthy(card_node.get_node("Content/%s" % label_name).visible, "%s remains on a narrow card face" % label_name, failures)
		panel.call("_apply_card_face_density", 1400.0)
		for card_node: Node in cards.get_children():
			if card_node is UpgradeCard and card_node.visible:
				for label_name: String in ["Eligibility", "Recipient", "Inheritance"]:
					TestAssertions.truthy(card_node.get_node("Content/%s" % label_name).visible, "%s returns at the wide threshold" % label_name, failures)
	_free_panel(panel)

func _test_duplicate_class_recipients_keep_identity(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	var fighter := catalog.class_by_id(&"fighter")
	party.initialize(fighter, catalog.traits)
	party.recruit(fighter)
	party.members[0].character_name = "Brann"
	party.members[1].character_name = "Alden"
	var vitality := UpgradeChoice.authored(catalog.upgrade_by_id(&"vitality"))
	var choices: Array[UpgradeChoice] = [
		vitality,
		UpgradeChoice.authored(catalog.upgrade_by_id(&"precision")),
		UpgradeChoice.authored(catalog.upgrade_by_id(&"tempered_armor")),
	]
	var panel := _attached_panel()
	panel.configure(catalog, UpgradeApplicationService.new(), func(_member_id: int) -> Vector2: return Vector2(100.0, 100.0))
	panel.show_choices(choices, party)
	(panel.get_node("ContentPanel/OfferView/Content/Cards/Card1") as Button).pressed.emit()
	var rows := panel.get_node("ContentPanel/RecipientView/Content/RecipientsScroll/Rows").get_children()
	var first := _row_for_member(rows, 1)
	var second := _row_for_member(rows, 2)
	TestAssertions.truthy(first != null and second != null, "duplicate-class members retain distinct row IDs", failures)
	TestAssertions.truthy(first != null and "Brann" in first.text, "first duplicate class uses stored name", failures)
	TestAssertions.truthy(second != null and "Alden" in second.text, "second duplicate class uses stored name", failures)
	TestAssertions.truthy(first != null and second != null and first.get_meta("member_id") != second.get_meta("member_id"), "duplicate-class rows retain distinct member IDs", failures)
	_free_panel(panel)
	party.free()

func _test_non_personal_confirmation_uses_zero(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var party_choice := UpgradeChoice.authored(catalog.upgrade_by_id(&"vanguard_wall"))
	var choices: Array[UpgradeChoice] = [
		party_choice,
		UpgradeChoice.authored(catalog.upgrade_by_id(&"vitality")),
		UpgradeChoice.authored(catalog.upgrade_by_id(&"precision")),
	]
	var panel := _attached_panel()
	panel.configure(catalog, UpgradeApplicationService.new(), func(_member_id: int) -> Vector2: return Vector2.ZERO)
	panel.show_choices(choices, party)
	var requests: Array[Dictionary] = []
	panel.confirmation_requested.connect(func(choice: UpgradeChoice, member_id: int) -> void: requests.append({"choice": choice, "member_id": member_id}))
	(panel.get_node("ContentPanel/OfferView/Content/Cards/Card1") as Button).pressed.emit()
	(panel.get_node("ContentPanel/ConfirmationView/Content/Actions/Confirm") as Button).pressed.emit()
	TestAssertions.equal(requests.size(), 1, "non-personal confirmation emits once", failures)
	if not requests.is_empty():
		TestAssertions.equal(requests[0].choice, party_choice, "non-personal confirmation keeps exact choice", failures)
		TestAssertions.equal(requests[0].member_id, 0, "non-personal confirmation uses member id zero", failures)
	_free_panel(panel)
	party.free()

func _test_production_card_tooltip_composition(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var vitality := catalog.upgrade_by_id(&"vitality")
	TestAssertions.truthy(
		UpgradeApplicationService.apply(vitality.id, catalog, party, party.members[0].member_id),
		"tooltip fixture applies personal rank one",
		failures,
	)
	var panel := _attached_panel()
	panel.configure(catalog, UpgradeApplicationService.new(), func(_member_id: int) -> Vector2: return Vector2(100.0, 100.0))
	var personal_choices: Array[UpgradeChoice] = [
		UpgradeChoice.authored(vitality),
		UpgradeChoice.authored(catalog.upgrade_by_id(&"tempered_armor")),
		UpgradeChoice.authored(catalog.upgrade_by_id(&"precision")),
	]
	panel.show_choices(personal_choices, party)
	var tooltip := panel.get_node_or_null("TooltipPanel") as UpgradeTooltipPanel
	TestAssertions.truthy(tooltip != null, "level-up scene composes one production tooltip panel", failures)
	if tooltip == null:
		_free_panel(panel)
		party.free()
		return
	var personal_card := panel.get_node("ContentPanel/OfferView/Content/Cards/Card1") as UpgradeCard
	personal_card.mouse_entered.emit()
	TestAssertions.truthy(tooltip.visible, "visible card hover reveals composed tooltip", failures)
	TestAssertions.equal((tooltip.get_node("Content/Header/Title") as Label).text, "Vitality", "composed tooltip renders authored title", failures)
	TestAssertions.equal((tooltip.get_node("Content/Rank") as Label).text, "Offered rank 2 / 5", "personal tooltip uses member next rank", failures)
	TestAssertions.equal((tooltip.get_node("Content/BodyScroll/Body/Effects") as Label).text, "8% increased Maximum Health.", "composed tooltip renders exact effect content", failures)
	TestAssertions.equal(
		(tooltip.get_node("Content/BodyScroll/Body/Keywords") as Label).text,
		"Maximum Health: The total damage a character can take before being downed.\nIncreased: An additive modifier combined with other increased and reduced values.",
		"composed tooltip renders exact keyword content",
		failures,
	)
	personal_card.mouse_exited.emit()
	TestAssertions.truthy(not tooltip.visible, "hover dismissal hides composed tooltip", failures)
	TestAssertions.equal(panel.get("_tooltip_choice"), null, "actual tooltip dismissal clears LevelUpPanel tracking", failures)
	personal_card.mouse_entered.emit()
	tooltip.set_hold_active(true)
	personal_card.mouse_exited.emit()
	TestAssertions.truthy(tooltip.visible, "Alt keeps tooltip alive after card exit", failures)
	var pinned_title := (tooltip.get_node("Content/Header/Title") as Label).text
	var pin := tooltip.get_node("Content/Header/Pin") as Button
	pin.pressed.emit()
	tooltip.set_hold_active(false)
	TestAssertions.truthy(tooltip.visible and tooltip.is_pinned(), "mouse pin survives Alt release", failures)
	var accepted_source := StringName(personal_choices[0].key())
	var body_scroll := tooltip.get_node("Content/BodyScroll") as ScrollContainer
	body_scroll.scroll_vertical = 37
	TestAssertions.truthy(tooltip.is_current_source(accepted_source), "pinned tooltip retains accepted LevelUpPanel source", failures)

	var second_card := panel.get_node("ContentPanel/OfferView/Content/Cards/Card2") as UpgradeCard
	second_card.mouse_entered.emit()
	TestAssertions.equal((tooltip.get_node("Content/Header/Title") as Label).text, pinned_title, "pinned content rejects another card hover", failures)
	TestAssertions.truthy(tooltip.is_current_source(accepted_source), "rejected card cannot replace accepted source identity", failures)
	TestAssertions.equal(body_scroll.scroll_vertical, 37, "rejected card cannot reset accepted source scroll", failures)
	second_card.mouse_exited.emit()
	TestAssertions.truthy(tooltip.visible and tooltip.is_current_source(accepted_source), "rejected card dismissal cannot release accepted source", failures)
	pin.pressed.emit()
	TestAssertions.truthy(not tooltip.visible, "unpinning inactive source dismisses", failures)

	personal_card.mouse_entered.emit()
	var controller_pin := InputEventJoypadButton.new()
	controller_pin.button_index = JOY_BUTTON_Y
	controller_pin.pressed = true
	tooltip.call("_unhandled_input", controller_pin)
	TestAssertions.truthy(tooltip.is_pinned(), "Y/Triangle pins visible tooltip", failures)
	tooltip.call("_unhandled_input", controller_pin)
	TestAssertions.truthy(not tooltip.is_pinned(), "Y/Triangle unpins visible tooltip", failures)
	personal_card.mouse_exited.emit()
	party.recruit(catalog.class_by_id(&"fighter"))
	panel.show_choices(personal_choices, party)
	TestAssertions.truthy(not tooltip.visible and not tooltip.is_pinned(), "new personal offer clears tooltip state", failures)
	personal_card = panel.get_node("ContentPanel/OfferView/Content/Cards/Card1") as UpgradeCard
	personal_card.focus_entered.emit()
	TestAssertions.equal((tooltip.get_node("Content/Rank") as Label).text, "Offered rank varies / 5", "mixed personal ranks remain explicit", failures)
	personal_card.focus_exited.emit()
	personal_card.mouse_entered.emit()
	pin.pressed.emit()

	var shared := vitality.duplicate(true) as UpgradeDefinition
	shared.id = &"shared_tooltip_fixture"
	shared.display_name = "Shared Tooltip Fixture"
	shared.scope = UpgradeDefinition.Scope.PARTY
	shared.max_rank = 5
	catalog.upgrades.append(shared)
	TestAssertions.truthy(UpgradeApplicationService.apply(shared.id, catalog, party), "tooltip fixture applies shared rank one", failures)
	var shared_choice := UpgradeChoice.authored(shared)
	var shared_choices: Array[UpgradeChoice] = [
		UpgradeChoice.authored(catalog.upgrade_by_id(&"precision")),
		shared_choice,
		UpgradeChoice.authored(catalog.upgrade_by_id(&"tempered_armor")),
	]
	panel.show_choices(shared_choices, party)
	TestAssertions.truthy(not tooltip.visible and not tooltip.is_pinned(), "new offer clears stale tooltip state", failures)
	var shared_card := panel.get_node("ContentPanel/OfferView/Content/Cards/Card2") as UpgradeCard
	shared_card.focus_entered.emit()
	TestAssertions.truthy(tooltip.visible, "visible card focus reveals same composed tooltip", failures)
	TestAssertions.equal((tooltip.get_node("Content/Rank") as Label).text, "Offered rank 2 / 5", "shared tooltip uses party next rank", failures)
	shared_card.focus_exited.emit()
	TestAssertions.truthy(not tooltip.visible, "focus dismissal hides composed tooltip", failures)
	shared_card.focus_entered.emit()
	pin.pressed.emit()
	shared_card.pressed.emit()
	TestAssertions.truthy(not tooltip.visible and not tooltip.is_pinned(), "non-offer view clears tooltip state", failures)
	panel.cancel_subflow()
	shared_card.focus_entered.emit()
	pin.pressed.emit()
	panel.cancel_subflow()
	TestAssertions.truthy(not tooltip.visible and not tooltip.is_pinned(), "subflow cancellation clears stale tooltip state", failures)
	shared_card.focus_exited.emit()
	shared_card.focus_entered.emit()
	pin.pressed.emit()
	panel.complete_selection()
	TestAssertions.truthy(not tooltip.visible and not tooltip.is_pinned(), "selection completion clears stale tooltip state", failures)
	_free_panel(panel)
	party.free()


func _test_tooltip_forced_lifecycle_cleanup(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	party.recruit(catalog.class_by_id(&"marksman"))
	var personal_choice := UpgradeChoice.authored(catalog.upgrade_by_id(&"deadeye"))
	var choices: Array[UpgradeChoice] = [
		personal_choice,
		UpgradeChoice.authored(catalog.upgrade_by_id(&"vanguard_wall")),
		UpgradeChoice.authored(catalog.upgrade_by_id(&"vitality")),
	]
	var panel := _attached_panel()
	panel.configure(catalog, UpgradeApplicationService.new(), func(_member_id: int) -> Vector2: return Vector2(100.0, 100.0))
	panel.show_choices(choices, party)
	var tooltip := panel.get_node("TooltipPanel") as UpgradeTooltipPanel
	var personal_card := panel.get_node("ContentPanel/OfferView/Content/Cards/Card1") as UpgradeCard
	var personal_source := StringName(personal_choice.key())
	personal_card.mouse_entered.emit()
	_dirty_tooltip(tooltip, personal_source, 19, failures, "recipient selection")
	personal_card.pressed.emit()
	TestAssertions.truthy((panel.get_node("ContentPanel/RecipientView") as Control).visible, "recipient selection opens recipient view", failures)
	_assert_forced_tooltip_cleanup(panel, tooltip, personal_source, "recipient selection", failures)
	personal_card.mouse_exited.emit()

	var rows := panel.get_node("ContentPanel/RecipientView/Content/RecipientsScroll/Rows").get_children()
	var marksman_row := _row_for_member(rows, 2)
	var confirmation_source := &"recipient_confirmation_transition"
	TestAssertions.truthy(marksman_row != null, "confirmation transition has eligible recipient", failures)
	if marksman_row != null:
		TestAssertions.truthy(
			tooltip.show_content(_lifecycle_tooltip_content("Recipient transition"), marksman_row, confirmation_source),
			"confirmation transition accepts dirty source",
			failures,
		)
		_dirty_tooltip(tooltip, confirmation_source, 23, failures, "confirmation transition")
		marksman_row.pressed.emit()
		TestAssertions.truthy((panel.get_node("ContentPanel/ConfirmationView") as Control).visible, "recipient choice opens confirmation view", failures)
		_assert_forced_tooltip_cleanup(panel, tooltip, confirmation_source, "confirmation transition", failures)

	panel.cancel_subflow()
	personal_card.mouse_entered.emit()
	_dirty_tooltip(tooltip, personal_source, 31, failures, "level-up exit")
	panel.complete_selection()
	TestAssertions.truthy(not panel.visible, "level-up exit hides panel", failures)
	_assert_forced_tooltip_cleanup(panel, tooltip, personal_source, "level-up exit", failures)

	var probe_source := &"post_level_up_exit_probe"
	TestAssertions.truthy(
		tooltip.show_content(_lifecycle_tooltip_content("Post-exit probe"), personal_card, probe_source),
		"post-exit probe is accepted",
		failures,
	)
	personal_card.detail_dismissed.emit(personal_choice)
	TestAssertions.truthy(
		tooltip.visible and tooltip.is_current_source(probe_source),
		"stale LevelUpPanel tracking cannot dismiss a fresh source",
		failures,
	)
	tooltip.release_source(probe_source)
	TestAssertions.truthy(not tooltip.visible, "level-up exit clears Alt hold retention", failures)
	_free_panel(panel)
	party.free()


func _dirty_tooltip(
	tooltip: UpgradeTooltipPanel,
	source_id: StringName,
	scroll_position: int,
	failures: Array[String],
	context: String
) -> void:
	var body_scroll := tooltip.get_node("Content/BodyScroll") as ScrollContainer
	body_scroll.scroll_vertical = scroll_position
	tooltip.set_hold_active(true)
	if not tooltip.is_pinned():
		(tooltip.get_node("Content/Header/Pin") as Button).pressed.emit()
	TestAssertions.truthy(tooltip.visible, "%s begins with visible tooltip" % context, failures)
	TestAssertions.truthy(tooltip.is_pinned(), "%s begins with pinned tooltip" % context, failures)
	TestAssertions.truthy(tooltip.is_current_source(source_id), "%s begins with current source" % context, failures)
	TestAssertions.equal(body_scroll.scroll_vertical, scroll_position, "%s begins with non-top scroll" % context, failures)


func _assert_forced_tooltip_cleanup(
	panel: LevelUpPanel,
	tooltip: UpgradeTooltipPanel,
	former_source: StringName,
	context: String,
	failures: Array[String]
) -> void:
	TestAssertions.truthy(not tooltip.visible, "%s force-hides tooltip" % context, failures)
	TestAssertions.truthy(not tooltip.is_pinned(), "%s clears pin" % context, failures)
	TestAssertions.truthy(not tooltip.is_current_source(former_source), "%s clears source" % context, failures)
	TestAssertions.equal(tooltip.get("_source_id"), StringName(), "%s clears exact popup source identity" % context, failures)
	TestAssertions.equal((tooltip.get_node("Content/BodyScroll") as ScrollContainer).scroll_vertical, 0, "%s resets scroll" % context, failures)
	TestAssertions.equal(panel.get("_tooltip_choice"), null, "%s clears LevelUpPanel tracking" % context, failures)


func _lifecycle_tooltip_content(title: String) -> Dictionary:
	return {
		"title": title,
		"rank_text": "Fixture rank",
		"description": "Lifecycle fixture content.",
		"effect_lines": ["Fixture effect."],
		"eligibility_text": "Fixture eligible.",
		"inheritance_text": "",
		"keyword_lines": ["Fixture: Lifecycle detail."],
	}

func _row_for_member(rows: Array[Node], member_id: int) -> Button:
	for row: Node in rows:
		if int(row.get_meta("member_id", 0)) == member_id:
			return row as Button
	return null

func _visible_card_count(cards: HBoxContainer) -> int:
	var count := 0
	for card: Node in cards.get_children():
		if card is UpgradeCard and card.visible:
			count += 1
	return count

func _attached_panel() -> LevelUpPanel:
	var panel := (load("res://scenes/ui/level_up_panel.tscn") as PackedScene).instantiate() as LevelUpPanel
	for card: Node in panel.get_node("ContentPanel/OfferView/Content/Cards").get_children():
		card.call("_ready")
	panel.get_node("ContentPanel/RecipientView").call("_ready")
	panel.get_node("TooltipPanel").call("_ready")
	panel.call("_ready")
	return panel

func _free_panel(panel: LevelUpPanel) -> void:
	panel.free()

func _action_event(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event
