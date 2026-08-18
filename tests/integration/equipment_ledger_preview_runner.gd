extends SceneTree

const PAGE_SCENE_PATH := "res://scenes/ui/ledger/equipment_inventory_ledger_page.tscn"
const PREVIEW_PATH := "Layout/Body/EquipmentRegion/Doll/PreviewProtectedCenter/CharacterEquipmentPreview"

var _failures: Array[String] = []

class GameplayInputProbe extends Node:
	var mouse_motion_count := 0
	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			mouse_motion_count += 1


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	if not ResourceLoader.exists(PAGE_SCENE_PATH):
		_failures.append("equipment ledger page scene is absent")
		_finish()
		return
	var fixture := _fixture()
	var gameplay_probe := GameplayInputProbe.new()
	root.add_child(gameplay_probe)
	var party := fixture.get("party") as PartyManager
	var run_context := fixture.get("run_context") as PlayerRunContext
	var catalog := fixture.get("catalog") as GameCatalog
	if party == null or run_context == null or catalog == null:
		_finish()
		return
	var member := party.member_by_id(1)
	var leader := (load("res://scenes/characters/leader.tscn") as PackedScene).instantiate() as PartyActor
	root.add_child(leader)
	leader.configure(member)
	leader.position = Vector3(4.0, 0.0, -3.0)
	var health := leader.get_node("HealthComponent") as HealthComponent
	health.current_health = 41.0
	var live_parent := leader.get_parent()
	var live_transform := leader.transform
	var live_health := health.current_health
	var provider := LedgerDataProvider.new()
	provider.configure(party, catalog, Callable(), Callable(), run_context, run_context, catalog.equipment_catalog, catalog.item_foundation_catalog)
	var context := LedgerPlayerContext.new(0)
	context.selected_member_id = 1
	var page := (load(PAGE_SCENE_PATH) as PackedScene).instantiate() as CharacterLedgerPage
	root.add_child(page)
	page.configure(provider, context)
	page.activate()
	await process_frame
	await process_frame
	var preview := page.get_node_or_null(PREVIEW_PATH) as Control
	_assert(preview != null, "ledger embeds the character preview")
	if preview != null:
		var subviewport := preview.get_node("SubViewport") as SubViewport
		_assert(subviewport.own_world_3d, "equipment preview owns an isolated World3D")
		var active := preview.get("active_preview") as CharacterPresentation
		_assert(active != null and active.active_profile == member.class_definition.visual_profile, "selected member class profile is rendered")
		_assert(active != leader.get_node("Presentation"), "preview presentation is distinct from the live actor presentation")
		_assert(active != null and active.get_world_3d() != leader.get_world_3d(), "preview actor world is isolated from the arena world")
		var model := active.active_model as ForgeHumanoidModel if active != null else null
		_assert(model != null and model.equipped_definitions.has(&"helmet"), "accepted equipped helmet is rendered")
		var active_id := active.get_instance_id() if active != null else 0
		page.deactivate()
		_assert(preview.get("active_preview") == null, "deactivation releases preview actor")
		page.deactivate()
		_assert(preview.get("active_preview") == null, "repeated deactivation remains idempotent")
		page.activate()
		await process_frame
		await process_frame
		var reactivated := preview.get("active_preview") as CharacterPresentation
		var reactivated_model := reactivated.active_model as ForgeHumanoidModel if reactivated != null else null
		_assert(reactivated != null and reactivated.get_instance_id() != active_id, "reactivation rebuilds the selected member preview")
		_assert(active_id == 0 or not is_instance_id_valid(active_id), "deactivation frees the previous preview actor")
		_assert(reactivated_model != null and reactivated_model.equipped_definitions.has(&"helmet"), "reactivation preserves selected member equipment visuals")
		var before_id := reactivated.get_instance_id() if reactivated != null else 0
		var helmet := page.get_node("Layout/Body/EquipmentRegion/Doll/Slots/Slot_helmet") as StorageSlotButton
		var invalid := page.get_node("Layout/Body/EquipmentRegion/Doll/Slots/Slot_body_armour") as StorageSlotButton
		invalid.item_dropped.emit(helmet.container_id, helmet.slot, helmet.item_id, invalid.container_id, invalid.slot)
		_assert((preview.get("active_preview") as CharacterPresentation).get_instance_id() == before_id, "rejected equipment drop does not refresh preview")
		var inventory := page.get_node("Layout/Body/InventoryRegion/InventoryScroll/Grid") as GridContainer
		var empty := inventory.get_node("InventorySlot_004") as StorageSlotButton
		empty.item_dropped.emit(helmet.container_id, helmet.slot, helmet.item_id, empty.container_id, empty.slot)
		var after := preview.get("active_preview") as CharacterPresentation
		_assert(after != null and after.get_instance_id() != before_id, "accepted unequip replaces only the presentation copy")
		var after_model := after.active_model as ForgeHumanoidModel if after != null else null
		_assert(after_model != null and not after_model.equipped_definitions.has(&"helmet"), "accepted unequip clears the preview helmet")
		var mount := preview.get_node("SubViewport/World/PreviewRoot") as Node3D
		var preview_center := preview.get_global_rect().get_center()
		var yaw_before_input := mount.rotation.y
		root.push_input(_mouse_button(preview_center, true))
		await process_frame
		root.push_input(_mouse_motion(preview_center + Vector2(80.0, 0.0), Vector2(80.0, 0.0), MOUSE_BUTTON_MASK_LEFT))
		await process_frame
		root.push_input(_mouse_button(preview_center + Vector2(80.0, 0.0), false))
		await process_frame
		_assert(not is_equal_approx(mount.rotation.y, yaw_before_input), "mouse drag over the preview rotates the presentation host (rect=%s root=%s center=%s)" % [preview.get_global_rect(), root.size, preview_center])
		_assert(gameplay_probe.mouse_motion_count == 0, "preview drag is consumed before gameplay movement (unhandled=%d rect=%s)" % [gameplay_probe.mouse_motion_count, preview.get_global_rect()])
		_assert(mount.rotation.y >= -PI and mount.rotation.y <= PI, "preview drag is bounded to a full horizontal turn")
		_assert(is_equal_approx(mount.rotation.x, deg_to_rad(-8.0)), "preview drag retains the fixed vertical angle")
		var yaw_before_outside := mount.rotation.y
		root.push_input(_mouse_motion(Vector2(2.0, 2.0), Vector2(60.0, 0.0), MOUSE_BUTTON_MASK_LEFT))
		await process_frame
		_assert(is_equal_approx(mount.rotation.y, yaw_before_outside), "mouse motion outside the preview does not rotate it")
	_assert(leader.get_parent() == live_parent, "live actor parent remains unchanged")
	_assert(leader.transform == live_transform, "live actor transform remains unchanged")
	_assert(is_equal_approx(health.current_health, live_health), "live actor health remains unchanged")
	var teardown_preview_id := _active_preview_id(preview)
	root.remove_child(page)
	_assert(preview.get("active_preview") == null, "scene-tree teardown releases preview actor")
	_assert(teardown_preview_id == 0 or not is_instance_id_valid(teardown_preview_id), "scene-tree teardown frees the preview actor")
	page.free()
	leader.free()
	party.free()
	await process_frame
	_finish()


func _fixture() -> Dictionary:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var profile := ProfileState.new_profile("task11-preview", "Task 11 Preview", 1000)
	profile.inventory_columns = 5
	var context := PlayerRunContext.new()
	var errors := context.configure(&"task11_preview_owner", 0, profile, 111111, party, 100)
	_assert(errors.is_empty(), "preview fixture run context configures")
	if not errors.is_empty():
		return {"party": party, "catalog": catalog}
	var decoded := ItemInstanceCodec.decode({
		"schema_version": ItemInstance.SCHEMA_VERSION,
		"instance_id": "task11-preview-helmet",
		"base_definition_id": "dawn_bulwark_crown",
		"base_damage_components": [],
		"item_level": 12,
		"rarity_id": "common",
		"affixes": [],
		"origin": {"issuer_namespace": "run:%s:%d:%s" % [context.profile_id, context.run_seed, context.run_player_id], "seed": context.run_seed, "sequence": 0, "source": "task11-preview"},
	}, catalog.equipment_catalog, catalog.item_foundation_catalog)
	_assert(decoded.ok(), "preview helmet decodes")
	if decoded.ok():
		_assert(context.apply_item_transaction(ItemTransactionRequest.create("task11-preview-create", String(context.run_player_id), &"run-inventory", 0, decoded.item), catalog.equipment_catalog, catalog.item_foundation_catalog).ok(), "preview helmet enters inventory")
		_assert(context.assign_equipment(1, decoded.item.instance_id, &"helmet", catalog.equipment_catalog, catalog.item_foundation_catalog).ok(), "preview helmet equips")
	return {"party": party, "catalog": catalog, "run_context": context}


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _active_preview_id(preview: Control) -> int:
	if preview == null:
		return 0
	var active := preview.get("active_preview") as CharacterPresentation
	return active.get_instance_id() if active != null else 0


func _mouse_motion(position: Vector2, relative: Vector2, button_mask: MouseButtonMask) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = relative
	event.button_mask = button_mask
	return event


func _mouse_button(position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	return event


func _finish() -> void:
	for failure: String in _failures:
		push_error("TASK11_EQUIPMENT_LEDGER_PREVIEW_FAILURE: %s" % failure)
	print("TASK11_EQUIPMENT_LEDGER_PREVIEW_SUMMARY: %s (%d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _failures.size()])
	quit(0 if _failures.is_empty() else 1)
