class_name SwarmerRatPresentation
extends Node

@export var animation_player_path: NodePath

var _locked := false
var _dead := false
var _player: AnimationPlayer

func _ready() -> void:
	_player = get_node_or_null(animation_player_path) as AnimationPlayer
	play_locomotion(false)

func play_locomotion(moving: bool) -> void:
	if _dead or _locked or _player == null:
		return
	var desired: StringName = &"scurry" if moving else &"idle_sniff"
	if _player.has_animation(desired) and _player.current_animation != desired:
		_player.play(desired, 0.08)

func play_attack() -> void:
	_play_locked(&"pounce_bite", 0.04)

func play_hit() -> void:
	if not _dead:
		_play_locked(&"hit_react", 0.02)

func play_death() -> float:
	_dead = true
	_locked = true
	if _player == null or not _player.has_animation(&"death_curl"):
		return 0.0
	_player.play(&"death_curl", 0.03)
	return _player.get_animation(&"death_curl").length

func _play_locked(animation_name: StringName, blend: float) -> void:
	if _dead or _player == null or not _player.has_animation(animation_name):
		return
	_locked = true
	_player.play(animation_name, blend)
	if not _player.animation_finished.is_connected(_on_animation_finished):
		_player.animation_finished.connect(_on_animation_finished)

func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name != &"death_curl":
		_locked = false
