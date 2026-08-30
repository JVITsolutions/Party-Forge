extends RefCounted

const CONTROLLER_PATH := "res://scripts/ui/run_result/terminal_extraction_selection_controller.gd"

func run() -> Array[String]:
	var failures: Array[String] = []
	var controller_type := load(CONTROLLER_PATH) as Script
	TestAssertions.truthy(controller_type != null, "terminal extraction selection controller exists", failures)
	if controller_type == null:
		return failures
	_test_defaults_and_bounds(controller_type, failures)
	_test_pending_acknowledgement_and_order(controller_type, failures)
	_test_acknowledgement_tracks_exact_reconciled_projection(controller_type, failures)
	_test_exact_reconcile_and_duplicates(controller_type, failures)
	_test_capacity_drift_reconcile(controller_type, failures)
	_test_durable_selection_initialization(controller_type, failures)
	return failures

func _test_defaults_and_bounds(controller_type: Script, failures: Array[String]) -> void:
	var all_fit: RunExtractionProjection = _policy(3, [_selection("a", &"run-inventory", 0), _selection("b", &"run-inventory", 1)], ["automatic"])
	var controller: Variant = controller_type.new()
	TestAssertions.truthy(controller.call(&"initialize", all_fit), "all-fit policy initializes", failures)
	TestAssertions.equal(controller.call(&"selected_item_ids"), ["a", "b"], "all-fit defaults selected in canonical order", failures)
	TestAssertions.truthy(not controller.call(&"toggle", "automatic"), "automatic item cannot toggle", failures)
	var constrained: RunExtractionProjection = _policy(1, [_selection("a", &"run-inventory", 0), _selection("b", &"run-inventory", 1)], ["automatic"])
	TestAssertions.truthy(controller.call(&"initialize", constrained), "constrained policy initializes", failures)
	TestAssertions.equal(controller.call(&"selected_item_ids"), [], "constrained choice starts empty", failures)
	TestAssertions.truthy(controller.call(&"toggle", "b"), "eligible item toggles", failures)
	TestAssertions.truthy(not controller.call(&"toggle", "a"), "over-capacity selection is rejected", failures)
	TestAssertions.equal(controller.call(&"selected_item_ids"), ["b"], "bounded selection is retained", failures)
	var zero: RunExtractionProjection = _policy(0, [_selection("a", &"run-inventory", 0), _selection("b", &"run-inventory", 1)])
	TestAssertions.truthy(controller.call(&"initialize", zero), "zero-capacity policy remains presentable", failures)
	TestAssertions.equal(controller.call(&"selected_item_ids"), [], "zero capacity selects nothing", failures)
	TestAssertions.truthy(not controller.call(&"toggle", "a"), "zero capacity rejects selection", failures)

func _test_pending_acknowledgement_and_order(controller_type: Script, failures: Array[String]) -> void:
	var controller: Variant = controller_type.new()
	var policy: RunExtractionProjection = _policy(3, [
		_selection("a", &"run-equipment-001", 9),
		_selection("b", &"run-equipment-002", 7),
		_selection("c", &"run-inventory", 0),
		_selection("d", &"run-inventory", 4),
	])
	controller.call(&"initialize", policy)
	controller.call(&"toggle", "d")
	controller.call(&"toggle", "a")
	TestAssertions.equal(controller.call(&"selected_item_ids"), ["a", "d"], "selection order follows policy rather than click order", failures)
	TestAssertions.truthy(controller.call(&"needs_unused_capacity_acknowledgement"), "unused slot plus loss requires acknowledgement", failures)
	controller.call(&"acknowledge_unused_capacity")
	TestAssertions.truthy(not controller.call(&"needs_unused_capacity_acknowledgement"), "explicit acknowledgement clears warning", failures)
	controller.call(&"toggle", "d")
	TestAssertions.truthy(controller.call(&"needs_unused_capacity_acknowledgement"), "selection change resets acknowledgement", failures)
	controller.call(&"set_pending", true)
	TestAssertions.truthy(not controller.call(&"toggle", "b"), "pending state rejects mutation", failures)
	TestAssertions.truthy(not controller.call(&"acknowledge_unused_capacity"), "pending state rejects acknowledgement", failures)
	controller.call(&"set_pending", false)
	TestAssertions.truthy(controller.call(&"toggle", "c"), "selection resumes after pending clears", failures)
	var exact: Array = controller.call(&"selected_selections")
	TestAssertions.equal(_documents(exact), [
		{"item_id": "a", "expected_source_container_id": "run-equipment-001", "expected_source_slot": 9},
		{"item_id": "c", "expected_source_container_id": "run-inventory", "expected_source_slot": 0},
	], "controller returns copied exact source tokens in policy order", failures)
	(exact[0] as ExtractionSelection)._item_id = "escaped"
	TestAssertions.equal(controller.call(&"selected_item_ids"), ["a", "c"], "selected tokens are defensive copies", failures)

func _test_acknowledgement_tracks_exact_reconciled_projection(controller_type: Script, failures: Array[String]) -> void:
	var controller: Variant = controller_type.new()
	var exact := _policy(3, [
		_selection("a", &"run-inventory", 0),
		_selection("b", &"run-inventory", 1),
		_selection("c", &"run-inventory", 2),
		_selection("d", &"run-inventory", 3),
	])
	controller.call(&"initialize", exact)
	controller.call(&"toggle", "a")
	controller.call(&"toggle", "b")
	TestAssertions.truthy(controller.call(&"acknowledge_unused_capacity"), "exact projection acknowledgement fixture is accepted", failures)
	var changed: Array = controller.call(&"reconcile", exact)
	TestAssertions.equal(changed, [], "unchanged exact projection reconciliation preserves every selection", failures)
	TestAssertions.truthy(not controller.call(&"needs_unused_capacity_acknowledgement"), "unchanged exact projection preserves its explicit acknowledgement", failures)
	changed = controller.call(&"reconcile", _policy(4, exact.eligible_items))
	TestAssertions.equal(changed, [], "capacity drift can change acknowledgement truth without changing selected identities", failures)
	TestAssertions.truthy(controller.call(&"needs_unused_capacity_acknowledgement"), "changed capacity/loss projection invalidates the prior acknowledgement", failures)

func _test_exact_reconcile_and_duplicates(controller_type: Script, failures: Array[String]) -> void:
	var controller: Variant = controller_type.new()
	var initial: RunExtractionProjection = _policy(2, [_selection("a", &"run-inventory", 0), _selection("b", &"run-inventory", 1)])
	controller.call(&"initialize", initial)
	var changed: Array = controller.call(&"reconcile", _policy(2, [_selection("a", &"run-inventory", 0), _selection("b", &"run-equipment-002", 7)]))
	TestAssertions.equal(changed, ["b"], "changed source token is invalidated exactly", failures)
	TestAssertions.equal(controller.call(&"selected_item_ids"), ["a"], "still-valid selection survives reconcile", failures)
	changed = controller.call(&"reconcile", _policy(2, [_selection("b", &"run-equipment-002", 7)]))
	TestAssertions.equal(changed, ["a"], "missing selected item is reported changed", failures)
	var duplicate := _policy(2, [_selection("dup", &"run-inventory", 0), _selection("dup", &"run-inventory", 1)])
	TestAssertions.truthy(not controller.call(&"initialize", duplicate), "duplicate eligible item IDs fail closed", failures)
	TestAssertions.equal(controller.call(&"selected_item_ids"), [], "duplicate failure exposes no ambiguous selection", failures)
	controller.call(&"initialize", initial)
	changed = controller.call(&"reconcile", _policy(2, [_selection("a", &"run-inventory", 0), _selection("b", &"run-inventory", 1)], ["automatic", "automatic"]))
	TestAssertions.equal(changed, ["a", "b"], "duplicate automatic IDs make reconcile fail closed", failures)
	TestAssertions.equal(controller.call(&"selected_item_ids"), [], "duplicate automatic reconcile exposes no ambiguous selection", failures)

func _test_capacity_drift_reconcile(controller_type: Script, failures: Array[String]) -> void:
	var controller: Variant = controller_type.new()
	var initial := _policy(3, [
		_selection("a", &"run-inventory", 0),
		_selection("b", &"run-inventory", 1),
		_selection("c", &"run-inventory", 2),
		_selection("d", &"run-inventory", 3),
	])
	controller.call(&"initialize", initial)
	controller.call(&"toggle", "c")
	controller.call(&"toggle", "a")
	controller.call(&"toggle", "b")
	TestAssertions.equal(controller.call(&"selected_item_ids"), ["a", "b", "c"], "precondition uses canonical selection order", failures)
	controller.call(&"acknowledge_unused_capacity")
	var changed: Array = controller.call(&"reconcile", _policy(1, initial.eligible_items))
	TestAssertions.equal(changed, ["b", "c"], "capacity shrink deterministically reports trailing canonical selections", failures)
	TestAssertions.equal(controller.call(&"selected_item_ids"), ["a"], "capacity shrink never exposes over-capacity exact tokens", failures)
	TestAssertions.truthy(not controller.call(&"needs_unused_capacity_acknowledgement"), "full shrunken capacity has no unused-slot acknowledgement", failures)
	changed = controller.call(&"reconcile", _policy(3, initial.eligible_items))
	TestAssertions.equal(changed, [], "capacity growth does not invalidate a still-exact selection", failures)
	TestAssertions.equal(controller.call(&"selected_item_ids"), ["a"], "capacity growth never invents restored selections", failures)
	TestAssertions.truthy(controller.call(&"needs_unused_capacity_acknowledgement"), "capacity growth resets acknowledgement against current loss", failures)

func _test_durable_selection_initialization(controller_type: Script, failures: Array[String]) -> void:
	var controller: Variant = controller_type.new()
	var durable := _policy(2, [
		_selection("a", &"run-inventory", 0),
		_selection("b", &"run-inventory", 1),
		_selection("c", &"run-inventory", 2),
	], [], ["b", "c"])
	TestAssertions.truthy(controller.call(&"initialize", durable), "durable constrained projection initializes", failures)
	TestAssertions.equal(controller.call(&"selected_item_ids"), ["b", "c"], "cold initialization restores exact durable selections in canonical order", failures)
	var invalid := _policy(1, durable.eligible_items, [], ["missing"])
	TestAssertions.truthy(not controller.call(&"initialize", invalid), "unknown durable selected identity fails closed", failures)

func _policy(capacity: int, eligible: Array[ExtractionSelection], automatic: Array[String] = [], selected: Array[String] = []) -> RunExtractionProjection:
	var lost: Array[String] = []
	for selection: ExtractionSelection in eligible:
		if selection.item_id not in selected:
			lost.append(selection.item_id)
	return RunExtractionProjection.create(automatic, eligible, selected, lost, capacity, [])

func _selection(item_id: String, container_id: StringName, slot: int) -> ExtractionSelection:
	return ExtractionSelection.create(item_id, container_id, slot)

func _documents(values: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Variant in values:
		result.append((value as ExtractionSelection).to_dictionary())
	return result
