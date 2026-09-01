extends RefCounted

const CATALOG_PATH := "res://scripts/presentation/humanoid_rig_mapping_catalog.gd"
const MAPPING_PATH := "res://scripts/presentation/humanoid_rig_mapping.gd"
const MASCULINE_ID := &"pf_humanoid_v1_mixamo52_masculine"
const FEMININE_ID := &"pf_humanoid_v1_mixamo52_feminine"
const MASCULINE_SHA := "8f589e35f16f02fe4aa0f45b5f2c85377a41f9ecc188670bf59159518e6cdbe4"
const FEMININE_SHA := "173198e3d044418b9765971e8b698664176c05dadd6a5aaa4ddb8df8d4c08667"
const MASCULINE_REST := "1ea73d190881c437d8ca6fc10dd7c4f446d2d14523416bcd0731264dad689eda"
const FEMININE_REST := "fad7e1860ef45781179d156654734b6160a7d97df96be43d3eb8c0bc51ea5c85"

var _catalog_script: Script
var _mapping_script: Script

func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog_exists := FileAccess.file_exists(CATALOG_PATH)
	TestAssertions.truthy(catalog_exists, "body-specific mapping catalog exists", failures)
	if not catalog_exists:
		return failures
	_catalog_script = load(CATALOG_PATH) as Script
	_mapping_script = load(MAPPING_PATH) as Script
	TestAssertions.truthy(_catalog_script != null, "body-specific mapping catalog loads", failures)
	TestAssertions.truthy(_mapping_script != null, "mapping resource script loads", failures)
	if _catalog_script == null or _mapping_script == null:
		return failures
	var masculine := _mapping(MASCULINE_ID, MASCULINE_SHA, MASCULINE_REST)
	var feminine := _mapping(FEMININE_ID, FEMININE_SHA, FEMININE_REST)
	var injected := {&"masculine": masculine, &"feminine": feminine}
	var catalog := _catalog_script.new(injected) as RefCounted

	TestAssertions.equal(catalog.call(&"resolve", &"masculine"), masculine, "masculine resolves only its exact injected mapping", failures)
	TestAssertions.equal(catalog.call(&"resolve", &"feminine"), feminine, "feminine resolves only its exact injected mapping", failures)

	var active_mapping := masculine
	active_mapping = _activate_if_resolved(catalog, &"unknown", active_mapping)
	TestAssertions.equal(active_mapping, masculine, "failed unknown selection leaves active mapping unchanged", failures)

	var crossed_catalog := _catalog_script.new({&"masculine": feminine, &"feminine": masculine}) as RefCounted
	active_mapping = _activate_if_resolved(crossed_catalog, &"masculine", active_mapping)
	TestAssertions.equal(active_mapping, masculine, "failed cross-body masculine selection leaves active mapping unchanged", failures)
	TestAssertions.equal(crossed_catalog.call(&"resolve", &"feminine"), null, "cross-body feminine selection fails", failures)

	var wrong_canonical := _mapping(MASCULINE_ID, MASCULINE_SHA, MASCULINE_REST)
	wrong_canonical.set(&"canonical_rig_id", &"wrong")
	var wrong_canonical_catalog := _catalog_script.new({&"masculine": wrong_canonical}) as RefCounted
	TestAssertions.equal(wrong_canonical_catalog.call(&"resolve", &"masculine"), null, "wrong canonical identity rejects", failures)

	var wrong_id := _mapping(&"wrong", MASCULINE_SHA, MASCULINE_REST)
	var wrong_id_catalog := _catalog_script.new({&"masculine": wrong_id}) as RefCounted
	TestAssertions.equal(wrong_id_catalog.call(&"resolve", &"masculine"), null, "wrong mapping id rejects", failures)

	var wrong_source := _mapping(MASCULINE_ID, FEMININE_SHA, MASCULINE_REST)
	var wrong_source_catalog := _catalog_script.new({&"masculine": wrong_source}) as RefCounted
	TestAssertions.equal(wrong_source_catalog.call(&"resolve", &"masculine"), null, "wrong source hash rejects", failures)

	var wrong_rest := _mapping(MASCULINE_ID, MASCULINE_SHA, FEMININE_REST)
	var wrong_rest_catalog := _catalog_script.new({&"masculine": wrong_rest}) as RefCounted
	TestAssertions.equal(wrong_rest_catalog.call(&"resolve", &"masculine"), null, "wrong source rest signature rejects", failures)

	injected[&"masculine"] = feminine
	TestAssertions.equal(catalog.call(&"resolve", &"masculine"), masculine, "constructor duplicates injected dictionary", failures)

	var script_constants := _catalog_script.get_script_constant_map()
	var resource_paths := script_constants.get("RESOURCE_PATH_BY_BODY_PRESET", {}) as Dictionary
	TestAssertions.equal(
		resource_paths.get(&"masculine"),
		"res://data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_masculine.tres",
		"masculine future resource path is exact",
		failures
	)
	TestAssertions.equal(
		resource_paths.get(&"feminine"),
		"res://data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_feminine.tres",
		"feminine future resource path is exact",
		failures
	)
	return failures

func _mapping(mapping_id: StringName, source_sha: String, rest_signature: String) -> Resource:
	var mapping := _mapping_script.new() as Resource
	mapping.set(&"mapping_id", mapping_id)
	mapping.set(&"canonical_rig_id", &"pf_humanoid_v1")
	mapping.set(&"source_skeleton_sha256", source_sha)
	mapping.set(&"source_rest_signature", rest_signature)
	return mapping

func _activate_if_resolved(catalog: RefCounted, body_preset_id: StringName, active_mapping: Resource) -> Resource:
	var resolved := catalog.call(&"resolve", body_preset_id) as Resource
	return resolved if resolved != null else active_mapping
