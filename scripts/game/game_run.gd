class_name GameRun
extends Node

signal state_changed(state: int)
signal boss_requested
signal victory
signal defeat

const RunStateMachineScript := preload("res://scripts/game/run_state_machine.gd")
const DEBUG_ACCELERATION_PREFIX := "--party-forge-debug-acceleration="

var state_machine: RefCounted
var debug_time_scale := 1.0
var run_seed := 1337
var combat_rng := CombatRng.new(run_seed)

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	state_machine = RunStateMachineScript.new() as RefCounted
	state_machine.connect("state_changed", _on_state_changed)
	state_machine.connect("boss_requested", func() -> void: boss_requested.emit())
	state_machine.connect("victory", func() -> void: victory.emit())
	state_machine.connect("defeat", func() -> void: defeat.emit())

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	debug_time_scale = debug_scale_from_arguments(OS.get_cmdline_user_args(), OS.is_debug_build())

func configure_seed(seed_value: int) -> void:
	run_seed = seed_value
	combat_rng.reseed(run_seed)

func _process(delta: float) -> void:
	advance_run_time(delta)

func start_run() -> void:
	state_machine.call("start")

func advance_run_time(delta: float) -> void:
	state_machine.call("advance_run_time", maxf(delta, 0.0) * debug_time_scale)

func begin_level_up() -> void:
	state_machine.call("begin_level_up")

func resume_run() -> void:
	state_machine.call("resume_run")

func leader_defeated() -> void:
	state_machine.call("leader_defeated")

func boss_defeated() -> void:
	state_machine.call("boss_defeated")

func current_state() -> int:
	return int(state_machine.get("state"))

func elapsed_time() -> float:
	return float(state_machine.get("elapsed"))

static func debug_scale_from_arguments(arguments: PackedStringArray, debug_enabled: bool) -> float:
	if not debug_enabled:
		return 1.0
	for argument: String in arguments:
		if not argument.begins_with(DEBUG_ACCELERATION_PREFIX):
			continue
		var value := argument.trim_prefix(DEBUG_ACCELERATION_PREFIX).to_float()
		if value > 0.0:
			return value
	return 1.0

func _on_state_changed(next_state: int) -> void:
	var should_pause := next_state in [
		RunStateMachineScript.State.LEVEL_UP,
		RunStateMachineScript.State.VICTORY,
		RunStateMachineScript.State.DEFEAT,
	]
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.paused = should_pause
	state_changed.emit(next_state)
