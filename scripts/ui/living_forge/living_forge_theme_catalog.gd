class_name LivingForgeThemeCatalog
extends RefCounted

const NORMAL_THEME_PATH := "res://data/ui/living_forge/living_forge_theme.tres"
const HIGH_CONTRAST_THEME_PATH := "res://data/ui/living_forge/living_forge_high_contrast_theme.tres"
const _GEOMETRY_CONSTANTS: Array[StringName] = [
	&"grid", &"compact_gap", &"standard_gap", &"panel_padding", &"section_gap",
	&"action_minimum", &"status_chip_height",
]
const _FONT_SIZE_TYPES: Array[StringName] = [
	&"Button", &"Label", &"LivingForgePrimaryButton", &"LivingForgeSecondaryButton",
	&"LivingForgeUnavailableButton", &"LivingForgeDestructiveButton",
	&"LivingForgeDisplayLabel", &"LivingForgeSectionLabel", &"LivingForgeCaptionLabel",
	&"LivingForgeStatusChip",
]
const _STYLEBOX_SLOTS: Array[Array] = [
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
const _STYLEBOX_MARGIN_PROPERTIES: Array[StringName] = [
	&"content_margin_left", &"content_margin_top", &"content_margin_right", &"content_margin_bottom",
]
const _STYLEBOX_INTEGER_PROPERTIES: Array[StringName] = [
	&"border_width_left", &"border_width_top", &"border_width_right", &"border_width_bottom",
	&"corner_radius_top_left", &"corner_radius_top_right", &"corner_radius_bottom_right", &"corner_radius_bottom_left",
	&"shadow_size",
]
static var _cache: Dictionary = {}


static func resolve(high_contrast: bool, ui_scale_percent: int, text_scale_percent: int) -> Theme:
	var ui_percent := maxi(ui_scale_percent, 1)
	var text_percent := maxi(text_scale_percent, 1)
	var cache_key := "%s:%d:%d" % [high_contrast, ui_percent, text_percent]
	if _cache.has(cache_key):
		return _cache[cache_key] as Theme
	var path := HIGH_CONTRAST_THEME_PATH if high_contrast else NORMAL_THEME_PATH
	var base := load(path) as Theme
	if base == null:
		return null
	var owned := base.duplicate(true) as Theme
	_apply_geometry_scale(owned, float(ui_percent) / 100.0)
	_apply_typography_scale(owned, float(text_percent) / 100.0)
	_cache[cache_key] = owned
	return owned


static func _apply_geometry_scale(theme: Theme, scale_factor: float) -> void:
	for role: StringName in _GEOMETRY_CONSTANTS:
		if theme.has_constant(role, &"LivingForgeMetrics"):
			var base_value := theme.get_constant(role, &"LivingForgeMetrics")
			var scaled_value := maxi(roundi(float(base_value) * scale_factor), 1)
			if role == &"action_minimum":
				scaled_value = maxi(scaled_value, 48)
			theme.set_constant(role, &"LivingForgeMetrics", scaled_value)
	_scale_owned_styleboxes(theme, scale_factor)


static func _scale_owned_styleboxes(theme: Theme, scale_factor: float) -> void:
	var scaled_ids := {}
	for slot: Array in _STYLEBOX_SLOTS:
		var style := theme.get_stylebox(slot[1] as StringName, slot[0] as StringName) as StyleBoxFlat
		if style == null or scaled_ids.has(style.get_instance_id()):
			continue
		scaled_ids[style.get_instance_id()] = true
		for property: StringName in _STYLEBOX_MARGIN_PROPERTIES:
			style.set(property, maxf(roundf(float(style.get(property)) * scale_factor), 1.0))
		for property: StringName in _STYLEBOX_INTEGER_PROPERTIES:
			var base_value := int(style.get(property))
			style.set(property, 0 if base_value == 0 else maxi(roundi(float(base_value) * scale_factor), 1))


static func _apply_typography_scale(theme: Theme, scale_factor: float) -> void:
	theme.default_font_size = maxi(roundi(float(theme.default_font_size) * scale_factor), 1)
	for type_name: StringName in _FONT_SIZE_TYPES:
		if theme.has_font_size(&"font_size", type_name):
			var base_size := theme.get_font_size(&"font_size", type_name)
			theme.set_font_size(&"font_size", type_name, maxi(roundi(float(base_size) * scale_factor), 1))
