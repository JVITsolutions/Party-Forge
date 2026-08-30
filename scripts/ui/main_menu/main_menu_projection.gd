class_name MainMenuProjection
extends RefCounted

var primary_label := ""
var primary_visible := false
var primary_enabled := false
var primary_route_id: StringName = &""

var city_tree_label := ""
var city_tree_visible := false
var city_tree_enabled := false
var city_tree_route_id: StringName = &""

var armoury_label := ""
var armoury_visible := false
var armoury_enabled := false
var armoury_route_id: StringName = &""

var warehouse_label := ""
var warehouse_visible := false
var warehouse_enabled := false
var warehouse_route_id: StringName = &""
var warehouse_presentation_state: WarehousePresentationResult.State = WarehousePresentationResult.State.HIDDEN

var developer_quick_start_label := ""
var developer_quick_start_visible := false
var developer_quick_start_enabled := false
var developer_quick_start_route_id: StringName = &""

var settings_label := ""
var settings_visible := false
var settings_enabled := false
var settings_route_id: StringName = &""

var quit_label := ""
var quit_visible := false
var quit_enabled := false
var quit_route_id: StringName = &""

var active_profile_text := ""
var status_text := ""
var reduced_motion := false

func copy() -> MainMenuProjection:
	var result := MainMenuProjection.new()
	result.primary_label = primary_label
	result.primary_visible = primary_visible
	result.primary_enabled = primary_enabled
	result.primary_route_id = primary_route_id
	result.city_tree_label = city_tree_label
	result.city_tree_visible = city_tree_visible
	result.city_tree_enabled = city_tree_enabled
	result.city_tree_route_id = city_tree_route_id
	result.armoury_label = armoury_label
	result.armoury_visible = armoury_visible
	result.armoury_enabled = armoury_enabled
	result.armoury_route_id = armoury_route_id
	result.warehouse_label = warehouse_label
	result.warehouse_visible = warehouse_visible
	result.warehouse_enabled = warehouse_enabled
	result.warehouse_route_id = warehouse_route_id
	result.warehouse_presentation_state = warehouse_presentation_state
	result.developer_quick_start_label = developer_quick_start_label
	result.developer_quick_start_visible = developer_quick_start_visible
	result.developer_quick_start_enabled = developer_quick_start_enabled
	result.developer_quick_start_route_id = developer_quick_start_route_id
	result.settings_label = settings_label
	result.settings_visible = settings_visible
	result.settings_enabled = settings_enabled
	result.settings_route_id = settings_route_id
	result.quit_label = quit_label
	result.quit_visible = quit_visible
	result.quit_enabled = quit_enabled
	result.quit_route_id = quit_route_id
	result.active_profile_text = active_profile_text
	result.status_text = status_text
	result.reduced_motion = reduced_motion
	return result
