class_name CombatHudResponsiveLayout
extends RefCounted

enum Mode { RICH, COMPACT }

const MAX_PARTY_COUNT := 24
const MIN_COMPACT_ROWS := 1
const MAX_COMPACT_ROWS := 4


class Metrics:
	extends RefCounted

	var mode: Mode
	var visible_member_count: int
	var column_count: int
	var page_count: int

	static func create(mode_value: Mode, visible_member_count_value: int, column_count_value: int, page_count_value: int) -> Metrics:
		var result := Metrics.new()
		result.mode = mode_value
		result.visible_member_count = visible_member_count_value
		result.column_count = column_count_value
		result.page_count = page_count_value
		return result

	func clamped_page(page: int) -> int:
		return clampi(page, 0, page_count - 1)


static func resolve(viewport_size: Vector2i, ui_scale_percent: int, text_scale_percent: int, party_count: int) -> Metrics:
	var normalized_ui_scale := _normalized_scale(ui_scale_percent)
	var normalized_text_scale := _normalized_scale(text_scale_percent)
	var normalized_party_count := clampi(party_count, 1, MAX_PARTY_COUNT)
	var rich := normalized_party_count <= 6
	var visible := normalized_party_count if rich else clampi(_compact_visible_count(viewport_size, normalized_ui_scale, normalized_text_scale), 1, normalized_party_count)
	var pages := maxi(1, ceili(float(normalized_party_count) / float(visible)))
	return Metrics.create(Mode.RICH if rich else Mode.COMPACT, visible, _columns(viewport_size, rich), pages)


static func _compact_visible_count(viewport_size: Vector2i, ui_scale_percent: int, text_scale_percent: int) -> int:
	var ui_scale := float(ui_scale_percent) / 100.0
	var text_scale := float(text_scale_percent) / 100.0
	var row_scale := maxf(ui_scale, text_scale)
	var available_height := maxf(1.0, float(viewport_size.y) - 132.0 * ui_scale)
	var row_height := 84.0 * row_scale
	var rows := clampi(floori(available_height / row_height), MIN_COMPACT_ROWS, MAX_COMPACT_ROWS)
	return rows * _columns(viewport_size, false)


static func _columns(viewport_size: Vector2i, rich: bool) -> int:
	var minimum_column_width := 440 if rich else 280
	var maximum_columns := 3 if rich else 2
	return clampi(viewport_size.x / minimum_column_width, 1, maximum_columns)


static func _normalized_scale(value: int) -> int:
	var nearest := PartyForgeSettings.UI_SCALE_OPTIONS[0]
	for option: int in PartyForgeSettings.UI_SCALE_OPTIONS:
		if abs(option - value) <= abs(nearest - value):
			nearest = option
	return nearest
