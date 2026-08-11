class_name DeveloperLootLab
extends Control

signal sandbox_item_issued
signal close_requested
signal active_job_changed(active: bool)

var _session: LootLabSessionController
var _sandbox_state: DeveloperItemSandboxState
var _tooltip: ItemTooltipPanel
var _presentation_projection: Callable

func configure(
	session: LootLabSessionController,
	sandbox_state: DeveloperItemSandboxState,
	tooltip: ItemTooltipPanel,
	presentation_projection: Callable = Callable()
) -> void:
	_session = session
	_sandbox_state = sandbox_state
	_tooltip = tooltip
	_presentation_projection = presentation_projection

func focus_controls() -> Array[Control]:
	return [get_node("Layout/WorkbenchFocusAnchor") as Control]

func configured() -> bool:
	return _session != null and _sandbox_state != null and _tooltip != null
