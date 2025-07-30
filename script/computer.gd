extends Node3D

@export var focus_fov: float = 75
@export var origin_offset: Vector3 = Vector3(0, 0, 0)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$focus_origin.position += origin_offset
