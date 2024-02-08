@tool
class_name ForestAreaData
extends Resource

@export var aabb : AABB
@export var items : Dictionary = {}
@export var children : Array = []
var max_items: int = 64

func _init(_position = null, _size = null) -> void:
	if _position && _size:
		aabb = AABB()
		aabb.position = _position
		aabb.size = _size

func size() -> int:
	# total count of nodes
	var count = 1 # Counting the current node
	for child in children:
		count += child.size()
	return count

func items_size() -> int:
	var count = items.size()

	for child in children:
		count += child.items_size()

	return count

func clear():
	items.clear()
	children.clear()

func insert(item_position: Vector3, data: Dictionary) -> bool:
	# dont insert if item position is not inside aabb
	if not aabb.has_point(item_position):
		return false
	# insert into node if items size is smaller than max items and this node has no children
	if items.size() < max_items and children.size() == 0:
		items[item_position] = data
		return true
	# if all of the above is false subdivide this node and place children into sub node
	if children.size() == 0:
		subdivide()

	for child in children:
		if child.insert(item_position, data):
			return true
	return false


func subdivide() -> void:
	var child_half_dim = aabb.size / 4  # Use aabb.size / 4 instead of aabb.size / 2

	for i in range(8):
		var offset = Vector3(
			(i & 1) * child_half_dim.x * 2 - child_half_dim.x,
			((i >> 1) & 1) * child_half_dim.y * 2 - child_half_dim.y,
			((i >> 2) & 1) * child_half_dim.z * 2 - child_half_dim.z
		)

		var child_position = aabb.position + offset + child_half_dim
		children.append(ForestAreaData.new(child_position, child_half_dim * 2))





func query(radius: float, position: Vector3) -> Dictionary:
	var items_within_radius = {}
	if not intersects_sphere(position, radius):
		return items_within_radius

	for item_position in items.keys():
		if item_position.distance_to(position) <= radius:
			items_within_radius[item_position] = items[item_position]

	for child in children:
		var child_results = child.query(radius, position)
		for key in child_results.keys():
			items_within_radius[key] = child_results[key]

	return items_within_radius

func is_in_bounds(aabb : AABB) -> bool:
	if not aabb.encloses(aabb):
		return false
	return true

func intersects_sphere(center: Vector3, radius: float) -> bool:
	var squared_distance = 0.0
	var extents = aabb.position + aabb.size

	for i in range(3):
		if center[i] < aabb.position[i]:
			squared_distance += pow(center[i] - aabb.position[i], 2)
		elif center[i] > extents[i]:
			squared_distance += pow(center[i] - extents[i], 2)

	return squared_distance <= pow(radius, 2)

static func visualize(data: ForestAreaData) -> Node3D:
	return visualize_node(data.aabb, data.children)

static func visualize_node(aabb: AABB, children: Array) -> Node3D:
	var all = Node3D.new()
	for i in range(1,8):
		var minst = MeshInstance3D.new()
		minst.top_level = true
		minst.global_transform.origin = aabb.get_endpoint(i)
		var mesh = BoxMesh.new()
		mesh.size = Vector3(10,i,10)

		var material = StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color.BROWN
		material.flags_unshaded = true
		mesh.surface_set_material(0, material)

		minst.mesh = mesh
		all.add_child(minst)
	var node = MeshInstance3D.new()
	node.add_to_group("_octree_visualize")
	node.position = aabb.get_center()

	var box_mesh = BoxMesh.new()
	box_mesh.size = aabb.size

	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(randf(), randf(), randf(), 0.25)
	material.flags_unshaded = true

	box_mesh.surface_set_material(0, material)

	node.mesh = box_mesh
	all.add_child(node)

	for child in children:
		var childNode = visualize_node(child.aabb, child.children)
		all.add_child(childNode)

	return all
