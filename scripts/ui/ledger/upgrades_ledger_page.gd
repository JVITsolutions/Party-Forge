class_name UpgradesLedgerPage
extends CharacterLedgerPage

func refresh() -> void:
	(get_node("Content/Title") as Label).text = "Current Upgrades"

func initial_focus() -> Control:
	return get_node("Content/Title") as Control
