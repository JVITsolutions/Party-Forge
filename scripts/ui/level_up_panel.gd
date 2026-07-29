class_name LevelUpPanel
extends PanelContainer

signal choice_selected(choice: UpgradeChoice)

var choices: Array[UpgradeChoice] = []
var selected_once := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _connect_buttons()

func show_choices(exact_choices: Array[UpgradeChoice], party: PartyManager) -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _connect_buttons()
    choices = exact_choices.duplicate()
    selected_once = false
    visible = true
    var buttons := get_node("Choices").get_children()
    for index: int in range(3):
        var button := buttons[index] as Button
        var choice: UpgradeChoice = choices[index] if index < choices.size() else null
        button.text = choice.label if choice != null else "Unavailable"
        button.disabled = choice == null or party == null or not choice.is_valid_for(party)

func _connect_buttons() -> void:
    var buttons := get_node("Choices").get_children()
    for index: int in range(mini(3, buttons.size())):
        var callback := _select.bind(index)
        if not (buttons[index] as Button).pressed.is_connected(callback):
            (buttons[index] as Button).pressed.connect(callback)

func _select(index: int) -> void:
    if selected_once or index < 0 or index >= choices.size():
        return
    var button := get_node("Choices").get_child(index) as Button
    if button.disabled:
        return
    selected_once = true
    visible = false
    choice_selected.emit(choices[index])
