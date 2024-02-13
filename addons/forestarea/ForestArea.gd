@tool
extends Node3D
class_name ForestArea

# TODO:
# fix issue when rotating the area, the raycasts dont seem to be rotated with it

## Generates a new forest
@export var generate : bool = false :
	set(_v):
		_generate()
		if _show_aabb_preview:
			_update_aabb_preview()
## Defines the area of the Forest as an AABB
@export var _size : Vector3 = Vector3(100,100,100):
	set(v):
		_size = v
		if _show_aabb_preview:
			_update_aabb_preview()
## Sets the max amount of trees in the area. Usually it's less
@export var max_tree_count : int = 7
## Max degree angle on which trees grow
@export var max_slope : float = 45.0
## The group on which trees grow
@export var tree_growing_group : String = "terrain"
## The scenes to be instanced
@export var flora : Array[ForestAreaItem]
@export var ForestData : ForestAreaData
## Sets the editor render distance
@export var editor_render_distance : float = 1000.0
## Defines when each LOD gets shown
@export var lod_curve : Curve = load("res://addons/forestarea/base_curve.tres"):
	set(v):
		lod_curve = v
## Shows the bounding box of the Forest
@export var _show_aabb_preview : bool = true :
	set(v):
		_show_aabb_preview = v
		_update_aabb_preview()

@export_category("Debug")
@export_group("Settings")
@export var _aabb_color : Color = Color(Color.WEB_GREEN,0.3)
## Shows the positions of the raycasts that did not hit the AABB
@export var _view_query_data : bool = false:
	set(v):
		_view_query_data = v
		if not v:
			_show_query_data([])
## Visualizes the octree structure
@export var _show_octree_structure : bool = false:
	set(v):
		_show_octree_structure = v
		if v:
			_view_octree_structure()
		else:
			for c in get_children():
				if c.is_in_group("_octree_visualize"):
					c.queue_free()
@export var _octree_corners_color : Color = Color.ALICE_BLUE

var _temp_meshes : Array[MeshInstance3D]
var _preview_mesh : MeshInstance3D = MeshInstance3D.new()
var _multi_mesh_instance_lod0 : MultiMeshInstance3D
var _multi_mesh_instance_lod1 : MultiMeshInstance3D
var _multi_mesh_instance_lod2 : MultiMeshInstance3D
var _multi_mesh_instance_lod3 : MultiMeshInstance3D

var _multi_mesh_lod0 : MultiMesh
var _multi_mesh_lod1 : MultiMesh
var _multi_mesh_lod2 : MultiMesh
var _multi_mesh_lod3 : MultiMesh

var _multi_mesh_instances : Array
var _static_body : StaticBody3D
var _area_body : Area3D

signal generation_done

func _ready():
	_static_body = StaticBody3D.new()
	add_child(_static_body)
	if Engine.is_editor_hint():
		add_child(_preview_mesh)
		_preview_mesh.visible = _show_aabb_preview
	if ForestData:
		if flora:
			_multi_mesh_instances = _create_mm_instances(flora)
			prints(self.name, "has", ForestData.items_size(),"items")
			for group in _multi_mesh_instances:
				for lod in group:
					add_child(lod)

func _process(delta):
	if Engine.is_editor_hint():
		if ForestData && flora.size() != 0:
			update(EditorInterface.get_editor_viewport_3d().get_camera_3d().position,editor_render_distance)
func _generate():
	if ForestData:
		ForestData.clear()
	else:
		if flora.size() == 0:
			printerr("Missing Flora. No flora assigned to %s" % self.name )
		ForestData = ForestAreaData.new()
	existing_points.clear()
	if is_inside_tree():
		_update_aabb_preview(true)
		ForestData = ForestAreaData.new(self.global_transform.origin - _size / 2,_size)
		prints("ForestData aabb",ForestData.aabb,self.global_transform.origin,_preview_mesh.mesh.get_aabb())
		#ForestData.aabb = rotated_aabb(ForestData.aabb,rotation_degrees.y)
		var denied_positions = []
		var result_positions = []
		# Clear existing trees
		for m in _temp_meshes:
			if m:
				m.queue_free()
		_temp_meshes.clear()
		var space_state = get_world_3d().direct_space_state
		var _generated_trees = 0
		var _error = 0
		for i : int in range(max_tree_count):
			var random_position = random_point_in_aabb(ForestData.aabb)
			var query_start = to_global(random_position)
			var query_end = to_global(random_position + Vector3(0,-ForestData.aabb.size.y,0))

			var query = PhysicsRayQueryParameters3D.create(query_start,query_end) # global coords
			var result = space_state.intersect_ray(query) # global coords

			if result && result.collider.is_in_group(tree_growing_group):
				var up_direction = Vector3.UP
				var dot_product = result.normal.dot(up_direction)
				var angle_rad = acos(dot_product)
				var angle_deg = rad_to_deg(angle_rad)

				if angle_deg < max_slope:
					result_positions.append(result.position)

		for pos : Vector3 in result_positions:
			var instance_transform = Transform3D.IDENTITY
			var scene_id = randi() % flora.size()
			var tree_scale_x = randf_range(flora[scene_id].scale_min.x, flora[scene_id].scale_max.x)
			var tree_scale_y = randf_range(flora[scene_id].scale_min.y, flora[scene_id].scale_max.y)
			var tree_scale_z = randf_range(flora[scene_id].scale_min.z, flora[scene_id].scale_max.z)
			var _scale = Vector3(tree_scale_x, tree_scale_y, tree_scale_z)

			var _basis = Basis()
			_basis = _basis.scaled(_scale)  # Apply scaling
			_basis = _basis.rotated(Vector3.UP, randf() * 2 * PI)  # Rotate around Y-axis
			#_basis.y.y = randf() * 2 * PI


			#var instance_transform = Transform3D(_basis, to_local(pos))
			instance_transform.origin = to_local(pos)
			instance_transform.basis = _basis
			var data = {
				"index": scene_id,
				"scale": _scale,
				"transform": instance_transform,
				"collider_shape": flora[scene_id].collision,
				"meshes": flora[scene_id].LOD,
			}
			if not ForestData.insert(pos, data):
				denied_positions.append(pos)

		_show_query_data(denied_positions)
		if _show_octree_structure:
			_view_octree_structure()
		_update_aabb_preview()

		emit_signal("generation_done")

func update(_pos,_radius):
	if ForestData:
		if Engine.get_frames_drawn() % 2 == 0:
			load_items_within_radius(_pos,_radius)
		else:
			unload_items_outside_radius(_pos,_radius)

func _show_query_data(data : Array):
	for c in get_children():
		if c.is_in_group("_forest_area_tmp"):
			c.queue_free()
	if _view_query_data:
		for pos : Vector3 in data:
			var x = draw_debug_box(pos,Vector3.ONE * 1,Color.TOMATO)
			x.add_to_group("_forest_area_tmp")
			x.position = to_local(pos)
			add_child(x)

func _view_octree_structure():
	for c in get_children():
		if c.is_in_group("_octree_visualize"):
			c.queue_free()
	var nodes = ForestAreaData.visualize(ForestData,_octree_corners_color)
	nodes.add_to_group("_octree_visualize")
	add_child(nodes)
	nodes.global_transform.origin -= self.global_transform.origin

func _update_aabb_preview(force : bool = false):
	if _show_aabb_preview or force:
		if ForestData:
			var box = BoxMesh.new()
			box.size = ForestData.aabb.size
			var material = StandardMaterial3D.new()
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color = _aabb_color
			material.flags_unshaded = true
			box.surface_set_material(0, material)
			_preview_mesh.mesh = box
			_preview_mesh.visible = true
			#_preview_mesh.global_transform = self.global_transform
		else:
			var box = BoxMesh.new()
			box.size = _size
			var material = StandardMaterial3D.new()
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color = _aabb_color
			material.flags_unshaded = true
			box.surface_set_material(0, material)
			_preview_mesh.mesh = box
			_preview_mesh.visible = true
	else:
		_preview_mesh.visible = false

func random_point_in_aabb(aabb: AABB) -> Vector3:
	var random_point = Vector3(
			randi_range(-(aabb.size.x / 2),(aabb.size.x / 2)),
			aabb.size.y / 2,  # Keep Y coordinate constant at max y
			randi_range(-(aabb.size.z / 2),(aabb.size.z / 2))
		)
	return random_point

func draw_debug_sphere(location: Vector3, size: float = 1.0, col: Color = Color.RED,  radial_segments : int = 8, is_hemisphere : bool = false) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	# Create sphere with low detail of size.
	var sphere = SphereMesh.new()
	sphere.is_hemisphere = is_hemisphere
	sphere.radial_segments = radial_segments
	sphere.rings = radial_segments / 2
	sphere.radius = size
	if is_hemisphere:
		node.rotate_x(deg_to_rad(180))
		sphere.height = size
	else:
		sphere.height = size * 2
	# Bright red material (unshaded).
	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = col
	material.flags_unshaded = true
	sphere.surface_set_material(0, material)
	# Add to meshinstance in the right place.
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.mesh = sphere
	if false:
		node.rotation.y = randf()
	return node

func draw_debug_box(location: Vector3, size: Vector3, col: Color = Color.RED) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = col
	material.flags_unshaded = true
	box.surface_set_material(0, material)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.mesh = box
	return node

var existing_points : Array = []
func generate_unique_random_point(aabb: AABB, min_distance_threshold: float) -> Vector3:
	var random_point = random_point_in_aabb(aabb)

	# Check the distance between the new point and existing points
	for existing_point : Vector3 in existing_points:
		var distance = random_point.distance_to(existing_point)
		if distance < min_distance_threshold:
			# If too close, generate a new point recursively
			return generate_unique_random_point(aabb, min_distance_threshold)

	# If the point is unique enough, add it to the existing points and return
	existing_points.append(random_point)
	return random_point

func load_items_within_radius(_pos : Vector3,_radius : float = 100.0):
	var query = ForestData.query(_radius, _pos)
	# go through each group of mm instances
	var used_pos = []
	for group_index : int in range(_multi_mesh_instances.size()):
		for lod_index in range(_multi_mesh_instances[group_index].size()):
			var _instance_count = 0
			var _position = []
			var x_coord_fraction = 1.0 / (_multi_mesh_instances[group_index].size() - 1)
			var _prev_lod_level : float = 0

			var lod_distances = []
			for i in range(_multi_mesh_instances[group_index].size()):
				var lod_sample = lod_curve.sample(x_coord_fraction * i)
				var distance = _radius * lod_sample
				lod_distances.append(lod_sample)
			#print(lod_distances)
			for pos : Vector3 in query:
				var distance = _pos.distance_to(pos)
				if lod_index == 0:
					if distance < lod_distances[lod_index]:
						_instance_count += 1
						_position.append(query[pos])
				else:
					if distance < lod_distances[lod_index] and not distance > lod_distances[lod_index] and distance > lod_distances[lod_index - 1]:
						_instance_count += 1
						_position.append(query[pos])

			_multi_mesh_instances[group_index][lod_index].multimesh.instance_count = _instance_count

			if _position.size() > 0:
				_multi_mesh_instances[group_index][lod_index].multimesh.mesh = _position[0].meshes[lod_index]
				for i in range(_position.size()):
					_multi_mesh_instances[group_index][lod_index].multimesh.set_instance_transform(i,_position[i].transform)
			#print(lod_distances)
			_position.clear()

var _colliders : Dictionary = {}
func unload_items_outside_radius(_pos,_radius = 100.0):
	var positions_to_unload = []
	for pos in _colliders.keys():
		if pos.origin.distance_to(_pos) > _radius * lod_curve.sample(0.5):
			positions_to_unload.append(pos)
	if positions_to_unload.size() == 0:
		return
	for pos in positions_to_unload:
		var obj = _colliders[pos]
		obj.queue_free()
		_colliders.erase(pos)

func _add_collider(_transform : Transform3D, _shape : Shape3D):
	if Engine.get_frames_drawn() % 2 == 0:
		if not _colliders.has(_transform):
			var collider = CollisionShape3D.new()
			collider.global_transform = _transform
			collider.shape = _shape
			_colliders[_transform] = collider
			_static_body.add_child(_colliders[_transform])

func _create_mm_instances(data : Array) -> Array:
	var instances : Array = []
	for i : int in range(data.size()): # for each model in data
		var group = []
		for j : int in range(data[i].LOD.size()): # for each lod model in data[i] we create a MultimeshInstance3D
			var _multi_mesh_instance = MultiMeshInstance3D.new()
			_multi_mesh_instance.name = "%s_%s_%s" % [i, data[i].name ,j]
			print(_multi_mesh_instance.name)
			var _multi_mesh = MultiMesh.new()
			_multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
			_multi_mesh.mesh = data[i].LOD[j]
			_multi_mesh_instance.multimesh = _multi_mesh
			group.append(_multi_mesh_instance)
		instances.append(group)
	return instances

func rotated_aabb(aabb : AABB, _rotation_degrees):
	var center = aabb.get_center()
	var corners = []
	var new_aabb = aabb
	if _rotation_degrees == 0.0:
		return new_aabb
	for i in range(8):
		corners.append(aabb.get_endpoint(i))

	var s = sin(deg_to_rad(_rotation_degrees))
	var c = cos(deg_to_rad(_rotation_degrees))

	for corner in corners:
		var x1 = corner.x - center.x
		var z1 = corner.z - center.z

		var x2 = x1 * c - z1 * s
		var z2 = x1 * s - z1 * c
		print(corner)
		corner.x = x2 + corner.x
		corner.z = z2 + corner.z
		print(corner)
	return new_aabb
