class_name TraitDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var stat_id: StringName
@export var tiers: Dictionary = {2: 0.15, 4: 0.35}

func validate() -> PackedStringArray:
    var errors: PackedStringArray = []
    if id.is_empty(): errors.append("trait id is empty")
    if stat_id.is_empty(): errors.append("trait %s stat id is empty" % id)
    for threshold: Variant in tiers.keys():
        if int(threshold) < 2: errors.append("trait %s threshold must be at least two" % id)
    return errors
