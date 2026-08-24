extends PartyManager

var action_snapshot_calls := 0
var weapon_snapshot_calls := 0

func stats_for_action(member_id: int, action_tags: Array[StringName]) -> ResolvedStatSnapshot:
	action_snapshot_calls += 1
	return super.stats_for_action(member_id, action_tags)

func active_weapon_snapshot(member_id: int) -> ActiveWeaponDamageSnapshot:
	weapon_snapshot_calls += 1
	return super.active_weapon_snapshot(member_id)
