class_name HeadwearFitDescriptor
extends Resource

const CATEGORIES: Array[StringName] = [&"full_helmet", &"open_helmet", &"circlet"]

@export var category: StringName
@export var compatible_envelope_ids: Array[StringName] = []
@export var hide_head_region_ids: Array[StringName] = []
@export var helmet_safe_hair_id: StringName


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if category not in CATEGORIES:
		errors.append("headwear category %s is invalid" % category)
	var seen_envelopes: Dictionary = {}
	for envelope_id: StringName in compatible_envelope_ids:
		if envelope_id.is_empty() or seen_envelopes.has(envelope_id):
			errors.append("headwear has empty or duplicate envelope %s" % envelope_id)
		seen_envelopes[envelope_id] = true
	if compatible_envelope_ids.is_empty():
		errors.append("headwear compatible envelopes are empty")
	var seen_regions: Dictionary = {}
	for region_id: StringName in hide_head_region_ids:
		if region_id.is_empty() or seen_regions.has(region_id):
			errors.append("headwear has empty or duplicate hidden region %s" % region_id)
		seen_regions[region_id] = true
	if category == &"open_helmet" and helmet_safe_hair_id.is_empty():
		errors.append("open helmet requires a helmet-safe hair id")
	return errors
