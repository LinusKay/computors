extends Node3D

@export var camera: Camera3D
@export var monitor_reference: Node3D
@export var monitor_input: Node3D
@export var monitor_receive: Node3D

@onready var message_label = monitor_receive.get_node("Screen/SubViewportContainer/SubViewport/Control/MessageLabel")

var message_text = "A236D"
var required_response = "ANSWER"

func _ready() -> void:	
	message_label.text = message_text
	message_label.show()

func _on_monitor_input_pass_command_eventcontroller(command: String) -> void:
	print("command " + command + " received at controller")
	if command == required_response:
		message_label.hide()
