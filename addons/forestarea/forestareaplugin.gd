@tool
extends EditorPlugin

func _enter_tree():
	add_custom_type(
		"ForestArea",
		"Node3D",
		preload("res://addons/forestarea/ForestArea.gd"),
		preload("res://addons/forestarea/forestarea_icon.svg")
	)
	add_custom_type(
		"ForestAreaData",
		"Resource",
		preload("res://addons/forestarea/ForestAreaData.gd"),
		preload("res://addons/forestarea/forestarea_icon.svg")
	)

func _exit_tree():
	# Clean-up of the plugin goes here.
	remove_custom_type("ForestArea")
	remove_custom_type("ForestAreaData")
	for c in get_children():
		if c.is_in_group("_forest_tree_tmp"):
			c.queue_free()
