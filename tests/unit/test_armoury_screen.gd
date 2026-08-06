extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var storage := Task9StorageFixture.storage(false)
	var screen := (load("res://scenes/ui/armoury/armoury_screen.tscn") as PackedScene).instantiate() as ArmouryScreen
	TestAssertions.truthy(screen.has_method(&"set_pending_run_class"), "Armoury exposes display-only pending run class", failures)
	screen.call("_ready")
	screen.configure_classes(GameCatalog.load_defaults().classes)
	screen.open(storage)
	TestAssertions.equal(screen.process_mode, Node.PROCESS_MODE_ALWAYS, "Armoury processes while the game tree is paused", failures)
	TestAssertions.equal(screen.equipment_button_count(), 11, "Armoury owns exactly eleven leader equipment buttons", failures)
	TestAssertions.equal(screen.stash_tab_count(), 3, "Armoury directly reaches every unlocked stash tab", failures)
	TestAssertions.truthy(screen.get_node_or_null("Overlay/Frame/Layout/Body/Follower") == null, "Armoury v1 has no follower sheet selector", failures)
	TestAssertions.truthy((screen.get_node("Overlay/Frame/Layout/Header/ClassChooser") as OptionButton).visible, "empty loadout exposes target class chooser", failures)
	screen.call("_select_item", "item-ring")
	TestAssertions.equal(screen.selected_item_detail()["instance_id"], "item-ring", "Armoury selected-item API remains available without a persistent inspector", failures)
	TestAssertions.truthy(screen.get_node_or_null("Overlay/Frame/Layout/Body/Inspector") == null, "Armoury removes the persistent inspector column", failures)
	var empty_ring_slot := screen.get_node("Overlay/Frame/Layout/Body/Equipment/Slots").get_child(6) as StorageSlotButton
	TestAssertions.equal(empty_ring_slot.text, "Ring Left", "empty equipment cell retains its equipment label", failures)
	TestAssertions.truthy(empty_ring_slot.accessibility_name.contains("empty"), "empty equipment cell exposes an accessible empty state", failures)
	var occupied_stash := screen.get_node("Overlay/Frame/Layout/Body/Stash/Scroll/Grid").get_child(99) as StorageSlotButton
	TestAssertions.equal(occupied_stash.text, "", "occupied stash cell renders no slot number or truncated item name", failures)
	TestAssertions.truthy(occupied_stash.icon != null, "occupied stash cell renders the authored item icon", failures)
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
	var occupied_leader := screen.get_node("Overlay/Frame/Layout/Body/Equipment/Slots").get_child(0) as StorageSlotButton
	TestAssertions.equal(occupied_leader.text, "", "occupied leader cell is icon-only", failures)
	TestAssertions.truthy(occupied_leader.icon != null, "occupied leader cell renders the authored icon", failures)
	var transitions: Array[StringName] = []
	screen.loadout_class_change_requested.connect(func(class_id: StringName) -> void: transitions.append(class_id))
	screen.choose_class(&"mage")
	TestAssertions.equal(transitions, [&"mage"], "nonempty class choice emits future compatibility-transition intent", failures)

	var empty_mage := Task9StorageFixture.storage(false, &"mage")
	screen.open(empty_mage)
	var chooser := screen.get_node("Overlay/Frame/Layout/Header/ClassChooser") as OptionButton
	TestAssertions.equal(StringName(chooser.get_item_metadata(chooser.selected)), &"mage", "empty loadout chooser selects stored active class", failures)
	equip.clear()
	screen.request_drop(&"stash-tab-zeta", 99, "item-ring", &"leader-loadout", 6)
	TestAssertions.equal((equip[0] as Array)[2] if not equip.is_empty() else &"", &"mage", "first empty-loadout equip submits stored Mage target", failures)

	var compare_storage := _comparison_storage()
	screen.open(compare_storage, null, true)
	var compare_button := screen.get_node("Overlay/Frame/Layout/Body/Stash/Scroll/Grid").get_child(99) as StorageSlotButton
	compare_button.inspection_started.emit(compare_button)
	var tooltip := screen.get_node("Overlay/ItemTooltip") as Control
	TestAssertions.truthy(tooltip.visible, "focus or hover opens the shared item tooltip", failures)
	tooltip.call("set_compare_active", true)
	TestAssertions.equal(int(tooltip.call("card_count")), 3, "stash ring compares against both occupied leader ring slots", failures)
	tooltip.call("toggle_pin")
	screen.close()
	TestAssertions.truthy(not tooltip.visible and not bool(tooltip.call("is_pinned")), "closing Armoury force-dismisses and unpins its tooltip", failures)
	screen.free()
	return failures


func _comparison_storage() -> ProfileStorageProjection:
	var stash_ring := _item("stash-ring", &"windrunner_band", 0)
	var left_ring := _item("left-ring", &"storm_ring", 1)
	var right_ring := _item("right-ring", &"pact_ring", 2)
	var profile := ProfileState.new_profile("armoury-comparison", "Armoury Comparison", 1000)
	profile.item_records = ItemRegistry.new([stash_ring, left_ring, right_ring]).to_dictionary()
	profile.leader_loadout = ItemSlotContainer.create(
		&"leader-loadout",
		ItemSlotContainer.PROFILE_LEADER_EQUIPMENT,
		profile.profile_id,
		11,
		{6: left_ring.instance_id, 7: right_ring.instance_id},
	).to_dictionary()
	profile.leader_loadout_class_id = "fighter"
	profile.stash_tabs = [ItemSlotContainer.create(
		&"stash-tab-compare",
		ItemSlotContainer.PROFILE_STASH_TAB,
		profile.profile_id,
		100,
		{99: stash_ring.instance_id},
	).to_dictionary()]
	return ProfileStorageProjection.from_profile(
		profile,
		GameCatalog.EQUIPMENT_CATALOG,
		GameCatalog.ITEM_FOUNDATION_CATALOG,
		GameCatalog.STAT_CATALOG,
		GameCatalog.load_defaults().class_by_id(&"fighter"),
	)


func _item(instance_id: String, base_id: StringName, sequence: int) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = instance_id
	item.base_definition_id = base_id
	item.item_level = 31
	item.rarity_id = &"rare"
	item.origin = {"issuer_namespace": "profile:armoury-comparison", "seed": 44, "sequence": sequence, "source": "armoury_test"}
	return item
