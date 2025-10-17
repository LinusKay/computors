extends CSGBox3D

@onready var paper = preload("res://scene/object/paper.tscn")

@export var focus_fov: float = 75
@export var origin_offset: Vector3 = Vector3(0, 0, 0)

@export var printing: bool = false

func _ready() -> void:
	$focus_origin.position = $focus_origin.position + origin_offset

func print(image: Resource) -> void:
	printing = true
	var printouts = $printouts.get_children()
	if printouts.size() > 0:
		var paper_animationplayer = printouts[0].get_node("AnimationPlayer")
		paper_animationplayer.play("paper_fall")
	var new_printout = paper.instantiate()
	$printouts.add_child(new_printout)
	new_printout.texture = image
	var new_printout_animationplayer = new_printout.get_node("AnimationPlayer")
	new_printout_animationplayer.play("paper_print")
