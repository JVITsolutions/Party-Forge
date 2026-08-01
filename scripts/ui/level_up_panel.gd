class_name LevelUpPanel
extends Control

const UPGRADE_CARD_SCENE := preload("res://scenes/ui/upgrade_card.tscn")

signal choice_selected(choice: UpgradeChoice)
signal confirmation_requested(choice: UpgradeChoice, recipient_member_id: int)

var choices: Array[UpgradeChoice] = []
var selected_once := false

var _catalog: GameCatalog
var _upgrade_service: UpgradeApplicationService
var _health_provider := Callable()
var _party: PartyManager
var _invalid_choice_keys: Dictionary = {}
var _pending_level_count := 1
var _pending_choice: UpgradeChoice
var _pending_member_id := 0
var _awaiting_application := false
var _initial_focus_card: UpgradeCard
var _tooltip_choice: UpgradeChoice
var _reveal_controller: LevelUpRevealController
var _final_bindings: Array[Dictionary] = []
var _reduced_motion := true
var _reveal_request_id := 0
var _reveal_pending := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_reveal_controller = get_node_or_null("RevealController") as LevelUpRevealController
	if _reveal_controller != null and not _reveal_controller.resolved.is_connected(_on_reveal_resolved):
		_reveal_controller.resolved.connect(_on_reveal_resolved)
	_connect_cards()
	_configure_card_focus_neighbors()
	_connect_recipient_picker()
	_connect_confirmation()
	_connect_legacy_buttons()
	var tooltip := _tooltip()
	if tooltip != null and not tooltip.dismissed.is_connected(_on_tooltip_dismissed):
		tooltip.dismissed.connect(_on_tooltip_dismissed)
	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)
	_apply_card_face_density(_current_viewport_width())


func _process(delta: float) -> void:
	if _reveal_controller == null:
		return
	_reveal_controller.advance(delta)
	var pending_label := get_node_or_null("ContentPanel/OfferView/Content/PendingLevels") as Label
	if pending_label == null:
		return
	if _reduced_motion or _reveal_controller.is_revealing():
		pending_label.modulate.a = 1.0
		return
	var pulse := (sin(_reveal_controller.elapsed_phase() * TAU) + 1.0) * 0.5
	pending_label.modulate.a = lerpf(0.75, 1.0, pulse)


func configure(
	catalog: GameCatalog,
	upgrade_service: UpgradeApplicationService,
	health_provider: Callable
) -> void:
	_catalog = catalog
	_upgrade_service = upgrade_service
	_health_provider = health_provider


func configure_reduced_motion(reduced_motion: bool) -> void:
	_reduced_motion = reduced_motion
	var pending_label := get_node_or_null("ContentPanel/OfferView/Content/PendingLevels") as Label
	if pending_label != null and _reduced_motion:
		pending_label.modulate.a = 1.0


func show_choices(
	exact_choices: Array[UpgradeChoice],
	party: PartyManager,
	invalid_choice_keys: Dictionary = {},
	pending_count: int = 1
) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_invalidate_reveal()
	_connect_recipient_picker()
	_connect_confirmation()
	_connect_legacy_buttons()
	if _catalog == null:
		_catalog = GameCatalog.load_defaults()
	if _upgrade_service == null:
		_upgrade_service = UpgradeApplicationService.new()
	choices = exact_choices.duplicate()
	_ensure_card_count(choices.size())
	_apply_card_face_density(_current_viewport_width())
	_party = party
	_invalid_choice_keys = invalid_choice_keys.duplicate()
	_pending_level_count = maxi(pending_count, 1)
	var pending_label := get_node("ContentPanel/OfferView/Content/PendingLevels") as Label
	pending_label.text = "%d %s ready" % [
		_pending_level_count,
		"upgrade" if _pending_level_count == 1 else "upgrades",
	]
	pending_label.visible = _pending_level_count > 0
	_pending_choice = null
	_pending_member_id = 0
	_awaiting_application = false
	_initial_focus_card = null
	selected_once = false
	_hide_tooltip()
	visible = true
	_populate_offer_cards()
	_populate_legacy_buttons()
	_show_view(&"offer")
	if _reveal_controller != null:
		var reveal_cards: Array[UpgradeCard] = []
		var cards_row := get_node("ContentPanel/OfferView/Content/Cards") as HBoxContainer
		for card_node: Node in cards_row.get_children():
			if card_node is UpgradeCard and card_node.visible:
				var reveal_card := card_node as UpgradeCard
				reveal_card.disabled = true
				reveal_cards.append(reveal_card)
		var preview_presentations: Array[Dictionary] = []
		for binding: Dictionary in _final_bindings:
			preview_presentations.append((binding.get("presentation", {}) as Dictionary).duplicate(true))
		if not cards_row.is_inside_tree():
			# Lightweight unit fixtures exercise the controller without a viewport.
			_reveal_controller.play(reveal_cards, _final_bindings, preview_presentations, _reduced_motion)
		else:
			_reveal_pending = true
			var request_id := _reveal_request_id
			cards_row.sort_children.connect(
				_start_reveal_after_layout.bind(
					request_id,
					reveal_cards,
					_final_bindings.duplicate(true),
					preview_presentations,
					_reduced_motion
				),
				CONNECT_ONE_SHOT
			)
			cards_row.queue_sort()
			# The panel starts hidden, so its HBox has not received its first sort when
			# show_choices() is called. Resolve that queued layout now so the reveal
			# controller records the real per-card positions instead of five (0, 0)s.
			cards_row.notification(Container.NOTIFICATION_SORT_CHILDREN)
	else:
		_focus_first_enabled_card()


func complete_selection() -> void:
	_hide_tooltip()
	_invalidate_reveal()
	_awaiting_application = false
	_pending_choice = null
	_pending_member_id = 0
	visible = false
	var pending_label := get_node_or_null("ContentPanel/OfferView/Content/PendingLevels") as Label
	if pending_label != null:
		pending_label.modulate.a = 1.0


func reject_selection(reason: String) -> void:
	if _pending_choice == null:
		return
	visible = true
	_awaiting_application = false
	var confirm := get_node("ContentPanel/ConfirmationView/Content/Actions/Confirm") as Button
	confirm.disabled = false
	var error := get_node("ContentPanel/ConfirmationView/Content/Error") as Label
	error.text = reason
	error.visible = not reason.is_empty()
	_show_view(&"confirmation")
	if confirm.is_inside_tree():
		confirm.grab_focus()


func cancel_subflow() -> void:
	if _awaiting_application:
		return
	_hide_tooltip()
	_pending_choice = null
	_pending_member_id = 0
	_show_view(&"offer")
	_focus_first_enabled_card()


func _populate_offer_cards() -> void:
	_final_bindings.clear()
	var cards := get_node("ContentPanel/OfferView/Content/Cards").get_children()
	for index: int in cards.size():
		var card := cards[index] as UpgradeCard
		var choice: UpgradeChoice = choices[index] if index < choices.size() else null
		if not card.visible:
			continue
		var presentation := _presentation_for(choice)
		var disabled_reason := _disabled_reason(choice)
		var final_binding := {
			"choice": choice,
			"presentation": presentation,
			"disabled_reason": disabled_reason,
		}
		_final_bindings.append(final_binding)
		card.bind_choice(choice, presentation, disabled_reason)


func _presentation_for(choice: UpgradeChoice) -> Dictionary:
	if choice == null:
		return {"name": "Unavailable", "scope_badge": "", "rank_text": "", "summary": ""}
	if choice.kind == UpgradeChoice.Kind.AUTHORED and choice.definition != null:
		return UpgradePresentationService.card(choice.definition, _party)
	return FoundationalUpgradePresentationService.card(choice, _party, _catalog)


func _disabled_reason(choice: UpgradeChoice) -> String:
	if choice == null:
		return "Unavailable."
	if _invalid_choice_keys.has(choice.key()):
		var supplied_reason: Variant = _invalid_choice_keys[choice.key()]
		return supplied_reason if supplied_reason is String and not supplied_reason.is_empty() else "Unavailable."
	if _party == null:
		return "Party is unavailable."
	if not choice.is_valid_for(_party):
		return "No longer available."
	return ""


func _connect_cards() -> void:
	var cards_node := get_node_or_null("ContentPanel/OfferView/Content/Cards")
	if cards_node == null:
		return
	for card_node: Node in cards_node.get_children():
		var card := card_node as UpgradeCard
		if card == null:
			continue
		if not card.activated.is_connected(_on_card_activated):
			card.activated.connect(_on_card_activated)
		if not card.detail_requested.is_connected(_on_card_detail_requested):
			card.detail_requested.connect(_on_card_detail_requested)
		if not card.detail_dismissed.is_connected(_on_card_detail_dismissed):
			card.detail_dismissed.connect(_on_card_detail_dismissed)


func _ensure_card_count(count: int) -> void:
	var cards := get_node("ContentPanel/OfferView/Content/Cards") as HBoxContainer
	var needed := clampi(count, 1, 8)
	while cards.get_child_count() < needed:
		var card := UPGRADE_CARD_SCENE.instantiate() as UpgradeCard
		card.name = "Card%d" % (cards.get_child_count() + 1)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_stretch_ratio = 1.0
		cards.add_child(card)
	for index: int in cards.get_child_count():
		(cards.get_child(index) as Control).visible = index < needed
	_connect_cards()
	_configure_card_focus_neighbors()


func _configure_card_focus_neighbors() -> void:
	var cards := get_node_or_null("ContentPanel/OfferView/Content/Cards") as HBoxContainer
	if cards == null:
		return
	var visible_cards: Array[Control] = []
	for child: Node in cards.get_children():
		if child is Control and child.visible:
			visible_cards.append(child as Control)
	for index: int in visible_cards.size():
		var card := visible_cards[index]
		card.focus_neighbor_left = card.get_path_to(visible_cards[index - 1]) if index > 0 else NodePath()
		card.focus_neighbor_right = card.get_path_to(visible_cards[index + 1]) if index + 1 < visible_cards.size() else NodePath()


func _on_viewport_size_changed() -> void:
	_apply_card_face_density(_current_viewport_width())


func _current_viewport_width() -> float:
	if is_inside_tree():
		return get_viewport_rect().size.x
	return float(ProjectSettings.get_setting("display/window/size/viewport_width", 1920))


func _apply_card_face_density(viewport_width: float) -> void:
	var cards := get_node_or_null("ContentPanel/OfferView/Content/Cards") as HBoxContainer
	if cards == null:
		return
	var show_extended_summary := viewport_width >= 1400.0
	for child: Node in cards.get_children():
		if not (child is UpgradeCard) or not child.visible:
			continue
		for label_name: String in ["Eligibility", "Recipient", "Inheritance"]:
			var label := child.get_node_or_null("Content/%s" % label_name) as Label
			if label != null:
				label.visible = show_extended_summary


func _connect_recipient_picker() -> void:
	var picker := get_node_or_null("ContentPanel/RecipientView") as UpgradeRecipientPicker
	if picker == null:
		return
	if not picker.recipient_selected.is_connected(_on_recipient_selected):
		picker.recipient_selected.connect(_on_recipient_selected)
	if not picker.cancelled.is_connected(cancel_subflow):
		picker.cancelled.connect(cancel_subflow)


func _connect_confirmation() -> void:
	var confirm := get_node_or_null("ContentPanel/ConfirmationView/Content/Actions/Confirm") as Button
	var cancel := get_node_or_null("ContentPanel/ConfirmationView/Content/Actions/Cancel") as Button
	if confirm != null and not confirm.pressed.is_connected(_on_confirm_pressed):
		confirm.pressed.connect(_on_confirm_pressed)
	if cancel != null and not cancel.pressed.is_connected(cancel_subflow):
		cancel.pressed.connect(cancel_subflow)


func _on_card_activated(choice: UpgradeChoice) -> void:
	if _reveal_pending or (_reveal_controller != null and _reveal_controller.is_revealing()) or _awaiting_application or choice == null:
		return
	_hide_tooltip()
	if choice.requires_recipient():
		var rows := UpgradePresentationService.recipient_rows(
			choice.definition,
			_party,
			_health_provider
		)
		(get_node("ContentPanel/RecipientView") as UpgradeRecipientPicker).show_for(choice, rows)
		_show_view(&"recipient")
		_focus_first_enabled_recipient()
		return
	_pending_choice = choice
	_pending_member_id = 0
	_show_confirmation()


func _on_recipient_selected(choice: UpgradeChoice, member_id: int) -> void:
	if _awaiting_application or choice == null:
		return
	_pending_choice = choice
	_pending_member_id = member_id
	_show_confirmation()


func _show_confirmation() -> void:
	var choice_name := get_node("ContentPanel/ConfirmationView/Content/ChoiceName") as Label
	var recipient := get_node("ContentPanel/ConfirmationView/Content/Recipient") as Label
	var error := get_node("ContentPanel/ConfirmationView/Content/Error") as Label
	var confirm := get_node("ContentPanel/ConfirmationView/Content/Actions/Confirm") as Button
	choice_name.text = _pending_choice.label
	if _pending_member_id == 0:
		recipient.text = "Applies without a character target."
	else:
		var member := _party.member_by_id(_pending_member_id)
		recipient.text = "Recipient: %s [#%d]" % [
			member.character_name if member != null else "Unavailable",
			_pending_member_id,
		]
	error.text = ""
	error.visible = false
	confirm.disabled = false
	_show_view(&"confirmation")
	if confirm.is_inside_tree():
		confirm.grab_focus()


func _on_confirm_pressed() -> void:
	if _awaiting_application or _pending_choice == null:
		return
	_awaiting_application = true
	(get_node("ContentPanel/ConfirmationView/Content/Actions/Confirm") as Button).disabled = true
	confirmation_requested.emit(_pending_choice, _pending_member_id)


func _show_view(view: StringName) -> void:
	if view != &"offer":
		_hide_tooltip()
	(get_node("ContentPanel/OfferView") as Control).visible = view == &"offer"
	(get_node("ContentPanel/RecipientView") as Control).visible = view == &"recipient"
	(get_node("ContentPanel/ConfirmationView") as Control).visible = view == &"confirmation"


func _unhandled_input(event: InputEvent) -> void:
	if visible and (_reveal_pending or (_reveal_controller != null and _reveal_controller.is_revealing())) and (
		event.is_action_pressed(&"ui_accept")
		or event.is_action_pressed(&"ui_cancel")
	):
		if _reveal_controller != null and _reveal_controller.is_revealing():
			_reveal_controller.skip()
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		return


func _on_reveal_resolved() -> void:
	if visible and (get_node("ContentPanel/OfferView") as Control).visible:
		_focus_first_enabled_card()


func _start_reveal_after_layout(
	request_id: int,
	reveal_cards: Array[UpgradeCard],
	final_bindings: Array[Dictionary],
	preview_presentations: Array[Dictionary],
	reduced_motion: bool
) -> void:
	if request_id != _reveal_request_id or not visible or _reveal_controller == null:
		return
	_reveal_pending = false
	_reveal_controller.play(reveal_cards, final_bindings, preview_presentations, reduced_motion)


func _invalidate_reveal() -> void:
	_reveal_request_id += 1
	_reveal_pending = false
	if _reveal_controller != null:
		_reveal_controller.reset()


func _focus_first_enabled_card() -> void:
	_initial_focus_card = null
	for card_node: Node in get_node("ContentPanel/OfferView/Content/Cards").get_children():
		var card := card_node as UpgradeCard
		if card != null and not card.disabled:
			_initial_focus_card = card
			if card.is_inside_tree():
				card.grab_focus()
			return


func _focus_first_enabled_recipient() -> void:
	for row_node: Node in get_node("ContentPanel/RecipientView/Content/RecipientsScroll/Rows").get_children():
		var row := row_node as Button
		if row != null and not row.disabled:
			if row.is_inside_tree():
				row.grab_focus()
			return


func _on_card_detail_requested(choice: UpgradeChoice, anchor: Control) -> void:
	if (
		not visible
		or not (get_node("ContentPanel/OfferView") as Control).visible
		or _reveal_pending
		or (_reveal_controller != null and _reveal_controller.is_revealing())
		or choice == null
		or _catalog == null
		or _catalog.keywords == null
		or _party == null
	):
		_hide_tooltip()
		return
	var content: Dictionary
	if choice.kind == UpgradeChoice.Kind.AUTHORED:
		var definition := _catalog.upgrade_by_id(choice.target_id)
		if definition == null:
			_hide_tooltip()
			return
		var rank_state := _offered_rank_state(definition)
		content = UpgradePresentationService.tooltip(
			definition,
			int(rank_state.rank),
			PartyManager.STAT_CATALOG,
			_catalog.keywords
		)
		if bool(rank_state.varies):
			content["rank_text"] = "Offered rank varies / %d" % definition.max_rank
	else:
		content = FoundationalUpgradePresentationService.tooltip(choice, _party, _catalog)
	var source_id := StringName(choice.key())
	if _tooltip().show_content(content, anchor, source_id):
		_tooltip_choice = choice


func _on_card_detail_dismissed(choice: UpgradeChoice) -> void:
	if choice == null:
		return
	_tooltip().release_source(StringName(choice.key()))


func _on_tooltip_dismissed() -> void:
	_tooltip_choice = null


func _offered_rank_state(definition: UpgradeDefinition) -> Dictionary:
	if _party == null or definition == null:
		return {"rank": 1, "varies": false}
	var current_rank := _party.upgrade_rank(definition.id)
	if not definition.is_single_recipient():
		return {
			"rank": clampi(current_rank + 1, 1, definition.max_rank),
			"varies": false,
		}
	var usable_ranks: Array[int] = []
	for member: PartyMemberState in _party.members:
		if not definition.is_member_eligible(member):
			continue
		var personal_rank := _party.upgrade_rank(definition.id, member.member_id)
		if personal_rank < definition.max_rank:
			usable_ranks.append(personal_rank)
	if usable_ranks.is_empty():
		return {"rank": definition.max_rank, "varies": false}
	current_rank = usable_ranks[0]
	var varies := false
	for personal_rank: int in usable_ranks:
		current_rank = mini(current_rank, personal_rank)
		varies = varies or personal_rank != usable_ranks[0]
	return {
		"rank": clampi(current_rank + 1, 1, definition.max_rank),
		"varies": varies,
	}


func _hide_tooltip() -> void:
	_tooltip_choice = null
	var tooltip := _tooltip()
	if tooltip != null:
		tooltip.force_dismiss()


func _tooltip() -> UpgradeTooltipPanel:
	return get_node_or_null("TooltipPanel") as UpgradeTooltipPanel


# Temporary compatibility for Main's pre-Task-8 choice_selected wiring. These
# hidden buttons are not part of the production modal flow.
func _connect_legacy_buttons() -> void:
	var legacy := get_node_or_null("Choices")
	if legacy == null:
		return
	for index: int in mini(3, legacy.get_child_count()):
		var button := legacy.get_child(index) as Button
		var callback := _legacy_select.bind(index)
		if not button.pressed.is_connected(callback):
			button.pressed.connect(callback)


func _populate_legacy_buttons() -> void:
	var legacy := get_node("Choices")
	for index: int in 3:
		var button := legacy.get_child(index) as Button
		var choice: UpgradeChoice = choices[index] if index < choices.size() else null
		button.text = choice.label if choice != null else "Unavailable"
		button.disabled = not _disabled_reason(choice).is_empty()


func _legacy_select(index: int) -> void:
	if _reveal_pending or (_reveal_controller != null and _reveal_controller.is_revealing()) or selected_once or index < 0 or index >= choices.size():
		return
	var button := get_node("Choices").get_child(index) as Button
	if button.disabled:
		return
	selected_once = true
	visible = false
	choice_selected.emit(choices[index])
