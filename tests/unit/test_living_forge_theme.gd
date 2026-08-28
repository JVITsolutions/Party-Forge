extends RefCounted

const TOKENS_PATH := "res://scripts/ui/living_forge/living_forge_tokens.gd"
const CATALOG_PATH := "res://scripts/ui/living_forge/living_forge_theme_catalog.gd"
const NORMAL_THEME_PATH := "res://data/ui/living_forge/living_forge_theme.tres"
const HIGH_CONTRAST_THEME_PATH := "res://data/ui/living_forge/living_forge_high_contrast_theme.tres"

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


func run() -> Array[String]:
	var failures: Array[String] = []
	_assert_assets_and_licenses(failures)
	_assert_tokens(failures)
	_assert_theme_contracts(failures)
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
