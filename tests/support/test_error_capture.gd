extends Logger

var _mutex := Mutex.new()
var _messages := PackedStringArray()


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
	var message := rationale if not rationale.is_empty() else code
	_mutex.lock()
	_messages.append("type=%d %s:%d function=%s reason=%s" % [error_type, file, line, function, message])
	_mutex.unlock()


func drain_after_detach() -> PackedStringArray:
	_mutex.lock()
	var result := _messages.duplicate()
	_messages.clear()
	_mutex.unlock()
	return result
