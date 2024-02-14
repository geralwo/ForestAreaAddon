@tool
extends Resource
class_name ForestAreaItem

@export var name : String
@export var LOD : Array[Mesh]
@export var collision : Shape3D
@export var scene : PackedScene
var _scale_min_uniform : Vector3 = Vector3.ONE
@export var scale_min : Vector3 = Vector3.ONE:
	set(v):
		if scale_uniformly:
			_scale_min_uniform = Vector3(v[v.min_axis_index()],v[v.min_axis_index()],v[v.min_axis_index()])
		else:
			scale_min = v
	get:
		if scale_uniformly:
			return _scale_min_uniform
		return scale_min

var _scale_max_uniform : Vector3 = Vector3.ONE
@export var scale_max : Vector3 = Vector3.ONE:
	set(v):
		if scale_uniformly:
			_scale_max_uniform = Vector3(v[v.max_axis_index()],v[v.max_axis_index()],v[v.max_axis_index()])
		else:
			scale_max = v
	get:
		if scale_uniformly:
			return _scale_max_uniform
		return scale_max
## If set to true, the minimum scale will be the lowest value in the scale_min Vector3 and the maximum scale will be the heighest value in the scale_max Vector3, so the scaling is uniform
@export var scale_uniformly : bool = false
@export var create_trimesh_collison = false:
	set(v):
		create_trimesh_collison = v
		if LOD.size() > 0:
			collision = _create_trimesh_collider(LOD[0])
		else:
			create_trimesh_collison = false
			printerr("No LOD0 set")
@export var scripts : Array
@export var childs : Array

func _create_trimesh_collider(mesh : Mesh) -> ConcavePolygonShape3D:
	return mesh.create_trimesh_shape()
