class_name StatDefinition
extends Resource

enum ValueFormat { NUMBER, INTEGER, RATIO_PERCENT, MULTIPLIER, PER_SECOND }
enum Visibility { UNIVERSAL, CAPABILITY, NON_DEFAULT }
enum ComparisonDirection { HIGHER_IS_BETTER, LOWER_IS_BETTER, NEUTRAL }

@export var id: StringName
@export var display_name: String
@export var ui_group: StringName
@export var value_format := ValueFormat.NUMBER
@export_range(0, 3, 1) var precision := 1
@export var default_value := 0.0
@export var has_minimum := false
@export var minimum := 0.0
@export var has_maximum := false
@export var maximum := 0.0
@export var visibility := Visibility.NON_DEFAULT
@export var capability_tags: Array[StringName] = []
@export var keyword_id: StringName
@export var comparison_direction := ComparisonDirection.HIGHER_IS_BETTER

func finalize_value(value: float) -> float:
	var result := value
	if has_minimum:
		result = maxf(result, minimum)
	if has_maximum:
		result = minf(result, maximum)
	var decimal_places := precision + 2 if value_format == ValueFormat.RATIO_PERCENT else precision
	return snappedf(result, pow(10.0, -decimal_places))

func format_value(value: float) -> String:
	var final := finalize_value(value)
	match value_format:
		ValueFormat.INTEGER:
			return str(roundi(final))
		ValueFormat.RATIO_PERCENT:
			return ("%.*f%%" % [precision, final * 100.0])
		ValueFormat.MULTIPLIER:
			return ("%.*fx" % [precision, final])
		ValueFormat.PER_SECOND:
			return ("%.*f/s" % [precision, final])
		_:
			return ("%.*f" % [precision, final])

func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if id.is_empty(): errors.append("stat id is empty")
	if display_name.is_empty(): errors.append("stat %s display name is empty" % id)
	if ui_group.is_empty(): errors.append("stat %s UI group is empty" % id)
	if keyword_id.is_empty(): errors.append("stat %s keyword id is empty" % id)
	if has_minimum and has_maximum and minimum > maximum:
		errors.append("stat %s minimum exceeds maximum" % id)
	if visibility == Visibility.CAPABILITY and capability_tags.is_empty():
		errors.append("stat %s capability visibility has no tags" % id)
	return errors
