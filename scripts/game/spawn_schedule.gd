class_name SpawnSchedule
extends RefCounted

class SpawnBand extends RefCounted:
    var interval: float
    var swarmer_weight: int
    var boltcaster_weight: int
    var spitter_weight: int

    func _init(seconds: float, swarmer: int, boltcaster: int, spitter: int) -> void:
        interval = seconds
        swarmer_weight = swarmer
        boltcaster_weight = boltcaster
        spitter_weight = spitter

static func sample(elapsed_seconds: float) -> SpawnBand:
    if elapsed_seconds < 0.0 or elapsed_seconds >= 300.0:
        return null
    if elapsed_seconds < 60.0:
        return SpawnBand.new(0.56, 100, 0, 0)
    if elapsed_seconds < 150.0:
        return SpawnBand.new(0.40, 75, 25, 0)
    if elapsed_seconds < 240.0:
        return SpawnBand.new(0.29, 60, 32, 8)
    return SpawnBand.new(0.20, 50, 35, 15)
