class_name StatsLedgerPage
extends CharacterLedgerPage

func refresh() -> void:
	(get_node("Content/Title") as Label).text = "Character Stats"

func initial_focus() -> Control:
	return get_node("Content/Title") as Control
