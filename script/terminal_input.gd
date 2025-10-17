extends Control

@onready var terminal_log: VBoxContainer = $ScrollContainer/TerminalLog
@onready var audio_keyboard_sfx: AudioStreamPlayer3D = get_node("/root/Node3D/KeyboardSFX")
var current_context: Context
var command_history = []

signal command_input(command: String)

const SCROLL_DISTANCE = 75

# https://gist.github.com/awhiskin/b1d752e57f75319029c222bb4c14709a
class Context:
	var user_name := ""
	var device_name := ""
	var date := "2025-07-30"
	

func _new_log(log_text: String) -> void:
	var new_log = Label.new()
	new_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	new_log.custom_minimum_size = Vector2(640, 0)
	log_text = log_text.replace(" ", "\u00A0")
	print(log_text)
	new_log.text = log_text
	#var log_text_lines: Array = log_text.split("\n")
	#for line in log_text_lines:
		#print(line)
		#new_log.text += line
		
	terminal_log.add_child(new_log)


func _on_text_edit_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("terminal_enter"):
		var terminal_pretext = $TerminalInput/Label.text
		
		var input = $TerminalInput/TextEdit.text
		var input_sanitised = input.strip_edges()
		
		#var command = input_sanitised.split(" ")[0]
		#
		#var first_space_index = input_sanitised.find(" ")
		#var args = input_sanitised.substr(first_space_index + 1)
		
		_new_log(terminal_pretext + " " + input_sanitised)
		
		$TerminalInput/TextEdit.clear()
		$ScrollContainer.scroll_vertical = $ScrollContainer.get_v_scroll_bar().max_value
		
		# Prevent newline from being placed in input box by cancelling further handling
		get_viewport().set_input_as_handled()
		update_visual_context()
		
		emit_signal("command_input", input_sanitised)
			
	elif event.is_action_pressed("pgdn"):
		$ScrollContainer.scroll_vertical += SCROLL_DISTANCE
		
	elif event.is_action_pressed("pgup"):
		$ScrollContainer.scroll_vertical -= SCROLL_DISTANCE
	
	if audio_keyboard_sfx != null:
		audio_keyboard_sfx.play()
	

func _ready() -> void:
	current_context = Context.new()
	update_visual_context()
	
func update_visual_context() -> void:
	$TerminalInput/Label.text = current_context.user_name + "@" + current_context.device_name + ">"
