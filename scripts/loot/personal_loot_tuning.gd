class_name PersonalLootTuning
extends Resource

@export var drop_basis_points := {&"ordinary_melee": 100, &"ordinary_specialist": 200, &"elite": 0, &"boss": 0}
@export var seconds_per_item_level := 12.0
@export var specialist_item_level_bonus := 1
@export var elite_item_level_bonus := 5
@export var boss_item_level_bonus := 10
@export var difficulty_item_level_bonus := {&"normal": 0}
@export var heat_item_levels_per_point := 0.25
@export var pickup_interaction_radius := 3.5
@export var controller_target_query_radius := 30.0
