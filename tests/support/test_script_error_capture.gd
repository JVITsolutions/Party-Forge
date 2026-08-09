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


## Call only after OS.remove_logger(self). Detaching closes the producer boundary;
## this mutex-protected drain serializes with any callback already writing and
## leaves the local Logger reference alive until the runner has copied all data.
func drain_after_detach() -> PackedStringArray:
	_mutex.lock()
	var result := _errors.duplicate()
	_errors.clear()
	_mutex.unlock()
	return result
