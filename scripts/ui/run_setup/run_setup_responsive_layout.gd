class_name RunSetupResponsiveLayout
extends RefCounted

enum Mode { DESKTOP, COMPACT }

const DESKTOP_WIDTH := 1600.0
const DESKTOP_HEIGHT := 900.0
const MAX_CONTENT_WIDTH := 1920.0

static func mode_for_size(size: Vector2) -> Mode:
	return Mode.DESKTOP if size.x >= DESKTOP_WIDTH and size.y >= DESKTOP_HEIGHT else Mode.COMPACT

static func content_width_for_size(size: Vector2) -> float:
	return minf(size.x, MAX_CONTENT_WIDTH)
