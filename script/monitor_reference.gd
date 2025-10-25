extends computer

func new_log(text: String) -> void:
	%Control._new_log(text)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("f_terminal"):
		%InterfaceTerminal.show()
		%InterfaceSoundControl.hide()
		%TerminalInput/TextEdit.grab_focus()
		
	elif event.is_action_pressed("f_sound_control"):
		%InterfaceTerminal.hide()
		%InterfaceSoundControl.show()
		
	elif event.is_action_pressed("f_help") and not %InterfaceSoundControl.visible:
		%Control.call(%Control.commands["help"].func, "")
		%Control.command_history.append("help")
		get_viewport().set_input_as_handled()
