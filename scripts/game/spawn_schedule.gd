class_name SpawnSchedule
extends RefCounted

class SpawnBand extends RefCounted:
    var interval: float
    var swarmer_weight: int
    var spitter_weight: int

    func _init(seconds: float, swarmer: int, spitter: int) -> void:
        interval = seconds
        swarmer_weight = swarmer
        spitter_weight = spitter

static func sample(elapsed_seconds: float) -> SpawnBand:
    if elapsed_seconds < 0.0 or elapsed_seconds >= 300.0:
        return null
    if elapsed_seconds < 60.0:
        return SpawnBand.new(1.25, 100, 0)
    if elapsed_seconds < 150.0:
        return SpawnBand.new(0.9, 80, 20)
    if elapsed_seconds < 240.0:
        return SpawnBand.new(0.65, 65, 35)
    return SpawnBand.new(0.45, 55, 45)
