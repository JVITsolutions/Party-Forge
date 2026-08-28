class_name LivingForgeTokens
extends RefCounted

const _NORMAL_COLORS := {
	&"surface_forged": Color("111923"),
	&"surface_inset": Color("080d12"),
	&"ember_primary": Color("f0b94a"),
	&"focus_outline": Color("f8f2df"),
	&"text_primary": Color("f2ead8"),
	&"text_muted": Color("b9c2cc"),
	&"valid": Color("54d4c2"),
	&"warning": Color("ffc857"),
	&"error": Color("ff766b"),
	&"disabled": Color("8a96a5"),
}
const _HIGH_CONTRAST_COLORS := {
	&"surface_forged": Color("000000"),
	&"surface_inset": Color("101820"),
	&"ember_primary": Color("ffd75a"),
	&"focus_outline": Color("ffffff"),
	&"text_primary": Color("ffffff"),
	&"text_muted": Color("dbe7f2"),
	&"valid": Color("63f2dd"),
	&"warning": Color("ffe066"),
	&"error": Color("ff8a80"),
	&"disabled": Color("aebccc"),
}
const _SPACING := {
	&"grid": 8,
	&"compact": 8,
	&"standard": 16,
	&"spacious": 24,
	&"section": 32,
}
const _CONTROL_SIZES := {
	&"action_minimum": Vector2(48.0, 48.0),
	&"action_standard": Vector2(160.0, 48.0),
	&"status_chip": Vector2(80.0, 32.0),
}
const _MOTION_MS := {
	&"focus": 120,
	&"selection": 180,
	&"modal": 180,
}


static func color(role: StringName, high_contrast := false) -> Color:
	var palette := _HIGH_CONTRAST_COLORS if high_contrast else _NORMAL_COLORS
	return palette.get(role, Color.TRANSPARENT) as Color


static func spacing(role: StringName) -> int:
	return int(_SPACING.get(role, 0))


static func control_size(role: StringName) -> Vector2:
	return _CONTROL_SIZES.get(role, Vector2.ZERO) as Vector2


static func motion_ms(role: StringName, reduced_motion: bool) -> int:
	if reduced_motion:
		return 0
	return int(_MOTION_MS.get(role, 0))
