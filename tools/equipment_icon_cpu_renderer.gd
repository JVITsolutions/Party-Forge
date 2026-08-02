class_name EquipmentIconCpuRenderer
extends RefCounted

const SLOT_FAMILIES := {
	&"helmet": &"helmet", &"body_armour": &"body_armour", &"legs": &"legs",
	&"gloves": &"gloves", &"boots": &"boots", &"amulet": &"amulet",
	&"ring_left": &"ring", &"ring_right": &"ring", &"belt": &"belt",
}
const HANDHELD_FAMILIES := {
	&"bow": &"bow", &"staff": &"staff", &"wand": &"wand", &"sceptre": &"sceptre",
	&"tome": &"tome", &"grimoire": &"tome", &"focus": &"focus", &"quiver": &"quiver",
	&"shield": &"shield", &"dagger": &"dagger", &"warhammer": &"hammer",
}
const ID_OVERRIDES := {
	&"forge_vanguard_sword": &"sword",
	&"forge_vanguard_shield": &"shield",
	&"forge_vanguard_hammer": &"hammer",
}
const PALETTES := {
	&"fighter": [Color("d94f4f"), Color("303a47"), Color("4a3426"), Color("b68b3a")],
	&"paladin": [Color("e0b94f"), Color("d7dce2"), Color("553c28"), Color("fff0a1")],
	&"ranger": [Color("4f7a4d"), Color("59636a"), Color("5a3f28"), Color("83b86a")],
	&"marksman": [Color("59613b"), Color("4b5157"), Color("493b2a"), Color("a89d5b")],
	&"rogue": [Color("5a426e"), Color("657080"), Color("282127"), Color("a773c2")],
	&"mage": [Color("7c4d9e"), Color("61556c"), Color("4b334f"), Color("ff7043")],
	&"frost_mage": [Color("4f7f9e"), Color("6b8292"), Color("374e5c"), Color("8ee8ff")],
	&"cleric": [Color("d8c36a"), Color("69727a"), Color("66563d"), Color("fff08a")],
	&"warlock": [Color("513663"), Color("41404a"), Color("302431"), Color("8c45c9")],
}

func family_for(definition: EquipmentBaseDefinition, registered_slot: StringName) -> StringName:
	if definition == null or not EquipmentSlotCatalog.is_valid(registered_slot):
		return &""
	if registered_slot not in definition.compatible_slot_ids:
		return &""
	if SLOT_FAMILIES.has(registered_slot):
		return SLOT_FAMILIES[registered_slot] as StringName
	if registered_slot in [&"main_hand", &"off_hand"]:
		if ID_OVERRIDES.has(definition.id):
			return ID_OVERRIDES[definition.id] as StringName
		return HANDHELD_FAMILIES.get(definition.item_type_id, &"") as StringName
	return &""

func identity_variant(item_index: int) -> Vector3i:
	return Vector3i(item_index % 4, item_index / 4, item_index % 2)

func render(set_id: StringName, definition: EquipmentBaseDefinition, registered_slot: StringName, item_index: int) -> Image:
	if definition == null or not PALETTES.has(set_id):
		return null
	var family := family_for(definition, registered_slot)
	if family.is_empty():
		return null
	var image := Image.create_empty(256, 256, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var palette: Array = PALETTES[set_id]
	var primary := palette[0] as Color
	var metal := palette[1] as Color
	var leather := palette[2] as Color
	var accent := palette[3] as Color
	_draw_circle(image, Vector2i(132, 140), 70, Color(0.03, 0.04, 0.06, 0.55))
	_draw_family(image, family, primary, metal, leather, accent)
	_draw_identity_treatment(image, identity_variant(item_index), primary, metal, accent)
	return image

func _draw_family(image: Image, family: StringName, primary: Color, metal: Color, leather: Color, accent: Color) -> void:
	match family:
		&"helmet":
			image.fill_rect(Rect2i(77, 63, 102, 128), metal)
			image.fill_rect(Rect2i(92, 86, 72, 68), Color(0.03, 0.04, 0.06, 1))
			image.fill_rect(Rect2i(102, 57, 52, 18), accent)
		&"body_armour":
			image.fill_rect(Rect2i(72, 68, 112, 132), leather)
			image.fill_rect(Rect2i(55, 70, 45, 55), metal)
			image.fill_rect(Rect2i(156, 70, 45, 55), metal)
			image.fill_rect(Rect2i(83, 80, 90, 92), primary)
			image.fill_rect(Rect2i(91, 92, 74, 15), accent)
		&"legs":
			image.fill_rect(Rect2i(76, 52, 45, 148), leather)
			image.fill_rect(Rect2i(135, 52, 45, 148), leather)
			image.fill_rect(Rect2i(76, 95, 104, 18), primary)
		&"gloves":
			image.fill_rect(Rect2i(84, 82, 90, 114), leather)
			image.fill_rect(Rect2i(70, 72, 22, 77), primary)
			image.fill_rect(Rect2i(164, 72, 22, 77), primary)
		&"boots":
			image.fill_rect(Rect2i(67, 62, 50, 128), leather)
			image.fill_rect(Rect2i(139, 62, 50, 128), leather)
			image.fill_rect(Rect2i(49, 166, 68, 32), primary)
			image.fill_rect(Rect2i(139, 166, 68, 32), primary)
		&"amulet":
			_draw_circle_outline(image, Vector2i(128, 111), 62, metal, 10)
			_draw_circle(image, Vector2i(128, 172), 28, accent)
		&"ring":
			_draw_circle_outline(image, Vector2i(128, 128), 58, metal, 25)
			_draw_circle(image, Vector2i(128, 65), 18, accent)
		&"belt":
			image.fill_rect(Rect2i(43, 112, 170, 37), leather)
			image.fill_rect(Rect2i(106, 102, 48, 57), accent)
			image.fill_rect(Rect2i(118, 113, 24, 35), Color(0.03, 0.04, 0.06, 1))
		&"sword", &"weapon":
			_draw_line(image, Vector2i(78, 204), Vector2i(162, 62), leather, 12)
			_draw_line(image, Vector2i(151, 84), Vector2i(194, 45), metal, 18)
			image.fill_rect(Rect2i(62, 188, 76, 13), accent)
		&"dagger":
			_draw_line(image, Vector2i(88, 191), Vector2i(151, 87), leather, 14)
			_draw_line(image, Vector2i(144, 98), Vector2i(185, 56), metal, 20)
			image.fill_rect(Rect2i(68, 179, 60, 14), accent)
		&"hammer":
			_draw_line(image, Vector2i(78, 204), Vector2i(162, 62), leather, 12)
			image.fill_rect(Rect2i(112, 42, 92, 48), metal)
			image.fill_rect(Rect2i(146, 48, 18, 36), accent)
		&"bow":
			_draw_line(image, Vector2i(79, 190), Vector2i(79, 68), leather, 11)
			_draw_line(image, Vector2i(79, 68), Vector2i(145, 46), leather, 11)
			_draw_line(image, Vector2i(79, 190), Vector2i(145, 212), leather, 11)
			_draw_line(image, Vector2i(145, 46), Vector2i(145, 212), accent, 4)
			_draw_line(image, Vector2i(75, 129), Vector2i(199, 129), metal, 8)
		&"staff":
			_draw_line(image, Vector2i(91, 210), Vector2i(157, 56), leather, 12)
			_draw_circle(image, Vector2i(163, 51), 24, accent)
			_draw_circle_outline(image, Vector2i(163, 51), 31, metal, 7)
		&"wand":
			_draw_line(image, Vector2i(78, 201), Vector2i(164, 70), leather, 12)
			_draw_circle(image, Vector2i(174, 57), 22, accent)
		&"sceptre":
			_draw_line(image, Vector2i(85, 205), Vector2i(151, 70), metal, 14)
			image.fill_rect(Rect2i(124, 47, 80, 24), accent)
			_draw_circle(image, Vector2i(164, 42), 16, accent)
		&"focus":
			_draw_circle(image, Vector2i(128, 125), 53, accent)
			_draw_circle_outline(image, Vector2i(128, 125), 70, metal, 9)
		&"tome":
			image.fill_rect(Rect2i(67, 57, 122, 151), leather)
			image.fill_rect(Rect2i(78, 69, 100, 128), primary)
			image.fill_rect(Rect2i(119, 69, 13, 128), metal)
			image.fill_rect(Rect2i(95, 119, 67, 14), accent)
		&"shield":
			image.fill_rect(Rect2i(65, 49, 126, 148), metal)
			image.fill_rect(Rect2i(78, 61, 100, 123), primary)
			image.fill_rect(Rect2i(119, 66, 18, 110), accent)
			image.fill_rect(Rect2i(82, 111, 92, 18), accent)
		&"quiver":
			image.fill_rect(Rect2i(91, 78, 75, 126), leather)
			image.fill_rect(Rect2i(86, 72, 85, 20), primary)
			for x: int in [101, 128, 155]:
				_draw_line(image, Vector2i(x, 92), Vector2i(x, 42), metal, 5)

func _draw_identity_treatment(image: Image, variant: Vector3i, primary: Color, metal: Color, accent: Color) -> void:
	var center := Vector2i(96 + variant.x * 18, 150 + variant.y * 14)
	var color := accent if variant.z == 0 else primary.lightened(0.20)
	match variant.x:
		0: _draw_circle(image, center, 8, color)
		1:
			image.fill_rect(Rect2i(center - Vector2i(8, 8), Vector2i(16, 16)), color)
		2:
			_draw_line(image, center - Vector2i(9, 9), center + Vector2i(9, 9), color, 6)
			_draw_line(image, center + Vector2i(9, -9), center + Vector2i(-9, 9), metal, 4)
		3:
			_draw_circle_outline(image, center, 10, color, 5)
			_draw_circle(image, center, 3, metal)

func _draw_line(image: Image, from: Vector2i, to: Vector2i, color: Color, width: int) -> void:
	var steps := maxi(abs(to.x - from.x), abs(to.y - from.y))
	for index: int in steps + 1:
		var point := Vector2(from).lerp(Vector2(to), float(index) / maxf(1.0, steps))
		_draw_circle(image, Vector2i(point), maxi(1, width / 2), color)

func _draw_circle(image: Image, center: Vector2i, radius: int, color: Color) -> void:
	for y: int in range(-radius, radius + 1):
		for x: int in range(-radius, radius + 1):
			if x * x + y * y <= radius * radius:
				var point := center + Vector2i(x, y)
				if point.x >= 0 and point.y >= 0 and point.x < image.get_width() and point.y < image.get_height():
					image.set_pixelv(point, color)

func _draw_circle_outline(image: Image, center: Vector2i, radius: int, color: Color, width: int) -> void:
	var inner := maxi(0, radius - width)
	for y: int in range(-radius, radius + 1):
		for x: int in range(-radius, radius + 1):
			var distance := x * x + y * y
			if distance <= radius * radius and distance >= inner * inner:
				var point := center + Vector2i(x, y)
				if point.x >= 0 and point.y >= 0 and point.x < image.get_width() and point.y < image.get_height():
					image.set_pixelv(point, color)
