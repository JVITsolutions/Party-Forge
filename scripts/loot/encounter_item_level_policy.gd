class_name EncounterItemLevelPolicy
extends RefCounted

static func resolve(
	event: EnemyDefeatEvent,
	difficulty_id: StringName,
	heat: float,
	tuning: PersonalLootTuning,
) -> int:
	var category_bonus := 0
	match event.source_category:
		&"ordinary_specialist":
			category_bonus = tuning.specialist_item_level_bonus
		&"elite":
			category_bonus = tuning.elite_item_level_bonus
		&"boss":
			category_bonus = tuning.boss_item_level_bonus
	var difficulty_bonus := int(tuning.difficulty_item_level_bonus.get(difficulty_id, 0))
	var item_level := (
		1
		+ floori(event.encounter_seconds / tuning.seconds_per_item_level)
		+ category_bonus
		+ difficulty_bonus
		+ floori(heat * tuning.heat_item_levels_per_point)
	)
	return clampi(item_level, ItemGenerationRequest.MIN_ITEM_LEVEL, ItemGenerationRequest.MAX_ITEM_LEVEL)
