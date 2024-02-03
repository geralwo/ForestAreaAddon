@tool
extends EditorPlugin
var forest = load("res://addons/forestarea/main.gd")

func _enter_tree():
	add_custom_type(
		"ForestArea",
		"Node3D",
		preload("res://addons/forestarea/main.gd"),
		preload("res://icon.svg")
	)
	add_custom_type(
		"OctreeNode",
		"Resource",
		preload("res://addons/forestarea/octree_node.gd"),
		preload("res://icon.svg")
	)


func _exit_tree():
	# Clean-up of the plugin goes here.
	remove_custom_type("GridPlacer")
