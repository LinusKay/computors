extends computer

@onready var interface_adjust_signal = preload("res://scene/Interface/interface_adjust_signal.tscn")
signal pass_command_eventcontroller(command: String)

@onready var success_label = %InterfaceInputCommand.get_node("%SuccessLabel")
@onready var success_timer = %InterfaceInputCommand.get_node("%SuccessTimer")

func success() -> void:
	success_label.show()
	success_timer.start()
	
	%AudioTypeSounds.pitch_scale = randf_range(0.9,1.1)
	%AudioTypeSounds.play()
	
	#for child in %SubViewport.get_children():
		#child.queue_free()
		#
	#var new_interface = interface_adjust_signal.instantiate()
	#%SubViewport.add_child(new_interface)


func _on_interface_input_command_command_input(command: String) -> void:
	emit_signal("pass_command_eventcontroller", command)
