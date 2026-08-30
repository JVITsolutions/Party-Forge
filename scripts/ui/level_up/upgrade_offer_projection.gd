class_name UpgradeOfferProjection
extends RefCounted

var choice_key: String = ""
var target_id: StringName
var category_id: StringName
var icon_id: StringName
var display_name: String = ""
var rarity_label: String = ""
var effect_text: String = ""
var scope_text: String = ""
var rank_text: String = ""
var eligibility_text: String = ""
var recipient_tags: Array[StringName] = []
var class_tags: Array[StringName] = []
var disabled_reason: String = ""


func enabled() -> bool:
	return disabled_reason.is_empty()


func copy() -> UpgradeOfferProjection:
	var result := UpgradeOfferProjection.new()
	result.choice_key = choice_key
	result.target_id = target_id
	result.category_id = category_id
	result.icon_id = icon_id
	result.display_name = display_name
	result.rarity_label = rarity_label
	result.effect_text = effect_text
	result.scope_text = scope_text
	result.rank_text = rank_text
	result.eligibility_text = eligibility_text
	result.recipient_tags = recipient_tags.duplicate()
	result.class_tags = class_tags.duplicate()
	result.disabled_reason = disabled_reason
	return result
