extends RefCounted

const PROFILE_ROOT_PREFIX := "user://tests/profile_boot_integration"


func run() -> Array[String]:
	var failures: Array[String] = []
	var root := "%s_%d_%d" % [PROFILE_ROOT_PREFIX, OS.get_process_id(), Time.get_ticks_usec()]
	ProfileTestSupport.remove_tree(root)
	_test_fresh_boot_and_run_gate(root, failures)
	ProfileTestSupport.remove_tree(root)

	var error_root := "%s_error_%d_%d" % [PROFILE_ROOT_PREFIX, OS.get_process_id(), Time.get_ticks_usec()]
	ProfileTestSupport.remove_tree(error_root)
	_test_bootstrap_error_routes_to_profiles(error_root, failures)
	_remove_file(error_root)
	return failures


func _test_fresh_boot_and_run_gate(root: String, failures: Array[String]) -> void:
	var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate() as PartyForgeMain
	main.set("profile_root", root)
	(Engine.get_main_loop() as SceneTree).root.add_child(main)
	main.call("_ready")
	TestAssertions.truthy(main.get("profile_manager") is ProfileManager, "main creates ProfileManager", failures)
	TestAssertions.equal(main.call("active_profile"), null, "fresh boot has no active profile", failures)
	var settings := main.get_node("SettingsScreen") as SettingsScreen
	TestAssertions.truthy(settings.is_open(), "fresh boot opens Profiles Settings", failures)

	TestAssertions.truthy(not main.call("select_leader_class", &"fighter"), "run launch rejects missing profile", failures)
	TestAssertions.truthy(not main.call("select_leader_class", &"fighter"), "repeated run launch still rejects missing profile", failures)
	TestAssertions.equal(main.get("run_started"), false, "missing profile leaves gameplay unstarted", failures)
	TestAssertions.equal(main.get("leader"), null, "missing profile creates no leader", failures)
	TestAssertions.truthy(settings.is_open(), "missing profile keeps Profiles Settings open", failures)

	var manager := main.get("profile_manager") as ProfileManager
	var created := manager.create_profile("Jacob", 1000)
	TestAssertions.truthy(created.ok(), "profile creates through boot manager", failures)
	var exposed := main.call("active_profile") as ProfileState
	TestAssertions.truthy(exposed != null, "main exposes the selected profile", failures)
	if exposed != null:
		exposed.display_name = "Mutated Copy"
		TestAssertions.equal((main.call("active_profile") as ProfileState).display_name, "Jacob", "main active profile is a defensive copy", failures)
	TestAssertions.truthy(main.call("select_leader_class", &"fighter"), "active profile permits existing arena launch", failures)
	TestAssertions.equal(main.get("run_started"), true, "profile-backed class selection starts gameplay", failures)
	(Engine.get_main_loop() as SceneTree).paused = false
	main.free()


func _test_bootstrap_error_routes_to_profiles(root: String, failures: Array[String]) -> void:
	var file := FileAccess.open(root, FileAccess.WRITE)
	TestAssertions.truthy(file != null, "bootstrap error fixture creates an exact conflicting root", failures)
	if file == null:
		return
	file.store_string("not a profile directory")
	file.close()
	var expected_error := "PROFILE_BOOTSTRAP_ERROR root=%s stage=validate-root reason=path is not a directory" % root
	TestAssertions.equal(ProfileManager.new().bootstrap(root), expected_error, "bootstrap error source includes the exact injected root", failures)
	var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate() as PartyForgeMain
	main.set("profile_root", root)
	(Engine.get_main_loop() as SceneTree).root.add_child(main)
	main.call("_ready")
	var settings := main.get_node("SettingsScreen") as SettingsScreen
	TestAssertions.equal(main.call("active_profile"), null, "bootstrap error exposes no active profile", failures)
	TestAssertions.equal(settings.get("_profile_manager"), main.get("profile_manager"), "bootstrap error routes the main manager to Profiles Settings", failures)
	TestAssertions.truthy(settings.is_open(), "bootstrap error opens Settings", failures)
	TestAssertions.truthy(not main.call("select_leader_class", &"fighter"), "bootstrap error cannot launch a run", failures)
	TestAssertions.equal(main.get("run_started"), false, "bootstrap error leaves gameplay unstarted", failures)
	(Engine.get_main_loop() as SceneTree).paused = false
	main.free()


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
