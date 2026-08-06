class_name ItemRarityPalette
extends RefCounted

const COLORS := {
	&"common": Color(0.76, 0.78, 0.82),
	&"uncommon": Color(0.30, 0.82, 0.42),
	&"rare": Color(0.28, 0.56, 1.00),
	&"epic": Color(0.68, 0.36, 0.96),
	&"legendary": Color(1.00, 0.56, 0.18),
	&"mythic": Color(1.00, 0.25, 0.42),
	&"eternal": Color(1.00, 0.84, 0.28),
}
const INTENSITIES := {
	&"common": 0,
	&"uncommon": 1,
	&"rare": 2,
	&"epic": 3,
	&"legendary": 4,
	&"mythic": 5,
	&"eternal": 6,
}


static func color_for(rarity_id: StringName) -> Color:
	return COLORS.get(rarity_id, Color(0.62, 0.65, 0.70)) as Color


static func intensity_for(rarity_id: StringName) -> int:
	return int(INTENSITIES.get(rarity_id, 0))
