class_name RunResultProjection
extends RefCounted

enum TerminalState { PENDING, INTERRUPTED, FINALIZED }
enum InterruptionKind { TERMINAL_STATE_SAVE, TERMINAL_REFRESH, RESOLUTION, PROJECTION }
enum PendingKind { TERMINAL_STATE_SAVE, TERMINAL_REFRESH, RESOLUTION, PROJECTION, PROTECTION, TERMINAL_COMPLETION }

var _terminal_state := TerminalState.PENDING
var terminal_state: TerminalState:
	get: return _terminal_state
var _interruption_kind := -1
var interruption_kind: int:
	get: return _interruption_kind
var _pending_kind := PendingKind.TERMINAL_STATE_SAVE
var pending_kind: PendingKind:
	get: return _pending_kind
var _readable_reason := ""
var readable_reason: String:
	get: return _readable_reason
var _snapshot: RunTerminalSnapshot
var snapshot: RunTerminalSnapshot:
	get: return _snapshot.copy() if _snapshot != null else null
var _sections: Array[RunRecapSectionProjection] = []
var sections: Array[RunRecapSectionProjection]:
	get:
		var result: Array[RunRecapSectionProjection] = []
		for section: RunRecapSectionProjection in _sections:
			result.append(section.copy())
		return result
var _party_members: Array[RunResultPartyMemberProjection] = []
var party_members: Array[RunResultPartyMemberProjection]:
	get:
		var result: Array[RunResultPartyMemberProjection] = []
		for member: RunResultPartyMemberProjection in _party_members:
			result.append(member.copy())
		return result

var retry_terminal_save_allowed := false
var retry_terminal_refresh_allowed := false
var retry_resolution_allowed := false
var retry_projection_allowed := false
var protect_displaced_gear_allowed := false
var open_armoury_allowed := false
var restart_run_allowed := false
var return_to_forge_allowed := false
var quit_application_allowed := false
var displaced_gear_count := 0

var high_contrast := false
var reduced_motion := false
var ui_scale_percent := 100
var text_scale_percent := 100

static func create(
	terminal_state_value: int,
	snapshot_value: RunTerminalSnapshot,
	section_values: Array,
	party_member_values: Array,
	interruption_kind_value: int = -1,
	readable_reason_value: String = "",
	action_values: Dictionary = {},
	displaced_count_value: int = 0,
	pending_kind_value: int = PendingKind.TERMINAL_STATE_SAVE,
) -> RunResultProjection:
	var result := RunResultProjection.new()
	result._terminal_state = terminal_state_value
	result._snapshot = snapshot_value.copy() if snapshot_value != null else null
	result._interruption_kind = interruption_kind_value
	result._pending_kind = pending_kind_value as PendingKind
	result._readable_reason = readable_reason_value.strip_edges()
	for value: Variant in section_values:
		if value is RunRecapSectionProjection:
			result._sections.append((value as RunRecapSectionProjection).copy())
	for value: Variant in party_member_values:
		if value is RunResultPartyMemberProjection:
			result._party_members.append((value as RunResultPartyMemberProjection).copy())
	result.retry_terminal_save_allowed = bool(action_values.get("retry_terminal_save", false))
	result.retry_terminal_refresh_allowed = bool(action_values.get("retry_terminal_refresh", false))
	result.retry_resolution_allowed = bool(action_values.get("retry_resolution", false))
	result.retry_projection_allowed = bool(action_values.get("retry_projection", false))
	result.protect_displaced_gear_allowed = bool(action_values.get("protect_displaced_gear", false))
	result.open_armoury_allowed = bool(action_values.get("open_armoury", false))
	result.restart_run_allowed = bool(action_values.get("restart_run", false))
	result.return_to_forge_allowed = bool(action_values.get("return_to_forge", false))
	result.quit_application_allowed = bool(action_values.get("quit_application", false))
	result.displaced_gear_count = maxi(0, displaced_count_value)
	return result

func section_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for section: RunRecapSectionProjection in _sections:
		result.append(section.section_id)
	return result

func with_visual_settings(settings: PartyForgeSettings) -> RunResultProjection:
	var result := copy()
	if settings == null:
		return result
	result.high_contrast = settings.high_contrast
	result.reduced_motion = settings.reduced_motion
	result.ui_scale_percent = clampi(settings.ui_scale_percent, 80, 150)
	result.text_scale_percent = clampi(settings.text_scale_percent, 80, 150)
	return result

func valid() -> bool:
	if _snapshot == null or _terminal_state not in [TerminalState.PENDING, TerminalState.INTERRUPTED, TerminalState.FINALIZED]:
		return false
	var actions := _action_count()
	if _terminal_state == TerminalState.PENDING:
		return _pending_kind in [PendingKind.TERMINAL_STATE_SAVE, PendingKind.TERMINAL_REFRESH, PendingKind.RESOLUTION, PendingKind.PROJECTION, PendingKind.PROTECTION, PendingKind.TERMINAL_COMPLETION] and _interruption_kind == -1 and _readable_reason.is_empty() and _sections.is_empty() and _party_members.is_empty() and actions == 0 and displaced_gear_count == 0
	if _terminal_state == TerminalState.INTERRUPTED:
		if _interruption_kind not in [InterruptionKind.TERMINAL_STATE_SAVE, InterruptionKind.TERMINAL_REFRESH, InterruptionKind.RESOLUTION, InterruptionKind.PROJECTION] or _readable_reason.is_empty() or not _sections.is_empty() or not _party_members.is_empty() or restart_run_allowed:
			return false
		if _interruption_kind == InterruptionKind.TERMINAL_STATE_SAVE:
			return retry_terminal_save_allowed and not retry_terminal_refresh_allowed and actions == 1 and displaced_gear_count == 0
		if _interruption_kind == InterruptionKind.TERMINAL_REFRESH:
			return retry_terminal_refresh_allowed and not retry_terminal_save_allowed and actions == 1 and displaced_gear_count == 0
		if _interruption_kind == InterruptionKind.PROJECTION:
			return retry_projection_allowed and actions == 1 and displaced_gear_count == 0
		if not retry_resolution_allowed or retry_terminal_save_allowed or retry_terminal_refresh_allowed or retry_projection_allowed:
			return false
		if protect_displaced_gear_allowed != (displaced_gear_count > 0):
			return false
		return true
	if _interruption_kind != -1 or _sections.is_empty() or _party_members.is_empty():
		return false
	if retry_terminal_save_allowed or retry_terminal_refresh_allowed or retry_resolution_allowed or retry_projection_allowed or protect_displaced_gear_allowed or open_armoury_allowed:
		return false
	var finalized_action_count := int(restart_run_allowed) + int(return_to_forge_allowed) + int(quit_application_allowed)
	if displaced_gear_count != 0 or (finalized_action_count != 3 and (_readable_reason.is_empty() or finalized_action_count != 1)):
		return false
	return _valid_finalized_truth()

func _valid_finalized_truth() -> bool:
	if _party_members.is_empty() or _snapshot.members.size() != _party_members.size():
		return false
	var seen_members: Dictionary = {}
	for index: int in _party_members.size():
		var member := _party_members[index]
		var snapshot_member := _snapshot.members[index]
		if member == null or not member.valid() or snapshot_member == null or seen_members.has(member.member_id):
			return false
		seen_members[member.member_id] = true
		if member.member_id != snapshot_member.member_id or member.display_name != snapshot_member.display_name or member.class_id != snapshot_member.class_id or member.class_label != String(snapshot_member.get("class_name")) or member.is_leader != snapshot_member.is_leader or member.final_level != snapshot_member.final_level:
			return false
	var seen_sections: Dictionary = {}
	var previous_kind := -1
	var outcome_index := -1
	var party_index := -1
	var loot_index := -1
	for index: int in _sections.size():
		var section := _sections[index]
		if section == null or not section.valid() or seen_sections.has(section.section_id) or int(section.semantic_kind) < previous_kind:
			return false
		seen_sections[section.section_id] = true
		previous_kind = int(section.semantic_kind)
		if section.section_id == &"outcome":
			if section.semantic_kind != RunRecapSectionProjection.SemanticKind.OUTCOME or not _valid_outcome_section(section): return false
			outcome_index = index
		elif section.section_id == &"party":
			if section.semantic_kind != RunRecapSectionProjection.SemanticKind.PARTY or not _valid_party_section(section): return false
			party_index = index
		elif section.section_id == &"loot":
			if section.semantic_kind != RunRecapSectionProjection.SemanticKind.LOOT: return false
			loot_index = index
	if outcome_index < 0 or party_index <= outcome_index or loot_index <= party_index:
		return false
	return true

func _valid_outcome_section(section: RunRecapSectionProjection) -> bool:
	var entries := section.entries
	if entries.size() != 2 or entries[0].label != "Outcome" or entries[1].label != "Duration":
		return false
	var expected_outcome := "Victory" if _snapshot.outcome == RunTerminalSnapshot.Outcome.VICTORY else "Defeat"
	return entries[0].value == expected_outcome and entries[1].value == _duration(_snapshot.elapsed_seconds)

func _valid_party_section(section: RunRecapSectionProjection) -> bool:
	var entries := section.entries
	if entries.size() != _party_members.size():
		return false
	for index: int in entries.size():
		var member := _party_members[index]
		var expected_value := "%s%s · Level %d" % ["Leader · " if member.is_leader else "", member.class_label, member.final_level]
		if entries[index].label != member.display_name or entries[index].value != expected_value:
			return false
	return true

func _duration(elapsed_seconds: float) -> String:
	var total := maxi(0, roundi(elapsed_seconds))
	var hours := total / 3600
	var minutes := (total % 3600) / 60
	var seconds := total % 60
	return "%d:%02d:%02d" % [hours, minutes, seconds] if hours > 0 else "%02d:%02d" % [minutes, seconds]

func copy() -> RunResultProjection:
	var result := create(_terminal_state, _snapshot, _sections, _party_members, _interruption_kind, _readable_reason, {
		"retry_terminal_save": retry_terminal_save_allowed,
		"retry_terminal_refresh": retry_terminal_refresh_allowed,
		"retry_resolution": retry_resolution_allowed,
		"retry_projection": retry_projection_allowed,
		"protect_displaced_gear": protect_displaced_gear_allowed,
		"open_armoury": open_armoury_allowed,
		"restart_run": restart_run_allowed,
		"return_to_forge": return_to_forge_allowed,
		"quit_application": quit_application_allowed,
	}, displaced_gear_count, _pending_kind)
	result.high_contrast = high_contrast
	result.reduced_motion = reduced_motion
	result.ui_scale_percent = ui_scale_percent
	result.text_scale_percent = text_scale_percent
	return result

func with_readable_reason(reason: String) -> RunResultProjection:
	var result := copy()
	result._readable_reason = reason.strip_edges()
	return result

func _action_count() -> int:
	var result := 0
	for allowed: bool in [retry_terminal_save_allowed, retry_terminal_refresh_allowed, retry_resolution_allowed, retry_projection_allowed, protect_displaced_gear_allowed, open_armoury_allowed, restart_run_allowed, return_to_forge_allowed, quit_application_allowed]:
		if allowed: result += 1
	return result
