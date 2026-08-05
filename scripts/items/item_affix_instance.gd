class_name ItemAffixInstance
extends RefCounted

var definition_id: StringName
var affix_kind: String
var tier: int = 1
var rolls: Array[ItemModifierRoll] = []

func copy() -> ItemAffixInstance:
	var result := ItemAffixInstance.new()
	result.definition_id = definition_id
	result.affix_kind = affix_kind
	result.tier = tier
	for roll: ItemModifierRoll in rolls:
		result.rolls.append(roll.copy() if roll != null else null)
	return result

func to_dictionary() -> Dictionary:
	var roll_documents: Array[Dictionary] = []
	for roll: ItemModifierRoll in rolls:
		roll_documents.append(roll.to_dictionary() if roll != null else {})
	return {
		"affix_kind": affix_kind,
		"definition_id": String(definition_id),
		"rolls": roll_documents,
		"tier": tier,
	}
