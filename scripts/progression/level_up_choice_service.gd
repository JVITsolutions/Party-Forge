class_name LevelUpChoiceService
extends RefCounted

const PARTY_STATS: Array[StringName] = [&"max_health", &"damage", &"move_speed", &"attack_speed", &"pickup_radius"]

static func generate(party: PartyManager, catalog: GameCatalog, seed: int) -> Array[UpgradeChoice]:
    var rng := RandomNumberGenerator.new(); rng.seed = seed
    var chosen: Array[UpgradeChoice] = []
    var candidates: Array[UpgradeChoice] = []
    var recruits: Array[UpgradeChoice] = []
    var recruit_keys: Dictionary = {}
    for definition: ClassDefinition in catalog.classes:
        _append_recruit(definition, recruits, recruit_keys)
        if definition != null and party.get_class_rank(definition.id) > 0:
            candidates.append(UpgradeChoice.new(UpgradeChoice.Kind.CLASS_RANK, definition.id, "Train %s" % definition.display_name))
    if recruits.is_empty():
        for member: PartyMemberState in party.members:
            _append_recruit(member.class_definition, recruits, recruit_keys)
    for definition: TraitDefinition in catalog.traits:
        if definition != null and party.active_tier(definition.id) > 0:
            candidates.append(UpgradeChoice.new(UpgradeChoice.Kind.TRAIT, definition.id, "Strengthen %s" % definition.display_name))
    for stat: StringName in PARTY_STATS:
        candidates.append(_party_stat_choice(stat))
    if party.members.size() < PartyManager.MAX_PARTY_SIZE and not recruits.is_empty():
        chosen.append(recruits[rng.randi_range(0, recruits.size() - 1)])
    for index: int in range(candidates.size() - 1, 0, -1):
        var swap_index: int = rng.randi_range(0, index)
        var held: UpgradeChoice = candidates[index]
        candidates[index] = candidates[swap_index]
        candidates[swap_index] = held
    var keys: Dictionary = {}
    for existing: UpgradeChoice in chosen: keys[existing.key()] = true
    _append_usable_unique(candidates, party, chosen, keys)
    if chosen.size() < 3:
        var fallbacks: Array[UpgradeChoice] = []
        for stat: StringName in PARTY_STATS:
            fallbacks.append(_party_stat_choice(stat))
        _append_usable_unique(fallbacks, party, chosen, keys)
    return chosen

static func _append_recruit(definition: ClassDefinition, recruits: Array[UpgradeChoice], keys: Dictionary) -> void:
    if definition == null:
        return
    var choice := UpgradeChoice.new(UpgradeChoice.Kind.RECRUIT, definition.id, "Recruit %s" % definition.display_name)
    if not keys.has(choice.key()):
        recruits.append(choice)
        keys[choice.key()] = true

static func _party_stat_choice(stat: StringName) -> UpgradeChoice:
    return UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, stat, "Party %s" % String(stat).replace("_", " ").capitalize())

static func _append_usable_unique(candidates: Array[UpgradeChoice], party: PartyManager, chosen: Array[UpgradeChoice], keys: Dictionary) -> void:
    for candidate: UpgradeChoice in candidates:
        if chosen.size() >= 3:
            return
        if candidate.is_valid_for(party) and not keys.has(candidate.key()):
            chosen.append(candidate)
            keys[candidate.key()] = true
