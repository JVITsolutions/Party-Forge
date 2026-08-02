class_name Leader
extends PartyActor

func _physics_process(_delta: float) -> void:
    var health: HealthComponent = _health_component()
    if get_tree().paused or (health != null and (health.is_downed or health.is_dead)):
        velocity = Vector3.ZERO
        update_presentation_locomotion()
        return
    var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    velocity = LeaderMovement.velocity(input_vector, move_speed)
    move_and_slide()
    update_presentation_locomotion()
