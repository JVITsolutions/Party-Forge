class_name LevelUpPanel
extends Control

const UPGRADE_CARD_SCENE := preload("res://scenes/ui/upgrade_card.tscn")

enum State { REVEALING, CHOOSING, CHOOSING_RECIPIENT, CONFIRMING, PENDING }

signal application_requested(choice: UpgradeChoice, recipient_member_id: int)
signal recovery_requested

var choices: Array[UpgradeChoice] = []

var _catalog: GameCatalog
var _upgrade_service: UpgradeApplicationService
var _health_provider := Callable()
var _party: PartyManager
var _invalid_choice_keys: Dictionary = {}
var _choices_by_key: Dictionary = {}
var _projections_by_key: Dictionary = {}
var _pending_level_count := 1
var _state := State.CHOOSING
var _initiating_choice_key: StringName
var _pending_member_id := 0
var _initial_focus_card: UpgradeCard
var _gameplay_return_focus: Control
var _tooltip_choice_key: StringName
var _reveal_controller: LevelUpRevealController
var _final_projections: Array[UpgradeOfferProjection] = []
var _reduced_motion := true
var _reveal_request_id := 0
var _reveal_pending := false
var _reveal_layout_callback := Callable()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_reveal_controller = get_node_or_null("RevealController") as LevelUpRevealController
	if _reveal_controller != null and not _reveal_controller.resolved.is_connected(_on_reveal_resolved):
		_reveal_controller.resolved.connect(_on_reveal_resolved)
	_connect_cards()
	_connect_recipient_picker()
	_connect_confirmation()
	var retry := get_node("Frame/Content/Offer/RetryOffers") as Button
	if not retry.pressed.is_connected(_on_recovery_pressed):
		retry.pressed.connect(_on_recovery_pressed)
	var tooltip := _tooltip()
	if tooltip != null and not tooltip.dismissed.is_connected(_on_tooltip_dismissed):
		tooltip.dismissed.connect(_on_tooltip_dismissed)
	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)
	_apply_card_face_density(_current_viewport_width())
	_sync_view_focus_modes(&"")


func _process(delta: float) -> void:
	if _reveal_controller == null:
		return
	_reveal_controller.advance(delta)
	var pending_label := get_node("Frame/Content/Offer/PendingLevels") as Label
	if _reduced_motion or _reveal_controller.is_revealing():
		pending_label.modulate.a = 1.0
		return
	var pulse := (sin(_reveal_controller.elapsed_phase() * TAU) + 1.0) * 0.5
	pending_label.modulate.a = lerpf(0.75, 1.0, pulse)


func configure(catalog: GameCatalog, upgrade_service: UpgradeApplicationService, health_provider: Callable) -> void:
	_catalog = catalog
	_upgrade_service = upgrade_service
	_health_provider = health_provider


func configure_reduced_motion(reduced_motion: bool) -> void:
	_reduced_motion = reduced_motion
	(get_node("Frame/Content/Offer/PendingLevels") as Label).modulate.a = 1.0


func configure_visual_settings(settings: PartyForgeSettings) -> void:
	var resolved := settings.copy() if settings != null else PartyForgeSettings.new()
	resolved.normalize()
	theme = LivingForgeThemeCatalog.resolve(resolved.high_contrast, resolved.ui_scale_percent, resolved.text_scale_percent)
	configure_reduced_motion(resolved.reduced_motion)


func show_choices(
	exact_choices: Array[UpgradeChoice],
	party: PartyManager,
	invalid_choice_keys: Dictionary = {},
	pending_count: int = 1,
) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_capture_gameplay_focus()
	_invalidate_reveal()
	_connect_cards()
	_connect_recipient_picker()
	_connect_confirmation()
	if _catalog == null:
		_catalog = GameCatalog.load_defaults()
	if _upgrade_service == null:
		_upgrade_service = UpgradeApplicationService.new()
	choices = exact_choices.duplicate()
	_party = party
	_invalid_choice_keys = invalid_choice_keys.duplicate(true)
	_pending_level_count = maxi(pending_count, 1)
	_initiating_choice_key = &""
	_pending_member_id = 0
	_initial_focus_card = null
	_hide_tooltip()
	_clear_error()
	visible = true
	var pending_label := get_node("Frame/Content/Offer/PendingLevels") as Label
	pending_label.text = "%d %s ready" % [_pending_level_count, "upgrade" if _pending_level_count == 1 else "upgrades"]
	pending_label.visible = true
	_rebuild_offer_authority()
	_ensure_card_count(choices.size())
	_apply_card_face_density(_current_viewport_width())
	_populate_offer_cards()

	var retry := get_node("Frame/Content/Offer/RetryOffers") as Button
	if choices.is_empty():
		_state = State.CHOOSING
		retry.visible = true
		_show_view(&"offer")
		_show_error(str(_invalid_choice_keys.get(&"__empty__", "No eligible upgrades are available. Retry the offer.")))
		retry.accessibility_name = "Retry level-up offers"
		if retry.is_inside_tree():
			retry.grab_focus()
		return
	retry.visible = false
	_start_reveal()


func accept_application() -> void:
	if _state != State.PENDING:
		return
	_hide_tooltip()
	if _pending_level_count > 1:
		(get_node("Frame/Content/Pending/Status") as Label).text = "Preparing next upgrade..."
		return
	visible = false
	_invalidate_reveal()
	_clear_error()
	_pending_member_id = 0
	_initiating_choice_key = &""
	_state = State.CHOOSING
	_restore_gameplay_focus()


func reject_application(reason: String) -> void:
	if _state != State.PENDING or _initiating_choice_key.is_empty():
		return
	_pending_member_id = 0
	_state = State.CHOOSING
	_show_view(&"offer")
	_show_error(reason)
	_focus_choice(_initiating_choice_key)


func cancel_subflow() -> void:
	if _state not in [State.CHOOSING_RECIPIENT, State.CONFIRMING]:
		return
	_hide_tooltip()
	_pending_member_id = 0
	_state = State.CHOOSING
	_clear_error()
	_show_view(&"offer")
	_focus_choice(_initiating_choice_key)


func _rebuild_offer_authority() -> void:
	_choices_by_key.clear()
	_projections_by_key.clear()
	for choice: UpgradeChoice in choices:
		if choice == null:
			continue
		var key := String(choice.key())
		if _choices_by_key.has(key):
			continue
		_choices_by_key[key] = choice
		var projection := UpgradeOfferProjectionService.new().build(choice, _party, _catalog, _disabled_reason(choice))
		_projections_by_key[key] = projection


func _populate_offer_cards() -> void:
	_final_projections.clear()
	var cards := get_node("Frame/Content/Offer/CardsScroll/Cards").get_children()
	for index: int in cards.size():
		var card := cards[index] as UpgradeCard
		if card == null or not card.visible:
			continue
		var choice: UpgradeChoice = choices[index] if index < choices.size() else null
		var projection := (_projections_by_key.get(String(choice.key())) as UpgradeOfferProjection) if choice != null else UpgradeOfferProjection.new()
		var owned_projection := projection.copy()
		_final_projections.append(owned_projection)
		card.present(owned_projection)
		card.set_action_hint(_action_hint(choice))
	_configure_card_focus_neighbors()


func _action_hint(choice: UpgradeChoice) -> String:
	if choice == null:
		return "Unavailable"
	match choice.application_route():
		UpgradeChoice.ApplicationRoute.RECIPIENT_CONFIRMATION:
			return "Choose Recipient"
		UpgradeChoice.ApplicationRoute.CONTEXT_CONFIRMATION:
			return "Review Recruit"
		_:
			return "Apply"


func _disabled_reason(choice: UpgradeChoice) -> String:
	if choice == null:
		return "This offer is no longer available."
	if _invalid_choice_keys.has(choice.key()):
		var supplied: Variant = _invalid_choice_keys[choice.key()]
		return supplied if supplied is String and not String(supplied).is_empty() else "This offer is no longer available."
	if _party == null:
		return "The party is no longer available."
	if not choice.is_valid_for(_party):
		return "This offer is no longer available."
	return ""


func _start_reveal() -> void:
	_show_view(&"offer")
	var cards_scroll := get_node("Frame/Content/Offer/CardsScroll") as ScrollContainer
	cards_scroll.scroll_horizontal = int(cards_scroll.get_h_scroll_bar().min_value)
	cards_scroll.scroll_vertical = int(cards_scroll.get_v_scroll_bar().min_value)
	if _reveal_controller == null:
		_state = State.CHOOSING
		_sync_view_focus_modes(&"offer")
		_focus_first_enabled_card()
		return
	_state = State.REVEALING
	_sync_view_focus_modes(&"offer")
	var reveal_cards: Array[UpgradeCard] = []
	for card_node: Node in get_node("Frame/Content/Offer/CardsScroll/Cards").get_children():
		if card_node is UpgradeCard and card_node.visible:
			reveal_cards.append(card_node as UpgradeCard)
	var previews: Array[UpgradeOfferProjection] = []
	for projection: UpgradeOfferProjection in _final_projections:
		previews.append(projection.copy())
	var cards_row := get_node("Frame/Content/Offer/CardsScroll/Cards") as HBoxContainer
	if not cards_row.is_inside_tree():
		_reveal_controller.play(reveal_cards, _final_projections, previews, _reduced_motion)
		return
	if _reduced_motion:
		cards_row.notification(Container.NOTIFICATION_SORT_CHILDREN)
		_reveal_controller.play(reveal_cards, _final_projections, previews, true)
		return
	_reveal_pending = true
	var request_id := _reveal_request_id
	_reveal_layout_callback = _start_reveal_after_layout.bind(
			request_id,
			reveal_cards,
			_final_projections.duplicate(),
			previews,
			_reduced_motion
	)
	cards_row.sort_children.connect(_reveal_layout_callback, CONNECT_ONE_SHOT)
	cards_row.queue_sort()
	cards_row.notification(Container.NOTIFICATION_SORT_CHILDREN)


func _connect_cards() -> void:
	var cards_node := get_node_or_null("Frame/Content/Offer/CardsScroll/Cards")
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
	var cards := get_node("Frame/Content/Offer/CardsScroll/Cards") as HBoxContainer
	var needed := clampi(count, 0, 8)
	while cards.get_child_count() < needed:
		var card := UPGRADE_CARD_SCENE.instantiate() as UpgradeCard
		card.name = "Card%d" % (cards.get_child_count() + 1)
		card.size_flags_horizontal = Control.SIZE_FILL
		cards.add_child(card)
	for index: int in cards.get_child_count():
		(cards.get_child(index) as Control).visible = index < needed
	_connect_cards()
	_configure_card_focus_neighbors()


func _configure_card_focus_neighbors() -> void:
	var visible_cards: Array[Control] = []
	for child: Node in get_node("Frame/Content/Offer/CardsScroll/Cards").get_children():
		if child is UpgradeCard and child.visible and not (child as UpgradeCard).disabled:
			visible_cards.append(child as Control)
	for index: int in visible_cards.size():
		var card := visible_cards[index]
		var previous := visible_cards[index - 1] if index > 0 else visible_cards[-1]
		var next := visible_cards[index + 1] if index + 1 < visible_cards.size() else visible_cards[0]
		card.focus_neighbor_left = card.get_path_to(previous)
		card.focus_neighbor_right = card.get_path_to(next)
		card.focus_neighbor_top = card.get_path_to(card)
		card.focus_neighbor_bottom = card.get_path_to(card)


func _connect_recipient_picker() -> void:
	var picker := get_node_or_null("Frame/Content/Recipient") as UpgradeRecipientPicker
	if picker == null:
		return
	if not picker.recipient_selected.is_connected(_on_recipient_selected):
		picker.recipient_selected.connect(_on_recipient_selected)
	if not picker.cancelled.is_connected(cancel_subflow):
		picker.cancelled.connect(cancel_subflow)


func _connect_confirmation() -> void:
	var confirm := get_node_or_null("Frame/Content/Confirmation/Actions/Confirm") as Button
	var cancel := get_node_or_null("Frame/Content/Confirmation/Actions/Cancel") as Button
	if confirm != null and not confirm.pressed.is_connected(_on_confirm_pressed):
		confirm.pressed.connect(_on_confirm_pressed)
	if cancel != null and not cancel.pressed.is_connected(cancel_subflow):
		cancel.pressed.connect(cancel_subflow)
	if confirm != null and cancel != null:
		confirm.focus_neighbor_left = confirm.get_path_to(cancel)
		confirm.focus_neighbor_right = confirm.get_path_to(cancel)
		confirm.focus_neighbor_top = confirm.get_path_to(confirm)
		confirm.focus_neighbor_bottom = confirm.get_path_to(confirm)
		cancel.focus_neighbor_left = cancel.get_path_to(confirm)
		cancel.focus_neighbor_right = cancel.get_path_to(confirm)
		cancel.focus_neighbor_top = cancel.get_path_to(cancel)
		cancel.focus_neighbor_bottom = cancel.get_path_to(cancel)


func _on_card_activated(choice_key: StringName) -> void:
	if not visible or _state != State.CHOOSING or choice_key.is_empty():
		return
	if not (get_node("Frame/Content/Offer") as Control).visible or (get_node("Frame/Content/Pending") as Control).visible:
		return
	var choice := _choices_by_key.get(String(choice_key)) as UpgradeChoice
	var projection := _projections_by_key.get(String(choice_key)) as UpgradeOfferProjection
	if choice == null or projection == null or not projection.enabled():
		return
	_hide_tooltip()
	_clear_error()
	_initiating_choice_key = choice_key
	_pending_member_id = 0
	match choice.application_route():
		UpgradeChoice.ApplicationRoute.DIRECT:
			_enter_pending(choice, 0)
		UpgradeChoice.ApplicationRoute.RECIPIENT_CONFIRMATION:
			var rows := UpgradePresentationService.recipient_rows(choice.definition, _party, _health_provider)
			_state = State.CHOOSING_RECIPIENT
			_show_view(&"recipient")
			(get_node("Frame/Content/Recipient") as UpgradeRecipientPicker).show_for(choice_key, rows)
		UpgradeChoice.ApplicationRoute.CONTEXT_CONFIRMATION:
			_show_confirmation(choice, {})


func _on_recipient_selected(choice_key: StringName, member_id: int) -> void:
	if _state != State.CHOOSING_RECIPIENT or choice_key != _initiating_choice_key:
		return
	var choice := _choices_by_key.get(String(choice_key)) as UpgradeChoice
	if choice == null:
		return
	_pending_member_id = member_id
	var row := (get_node("Frame/Content/Recipient") as UpgradeRecipientPicker).recipient_row(member_id)
	_show_confirmation(choice, row)


func _show_confirmation(choice: UpgradeChoice, recipient_row: Dictionary) -> void:
	var projection := _projections_by_key.get(String(choice.key())) as UpgradeOfferProjection
	(get_node("Frame/Content/Confirmation/BodyScroll/Body/ChoiceName") as Label).text = projection.display_name
	var recipient_label := get_node("Frame/Content/Confirmation/BodyScroll/Body/Recipient") as Label
	var effect_label := get_node("Frame/Content/Confirmation/BodyScroll/Body/Effect") as Label
	if choice.application_route() == UpgradeChoice.ApplicationRoute.RECIPIENT_CONFIRMATION:
		recipient_label.text = "Recipient: %s [#%d]" % [recipient_row.get("character_name", "Unavailable"), _pending_member_id]
		var preview_lines := PackedStringArray()
		for line: Variant in recipient_row.get("preview_lines", []):
			preview_lines.append(str(line))
		effect_label.text = "\n".join(preview_lines) if not preview_lines.is_empty() else projection.effect_text
	else:
		recipient_label.text = "Recruitment choice"
		effect_label.text = projection.effect_text
	(get_node("Frame/Content/Confirmation/BodyScroll/Body/Scope") as Label).text = projection.scope_text
	var confirm := get_node("Frame/Content/Confirmation/Actions/Confirm") as Button
	var cancel := get_node("Frame/Content/Confirmation/Actions/Cancel") as Button
	confirm.disabled = false
	confirm.accessibility_name = "Confirm %s" % projection.display_name
	_state = State.CONFIRMING
	_show_view(&"confirmation")
	if cancel.is_inside_tree():
		cancel.grab_focus()


func _on_confirm_pressed() -> void:
	if _state != State.CONFIRMING or _initiating_choice_key.is_empty():
		return
	var choice := _choices_by_key.get(String(_initiating_choice_key)) as UpgradeChoice
	if choice != null:
		_enter_pending(choice, _pending_member_id)


func _enter_pending(choice: UpgradeChoice, member_id: int) -> void:
	if _state == State.PENDING or choice == null:
		return
	_state = State.PENDING
	_pending_member_id = member_id
	(get_node("Frame/Content/Pending/Status") as Label).text = "Applying %s..." % choice.label
	_show_view(&"pending")
	application_requested.emit(choice, member_id)


func _show_view(view: StringName) -> void:
	if view != &"offer" and view != &"pending":
		_hide_tooltip()
	(get_node("Frame/Content/Offer") as Control).visible = view in [&"offer", &"pending"]
	(get_node("Frame/Content/Recipient") as Control).visible = view == &"recipient"
	(get_node("Frame/Content/Confirmation") as Control).visible = view == &"confirmation"
	(get_node("Frame/Content/Pending") as Control).visible = view == &"pending"
	_sync_view_focus_modes(view)


func _sync_view_focus_modes(view: StringName) -> void:
	var offer_active := view == &"offer" and _state == State.CHOOSING
	for node: Node in get_node("Frame/Content/Offer/CardsScroll/Cards").get_children():
		if node is Button:
			_set_button_focus_enabled(node as Button, offer_active)
	var retry := get_node("Frame/Content/Offer/RetryOffers") as Button
	_set_button_focus_enabled(retry, offer_active)
	(get_node("Frame/Content/Recipient") as UpgradeRecipientPicker).set_interaction_enabled(view == &"recipient")
	var confirmation_active := view == &"confirmation"
	_set_button_focus_enabled(get_node("Frame/Content/Confirmation/Actions/Cancel") as Button, confirmation_active)
	_set_button_focus_enabled(get_node("Frame/Content/Confirmation/Actions/Confirm") as Button, confirmation_active)


func _set_button_focus_enabled(button: Button, enabled: bool) -> void:
	var focusable := enabled and button.visible and not button.disabled
	if not focusable and button.has_focus():
		button.release_focus()
	button.focus_mode = Control.FOCUS_ALL if focusable else Control.FOCUS_NONE


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _state == State.REVEALING and (event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"ui_cancel")):
		_reveal_controller.skip()
		var reveal_viewport := get_viewport()
		if reveal_viewport != null:
			reveal_viewport.set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_cancel"):
		if _state in [State.CHOOSING_RECIPIENT, State.CONFIRMING]:
			cancel_subflow()
		var cancel_viewport := get_viewport()
		if cancel_viewport != null:
			cancel_viewport.set_input_as_handled()


func _on_reveal_resolved() -> void:
	if not visible or _state != State.REVEALING:
		return
	_state = State.CHOOSING
	_sync_view_focus_modes(&"offer")
	_focus_first_enabled_card()


func _start_reveal_after_layout(
	request_id: int,
	reveal_cards: Array[UpgradeCard],
	final_projections: Array[UpgradeOfferProjection],
	preview_projections: Array[UpgradeOfferProjection],
	reduced_motion: bool,
) -> void:
	if request_id != _reveal_request_id or not visible or _reveal_controller == null:
		return
	_reveal_pending = false
	_reveal_layout_callback = Callable()
	_reveal_controller.play(reveal_cards, final_projections, preview_projections, reduced_motion)
	_sync_view_focus_modes(&"offer")


func _invalidate_reveal() -> void:
	_reveal_request_id += 1
	_reveal_pending = false
	var cards_row := get_node_or_null("Frame/Content/Offer/CardsScroll/Cards") as HBoxContainer
	if cards_row != null and _reveal_layout_callback.is_valid() and cards_row.sort_children.is_connected(_reveal_layout_callback):
		cards_row.sort_children.disconnect(_reveal_layout_callback)
	_reveal_layout_callback = Callable()
	if _reveal_controller != null:
		_reveal_controller.reset()


func _focus_first_enabled_card() -> void:
	_initial_focus_card = null
	for card_node: Node in get_node("Frame/Content/Offer/CardsScroll/Cards").get_children():
		var card := card_node as UpgradeCard
		if card != null and card.visible and not card.disabled:
			_initial_focus_card = card
			if card.is_inside_tree():
				card.grab_focus()
				call_deferred(&"_grab_offer_focus_if_active", card, card.bound_choice_key())
			return


func _focus_choice(choice_key: StringName) -> void:
	for card_node: Node in get_node("Frame/Content/Offer/CardsScroll/Cards").get_children():
		var card := card_node as UpgradeCard
		if card != null and card.visible and card.bound_choice_key() == choice_key and not card.disabled:
			_initial_focus_card = card
			if card.is_inside_tree():
				card.grab_focus()
				call_deferred(&"_grab_offer_focus_if_active", card, choice_key)
			return
	_focus_first_enabled_card()


func _grab_offer_focus_if_active(card: UpgradeCard, choice_key: StringName) -> void:
	if not visible or _state != State.CHOOSING or not is_instance_valid(card) or card.disabled:
		return
	if not (get_node("Frame/Content/Offer") as Control).visible or card.bound_choice_key() != choice_key:
		return
	card.grab_focus()
	var cards_scroll := get_node("Frame/Content/Offer/CardsScroll") as ScrollContainer
	cards_scroll.ensure_control_visible(card)
	if card == _initial_focus_card:
		cards_scroll.scroll_horizontal = int(cards_scroll.get_h_scroll_bar().min_value)
		cards_scroll.scroll_vertical = int(cards_scroll.get_v_scroll_bar().min_value)


func _on_card_detail_requested(choice_key: StringName, anchor: Control) -> void:
	if not visible or _state != State.CHOOSING or _catalog == null or _catalog.keywords == null or _party == null:
		_hide_tooltip()
		return
	var choice := _choices_by_key.get(String(choice_key)) as UpgradeChoice
	if choice == null:
		return
	var content: Dictionary
	if choice.kind == UpgradeChoice.Kind.AUTHORED:
		var definition := _catalog.upgrade_by_id(choice.target_id)
		if definition == null or not is_same(definition, choice.definition):
			return
		var rank_state := _offered_rank_state(definition)
		content = UpgradePresentationService.tooltip(definition, int(rank_state.rank), PartyManager.STAT_CATALOG, _catalog.keywords)
		if bool(rank_state.varies):
			content["rank_text"] = "Offered rank varies / %d" % definition.max_rank
	else:
		content = FoundationalUpgradePresentationService.tooltip(choice, _party, _catalog)
	if _tooltip().show_content(content, anchor, choice_key):
		_tooltip_choice_key = choice_key


func _on_card_detail_dismissed(choice_key: StringName) -> void:
	_tooltip().release_source(choice_key)


func _on_tooltip_dismissed() -> void:
	_tooltip_choice_key = &""


func _offered_rank_state(definition: UpgradeDefinition) -> Dictionary:
	if _party == null or definition == null:
		return {"rank": 1, "varies": false}
	var current_rank := _party.upgrade_rank(definition.id)
	if not definition.is_single_recipient():
		return {"rank": clampi(current_rank + 1, 1, definition.max_rank), "varies": false}
	var usable_ranks: Array[int] = []
	for member: PartyMemberState in _party.members:
		if definition.is_member_eligible(member):
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
	return {"rank": clampi(current_rank + 1, 1, definition.max_rank), "varies": varies}


func _hide_tooltip() -> void:
	_tooltip_choice_key = &""
	var tooltip := _tooltip()
	if tooltip != null:
		tooltip.force_dismiss()


func _tooltip() -> UpgradeTooltipPanel:
	return get_node_or_null("TooltipPanel") as UpgradeTooltipPanel


func _show_error(reason: String) -> void:
	var error := get_node("Frame/Content/ReadableError") as Label
	error.text = reason
	error.visible = not reason.is_empty()
	error.accessibility_name = "Level-up message: %s" % reason


func _clear_error() -> void:
	_show_error("")


func _on_recovery_pressed() -> void:
	if _state == State.CHOOSING and choices.is_empty():
		recovery_requested.emit()


func _capture_gameplay_focus() -> void:
	if not is_inside_tree():
		return
	var current := get_viewport().gui_get_focus_owner()
	if current != null and not is_ancestor_of(current):
		_gameplay_return_focus = current


func _restore_gameplay_focus() -> void:
	var disabled := _gameplay_return_focus is BaseButton and (_gameplay_return_focus as BaseButton).disabled
	if is_instance_valid(_gameplay_return_focus) and _gameplay_return_focus.is_inside_tree() and _gameplay_return_focus.visible and not disabled:
		_gameplay_return_focus.grab_focus()
	_gameplay_return_focus = null


func _on_viewport_size_changed() -> void:
	_apply_card_face_density(_current_viewport_width())


func _current_viewport_width() -> float:
	return get_viewport_rect().size.x if is_inside_tree() else float(ProjectSettings.get_setting("display/window/size/viewport_width", 1920))


func _apply_card_face_density(_viewport_width: float) -> void:
	# Compact layouts remove ornamental whitespace, never scope, eligibility, rank,
	# effect, category, or action meaning.
	for child: Node in get_node("Frame/Content/Offer/CardsScroll/Cards").get_children():
		if not (child is UpgradeCard):
			continue
		for label_name: String in ["Identity", "Name", "Scope", "Rank", "Summary", "Eligibility", "Action"]:
			var semantic := child.get_node_or_null("Content/%s" % label_name) as Control
			if semantic != null:
				semantic.visible = true
