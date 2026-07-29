extends RefCounted

func run() -> Array[String]:
    var failures: Array[String] = []
    var catalog: GameCatalog = GameCatalog.load_defaults()
    TestAssertions.equal(catalog.classes.size(), 4, "four classes", failures)
    TestAssertions.equal(catalog.traits.size(), 7, "seven traits", failures)
    TestAssertions.equal(catalog.enemies.size(), 3, "two enemies plus boss", failures)
    TestAssertions.equal(catalog.validate().size(), 0, "catalog validates", failures)
    TestAssertions.equal(catalog.class_by_id(&"fighter").traits, [&"martial", &"vanguard"], "fighter traits", failures)
    TestAssertions.equal(catalog.class_by_id(&"cleric").support_action.id, &"cleric_heal", "cleric heal", failures)
    return failures
