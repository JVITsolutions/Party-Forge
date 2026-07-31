class_name InputBindingFormatter
extends RefCounted

const MISSING_BINDING := "Missing binding"


static func event_text(event: InputEvent) -> String:
	if event is InputEventMouseButton:
		return "Mouse %d" % (event as InputEventMouseButton).button_index
	if event is InputEventJoypadMotion:
		return "%s +/-" % event.as_text()
	return event.as_text()


static func events_for_device(events: Array[InputEvent], controller: bool) -> String:
	var labels: Array[String] = []
	for event: InputEvent in events:
		var is_controller := event is InputEventJoypadButton or event is InputEventJoypadMotion
		if is_controller != controller:
			continue
		if not (is_controller or event is InputEventKey or event is InputEventMouseButton):
			continue
		var label := event_text(event)
		if not label.is_empty() and not labels.has(label):
			labels.append(label)
	return MISSING_BINDING if labels.is_empty() else " / ".join(labels)
