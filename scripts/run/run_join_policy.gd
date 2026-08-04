class_name RunJoinPolicy
extends RefCounted

const ARENA: StringName = &"arena"
const ADVENTURE: StringName = &"adventure"

static func can_accept(mode_id: StringName, roster_locked: bool, at_safe_checkpoint: bool) -> bool:
	match mode_id:
		ARENA:
			return not roster_locked
		ADVENTURE:
			return at_safe_checkpoint
		_:
			return false
