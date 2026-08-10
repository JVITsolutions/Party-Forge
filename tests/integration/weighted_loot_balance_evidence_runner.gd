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
	var failures: Array[String] = ItemGenerationBalanceReport.production_evidence_errors(report)
	if not failures.is_empty():
		_fail("; ".join(failures))
		return
	var json_text := ItemGenerationBalanceReport.to_json(report)
	var markdown_text := ItemGenerationBalanceReport.to_markdown(report)
	if json_text != _read_text(JSON_PATH):
		_fail("independent JSON build differs from committed evidence")
		return
	if markdown_text != _read_text(MARKDOWN_PATH):
		_fail("independent Markdown build differs from committed evidence")
		return
	var summary := report.get("summary", {}) as Dictionary
	print("WEIGHTED_LOOT_BALANCE_EVIDENCE: PASS rows=%d attempts=%d unique_ids=%d json_sha256=%s markdown_sha256=%s" % [
		int((report.get("configuration", {}) as Dictionary).get("scenario_count", 0)),
		int(summary.get("attempted", 0)),
		int(summary.get("unique_instance_id_count", 0)),
		json_text.sha256_text(),
		markdown_text.sha256_text(),
	])
	quit(0)

func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text

func _fail(message: String) -> void:
	push_error("WEIGHTED_LOOT_BALANCE_EVIDENCE_ERROR: %s" % message)
	quit(1)
