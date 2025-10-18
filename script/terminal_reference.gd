extends Control

@onready var terminal_log: VBoxContainer = %TerminalLog
@onready var audio_keyboard_sfx: AudioStreamPlayer3D = get_node("/root/Node3D/KeyboardSFX")
@onready var printer: CSGBox3D = get_node("/root/Node3D/Printer")
@onready var speaker: CSGBox3D = get_node("/root/Node3D/Speaker")

var command_history = []
var command_history_index = 0

var current_context: Context
var context_home: Context
var context_drive_storage: Context

const SCROLL_DISTANCE = 75

var drives := []
var drive_connected = false

var audio_loaded := false
var audio_file: AudioStream = null
var audio_file_name := ""

# https://gist.github.com/awhiskin/b1d752e57f75319029c222bb4c14709a
class Context:
	var user_name := "USER"
	var device_name := "MCHN-89"
	var drive_name := ""
	var working_directory: Folder
	var root_directory: Folder
	var date := "2025-07-30"
	var password := ""

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
		"alias": ["list", "dir"]
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
	},
	"drives": {
		"description": "\n     View a list of shared drives to connect to.",
		"func": "_cmd_drives",
		"args": ["connect <drive_name> [username:password]", "disconnect", "list"],
		"alias": ["shares", "drive", "drives", "drv", "shr", "//"]
	},
	"audio": {
		"description": "\n     Control audio playback\n     Volume in dB from -80 to 0.",
		"func": "_cmd_audio",
		"args": ["load [file]", "play", "pause", "stop", "unload", "pitch <pitch_value>", "volume <-80 - 0>"],
		"alias": ["sound"]
	}
}


func _cmd_audio(_args: String) -> bool:
	var _args_split = _args.strip_edges().to_lower().split(" ")
	if _args_split.size() > 0 and _args_split[0] != "":
		var operation = _args_split[0]
		if operation == "load":
			if _args_split.size() < 2:
				_error("FILE_NOT_SPECIFIED")
				return false
			var file_name = _args_split[1]
			var files = current_context.working_directory.child_files
			for file in files:
				if file.to_string().to_lower() == file_name:
					var file_name_split = file_name.split(".")
					if file_name_split.size() == 0:
						_error("NOT_AN_AUDIO_FILE")
						return false
					var file_ext = file_name_split[1]
					if not ["wav", "ogg", "mp3"].has(file_ext):
						_error("NOT_AN_AUDIO_FILE")
						return false
					audio_file = load(file.content)
					audio_file_name = file_name
					speaker.load_audio(audio_file)
					audio_loaded = true
					_new_log("Loaded audio file " + audio_file_name + "into memory.")
					return true
			_error("FILE_NOT_FOUND")
			return false	
			
		elif operation == "play":
			if !audio_loaded:
				_error("NO_AUDIO_LOADED")
				return false
			if audio_file == null:
				_error("NO_AUDIO_LOADED")
				return false
			speaker.play()
			_new_log("Playing audio")
			return true
			
		elif operation == "pause":
			if !audio_loaded:
				_error("NO_AUDIO_LOADED")
				return false
			if audio_file == null:
				_error("NO_AUDIO_LOADED")
				return false
			speaker.pause()
			_new_log("Pausing audio.")
			return true
			
		elif operation == "stop":
			if !audio_loaded:
				_error("NO_AUDIO_LOADED")
				return false
			if audio_file == null:
				_error("NO_AUDIO_LOADED")
				return false
			speaker.stop()
			_new_log("Stopping audio.")
			return true
			
		elif operation == "unload":
			if !audio_loaded:
				_error("NO_AUDIO_LOADED")
				return false
			if audio_file == null:
				_error("NO_AUDIO_LOADED")
				return false
			_new_log("Unloading audio file " + audio_file_name + " from memory.")
			speaker.stop()
			audio_file = null
			audio_file_name = ""
			audio_loaded = false
			return true
			
		elif operation == "pitch":
			if _args_split.size() < 2:
				_error("NOT_ENOUGH_ARGS")
				return false
			var pitch_value = _args_split[1]
			if !pitch_value.is_valid_float():
				if pitch_value == "reset":
					pitch_value = 1
				else:
					_error("VALUE_NOT_NUMERIC")
					return false
			speaker.pitch(float(pitch_value))
			_new_log("Set audio pitch value to " + str(pitch_value))
			return true
			
		elif operation == "volume":
			if _args_split.size() < 2:
				_error("NOT_ENOUGH_ARGS")
				return false
			var volume_value = _args_split[1]
			if !volume_value.is_valid_float():
				if volume_value == "reset":
					volume_value = 1
				else:
					_error("VALUE_NOT_NUMERIC")
					return false
			volume_value = float(volume_value)
			if volume_value > 0 or volume_value < -80:
				_error("VALUE_OUT_OF_BOUNDS")
				return false
				
			speaker.volume(volume_value)
			_new_log("Set audio volume value to " + str(volume_value))
			return true
		else:
			_error("UNRECOGNISED_OPERATION")
			return false
	_error("NOT_ENOUGH_ARGS")
	return false


func _cmd_drives(_args: String) -> bool:
	var _args_split = _args.strip_edges().to_lower().split(" ")
	# feat. janky handling for when no args provided
	if _args_split.size() > 0 and _args_split[0] != "":
		var operation = _args_split[0]
		if operation == "connect" or operation == "+":
			# Check if drive name given
			if _args_split.size() > 1:
				var drive_name = _args_split[1]
				# Check if drive exists, else fail
				for drive in drives:
					if drive.drive_name.to_lower() == drive_name:
						if drive.password != "":
							if _args_split.size() <= 2:
								_error("LOGIN_NOT_GIVEN")
								return false
							else: 
								if _args_split[2] != drive.password:
									_error("LOGIN_NOT_AUTHORISED")
									return false
						_new_log("Connected to drive " + drive_name.to_upper() + " successfully")
						current_context = drive
						drive_connected = true
						update_visual_context()
						return true
				_error("DRIVE_NOT_FOUND")
				return false
			else: 
				_error("NOT_ENOUGH_ARGS")
				return false
		elif operation == "disconnect" or operation == "-" or operation == "exit" or operation == "quit":
			if drive_connected == false:
				_error("DRIVE_NOT_CONNECTED")
				return false
			drive_connected = false
			_new_log("Disconnected from drive " + current_context.drive_name + " successfully")
			current_context = context_home
			update_visual_context()
			return true
		elif operation == "list" or operation == "?":
			_drives_list()
			return true
		else:
			_error("UNRECOGNISED_OPERATION")
			return false
	# If no operation given, print drives
	_drives_list()
	return true

func _drives_list() -> void:
	var drive_string = ""
	for drive in drives:
		drive_string += drive.drive_name + ", "
	drive_string = drive_string.substr(0, drive_string.length() - 2)
	_new_log(drive_string)


func _cmd_print(_args: String) -> bool:
	var input_image = _args.split(" ")[0]
	if input_image.length() == 0: 
		_error("NOT_ENOUGH_ARGS")
		return false
		
	var input_image_ext_split = input_image.split(".")
	if input_image_ext_split.size() < 2:
		_error("NOT_AN_IMAGE_FILE")
		return false
	var input_image_ext = input_image_ext_split[1]
	if not ["png", "jpg", "bmp"].has(input_image_ext.to_lower()):
		_error("NOT_AN_IMAGE_FILE")
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
				if commands[command]["args"].size() == 1:
					args = commands[command].args[0]
					_new_log(command + " " + args + "     " + commands[command].description + aliases)
				else:
					args = "\n     - " + "\n     - ".join(commands[command].args)
					_new_log(command + "     " + commands[command].description + args + aliases)
			else:
				_new_log(command + "     " + commands[command].description + aliases)


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
		"NOT_AN_IMAGE_FILE": "Given file not an image (JPG, PNG, BMP).",
		"NOT_A_TEXT_FILE": "Given file not a text file (TXT, DOC, MD, PDF).",
		"NOT_AN_AUDIO_FILE": "Given file not an audio file (WAV, MP3, OGG).",
		"PRINT_IN_PROGRESS": "A print operation is already in progress.",
		"DRIVE_NOT_FOUND": "Cannot find the drive specified.",
		"DRIVE_NOT_CONNECTED": "Not currently connected to any drive.",
		"LOGIN_NOT_GIVEN": "Drive protected, please supply login.",
		"LOGIN_NOT_AUTHORISED": "Drive protected, given login unauthorised.",
		"FILE_NOT_SPECIFIED": "No file has been specified.",
		"NO_AUDIO_LOADED": "No audio file has been loaded into memory.",
		"VALUE_NOT_NUMERIC": "Input value is not numeric.",
		"VALUE_OUT_OF_BOUNDS": "Input value is out of allowed bounds."
	}
	if error_types.has(_error_type): _new_log(error_types[_error_type])
	else: _new_log(error_types[_error_type])


func _new_log(log_text: String) -> void:
	var new_log = Label.new()
	new_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	new_log.custom_minimum_size = Vector2(640, 0)
	log_text = log_text.replace(" ", "\u00A0")
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
		var args
		if first_space_index == -1:
			args = ""
		else: args = input_sanitised.substr(first_space_index + 1)
		
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
	setup_contexts()
	update_visual_context()

func setup_contexts() -> void:
	# Init context and directories
	context_home = Context.new()
	context_home.root_directory = Folder.new("", null)
	context_home.root_directory.subdirectories = [
		Folder.new("Desktop", context_home.root_directory),
		Folder.new("Documents", context_home.root_directory),
	]
	context_home.working_directory = context_home.root_directory
	
	context_home.root_directory.child_files = [
		Document.new("sheet.png", context_home.root_directory),
		Document.new("sheet2.png", context_home.root_directory),
		Document.new("print_stall1.ogg", context_home.root_directory)
	]
	context_home.root_directory.child_files[0].set_content("res://sprite/sheet.png")
	context_home.root_directory.child_files[1].set_content("res://sprite/LEVELDATASHEETREPORT.png")
	context_home.root_directory.child_files[2].set_content("res://audio/sfx/printer/print_mid.ogg")
	context_home.root_directory.subdirectories[0].child_files = [
		Document.new("creds.txt", context_home.root_directory.subdirectories[0])
	]
	context_home.root_directory.subdirectories[0].child_files[0].set_content(
		"DO NOT SHARE OR UPLOAD\n" +
		"Login credentials: jason:pass"
	)
	current_context = context_home
	
	# DRIVE CONTEXT SETUP
	context_drive_storage = Context.new()
	context_drive_storage.drive_name = "STORAGE"
	context_drive_storage.user_name = "jason"
	context_drive_storage.password = "jason:pass"
	context_drive_storage.root_directory = Folder.new("", null)
	context_drive_storage.root_directory.subdirectories = [
		Folder.new("docs", context_drive_storage.root_directory),
	]
	context_drive_storage.working_directory = context_drive_storage.root_directory

	context_drive_storage.root_directory.child_files = [
		Document.new("keywords.txt", context_drive_storage.root_directory)
	]
	context_drive_storage.root_directory.child_files[0].set_content(
		'INPUT terminal requires specific values corresponding to MONITOR screen:\n' +
		'"A236D": "MOUNTAIN"\n' +
		'"B38HE": "RIVER"\n' +
		'"C48E2": "MOSQUITO"\n' +
		'"D12H1": "GRIZZLY"\n' +
		'"E01D3": "NETWORK"\n' +
		'"F10BA": "TERMINAL"'
	)
	drives.append(context_drive_storage)
	
func update_visual_context() -> void:
	var drive_name = ""
	if current_context.drive_name != "":
		drive_name = ":" + current_context.drive_name
	%TerminalInput/Label.text = current_context.user_name + "@" + current_context.device_name + drive_name + ":/" + current_context.working_directory.to_string() + ">"
