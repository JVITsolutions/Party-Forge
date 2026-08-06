class_name EquipmentUiMetrics
extends RefCounted


static func for_viewport(size: Vector2) -> Dictionary:
	var scale := clampf(minf(size.x / 1920.0, size.y / 1080.0), 0.82, 1.60)
	return {
		"scale": scale,
		"slot_size": Vector2(78.0, 78.0) * scale,
		"card_width": 340.0 * scale,
		"card_gap": 12.0 * scale,
		"edge_margin": 16.0 * scale,
		"maximum_card_height": minf(720.0 * scale, size.y - 32.0 * scale),
	}
