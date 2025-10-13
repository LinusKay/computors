extends Control

@onready var terminal_log: VBoxContainer = $ScrollContainer/TerminalLog
@onready var audio_keyboard_sfx: AudioStreamPlayer3D = get_node("/root/Node3D/KeyboardSFX")

var command_history = []

const SCROLL_DISTANCE = 75

# https://gist.github.com/awhiskin/b1d752e57f75319029c222bb4c14709a

var commands = {
	"chatroom": {
		"description": "chatroom help"
	},
	"help": {
		"description": " Provides help information for commands",
		"func": "_cmd_help",
		"alias": ["h"]
	},
	"clear": {
		"description": "Clear the terminal",
		"func": "_cmd_clear",
		"alias": ["cls"]
	},
	"time": {
		"description": " Print the system time",
		"func": "_cmd_time",
		"alias": ["date"]
	},
	"colour": {
		"description": 
			" Set the terminal colour\n" + 
			"     1 = Blue          2 = Green          3 = Aqua\n" + 
			"     4 = Red           5 = Web Purple     6 = Yellow\n" + 
			"     7 = Antique White 8 = Grey           9 = Light Blue\n" + 
			"     A = Light Green   B = Pale Turqouise C = Light Coral\n" + 
			"     D = Purple        E = Light Yellow   F = White"
			,
		"func": "_cmd_colour",
		"args": ["<code>"],
		"alias": ["color"]
	}
}


func _cmd_clear(_args: String):
	var logs = terminal_log.get_children()
	for log_entry in logs:
		log_entry.queue_free()

func _cmd_help(_args: String):
	for command in commands.keys():
		if commands[command].has("description"):
			var aliases = ""
			var args = ""
			if commands[command].has("alias"):
				aliases = " (" + ", ".join(commands[command].alias) + ")"
			if commands[command].has("args"):
				args = "".join(commands[command].args)
			_new_log(command + " " + args + "     " + commands[command].description + aliases)


func _cmd_colour(_colour_code: String):
	var error: bool
	var colour_chosen: Color
	match _colour_code.to_lower():
		"1": colour_chosen = Color.DARK_BLUE
		"2": colour_chosen = Color.DARK_GREEN
		"3": colour_chosen = Color.AQUA
		"4": colour_chosen = Color.DARK_RED
		"5": colour_chosen = Color.WEB_PURPLE
		"6": colour_chosen = Color.YELLOW
		"7": colour_chosen = Color.ANTIQUE_WHITE
		"8": colour_chosen = Color.GRAY
		"9": colour_chosen = Color.LIGHT_BLUE
		"a": colour_chosen = Color.LIGHT_GREEN
		"b": colour_chosen = Color.PALE_TURQUOISE
		"c": colour_chosen = Color.LIGHT_CORAL
		"d": colour_chosen = Color.PURPLE
		"e": colour_chosen = Color.LIGHT_YELLOW
		"f": colour_chosen = Color.WHITE
		_:   
			colour_chosen = Color.WHITE
			error = true
	
	if error:
		_error("UNRECOGNISED_OPERATION")
		_new_log("Colour code <" + _colour_code + "> not found!")
	else:
		theme.set_color("font_color", "Label", colour_chosen)

func _cmd_time(_args: String):
	var time = Time.get_datetime_string_from_system()
	_new_log(time)

func _error(_error_type: String) -> void:
	var error_types = {
		"GENERIC": "Invalid Operation: Something went wrong!",
		"UNRECOGNISED_OPERATION": "Input not recognised as an internal or external command, operable program or file.",
		"FOLDER_NOT_FOUND": "Cannot find the path specified.",
		"FILE_NOT_FOUND": "Cannot find the path specified.",
		"NOT_ENOUGH_ARGS": "Not enough arguments provided.",
		"INTERNAL_ERROR": "An internal error has occured."
	}
	if error_types.has(_error_type): _new_log(error_types[_error_type])
	else: _new_log(error_types[_error_type])


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
		
		var command = input_sanitised.split(" ")[0]
		
		var first_space_index = input_sanitised.find(" ")
		var args = input_sanitised.substr(first_space_index + 1)
		
		_new_log(terminal_pretext + " " + input_sanitised)
		
		$TerminalInput/TextEdit.clear()
		
		if commands.has(command): 
			if commands[command].has("func"):
				call(commands[command].func, args)
			else:
				_error("INTERNAL_ERROR")
		else:
			var match_found = false
			for key in commands.keys():
				if commands[key].has("alias"):
					if commands[key]["alias"].has(command):
						call(commands[key].func, args)
						match_found = true
						break
			if !match_found: _error("UNRECOGNISED_OPERATION")
		print($ScrollContainer.get_v_scroll_bar().max_value)
		$ScrollContainer.scroll_vertical = $ScrollContainer.get_v_scroll_bar().max_value
		# Prevent newline from being placed in input box by cancelling further handling
		get_viewport().set_input_as_handled()

			
	elif event.is_action_pressed("pgdn"):
		$ScrollContainer.scroll_vertical += SCROLL_DISTANCE
		
	elif event.is_action_pressed("pgup"):
		$ScrollContainer.scroll_vertical -= SCROLL_DISTANCE
	get_node("/root/Node3D/KeyboardSFX").play()
	#audio_keyboard_sfx.play()
	

func _ready() -> void:
	pass
