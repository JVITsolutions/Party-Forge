class_name TestAssertions
extends RefCounted

static func equal(actual: Variant, expected: Variant, label: String, failures: Array[String]) -> void:
    if actual != expected:
        failures.append("%s: expected %s, got %s" % [label, expected, actual])

static func truthy(value: bool, label: String, failures: Array[String]) -> void:
    if not value:
        failures.append("%s: expected true" % label)

static func near(actual: float, expected: float, tolerance: float, label: String, failures: Array[String]) -> void:
    if absf(actual - expected) > tolerance:
        failures.append("%s: expected %.3f +/- %.3f, got %.3f" % [label, expected, tolerance, actual])
