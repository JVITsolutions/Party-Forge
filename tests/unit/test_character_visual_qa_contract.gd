extends RefCounted

const RENDER_TOOL_PATH := "res://tools/render_character_visual_qa.gd"

func run() -> Array[String]:
	var failures: Array[String] = []
	var file := FileAccess.open(RENDER_TOOL_PATH, FileAccess.READ)
	TestAssertions.truthy(file != null, "character visual QA renderer exists", failures)
	if file == null:
		return failures
	var source := file.get_as_text()
	TestAssertions.truthy("const SAMPLE_COUNT := 20" in source, "QA renderer includes loaded and release close attack samples", failures)
	TestAssertions.truthy("Vector3(0.0, 3.15, -5.8)" in source, "QA front camera observes the model's -Z facing axis", failures)
	TestAssertions.truthy("hands_equipped_close" in source, "QA renderer captures close equipped hands", failures)
	TestAssertions.truthy("attack_loaded_close" in source, "QA renderer captures the attack wind-up close", failures)
	TestAssertions.truthy("attack_release_close" in source, "QA renderer captures close attack release", failures)
	TestAssertions.truthy("_clear_png_output" in source, "QA renderer removes stale generated frames before capture", failures)
	TestAssertions.truthy("camera_size" in source, "QA samples can request close framing", failures)
	TestAssertions.truthy("hand_behind_torso" in source, "QA manifest records behind-back hand state", failures)
	TestAssertions.truthy("left_hand_z" in source, "QA manifest records left hand depth", failures)
	TestAssertions.truthy("right_hand_z" in source, "QA manifest records right hand depth", failures)
	TestAssertions.truthy("left_elbow_z" in source, "QA manifest records left elbow depth", failures)
	TestAssertions.truthy("right_elbow_z" in source, "QA manifest records right elbow depth", failures)
	TestAssertions.truthy("arm_span_ratio" in source, "QA manifest records wide display-pose span", failures)
	TestAssertions.truthy("equipment_arm_overlap" in source, "QA manifest records real held-equipment overlap", failures)
	return failures
