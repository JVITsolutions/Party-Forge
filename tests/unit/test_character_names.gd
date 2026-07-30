extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var class_pool := CharacterNamePool.new()
	class_pool.id = &"fixture_class"
	class_pool.names = PackedStringArray(["Aldric", "Branna"])
	var fallback_pool := CharacterNamePool.new()
	fallback_pool.id = &"generic"
	fallback_pool.names = PackedStringArray(["Ada", "Bram"])

	var first := CharacterNameService.choose_name(class_pool, fallback_pool, 1337, 1, PackedStringArray())
	var repeated := CharacterNameService.choose_name(class_pool, fallback_pool, 1337, 1, PackedStringArray())
	TestAssertions.equal(first, repeated, "same seed and member id choose the same name", failures)

	var second := CharacterNameService.choose_name(class_pool, fallback_pool, 1337, 2, PackedStringArray([first]))
	TestAssertions.truthy(second != first, "used class name is avoided while alternatives exist", failures)

	var empty_class_pool := CharacterNamePool.new()
	empty_class_pool.id = &"empty"
	var fallback_name := CharacterNameService.choose_name(empty_class_pool, fallback_pool, 1337, 3, PackedStringArray())
	TestAssertions.truthy(fallback_name in fallback_pool.names, "empty class pool uses generic names", failures)

	var definition := ClassDefinition.new()
	var member := PartyMemberState.new(7, definition, false, "Stored Name")
	TestAssertions.equal(member.character_name, "Stored Name", "member state stores the chosen name", failures)
	member.character_name = "Edited Name"
	TestAssertions.equal(member.character_name, "Edited Name", "stored member name remains mutable", failures)
	return failures
