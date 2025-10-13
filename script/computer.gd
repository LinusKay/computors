extends Node3D

@export var focus_fov: float = 75
@export var origin_offset: Vector3 = Vector3(0, 0, 0)
@export_enum("reference", "input", "monitor", "chatroom") var computer_type: String

@onready var script_terminal_reference = load("res://script/terminal_reference.gd")
@onready var script_terminal_chatroom = load("res://script/terminal_chatroom.gd")
#@onready var script_terminal_input = preload("res://script/terminal_input.gd")
#@onready var script_terminal_monitor = preload("res://script/terminal_monitor.gd")
@onready var computer_control = get_node("Screen/SubViewportContainer/SubViewport/Control")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$focus_origin.position += origin_offset
	var script = script_terminal_reference
	if computer_type == "reference": script = script_terminal_reference
	elif computer_type == "input":   script = script_terminal_reference
	elif computer_type == "monitor": script = script_terminal_reference
	elif computer_type == "chatroom": script = script_terminal_chatroom
	computer_control.set_script(script)
