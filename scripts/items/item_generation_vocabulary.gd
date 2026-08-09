class_name ItemGenerationVocabulary
extends RefCounted

const DOMAINS: Array[StringName] = [&"ordinary_drop", &"boss_drop", &"raid_drop", &"vendor", &"crafting", &"developer"]
const ARCHETYPES: Array[StringName] = [&"melee", &"ranged", &"caster", &"global"]
const AFFIX_KINDS: PackedStringArray = ["implicit", "prefix", "suffix", "special"]
