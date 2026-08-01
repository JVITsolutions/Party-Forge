extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var tree := Engine.get_main_loop() as SceneTree
	tree.paused = false
	var run := GameRun.new()
	run.start_run()
	run.call("_process", 1.0)
	TestAssertions.near(run.elapsed_time(), 1.0, 0.001, "RUNNING automatic clock advances", failures)
	tree.paused = true
	run.call("_process", 3.0)
	TestAssertions.near(run.elapsed_time(), 1.0, 0.001, "tree pause blocks automatic clock", failures)
	tree.paused = false
	run.begin_level_up()
	run.call("_process", 2.0)
	TestAssertions.near(run.elapsed_time(), 1.0, 0.001, "LEVEL_UP blocks automatic clock", failures)
	run.resume_run()
	run.advance_run_time(RunStateMachine.BOSS_TIME)
	TestAssertions.truthy(run.can_advance_automatically(tree), "BOSS remains automatically eligible", failures)
	run.call("_process", 0.5)
	TestAssertions.near(run.elapsed_time(), RunStateMachine.BOSS_TIME, 0.001, "BOSS run clock remains capped", failures)
	tree.paused = false
	run.free()
	return failures
