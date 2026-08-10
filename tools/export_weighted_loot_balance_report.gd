extends SceneTree

const EQUIPMENT_PATH := "res://data/equipment/core_equipment_catalog.tres"
const FOUNDATION_PATH := "res://data/items/core_item_foundation_catalog.tres"
const JSON_PATH := "res://docs/validation/evidence/2026-08-10-weighted-loot-production-balance.json"
const MARKDOWN_PATH := "res://docs/validation/evidence/2026-08-10-weighted-loot-production-balance.md"

func _initialize() -> void:
	var equipment := load(EQUIPMENT_PATH) as EquipmentCatalog
	var foundation := load(FOUNDATION_PATH) as ItemFoundationCatalog
	if equipment == null or foundation == null:
		_fail("production catalogs failed to load")
		return
	var requests := ItemGenerationBalanceReport.production_requests(foundation)
	var report := ItemGenerationBalanceReport.build(equipment, foundation, requests)
	if report.get("status", "") != "ok":
		_fail("report build failed: %s" % report.get("errors", []))
		return
	var json_text := ItemGenerationBalanceReport.to_json(report)
	var markdown_text := ItemGenerationBalanceReport.to_markdown(report)
	if json_text.is_empty() or markdown_text.is_empty():
		_fail("report rendering returned empty output")
		return
	if not _write_text(JSON_PATH, json_text) or not _write_text(MARKDOWN_PATH, markdown_text):
		return
	print("WEIGHTED_LOOT_BALANCE_REPORT: PASS attempts=%d json_sha256=%s markdown_sha256=%s" % [
		int((report.get("summary", {}) as Dictionary).get("attempted", 0)),
		json_text.sha256_text(),
		markdown_text.sha256_text(),
	])
	quit(0)

func _write_text(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("cannot open %s for writing: %s" % [path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(text)
	file.close()
	return true

func _fail(message: String) -> void:
	push_error("WEIGHTED_LOOT_BALANCE_REPORT_ERROR: %s" % message)
	quit(1)
