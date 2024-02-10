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
@export var flora : Array[TreeBase]
@export var ForestData : ForestAreaData
## Sets the editor render distance
@export var editor_render_distance : float = 250.0
## Shows the bounding box of the Forest
@export var _show_aabb_preview : bool = true :
	set(v):
		_show_aabb_preview = v
		_update_aabb_preview()
@export var lod_curve : Curve = Curve.new()
@export_category("Debug")
@export_group("Settings")
@export var _aabb_color : Color = Color(Color.WEB_GREEN,0.3)
## Shows the positions of the raycasts
@export var _view_query_data : bool = false
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


var lod0_distance = 100.0
var lod1_distance = 200.0


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


var inactive_objs = {}
var active_objs = {}
var load_queue = []
var unload_queue = []
signal generation_done

func _ready():
	add_child(_preview_mesh)
	_preview_mesh.visible = _show_aabb_preview
	if ForestData:
		if flora:
			_multi_mesh_lod0 = MultiMesh.new()
			_multi_mesh_lod1 = MultiMesh.new()
			_multi_mesh_lod2 = MultiMesh.new()
			_multi_mesh_lod3 = MultiMesh.new()
			_multi_mesh_lod0.transform_format = MultiMesh.TRANSFORM_3D
			_multi_mesh_lod1.transform_format = MultiMesh.TRANSFORM_3D
			_multi_mesh_lod2.transform_format = MultiMesh.TRANSFORM_3D
			_multi_mesh_lod3.transform_format = MultiMesh.TRANSFORM_3D

			_multi_mesh_instance_lod0 = MultiMeshInstance3D.new()
			_multi_mesh_instance_lod1 = MultiMeshInstance3D.new()
			_multi_mesh_instance_lod2 = MultiMeshInstance3D.new()
			_multi_mesh_instance_lod3 = MultiMeshInstance3D.new()
			prints(self.name, "has", ForestData.items_size(),"trees")
			add_child(_multi_mesh_instance_lod0)
			add_child(_multi_mesh_instance_lod1)
			add_child(_multi_mesh_instance_lod2)
			add_child(_multi_mesh_instance_lod3)
func _process(delta):
	if ForestData && flora:
		if Engine.is_editor_hint():
			if Engine.get_frames_drawn() % 2 != 0: # on uneven frames
				load_items_within_radius(EditorInterface.get_editor_viewport_3d().get_camera_3d().position,editor_render_distance)
				#unload_items_outside_radius(EditorInterface.get_editor_viewport_3d().get_camera_3d().position,editor_render_distance)

func _generate():
	print(_preview_mesh.mesh.get_aabb())
	if ForestData:
		ForestData.clear()
	else:
		if flora.size() == 0:
			printerr("Missing Flora. No flora assigned to %s" % self.name )
		ForestData = ForestAreaData.new()
	existing_points.clear()
	if is_inside_tree():
		_update_aabb_preview(true)
		print(_preview_mesh.mesh.get_aabb())
		ForestData = ForestAreaData.new(self.global_transform.origin - _preview_mesh.mesh.get_aabb().size / 2,_size)
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
				var up_direction = Vector3.UP
				var dot_product = result.normal.dot(up_direction)
				var angle_rad = acos(dot_product)
				var angle_deg = rad_to_deg(angle_rad)

				if angle_deg < max_slope:
					var hit = draw_debug_box(result.position,Vector3.ONE * 5,Color(Color.SKY_BLUE,0.95))
					result_positions.append(result.position)
					hit.position = to_local(result.position)
					_temp_meshes.append(hit)
		for pos in result_positions:
			var _basis = Basis().rotated(Vector3.UP,randf())
			var tree_scale = randf_range(1,3)
			var _scale = Vector3(tree_scale,tree_scale,tree_scale)
			_basis = _basis.scaled(_scale)
			var scene_id = randi() % flora.size()
			var instance_transform = Transform3D(_basis,to_local(pos))
			var data = {
				"index": scene_id,
				"scale": _scale,
				"transform": instance_transform,
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

func _update_aabb_preview(force : bool = false):
	prints("shoud show preview:",_show_aabb_preview, "force:",force)
	if _show_aabb_preview or force:
		if ForestData:
			var box = BoxMesh.new()
			box.size = ForestData.aabb.size
			var material = StandardMaterial3D.new()
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color = _aabb_color
			material.flags_unshaded = true
			box.surface_set_material(0, material)
			#_preview_mesh = draw_debug_box(ForestData.aabb.position,ForestData.aabb.size,_aabb_color)
			_preview_mesh.mesh = box
			_preview_mesh.visible = true
		else:
			#_preview_mesh = draw_debug_box(self.position,_size,_aabb_color)
			#_preview_mesh.visible = true
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
	for existing_point in existing_points:
		var distance = random_point.distance_to(existing_point)
		if distance < min_distance_threshold:
			# If too close, generate a new point recursively
			return generate_unique_random_point(aabb, min_distance_threshold)

	# If the point is unique enough, add it to the existing points and return
	existing_points.append(random_point)
	return random_point


func load_items_within_radius(_pos : Vector3,_radius : float = 100.0):
	var query = ForestData.query(_radius, _pos)
	var lod0 = []
	var lod1 = []
	var lod2 = []
	var lod3 = []

	if flora[0].LOD.size() == 1:
		_multi_mesh_lod0.mesh = flora[0].LOD[0]
		_multi_mesh_instance_lod0.multimesh = _multi_mesh_lod0
		_multi_mesh_lod1.mesh = flora[0].LOD[0]
		_multi_mesh_instance_lod1.multimesh = _multi_mesh_lod0
		_multi_mesh_lod2.mesh = flora[0].LOD[0]
		_multi_mesh_instance_lod2.multimesh = _multi_mesh_lod0
		_multi_mesh_lod3.mesh = flora[0].LOD[0]
		_multi_mesh_instance_lod3.multimesh = _multi_mesh_lod0
	elif flora[0].LOD.size() == 2:
		_multi_mesh_lod0.mesh = flora[0].LOD[0]
		_multi_mesh_instance_lod0.multimesh = _multi_mesh_lod0
		_multi_mesh_lod1.mesh = flora[0].LOD[1]
		_multi_mesh_instance_lod1.multimesh = _multi_mesh_lod1
		_multi_mesh_lod2.mesh = flora[0].LOD[1]
		_multi_mesh_instance_lod2.multimesh = _multi_mesh_lod1
		_multi_mesh_lod3.mesh = flora[0].LOD[1]
		_multi_mesh_instance_lod3.multimesh = _multi_mesh_lod1
	elif flora[0].LOD.size() == 3:
		_multi_mesh_lod0.mesh = flora[0].LOD[0]
		_multi_mesh_instance_lod0.multimesh = _multi_mesh_lod0
		_multi_mesh_lod1.mesh = flora[0].LOD[1]
		_multi_mesh_instance_lod1.multimesh = _multi_mesh_lod1
		_multi_mesh_lod2.mesh = flora[0].LOD[2]
		_multi_mesh_instance_lod2.multimesh = _multi_mesh_lod2
		_multi_mesh_lod3.mesh = flora[0].LOD[2]
		_multi_mesh_instance_lod3.multimesh = _multi_mesh_lod2
	elif flora[0].LOD.size() == 4:
		_multi_mesh_lod0.mesh = flora[0].LOD[0]
		_multi_mesh_instance_lod0.multimesh = _multi_mesh_lod0
		_multi_mesh_lod1.mesh = flora[0].LOD[1]
		_multi_mesh_instance_lod1.multimesh = _multi_mesh_lod1
		_multi_mesh_lod2.mesh = flora[0].LOD[2]
		_multi_mesh_instance_lod2.multimesh = _multi_mesh_lod2
		_multi_mesh_lod3.mesh = flora[0].LOD[3]
		_multi_mesh_instance_lod3.multimesh = _multi_mesh_lod3
	else:
		printerr("wrong number of lods")
		return
	var i0 = 0
	var i1 = 0
	var i2 = 0
	var i3 = 0

	for pos in query:
		if _pos.distance_to(pos) < _radius * lod_curve.sample(0.25):
			lod0.append(query[pos].transform)
			i0 += 1
		elif _pos.distance_to(pos) < _radius * lod_curve.sample(0.5):
			lod1.append(query[pos].transform)
			i1 += 1
		elif _pos.distance_to(pos) < _radius * lod_curve.sample(0.75):
			lod2.append(query[pos].transform)
			i2 += 1
		else:
			lod3.append(query[pos].transform)
			i3 =+ 1

	_multi_mesh_lod0.instance_count = lod0.size()
	_multi_mesh_lod1.instance_count = lod1.size()
	_multi_mesh_lod2.instance_count = lod2.size()
	_multi_mesh_lod3.instance_count = lod3.size()
	for i in range(lod0.size()):
		_add_collider(lod0[i])
		_multi_mesh_lod0.set_instance_transform(i,lod0[i])
	for i in range(lod1.size()):
		_multi_mesh_lod1.set_instance_transform(i,lod1[i])
	for i in range(lod2.size()):
		_multi_mesh_lod2.set_instance_transform(i,lod2[i])
	for i in range(lod3.size()):
		_multi_mesh_lod3.set_instance_transform(i,lod3[i])

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

func _add_collider(_transform : Transform3D):
	pass
