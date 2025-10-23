extends Control

@export var skip_menu = false
@export var audio_keyboard_sfx: AudioStreamPlayer3D

func _ready() -> void:
	%LineEdit.grab_focus()
	if skip_menu:
		get_parent().get_node("FadeRect").fade_in()
		get_parent().get_node("Camera3D").start()
		queue_free()


func _on_line_edit_text_submitted(new_text: String) -> void:
	var text_sanitised := new_text.to_lower().strip_edges()
	if text_sanitised == "start":
		get_parent().get_node("FadeRect").fade_in()
		get_parent().get_node("Camera3D").start()
		queue_free()
	if text_sanitised == "settings":
		hide()
	if text_sanitised == "quit":
		get_tree().quit()
	


func _on_line_edit_text_changed(new_text: String) -> void:
	audio_keyboard_sfx.play()
	var text_sanitised := new_text.to_lower().strip_edges()
	if text_sanitised == "start":
		%LabelStart.selected()
		%LabelQuit.deselected()
		#%LabelEnter.show()
	elif text_sanitised == "quit":
		%LabelStart.deselected()
		%LabelQuit.selected()
		#%LabelEnter.show()
	else:
		%LabelStart.deselected()
		%LabelQuit.deselected()
		#%LabelEnter.hide()
		
