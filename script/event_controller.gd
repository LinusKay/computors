extends Node3D

@export var camera: Camera3D
@export var monitor_reference: Node3D
@export var monitor_input: Node3D
@export var monitor_receive: Node3D

@onready var message_label = monitor_receive.get_node("Screen/SubViewportContainer/SubViewport/Control/MessageLabel")

var message_options = {
	"A236D": "MOUNTAIN",
	"B38HE": "RIVER",
	"C48E2": "MOSQUITO",
	"D12H1": "GRIZZLY",
	"E01D3": "NETWORK",
	"F10BA": "TERMINAL"
}

var message = "A236D"
var required_response = "ANSWER"


func _ready() -> void:	
	message_label.text = message
	message_label.show()
	new_message()
	display_message()

func _on_monitor_input_pass_command_eventcontroller(command: String) -> void:
	print("input " + command + " received at controller")
	if command == required_response:
		print("input accepted!")
		new_message()
		display_message()
		monitor_input.success()

func display_message() -> void:
	monitor_receive.show_message(message)

func new_message() -> void:
	message = message_options.keys().pick_random()
	required_response = message_options[message]
	
