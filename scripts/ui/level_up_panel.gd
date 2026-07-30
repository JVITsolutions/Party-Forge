class_name LevelUpPanel
extends Control

signal choice_selected(choice: UpgradeChoice)
signal confirmation_requested(choice: UpgradeChoice, recipient_member_id: int)

var choices: Array[UpgradeChoice] = []
var selected_once := false

var _catalog: GameCatalog
var _upgrade_service: UpgradeApplicationService
var _health_provider := Callable()
var _party: PartyManager
var _invalid_choice_keys: Dictionary = {}
var _pending_choice: UpgradeChoice
var _pending_member_id := 0
var _awaiting_application := false
var _initial_focus_card: UpgradeCard
var _tooltip_choice: UpgradeChoice


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_connect_cards()
	_connect_recipient_picker()
	_connect_confirmation()
	_connect_legacy_buttons()


func configure(
	catalog: GameCatalog,
	upgrade_service: UpgradeApplicationService,
	health_provider: Callable
) -> void:
	_catalog = catalog
	_upgrade_service = upgrade_service
	_health_provider = health_provider


func show_choices(
	exact_choices: Array[UpgradeChoice],
	party: PartyManager,
	invalid_choice_keys: Dictionary = {}
) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_connect_cards()
	_connect_recipient_picker()
	_connect_confirmation()
	_connect_legacy_buttons()
	if _catalog == null:
		_catalog = GameCatalog.load_defaults()
	if _upgrade_service == null:
		_upgrade_service = UpgradeApplicationService.new()
	choices = exact_choices.duplicate()
	_party = party
	_invalid_choice_keys = invalid_choice_keys.duplicate()
	_pending_choice = null
	_pending_member_id = 0
	_awaiting_application = false
	selected_once = false
	_hide_tooltip()
	visible = true
	_populate_offer_cards()
	_populate_legacy_buttons()
	_show_view(&"offer")
	_focus_first_enabled_card()


func complete_selection() -> void:
	_hide_tooltip()
	_awaiting_application = false
	_pending_choice = null
	_pending_member_id = 0
	visible = false


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
	var cards := get_node("ContentPanel/OfferView/Content/Cards").get_children()
	for index: int in 3:
		var card := cards[index] as UpgradeCard
		var choice: UpgradeChoice = choices[index] if index < choices.size() else null
		card.bind_choice(choice, _presentation_for(choice), _disabled_reason(choice))


func _presentation_for(choice: UpgradeChoice) -> Dictionary:
	if choice == null:
		return {"name": "Unavailable", "scope_badge": "", "rank_text": "", "summary": ""}
	if choice.kind == UpgradeChoice.Kind.AUTHORED and choice.definition != null:
		return UpgradePresentationService.card(choice.definition, _party)
	return {
		"name": choice.label,
		"scope_badge": _legacy_scope_name(choice.kind),
		"rank_text": "",
		"summary": "A foundational party progression choice.",
		"eligibility_text": "Available to the current party.",
		"recipient_text": "Applies without a character target.",
		"inheritance_text": "",
	}


func _legacy_scope_name(kind: UpgradeChoice.Kind) -> String:
	match kind:
		UpgradeChoice.Kind.RECRUIT:
			return "Recruit"
		UpgradeChoice.Kind.CLASS_RANK:
			return "Class Rank"
		UpgradeChoice.Kind.TRAIT:
			return "Trait Rank"
		UpgradeChoice.Kind.PARTY_STAT:
			return "Party"
		_:
			return "Upgrade"


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
	if _awaiting_application or choice == null:
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
		or choice == null
		or choice.kind != UpgradeChoice.Kind.AUTHORED
		or _catalog == null
		or _catalog.keywords == null
		or _party == null
	):
		_hide_tooltip()
		return
	var definition := _catalog.upgrade_by_id(choice.target_id)
	if definition == null:
		_hide_tooltip()
		return
	var rank_state := _offered_rank_state(definition)
	var content := UpgradePresentationService.tooltip(
		definition,
		int(rank_state.rank),
		PartyManager.STAT_CATALOG,
		_catalog.keywords
	)
	if bool(rank_state.varies):
		content["rank_text"] = "Offered rank varies / %d" % definition.max_rank
	_tooltip_choice = choice
	(get_node("TooltipPanel") as UpgradeTooltipPanel).show_content(content, anchor)


func _on_card_detail_dismissed(choice: UpgradeChoice) -> void:
	if choice == _tooltip_choice:
		_hide_tooltip()


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
	var tooltip := get_node_or_null("TooltipPanel") as UpgradeTooltipPanel
	if tooltip != null:
		tooltip.hide_content()


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
	if selected_once or index < 0 or index >= choices.size():
		return
	var button := get_node("Choices").get_child(index) as Button
	if button.disabled:
		return
	selected_once = true
	visible = false
	choice_selected.emit(choices[index])
