class_name LedgerResponsiveLayout
extends RefCounted

enum Mode { DESKTOP, COMPACT }

const COMPACT_WIDTH := 1100.0
const COMPACT_HEIGHT := 650.0


static func mode_for_size(size: Vector2) -> Mode:
	return Mode.COMPACT if size.x < COMPACT_WIDTH or size.y < COMPACT_HEIGHT else Mode.DESKTOP
