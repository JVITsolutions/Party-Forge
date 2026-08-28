class_name RunSetupLobbyViewModel
extends RefCounted

const UNAVAILABLE_COPY := "Class selection is temporarily unavailable."
const NO_SELECTION_COPY := "Choose a class to begin your run."
const CHECKING_COPY := "Checking class loadout."
const READY_COPY := "Ready to begin your run."
const NEEDS_ATTENTION_COPY := "Review your equipped items before starting."
const STARTING_COPY := "Starting your run."

static func build(
	profile_value: Variant,
	catalog_value: Variant,
	selected_class_id_value: StringName,
	previewed_class_id_value: StringName,
	compatibility_value: Variant,
	_safe_player_copy: Variant,
	starting: Variant,
) -> RunSetupLobbyProjection:
	var seats := _seats()
	var profile := profile_value as ProfileState if profile_value is ProfileState else null
	var catalog := catalog_value as GameCatalog if catalog_value is GameCatalog else null
	if not _profile_is_completed(profile) or not _catalog_is_usable(catalog):
		return RunSetupLobbyProjection.create(seats, [], &"", &"", RunSetupLobbyProjection.State.UNAVAILABLE, UNAVAILABLE_COPY)
	if selected_class_id_value.is_empty():
		return RunSetupLobbyProjection.create(seats, _class_values(catalog, &"", null), &"", previewed_class_id_value, RunSetupLobbyProjection.State.NO_SELECTION, NO_SELECTION_COPY)
	var selected_definition := catalog.class_by_id(selected_class_id_value)
	var previewed_definition := catalog.class_by_id(previewed_class_id_value)
	if selected_definition == null or previewed_definition == null:
		return RunSetupLobbyProjection.create(seats, [], &"", &"", RunSetupLobbyProjection.State.UNAVAILABLE, UNAVAILABLE_COPY)
	var compatibility := compatibility_value as LoadoutCompatibilityProjection if compatibility_value is LoadoutCompatibilityProjection else null
	if compatibility != null and (not compatibility.valid or compatibility.selected_class_id != selected_class_id_value):
		return RunSetupLobbyProjection.create(seats, _class_values(catalog, selected_class_id_value, compatibility), selected_class_id_value, previewed_class_id_value, RunSetupLobbyProjection.State.UNAVAILABLE, UNAVAILABLE_COPY)
	var class_values := _class_values(catalog, selected_class_id_value, compatibility)
	var state := _lobby_state(compatibility, starting is bool and starting)
	return RunSetupLobbyProjection.create(seats, class_values, selected_class_id_value, previewed_class_id_value, state, _status_for(state))

static func _seats() -> Array[RunSetupSeatProjection]:
	return [
		RunSetupSeatProjection.active(1, "P1"),
		RunSetupSeatProjection.coming_soon(2),
		RunSetupSeatProjection.coming_soon(3),
		RunSetupSeatProjection.coming_soon(4),
	]

static func _profile_is_completed(profile: ProfileState) -> bool:
	return profile != null and profile.schema_version == ProfileState.SCHEMA_VERSION and not profile.profile_id.strip_edges().is_empty() and not profile.display_name.strip_edges().is_empty() and profile.prologue_state == ProfileState.PrologueState.COMPLETED

static func _catalog_is_usable(catalog: GameCatalog) -> bool:
	if catalog == null or catalog.classes.is_empty():
		return false
	for definition: ClassDefinition in catalog.classes:
		if definition == null or definition.id.is_empty() or definition.display_name.strip_edges().is_empty() or definition.primary_attack == null or definition.primary_attack.id.is_empty():
			return false
		if int(definition.role) < 0 or int(definition.role) >= ClassDefinition.Role.size():
			return false
		for trait_id: StringName in definition.traits:
			if catalog.trait_by_id(trait_id) == null:
				return false
	return true

static func _class_values(catalog: GameCatalog, selected_id: StringName, compatibility: LoadoutCompatibilityProjection) -> Array[RunSetupClassProjection]:
	var result: Array[RunSetupClassProjection] = []
	for definition: ClassDefinition in catalog.classes:
		var trait_names: Array[String] = []
		for trait_id: StringName in definition.traits:
			trait_names.append(catalog.trait_by_id(trait_id).display_name)
		var compatibility_state := RunSetupClassProjection.Compatibility.UNKNOWN
		var compatibility_copy: Dictionary = {}
		if definition.id == selected_id:
			compatibility_state = _compatibility_state(compatibility)
			compatibility_copy = _compatibility_copy(compatibility, compatibility_state)
		result.append(RunSetupClassProjection.create(
			definition.id, definition.display_name, _role_label(definition.role), definition.color, trait_names,
			_humanize_action_id(definition.primary_attack.id), compatibility_state, compatibility_copy,
		))
	return result

static func _compatibility_state(compatibility: LoadoutCompatibilityProjection) -> RunSetupClassProjection.Compatibility:
	if compatibility == null:
		return RunSetupClassProjection.Compatibility.UNKNOWN
	if not compatibility.valid:
		return RunSetupClassProjection.Compatibility.UNAVAILABLE
	if compatibility.incompatible_items.is_empty():
		return RunSetupClassProjection.Compatibility.COMPATIBLE
	return RunSetupClassProjection.Compatibility.NEEDS_ATTENTION

static func _compatibility_copy(compatibility: LoadoutCompatibilityProjection, state: RunSetupClassProjection.Compatibility) -> Dictionary:
	if compatibility == null or not compatibility.valid:
		return {}
	return {
		"incompatible_item_count": compatibility.incompatible_items.size(),
		"summary": READY_COPY if state == RunSetupClassProjection.Compatibility.COMPATIBLE else NEEDS_ATTENTION_COPY,
	}

static func _lobby_state(compatibility: LoadoutCompatibilityProjection, starting: bool) -> RunSetupLobbyProjection.State:
	if compatibility == null:
		return RunSetupLobbyProjection.State.CHECKING
	if not compatibility.valid:
		return RunSetupLobbyProjection.State.UNAVAILABLE
	if starting:
		return RunSetupLobbyProjection.State.STARTING
	return RunSetupLobbyProjection.State.READY if compatibility.incompatible_items.is_empty() else RunSetupLobbyProjection.State.NEEDS_ATTENTION

static func _status_for(state: RunSetupLobbyProjection.State) -> String:
	match state:
		RunSetupLobbyProjection.State.CHECKING:
			return CHECKING_COPY
		RunSetupLobbyProjection.State.READY:
			return READY_COPY
		RunSetupLobbyProjection.State.NEEDS_ATTENTION:
			return NEEDS_ATTENTION_COPY
		RunSetupLobbyProjection.State.STARTING:
			return STARTING_COPY
		_:
			return UNAVAILABLE_COPY

static func _role_label(role: ClassDefinition.Role) -> String:
	match role:
		ClassDefinition.Role.FRONTLINE:
			return "Frontline"
		ClassDefinition.Role.MIDLINE:
			return "Midline"
		ClassDefinition.Role.BACKLINE:
			return "Backline"
		ClassDefinition.Role.SUPPORT:
			return "Support"
		_:
			return ""

static func _humanize_action_id(action_id: StringName) -> String:
	var words := String(action_id).replace("_", " ").split(" ", false)
	for index: int in words.size():
		words[index] = (words[index] as String).capitalize()
	return " ".join(words)
