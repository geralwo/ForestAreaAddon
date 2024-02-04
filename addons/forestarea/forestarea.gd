@tool
extends EditorPlugin


func _enter_tree():
	add_custom_type(
		"ForestArea",
		"Node3D",
		preload("res://addons/forestarea/main.gd"),
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
