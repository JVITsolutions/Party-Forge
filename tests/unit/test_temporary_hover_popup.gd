extends RefCounted


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_transient_and_hold_lifetime(failures)
	_test_preheld_hold_lifetime(failures)
	_test_pin_lock_and_replacement(failures)
	_test_forced_reset(failures)
	return failures


func _test_transient_and_hold_lifetime(failures: Array[String]) -> void:
	var popup := TemporaryHoverPopup.new()
	popup.call("_ready")
	TestAssertions.truthy(popup.present_source(&"first"), "first source is accepted", failures)
	TestAssertions.truthy(popup.visible, "accepted source reveals popup", failures)
	popup.release_source(&"first")
	TestAssertions.truthy(not popup.visible, "transient source exit dismisses", failures)

	popup.present_source(&"first")
	popup.set_hold_active(true)
	popup.release_source(&"first")
	TestAssertions.truthy(popup.visible, "Alt hold retains inactive source", failures)
	popup.set_hold_active(false)
	TestAssertions.truthy(not popup.visible, "Alt release dismisses inactive unpinned source", failures)
	popup.free()


func _test_preheld_hold_lifetime(failures: Array[String]) -> void:
	var popup := TemporaryHoverPopup.new()
	popup.call("_ready")
	popup.set_hold_active(true)
	TestAssertions.truthy(not popup.visible, "hidden Alt does not reveal popup", failures)
	TestAssertions.truthy(not popup.is_pinned(), "hidden Alt does not pin popup", failures)
	popup.present_source(&"preheld")
	popup.release_source(&"preheld")
	TestAssertions.truthy(popup.visible, "Alt held before presentation retains inactive source", failures)
	popup.set_hold_active(false)
	TestAssertions.truthy(not popup.visible, "preheld Alt release dismisses inactive unpinned source", failures)

	popup.set_hold_active(true)
	popup.force_dismiss()
	popup.present_source(&"post_reset")
	popup.release_source(&"post_reset")
	TestAssertions.truthy(not popup.visible, "forced reset clears a hidden preheld Alt state", failures)
	popup.free()


func _test_pin_lock_and_replacement(failures: Array[String]) -> void:
	var popup := TemporaryHoverPopup.new()
	popup.call("_ready")
	var pin_events: Array[bool] = []
	popup.pin_changed.connect(func(pinned: bool) -> void: pin_events.append(pinned))
	popup.present_source(&"first")
	popup.toggle_pin()
	popup.release_source(&"first")
	TestAssertions.truthy(popup.visible and popup.is_pinned(), "pin survives source exit", failures)
	TestAssertions.truthy(not popup.present_source(&"second"), "pinned content rejects another source", failures)
	TestAssertions.truthy(popup.is_current_source(&"first"), "rejected source cannot replace identity", failures)
	popup.toggle_pin()
	TestAssertions.truthy(not popup.visible, "unpinning inactive source dismisses", failures)
	TestAssertions.equal(pin_events, [true, false], "pin signal reports exact transitions", failures)
	popup.free()


func _test_forced_reset(failures: Array[String]) -> void:
	var popup := TemporaryHoverPopup.new()
	popup.call("_ready")
	var events: Array[String] = []
	popup.pin_changed.connect(func(pinned: bool) -> void: events.append("pin:%s" % pinned))
	popup.dismissed.connect(func() -> void: events.append("dismissed"))
	popup.present_source(&"first")
	popup.set_hold_active(true)
	popup.toggle_pin()
	popup.force_dismiss()
	TestAssertions.truthy(not popup.visible, "forced reset hides popup", failures)
	TestAssertions.truthy(not popup.is_pinned(), "forced reset clears pin", failures)
	TestAssertions.truthy(not popup.is_current_source(&"first"), "forced reset clears source", failures)
	TestAssertions.equal(events, ["pin:true", "pin:false", "dismissed"], "forced reset emits one unpin before dismissal", failures)
	popup.force_dismiss()
	TestAssertions.equal(events, ["pin:true", "pin:false", "dismissed"], "hidden reset does not duplicate unpin or dismissal", failures)
	popup.present_source(&"unpinned")
	popup.force_dismiss()
	TestAssertions.equal(events, ["pin:true", "pin:false", "dismissed", "dismissed"], "unpinned forced reset does not emit pin change", failures)
	popup.free()
