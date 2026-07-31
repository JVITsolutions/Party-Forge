class_name CharacterLedgerPage
extends Control

var provider: LedgerDataProvider
var context: LedgerPlayerContext

func configure(data_provider: LedgerDataProvider, player_context: LedgerPlayerContext) -> void:
	provider = data_provider
	context = player_context

func activate() -> void:
	visible = true
	refresh()

func deactivate() -> void:
	visible = false

func refresh() -> void:
	pass

func initial_focus() -> Control:
	return null
