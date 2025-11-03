extends Control

@onready var camera: Camera3D = get_node("/root/Node3D/Camera3D")
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
var audio_file: Document = null
var audio_file_name := ""

var controllable = true
var autotyping = false
var autotype_string = ""
var autotype_interval := 0.1
var autotype_submit = true
var autotype_next = [
	]
var autotype_next_delay := 0.5
@onready var autotype_timer = %AutoTypeTimer

func _ready() -> void:
	setup_contexts()
	update_visual_context()

func debug() -> void:
	autotype_next.append(["audio loop", true, 0.1])
	autotype_next.append(["audio play", true, 0.1])
	autotype("audio load ../../../../../../music/terminal.ogg", true, 0.01)
	
func autotype(string: String, submit: bool = false, speed: float = 0.1) -> void:
	controllable = false
	camera.set_focus_target_index(0)
	autotype_string = string
	autotype_interval = speed
	autotype_timer.start(autotype_interval)
	autotype_submit = submit
	
func autotype_load_next() -> void:
	var _autotype_submit = autotype_next[0][1]
	var _autotype_interval = autotype_next[0][2]
	autotype(autotype_next[0][0], _autotype_submit, _autotype_interval)
	autotype_next.pop_front()

func _on_auto_type_timer_timeout() -> void:
	if autotype_string == "":
		autotyping = false
		controllable = true
		autotype_timer.stop()
		if autotype_submit:
			submit_input()
		if autotype_next.size() > 0:
			autotype_load_next()
	else:
		var autotype_key = autotype_string[0]
		autotype_string = autotype_string.substr(1)
		autotype_type(autotype_key)

func autotype_type(text: String) -> void:
	%TextEdit.text += text
	caret_to_end()
	

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
	
	func get_full_path() -> String:
		var path_parts = []
		var parent_step = parent_directory
		while parent_step != null:
			path_parts.append(parent_step.to_string())
			parent_step = parent_step.parent_directory
		var full_path = "/".join(path_parts) + folder_path
		return full_path


class Document:
	var document_name: String
	var parent_directory: Folder
	var content: String
	var size_kb := 10
	var metadata = {}
	
	func _init(name, parent) -> void:
		document_name = name
		parent_directory = parent
	
	func set_content(new_content: String) -> void:
		content = new_content
		size_kb = snapped((float(content.length()) * 8) / 1024, 0.01)
	
	func set_metadata(new_metadata: Dictionary) -> void:
		metadata = new_metadata
	
	func set_metadata_key(key: String, value: String) -> void:
		metadata[key] = value
	
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
		"args": ["-v"],
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
			"     D = Purple        E = Light Yellow   F = White\n" +
			" Eg: colour 71"
			,
		"func": "_cmd_colour",
		"args": ["<foreground colour>[background colour]"],
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
		"args": ["load [file]", "play", "pause", "stop", "unload", "pitch <pitch_value>", "volume <-80 - 0>", "loop [true|false]"],
		"alias": ["sound"]
	},
	"run": {
		"description": "Start an instance of the input executable file.",
		"func": "_cmd_run",
		"args": ["<file>"],
		"alias": ["start", "execute", "exe"]
	},
	"support": {
		"description": "Retrieve your support token",
		"func": "_cmd_support"
	}
}


func _find_folder_from_path(path: String) -> Folder:
	var path_split = path.strip_edges().split("/")
	var working_directory_temp = current_context.working_directory
	
	# allow passing index # for current working directory
	if path.is_valid_int():
		if working_directory_temp.subdirectories.size() == 0: 
			return null
		var folder_index = int(path)
		return working_directory_temp.subdirectories[folder_index]
		
	if path_split.size() > 0 and path_split[0] != "":
		var dir_match = false
		for step in path_split.size():
			var directories = working_directory_temp.subdirectories
			if path_split[step] != "":
				if path_split[step] == "..":
					if working_directory_temp.parent_directory != null:
						working_directory_temp = working_directory_temp.parent_directory
					dir_match = true
				elif path_split[step] == ".":
					dir_match = true
				else:
					for directory in directories:
						if directory.to_string() == path_split[step].to_lower():
							working_directory_temp = directory
							dir_match = true
							break
						else:
							dir_match = false
		if !dir_match:
			return null
	return working_directory_temp
	
	
func _find_file_from_path(path: String) -> Document:
	var file_directory = current_context.working_directory
	var files = file_directory.child_files
	
	# allow passing index # for current working directory
	if path.is_valid_int():
		if files.size() == 0: 
			return null
		var file_index = int(path)
		return files[file_index]
	var path_split = path.split("/")
	var path_file = path_split[-1]
	if path_split.size() > 1:
		path_split.remove_at(path_split.size() - 1)
		var path_directory = "/".join(path_split)
		var file_folder = _find_folder_from_path(path_directory)
		if file_folder != null: file_directory = file_folder
		
	files = file_directory.child_files	
	for file in files:
		if file.to_string().to_lower() == path_file:
			return file

	return null


func _check_file_type(file: Document, extensions: Array[String] = [], error_code: String = "GENERIC") -> bool:
	var file_ext_split = file.to_string().split(".")
	if file_ext_split.size() < 2:
		_error(error_code)
		return false
	var file_ext = file_ext_split[1]
	if not extensions.has(file_ext.to_lower()):
		_error(error_code)
		return false
	return true


func _cmd_support(_args: String) -> void:
	_new_log("               #")
	_new_log("             #####")
	_new_log("           #########")
	_new_log("       Machine ID: 3354")
	_new_log("     Support Token: 197831")
	_new_log("Support Hotline: +XX X 7XXX 9XXX")
	_new_log("==================================")


func _cmd_help(_args: String) -> void:
	var args_split = _args.split(" ")
	if args_split.size() > 0 && args_split[0] != "":
		var command = args_split[0]
		var command_match = null
		if commands.has(command): command_match = commands[command]
		else:
			for key in commands.keys():
				if commands[key].has("alias"):
					if commands[key]["alias"].has(command):
						command_match = commands[key]
						break
		
		if command_match == null: _error("UNRECOGNISED_OPERATION")
		if command_match.has("description"):
			var aliases = ""
			var args = ""
			if command_match.has("alias"):
				aliases = ", ".join(command_match.alias)
			if command_match.has("args"):
				if command_match["args"].size() == 1:
					args = command_match.args[0]
					_new_log(command + " " + args + "     " + command_match.description + "\n     Alias: " + aliases)
				else:
					args = "\n     - " + "\n     - ".join(command_match.args)
					_new_log(command + "     " + command_match.description + args + "\n     Alias: " + aliases)
			else:
				_new_log(command + "     " + command_match.description + "\n     Alias: " + aliases)
	else:
		for command in commands.keys():
			if commands[command].has("description"):
				var aliases = ""
				var args = ""
				if commands[command].has("alias"):
					aliases = ", ".join(commands[command].alias)
				if commands[command].has("args"):
					if commands[command]["args"].size() == 1:
						args = commands[command].args[0]
						_new_log(command + " " + args + "     " + commands[command].description + "\n     Alias: " + aliases)
					else:
						args = "\n     - " + "\n     - ".join(commands[command].args)
						_new_log(command + "     " + commands[command].description + args + "\n     Alias: " + aliases)
				else:
					_new_log(command + "     " + commands[command].description + "\n     Alias: " + aliases)


func _cmd_run(_args: String) -> bool:
	var input_file = _args.split(" ")[0]
	if input_file.length() == 0: 
		_error("NOT_ENOUGH_ARGS", [1])
		return false
		
	var exe_file = _find_file_from_path(_args)
	if exe_file == null:
		_error("FILE_NOT_FOUND")
		return false
	
	if _check_file_type(exe_file, ["exe", "sh", "bat", "app"], "NOT_AN_EXECUTABLE_FILE") == false:
		return false
		
	print("Running ", exe_file.to_string(), ". Process: ", exe_file.content)
	return true


func _cmd_audio(_args: String) -> bool:
	var _args_split = _args.strip_edges().to_lower().split(" ")
	if _args_split.size() > 0 and _args_split[0] != "":
		var operation = _args_split[0]
		if operation == "load":
			if _args_split.size() < 2:
				_error("FILE_NOT_SPECIFIED")
				return false
			var file_name = _args_split[1]
			var audio_load_file = _find_file_from_path(file_name)
			if audio_load_file == null:
				_error("FILE_NOT_FOUND")
				return false	
				
			if _check_file_type(audio_load_file, ["wav", "mp3", "ogg"], "NOT_AN_AUDIO_FILE") == false:
				return false
				
			#audio_file = load(audio_load_file.content)
			audio_file = audio_load_file
			audio_file_name = file_name
			speaker.load_audio(load(audio_load_file.content))
			speaker.audio_metadata = audio_load_file.metadata
			audio_loaded = true
			%InterfaceSoundControl.add_recently_played(
				[
					audio_file.parent_directory.get_full_path() + "/" + audio_file.document_name, 
					audio_load_file.content, 
					audio_load_file.metadata,
					speaker.get_audio_length()
				]
			)
			%InterfaceSoundControl.update_screen_playback_tracker()
			_new_log("Loaded audio file " + audio_load_file.document_name + " into memory.")
			return true
			
		elif operation == "play":
			if !audio_loaded:
				_error("NO_AUDIO_LOADED")
				return false
			if audio_file == null:
				_error("NO_AUDIO_LOADED")
				return false
			speaker.play()
			if speaker.loop:
				_new_log("Playing audio (Loop enabled)")
			else:
				_new_log("Playing audio (Loop disabled)")
			var playback_tracker = speaker.get_playback_tracker_detailed()
			_new_log(playback_tracker)
			return true
			
		elif operation == "pause":
			if !audio_loaded:
				_error("NO_AUDIO_LOADED")
				return false
			if audio_file == null:
				_error("NO_AUDIO_LOADED")
				return false
			_new_log("Pausing audio.")
			var playback_tracker = speaker.get_playback_tracker_detailed()
			_new_log(playback_tracker)
			speaker.pause()
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
			_new_log("Unloading audio file " + audio_file.document_name + " from memory.")
			speaker.stop()
			audio_file = null
			audio_file_name = ""
			audio_loaded = false
			return true
			
		elif operation == "pitch":
			if _args_split.size() < 2:
				_error("NOT_ENOUGH_ARGS", [2])
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
				_error("NOT_ENOUGH_ARGS", [2])
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
			
		elif operation == "loop":
			if _args_split.size() > 1 and _args_split[0] != "":
				if _args_split[1] == "true":
					speaker.loop = true
					_new_log("Audio loop enabled")
					return true
				elif _args_split[1] == "false":
					speaker.loop = false
					_new_log("Audio loop disabled")
					return true
				else:
					_error("UNRECOGNISED_OPERATION")
					return false
			else:
				if speaker.loop: 
					speaker.loop = false
					_new_log("Audio loop disabled")
					return true
				else:
					speaker.loop = true
					_new_log("Audio loop enabled")
					return true
				
		else:
			_error("UNRECOGNISED_OPERATION")
			return false
	_error("NOT_ENOUGH_ARGS", [">1"])
	return false


func _cmd_drives(_args: String) -> bool:
	var _args_split = _args.strip_edges().to_lower().split(" ")

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
				_error("NOT_ENOUGH_ARGS", [">1"])
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

	_drives_list()
	return true

func _drives_list() -> void:
	_new_log("Network drives available", true)
	var drive_string = ""
	for drive in drives:
		drive_string += drive.drive_name + ", "
	drive_string = drive_string.substr(0, drive_string.length() - 2)
	_new_log(drive_string)


func _cmd_print(_args: String) -> bool:
	var input_image = _args.split(" ")[0]
	if input_image.length() == 0: 
		_error("NOT_ENOUGH_ARGS", [1])
		return false
		
	var print_file = _find_file_from_path(_args)
	if print_file == null:
		_error("FILE_NOT_FOUND")
		return false
	
	if _check_file_type(print_file, ["png", "jpg", "bmp"], "NOT_AN_IMAGE_FILE") == false:
		return false
		
	if printer.printing:
		_error("PRINT_IN_PROGRESS")
		return false
	else:
		printer.print(load(print_file.content))
		return true


func _cmd_ls(_args: String) -> bool:
	var verbose := false
	
	var args = _args
	if args.ends_with("-v"): 
		print("ends with -v")
		verbose = true
		args = args.left(args.length() - 2)
		print("args ", args)
	
	var ls_directory = _find_folder_from_path(args)
	
	if ls_directory == null:
		_error("FOLDER_NOT_FOUND")
		return false
		
	var folders: Array[Folder] = ls_directory.subdirectories
	var files: Array[Document] = ls_directory.child_files
	if folders.size() == 0 and files.size() == 0:
		_new_log("No files present in " + current_context.working_directory.folder_path)
		return true
	
	if verbose:
		_new_log("Index  Name", true)
		for folder_index in folders.size():
			_new_log(str(folder_index) + "      " + folders[folder_index].to_string() + "/")
		for file_index in files.size():
			_new_log(str(file_index) + "      " + files[file_index].to_string())
	else:
		for folder in folders:
			_new_log(folder.to_string() + "/")
		for file in files:
			_new_log(file.to_string())
	return true


func _cmd_cd(_args: String) -> bool:
	var input_folder = _args.split(" ")[0]
	if input_folder.length() == 0: 
		_error("NOT_ENOUGH_ARGS", [1])
		return false 
		
	var cd_directory = _find_folder_from_path(_args)
	
	if cd_directory == null:
		_error("FOLDER_NOT_FOUND")
		return false
	
	current_context.working_directory = cd_directory
	return true
	
	
func _cmd_cat(_args: String) -> bool:
	var input_document = _args.split(" ")[0]
	
	if input_document.length() == 0: 
		_error("NOT_ENOUGH_ARGS", [1])
		return false
		
	var cat_file = _find_file_from_path(_args)
	if cat_file == null:
		_error("FILE_NOT_FOUND")
		return false
		
	if _check_file_type(cat_file, ["txt", "doc", "pdf"], "NOT_A_TEXT_FILE") == false:
		return false
	
	_new_log(cat_file.content)
	return true
	

func _cmd_clear(_args: String) -> void:
	var logs = terminal_log.get_children()
	for log_entry in logs:
		log_entry.queue_free()
		

func _cmd_colour(_colour_code: String) -> bool:
	var colour_split = _colour_code.to_lower().split("")
	
	if colour_split.size() > 2:
		_error("TOO_MANY_ARGS", [2])
		return false
	
	# foregroud colour
	if colour_split.size() == 1:
		var input_foreground_colour = colour_split[0]
		var chosen_foreground_colour: Color = _id_to_colour(input_foreground_colour)
		if chosen_foreground_colour == Color(0.0, 0.0, 0.0, 1.0):
			_error("UNRECOGNISED_OPERATION")
			_new_log("Colour code <" + input_foreground_colour + "> not found!")
			return false
		elif chosen_foreground_colour == %ColorRect.color:
			_error("FOREGROUND_BACKGROUND_COLOUR_SAME")
			return false
		else:
			theme.set_color("font_color", "Label", chosen_foreground_colour)
		
	# background colour
	elif colour_split.size() == 2:
		var input_foreground_colour = colour_split[0]
		var chosen_foreground_colour: Color = _id_to_colour(input_foreground_colour)
		
		var input_background_colour = colour_split[1]
		var chosen_background_colour: Color = _id_to_colour(input_background_colour)
		
		if chosen_foreground_colour == chosen_background_colour:
			_error("FOREGROUND_BACKGROUND_COLOUR_SAME")
			return false
		
		if chosen_foreground_colour == Color(0.0, 0.0, 0.0, 1.0):
			_error("UNRECOGNISED_OPERATION")
			_new_log("Colour code <" + input_foreground_colour + "> not found!")
			return false
		else:
			theme.set_color("font_color", "Label", chosen_foreground_colour)
		
		if chosen_background_colour == Color(0.0, 0.0, 0.0, 1.0):
			_error("UNRECOGNISED_OPERATION")
			_new_log("Colour code <" + input_background_colour + "> not found!")
			return false
		else:
			%ColorRect.color = chosen_background_colour
	return true

func _id_to_colour(_colour_id: String) -> Color:
	var colour_match: Color
	var colours = {
		"1": Color.DARK_BLUE,
		"2": Color.DARK_GREEN,
		"3": Color8(6, 152, 154, 255),
		"4": Color.DARK_RED,
		"5": Color.WEB_PURPLE,
		"6": Color.YELLOW,
		"7": Color.ANTIQUE_WHITE,
		"8": Color.GRAY,
		"9": Color8(52, 101, 164, 255),
		"a": Color.LIGHT_GREEN,
		"b": Color.PALE_TURQUOISE,
		"c": Color.LIGHT_CORAL,
		"d": Color.PURPLE,
		"e": Color.LIGHT_YELLOW,
		"f": Color.WHITE
	}
	if colours.keys().has(_colour_id):
		colour_match = colours[_colour_id]
		
	return colour_match


func _cmd_time(_args: String) -> void:
	var time = Time.get_datetime_string_from_system()
	_new_log(time)


func _error(_error_type: String, _args: Array = [""]) -> void:
	var error_types = {
		"GENERIC": "Invalid Operation: Something went wrong!",
		"UNRECOGNISED_OPERATION": "Input not recognised as an internal or external command, operable program or file.",
		"FOLDER_NOT_FOUND": "Cannot find the path specified.",
		"FILE_NOT_FOUND": "Cannot find the path specified.",
		"NOT_ENOUGH_ARGS": "Not enough arguments provided. Expected " + str(_args[0]) + ".",
		"TOO_MANY_ARGS": "Too many arguments provided. Expected " + str(_args[0]) + ".",
		"INTERNAL_ERROR": "An internal error has occured.",
		"NOT_AN_IMAGE_FILE": "Given file not an image (JPG, PNG, BMP).",
		"NOT_A_TEXT_FILE": "Given file not a text file (TXT, DOC, MD, PDF).",
		"NOT_AN_AUDIO_FILE": "Given file not an audio file (WAV, MP3, OGG).",
		"NOT_AN_EXECUTABLE_FILE": "Given file not an executable file (EXE).",
		"PRINT_IN_PROGRESS": "A print operation is already in progress.",
		"DRIVE_NOT_FOUND": "Cannot find the drive specified.",
		"DRIVE_NOT_CONNECTED": "Not currently connected to any drive.",
		"LOGIN_NOT_GIVEN": "Drive protected, please supply login.",
		"LOGIN_NOT_AUTHORISED": "Drive protected, given login unauthorised.",
		"FILE_NOT_SPECIFIED": "No file has been specified.",
		"NO_AUDIO_LOADED": "No audio file has been loaded into memory.",
		"VALUE_NOT_NUMERIC": "Input value is not numeric.",
		"VALUE_OUT_OF_BOUNDS": "Input value is out of allowed bounds.",
		"FOREGROUND_BACKGROUND_COLOUR_SAME": "Foreground and background colours cannot be identical."
	}
	if error_types.has(_error_type): _new_log(error_types[_error_type])
	else: _new_log(error_types[_error_type])


func _new_log(log_text: String, underline: bool = false) -> void:
	var new_log = Label.new()
	if underline:
		var new_stylebox = StyleBoxFlat.new()
		new_stylebox.border_width_bottom = 1
		new_stylebox.bg_color = Color.TRANSPARENT
		new_log.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		new_log.add_theme_stylebox_override("normal", new_stylebox)
	new_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	new_log.custom_minimum_size = Vector2(640, 0)
	log_text = log_text.replace(" ", "\u00A0")
	new_log.text = log_text
	terminal_log.add_child(new_log)
	%AudioMessage.play()


func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("debug"):
		debug()

func _on_text_edit_gui_input(event: InputEvent) -> bool:
	if not Input.is_action_pressed("pull_back"):
		audio_keyboard_sfx.play()
	if %InterfaceTerminal.visible:
		if not controllable:
			get_viewport().set_input_as_handled()
			return false
		else:
			if Input.is_action_pressed("ctrl_left") && Input.is_key_pressed(KEY_C):
				var terminal_pretext = %TerminalInput/Label.text
				var input = %TerminalInput/TextEdit.text
				var input_sanitised = input.strip_edges()
				_new_log(terminal_pretext + " " + input_sanitised)
				%TerminalInput/TextEdit.clear()
				return true
			elif event.is_action_pressed("terminal_enter"):
				return submit_input()
					
			elif event.is_action_pressed("pgdn"):
				%ScrollContainer.scroll_vertical += SCROLL_DISTANCE
				return true
				
			elif event.is_action_pressed("pgup"):
				%ScrollContainer.scroll_vertical -= SCROLL_DISTANCE
				return true
			
			elif event.is_action_pressed("ui_up"):
				var history_size = command_history.size()
				if history_size > 0:
					command_history_index += 1
					if command_history_index > history_size - 1:
						command_history_index = history_size - 1
					if command_history_index < 0: 
						command_history_index = 0
					%TerminalInput/TextEdit.text = command_history[command_history_index]
					get_viewport().set_input_as_handled()
					caret_to_end()
					return true
			elif event.is_action_pressed("ui_down"):
				var history_size = command_history.size()
				if history_size > 0:
					command_history_index -= 1
					if command_history_index < 0: 
						command_history_index = 0
					%TerminalInput/TextEdit.text = command_history[command_history_index]
					get_viewport().set_input_as_handled()
					caret_to_end()
					return true
	return true
	

func submit_input() -> bool:
	var terminal_pretext = %TerminalInput/Label.text
	var input = %TerminalInput/TextEdit.text
	var input_sanitised = input.strip_edges()
	if input_sanitised == "":
		_new_log(terminal_pretext)
		return true
	
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
	var command_func = null
	if commands.has(command): 
		if commands[command].has("func"):
			command_func = commands[command].func
		else:
			_error("INTERNAL_ERROR")
			return false
	else:
		for key in commands.keys():
			if commands[key].has("alias"):
				if commands[key]["alias"].has(command):
					command_func = commands[key].func
					break
	if command_func == null: 
		_error("UNRECOGNISED_OPERATION")
		return false
	var args_split = args.split(" ")
	if args_split.size() > 0 and ["-h", "help", "?", "/?"].has(args_split[0]):
		call(commands["help"].func, command)
	else:
		call(command_func, args)
	
	# Prevent newline from being placed in input box by cancelling further handling
	get_viewport().set_input_as_handled()
	update_visual_context()
	return true

func setup_contexts() -> void:
	# Init context and directories
	context_home = Context.new()
	context_home.root_directory = Folder.new("", null)

	# Dir setup: / -> Subdirs
	context_home.root_directory.subdirectories = [
		Folder.new("desktop", context_home.root_directory),
		Folder.new("documents", context_home.root_directory),
		Folder.new("music", context_home.root_directory)
	]
	
	# Dir setup: / -> Files
	context_home.root_directory.child_files = [
		Document.new("app.exe", context_home.root_directory),
		Document.new("woah.png", context_home.root_directory)
	]
	# Dir setup: / -> Files -> Content
	context_home.root_directory.child_files[0].set_content(
		"App EXE contents"
	)
	context_home.root_directory.child_files[1].set_content(
		"res://sprite/yuck.png"
	)

	# Dir setup: /desktop/ -> Files
	context_home.root_directory.subdirectories[0].child_files = [
		Document.new("creds.txt", context_home.root_directory.subdirectories[0])
	]
	
	# Dir setup: /desktop/ -> Files -> Content
	context_home.root_directory.subdirectories[0].child_files[0].set_content(
		"DO NOT SHARE OR UPLOAD\n" +
		"Login credentials: jason:pass"
	)
	
	# Dir setup: /desktop/ -> Subdirs
	context_home.root_directory.subdirectories[0].subdirectories = [
		Folder.new("folder", context_home.root_directory.subdirectories[0])
	]
	# Dir setup /desktop/folder -> Files
	context_home.root_directory.subdirectories[0].subdirectories[0].child_files = [
		Document.new("folderfile.txt", context_home.root_directory.subdirectories[0]),
		Document.new("1.png", context_home.root_directory.subdirectories[0])
	]
	context_home.root_directory.subdirectories[0].subdirectories[0].child_files[0].set_content(
		"This is a test file"
	)
	context_home.root_directory.subdirectories[0].subdirectories[0].child_files[1].set_content(
		"res://sprite/LEVELDATASHEETREPORT.png"
	)
	
	# Files: /music/
	context_home.root_directory.subdirectories[2].child_files = [
		Document.new("terminal.ogg", context_home.root_directory.subdirectories[2]),
		Document.new("whwh.ogg", context_home.root_directory.subdirectories[2]),
		Document.new("dominionofthefist.mp3", context_home.root_directory.subdirectories[2]),
		Document.new("td3.mp3", context_home.root_directory.subdirectories[2]),
		
	]
	# Files: /music/ -> Contents
	context_home.root_directory.subdirectories[2].child_files[0].set_content("res://audio/music/terminal.ogg")
	context_home.root_directory.subdirectories[2].child_files[0].set_metadata_key("artist", "EraDaze")
	context_home.root_directory.subdirectories[2].child_files[0].set_metadata_key("title", "Terminal")
	context_home.root_directory.subdirectories[2].child_files[0].set_metadata_key("year", "2009")
	context_home.root_directory.subdirectories[2].child_files[1].set_content("res://audio/music/whwhwhwhwhwh.ogg")
	context_home.root_directory.subdirectories[2].child_files[1].set_metadata_key("artist", "keltroniks")
	context_home.root_directory.subdirectories[2].child_files[1].set_metadata_key("title", "pressure")
	context_home.root_directory.subdirectories[2].child_files[1].set_metadata_key("year", "2008")
	context_home.root_directory.subdirectories[2].child_files[2].set_content("res://audio/music/dominionofthefist.mp3")
	context_home.root_directory.subdirectories[2].child_files[2].set_metadata_key("artist", "Alfonso Surman")
	context_home.root_directory.subdirectories[2].child_files[2].set_metadata_key("title", "Le Monde du Poing")
	context_home.root_directory.subdirectories[2].child_files[2].set_metadata_key("year", "2006")
	context_home.root_directory.subdirectories[2].child_files[3].set_content("res://audio/music/td3improv.mp3")
	context_home.root_directory.subdirectories[2].child_files[3].set_metadata_key("artist", "d")
	context_home.root_directory.subdirectories[2].child_files[3].set_metadata_key("title", "t")
	context_home.root_directory.subdirectories[2].child_files[3].set_metadata_key("year", "2003")
	
	# Set active context
	context_home.working_directory = context_home.root_directory
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
	%TerminalInput/Label.text = current_context.user_name + "@" + current_context.device_name + drive_name + ":/" + current_context.working_directory.get_full_path() + ">"


func _on_text_edit_focus_entered() -> void:
	caret_to_end()

func caret_to_end() -> void:
	%TextEdit.caret_column = %TextEdit.text.length()
pass # Replace with function body.
