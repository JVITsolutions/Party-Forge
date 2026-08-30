class_name RunRecapEntryProjection
extends RefCounted

var _label := ""
var label: String:
	get: return _label
var _value := ""
var value: String:
	get: return _value
var _detail := ""
var detail: String:
	get: return _detail

static func create(label_value: String, value_value: String, detail_value: String = "") -> RunRecapEntryProjection:
	var result := RunRecapEntryProjection.new()
	result._label = label_value.strip_edges()
	result._value = value_value.strip_edges()
	result._detail = detail_value.strip_edges()
	return result

func valid() -> bool:
	return not _label.is_empty() and not _value.is_empty()

func copy() -> RunRecapEntryProjection:
	return create(_label, _value, _detail)
