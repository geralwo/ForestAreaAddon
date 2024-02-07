@tool
extends Resource
class_name SceneCollection

@export var scenes : Array[PackedScene]
var _last_scene = null


func size():
	return scenes.size()

func last_scene():
	return _last_scene

func all():
	return scenes

func give_random_item():
	var index = randi() % scenes.size()
	_last_scene = scenes[index]
	return scenes[index]
