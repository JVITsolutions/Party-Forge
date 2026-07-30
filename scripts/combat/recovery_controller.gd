class_name RecoveryController
extends Node

var health: HealthComponent
var regeneration_provider: Callable

func configure(target_health: HealthComponent, provider: Callable) -> void:
	health = target_health
	regeneration_provider = provider

func advance(delta: float) -> float:
	if health == null or health.is_dead or health.is_downed or delta <= 0.0 or health.current_health >= health.max_health:
		return 0.0
	var rate := maxf(0.0, float(regeneration_provider.call())) if regeneration_provider.is_valid() else 0.0
	return health.heal(rate * delta)
