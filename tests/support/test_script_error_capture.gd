extends Logger

var _mutex := Mutex.new()
var _errors := PackedStringArray()


func _log_error(
	function: String,
	file: String,
	line: int,
	code: String,
	rationale: String,
	_editor_notify: bool,
	error_type: int,
	_script_backtraces: Array[ScriptBacktrace],
) -> void:
	if error_type != Logger.ERROR_TYPE_SCRIPT:
		return
	var message := rationale if not rationale.is_empty() else code
	_mutex.lock()
	_errors.append("%s:%d function=%s reason=%s" % [file, line, function, message])
	_mutex.unlock()


func errors() -> PackedStringArray:
	_mutex.lock()
	var result := _errors.duplicate()
	_mutex.unlock()
	return result
