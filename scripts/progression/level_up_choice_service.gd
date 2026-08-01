class_name LevelUpChoiceService
extends RefCounted

const PARTY_STATS: Array[StringName] = [&"max_health", &"damage", &"move_speed", &"attack_speed", &"pickup_radius"]

@warning_ignore("shadowed_global_identifier")
static func generate(
	party: PartyManager,
	catalog: GameCatalog,
	seed: int,
	offer_count: int = 5,
	offer_state: LevelUpOfferState = null
) -> Array[UpgradeChoice]:
	var chosen: Array[UpgradeChoice] = []
	if party == null:
		return chosen
	var limit := clampi(offer_count, 1, 8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var keys: Dictionary = {}

	var recruits := _recruit_candidates(party, catalog)
	var recruit_eligible := party.can_recruit() and not recruits.is_empty()
	var desired_recruits := 0
	if recruit_eligible:
		var drought := offer_state.consecutive_eligible_without_recruit if offer_state != null else 0
		desired_recruits = RecruitOfferPolicy.count_for_roll(rng.randf(), drought)
		var remaining_capacity := maxi(party.capacity() - party.members.size(), 0)
		desired_recruits = mini(desired_recruits, mini(limit, mini(recruits.size(), remaining_capacity)))
		while desired_recruits > 0 and not recruits.is_empty():
			var index := rng.randi_range(0, recruits.size() - 1)
			_append_choice(recruits[index], party, chosen, keys, limit)
			recruits.remove_at(index)
			desired_recruits -= 1
	if offer_state != null:
		offer_state.record_recruit_result(recruit_eligible, _kind_count(chosen, UpgradeChoice.Kind.RECRUIT))

	var normal: Array[UpgradeChoice] = []
	var universal: Array[UpgradeChoice] = []
	if catalog != null:
		for definition: UpgradeDefinition in catalog.upgrades:
			if definition == null:
				continue
			var choice := UpgradeChoice.authored(definition)
			if not choice.is_valid_for(party):
				continue
			if _is_universal(definition):
				universal.append(choice)
			else:
				normal.append(choice)
	_append_foundational_candidates(party, catalog, normal)
	_sort_by_target_id(normal)
	_sort_by_target_id(universal)
	_append_weighted_without_replacement(normal, rng, party, chosen, keys, limit)
	_append_weighted_without_replacement(universal, rng, party, chosen, keys, limit)

	for stat: StringName in PARTY_STATS:
		if chosen.size() >= limit:
			break
		_append_choice(_party_stat_choice(stat), party, chosen, keys, limit)
	return chosen

static func _kind_count(choices: Array[UpgradeChoice], kind: UpgradeChoice.Kind) -> int:
	var count := 0
	for choice: UpgradeChoice in choices:
		if choice != null and choice.kind == kind:
			count += 1
	return count

static func _recruit_candidates(party: PartyManager, catalog: GameCatalog) -> Array[UpgradeChoice]:
	var recruits: Array[UpgradeChoice] = []
	var keys: Dictionary = {}
	if catalog != null:
		for definition: ClassDefinition in catalog.classes:
			_append_recruit(definition, recruits, keys)
	if recruits.is_empty():
		for member: PartyMemberState in party.members:
			_append_recruit(member.class_definition, recruits, keys)
	_sort_by_target_id(recruits)
	return recruits

static func _append_recruit(definition: ClassDefinition, recruits: Array[UpgradeChoice], keys: Dictionary) -> void:
	if definition == null:
		return
	var choice := UpgradeChoice.new(UpgradeChoice.Kind.RECRUIT, definition.id, "Recruit %s" % definition.display_name)
	if not keys.has(choice.key()):
		recruits.append(choice)
		keys[choice.key()] = true

static func _append_foundational_candidates(party: PartyManager, catalog: GameCatalog, candidates: Array[UpgradeChoice]) -> void:
	var keys: Dictionary = {}
	if catalog != null:
		for definition: ClassDefinition in catalog.classes:
			_append_class_rank(definition, party, candidates, keys)
	for member: PartyMemberState in party.members:
		_append_class_rank(member.class_definition, party, candidates, keys)
	if catalog != null:
		for definition: TraitDefinition in catalog.traits:
			_append_trait(definition, party, candidates, keys)
	for definition: TraitDefinition in party.trait_definitions:
		_append_trait(definition, party, candidates, keys)

static func _append_class_rank(definition: ClassDefinition, party: PartyManager, candidates: Array[UpgradeChoice], keys: Dictionary) -> void:
	if definition == null or party.get_class_rank(definition.id) <= 0:
		return
	var choice := UpgradeChoice.new(UpgradeChoice.Kind.CLASS_RANK, definition.id, "Train %s" % definition.display_name)
	if not keys.has(choice.key()):
		candidates.append(choice)
		keys[choice.key()] = true

static func _append_trait(definition: TraitDefinition, party: PartyManager, candidates: Array[UpgradeChoice], keys: Dictionary) -> void:
	if definition == null or party.active_tier(definition.id) <= 0:
		return
	var choice := UpgradeChoice.new(UpgradeChoice.Kind.TRAIT, definition.id, "Strengthen %s" % definition.display_name)
	if not keys.has(choice.key()):
		candidates.append(choice)
		keys[choice.key()] = true

static func _is_universal(definition: UpgradeDefinition) -> bool:
	return definition.scope == UpgradeDefinition.Scope.CHARACTER \
		and definition.allowed_class_ids.is_empty() \
		and definition.required_all_tags.is_empty() \
		and definition.required_any_tags.is_empty() \
		and definition.excluded_tags.is_empty()

static func _sort_by_target_id(candidates: Array[UpgradeChoice]) -> void:
	candidates.sort_custom(func(left: UpgradeChoice, right: UpgradeChoice) -> bool:
		if left.target_id == right.target_id:
			return left.kind < right.kind
		return String(left.target_id) < String(right.target_id)
	)

static func _selection_weight(choice: UpgradeChoice) -> float:
	if choice.kind != UpgradeChoice.Kind.AUTHORED:
		return 1.0
	if choice.definition == null or not is_finite(choice.definition.selection_weight) or choice.definition.selection_weight <= 0.0:
		return 0.0
	return choice.definition.selection_weight

static func _append_weighted_without_replacement(candidates: Array[UpgradeChoice], rng: RandomNumberGenerator, party: PartyManager, chosen: Array[UpgradeChoice], keys: Dictionary, limit: int) -> void:
	var remaining: Array[UpgradeChoice] = candidates.duplicate()
	while chosen.size() < limit and not remaining.is_empty():
		var total_weight := 0.0
		for candidate: UpgradeChoice in remaining:
			total_weight += _selection_weight(candidate)
		if total_weight <= 0.0:
			return
		var roll := rng.randf() * total_weight
		var selected_index := remaining.size() - 1
		var cumulative := 0.0
		for index: int in remaining.size():
			var candidate := remaining[index]
			var weight := _selection_weight(candidate)
			if weight <= 0.0:
				continue
			cumulative += weight
			if roll < cumulative:
				selected_index = index
				break
		var selected := remaining[selected_index]
		remaining.remove_at(selected_index)
		_append_choice(selected, party, chosen, keys, limit)

static func _party_stat_choice(stat: StringName) -> UpgradeChoice:
	return UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, stat, "Party %s" % String(stat).replace("_", " ").capitalize())

static func _append_choice(choice: UpgradeChoice, party: PartyManager, chosen: Array[UpgradeChoice], keys: Dictionary, limit: int) -> void:
	if choice == null or chosen.size() >= limit or keys.has(choice.key()) or not choice.is_valid_for(party):
		return
	chosen.append(choice)
	keys[choice.key()] = true
