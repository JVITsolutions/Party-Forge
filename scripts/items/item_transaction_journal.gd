class_name ItemTransactionJournal
extends RefCounted

var _entries: Dictionary = {}

func has(transaction_id: String) -> bool:
	return _entries.has(transaction_id)

func entry(transaction_id: String) -> Dictionary:
	var value := _entries.get(transaction_id) as Dictionary
	return _copy_entry(value) if value != null else {}

func entries() -> Dictionary:
	var result: Dictionary = {}
	var transaction_ids: Array[String] = []
	for key: Variant in _entries:
		transaction_ids.append(String(key))
	transaction_ids.sort()
	for transaction_id: String in transaction_ids:
		result[transaction_id] = _copy_entry(_entries[transaction_id] as Dictionary)
	return result

func size() -> int:
	return _entries.size()

func copy() -> ItemTransactionJournal:
	var result := ItemTransactionJournal.new()
	for transaction_id: String in entries():
		result._entries[transaction_id] = _copy_entry(_entries[transaction_id] as Dictionary)
	return result

func _record_success(transaction_id: String, fingerprint: String, code: ItemTransactionResult.Code, state: ItemOwnershipState) -> void:
	_entries[transaction_id] = {
		"fingerprint": fingerprint,
		"code": code,
		"state": state.copy(),
	}

static func _copy_entry(value: Dictionary) -> Dictionary:
	if value.is_empty():
		return {}
	var state := value.get("state") as ItemOwnershipState
	return {
		"fingerprint": String(value.get("fingerprint", "")),
		"code": int(value.get("code", ItemTransactionResult.Code.INVALID_REQUEST)),
		"state": state.copy() if state != null else null,
	}
