class_name StrictJsonDocumentReader
extends RefCounted

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
	var scan_error := _JsonTokenScanner.new(text).scan()
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

class _JsonTokenScanner extends RefCounted:
	var _text := ""
	var _index := 0

	func _init(text: String) -> void:
		_text = text

	func scan() -> String:
		_skip_whitespace()
		var error := _value()
		if not error.is_empty():
			return error
		_skip_whitespace()
		return "" if _index == _text.length() else "unexpected trailing token"

	func _value() -> String:
		_skip_whitespace()
		if _index >= _text.length(): return "unexpected end of source"
		var character := _text[_index]
		if character == "{": return _object()
		if character == "[": return _array()
		if character == "\"": return String(_string().get("error", ""))
		if character == "t": return _literal("true")
		if character == "f": return _literal("false")
		if character == "n": return _literal("null")
		return _number() if character == "-" or (character >= "0" and character <= "9") else "invalid JSON token"

	func _object() -> String:
		_index += 1
		_skip_whitespace()
		var keys := {}
		if _consume("}"): return ""
		while true:
			_skip_whitespace()
			if _index >= _text.length() or _text[_index] != "\"": return "object key is missing"
			var key_result := _string()
			var key_error := String(key_result.get("error", ""))
			if not key_error.is_empty(): return key_error
			var key := String(key_result["value"])
			if keys.has(key): return "duplicate key"
			keys[key] = true
			_skip_whitespace()
			if not _consume(":"): return "object key separator is missing"
			var value_error := _value()
			if not value_error.is_empty(): return value_error
			_skip_whitespace()
			if _consume("}"): return ""
			if not _consume(","): return "object separator is missing"
		return "object scan did not terminate"

	func _array() -> String:
		_index += 1
		_skip_whitespace()
		if _consume("]"): return ""
		while true:
			var value_error := _value()
			if not value_error.is_empty(): return value_error
			_skip_whitespace()
			if _consume("]"): return ""
			if not _consume(","): return "array separator is missing"
		return "array scan did not terminate"

	func _string() -> Dictionary:
		if not _consume("\""): return {"error": "string is missing"}
		var result := ""
		while _index < _text.length():
			var character := _text[_index]
			_index += 1
			if character == "\"": return {"value": result}
			if character == "\\":
				if _index >= _text.length(): return {"error": "unterminated escape"}
				var escaped := _text[_index]
				_index += 1
				match escaped:
					"\"", "\\", "/": result += escaped
					"b": result += "\b"
					"f": result += "\f"
					"n": result += "\n"
					"r": result += "\r"
					"t": result += "\t"
					"u":
						var unicode_result := _unicode_escape()
						if unicode_result.has("error"): return unicode_result
						result += String(unicode_result["value"])
					_: return {"error": "invalid string escape"}
			elif character.unicode_at(0) < 0x20:
				return {"error": "control character in string"}
			else:
				result += character
		return {"error": "unterminated string"}

	func _unicode_escape() -> Dictionary:
		var high_result := _hex4()
		if high_result.has("error"): return high_result
		var high := int(high_result["value"])
		if high >= 0xd800 and high <= 0xdbff:
			if not _consume("\\") or not _consume("u"): return {"error": "unpaired unicode surrogate"}
			var low_result := _hex4()
			if low_result.has("error"): return low_result
			var low := int(low_result["value"])
			if low < 0xdc00 or low > 0xdfff: return {"error": "unpaired unicode surrogate"}
			return {"value": String.chr(0x10000 + ((high - 0xd800) << 10) + low - 0xdc00)}
		if high >= 0xdc00 and high <= 0xdfff: return {"error": "unpaired unicode surrogate"}
		return {"value": String.chr(high)}

	func _hex4() -> Dictionary:
		if _index + 4 > _text.length(): return {"error": "incomplete unicode escape"}
		var value := 0
		for offset: int in 4:
			var nibble := _hex_value(_text[_index + offset])
			if nibble < 0: return {"error": "invalid unicode escape"}
			value = value * 16 + nibble
		_index += 4
		return {"value": value}

	func _hex_value(character: String) -> int:
		if character >= "0" and character <= "9": return character.unicode_at(0) - "0".unicode_at(0)
		if character >= "a" and character <= "f": return character.unicode_at(0) - "a".unicode_at(0) + 10
		if character >= "A" and character <= "F": return character.unicode_at(0) - "A".unicode_at(0) + 10
		return -1

	func _number() -> String:
		if _consume("-") and _index >= _text.length(): return "invalid number"
		if _consume("0"):
			pass
		elif _index < _text.length() and _text[_index] >= "1" and _text[_index] <= "9":
			_index += 1
			while _index < _text.length() and _text[_index] >= "0" and _text[_index] <= "9": _index += 1
		else: return "invalid number"
		if _consume("."):
			if _index >= _text.length() or _text[_index] < "0" or _text[_index] > "9": return "invalid number fraction"
			while _index < _text.length() and _text[_index] >= "0" and _text[_index] <= "9": _index += 1
		if _index < _text.length() and _text[_index] in ["e", "E"]:
			_index += 1
			if _index < _text.length() and _text[_index] in ["+", "-"]: _index += 1
			if _index >= _text.length() or _text[_index] < "0" or _text[_index] > "9": return "invalid number exponent"
			while _index < _text.length() and _text[_index] >= "0" and _text[_index] <= "9": _index += 1
		return ""

	func _literal(value: String) -> String:
		if _text.substr(_index, value.length()) != value: return "invalid literal"
		_index += value.length()
		return ""

	func _consume(character: String) -> bool:
		if _index >= _text.length() or _text[_index] != character: return false
		_index += 1
		return true

	func _skip_whitespace() -> void:
		while _index < _text.length() and _text[_index] in [" ", "\t", "\r", "\n"]:
			_index += 1
