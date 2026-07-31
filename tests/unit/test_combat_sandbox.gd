extends RefCounted

const SANDBOX_SCENE := "res://scenes/dev/combat_sandbox.tscn"
const SANDBOX_SCRIPT := "res://scripts/dev/combat_sandbox.gd"

const REQUIRED_BUTTONS: PackedStringArray = [
    "HUD/Panel/Content/Buttons/Fighter",
    "HUD/Panel/Content/Buttons/Ranger",
    "HUD/Panel/Content/Buttons/Mage",
    "HUD/Panel/Content/Buttons/Cleric",
    "HUD/Panel/Content/Buttons/Swarmer",
    "HUD/Panel/Content/Buttons/Spitter",
    "HUD/Panel/Content/Buttons/ForgeGuardian",
    "HUD/Panel/Content/Buttons/DownSelectedCompanion",
    "HUD/Panel/Content/Buttons/ClearHostiles",
]

const REQUIRED_STATUS: PackedStringArray = [
    "HUD/Panel/Content/PartySize",
    "HUD/Panel/Content/ClassRanks",
    "HUD/Panel/Content/TraitCounts",
    "HUD/Panel/Content/ActiveTiers",
    "HUD/Panel/Content/SelectedCompanion",
]

func run() -> Array[String]:
    var failures: Array[String] = []
    TestAssertions.truthy(ResourceLoader.exists(SANDBOX_SCRIPT), "combat sandbox script exists", failures)
    TestAssertions.truthy(ResourceLoader.exists(SANDBOX_SCENE), "combat sandbox scene exists", failures)
    if not ResourceLoader.exists(SANDBOX_SCENE):
        return failures

    var packed := load(SANDBOX_SCENE) as PackedScene
    var sandbox := packed.instantiate()
    for path: String in REQUIRED_BUTTONS:
        TestAssertions.truthy(sandbox.has_node(path), "sandbox button %s" % path.get_file(), failures)
    for path: String in REQUIRED_STATUS:
        TestAssertions.truthy(sandbox.has_node(path), "sandbox status %s" % path.get_file(), failures)
    for method: StringName in [&"spawn_class", &"spawn_enemy", &"spawn_boss", &"down_selected_companion", &"clear_hostiles", &"refresh_status", &"cap_override_allowed"]:
        TestAssertions.truthy(sandbox.has_method(method), "sandbox public action %s" % method, failures)

    if sandbox.has_method("cap_override_allowed"):
        TestAssertions.truthy(not sandbox.call("cap_override_allowed", false, SANDBOX_SCENE), "ordinary sandbox launch keeps party cap", failures)
        TestAssertions.truthy(not sandbox.call("cap_override_allowed", true, "res://scenes/game/main.tscn"), "editor main scene keeps party cap", failures)
        TestAssertions.truthy(sandbox.call("cap_override_allowed", true, SANDBOX_SCENE), "direct editor sandbox launch permits cap override", failures)
    TestAssertions.truthy(sandbox.has_method(&"cap_override_allowed_for_current_scene"), "sandbox exposes a current-scene launch boundary", failures)
    if sandbox.has_method(&"cap_override_allowed_for_current_scene"):
        TestAssertions.truthy(sandbox.call("cap_override_allowed_for_current_scene", true, sandbox), "direct current sandbox scene permits cap override", failures)
        var main_scene := (load("res://scenes/game/main.tscn") as PackedScene).instantiate()
        var embedded_sandbox := packed.instantiate()
        main_scene.add_child(embedded_sandbox)
        TestAssertions.equal(embedded_sandbox.scene_file_path, SANDBOX_SCENE, "embedded sandbox retains its packed-scene origin", failures)
        TestAssertions.truthy(not embedded_sandbox.call("cap_override_allowed_for_current_scene", true, main_scene), "sandbox embedded under another current scene keeps production cap", failures)
        main_scene.free()

    if sandbox.has_method("spawn_class"):
        sandbox.call("_ready")
        for class_id: StringName in [&"fighter", &"ranger", &"mage", &"cleric", &"fighter"]:
            sandbox.call("spawn_class", class_id)
        var manager := sandbox.get_node("PartyManager") as PartyManager
        TestAssertions.equal(manager.members.size(), PartyManager.MAX_PARTY_SIZE, "ordinary sandbox enforces production party cap", failures)
        sandbox.call("refresh_status")
        TestAssertions.truthy((sandbox.get_node("HUD/Panel/Content/PartySize") as Label).text.contains("4 / 4"), "party size label is live", failures)
        if manager.has_method(&"configure_capacity"):
            manager.call("configure_capacity", PartyCapacityPolicy.new(24))
            sandbox.call("refresh_status")
            TestAssertions.truthy((sandbox.get_node("HUD/Panel/Content/PartySize") as Label).text.contains("4 / 24"), "party size label uses effective capacity", failures)
        else:
            TestAssertions.truthy(false, "sandbox capacity label requires PartyManager.configure_capacity", failures)
    sandbox.free()
    return failures
