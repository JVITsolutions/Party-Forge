class_name RunStateMachine
extends RefCounted

signal state_changed(state: State)
signal boss_requested
signal victory
signal defeat

enum State { SETUP, RUNNING, LEVEL_UP, BOSS, VICTORY, DEFEAT }

const BOSS_TIME := 300.0

var state: State = State.SETUP
var elapsed := 0.0
var terminal_locked := false
var boss_emitted := false

func start() -> void:
    _set_state(State.RUNNING)

func advance_run_time(delta: float) -> void:
    if state != State.RUNNING or delta <= 0.0:
        return
    elapsed = minf(BOSS_TIME, elapsed + delta)
    if is_equal_approx(elapsed, BOSS_TIME):
        elapsed = BOSS_TIME
    if elapsed >= BOSS_TIME and not boss_emitted:
        boss_emitted = true
        _set_state(State.BOSS)
        boss_requested.emit()

func begin_level_up() -> void:
    if state == State.RUNNING:
        _set_state(State.LEVEL_UP)

func resume_run() -> void:
    if state == State.LEVEL_UP:
        _set_state(State.RUNNING)

func leader_defeated() -> void:
    if terminal_locked:
        return
    terminal_locked = true
    _set_state(State.DEFEAT)
    defeat.emit()

func boss_defeated() -> void:
    if terminal_locked or state != State.BOSS:
        return
    terminal_locked = true
    _set_state(State.VICTORY)
    victory.emit()

func _set_state(next: State) -> void:
    if next == state:
        return
    state = next
    state_changed.emit(state)
