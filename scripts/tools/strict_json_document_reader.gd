class_name StrictJsonDocumentReader
extends RefCounted

const STRICT_JSON_TOKEN_SCANNER := preload("res://scripts/data/strict_json_token_scanner.gd")

class StrictJsonDocumentResult extends RefCounted:
	var bytes := PackedByteArray()
	var text := ""
	var document := {}
	var sha256 := ""
	var stage := ""
	var reason := ""

	func ok() -> bool:
		return stage.is_empty()

static func read(path: String, maximum_bytes: int) -> StrictJsonDocumentResult:
	if maximum_bytes < 0:
		return _failure("size", "byte limit is invalid")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure("open", "source is not a readable file")
	var length := file.get_length()
	if length > maximum_bytes:
		file.close()
		return _failure("size", "source exceeds byte limit")
	var bytes := file.get_buffer(length)
	var read_error := file.get_error()
	file.close()
	if read_error != OK or bytes.size() != length:
		return _failure("read", "source bytes could not be read")
	if bytes.size() >= 3 and bytes[0] == 0xef and bytes[1] == 0xbb and bytes[2] == 0xbf:
		return _failure("decode", "UTF-8 BOM is not allowed")
	var text := bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes:
		return _failure("decode", "source must be strict UTF-8")
	var scan_error := STRICT_JSON_TOKEN_SCANNER.new(text).scan()
	if not scan_error.is_empty():
		return _failure("duplicate-key" if scan_error == "duplicate key" else "scan", scan_error)
	var parser := JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary:
		return _failure("parse", "source must contain one JSON object")
	var result := StrictJsonDocumentResult.new()
	result.bytes = bytes
	result.text = text
	result.document = (parser.data as Dictionary).duplicate(true)
	result.sha256 = _sha256(bytes)
	return result

static func _failure(stage: String, reason: String) -> StrictJsonDocumentResult:
	var result := StrictJsonDocumentResult.new()
	result.stage = stage
	result.reason = reason
	return result

static func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()
