class_name LocalPlayerIdentityService
extends RefCounted

const PlayerColorPalette := preload("res://scripts/profile/player_color_palette.gd")
const LocalPlayerIdentityAssignment := preload("res://scripts/run/local_player_identity_assignment.gd")

const MAX_LOCAL_PLAYERS := 4


func assign(contexts: Array) -> LocalPlayerIdentityAssignment:
	var ordered: Array[PlayerRunContext] = []
	for value: Variant in contexts:
		if not value is PlayerRunContext:
			return LocalPlayerIdentityAssignment.new(
				"PARTY_FORGE_LOCAL_PLAYER_IDENTITY_ERROR reason=context is invalid"
			)
		ordered.append(value as PlayerRunContext)
	ordered.sort_custom(func(left: PlayerRunContext, right: PlayerRunContext) -> bool:
		if left.player_slot_index == right.player_slot_index:
			return String(left.run_player_id) < String(right.run_player_id)
		return left.player_slot_index < right.player_slot_index
	)
	if ordered.size() > MAX_LOCAL_PLAYERS:
		return LocalPlayerIdentityAssignment.new(
			"PARTY_FORGE_LOCAL_PLAYER_IDENTITY_ERROR count=%d reason=maximum local players is %d" % [ordered.size(), MAX_LOCAL_PLAYERS]
		)
	var identities: Dictionary = {}
	var claimed_slots: Dictionary = {}
	var claimed_profiles: Dictionary = {}
	var claimed_colors: Dictionary = {}
	for context: PlayerRunContext in ordered:
		var validation_error := _validate_context(context, identities, claimed_slots, claimed_profiles)
		if not validation_error.is_empty():
			return LocalPlayerIdentityAssignment.new(validation_error)
		var profile := context.profile_snapshot
		var color_id := profile.preferred_player_color_id
		if claimed_colors.has(color_id):
			return LocalPlayerIdentityAssignment.new(
				"PARTY_FORGE_LOCAL_PLAYER_IDENTITY_ERROR run_player_id=%s player_slot_index=%d profile=%s color_id=%s reason=preferred color already active" % [
					context.run_player_id,
					context.player_slot_index,
					context.profile_id,
					color_id,
				]
			)
		identities[context.run_player_id] = {
			"player_number": context.player_slot_index + 1,
			"color_id": color_id,
			"color": PlayerColorPalette.color(color_id),
		}
		claimed_slots[context.player_slot_index] = true
		claimed_profiles[context.profile_id] = true
		claimed_colors[color_id] = true
	return LocalPlayerIdentityAssignment.new("", identities)


func _validate_context(
	context: PlayerRunContext,
	identities: Dictionary,
	claimed_slots: Dictionary,
	claimed_profiles: Dictionary,
) -> String:
	if context.run_player_id.is_empty():
		return "PARTY_FORGE_LOCAL_PLAYER_IDENTITY_ERROR player_slot_index=%d profile=%s reason=run player id is empty" % [context.player_slot_index, context.profile_id]
	if context.player_slot_index < 0 or context.player_slot_index >= MAX_LOCAL_PLAYERS:
		return "PARTY_FORGE_LOCAL_PLAYER_IDENTITY_ERROR run_player_id=%s player_slot_index=%d profile=%s reason=slot is outside P1-P4" % [context.run_player_id, context.player_slot_index, context.profile_id]
	if identities.has(context.run_player_id):
		return "PARTY_FORGE_LOCAL_PLAYER_IDENTITY_ERROR run_player_id=%s player_slot_index=%d profile=%s reason=run player already assigned" % [context.run_player_id, context.player_slot_index, context.profile_id]
	if claimed_slots.has(context.player_slot_index):
		return "PARTY_FORGE_LOCAL_PLAYER_IDENTITY_ERROR run_player_id=%s player_slot_index=%d profile=%s reason=slot already assigned" % [context.run_player_id, context.player_slot_index, context.profile_id]
	if context.profile_id.is_empty() or claimed_profiles.has(context.profile_id):
		return "PARTY_FORGE_LOCAL_PLAYER_IDENTITY_ERROR run_player_id=%s player_slot_index=%d profile=%s reason=profile is invalid or already assigned" % [context.run_player_id, context.player_slot_index, context.profile_id]
	var profile := context.profile_snapshot
	if profile == null:
		return "PARTY_FORGE_LOCAL_PLAYER_IDENTITY_ERROR run_player_id=%s player_slot_index=%d profile=%s reason=profile snapshot is missing" % [context.run_player_id, context.player_slot_index, context.profile_id]
	if not PlayerColorPalette.is_valid(profile.preferred_player_color_id):
		return "PARTY_FORGE_LOCAL_PLAYER_IDENTITY_ERROR run_player_id=%s player_slot_index=%d profile=%s color_id=%s reason=preferred color is invalid" % [context.run_player_id, context.player_slot_index, context.profile_id, profile.preferred_player_color_id]
	return ""
