class_name LedgerPageCatalog
extends Resource

@export var pages: Array[LedgerPageDefinition] = []

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen: Dictionary = {}
	for page: LedgerPageDefinition in pages:
		if page == null:
			errors.append("PARTY_FORGE_LEDGER_ERROR page=<null> reason=definition is missing")
			continue
		if seen.has(page.id):
			errors.append("PARTY_FORGE_LEDGER_ERROR page=%s reason=duplicate page id %s" % [page.id, page.id])
			continue
		seen[page.id] = true
		errors.append_array(page.validate())
	return errors

func valid_pages(gate: LedgerFeatureGate) -> Array[LedgerPageDefinition]:
	var result: Array[LedgerPageDefinition] = []
	var seen: Dictionary = {}
	for page: LedgerPageDefinition in pages:
		if page == null or seen.has(page.id):
			continue
		seen[page.id] = true
		if not page.validate().is_empty():
			continue
		if gate.resolve(page) != LedgerPageDefinition.State.HIDDEN:
			result.append(page)
	result.sort_custom(func(left: LedgerPageDefinition, right: LedgerPageDefinition) -> bool:
		if left.display_order == right.display_order:
			return String(left.id) < String(right.id)
		return left.display_order < right.display_order
	)
	return result
