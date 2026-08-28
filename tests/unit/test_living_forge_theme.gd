extends RefCounted

const TOKENS_PATH := "res://scripts/ui/living_forge/living_forge_tokens.gd"
const CATALOG_PATH := "res://scripts/ui/living_forge/living_forge_theme_catalog.gd"
const NORMAL_THEME_PATH := "res://data/ui/living_forge/living_forge_theme.tres"
const HIGH_CONTRAST_THEME_PATH := "res://data/ui/living_forge/living_forge_high_contrast_theme.tres"
const PROVENANCE_PATH := "res://docs/third_party/living-forge-ui-assets.md"
const PROVENANCE_SCHEMA_MARKER := "<!-- living-forge-asset-inventory:v1 -->"

const REQUIRED_COLORS: Array[StringName] = [
	&"surface_forged", &"surface_inset", &"ember_primary", &"focus_outline",
	&"text_primary", &"text_muted", &"valid", &"warning", &"error", &"disabled",
]
const REQUIRED_VARIATIONS: Array[StringName] = [
	&"LivingForgePanel", &"LivingForgeInsetPanel", &"LivingForgePrimaryButton",
	&"LivingForgeSecondaryButton", &"LivingForgeUnavailableButton",
	&"LivingForgeDestructiveButton", &"LivingForgeDisplayLabel",
	&"LivingForgeSectionLabel", &"LivingForgeCaptionLabel", &"LivingForgeStatusChip",
]
const REQUIRED_ASSETS: Array[String] = [
	"res://assets/ui/living_forge/fonts/cinzel-2.000/Cinzel[wght].ttf",
	"res://assets/ui/living_forge/fonts/cinzel-2.000/OFL.txt",
	"res://assets/ui/living_forge/fonts/source-sans-3.052/SourceSans3VF-Upright.ttf",
	"res://assets/ui/living_forge/fonts/source-sans-3.052/LICENSE.md",
	"res://assets/ui/living_forge/fonts/noto-sans-2.014/NotoSans[wdth,wght].ttf",
	"res://assets/ui/living_forge/fonts/noto-sans-2.014/OFL.txt",
	"res://assets/ui/living_forge/fonts/noto-sans-symbols-2.008/NotoSansSymbols2-Regular.ttf",
	"res://assets/ui/living_forge/fonts/noto-sans-symbols-2.008/OFL.txt",
	"res://assets/ui/living_forge/icons/tabler-3.46.0/LICENSE",
	"res://assets/ui/living_forge/icons/tabler-3.46.0/arrow-left.svg",
	"res://assets/ui/living_forge/icons/tabler-3.46.0/settings.svg",
	"res://assets/ui/living_forge/icons/tabler-3.46.0/shield.svg",
	"res://assets/ui/living_forge/icons/tabler-3.46.0/check.svg",
	"res://assets/ui/living_forge/icons/tabler-3.46.0/player-play.svg",
	"res://assets/ui/living_forge/icons/tabler-3.46.0/alert-triangle.svg",
	"res://assets/ui/living_forge/icons/tabler-3.46.0/lock.svg",
	"res://assets/ui/living_forge/icons/tabler-3.46.0/user.svg",
	"res://assets/ui/living_forge/icons/tabler-3.46.0/keyboard.svg",
	"res://assets/ui/living_forge/icons/tabler-3.46.0/device-gamepad.svg",
	"res://assets/ui/living_forge/icons/tabler-3.46.0/hourglass.svg",
	"res://assets/ui/living_forge/frames/forge_panel.svg",
	"res://assets/ui/living_forge/frames/class_silhouette.svg",
	"res://docs/third_party/living-forge-ui-assets.md",
]
const ICON_DIRECTORY := "res://assets/ui/living_forge/icons/tabler-3.46.0"
const REQUIRED_ICON_FILES: Array[String] = [
	"alert-triangle.svg", "arrow-left.svg", "check.svg", "device-gamepad.svg",
	"hourglass.svg", "keyboard.svg", "lock.svg", "player-play.svg", "settings.svg",
	"shield.svg", "user.svg",
]
const LATIN_SAMPLE := "Party Forge 0123456789"
const EXTENDED_SAMPLE := "ÀéñŒß Łódź"
const SYMBOL_SAMPLE := "← ✓ ⚠ ⌛"
const EXPECTED_UPSTREAM_MARKERS := {
	"Cinzel": ["2.000", "SIL Open Font License 1.1"],
	"Source Sans 3": ["3.052R", "SIL Open Font License 1.1"],
	"Noto Sans": ["NotoSans-v2.014", "SIL Open Font License 1.1"],
	"Noto Sans Symbols 2": ["NotoSansSymbols2-v2.008", "SIL Open Font License 1.1"],
	"Tabler Icons": ["v3.46.0", "MIT"],
}
const EXPECTED_INVENTORY_SHA256 := {
	"assets/ui/living_forge/fonts/cinzel-2.000/Cinzel[wght].ttf": "f4d83d34d1f6c741193e4acf4b3dff9531e5a67b6aa65228d00a7db72a4e0f34",
	"assets/ui/living_forge/fonts/cinzel-2.000/OFL.txt": "f5a242cf68ad6ebd0603b3359a74c593ca080318a681035be5296ba2c6b04ae6",
	"assets/ui/living_forge/fonts/source-sans-3.052/SourceSans3VF-Upright.ttf": "1147db9a3f0edd4956068de77930148acce2742dd76d57f7239b2b1c687ac63f",
	"assets/ui/living_forge/fonts/source-sans-3.052/LICENSE.md": "937d1985d2d6d003b6efdfa47e098b96c69d55395175f154d7f56410c942f978",
	"assets/ui/living_forge/fonts/noto-sans-2.014/NotoSans[wdth,wght].ttf": "90a2b3c1fc4895e0d5f4ada26aab1592c0c52f4255b874734a8ede8c30cbaa29",
	"assets/ui/living_forge/fonts/noto-sans-2.014/OFL.txt": "e2e177a32561584d4fc13aaa3cd8e53758a12910f013fe9ca125419111722029",
	"assets/ui/living_forge/fonts/noto-sans-symbols-2.008/NotoSansSymbols2-Regular.ttf": "7d5fb73b7ca67a6798101741f5d280a3d016a56a197afcd4199dbb57b4b82a21",
	"assets/ui/living_forge/fonts/noto-sans-symbols-2.008/OFL.txt": "e87c2ed7ff174c637d55fa381939ebb96f43f0415ad94605a37589228f4cbf4f",
	"assets/ui/living_forge/icons/tabler-3.46.0/LICENSE": "b740a1d46122672da62833e97f7e7c8a13fa85cbc7445b584b297cc00dde93db",
	"assets/ui/living_forge/icons/tabler-3.46.0/alert-triangle.svg": "fc82f02dc9702293cb8609a8aed3242c0fe5f5b3337d79d341aa9343b4526ad4",
	"assets/ui/living_forge/icons/tabler-3.46.0/arrow-left.svg": "058fc4190c178ecce118b6294b74235d4f88c4dfbd17c6159d67210a03222bc0",
	"assets/ui/living_forge/icons/tabler-3.46.0/check.svg": "fe359b27c74ed0f4f72bfabbe5ca969a8bb13a5f39648bae63f9e798034ebed3",
	"assets/ui/living_forge/icons/tabler-3.46.0/device-gamepad.svg": "a2591eec1e15bbe8740ad349260c838abe55994e358030b3e5fec09b9a111682",
	"assets/ui/living_forge/icons/tabler-3.46.0/hourglass.svg": "64316d209522bc02b8a205184af4143584d7a4de7b5cb7c1ef8a84aec7aebd3e",
	"assets/ui/living_forge/icons/tabler-3.46.0/keyboard.svg": "8dcb52240a7f121651455a0a71322cb306c7e4695c70b4a9c14c453dc231c5da",
	"assets/ui/living_forge/icons/tabler-3.46.0/lock.svg": "19ef0a4888688ea415b611b7c9e085134683a7fbdce5517be1f722a65e28928d",
	"assets/ui/living_forge/icons/tabler-3.46.0/player-play.svg": "0178cf0262ec89422d632f6122c6be34a8b57db32dd1aea38dd283bdeecbfc2f",
	"assets/ui/living_forge/icons/tabler-3.46.0/settings.svg": "d71136dfd83ad19efe1777d01768a5d23d7b295de5dde3b1fccc50806809a423",
	"assets/ui/living_forge/icons/tabler-3.46.0/shield.svg": "98a7e284db5311c030b1dac736c9300e8c2799980ceb424806cc09894d373a0e",
	"assets/ui/living_forge/icons/tabler-3.46.0/user.svg": "4aeefe49af9decdd7b348ada73d9ef410b39f3599a2f2d38abb9e9eb3967e272",
	"assets/ui/living_forge/frames/forge_panel.svg": "c56ba15c51fc53b213e3088e9fa4202e9dddfb89c80b3923f616013fc1fc667e",
	"assets/ui/living_forge/frames/class_silhouette.svg": "73d7f659a0e3d75b43d4932967e99cb225e09a06981fc4e738d61f911406e778",
}


func run() -> Array[String]:
	var failures: Array[String] = []
	_assert_assets_and_licenses(failures)
	_assert_provenance_inventory(failures)
	_assert_tokens(failures)
	_assert_theme_contracts(failures)
	_assert_focus_stylebox_contrast(failures)
	_assert_high_contrast_interaction_states(failures)
	_assert_packaged_font_chain(failures)
	_assert_scaled_variants(failures)
	return failures


func _assert_assets_and_licenses(failures: Array[String]) -> void:
	for path: String in REQUIRED_ASSETS:
		TestAssertions.truthy(FileAccess.file_exists(path), "required Living Forge asset exists: %s" % path, failures)
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(ICON_DIRECTORY)):
		return
	var actual_icons: Array[String] = []
	for file_name: String in DirAccess.get_files_at(ICON_DIRECTORY):
		if file_name.ends_with(".svg"):
			actual_icons.append(file_name)
	actual_icons.sort()
	TestAssertions.equal(actual_icons, REQUIRED_ICON_FILES, "only the reviewed Tabler SVG subset is packaged", failures)


func _assert_provenance_inventory(failures: Array[String]) -> void:
	var document := FileAccess.get_file_as_string(PROVENANCE_PATH)
	TestAssertions.truthy(document.contains(PROVENANCE_SCHEMA_MARKER), "provenance exposes the stable Living Forge inventory schema marker", failures)
	var upstream_rows := _markdown_table_rows(document, "## Pinned upstreams")
	var upstream := {}
	for row: Array[String] in upstream_rows:
		if row.size() >= 4:
			upstream[row[0]] = [row[1], row[3]]
	TestAssertions.equal(upstream.size(), EXPECTED_UPSTREAM_MARKERS.size(), "provenance retains every reviewed upstream family", failures)
	for family: String in EXPECTED_UPSTREAM_MARKERS:
		TestAssertions.truthy(upstream.has(family), "provenance retains upstream family %s" % family, failures)
		if not upstream.has(family):
			continue
		var expected := EXPECTED_UPSTREAM_MARKERS[family] as Array
		var actual := upstream[family] as Array
		TestAssertions.equal(actual[0], expected[0], "%s retains reviewed version" % family, failures)
		TestAssertions.truthy(String(actual[1]).contains(expected[1]), "%s retains reviewed licence marker" % family, failures)
	var inventory := {}
	for row: Array[String] in _markdown_table_rows(document, "## Imported file inventory"):
		if row.size() >= 4:
			inventory[row[2]] = row[3]
	for row: Array[String] in _markdown_table_rows(document, "## Party Forge-owned assets"):
		if row.size() >= 3:
			inventory[row[0]] = row[2]
	TestAssertions.equal(inventory.size(), EXPECTED_INVENTORY_SHA256.size(), "provenance inventories exactly the reviewed Living Forge files", failures)
	for path: String in EXPECTED_INVENTORY_SHA256:
		var expected_hash := EXPECTED_INVENTORY_SHA256[path] as String
		TestAssertions.truthy(inventory.has(path), "provenance inventories %s" % path, failures)
		if inventory.has(path):
			TestAssertions.equal(inventory[path], expected_hash, "%s retains its reviewed provenance hash" % path, failures)
		var resource_path := "res://%s" % path
		TestAssertions.truthy(FileAccess.file_exists(resource_path), "inventoried file exists: %s" % resource_path, failures)
		if FileAccess.file_exists(resource_path):
			TestAssertions.equal(FileAccess.get_sha256(resource_path), expected_hash, "%s bytes match the reviewed SHA-256" % path, failures)


func _markdown_table_rows(document: String, heading: String) -> Array[Array]:
	var rows: Array[Array] = []
	var heading_index := document.find(heading)
	if heading_index < 0:
		return rows
	var section := document.substr(heading_index + heading.length())
	for line: String in section.split("\n"):
		if line.begins_with("## "):
			break
		if not line.begins_with("|"):
			continue
		var cells: Array[String] = []
		for cell: String in line.trim_prefix("|").trim_suffix("|").split("|"):
			cells.append(cell.strip_edges().trim_prefix("`").trim_suffix("`"))
		if cells.is_empty() or cells[0].begins_with("---") or cells[0] in ["Asset family", "Family", "Local path"]:
			continue
		rows.append(cells)
	return rows


func _assert_tokens(failures: Array[String]) -> void:
	if not ResourceLoader.exists(TOKENS_PATH):
		TestAssertions.truthy(false, "Living Forge semantic token script exists", failures)
		return
	var tokens := load(TOKENS_PATH) as Script
	for high_contrast: bool in [false, true]:
		for role: StringName in REQUIRED_COLORS:
			var value: Variant = tokens.call(&"color", role, high_contrast)
			TestAssertions.truthy(value is Color, "%s color role resolves in high_contrast=%s" % [role, high_contrast], failures)
	_assert_contrast(tokens, false, failures)
	_assert_contrast(tokens, true, failures)
	TestAssertions.equal(tokens.call(&"spacing", &"grid"), 8, "spacing uses the approved eight-pixel base grid", failures)
	var minimum_action: Variant = tokens.call(&"control_size", &"action_minimum")
	TestAssertions.equal(minimum_action, Vector2(48.0, 48.0), "actions retain the 48 by 48 minimum target", failures)
	TestAssertions.equal(tokens.call(&"motion_ms", &"focus", false), 120, "focus motion uses 120 ms", failures)
	TestAssertions.equal(tokens.call(&"motion_ms", &"selection", false), 180, "selection motion uses 180 ms", failures)
	TestAssertions.equal(tokens.call(&"motion_ms", &"modal", false), 180, "modal motion uses 180 ms", failures)
	for role: StringName in [&"focus", &"selection", &"modal"]:
		TestAssertions.equal(tokens.call(&"motion_ms", role, true), 0, "reduced motion makes %s immediate" % role, failures)


func _assert_contrast(tokens: Script, high_contrast: bool, failures: Array[String]) -> void:
	var forged := tokens.call(&"color", &"surface_forged", high_contrast) as Color
	var inset := tokens.call(&"color", &"surface_inset", high_contrast) as Color
	for role: StringName in [&"text_primary", &"text_muted"]:
		var foreground := tokens.call(&"color", role, high_contrast) as Color
		TestAssertions.truthy(_contrast_ratio(foreground, forged) >= 4.5, "%s normal-text contrast is at least 4.5:1 in high_contrast=%s" % [role, high_contrast], failures)
	for role: StringName in [&"ember_primary", &"focus_outline", &"valid", &"warning", &"error", &"disabled"]:
		var boundary := tokens.call(&"color", role, high_contrast) as Color
		var ratio := minf(_contrast_ratio(boundary, forged), _contrast_ratio(boundary, inset))
		TestAssertions.truthy(ratio >= 3.0, "%s focus/state boundary contrast is at least 3:1 in high_contrast=%s" % [role, high_contrast], failures)


func _assert_theme_contracts(failures: Array[String]) -> void:
	for path: String in [NORMAL_THEME_PATH, HIGH_CONTRAST_THEME_PATH]:
		if not ResourceLoader.exists(path):
			TestAssertions.truthy(false, "Living Forge theme resource exists: %s" % path, failures)
			continue
		var theme := load(path) as Theme
		TestAssertions.truthy(theme != null, "Living Forge theme loads: %s" % path, failures)
		if theme == null:
			continue
		for role: StringName in REQUIRED_COLORS:
			TestAssertions.truthy(theme.has_color(role, &"LivingForgeSemantic"), "%s exposes semantic color %s" % [path, role], failures)
		for variation: StringName in REQUIRED_VARIATIONS:
			TestAssertions.truthy(not theme.get_type_variation_base(variation).is_empty(), "%s exposes variation %s" % [path, variation], failures)


func _assert_focus_stylebox_contrast(failures: Array[String]) -> void:
	var state_names := {
		&"LivingForgePrimaryButton": [&"normal", &"hover", &"pressed"],
		&"LivingForgeSecondaryButton": [&"normal", &"hover", &"pressed"],
		&"LivingForgeDestructiveButton": [&"normal", &"hover", &"pressed"],
		&"LivingForgeUnavailableButton": [&"normal", &"disabled"],
	}
	for path: String in [NORMAL_THEME_PATH, HIGH_CONTRAST_THEME_PATH]:
		var theme := load(path) as Theme
		if theme == null:
			continue
		var forged := theme.get_color(&"surface_forged", &"LivingForgeSemantic")
		var inset := theme.get_color(&"surface_inset", &"LivingForgeSemantic")
		var semantic_focus := theme.get_color(&"focus_outline", &"LivingForgeSemantic")
		for variation: StringName in state_names:
			var focus := theme.get_stylebox(&"focus", variation) as StyleBoxFlat
			TestAssertions.truthy(focus != null, "%s %s exposes an inspectable focus StyleBoxFlat" % [path, variation], failures)
			if focus == null:
				continue
			if variation == &"LivingForgePrimaryButton":
				TestAssertions.equal(focus.shadow_color, semantic_focus, "%s Primary uses the semantic bright outer focus outline" % path, failures)
				TestAssertions.truthy(focus.shadow_color.a >= 1.0, "%s Primary outer focus outline is opaque" % path, failures)
				TestAssertions.truthy(focus.shadow_size >= 2, "%s Primary outer focus outline has visible expanded thickness" % path, failures)
				TestAssertions.equal(focus.shadow_offset, Vector2.ZERO, "%s Primary outer focus outline is centered on the control" % path, failures)
				TestAssertions.truthy(_contrast_ratio(focus.border_color, focus.shadow_color) >= 3.0, "%s Primary inner and outer focus outlines remain visually distinct" % path, failures)
				for surrounding: Color in [forged, inset]:
					var outer_ratio := _contrast_ratio(focus.shadow_color, surrounding)
					TestAssertions.truthy(outer_ratio >= 3.0, "%s Primary outer focus outline contrasts with surrounding forged/inset surface at >=3:1 (actual %.3f)" % [path, outer_ratio], failures)
			for state: StringName in state_names[variation]:
				var surface := theme.get_stylebox(state, variation) as StyleBoxFlat
				TestAssertions.truthy(surface != null, "%s %s exposes %s StyleBoxFlat" % [path, variation, state], failures)
				if surface == null:
					continue
				var ratio := _contrast_ratio(focus.border_color, surface.bg_color)
				TestAssertions.truthy(ratio >= 3.0, "%s %s focus boundary contrasts with %s surface at >=3:1 (actual %.3f)" % [path, variation, state, ratio], failures)


func _assert_high_contrast_interaction_states(failures: Array[String]) -> void:
	var theme := load(HIGH_CONTRAST_THEME_PATH) as Theme
	if theme == null:
		return
	var font_color_items := {
		&"normal": &"font_color",
		&"hover": &"font_hover_color",
		&"pressed": &"font_pressed_color",
	}
	for variation: StringName in [&"LivingForgePrimaryButton", &"LivingForgeSecondaryButton"]:
		var border_widths := {}
		for state: StringName in font_color_items:
			var style := theme.get_stylebox(state, variation) as StyleBoxFlat
			if style == null:
				continue
			border_widths[state] = _style_border_widths(style)
			var font_color := theme.get_color(font_color_items[state] as StringName, variation)
			var ratio := _contrast_ratio(font_color, style.bg_color)
			TestAssertions.truthy(ratio >= 4.5, "high-contrast %s %s text contrasts at >=4.5:1 (actual %.3f)" % [variation, state, ratio], failures)
		if border_widths.size() == 3:
			var normal := border_widths[&"normal"] as Array
			var hover := border_widths[&"hover"] as Array
			var pressed := border_widths[&"pressed"] as Array
			TestAssertions.truthy(hover[3] >= normal[3] + 2, "high-contrast %s hover adds a materially heavier lower edge" % variation, failures)
			TestAssertions.truthy(hover[3] > hover[1], "high-contrast %s hover border geometry communicates lift without color" % variation, failures)
			TestAssertions.truthy(pressed[0] >= normal[0] + 2, "high-contrast %s pressed adds a materially heavier left inset edge" % variation, failures)
			TestAssertions.truthy(pressed[1] >= normal[1] + 2, "high-contrast %s pressed adds a materially heavier top inset edge" % variation, failures)
			TestAssertions.truthy(pressed[0] > pressed[2] and pressed[1] > pressed[3], "high-contrast %s pressed border geometry communicates inset depth without color" % variation, failures)


func _style_border_widths(style: StyleBoxFlat) -> Array:
	return [
		style.border_width_left, style.border_width_top, style.border_width_right, style.border_width_bottom,
	]


func _assert_packaged_font_chain(failures: Array[String]) -> void:
	var font_paths: Array[String] = [
		REQUIRED_ASSETS[0], REQUIRED_ASSETS[2], REQUIRED_ASSETS[4], REQUIRED_ASSETS[6],
	]
	var fonts: Array[Font] = []
	for path: String in font_paths:
		if not ResourceLoader.exists(path):
			return
		var font := load(path) as Font
		TestAssertions.truthy(font != null, "packaged font loads: %s" % path, failures)
		if font == null:
			return
		fonts.append(font)
	for sample: String in [LATIN_SAMPLE, EXTENDED_SAMPLE, SYMBOL_SAMPLE]:
		for index: int in sample.length():
			var codepoint := sample.unicode_at(index)
			TestAssertions.truthy(fonts.any(func(font: Font) -> bool: return font.has_char(codepoint)), "packaged fallback chain covers U+%04X" % codepoint, failures)
	var normal_theme := load(NORMAL_THEME_PATH) as Theme
	if normal_theme == null:
		return
	var display_font := normal_theme.get_font(&"font", &"LivingForgeDisplayLabel")
	TestAssertions.truthy(display_font != null, "display variation resolves a packaged font", failures)
	if display_font != null:
		var chain: Array[Font] = [display_font]
		chain.append_array(display_font.get_fallbacks())
		TestAssertions.equal(chain.size(), 4, "display font exposes the four-font deterministic fallback chain", failures)
		for index: int in mini(chain.size(), fonts.size()):
			TestAssertions.equal(_packaged_font_path(chain[index]), fonts[index].resource_path, "fallback position %d uses the reviewed packaged font" % index, failures)
	for theme_path: String in [NORMAL_THEME_PATH, HIGH_CONTRAST_THEME_PATH]:
		var theme := load(theme_path) as Theme
		if theme != null:
			_assert_typography_instances(theme, font_paths[0], font_paths[1], failures)


func _assert_scaled_variants(failures: Array[String]) -> void:
	if not ResourceLoader.exists(CATALOG_PATH):
		TestAssertions.truthy(false, "Living Forge theme catalog exists", failures)
		return
	var catalog := load(CATALOG_PATH) as Script
	var base := load(NORMAL_THEME_PATH) as Theme
	if base == null:
		return
	var base_action_size := base.get_constant(&"action_minimum", &"LivingForgeMetrics")
	var base_font_size := base.default_font_size
	var standard := catalog.call(&"resolve", false, 100, 100) as Theme
	var standard_again := catalog.call(&"resolve", false, 100, 100) as Theme
	var geometry_scaled := catalog.call(&"resolve", false, 125, 100) as Theme
	var text_scaled := catalog.call(&"resolve", false, 100, 150) as Theme
	var high_contrast := catalog.call(&"resolve", true, 110, 125) as Theme
	for variant: Theme in [standard, geometry_scaled, text_scaled, high_contrast]:
		TestAssertions.truthy(variant != null, "catalog resolves an owned theme variant", failures)
		if variant == null:
			continue
		for role: StringName in REQUIRED_COLORS:
			TestAssertions.truthy(variant.has_color(role, &"LivingForgeSemantic"), "scaled variant retains semantic color %s" % role, failures)
		for variation: StringName in REQUIRED_VARIATIONS:
			TestAssertions.truthy(not variant.get_type_variation_base(variation).is_empty(), "scaled variant retains variation %s" % variation, failures)
	TestAssertions.equal(standard, standard_again, "identical catalog inputs return the cached owned theme", failures)
	if standard != null and geometry_scaled != null and text_scaled != null:
		TestAssertions.truthy(standard != base, "catalog never returns or mutates the canonical base theme", failures)
		TestAssertions.equal(geometry_scaled.default_font_size, standard.default_font_size, "UI scale does not change typography", failures)
		TestAssertions.truthy(geometry_scaled.get_constant(&"action_minimum", &"LivingForgeMetrics") > standard.get_constant(&"action_minimum", &"LivingForgeMetrics"), "UI scale changes geometry", failures)
		TestAssertions.equal(text_scaled.get_constant(&"action_minimum", &"LivingForgeMetrics"), standard.get_constant(&"action_minimum", &"LivingForgeMetrics"), "text scale does not change geometry", failures)
		TestAssertions.truthy(text_scaled.default_font_size > standard.default_font_size, "text scale changes typography", failures)
	TestAssertions.equal(base.get_constant(&"action_minimum", &"LivingForgeMetrics"), base_action_size, "catalog preserves canonical geometry", failures)
	TestAssertions.equal(base.default_font_size, base_font_size, "catalog preserves canonical typography", failures)
	_assert_supported_ui_geometry_scaling(catalog, base, failures)


func _assert_supported_ui_geometry_scaling(catalog: Script, base: Theme, failures: Array[String]) -> void:
	var base_constants := _geometry_constant_snapshot(base)
	var base_styles := _style_geometry_snapshot(base)
	var base_font_size := base.default_font_size
	for ui_percent: int in [80, 90, 100, 110, 125, 150]:
		var variant := catalog.call(&"resolve", false, ui_percent, 100) as Theme
		var cached := catalog.call(&"resolve", false, ui_percent, 100) as Theme
		TestAssertions.truthy(variant != null, "catalog resolves supported UI scale %d" % ui_percent, failures)
		if variant == null:
			continue
		TestAssertions.equal(variant, cached, "supported UI scale %d is cached" % ui_percent, failures)
		TestAssertions.truthy(variant.get_constant(&"action_minimum", &"LivingForgeMetrics") >= 48, "supported UI scale %d retains a 48px minimum action target" % ui_percent, failures)
		TestAssertions.equal(variant.default_font_size, base_font_size, "supported UI scale %d does not change typography" % ui_percent, failures)
		_assert_scaled_constants(base_constants, variant, ui_percent, failures)
		_assert_scaled_style_geometry(base_styles, variant, ui_percent, failures)
	var text_only := catalog.call(&"resolve", false, 100, 150) as Theme
	if text_only != null:
		TestAssertions.equal(_geometry_constant_snapshot(text_only), base_constants, "text-only scaling preserves every Task-3 geometry constant", failures)
		TestAssertions.equal(_style_geometry_snapshot(text_only), base_styles, "text-only scaling preserves every Task-3 StyleBox geometry field", failures)
	TestAssertions.equal(_geometry_constant_snapshot(base), base_constants, "all supported resolves preserve canonical Theme constants", failures)
	TestAssertions.equal(_style_geometry_snapshot(base), base_styles, "all supported resolves preserve canonical StyleBox geometry", failures)
	TestAssertions.equal(base.default_font_size, base_font_size, "all supported resolves preserve canonical font size", failures)


func _geometry_constant_snapshot(theme: Theme) -> Dictionary:
	var result := {}
	for role: StringName in [&"grid", &"compact_gap", &"standard_gap", &"panel_padding", &"section_gap", &"action_minimum", &"status_chip_height"]:
		result[role] = theme.get_constant(role, &"LivingForgeMetrics")
	return result


func _assert_scaled_constants(base: Dictionary, variant: Theme, ui_percent: int, failures: Array[String]) -> void:
	for role: StringName in base:
		var expected := maxi(roundi(float(base[role]) * float(ui_percent) / 100.0), 1)
		if role == &"action_minimum":
			expected = maxi(expected, 48)
		TestAssertions.equal(variant.get_constant(role, &"LivingForgeMetrics"), expected, "UI scale %d scales %s consistently" % [ui_percent, role], failures)


func _style_geometry_snapshot(theme: Theme) -> Dictionary:
	var result := {}
	for slot: Array in _owned_style_slots():
		var variation := slot[0] as StringName
		var state := slot[1] as StringName
		var style := theme.get_stylebox(state, variation) as StyleBoxFlat
		if style == null:
			continue
		var geometry := {}
		for property: StringName in _style_geometry_properties():
			geometry[property] = style.get(property)
		result["%s/%s" % [variation, state]] = geometry
	return result


func _assert_scaled_style_geometry(base: Dictionary, variant: Theme, ui_percent: int, failures: Array[String]) -> void:
	var actual := _style_geometry_snapshot(variant)
	TestAssertions.equal(actual.size(), base.size(), "UI scale %d retains every owned StyleBox slot" % ui_percent, failures)
	for slot_key: String in base:
		if not actual.has(slot_key):
			continue
		var base_geometry := base[slot_key] as Dictionary
		var actual_geometry := actual[slot_key] as Dictionary
		for property: StringName in base_geometry:
			var base_value := float(base_geometry[property])
			var expected := 0 if is_zero_approx(base_value) else maxi(roundi(base_value * float(ui_percent) / 100.0), 1)
			TestAssertions.equal(int(actual_geometry[property]), expected, "UI scale %d scales %s %s consistently" % [ui_percent, slot_key, property], failures)


func _owned_style_slots() -> Array[Array]:
	return [
		[&"LivingForgePanel", &"panel"],
		[&"LivingForgeInsetPanel", &"panel"],
		[&"LivingForgePrimaryButton", &"normal"],
		[&"LivingForgePrimaryButton", &"hover"],
		[&"LivingForgePrimaryButton", &"pressed"],
		[&"LivingForgePrimaryButton", &"focus"],
		[&"LivingForgeSecondaryButton", &"normal"],
		[&"LivingForgeSecondaryButton", &"hover"],
		[&"LivingForgeSecondaryButton", &"pressed"],
		[&"LivingForgeSecondaryButton", &"focus"],
		[&"LivingForgeUnavailableButton", &"normal"],
		[&"LivingForgeUnavailableButton", &"disabled"],
		[&"LivingForgeDestructiveButton", &"normal"],
		[&"LivingForgeDestructiveButton", &"hover"],
		[&"LivingForgeDestructiveButton", &"pressed"],
		[&"LivingForgeDestructiveButton", &"focus"],
		[&"LivingForgeStatusChip", &"normal"],
	]


func _style_geometry_properties() -> Array[StringName]:
	return [
		&"content_margin_left", &"content_margin_top", &"content_margin_right", &"content_margin_bottom",
		&"border_width_left", &"border_width_top", &"border_width_right", &"border_width_bottom",
		&"corner_radius_top_left", &"corner_radius_top_right", &"corner_radius_bottom_right", &"corner_radius_bottom_left",
		&"shadow_size",
	]


func _contrast_ratio(first: Color, second: Color) -> float:
	var first_luminance := _relative_luminance(first)
	var second_luminance := _relative_luminance(second)
	return (maxf(first_luminance, second_luminance) + 0.05) / (minf(first_luminance, second_luminance) + 0.05)


func _relative_luminance(value: Color) -> float:
	return 0.2126 * _linear_channel(value.r) + 0.7152 * _linear_channel(value.g) + 0.0722 * _linear_channel(value.b)


func _linear_channel(value: float) -> float:
	return value / 12.92 if value <= 0.04045 else pow((value + 0.055) / 1.055, 2.4)


func _packaged_font_path(font: Font) -> String:
	if font is FontVariation:
		var base_font := (font as FontVariation).base_font
		return base_font.resource_path if base_font != null else ""
	return font.resource_path


func _assert_typography_instances(theme: Theme, cinzel_path: String, source_path: String, failures: Array[String]) -> void:
	var display := theme.get_font(&"font", &"LivingForgeDisplayLabel") as FontVariation
	TestAssertions.truthy(display != null, "display role uses a font variation", failures)
	if display != null:
		TestAssertions.equal(_packaged_font_path(display), cinzel_path, "display role uses packaged Cinzel", failures)
		TestAssertions.equal(float(display.variation_opentype.get(&"wght", 0.0)), 600.0, "display role instantiates Cinzel SemiBold", failures)
	var weighted_roles := {
		&"Label": 400.0,
		&"LivingForgeUnavailableButton": 500.0,
		&"LivingForgeSecondaryButton": 600.0,
		&"LivingForgePrimaryButton": 700.0,
	}
	for role: StringName in weighted_roles:
		var body := theme.get_font(&"font", role) as FontVariation
		TestAssertions.truthy(body != null, "%s uses a body font variation" % role, failures)
		if body == null:
			continue
		TestAssertions.equal(_packaged_font_path(body), source_path, "%s uses packaged Source Sans 3" % role, failures)
		TestAssertions.equal(float(body.variation_opentype.get(&"wght", 0.0)), weighted_roles[role], "%s uses the required body weight" % role, failures)
		TestAssertions.equal(int(body.opentype_features.get(&"tnum", 0)), 1, "%s enables tabular numerals" % role, failures)
