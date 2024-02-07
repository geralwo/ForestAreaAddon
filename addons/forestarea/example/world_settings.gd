extends Node3D

@onready var forest = $ForestArea
# Called when the node enters the scene tree for the first time.
func _ready():
	# Access the master bus
	var master_bus = AudioServer.get_bus_index("Master")

	# Set the volume (0.5 is 50% volume)
	AudioServer.set_bus_volume_db(master_bus, -30.0)

# Called every frame. 'delta' is the elapsed time since the previous frame.
var s = 0
func _process(delta):
	forest.load_items_within_radius($Player.position)
	forest.unload_items_outside_radius($Player.position)
