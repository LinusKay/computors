extends computer

signal pass_command_eventcontroller(command: String)

func _on_control_command_input(command: String) -> void:
	emit_signal("pass_command_eventcontroller", command)

func success() -> void:
	%SuccessLabel.show()
	%SuccessTimer.start()

func _on_success_timer_timeout() -> void:
	%SuccessLabel.hide()
