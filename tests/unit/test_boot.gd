extends RefCounted

func run() -> Array[String]:
    var failures: Array[String] = []
    TestAssertions.equal(ProjectSettings.get_setting("application/config/name"), "Party Forge", "project name", failures)
    TestAssertions.truthy(ResourceLoader.exists("res://scenes/game/main.tscn"), "main scene exists", failures)
    return failures
