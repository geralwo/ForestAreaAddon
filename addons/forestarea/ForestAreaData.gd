@tool
class_name ForestAreaData
extends Resource

@export var aabb : AABB
@export var dimensions : Vector3
@export var location : Vector3
@export var items : Dictionary = {}
@export var children : Array = []
var max_items: int = 16

func _init(_location = null, _dimensions = null) -> void:
	if _location:
		location = _location
	if _dimensions:
		dimensions = _dimensions
	if location && dimensions:
		aabb = AABB(location - dimensions / 2,dimensions)

func size() -> int:
	var count = 1 # Counting the current node
	for child in children:
		count += child.size()
	return count

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
	var child_half_dim = aabb.size / 2

	for i in range(8):
		var offset = Vector3((i & 1) * child_half_dim.x, ((i >> 1) & 1) * child_half_dim.y, ((i >> 2) & 1) * child_half_dim.z)
		var child_position = aabb.position + offset
		children.append(ForestAreaData.new(child_position, child_half_dim))

func query(radius: float, position: Vector3) -> Dictionary:
#	prints("Querying Node with Boundary:", boundary)
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

func visualize_node(proxy_node : Node):
	var node = MeshInstance3D.new()
	# Create sphere with low detail of size.
	var box_mesh = BoxMesh.new()
	box_mesh.size = aabb.size
	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(randf(),randf(),randf(),0.1)
	material.flags_unshaded = true

	box_mesh.surface_set_material(0, material)
	# Add to meshinstance in the right place.
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.mesh = box_mesh
	node.add_to_group("octree_debug_visuals")
	proxy_node.add_child(node)
	node.position = aabb.get_center()
	for child in children:
		child.visualize_node(proxy_node)
