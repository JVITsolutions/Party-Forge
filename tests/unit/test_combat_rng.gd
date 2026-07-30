extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var rng := CombatRng.new(77, [0.20, 0.80])
	TestAssertions.equal(rng.roll(0.0), {"consumed": false, "draw": -1.0, "success": false}, "zero chance", failures)
	TestAssertions.equal(rng.roll(1.0), {"consumed": false, "draw": -1.0, "success": true}, "certain chance", failures)
	TestAssertions.equal(rng.roll(0.25), {"consumed": true, "draw": 0.20, "success": true}, "draw succeeds", failures)
	TestAssertions.equal(rng.roll(0.25), {"consumed": true, "draw": 0.80, "success": false}, "draw fails", failures)
	TestAssertions.equal(rng.draw_count, 2, "only probabilistic rolls consume draws", failures)

	var seeded := CombatRng.new(991)
	var first_seeded_roll := seeded.roll(0.5)
	seeded.reseed(991)
	TestAssertions.equal(seeded.draw_count, 0, "reseed resets draw count", failures)
	TestAssertions.equal(seeded.roll(0.5), first_seeded_roll, "reseed repeats seeded draws", failures)

	var run := GameRun.new()
	var owned_rng := run.combat_rng
	run.configure_seed(1337)
	TestAssertions.truthy(run.combat_rng is CombatRng, "run owns combat RNG", failures)
	TestAssertions.truthy(run.combat_rng == owned_rng, "run reseeds one combat RNG", failures)
	run.free()

	var source := CombatantAdapter.new(null, &"party:1", 1)
	var tags: Array[StringName] = [&"melee", &"physical"]
	var component := PreparedDamageComponent.new(&"physical", 18.0, 21.6, 25.92, 38.88)
	var prepared: Array[PreparedDamageComponent] = [component]
	var packet := DamagePacket.create(source, &"fighter_cleave", tags, true, true, 0.1, 1.5, 0.05, prepared)
	tags.clear()
	component.damage_type_id = &"fire"
	component.post_crit = 999.0
	prepared.clear()
	TestAssertions.equal(packet.action_tags, [&"melee", &"physical"], "packet copies caller tags", failures)
	TestAssertions.equal(packet.components.size(), 1, "packet copies caller component array", failures)
	TestAssertions.equal(packet.components[0].damage_type_id, &"physical", "packet copies caller component type", failures)
	TestAssertions.near(packet.components[0].post_crit, 38.88, 0.001, "packet copies caller component values", failures)
	var exposed_components := packet.components
	exposed_components[0].post_crit = 777.0
	exposed_components.clear()
	TestAssertions.equal(packet.components.size(), 1, "packet component getter returns copy", failures)
	TestAssertions.near(packet.components[0].post_crit, 38.88, 0.001, "packet component values remain immutable", failures)
	return failures
