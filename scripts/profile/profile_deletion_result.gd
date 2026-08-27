class_name ProfileDeletionResult
extends RefCounted

# Outcome truth table:
# committed=false, cleanup_debt=false: fully restored clean noncommit.
# committed=true, cleanup_debt=false: fully deleted.
# committed=true, cleanup_debt=true: deleted with index cleanup debt.
# committed=false, cleanup_debt=true: indeterminate partial rollback failure; reconcile disk authority.
var committed := false
var cleanup_debt := false
var deleted_profile_id := ""
var next_active_profile_id := ""
var error := ""

func ok() -> bool:
	return committed and not cleanup_debt
