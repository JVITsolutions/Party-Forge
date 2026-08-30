class_name RunRecapProvider
extends RefCounted

func provider_id() -> StringName:
	return &""

func display_order() -> int:
	return 0

func project(_snapshot: RunTerminalSnapshot, _resolution: RunResolutionResult) -> RunRecapProviderResult:
	return RunRecapProviderResult.failure("provider does not implement project")
