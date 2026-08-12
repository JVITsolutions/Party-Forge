class_name PartyManager
extends Node

signal member_added(member: PartyMemberState)
signal class_rank_changed(class_id: StringName, rank: int)
signal active_traits_changed(tiers: Dictionary)
signal upgrades_changed
signal stats_changed(member_id: int)

const MAX_PARTY_SIZE := 4
const PARTY_STAT_IDS: Array[StringName] = [&"max_health", &"damage", &"move_speed", &"attack_speed", &"pickup_radius"]
const DEFAULT_UPGRADE_TUNING: UpgradeTuning = preload("res://data/upgrades/default_upgrades.tres")
const DEFAULT_ATTRIBUTE_PROJECTION: AttributeProjectionTuning = preload("res://data/stats/default_attribute_projection.tres")
const STAT_CATALOG: StatCatalog = preload("res://data/stats/core_stats.tres")
const CANDIDATE_ACTION_VALIDATION := preload("res://scripts/combat/candidate_action_validation_service.gd")
var members: Array[PartyMemberState] = []
var class_ranks: Dictionary = {}
var trait_definitions: Array[TraitDefinition] = []
var active_tiers: Dictionary = {}
var party_stat_ranks: Dictionary = {}
var trait_upgrade_ranks: Dictionary = {}
var _party_upgrade_ranks: Dictionary = {}
var _party_upgrade_definitions: Dictionary = {}
var _party_upgrade_sources: Dictionary = {}
var party_upgrade_ranks: Dictionary:
	get:
		return _party_upgrade_ranks.duplicate()
var upgrade_tuning: UpgradeTuning = DEFAULT_UPGRADE_TUNING
var combat_rng: CombatRng
var damage_types: DamageTypeCatalog
var _capacity_policy := PartyCapacityPolicy.new(MAX_PARTY_SIZE)
var _identity_seed := 0
var _fallback_names: CharacterNamePool
var _stat_revision := 0
var _member_stat_revision: Dictionary = {}
var _stat_cache: Dictionary = {}
var _action_stat_cache: Dictionary = {}
var _active_weapon_by_member: Dictionary = {}
var _member_source_refresh_coordinator: Callable
var _member_source_refresh_authority: RefCounted
var _equipment_projection_publisher: Callable

func _init() -> void:
	for stat_id: StringName in PARTY_STAT_IDS:
		party_stat_ranks[stat_id] = 0

func initialize(leader_class: ClassDefinition, traits: Array[TraitDefinition], tuning: UpgradeTuning = null) -> void:
	_member_source_refresh_coordinator = Callable()
	_member_source_refresh_authority = null
	_equipment_projection_publisher = Callable()
	_active_weapon_by_member.clear()
	_member_stat_revision.clear()
	_stat_cache.clear()
	_action_stat_cache.clear()
	members.clear(); class_ranks.clear(); active_tiers.clear(); trait_upgrade_ranks.clear(); _party_upgrade_ranks.clear(); _party_upgrade_definitions.clear(); _party_upgrade_sources.clear(); trait_definitions = traits
	upgrade_tuning = tuning if tuning != null else DEFAULT_UPGRADE_TUNING
	for stat_id: StringName in PARTY_STAT_IDS:
		party_stat_ranks[stat_id] = 0
	_append_member(leader_class, true)

func configure_identity(run_seed: int, fallback_names: CharacterNamePool) -> void:
	_identity_seed = run_seed
	_fallback_names = fallback_names

func configure_capacity(policy: PartyCapacityPolicy) -> void:
	_capacity_policy = policy if policy != null else PartyCapacityPolicy.new(MAX_PARTY_SIZE)

func capacity() -> int:
	return _capacity_policy.capacity()

func can_recruit(additional_members: int = 1) -> bool:
	return _capacity_policy.can_add(members.size(), additional_members)

func recruit(definition: ClassDefinition) -> bool:
	if definition == null or not can_recruit():
		return false

	var candidate_member := _build_member(definition, false)
	var candidate_members: Array[PartyMemberState] = []
	candidate_members.assign(members)
	candidate_members.append(candidate_member)
	var candidate_class_ranks := class_ranks.duplicate()
	if not candidate_class_ranks.has(definition.id):
		candidate_class_ranks[definition.id] = 1
	var candidate_active_tiers := _trait_tiers_for_members(candidate_members)

	for member: PartyMemberState in candidate_members:
		if not _validate_candidate_member_sources_for_state(
			member,
			member._owned_modifier_sources(),
			_party_upgrade_definitions,
			_party_upgrade_sources,
			candidate_class_ranks,
			candidate_active_tiers,
		):
			return false

	members.append(candidate_member)
	class_ranks = candidate_class_ranks
	var traits_changed := candidate_active_tiers != active_tiers
	active_tiers = candidate_active_tiers
	_invalidate_all_members()
	if traits_changed:
		active_traits_changed.emit(active_tiers.duplicate())
	member_added.emit(candidate_member)
	return true

func member_by_id(member_id: int) -> PartyMemberState:
	for member: PartyMemberState in members:
		if member.member_id == member_id:
			return member
	return null

func member_base_values(member_id: int) -> Dictionary:
	var member := member_by_id(member_id)
	return member.class_definition.stat_base_values() if member != null else {}

func member_capabilities(member_id: int) -> Array[StringName]:
	var member := member_by_id(member_id)
	return member.capability_tags.duplicate() if member != null else []

func member_sources_without_equipment(member_id: int) -> Array[StatModifierSource]:
	var member := member_by_id(member_id)
	var result: Array[StatModifierSource] = []
	if member == null:
		return result
	for source: StatModifierSource in _sources_for(member):
		if source == null or source.source_type != &"equipment":
			result.append(source)
	return result

func stat_revision() -> int:
	return _stat_revision

func active_weapon_snapshot(member_id: int) -> ActiveWeaponDamageSnapshot:
	var snapshot := _active_weapon_by_member.get(member_id) as ActiveWeaponDamageSnapshot
	return snapshot.copy() if snapshot != null else null

func bind_member_source_refresh_coordinator(
	coordinator: Callable,
	equipment_projection_publisher: Callable = Callable(),
) -> RefCounted:
	if not coordinator.is_valid():
		return null
	if _member_source_refresh_coordinator.is_valid() or _member_source_refresh_authority != null:
		return null
	_member_source_refresh_coordinator = coordinator
	_equipment_projection_publisher = equipment_projection_publisher if equipment_projection_publisher.is_valid() else Callable()
	_member_source_refresh_authority = RefCounted.new()
	return _member_source_refresh_authority

func unbind_member_source_refresh_coordinator(coordinator: Callable, authority: RefCounted) -> void:
	if (
		authority != null
		and is_same(authority, _member_source_refresh_authority)
		and _member_source_refresh_coordinator == coordinator
	):
		_member_source_refresh_coordinator = Callable()
		_member_source_refresh_authority = null
		_equipment_projection_publisher = Callable()

func owns_member_source_refresh_coordinator(coordinator: Callable, authority: RefCounted) -> bool:
	return (
		authority != null
		and is_same(authority, _member_source_refresh_authority)
		and coordinator.is_valid()
		and _member_source_refresh_coordinator == coordinator
	)

func stats_for(member_id: int) -> ResolvedStatSnapshot:
	var member := member_by_id(member_id)
	if member == null:
		return null
	var member_revision := _effective_revision_for_member(member_id)
	if _stat_cache.has(member_id):
		var cached := _stat_cache[member_id] as ResolvedStatSnapshot
		if cached != null and cached.revision == member_revision:
			return cached
		_stat_cache.erase(member_id)
	var resolution := MemberStatResolutionService.resolve(
		member_id,
		STAT_CATALOG,
		member.class_definition.stat_base_values(),
		member.capability_tags,
		_sources_for(member),
		[],
		member_revision,
		DEFAULT_ATTRIBUTE_PROJECTION,
	)
	if not resolution.ok():
		push_error(resolution.error)
		return null
	var snapshot := resolution.final_stats
	_stat_cache[member_id] = snapshot
	return snapshot

func configure_combat(rng: CombatRng, types: DamageTypeCatalog) -> void:
	combat_rng = rng
	damage_types = types

func stats_for_action(member_id: int, action_tags: Array[StringName]) -> ResolvedStatSnapshot:
	var member := member_by_id(member_id)
	if member == null:
		return null
	var normalized := _normalized_tags(action_tags)
	var parts := PackedStringArray()
	for tag: StringName in normalized:
		parts.append(String(tag))
	var key := "%d|%s" % [member_id, ",".join(parts)]
	var member_revision := _effective_revision_for_member(member_id)
	if _action_stat_cache.has(key):
		var cached := _action_stat_cache[key] as ResolvedStatSnapshot
		if cached != null and cached.revision == member_revision:
			return cached
		_action_stat_cache.erase(key)
	var resolution := MemberStatResolutionService.resolve(
		member_id,
		STAT_CATALOG,
		member.class_definition.stat_base_values(),
		member.capability_tags,
		_sources_for(member),
		normalized,
		member_revision,
		DEFAULT_ATTRIBUTE_PROJECTION,
	)
	if not resolution.ok():
		push_error(resolution.error)
		return null
	var snapshot := resolution.final_stats
	_action_stat_cache[key] = snapshot
	return snapshot

func add_member_source(member_id: int, source: StatModifierSource) -> bool:
	var member := member_by_id(member_id)
	if member == null or source == null:
		return false
	if _member_source_refresh_authority != null:
		if source.source_type == &"equipment" or not _member_source_refresh_coordinator.is_valid():
			return false
		return bool(_member_source_refresh_coordinator.call(member_id, source))
	var candidate_sources := member.modifier_sources
	candidate_sources.append(source)
	if not _validate_candidate_member_sources(member_id, candidate_sources):
		return false
	member._add_modifier_source(source)
	_invalidate_member(member_id)
	return true

func replace_member_source(member_id: int, source: StatModifierSource) -> bool:
	var member := member_by_id(member_id)
	if member == null or source == null:
		return false
	if _member_source_refresh_authority != null:
		if source.source_type == &"equipment" or not _member_source_refresh_coordinator.is_valid():
			return false
		return bool(_member_source_refresh_coordinator.call(member_id, source))
	var candidate_sources := _sources_after_replace(member.modifier_sources, source)
	if not _validate_candidate_member_sources(member_id, candidate_sources):
		return false
	member._replace_modifier_source(source)
	_invalidate_member(member_id)
	return true

## Replaces one canonical equipment source and weapon snapshot per member as one observable transition.
## Returns zero on success, or the rejected member ID. Invalid non-member keys return -1.
func replace_member_equipment_projections_atomically(
	projections_by_member: Dictionary,
	authority: RefCounted = null,
) -> int:
	if not _equipment_authority_is_valid(authority) or projections_by_member.is_empty():
		return -1
	var member_ids: Array[int] = []
	for member_id_value: Variant in projections_by_member:
		if typeof(member_id_value) != TYPE_INT:
			return -1
		member_ids.append(int(member_id_value))
	member_ids.sort()
	var candidate_revision := _stat_revision + 1
	for member_id: int in member_ids:
		var projection_value: Variant = projections_by_member[member_id]
		if not projection_value is Dictionary:
			return member_id if member_id > 0 else -1
		var projection := projection_value as Dictionary
		if projection.size() != 2 or not projection.has("source") or not projection.has("weapon"):
			return member_id if member_id > 0 else -1
		var source_value: Variant = projection["source"]
		var weapon_value: Variant = projection["weapon"]
		if not source_value is StatModifierSource or (weapon_value != null and not weapon_value is ActiveWeaponDamageSnapshot):
			return member_id if member_id > 0 else -1
		if not _equipment_projection_is_valid(
			member_id,
			source_value as StatModifierSource,
			weapon_value as ActiveWeaponDamageSnapshot,
			authority,
			candidate_revision,
		):
			return member_id if member_id > 0 else -1

	var previous_sources: Dictionary = {}
	var previous_weapons: Dictionary = {}
	for member_id: int in member_ids:
		previous_sources[member_id] = member_by_id(member_id).modifier_sources
		previous_weapons[member_id] = active_weapon_snapshot(member_id)
	for member_id: int in member_ids:
		var projection := projections_by_member[member_id] as Dictionary
		if not _commit_equipment_projection_without_invalidation(
			member_id,
			projection["source"] as StatModifierSource,
			projection["weapon"] as ActiveWeaponDamageSnapshot,
		):
			_restore_equipment_projections(member_ids, previous_sources, previous_weapons)
			return member_id
	if not _publish_accepted_equipment_projections(member_ids):
		_restore_equipment_projections(member_ids, previous_sources, previous_weapons)
		return -1
	_invalidate_members(member_ids)
	return 0

## Commits one canonical equipment source and weapon snapshot as an authorized member-local transition.
func replace_member_equipment_projection_atomically(
	member_id: int,
	equipment_source: StatModifierSource,
	weapon: ActiveWeaponDamageSnapshot,
	authority: RefCounted = null,
) -> bool:
	if not _equipment_projection_is_valid(member_id, equipment_source, weapon, authority, _stat_revision + 1):
		return false
	var previous_sources := member_by_id(member_id).modifier_sources
	var previous_weapon := active_weapon_snapshot(member_id)
	if not _commit_equipment_projection_without_invalidation(member_id, equipment_source, weapon):
		_restore_member_sources_without_invalidation(member_id, previous_sources)
		_restore_weapon_without_invalidation(member_id, previous_weapon)
		return false
	if not _publish_accepted_equipment_projections([member_id]):
		_restore_member_sources_without_invalidation(member_id, previous_sources)
		_restore_weapon_without_invalidation(member_id, previous_weapon)
		return false
	_invalidate_member(member_id)
	return true

## Commits one candidate non-equipment source and its recomputed equipment projection
## as one observable member-local stat transition.
func replace_member_source_with_equipment_atomically(
	member_id: int,
	member_source: StatModifierSource,
	equipment_source: StatModifierSource,
	weapon: ActiveWeaponDamageSnapshot = null,
	authority: RefCounted = null,
) -> bool:
	var member := member_by_id(member_id)
	if (
		not _equipment_authority_is_valid(authority)
		or member == null
		or member_source == null
		or member_source.source_type == &"equipment"
		or member_source.owner_member_id != member_id
		or equipment_source == null
		or equipment_source.source_type != &"equipment"
		or equipment_source.id != StringName("equipment_member_%d" % member_id)
		or equipment_source.owner_member_id != member_id
		or member_source.id == equipment_source.id
	):
		return false
	var candidate_revision := _stat_revision + 1
	var candidate_sources := _sources_after_replace(member.modifier_sources, member_source)
	candidate_sources = _sources_after_replace(candidate_sources, equipment_source)
	if (
		not _weapon_snapshot_is_valid(member_id, weapon, candidate_revision)
		or not _validate_candidate_member_sources(member_id, candidate_sources, candidate_revision, weapon)
	):
		return false
	var previous_sources := member.modifier_sources
	var previous_weapon := active_weapon_snapshot(member_id)
	if (
		not _commit_member_source_without_invalidation(member_id, member_source)
		or not _commit_equipment_projection_without_invalidation(member_id, equipment_source, weapon)
	):
		_restore_member_sources_without_invalidation(member_id, previous_sources)
		_restore_weapon_without_invalidation(member_id, previous_weapon)
		return false
	if not _publish_accepted_equipment_projections([member_id]):
		_restore_member_sources_without_invalidation(member_id, previous_sources)
		_restore_weapon_without_invalidation(member_id, previous_weapon)
		return false
	_invalidate_member(member_id)
	return true

func _equipment_authority_is_valid(authority: RefCounted) -> bool:
	return (
		authority != null
		and is_same(authority, _member_source_refresh_authority)
		and _member_source_refresh_coordinator.is_valid()
		and _equipment_projection_publisher.is_valid()
	)

func _equipment_projection_is_valid(
	member_id: int,
	equipment_source: StatModifierSource,
	weapon: ActiveWeaponDamageSnapshot,
	authority: RefCounted,
	candidate_revision: int,
) -> bool:
	var member := member_by_id(member_id)
	if (
		not _equipment_authority_is_valid(authority)
		or member == null
		or equipment_source == null
		or equipment_source.source_type != &"equipment"
		or equipment_source.id != StringName("equipment_member_%d" % member_id)
		or equipment_source.owner_member_id != member_id
	):
		return false
	var candidate_sources := _sources_after_replace(member.modifier_sources, equipment_source)
	return (
		_weapon_snapshot_is_valid(member_id, weapon, candidate_revision)
		and _validate_candidate_member_sources(member_id, candidate_sources, candidate_revision, weapon)
	)

func _weapon_snapshot_is_valid(
	member_id: int,
	weapon: ActiveWeaponDamageSnapshot,
	candidate_revision: int,
) -> bool:
	if weapon == null:
		return true
	if (
		weapon.member_id != member_id
		or weapon.revision != candidate_revision
		or weapon.item_id.strip_edges().is_empty()
		or weapon.base_id.is_empty()
		or weapon.components.is_empty()
	):
		return false
	var base := GameCatalog.EQUIPMENT_CATALOG.definition(weapon.base_id)
	if base == null or base.weapon_damage_profile == null or &"main_hand" not in base.compatible_slot_ids:
		return false
	var seen_types: Dictionary = {}
	for component: ItemBaseDamageComponent in weapon.components:
		if component == null or not component.validate(GameCatalog.DAMAGE_TYPES).is_empty() or seen_types.has(component.damage_type_id):
			return false
		seen_types[component.damage_type_id] = true
	return true

func _commit_equipment_projection_without_invalidation(
	member_id: int,
	equipment_source: StatModifierSource,
	weapon: ActiveWeaponDamageSnapshot,
) -> bool:
	if not _commit_member_source_without_invalidation(member_id, equipment_source):
		return false
	return _commit_weapon_without_invalidation(member_id, weapon)

func _commit_weapon_without_invalidation(member_id: int, weapon: ActiveWeaponDamageSnapshot) -> bool:
	if member_by_id(member_id) == null:
		return false
	if weapon == null:
		_active_weapon_by_member.erase(member_id)
	else:
		_active_weapon_by_member[member_id] = weapon.copy()
	return true

func _restore_weapon_without_invalidation(member_id: int, weapon: ActiveWeaponDamageSnapshot) -> void:
	if weapon == null:
		_active_weapon_by_member.erase(member_id)
	else:
		_active_weapon_by_member[member_id] = weapon.copy()

func _restore_equipment_projections(
	member_ids: Array[int],
	previous_sources: Dictionary,
	previous_weapons: Dictionary,
) -> void:
	for member_id: int in member_ids:
		_restore_member_sources_without_invalidation(
			member_id,
			previous_sources[member_id] as Array[StatModifierSource],
		)
		_restore_weapon_without_invalidation(
			member_id,
			previous_weapons[member_id] as ActiveWeaponDamageSnapshot,
		)

func _publish_accepted_equipment_projections(member_ids: Array[int]) -> bool:
	return _equipment_projection_publisher.is_valid() and bool(_equipment_projection_publisher.call(member_ids.duplicate()))

func _commit_member_source_without_invalidation(member_id: int, source: StatModifierSource) -> bool:
	var member := member_by_id(member_id)
	if member == null or source == null:
		return false
	member._replace_modifier_source(source)
	return true

func _sources_after_replace(
	current_sources: Array[StatModifierSource],
	source: StatModifierSource,
) -> Array[StatModifierSource]:
	var candidate_sources := current_sources.duplicate()
	for index: int in candidate_sources.size():
		var current: StatModifierSource = candidate_sources[index]
		if current != null and source != null and current.id == source.id:
			candidate_sources[index] = source
			return candidate_sources
	candidate_sources.append(source)
	return candidate_sources

func _validate_candidate_member_sources(
	member_id: int,
	candidate_sources: Array[StatModifierSource],
	candidate_revision: int = -1,
	candidate_weapon: Variant = false,
) -> bool:
	return _validate_candidate_member_sources_for_party_upgrades(
		member_id,
		candidate_sources,
		_party_upgrade_definitions,
		_party_upgrade_sources,
		candidate_revision,
		candidate_weapon,
	)

func _validate_candidate_member_sources_for_party_upgrades(
	member_id: int,
	candidate_sources: Array[StatModifierSource],
	candidate_party_upgrade_definitions: Dictionary,
	candidate_party_upgrade_sources: Dictionary,
	candidate_revision: int = -1,
	candidate_weapon: Variant = false,
) -> bool:
	var member := member_by_id(member_id)
	if member == null:
		return false
	return _validate_candidate_member_sources_for_state(
		member,
		candidate_sources,
		candidate_party_upgrade_definitions,
		candidate_party_upgrade_sources,
		class_ranks,
		active_tiers,
		candidate_revision,
		candidate_weapon,
	)

func _validate_candidate_member_sources_for_state(
	member: PartyMemberState,
	candidate_sources: Array[StatModifierSource],
	candidate_party_upgrade_definitions: Dictionary,
	candidate_party_upgrade_sources: Dictionary,
	candidate_class_ranks: Dictionary,
	candidate_active_tiers: Dictionary,
	candidate_revision: int = -1,
	candidate_weapon: Variant = false,
) -> bool:
	if member == null:
		return false
	var validation_errors := StatResolver.validate_sources(STAT_CATALOG, candidate_sources)
	if not validation_errors.is_empty():
		for error: String in validation_errors:
			push_error(error)
		return false
	var equipment_count := 0
	var canonical_equipment_id := StringName("equipment_member_%d" % member.member_id)
	for source: StatModifierSource in candidate_sources:
		if source.source_type != &"equipment":
			continue
		equipment_count += 1
		if source.id != canonical_equipment_id or source.owner_member_id != member.member_id:
			return false
	if equipment_count > 1:
		return false
	var normalized_candidate_sources: Array[StatModifierSource] = []
	for source: StatModifierSource in candidate_sources:
		normalized_candidate_sources.append(member._normalized_modifier_source_copy(source))
	var effective_candidate_sources := _sources_for_owned_with_state(
		member,
		normalized_candidate_sources,
		candidate_party_upgrade_definitions,
		candidate_party_upgrade_sources,
		candidate_class_ranks,
		candidate_active_tiers,
	)
	var resolution_revision := candidate_revision if candidate_revision >= 0 else _stat_revision
	var action_weapon: ActiveWeaponDamageSnapshot
	if candidate_weapon is ActiveWeaponDamageSnapshot:
		action_weapon = (candidate_weapon as ActiveWeaponDamageSnapshot).copy()
	elif candidate_weapon == null:
		action_weapon = null
	else:
		action_weapon = active_weapon_snapshot(member.member_id)
		if action_weapon != null and action_weapon.revision != resolution_revision:
			action_weapon = ActiveWeaponDamageSnapshot.create(
				action_weapon.member_id,
				action_weapon.item_id,
				action_weapon.base_id,
				action_weapon.components,
				resolution_revision,
			)
	var resolution := MemberStatResolutionService.resolve(
		member.member_id,
		STAT_CATALOG,
		member.class_definition.stat_base_values(),
		member.capability_tags,
		effective_candidate_sources,
		[],
		resolution_revision,
		DEFAULT_ATTRIBUTE_PROJECTION,
	)
	if not resolution.ok():
		push_error(resolution.error)
		return false
	var action_error := CANDIDATE_ACTION_VALIDATION.validate(
		member.class_definition,
		member.member_id,
		STAT_CATALOG,
		damage_types if damage_types != null else GameCatalog.DAMAGE_TYPES,
		member.class_definition.stat_base_values(),
		member.capability_tags,
		effective_candidate_sources,
		resolution_revision,
		DEFAULT_ATTRIBUTE_PROJECTION,
		action_weapon,
	)
	if not action_error.is_empty():
		push_error(action_error)
		return false
	return true

func _restore_member_sources_without_invalidation(member_id: int, sources: Array[StatModifierSource]) -> void:
	var member := member_by_id(member_id)
	if member == null:
		return
	member._owned_modifier_sources().clear()
	for source: StatModifierSource in sources:
		member._add_modifier_source(source)

func upgrade_rank(upgrade_id: StringName, member_id: int = 0) -> int:
	if member_id > 0:
		var member := member_by_id(member_id)
		return member.upgrade_rank(upgrade_id) if member != null else 0
	return int(_party_upgrade_ranks.get(upgrade_id, 0))

func _commit_personal_upgrade(definition: UpgradeDefinition, member_id: int, rank: int, source: StatModifierSource) -> bool:
	var member := member_by_id(member_id)
	if member == null or definition == null or source == null:
		return false
	var previous_rank_present := member._upgrade_ranks.has(definition.id)
	var previous_rank := member.upgrade_rank(definition.id)
	member._set_upgrade_rank(definition.id, rank)
	if not replace_member_source(member_id, source):
		if previous_rank_present:
			member._set_upgrade_rank(definition.id, previous_rank)
		else:
			member._upgrade_ranks.erase(definition.id)
		return false
	upgrades_changed.emit()
	return true

func _commit_party_upgrade(definition: UpgradeDefinition, rank: int, source: StatModifierSource) -> bool:
	if definition == null or source == null:
		return false
	var candidate_ranks := _party_upgrade_ranks.duplicate()
	var candidate_definitions := _party_upgrade_definitions.duplicate()
	var candidate_sources := _party_upgrade_sources.duplicate()
	candidate_ranks[definition.id] = rank
	candidate_definitions[definition.id] = definition
	candidate_sources[definition.id] = source

	var previous_definition := _party_upgrade_definitions.get(definition.id) as UpgradeDefinition
	for member: PartyMemberState in members:
		var was_eligible := previous_definition != null and previous_definition.is_member_eligible(member)
		if not was_eligible and not definition.is_member_eligible(member):
			continue
		if not _validate_candidate_member_sources_for_party_upgrades(
			member.member_id,
			member.modifier_sources,
			candidate_definitions,
			candidate_sources,
		):
			return false

	_party_upgrade_ranks = candidate_ranks
	_party_upgrade_definitions = candidate_definitions
	_party_upgrade_sources = candidate_sources
	_invalidate_all_members()
	upgrades_changed.emit()
	return true

func _invalidate_member(member_id: int) -> void:
	_stat_revision += 1
	_member_stat_revision[member_id] = _stat_revision
	_restamp_active_weapon(member_id, _stat_revision)
	_stat_cache.erase(member_id)
	var prefix := "%d|" % member_id
	for key: Variant in _action_stat_cache.keys():
		if String(key).begins_with(prefix):
			_action_stat_cache.erase(key)
	stats_changed.emit(member_id)

func _invalidate_members(member_ids: Array[int]) -> void:
	_stat_revision += 1
	for member_id: int in member_ids:
		_member_stat_revision[member_id] = _stat_revision
		_restamp_active_weapon(member_id, _stat_revision)
		_stat_cache.erase(member_id)
		var prefix := "%d|" % member_id
		for key: Variant in _action_stat_cache.keys():
			if String(key).begins_with(prefix):
				_action_stat_cache.erase(key)
	for member_id: int in member_ids:
		stats_changed.emit(member_id)

func _invalidate_all_members() -> void:
	_stat_revision += 1
	var transition_revision := _stat_revision
	_stat_cache.clear()
	_action_stat_cache.clear()
	var member_ids: Array[int] = []
	for member: PartyMemberState in members:
		var member_id := member.member_id
		member_ids.append(member_id)
		_member_stat_revision[member_id] = transition_revision
		_restamp_active_weapon(member_id, transition_revision)
	for member_id: int in member_ids:
		stats_changed.emit(member_id)

func _effective_revision_for_member(member_id: int) -> int:
	return int(_member_stat_revision.get(member_id, _stat_revision))

func _restamp_active_weapon(member_id: int, revision: int) -> void:
	var weapon := _active_weapon_by_member.get(member_id) as ActiveWeaponDamageSnapshot
	if weapon == null or weapon.revision == revision:
		return
	_active_weapon_by_member[member_id] = ActiveWeaponDamageSnapshot.create(
		weapon.member_id,
		weapon.item_id,
		weapon.base_id,
		weapon.components,
		revision,
	)

func rank_up(class_id: StringName) -> bool:
	if not class_ranks.has(class_id):
		return false
	class_ranks[class_id] = int(class_ranks[class_id]) + 1
	_invalidate_all_members()
	class_rank_changed.emit(class_id, int(class_ranks[class_id]))
	return true

func get_class_rank(class_id: StringName) -> int:
	return int(class_ranks.get(class_id, 0))

func trait_count(trait_id: StringName) -> int:
	var count := 0
	for member: PartyMemberState in members:
		if trait_id in member.class_definition.traits:
			count += 1
	return count

func active_tier(trait_id: StringName) -> int:
	return int(active_tiers.get(trait_id, 0))

func upgrade_party_stat(stat_id: StringName) -> bool:
	if stat_id not in PARTY_STAT_IDS or party_stat_rank(stat_id) >= upgrade_tuning.party_stat_max_rank:
		return false
	party_stat_ranks[stat_id] = party_stat_rank(stat_id) + 1
	_invalidate_all_members()
	upgrades_changed.emit()
	return true

func party_stat_rank(stat_id: StringName) -> int:
	return int(party_stat_ranks.get(stat_id, 0))

func party_stat_multiplier(stat_id: StringName) -> float:
	var step := 0.0
	match stat_id:
		&"max_health": step = upgrade_tuning.max_health_per_rank
		&"damage": step = upgrade_tuning.damage_per_rank
		&"move_speed": step = upgrade_tuning.move_speed_per_rank
		&"attack_speed": step = upgrade_tuning.attack_speed_per_rank
		&"pickup_radius": step = upgrade_tuning.pickup_radius_per_rank
		_: return 1.0
	return 1.0 + float(party_stat_rank(stat_id)) * step

func upgrade_trait(trait_id: StringName) -> bool:
	if active_tier(trait_id) <= 0 or trait_definition(trait_id) == null:
		return false
	trait_upgrade_ranks[trait_id] = trait_upgrade_rank(trait_id) + 1
	_invalidate_all_members()
	upgrades_changed.emit()
	return true

func trait_upgrade_rank(trait_id: StringName) -> int:
	return int(trait_upgrade_ranks.get(trait_id, 0))

func effective_trait_value(trait_id: StringName) -> float:
	return _effective_trait_value_for_tiers(trait_id, active_tiers)

func _effective_trait_value_for_tiers(trait_id: StringName, tiers: Dictionary) -> float:
	var definition := trait_definition(trait_id)
	var tier := int(tiers.get(trait_id, 0))
	if definition == null or tier <= 0:
		return 0.0
	var base_value := float(definition.tiers.get(tier, 0.0))
	return base_value * (1.0 + float(trait_upgrade_rank(trait_id)) * upgrade_tuning.trait_upgrade_value_step)

func trait_definition(trait_id: StringName) -> TraitDefinition:
	for definition: TraitDefinition in trait_definitions:
		if definition != null and definition.id == trait_id:
			return definition
	return null

func revive_delay_multiplier() -> float:
	return maxf(0.1, 1.0 - effective_trait_value(&"divine"))

func incoming_damage_multiplier(target_actor: Node3D) -> float:
	if target_actor == null or active_tier(&"vanguard") <= 0:
		return 1.0
	var definition := trait_definition(&"vanguard")
	if definition == null:
		return 1.0
	var target_position: Vector3 = target_actor.global_position if target_actor.is_inside_tree() else target_actor.position
	var actor_nodes: Array[Node] = []
	if is_inside_tree():
		actor_nodes.assign(get_tree().get_nodes_in_group(&"party_actors"))
	elif get_parent() != null:
		for candidate: Node in get_parent().find_children("*", "PartyActor", true, false):
			actor_nodes.append(candidate)
	for actor_node: Node in actor_nodes:
		var actor := actor_node as PartyActor
		if actor == null or actor == target_actor or actor.party_manager != self or actor.member_state == null:
			continue
		if &"vanguard" not in actor.member_state.class_definition.traits:
			continue
		var combat_target := actor.get_combat_target()
		if not combat_target.is_available:
			continue
		var actor_position: Vector3 = actor.global_position if actor.is_inside_tree() else actor.position
		if actor_position.distance_to(target_position) <= definition.effect_radius:
			return maxf(0.0, 1.0 - effective_trait_value(&"vanguard"))
	return 1.0

func _sources_for(member: PartyMemberState) -> Array[StatModifierSource]:
	return _sources_for_owned(member, member._owned_modifier_sources())

func _sources_for_owned(
	member: PartyMemberState,
	owned_sources: Array[StatModifierSource],
) -> Array[StatModifierSource]:
	return _sources_for_owned_with_party_upgrades(
		member,
		owned_sources,
		_party_upgrade_definitions,
		_party_upgrade_sources,
	)

func _sources_for_owned_with_party_upgrades(
	member: PartyMemberState,
	owned_sources: Array[StatModifierSource],
	party_upgrade_definitions_for_graph: Dictionary,
	party_upgrade_sources_for_graph: Dictionary,
) -> Array[StatModifierSource]:
	return _sources_for_owned_with_state(
		member,
		owned_sources,
		party_upgrade_definitions_for_graph,
		party_upgrade_sources_for_graph,
		class_ranks,
		active_tiers,
	)

func _sources_for_owned_with_state(
	member: PartyMemberState,
	owned_sources: Array[StatModifierSource],
	party_upgrade_definitions_for_graph: Dictionary,
	party_upgrade_sources_for_graph: Dictionary,
	class_ranks_for_graph: Dictionary,
	active_tiers_for_graph: Dictionary,
) -> Array[StatModifierSource]:
	var sources: Array[StatModifierSource] = []
	var definition := member.class_definition
	var rank_bonus := float(maxi(int(class_ranks_for_graph.get(definition.id, 0)), 1) - 1) * definition.class_rank_power_step
	var class_rank_id := StringName("class_rank_%s" % definition.id)
	sources.append(StatModifierSource.create(
		class_rank_id,
		&"class_rank",
		"%s Rank" % definition.display_name,
		0,
		[StatModifier.create(&"damage", StatModifier.Operation.INCREASED, rank_bonus, class_rank_id, "%s Rank" % definition.display_name)],
	))
	for source: StatModifierSource in owned_sources:
		sources.append(source)

	for upgrade_id: StringName in party_upgrade_definitions_for_graph:
		var upgrade := party_upgrade_definitions_for_graph[upgrade_id] as UpgradeDefinition
		if upgrade != null and upgrade.is_member_eligible(member):
			sources.append(party_upgrade_sources_for_graph[upgrade_id] as StatModifierSource)

	var party_modifiers: Array[StatModifier] = []
	for stat_id: StringName in PARTY_STAT_IDS:
		var amount := float(party_stat_rank(stat_id)) * _party_stat_step(stat_id)
		party_modifiers.append(StatModifier.create(stat_id, StatModifier.Operation.INCREASED, amount, StringName("party_%s" % stat_id), "Party %s" % String(stat_id).capitalize()))
	sources.append(StatModifierSource.create(&"party_upgrades", &"party", "Party Upgrades", 0, party_modifiers))

	var trait_modifiers: Array[StatModifier] = []
	for trait_id: StringName in definition.traits:
		var trait_data := trait_definition(trait_id)
		var active_value := _effective_trait_value_for_tiers(trait_id, active_tiers_for_graph)
		if trait_data == null or active_value <= 0.0:
			continue
		var label := trait_data.display_name
		match trait_data.stat_id:
			&"attack_speed":
				trait_modifiers.append(StatModifier.create(&"attack_speed", StatModifier.Operation.INCREASED, active_value, trait_id, label))
			&"cooldown_reduction":
				trait_modifiers.append(StatModifier.create(&"attack_speed", StatModifier.Operation.MORE, 1.0 / maxf(1.0 - active_value, 0.05) - 1.0, trait_id, label))
			&"projectile_speed_and_range":
				trait_modifiers.append(StatModifier.create(&"projectile_speed", StatModifier.Operation.INCREASED, active_value, trait_id, label))
				trait_modifiers.append(StatModifier.create(&"attack_range", StatModifier.Operation.INCREASED, active_value, trait_id, label))
			&"area_size":
				trait_modifiers.append(StatModifier.create(&"area_size", StatModifier.Operation.INCREASED, active_value, trait_id, label))
			&"support_power", &"healing_and_revive":
				trait_modifiers.append(StatModifier.create(&"healing_power", StatModifier.Operation.INCREASED, active_value, trait_id, label))
			&"fire_damage", &"cold_damage", &"chaos_damage", &"attack_range":
				trait_modifiers.append(StatModifier.create(
					trait_data.stat_id,
					StatModifier.Operation.INCREASED,
					active_value,
					trait_id,
					label,
				))
			&"dodge_chance", &"life_steal":
				trait_modifiers.append(StatModifier.create(
					trait_data.stat_id,
					StatModifier.Operation.FLAT,
					active_value,
					trait_id,
					label,
				))
	sources.append(StatModifierSource.create(&"active_traits", &"trait", "Active Traits", 0, trait_modifiers))
	return sources

func _party_stat_step(stat_id: StringName) -> float:
	match stat_id:
		&"max_health": return upgrade_tuning.max_health_per_rank
		&"damage": return upgrade_tuning.damage_per_rank
		&"move_speed": return upgrade_tuning.move_speed_per_rank
		&"attack_speed": return upgrade_tuning.attack_speed_per_rank
		&"pickup_radius": return upgrade_tuning.pickup_radius_per_rank
		_: return 0.0

func _normalized_tags(tags: Array[StringName]) -> Array[StringName]:
	var normalized: Array[StringName] = []
	for tag: StringName in tags:
		if not tag.is_empty() and tag not in normalized:
			normalized.append(tag)
	normalized.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	return normalized

func _append_member(definition: ClassDefinition, leader: bool) -> void:
	var member := _build_member(definition, leader)
	members.append(member)
	if not class_ranks.has(definition.id): class_ranks[definition.id] = 1
	if not _recalculate_traits():
		_invalidate_all_members()
	member_added.emit(member)

func _build_member(definition: ClassDefinition, leader: bool) -> PartyMemberState:
	var member_id := members.size() + 1
	var used_names := PackedStringArray()
	for existing_member: PartyMemberState in members:
		if not existing_member.character_name.is_empty():
			used_names.append(existing_member.character_name)
	var generated_name := ""
	if definition.name_pool != null or _fallback_names != null:
		generated_name = CharacterNameService.choose_name(definition.name_pool, _fallback_names, _identity_seed, member_id, used_names)
	return PartyMemberState.new(member_id, definition, leader, generated_name)

func _recalculate_traits() -> bool:
	var next := _trait_tiers_for_members(members)
	if next == active_tiers:
		return false
	active_tiers = next
	_invalidate_all_members()
	active_traits_changed.emit(active_tiers.duplicate())
	return true

func _trait_tiers_for_members(candidate_members: Array[PartyMemberState]) -> Dictionary:
	var next: Dictionary = {}
	for definition: TraitDefinition in trait_definitions:
		var count := 0
		for member: PartyMemberState in candidate_members:
			if definition.id in member.class_definition.traits:
				count += 1
		var achieved := 0
		for threshold: Variant in definition.tiers.keys():
			if count >= int(threshold): achieved = maxi(achieved, int(threshold))
		if achieved > 0: next[definition.id] = achieved
	return next
