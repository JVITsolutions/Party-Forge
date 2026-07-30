extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_exact_offer_target_cancel_and_confirmation(failures)
	_test_duplicate_class_recipients_keep_identity(failures)
	_test_non_personal_confirmation_uses_zero(failures)
	_test_production_card_tooltip_composition(failures)
	return failures

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
	TestAssertions.equal(cards.size(), 3, "offer renders exactly three reusable cards", failures)
	for index: int in 3:
		TestAssertions.truthy(cards[index] is UpgradeCard, "offer card %d uses UpgradeCard" % index, failures)
		TestAssertions.equal(cards[index].get("_choice"), choices[index], "offer card %d keeps exact choice instance" % index, failures)
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
	TestAssertions.equal((tooltip.get_node("Content/Title") as Label).text, "Vitality", "composed tooltip renders authored title", failures)
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
	party.recruit(catalog.class_by_id(&"fighter"))
	panel.show_choices(personal_choices, party)
	personal_card = panel.get_node("ContentPanel/OfferView/Content/Cards/Card1") as UpgradeCard
	personal_card.focus_entered.emit()
	TestAssertions.equal((tooltip.get_node("Content/Rank") as Label).text, "Offered rank varies / 5", "mixed personal ranks remain explicit", failures)
	personal_card.focus_exited.emit()
	personal_card.mouse_entered.emit()

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
	TestAssertions.truthy(not tooltip.visible, "new offer hides stale tooltip", failures)
	var shared_card := panel.get_node("ContentPanel/OfferView/Content/Cards/Card2") as UpgradeCard
	shared_card.focus_entered.emit()
	TestAssertions.truthy(tooltip.visible, "visible card focus reveals same composed tooltip", failures)
	TestAssertions.equal((tooltip.get_node("Content/Rank") as Label).text, "Offered rank 2 / 5", "shared tooltip uses party next rank", failures)
	shared_card.focus_exited.emit()
	TestAssertions.truthy(not tooltip.visible, "focus dismissal hides composed tooltip", failures)
	shared_card.focus_entered.emit()
	panel.cancel_subflow()
	TestAssertions.truthy(not tooltip.visible, "subflow cancellation hides stale tooltip", failures)
	shared_card.focus_exited.emit()
	shared_card.focus_entered.emit()
	panel.complete_selection()
	TestAssertions.truthy(not tooltip.visible, "selection completion hides stale tooltip", failures)
	_free_panel(panel)
	party.free()

func _row_for_member(rows: Array[Node], member_id: int) -> Button:
	for row: Node in rows:
		if int(row.get_meta("member_id", 0)) == member_id:
			return row as Button
	return null

func _attached_panel() -> LevelUpPanel:
	var panel := (load("res://scenes/ui/level_up_panel.tscn") as PackedScene).instantiate() as LevelUpPanel
	for card: Node in panel.get_node("ContentPanel/OfferView/Content/Cards").get_children():
		card.call("_ready")
	panel.get_node("ContentPanel/RecipientView").call("_ready")
	panel.call("_ready")
	return panel

func _free_panel(panel: LevelUpPanel) -> void:
	panel.free()
