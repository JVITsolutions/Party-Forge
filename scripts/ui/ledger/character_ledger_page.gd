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

func focus_controls() -> Array[Control]:
	var target := initial_focus()
	return [target] if target != null else []

func apply_compact(_compact: bool) -> void:
	pass

func pin_active_detail() -> bool:
	return false

func dismiss_pinned_detail() -> bool:
	return false
