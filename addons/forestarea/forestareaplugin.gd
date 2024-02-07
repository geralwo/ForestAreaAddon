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


func editor_cam_pos():
	# Get the editor's current scene tree
	var scene_tree = EditorInterface.get_editor_main_screen()

	# Check if the editor's scene tree is valid
	if scene_tree:
		# Get the editor's active viewport
		var editor_viewport = scene_tree.get_root().get_child(0)

		# Check if the editor's viewport is valid
		if editor_viewport and editor_viewport.is_class("Viewport"):
			# Get the camera currently used by the editor
			var editor_camera = editor_viewport.get_camera()

			# Check if the editor camera is valid and is a Camera node
			if editor_camera and editor_camera.is_class("Camera"):
				# Get the position of the editor camera
				var camera_position = editor_camera.global_transform.origin
				print("Editor Camera Position:", camera_position)
			else:
				print("Editor camera is not valid or is not a Camera node.")
		else:
			print("Editor viewport is not valid.")
	else:
		print("Editor scene tree is not valid.")

func _exit_tree():
	# Clean-up of the plugin goes here.
	remove_custom_type("ForestArea")
	remove_custom_type("ForestAreaData")
