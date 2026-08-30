class_name CombatHudResponsiveLayout
extends RefCounted

enum Mode { RICH, COMPACT }

const MAX_PARTY_COUNT := 24
const MIN_COMPACT_ROWS := 1
const MAX_COMPACT_ROWS := 4
const RICH_CARD_BASE_SIZE := Vector2(424.0, 184.0)
const RICH_MAX_COLUMNS := 2
const RICH_HORIZONTAL_SEPARATION := 12.0
const RICH_VERTICAL_SEPARATION := 8.0
const PARTY_REGION_HORIZONTAL_INSET := 24.0
const PARTY_REGION_VERTICAL_INSET := 312.0


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
	var rich_card_size := _resolved_rich_card_size(normalized_ui_scale, normalized_text_scale)
	var rich_columns := _rich_columns(viewport_size, rich_card_size)
	var rich := normalized_party_count <= 6 and _rich_followers_fit(viewport_size, normalized_party_count - 1, rich_card_size, rich_columns)
	var visible := normalized_party_count if rich else clampi(_compact_visible_count(viewport_size, normalized_ui_scale, normalized_text_scale), 1, normalized_party_count)
	var pages := maxi(1, ceili(float(normalized_party_count) / float(visible)))
	return Metrics.create(Mode.RICH if rich else Mode.COMPACT, visible, rich_columns if rich else _compact_columns(viewport_size), pages)


static func _resolved_rich_card_size(ui_scale_percent: int, text_scale_percent: int) -> Vector2:
	var scale := maxf(float(ui_scale_percent), float(text_scale_percent)) / 100.0
	return RICH_CARD_BASE_SIZE * scale


static func _rich_columns(viewport_size: Vector2i, card_size: Vector2) -> int:
	var available_width := maxf(1.0, float(viewport_size.x) * 0.5 - PARTY_REGION_HORIZONTAL_INSET)
	return clampi(floori((available_width + RICH_HORIZONTAL_SEPARATION) / (card_size.x + RICH_HORIZONTAL_SEPARATION)), 1, RICH_MAX_COLUMNS)


static func _rich_followers_fit(viewport_size: Vector2i, follower_count: int, card_size: Vector2, columns: int) -> bool:
	if follower_count <= 0:
		return true
	var available_width := maxf(1.0, float(viewport_size.x) * 0.5 - PARTY_REGION_HORIZONTAL_INSET)
	var available_height := maxf(1.0, float(viewport_size.y) - PARTY_REGION_VERTICAL_INSET)
	var used_columns := mini(columns, follower_count)
	var rows := ceili(float(follower_count) / float(columns))
	var required_width := card_size.x * used_columns + RICH_HORIZONTAL_SEPARATION * maxi(0, used_columns - 1)
	var required_height := card_size.y * rows + RICH_VERTICAL_SEPARATION * maxi(0, rows - 1)
	return required_width <= available_width and required_height <= available_height


static func _compact_visible_count(viewport_size: Vector2i, ui_scale_percent: int, text_scale_percent: int) -> int:
	var ui_scale := float(ui_scale_percent) / 100.0
	var text_scale := float(text_scale_percent) / 100.0
	var row_scale := maxf(ui_scale, text_scale)
	var available_height := maxf(1.0, float(viewport_size.y) - 132.0 * ui_scale)
	var row_height := 84.0 * row_scale
	var rows := clampi(floori(available_height / row_height), MIN_COMPACT_ROWS, MAX_COMPACT_ROWS)
	if viewport_size.y <= 720 and text_scale_percent >= 150:
		rows = mini(rows, 3)
	return rows * _compact_columns(viewport_size)


static func _compact_columns(viewport_size: Vector2i) -> int:
	return clampi(viewport_size.x / 280, 1, 2)


static func _normalized_scale(value: int) -> int:
	var nearest := PartyForgeSettings.UI_SCALE_OPTIONS[0]
	for option: int in PartyForgeSettings.UI_SCALE_OPTIONS:
		if abs(option - value) <= abs(nearest - value):
			nearest = option
	return nearest
