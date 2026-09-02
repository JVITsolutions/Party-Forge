class_name PassiveTreeActivationPolicy
extends RefCounted

const CITY_TREE_ID := &"party-forge-city-v1"
const FUTURE_MESSAGE := "Coming Soon"
const DISTRICT_TARGET_MISSING_MESSAGE := "District tree not installed"
const MESSAGES := {
	&"ok": "Action is available.",
	&"future_node": FUTURE_MESSAGE,
	&"district_target_missing": DISTRICT_TARGET_MISSING_MESSAGE,
}

func decision(
	tree: PassiveTreeDefinition,
	tree_node: PassiveTreeNode,
	portfolio: LatticewrightRuntimePortfolioRegistry,
) -> PassiveTreeActionDecision:
	if tree == null or tree_node == null:
		return _decision(&"future_node")
	var authored_state := StringName(tree_node.metadata.get("activationState", ""))
	if authored_state.is_empty():
		return _decision(&"future_node" if tree.id == CITY_TREE_ID else &"ok")
	match authored_state:
		&"implemented":
			return _decision(&"ok")
		&"future":
			return _decision(&"future_node")
		&"portal-gated":
			var portal := tree.portal_for_source_node(tree_node.id)
			if portal != null and portfolio != null and portfolio.has_graph(portal.target_project_id, portal.target_graph_id):
				return _decision(&"ok")
			return _decision(&"district_target_missing")
		_:
			return _decision(&"future_node")

func _decision(code: StringName) -> PassiveTreeActionDecision:
	return PassiveTreeActionDecision.new(code == &"ok", code, MESSAGES[code])
