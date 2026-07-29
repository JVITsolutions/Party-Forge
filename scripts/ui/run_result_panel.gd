class_name RunResultPanel
extends Control

signal restart_requested
signal quit_requested

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    var restart := get_node("Panel/Content/Restart") as Button
    var quit := get_node("Panel/Content/Quit") as Button
    if not restart.pressed.is_connected(_on_restart): restart.pressed.connect(_on_restart)
    if not quit.pressed.is_connected(_on_quit): quit.pressed.connect(_on_quit)

func show_result(victory: bool) -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    (get_node("Panel/Content/Title") as Label).text = "VICTORY" if victory else "DEFEAT"
    visible = true

func _on_restart() -> void:
    restart_requested.emit()

func _on_quit() -> void:
    quit_requested.emit()
