extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.equal(RunSetupResponsiveLayout.mode_for_size(Vector2(1600.0, 900.0)), RunSetupResponsiveLayout.Mode.DESKTOP, "1600 by 900 is desktop", failures)
	TestAssertions.equal(RunSetupResponsiveLayout.mode_for_size(Vector2(1599.0, 900.0)), RunSetupResponsiveLayout.Mode.COMPACT, "width below 1600 is compact", failures)
	TestAssertions.equal(RunSetupResponsiveLayout.mode_for_size(Vector2(1600.0, 899.0)), RunSetupResponsiveLayout.Mode.COMPACT, "height below 900 is compact", failures)
	TestAssertions.equal(RunSetupResponsiveLayout.content_width_for_size(Vector2(1920.0, 1080.0)), 1920.0, "native desktop content width is unchanged", failures)
	TestAssertions.equal(RunSetupResponsiveLayout.content_width_for_size(Vector2(3840.0, 2160.0)), 1920.0, "ultrawide content is bounded to 1920 logical pixels", failures)
	return failures
