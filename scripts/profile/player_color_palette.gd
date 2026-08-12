class_name PlayerColorPalette
extends RefCounted

const DEFAULT_ID := &"red"
const ORDER: Array[StringName] = [&"red", &"blue", &"yellow", &"green", &"purple", &"orange", &"cyan", &"white"]
const COLORS := {
	&"red": Color("e45454"),
	&"blue": Color("4f8cff"),
	&"yellow": Color("f0cf4a"),
	&"green": Color("59bd72"),
	&"purple": Color("a66be8"),
	&"orange": Color("e58b45"),
	&"cyan": Color("52c7cf"),
	&"white": Color("e8edf2"),
}


static func is_valid(color_id: StringName) -> bool:
	return color_id in ORDER


static func color(color_id: StringName) -> Color:
	return COLORS.get(color_id, COLORS[DEFAULT_ID]) as Color


static func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for color_id: StringName in ORDER:
		result.append({
			"id": color_id,
			"label": String(color_id).capitalize(),
			"color": color(color_id),
		})
	return result
