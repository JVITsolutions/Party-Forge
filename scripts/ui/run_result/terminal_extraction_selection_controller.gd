class_name TerminalExtractionSelectionController
extends RefCounted

var _policy: RunExtractionProjection
var _eligible_by_id: Dictionary = {}
var _ordered_ids: Array[String] = []
var _automatic: Dictionary = {}
var _selected: Dictionary = {}
var _pending := false
var _unused_acknowledged := false

func initialize(policy: RunExtractionProjection) -> bool:
	_clear()
	if policy == null or not policy.valid:
		return false
	_policy = _copy_policy(policy)
	for item_id: String in policy.automatic_item_ids:
		if item_id.strip_edges().is_empty() or _automatic.has(item_id):
			_clear()
			return false
		_automatic[item_id] = true
	for selection: ExtractionSelection in policy.eligible_items:
		if selection == null or selection.item_id.strip_edges().is_empty() or _eligible_by_id.has(selection.item_id) or _automatic.has(selection.item_id):
			_clear()
			return false
		_eligible_by_id[selection.item_id] = selection.copy()
		_ordered_ids.append(selection.item_id)
	if _ordered_ids.size() <= policy.capacity:
		for item_id: String in _ordered_ids:
			_selected[item_id] = (_eligible_by_id[item_id] as ExtractionSelection).copy()
	return true

func toggle(item_id: String) -> bool:
	if _pending or _policy == null or not _eligible_by_id.has(item_id) or _automatic.has(item_id):
		return false
	if _selected.has(item_id):
		_selected.erase(item_id)
		_unused_acknowledged = false
		return true
	if _selected.size() >= _policy.capacity:
		return false
	_selected[item_id] = (_eligible_by_id[item_id] as ExtractionSelection).copy()
	_unused_acknowledged = false
	return true

func reconcile(next: RunExtractionProjection) -> Array[String]:
	var changed: Array[String] = []
	if next == null or not next.valid or _has_duplicate_candidates(next):
		for item_id: String in _ordered_ids:
			if _selected.has(item_id): changed.append(item_id)
		_clear()
		return changed
	var next_by_id: Dictionary = {}
	var next_order: Array[String] = []
	for selection: ExtractionSelection in next.eligible_items:
		next_by_id[selection.item_id] = selection.copy()
		next_order.append(selection.item_id)
	for item_id: String in _ordered_ids:
		if not _selected.has(item_id):
			continue
		var exact := next_by_id.get(item_id) as ExtractionSelection
		var prior := _selected[item_id] as ExtractionSelection
		if exact == null or prior.expected_source_container_id != exact.expected_source_container_id or prior.expected_source_slot != exact.expected_source_slot:
			_selected.erase(item_id)
			changed.append(item_id)
	_policy = _copy_policy(next)
	_eligible_by_id = next_by_id
	_ordered_ids = next_order
	_automatic.clear()
	for automatic_id: String in next.automatic_item_ids: _automatic[automatic_id] = true
	_unused_acknowledged = false
	_pending = false
	return changed

func selected_item_ids() -> Array[String]:
	var result: Array[String] = []
	for item_id: String in _ordered_ids:
		if _selected.has(item_id): result.append(item_id)
	return result

func selected_selections() -> Array[ExtractionSelection]:
	var result: Array[ExtractionSelection] = []
	for item_id: String in _ordered_ids:
		if _selected.has(item_id): result.append((_selected[item_id] as ExtractionSelection).copy())
	return result

func needs_unused_capacity_acknowledgement() -> bool:
	if _policy == null or _unused_acknowledged:
		return false
	var unused := _policy.capacity - _selected.size()
	var lost := _ordered_ids.size() - _selected.size()
	return unused > 0 and lost > 0

func acknowledge_unused_capacity() -> bool:
	if _pending or not needs_unused_capacity_acknowledgement():
		return false
	_unused_acknowledged = true
	return true

func set_pending(value: bool) -> void:
	_pending = value

func pending() -> bool:
	return _pending

func _clear() -> void:
	_policy = null
	_eligible_by_id.clear()
	_ordered_ids.clear()
	_automatic.clear()
	_selected.clear()
	_pending = false
	_unused_acknowledged = false

func _has_duplicate_candidates(policy: RunExtractionProjection) -> bool:
	var seen: Dictionary = {}
	for item_id: String in policy.automatic_item_ids:
		if item_id.strip_edges().is_empty() or seen.has(item_id): return true
		seen[item_id] = true
	for selection: ExtractionSelection in policy.eligible_items:
		if selection == null or selection.item_id.strip_edges().is_empty() or seen.has(selection.item_id): return true
		seen[selection.item_id] = true
	return false

func _copy_policy(policy: RunExtractionProjection) -> RunExtractionProjection:
	return RunExtractionProjection.create(policy.automatic_item_ids, policy.eligible_items, policy.selected_item_ids, policy.lost_item_ids, policy.capacity, policy.errors, policy.failure_kind)
