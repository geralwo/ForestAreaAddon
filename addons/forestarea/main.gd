@tool
extends Node3D
class_name ForestArea

@export var generate : bool = false :
	set(_v):
		_generate()
		if _show_aabb_preview:
			_update_preview()
@export var tree_count : int = 7
@export var _size : Vector3 = Vector3(100,100,100):
	set(v):
		_size = v
		if _show_aabb_preview:
			_update_preview()
@export var trees_meshlib : MeshLibrary
@export var ForestData : ForestAreaData
@export_category("Debug")
@export var _view_query_data : bool = false
@export var _show_aabb_preview : bool = false :
	set(v):
		_show_aabb_preview = v
		if v:
			_update_preview()
		else:
			remove_child(_preview_mesh)
@export var _aabb_color : Color = Color(Color.WEB_GREEN,0.3)
var _temp_meshes : Array[MeshInstance3D]
var _tree_meshes : Array[MeshInstance3D]
var _preview_mesh : MeshInstance3D

func _ready():
	if ForestData:
		var query = ForestData.query(100000.0,Vector3.ZERO)
		for pos in query:
			var mesh = trees_meshlib.get_item_mesh(query[pos].id)
			var generation_instance = MeshInstance3D.new()
			generation_instance.mesh = mesh
			generation_instance.scale = query[pos].scale
			generation_instance.position = to_local(pos)
			add_child(generation_instance)
func _generate():
	if is_inside_tree():
		ForestData = ForestAreaData.new(self.position,_size)
		if not trees_meshlib:
			printerr(self.name," - No MeshLibrary set. Please assign a MeshLibrary")
			return
		print("::: generating Forest")
		var result_positions = []
		# Clear existing trees
		for m in _temp_meshes:
			if m:
				m.queue_free()
		for m in _tree_meshes:
			if m:
				m.queue_free()
		_temp_meshes.clear()
		_tree_meshes.clear()

		var space_state = get_world_3d().direct_space_state

		for i in range(tree_count):
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

			if result:
				var hit = draw_debug_box(result.position,Vector3.ONE * 5,Color(Color.YELLOW,0.95))
				result_positions.append(result.position)
				hit.position = to_local(result.position)
				_temp_meshes.append(hit)

		for pos in result_positions:
			var tree_scale = randf_range(1,3)
			var _scale = Vector3(tree_scale,tree_scale,tree_scale)
			var meshlib_id = randi() % trees_meshlib.get_item_list().size()
			var mesh = trees_meshlib.get_item_mesh(meshlib_id)
			var generation_instance = MeshInstance3D.new()
			generation_instance.mesh = mesh
			generation_instance.scale = _scale
			generation_instance.position = to_local(pos)
			_tree_meshes.append(generation_instance)
			var data = {
				"id": meshlib_id,
				"scale": _scale,
			}
			prints("adding",pos,data)
			print(to_local(pos))
			ForestData.insert(pos, data)

		if _view_query_data:
			for m in _temp_meshes:
				add_child(m)

		for m in _tree_meshes:
			add_child(m)


func _load_forest():
	pass

func _update_preview():
	if _preview_mesh:
		remove_child(_preview_mesh)
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

func _exit_tree():
	for m in _temp_meshes:
		m.queue_free()
	for m in _tree_meshes:
		m.queue_free()
