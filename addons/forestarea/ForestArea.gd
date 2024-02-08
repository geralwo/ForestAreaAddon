@tool
extends Node3D
class_name ForestArea

# TODO:
# fix issue when rotating the area, the raycasts dont seem to be rotated with it

@export var generate : bool = false :
	set(_v):
		_generate()
		if _show_aabb_preview:
			_update_aabb_preview()
@export var max_tree_count : int = 7
@export var _size : Vector3 = Vector3(100,100,100):
	set(v):
		_size = v
		if _show_aabb_preview:
			_generate()
@export var tree_growing_group : String = "terrain"
@export var scenes : Array[PackedScene]
@export var ForestData : ForestAreaData
@export var editor_render_distance : float = 100.0
@export_category("Debug")
@export var _aabb_color : Color = Color(Color.WEB_GREEN,0.3)
@export var _view_query_data : bool = false
@export var _show_aabb_preview : bool = true :
	set(v):
		_show_aabb_preview = v
		if v:
			_update_aabb_preview()
		else:
			if _preview_mesh:
				_preview_mesh.queue_free()
@export var _show_octree_structure : bool = false:
	set(v):
		_show_octree_structure = v
		if v:
			_view_octree_structure()
		else:
			for c in get_children():
				if c.is_in_group("_octree_visualize"):
					c.queue_free()

var _temp_meshes : Array[MeshInstance3D]
var _preview_mesh : MeshInstance3D

signal generation_done

func _ready():
	if ForestData:
		prints(self.name, "has", ForestData.items_size(),"trees")

func _process(delta):
	if Engine.is_editor_hint():
		if ForestData:
			load_items_within_radius(EditorInterface.get_editor_viewport_3d().get_camera_3d().position,editor_render_distance)
			unload_items_outside_radius(EditorInterface.get_editor_viewport_3d().get_camera_3d().position,editor_render_distance)
	if load_queue.size() > 0:
		for i in 32:
			var obj_to_load = load_queue.pop_back()
			if obj_to_load:
				add_child(obj_to_load)
	if unload_queue.size() > 0:
		for i in 32:
			var obj_to_unload = unload_queue.pop_back()
			if obj_to_unload:
				obj_to_unload.queue_free()

func _generate():
	if ForestData:
		ForestData.clear()

	existing_points.clear()
	load_queue.clear()
	unload_queue.clear()
	for c in get_children():
		if c.is_in_group("_forest_tree_tmp"):
			if c:
				c.queue_free()
	if is_inside_tree():
		_update_aabb_preview()
		ForestData = ForestAreaData.new(self.global_transform.origin - _preview_mesh.mesh.get_aabb().size / 2,_preview_mesh.mesh.get_aabb().size)
		var denied_positions = []
		if scenes.size() == 0:
			printerr(self.name," - Please add a Scene")
			return
		print("::: generating Forest")
		var result_positions = []
		# Clear existing trees
		for m in _temp_meshes:
			if m:
				m.queue_free()
		_temp_meshes.clear()
		var space_state = get_world_3d().direct_space_state
		var _generated_trees = 0
		var _error = 0
		for i in range(max_tree_count):
			var random_position = random_point_in_aabb(ForestData.aabb)
			var query_start = to_global(random_position)
			var query_end = to_global(random_position + Vector3(0,-ForestData.aabb.size.y,0))

			var hit_s = draw_debug_box(query_start,Vector3.ONE * 5,Color(Color.HOT_PINK,0.15))
			var hit_e = draw_debug_box(query_end,Vector3.ONE * 5,Color(Color.LIME_GREEN,0.15))
			hit_s.position = to_local(query_start)
			hit_e.position = to_local(query_end)
			_temp_meshes.append(hit_s)
			_temp_meshes.append(hit_e)

			var query = PhysicsRayQueryParameters3D.create(query_start,query_end) # global coords
			var result = space_state.intersect_ray(query) # global coords

			if result && result.collider.is_in_group(tree_growing_group):
				var hit = draw_debug_box(result.position,Vector3.ONE * 5,Color(Color.SKY_BLUE,0.95))
				result_positions.append(result.position)
				hit.position = to_local(result.position)
				_temp_meshes.append(hit)
		for pos in result_positions:
			var tree_scale = randf_range(1,3)
			var _scale = Vector3(tree_scale,tree_scale,tree_scale)
			var scene_id = randi() % scenes.size()
			var data = {
				"id": scene_id,
				"scale": _scale,
			}
			if not ForestData.insert(pos, data):
				denied_positions.append(pos)
		if _view_query_data:
			for m in _temp_meshes:
				add_child(m)
			for pos in denied_positions:
				var x = draw_debug_box(pos,Vector3.ONE * 5,Color.TOMATO)
				x.add_to_group("_forest_tree_tmp")
				x.position = to_local(pos)
				add_child(x)
		if _show_octree_structure:
			_view_octree_structure()
		if _show_aabb_preview:
			_update_aabb_preview()

		emit_signal("generation_done")


func _view_octree_structure():
	for c in get_children():
		if c.is_in_group("_octree_visualize"):
			c.queue_free()
	var nodes = ForestAreaData.visualize(ForestData)
	nodes.add_to_group("_octree_visualize")
	nodes.global_transform.origin -= self.global_transform.origin
	add_child(nodes)

func _create_imposters():
	pass

func _update_aabb_preview():
	if _preview_mesh:
		_preview_mesh.queue_free()
		_preview_mesh = null
	if ForestData:
		_preview_mesh = draw_debug_box(ForestData.aabb.position,ForestData.aabb.size,_aabb_color)
		add_child(_preview_mesh)
	else:
		_preview_mesh = draw_debug_box(self.position,_size,_aabb_color)
		add_child(_preview_mesh)

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
	for existing_point in existing_points:
		var distance = random_point.distance_to(existing_point)
		if distance < min_distance_threshold:
			# If too close, generate a new point recursively
			return generate_unique_random_point(aabb, min_distance_threshold)

	# If the point is unique enough, add it to the existing points and return
	existing_points.append(random_point)
	return random_point



var inactive_objs = {}
var active_objs = {}
var load_queue = []
var unload_queue = []
func load_items_within_radius(_pos,_radius = 100.0):
	var query = ForestData.query(_radius, _pos)
	for pos in query:
		if not active_objs.has(pos):
			var generation_instance = scenes[query[pos].id].instantiate()
			generation_instance.add_to_group("_forest_tree_tmp")
			generation_instance.position = to_local(pos)
			add_child(generation_instance)
			active_objs[pos] = generation_instance

func unload_items_outside_radius(_pos,_radius = 100.0):
	var positions_to_unload = []
	for pos in active_objs.keys():
		if pos.distance_to(_pos) > _radius * 1.0:
			positions_to_unload.append(pos)

	for pos in positions_to_unload:
		var obj = active_objs[pos]
		var model_path = obj # Resource path
		if not inactive_objs.has(model_path):
			inactive_objs[model_path] = []
		inactive_objs[model_path].append(obj)

		#remove_child(obj)
		unload_queue.append(obj)
		active_objs.erase(pos)
