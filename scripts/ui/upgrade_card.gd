class_name UpgradeCard
extends Button

signal activated(choice_key: StringName)
signal detail_requested(choice_key: StringName, anchor: Control)
signal detail_dismissed(choice_key: StringName)

const FALLBACK_ICON := "◆"
const SEMANTIC_ICON_ROOT := "res://assets/ui/living_forge/icons/tabler-3.46.0/"
const SEMANTIC_ICONS := {
	&"alert-triangle": "alert-triangle.svg",
	&"check": "check.svg",
	&"hourglass": "hourglass.svg",
	&"lock": "lock.svg",
	&"player-play": "player-play.svg",
	&"settings": "settings.svg",
	&"shield": "shield.svg",
	&"user": "user.svg",
}

var _projection: UpgradeOfferProjection
var _bound_choice_key: StringName
var _mouse_inside := false
var _focus_inside := false
var _detail_visible := false
var _action_hint := "Apply"


func _ready() -> void:
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	if not focus_entered.is_connected(_on_focus_entered):
		focus_entered.connect(_on_focus_entered)
	if not focus_exited.is_connected(_on_focus_exited):
		focus_exited.connect(_on_focus_exited)


func present(projection: UpgradeOfferProjection) -> void:
	var previous_key := _bound_choice_key
	_projection = projection.copy() if projection != null else UpgradeOfferProjection.new()
	_bound_choice_key = StringName(_projection.choice_key)
	_present_copy(_projection)
	disabled = not _projection.enabled() or _bound_choice_key.is_empty()
	_update_accessibility()
	if previous_key != _bound_choice_key:
		call_deferred(&"_reset_details_scroll_if_bound_to", _bound_choice_key)
	if _detail_visible and previous_key != _bound_choice_key:
		if not previous_key.is_empty():
			detail_dismissed.emit(previous_key)
		_detail_visible = false
	_reconcile_detail_state()


func present_preview(projection: UpgradeOfferProjection) -> void:
	if projection == null:
		return
	# Preview presentation is deliberately display-only. It never changes the final
	# activation key, disabled authority, focus, hover, or detail-source identity.
	_present_copy(projection)


func bound_choice_key() -> StringName:
	return _bound_choice_key


func _reset_details_scroll_if_bound_to(expected_choice_key: StringName) -> void:
	if _bound_choice_key != expected_choice_key:
		return
	var details := get_node_or_null("Content/DetailsScroll") as ScrollContainer
	if details != null:
		details.scroll_vertical = int(details.get_v_scroll_bar().min_value)


func set_action_hint(action_text: String) -> void:
	_action_hint = action_text.strip_edges() if not action_text.strip_edges().is_empty() else "Apply"
	_set_text("Content/Footer/Action", _action_hint)
	_update_accessibility()


func _present_copy(projection: UpgradeOfferProjection) -> void:
	_present_icon(projection.icon_id)
	_set_text("Content/Identity/Category", _category_text(projection.category_id))
	_set_text("Content/Name", projection.display_name)
	_set_text("Content/Rarity", projection.rarity_label)
	_set_text("Content/DetailsScroll/Body/Scope", projection.scope_text)
	_set_text("Content/Footer/Rank", projection.rank_text)
	_set_text("Content/DetailsScroll/Body/Summary", projection.effect_text)
	_set_text("Content/DetailsScroll/Body/Eligibility", projection.eligibility_text)
	_set_text("Content/DetailsScroll/Body/Tags/RecipientTags", _tag_text("Traits", projection.recipient_tags))
	_set_text("Content/DetailsScroll/Body/Tags/ClassTags", _tag_text("Classes", projection.class_tags))
	_set_text("Content/Footer/DisabledReason", projection.disabled_reason)
	var rarity := get_node_or_null("Content/Rarity") as Label
	if rarity != null:
		rarity.visible = not projection.rarity_label.is_empty()
	var disabled_label := get_node_or_null("Content/Footer/DisabledReason") as Label
	if disabled_label != null:
		disabled_label.visible = not projection.disabled_reason.is_empty()
	_set_text("Content/Footer/Action", _action_hint)


func _present_icon(icon_id: StringName) -> void:
	var icon := get_node_or_null("Content/Identity/Icon") as TextureRect
	var fallback := get_node_or_null("Content/Identity/FallbackIcon") as Label
	var normalized := _normalized_icon_id(icon_id)
	var file_name := String(SEMANTIC_ICONS.get(normalized, ""))
	var texture := load(SEMANTIC_ICON_ROOT + file_name) as Texture2D if not file_name.is_empty() else null
	if icon != null:
		icon.texture = texture
		icon.visible = texture != null
	if fallback != null:
		fallback.text = FALLBACK_ICON
		fallback.visible = texture == null


func _normalized_icon_id(icon_id: StringName) -> StringName:
	return StringName(String(icon_id).strip_edges().to_lower().replace("_", "-"))


func _tag_text(prefix: String, tags: Array[StringName]) -> String:
	var names := PackedStringArray()
	for tag: StringName in tags:
		var value := String(tag).replace("_", " ").replace("-", " ").strip_edges()
		if not value.is_empty():
			names.append(value.capitalize())
	return "" if names.is_empty() else "%s: %s" % [prefix, ", ".join(names)]


func _category_text(category_id: StringName) -> String:
	var value := String(category_id).replace("_", " ").strip_edges()
	return "Upgrade" if value.is_empty() else value.capitalize()


func _set_text(path: NodePath, value: Variant) -> void:
	var label := get_node_or_null(path) as Label
	if label != null:
		label.text = str(value)


func _update_accessibility() -> void:
	if _projection == null:
		accessibility_name = "Unavailable upgrade"
		accessibility_description = "No upgrade is bound."
		return
	var parts := PackedStringArray([_projection.display_name])
	if not _projection.rarity_label.strip_edges().is_empty():
		parts.append(_projection.rarity_label.strip_edges())
	for value: String in [_projection.effect_text, _projection.scope_text, _projection.rank_text, _projection.eligibility_text]:
		if not value.strip_edges().is_empty():
			parts.append(value.strip_edges())
	if not _projection.disabled_reason.is_empty():
		parts.append("Unavailable: %s" % _projection.disabled_reason)
	for tag_text: String in [_tag_text("Traits", _projection.recipient_tags), _tag_text("Classes", _projection.class_tags)]:
		if not tag_text.is_empty():
			parts.append(tag_text)
	parts.append(_action_hint)
	accessibility_name = ", ".join(parts)
	var normalized_icon := _normalized_icon_id(_projection.icon_id)
	accessibility_description = (
		"%s icon. %s" % [String(normalized_icon).replace("-", " ").capitalize(), _category_text(_projection.category_id)]
		if SEMANTIC_ICONS.has(normalized_icon)
		else "Neutral forge category symbol. %s" % _category_text(_projection.category_id)
	)


func _on_pressed() -> void:
	if not disabled and not _bound_choice_key.is_empty():
		activated.emit(_bound_choice_key)


func _on_mouse_entered() -> void:
	_mouse_inside = true
	_update_detail_state()


func _on_mouse_exited() -> void:
	_mouse_inside = false
	_update_detail_state()


func _on_focus_entered() -> void:
	_focus_inside = true
	_update_detail_state()


func _on_focus_exited() -> void:
	_focus_inside = false
	_update_detail_state()


func _reconcile_detail_state() -> void:
	if is_inside_tree():
		call_deferred(&"_update_detail_state_if_bound_to", _bound_choice_key)
		return
	_update_detail_state()


func _update_detail_state_if_bound_to(expected_choice_key: StringName) -> void:
	if _bound_choice_key == expected_choice_key:
		_update_detail_state()


func _update_detail_state() -> void:
	var should_show := (_mouse_inside or _focus_inside) and not _bound_choice_key.is_empty() and not disabled
	if should_show == _detail_visible:
		return
	_detail_visible = should_show
	if _detail_visible:
		detail_requested.emit(_bound_choice_key, self)
	else:
		detail_dismissed.emit(_bound_choice_key)
