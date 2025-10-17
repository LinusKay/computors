extends Control

@onready var terminal_log: VBoxContainer = %TerminalLog
@onready var audio_keyboard_sfx: AudioStreamPlayer3D = get_node("/root/Node3D/KeyboardSFX")
@onready var printer: CSGBox3D = get_node("/root/Node3D/Printer")

var current_context: Context
var command_history = []
var command_history_index = 0

const SCROLL_DISTANCE = 75

# https://gist.github.com/awhiskin/b1d752e57f75319029c222bb4c14709a
class Context:
	var user_name := "UUSER"
	var device_name := "MCHN-89"
	var working_directory: Folder
	var root_directory: Folder
	var date := "2025-07-30"

class Folder:
	var folder_path: String
	var parent_directory: Folder
	var subdirectories: Array[Folder] = []
	var child_files: Array[Document] = []
	
	func _init(path, parent) -> void:
		folder_path = path
		parent_directory = parent
	
	func _to_string() -> String:
		return folder_path

class Document:
	var document_name: String
	var parent_directory: Folder
	var content: String
	var size_kb := 10
	
	func _init(name, parent) -> void:
		document_name = name
		parent_directory = parent
	
	func set_content(new_content: String) -> void:
		content = new_content
		size_kb = snapped((float(content.length()) * 8) / 1024, 0.01)
	
	func _to_string() -> String: 
		return document_name
	


var commands = {
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
	"ls": {
		"description": "   List files and directories in the current directory",
		"func": "_cmd_ls",
		"alias": ["list"]
	},
	"cd": {
		"description": "Change the working directory to the target directory",
		"func": "_cmd_cd",
		"args": ["<directory>"]
	},
	"cat": {
		"description": "     Output the contents of a text file",
		"func": "_cmd_cat",
		"args": ["<file>"],
		"alias": ["read", "more"]
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
	},
	"print": {
		"description": "Print the input image file",
		"func": "_cmd_print",
		"args": ["<file>"]
	}
}

func _cmd_print(_args: String) -> bool:
	var input_image = _args.split(" ")[0]
	print(input_image)
	if input_image.length() == 0: 
		_error("NOT_ENOUGH_ARGS")
		return false
		
	var input_image_ext_split = input_image.split(".")
	if input_image_ext_split.size() < 2:
		_error("NOT_AN_IMAGE")
		return false
	var input_image_ext = input_image_ext_split[1]
	if not ["png", "jpg", "bmp"].has(input_image_ext.to_lower()):
		_error("NOT_AN_IMAGE")
		return false
		
	var documents = current_context.working_directory.child_files
	for document in documents:
		if document.to_string().to_lower() == input_image.to_lower():
			if printer.printing:
				_error("PRINT_IN_PROGRESS")
				return false
			else:
				printer.print(load(document.content))
				return true
	_error("FILE_NOT_FOUND")
	return false

func _cmd_ls(_args: String) -> void:
	var folders: Array[Folder] = current_context.working_directory.subdirectories
	var files: Array[Document] = current_context.working_directory.child_files
	for folder in folders:
		_new_log(folder._to_string() + "/")
	for file in files:
		_new_log(file._to_string())

func _cmd_cd(_args: String) -> bool:
	var input_folder = _args.split(" ")[0]
	if input_folder.length() == 0: 
		_error("NOT_ENOUGH_ARGS")
		return false
	if input_folder == ".": return true
	if input_folder == "..":
		if current_context.working_directory.parent_directory != null:
			current_context.working_directory = current_context.working_directory.parent_directory
			return true
		else: return false
	var folders: Array[Folder] = current_context.working_directory.subdirectories
	for folder in folders:
		print(input_folder.to_lower())
		print(folder.to_string().to_lower())
		if folder.to_string().to_lower() == input_folder.to_lower():
			current_context.working_directory = folder
			return true
	
	_error("FOLDER_NOT_FOUND")
	return false
	
func _cmd_cat(_args: String) -> bool:
	var input_document = _args.split(" ")[0]
	if input_document.length() == 0: 
		_error("NOT_ENOUGH_ARGS")
		return false
	print(current_context.working_directory.child_files)
	
	var input_document_ext_split = input_document.split(".")
	if input_document_ext_split.size() == 2:
		var input_document_ext = input_document_ext_split[1]
		if not ["txt", "doc", "pdf"].has(input_document_ext.to_lower()):
			_error("NOT_A_TEXT_FILE")
			return false
	
	var documents = current_context.working_directory.child_files
	for document in documents:
		if document.to_string().to_lower() == input_document.to_lower():
			_new_log(document.content)
			return true
	_error("FILE_NOT_FOUND")
	return false

func _cmd_clear(_args: String) -> void:
	var logs = terminal_log.get_children()
	for log_entry in logs:
		log_entry.queue_free()

func _cmd_help(_args: String) -> void:
	for command in commands.keys():
		if commands[command].has("description"):
			var aliases = ""
			var args = ""
			if commands[command].has("alias"):
				aliases = " (" + ", ".join(commands[command].alias) + ")"
			if commands[command].has("args"):
				args = "".join(commands[command].args)
			_new_log(command + " " + args + "     " + commands[command].description + aliases)


func _cmd_colour(_colour_code: String) -> bool:
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
		return false
	else:
		theme.set_color("font_color", "Label", colour_chosen)
		return true

func _cmd_time(_args: String) -> void:
	var time = Time.get_datetime_string_from_system()
	_new_log(time)

func _error(_error_type: String) -> void:
	var error_types = {
		"GENERIC": "Invalid Operation: Something went wrong!",
		"UNRECOGNISED_OPERATION": "Input not recognised as an internal or external command, operable program or file.",
		"FOLDER_NOT_FOUND": "Cannot find the path specified.",
		"FILE_NOT_FOUND": "Cannot find the path specified.",
		"NOT_ENOUGH_ARGS": "Not enough arguments provided",
		"INTERNAL_ERROR": "An internal error has occured.",
		"NOT_AN_IMAGE": "Given file not an image (JPG, PNG, BMP).",
		"NOT_A_TEXT_FILE": "Given file not a text file (TXT, DOC, MD, PDF).",
		"PRINT_IN_PROGRESS": "A print operation is already in progress."
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
	terminal_log.add_child(new_log)


func _on_text_edit_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("terminal_enter"):
		
		var terminal_pretext = %TerminalInput/Label.text
		
		var input = %TerminalInput/TextEdit.text
		var input_sanitised = input.strip_edges()
		command_history.push_front(input_sanitised)
		command_history_index = -1
		
		var command = input_sanitised.split(" ")[0]
		
		var first_space_index = input_sanitised.find(" ")
		var args = input_sanitised.substr(first_space_index + 1)
		
		_new_log(terminal_pretext + " " + input_sanitised)
		
		%TerminalInput/TextEdit.clear()
		
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
		
		%ScrollContainer.scroll_vertical = %ScrollContainer.get_v_scroll_bar().max_value
		# Prevent newline from being placed in input box by cancelling further handling
		get_viewport().set_input_as_handled()
		update_visual_context()
			
	elif event.is_action_pressed("pgdn"):
		%ScrollContainer.scroll_vertical += SCROLL_DISTANCE
		
	elif event.is_action_pressed("pgup"):
		%ScrollContainer.scroll_vertical -= SCROLL_DISTANCE
	
	elif event.is_action_pressed("ui_up"):
		var history_size = command_history.size()
		if history_size > 0:
			command_history_index += 1
			if command_history_index > history_size - 1:
				command_history_index = history_size - 1
			if command_history_index < 0: 
				command_history_index = 0
			%TerminalInput/TextEdit.text = command_history[command_history_index]
			%TerminalInput/TextEdit.set_caret_column(10)
	elif event.is_action_pressed("ui_down"):
		var history_size = command_history.size()
		if history_size > 0:
			command_history_index -= 1
			if command_history_index < 0: 
				command_history_index = 0
			%TerminalInput/TextEdit.text = command_history[command_history_index]
			%TerminalInput/TextEdit.set_caret_column(10)
	audio_keyboard_sfx.play()
	

func _ready() -> void:
	# Init context and directories
	current_context = Context.new()
	current_context.root_directory = Folder.new("", null)
	current_context.root_directory.subdirectories = [
		Folder.new("Desktop", current_context.root_directory),
		Folder.new("Documents", current_context.root_directory),
	]
	current_context.working_directory = current_context.root_directory
	
	current_context.root_directory.child_files = [
		Document.new("commands.txt", current_context.root_directory),
		Document.new("sheet.png", current_context.root_directory),
		Document.new("sheet2.png", current_context.root_directory),
	]
	#current_context.root_directory.child_files[0].set_content(
		#"┌────────┬──────────────────────────────────────┐\n" +
		#"│ Letter   │ Keyword                                       │\n" +
		#"├────────┼──────────────────────────────────────┤\n" +
		#"│ A        │ MOUNTAIN                                      │\n" +
		#"├────────┼──────────────────────────────────────┤\n" +
		#"│ B        │ WALRUS                                        │\n" +
		#"├────────┼──────────────────────────────────────┤\n" +
		#"│ C        │ WALRUS                                        │\n" +
		#"└────────┴──────────────────────────────────────┘"
	#)
	current_context.root_directory.child_files[0].set_content(
			'"A236D": "MOUNTAIN"\n' +
			'"B38HE": "RIVER"\n' +
			'"C48E2": "MOSQUITO"\n' +
			'"D12H1": "GRIZZLY"\n' +
			'"E01D3": "NETWORK"\n' +
			'"F10BA": "TERMINAL"'
	)
	current_context.root_directory.child_files[1].set_content("res://sprite/sheet.png")
	current_context.root_directory.child_files[2].set_content("res://sprite/LEVELDATASHEETREPORT.png")
	current_context.root_directory.subdirectories[0].child_files = [
		Document.new("message.txt", current_context.root_directory.subdirectories[0])
	]
	update_visual_context()
	
func update_visual_context() -> void:
	%TerminalInput/Label.text = current_context.user_name + "@" + current_context.device_name + ":/" + current_context.working_directory.to_string() + ">"
