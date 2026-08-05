extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var storage := Task9StorageFixture.storage(false)
	var screen := (load("res://scenes/ui/armoury/armoury_screen.tscn") as PackedScene).instantiate() as ArmouryScreen
	screen.call("_ready")
	screen.configure_classes(GameCatalog.load_defaults().classes)
	screen.open(storage)
	TestAssertions.equal(screen.process_mode, Node.PROCESS_MODE_ALWAYS, "Armoury processes while the game tree is paused", failures)
	TestAssertions.equal(screen.equipment_button_count(), 11, "Armoury owns exactly eleven leader equipment buttons", failures)
	TestAssertions.equal(screen.stash_tab_count(), 3, "Armoury directly reaches every unlocked stash tab", failures)
	TestAssertions.truthy(screen.get_node_or_null("Overlay/Frame/Layout/Body/Follower") == null, "Armoury v1 has no follower sheet selector", failures)
	TestAssertions.truthy((screen.get_node("Overlay/Frame/Layout/Header/ClassChooser") as OptionButton).visible, "empty loadout exposes target class chooser", failures)
	var equip: Array = []
	screen.equip_requested.connect(func(item_id: String, slot_id: StringName, class_id: StringName) -> void: equip.append([item_id, slot_id, class_id]))
	screen.request_drop(&"stash-tab-zeta", 99, "item-ring", &"leader-loadout", 6)
	TestAssertions.equal((equip[0] as Array).slice(0, 2) if not equip.is_empty() else [], ["item-ring", &"ring_left"], "mouse/controller placement emits class-qualified equip intent", failures)
	var moved: Array = []
	screen.move_requested.connect(func(item_id: String, container_id: StringName, slot: int) -> void: moved.append([item_id, container_id, slot]))
	screen.request_drop(&"leader-loadout", 6, "item-ring", &"stash-tab-alpha", 4)
	TestAssertions.equal(moved[0] if not moved.is_empty() else [], ["item-ring", &"stash-tab-alpha", 4], "Armoury emits intent-only stash placement", failures)
	screen.apply_viewport_size(Vector2i(1920, 1080))
	TestAssertions.truthy(not (screen.get_node("Overlay/Frame/Layout/Body") as BoxContainer).vertical, "1080p Armoury uses wide responsive layout", failures)
	screen.apply_viewport_size(Vector2i(1200, 700))
	TestAssertions.truthy((screen.get_node("Overlay/Frame/Layout/Body") as BoxContainer).vertical, "compact Armoury stacks without offscreen fixed positioning", failures)

	var nonempty := Task9StorageFixture.storage(true)
	screen.open(nonempty)
	TestAssertions.truthy(not (screen.get_node("Overlay/Frame/Layout/Header/ClassChooser") as OptionButton).visible, "nonempty loadout hides direct target-class chooser", failures)
	TestAssertions.equal(screen.projection().leader_slots[0]["instance_id"], "item-crown", "Armoury retains exact shared leader item identity", failures)
	TestAssertions.equal(screen.projection().stash_tabs[0]["slots"], {"99": "item-ring"}, "Armoury retains exact shared sparse placement", failures)
	var transitions: Array[StringName] = []
	screen.loadout_class_change_requested.connect(func(class_id: StringName) -> void: transitions.append(class_id))
	screen.choose_class(&"mage")
	TestAssertions.equal(transitions, [&"mage"], "nonempty class choice emits future compatibility-transition intent", failures)
	screen.free()
	return failures
