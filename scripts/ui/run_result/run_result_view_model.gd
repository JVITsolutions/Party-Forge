class_name RunResultViewModel
extends RefCounted

const RESERVED_PROVIDER_IDS: Array[StringName] = [&"outcome", &"party", &"loot"]

func pending(snapshot: RunTerminalSnapshot) -> RunResultProjectionResult:
	if snapshot == null:
		return RunResultProjectionResult.failure("terminal snapshot is unavailable")
	return RunResultProjectionResult.success(RunResultProjection.create(RunResultProjection.TerminalState.PENDING, snapshot, [], []))

func terminal_save_interrupted(snapshot: RunTerminalSnapshot, reason: String) -> RunResultProjectionResult:
	if snapshot == null or reason.strip_edges().is_empty():
		return RunResultProjectionResult.failure("terminal-save interruption requires snapshot and readable reason")
	return RunResultProjectionResult.success(RunResultProjection.create(
		RunResultProjection.TerminalState.INTERRUPTED, snapshot, [], [],
		RunResultProjection.InterruptionKind.TERMINAL_STATE_SAVE, reason,
		{"retry_terminal_save": true},
	))

func resolution_interrupted(snapshot: RunTerminalSnapshot, reason: String, recovery_safety: Variant) -> RunResultProjectionResult:
	if snapshot == null or reason.strip_edges().is_empty():
		return RunResultProjectionResult.failure("resolution interruption requires snapshot and readable reason")
	var durable: RunTerminalRecoverySafetyResult
	var preflight: RunResolutionPreflightResult
	if recovery_safety is Dictionary:
		var safety_map := recovery_safety as Dictionary
		if safety_map.get("durable") is RunTerminalRecoverySafetyResult:
			durable = safety_map.get("durable") as RunTerminalRecoverySafetyResult
		if safety_map.get("preflight") is RunResolutionPreflightResult:
			preflight = safety_map.get("preflight") as RunResolutionPreflightResult
	elif recovery_safety is RunTerminalRecoverySafetyResult:
		durable = recovery_safety as RunTerminalRecoverySafetyResult
	var typed_automatic_block := (
		preflight != null
		and preflight.automatic_only_blocked
		and preflight.failure_category == RunResolutionEvaluation.FailureCategory.STASH_AUTOMATIC_ONLY
		and preflight.mandatory_stash_slots_known
		and preflight.mandatory_stash_slots > 0
	)
	var displaced_ids: Array[String] = []
	if durable != null and durable.ok():
		displaced_ids.assign(durable.record.protected_displaced_item_ids)
	var displaced_ids_proven := displaced_ids.size() == preflight.mandatory_stash_slots if typed_automatic_block else false
	var seen_displaced: Dictionary = {}
	for item_id: String in displaced_ids:
		if item_id.strip_edges().is_empty() or seen_displaced.has(item_id):
			displaced_ids_proven = false
		seen_displaced[item_id] = true
	var durable_allowed := durable != null and durable.ok()
	var protect_allowed := durable_allowed and typed_automatic_block and displaced_ids_proven
	var displaced_count := preflight.mandatory_stash_slots if protect_allowed else 0
	return RunResultProjectionResult.success(RunResultProjection.create(
		RunResultProjection.TerminalState.INTERRUPTED, snapshot, [], [],
		RunResultProjection.InterruptionKind.RESOLUTION, reason,
		{
			"retry_resolution": true,
			"protect_displaced_gear": protect_allowed,
			"open_armoury": durable_allowed,
			"return_to_forge": durable_allowed,
			"quit_application": durable_allowed,
		},
		displaced_count,
	))

func projection_interrupted(snapshot: RunTerminalSnapshot, accepted_resolution: RunResolutionResult, reason: String) -> RunResultProjectionResult:
	if snapshot == null or accepted_resolution == null or not accepted_resolution.ok() or reason.strip_edges().is_empty():
		return RunResultProjectionResult.failure("projection interruption requires accepted resolution and readable reason")
	if accepted_resolution.profile == null or accepted_resolution.profile.profile_id != snapshot.profile_id:
		return RunResultProjectionResult.failure("accepted resolution does not match terminal snapshot")
	return RunResultProjectionResult.success(RunResultProjection.create(
		RunResultProjection.TerminalState.INTERRUPTED, snapshot, [], [],
		RunResultProjection.InterruptionKind.PROJECTION, reason,
		{"retry_projection": true},
	))

func build(snapshot: RunTerminalSnapshot, resolution: RunResolutionResult, refreshed_profile: ProfileState, providers: Array) -> RunResultProjectionResult:
	if snapshot == null or resolution == null or not resolution.ok() or refreshed_profile == null:
		return RunResultProjectionResult.failure("accepted terminal result truth is unavailable")
	if snapshot.profile_id != refreshed_profile.profile_id or resolution.profile == null or resolution.profile.profile_id != snapshot.profile_id:
		return RunResultProjectionResult.failure("refreshed profile does not match accepted terminal identity")
	var party_result := _party_projection(snapshot)
	if not String(party_result.error).is_empty():
		return RunResultProjectionResult.failure(party_result.error)
	var loot_error := _validate_loot(snapshot, resolution, refreshed_profile)
	if not loot_error.is_empty():
		return RunResultProjectionResult.failure(loot_error)
	var provider_registry := _provider_registry(providers)
	if not String(provider_registry.error).is_empty():
		return RunResultProjectionResult.failure(provider_registry.error)

	var verified_resolution := RunResolutionResult.success(refreshed_profile, resolution.duplicate, resolution.accepted_extraction, resolution.protected_displaced_item_ids)
	var outcome_entries: Array[RunRecapEntryProjection] = [
		RunRecapEntryProjection.create("Outcome", "Victory" if snapshot.outcome == RunTerminalSnapshot.Outcome.VICTORY else "Defeat", "Captured once at the terminal boundary."),
		RunRecapEntryProjection.create("Duration", _duration(snapshot.elapsed_seconds), "Authoritative elapsed run duration."),
	]
	var sections_with_order: Array[Dictionary] = [
		{"section": RunRecapSectionProjection.create(&"outcome", "RUN OUTCOME", RunRecapSectionProjection.SemanticKind.OUTCOME, outcome_entries, _outcome_summary(snapshot)), "display_order": -100, "provider_id": &"outcome"},
		{"section": party_result.section, "display_order": -100, "provider_id": &"party"},
	]
	var loot_result := RunLootRecapProvider.new().project(snapshot, verified_resolution)
	if not loot_result.ok():
		return RunResultProjectionResult.failure("required loot recap failed: %s" % loot_result.error)
	sections_with_order.append({"section": loot_result.section, "display_order": -100, "provider_id": &"loot"})

	for provider_record: Dictionary in provider_registry.records:
		var provider: Variant = provider_record.provider
		var stable_id: StringName = provider_record.provider_id
		var provider_resolution := RunResolutionResult.success(refreshed_profile, resolution.duplicate, resolution.accepted_extraction, resolution.protected_displaced_item_ids)
		var optional_result: Variant = provider.call(&"project", snapshot.copy(), provider_resolution)
		if not optional_result is RunRecapProviderResult:
			_log_optional(stable_id, "returned no typed RunRecapProviderResult")
			continue
		var typed_result := optional_result as RunRecapProviderResult
		if typed_result.is_empty():
			continue
		if not typed_result.ok():
			_log_optional(stable_id, typed_result.error)
			continue
		var section := typed_result.section
		if section == null or not section.valid() or section.section_id != stable_id:
			_log_optional(stable_id, "returned an invalid or mismatched section")
			continue
		sections_with_order.append({"section": section, "display_order": int(provider_record.display_order), "provider_id": stable_id})

	sections_with_order.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_section := left.section as RunRecapSectionProjection
		var right_section := right.section as RunRecapSectionProjection
		if left_section.semantic_kind != right_section.semantic_kind:
			return left_section.semantic_kind < right_section.semantic_kind
		if int(left.display_order) != int(right.display_order):
			return int(left.display_order) < int(right.display_order)
		return String(left.provider_id) < String(right.provider_id)
	)
	var sections: Array[RunRecapSectionProjection] = []
	for record: Dictionary in sections_with_order:
		sections.append((record.section as RunRecapSectionProjection).copy())
	var projection := RunResultProjection.create(
		RunResultProjection.TerminalState.FINALIZED, snapshot, sections, party_result.members,
		-1, "", {"restart_run": true, "return_to_forge": true, "quit_application": true},
	)
	return RunResultProjectionResult.success(projection)

func _provider_registry(providers: Array) -> Dictionary:
	var records: Array[Dictionary] = []
	var counts: Dictionary = {}
	for provider: Variant in providers:
		if provider == null or not provider.has_method(&"provider_id") or not provider.has_method(&"display_order") or not provider.has_method(&"project"):
			return {"records": [], "error": "optional provider does not implement the RunRecapProvider interface"}
		var stable_id := StringName(provider.call(&"provider_id"))
		if String(stable_id).strip_edges().is_empty():
			return {"records": [], "error": "optional provider ID must not be blank"}
		counts[stable_id] = int(counts.get(stable_id, 0)) + 1
		records.append({"provider": provider, "provider_id": stable_id, "display_order": int(provider.call(&"display_order"))})
	var sorted_ids: Array[String] = []
	for stable_id: StringName in counts:
		sorted_ids.append(String(stable_id))
	sorted_ids.sort()
	for stable_id_text: String in sorted_ids:
		var stable_id := StringName(stable_id_text)
		if stable_id in RESERVED_PROVIDER_IDS:
			return {"records": [], "error": "optional provider ID %s is reserved" % stable_id}
		if int(counts[stable_id]) > 1:
			return {"records": [], "error": "duplicate optional provider ID %s" % stable_id}
	return {"records": records, "error": ""}

func _party_projection(snapshot: RunTerminalSnapshot) -> Dictionary:
	var members: Array[RunResultPartyMemberProjection] = []
	var entries: Array[RunRecapEntryProjection] = []
	var seen: Dictionary = {}
	for member: RunTerminalPartyMemberSnapshot in snapshot.members:
		if member == null or seen.has(member.member_id):
			return {"members": [], "section": null, "error": "terminal party member identity is invalid or duplicated"}
		seen[member.member_id] = true
		var projected := RunResultPartyMemberProjection.create(member.member_id, member.display_name, member.class_id, String(member.get("class_name")), member.is_leader, member.final_level)
		if not projected.valid():
			return {"members": [], "section": null, "error": "terminal party member %s is invalid" % member.member_id}
		members.append(projected)
		var role := "Leader · " if projected.is_leader else ""
		entries.append(RunRecapEntryProjection.create(projected.display_name, "%s%s · Level %d" % [role, projected.class_label, projected.final_level], "Member %d · %s" % [projected.member_id, String(projected.class_id)]))
	var section := RunRecapSectionProjection.create(&"party", "FINAL PARTY", RunRecapSectionProjection.SemanticKind.PARTY, entries, "%d members · exact terminal order" % members.size())
	return {"members": members, "section": section, "error": "" if section.valid() else "terminal party section is invalid"}

func _validate_loot(snapshot: RunTerminalSnapshot, resolution: RunResolutionResult, profile: ProfileState) -> String:
	var accepted := resolution.accepted_extraction
	if accepted == null or not accepted.valid:
		return "accepted extraction is invalid"
	var source := snapshot.resolution_source
	var source_state := source.item_state if source != null else null
	var source_registry := source_state.registry() if source_state != null else null
	if source == null or source_registry == null:
		return "terminal source item truth is unavailable"
	var ownership_result := _profile_ownership(profile)
	if not String(ownership_result.error).is_empty():
		return ownership_result.error
	var ownership := ownership_result.state as ItemOwnershipState
	var leader := ownership.container(&"leader-loadout")
	var overflow := ownership.container(ItemSlotContainer.TERMINAL_RECOVERY_OVERFLOW_ID)
	if leader == null or overflow == null:
		return "refreshed leader loadout or Recovery Overflow is unavailable"
	var category_by_id: Dictionary = {}
	for pair: Dictionary in [
		{"name": "automatic", "ids": accepted.automatic_item_ids},
		{"name": "selected", "ids": accepted.selected_item_ids},
		{"name": "lost", "ids": accepted.lost_item_ids},
		{"name": "protected", "ids": resolution.protected_displaced_item_ids},
	]:
		for item_id: String in pair.ids:
			if item_id.strip_edges().is_empty() or category_by_id.has(item_id):
				return "accepted loot ID %s is blank, duplicated, or crosses categories" % item_id
			category_by_id[item_id] = pair.name
	var eligible_ids: Array[String] = []
	for selection: ExtractionSelection in accepted.eligible_items:
		if selection == null or selection.item_id.strip_edges().is_empty() or selection.item_id in eligible_ids:
			return "accepted eligible extraction contains invalid or duplicate identity"
		eligible_ids.append(selection.item_id)
		if source_registry.item(selection.item_id) == null:
			return "accepted eligible item %s is absent from terminal source" % selection.item_id
	var selected_and_lost := accepted.selected_item_ids.duplicate()
	selected_and_lost.append_array(accepted.lost_item_ids)
	selected_and_lost.sort()
	var sorted_eligible := eligible_ids.duplicate()
	sorted_eligible.sort()
	if selected_and_lost != sorted_eligible:
		return "selected and lost IDs do not exactly partition eligible extraction"
	for item_id: String in accepted.automatic_item_ids:
		if source_registry.item(item_id) == null or not _container_has(leader, item_id):
			return "automatic item %s is not proven in refreshed leader loadout" % item_id
	for item_id: String in accepted.selected_item_ids:
		if not _stash_has(profile, item_id):
			return "selected item %s is not proven in refreshed stash" % item_id
	for item_id: String in resolution.protected_displaced_item_ids:
		if not _container_has(overflow, item_id):
			return "protected item %s is not proven in Recovery Overflow" % item_id
	for item_id: String in accepted.lost_item_ids:
		if ownership.registry().item(item_id) != null or _ownership_has(ownership, item_id):
			return "lost item %s remains in refreshed durable profile" % item_id
	return ""

func _profile_ownership(profile: ProfileState) -> Dictionary:
	var containers: Array = [profile.leader_loadout.duplicate(true)]
	containers.append_array(profile.stash_tabs.duplicate(true))
	containers.append(profile.terminal_recovery_overflow.duplicate(true))
	var decoded := ItemOwnershipState.decode({
		"schema_version": ItemOwnershipState.SCHEMA_VERSION,
		"owner_id": profile.profile_id,
		"registry": profile.item_records.duplicate(true),
		"containers": containers,
	}, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	return {"state": decoded.state if decoded.ok() else null, "error": "" if decoded.ok() else "refreshed profile ownership is invalid: %s" % decoded.error}

func _container_has(container: ItemSlotContainer, item_id: String) -> bool:
	if container == null: return false
	for slot: int in container.occupied_slots():
		if container.item_id_at(slot) == item_id: return true
	return false

func _stash_has(profile: ProfileState, item_id: String) -> bool:
	for document: Dictionary in profile.stash_tabs:
		var decoded := ItemSlotContainer._decode(document, "stash")
		if String(decoded.error).is_empty() and _container_has(decoded.value as ItemSlotContainer, item_id):
			return true
	return false

func _ownership_has(state: ItemOwnershipState, item_id: String) -> bool:
	for container: ItemSlotContainer in state.containers():
		if _container_has(container, item_id): return true
	return false

func _duration(elapsed_seconds: float) -> String:
	var total := maxi(0, roundi(elapsed_seconds))
	var hours := total / 3600
	var minutes := (total % 3600) / 60
	var seconds := total % 60
	return "%d:%02d:%02d" % [hours, minutes, seconds] if hours > 0 else "%02d:%02d" % [minutes, seconds]

func _outcome_summary(snapshot: RunTerminalSnapshot) -> String:
	return "%s · %s" % ["Victory" if snapshot.outcome == RunTerminalSnapshot.Outcome.VICTORY else "Defeat", _duration(snapshot.elapsed_seconds)]

func _log_optional(provider_id: StringName, error: String) -> void:
	push_warning("RUN_RECAP_PROVIDER_OMITTED id=%s error=%s" % [provider_id, error.strip_edges()])
