extends Control

@onready var terminal_log: VBoxContainer = $ScrollContainer/TerminalLog

var current_context: Context
var command_history = []

# https://gist.github.com/awhiskin/b1d752e57f75319029c222bb4c14709a
class Context:
	var user_name := "USER"
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
	var  document_name: String
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
	
#colour <code>
	  #1 = Blue  2 = Green  3 = Aqua
	  #4 = Red   5 = Purple 6 = Yellow
	  #7 = white 8 = Grey   9 = Light Blue

var commands = {
	"help": {
		"description": "
			help      Provides help information for commands
		",
		"func": "_cmd_help"
	},
	"clear": {
		"description": "Clear the screen",
		"func": "_cmd_clear"
	},
	"cls": {
		"alias": "clear"
	},
	"ls": {
		"description": "Shows a list of files and folders in the current location",
		"func": "_cmd_ls"
	},
	"cd": {
		"description": "Change the working directory to the target directory",
		"func": "_cmd_cd"
	}
}

func _cmd_ls(_args: String):
	var folders: Array[Folder] = current_context.working_directory.subdirectories
	var files: Array[Document] = current_context.working_directory.child_files
	for folder in folders:
		_new_log(folder._to_string())
	for file in files:
		_new_log(file._to_string())

func _cmd_cd(_args: String):
	var folders: Array[Folder] = current_context.working_directory.subdirectories
	print(folders)
	#current_context.working_directory = 

func _cmd_clear(_args: String):
	var logs = terminal_log.get_children()
	for log in logs:
		log.queue_free()

func _cmd_help(_args: String):
	_new_log(commands["help"].description)


func _cmd_colour(_colour_code: String):
	var error: bool
	var colour_chosen: Color
	match _colour_code:
		"1": colour_chosen = Color.DARK_BLUE
		"2": colour_chosen = Color.DARK_GREEN
		"3": colour_chosen = Color.AQUA
		"4": colour_chosen = Color.DARK_RED
		"5": colour_chosen = Color.PURPLE
		"6": colour_chosen = Color.YELLOW
		"7": colour_chosen = Color.WHITE
		"8": colour_chosen = Color.GRAY
		"9": colour_chosen = Color.LIGHT_BLUE
		_:   
			colour_chosen = Color.WHITE
			error = true
	if error:
		_error("UNRECOGNISED_OPERATION")
		_new_log("Colour code <" + _colour_code + "not found!")
	else:
		theme.set_color("font_color", "Label", colour_chosen)


func _error(_error_type: String) -> void:
	var error_types = {
		"GENERIC": "Invalid Operation: Something went wrong!",
		"UNRECOGNISED_OPERATION": "Input not recognised as an internal or external command, operable program or file."
	}
	if error_types.has(_error_type): _new_log(error_types[_error_type])
	else: _new_log(error_types[_error_type])


func _new_log(log_text: String) -> void:
	var new_log = Label.new()
	new_log.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	new_log.custom_minimum_size = Vector2(640, 0)
	
	var log_text_lines: Array = log_text.split("\n")
	for line in log_text_lines:
		new_log.text += line
		
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
			if commands[command].has("alias"):
				var aliased_command = commands[command].alias
				print(aliased_command)
				call(commands[aliased_command].func, args)
			else: 
				call(commands[command].func, args)
		else:
			_error("UNRECOGNISED_OPERATION")


func _ready() -> void:
	# Init context and directories
	current_context = Context.new()
	current_context.root_directory = Folder.new("", null)
	current_context.root_directory.subdirectories = [
		Folder.new("Desktop", current_context.root_directory),
		Folder.new("Documents", current_context.root_directory),
		Folder.new("Downloads", current_context.root_directory),
		Folder.new("Music", current_context.root_directory)
	]
	current_context.working_directory = current_context.root_directory
	
	current_context.root_directory.child_files = [
		Document.new("readme.txt", current_context.root_directory),
		Document.new("dontread.txt", current_context.root_directory),
		Document.new("passwords.txt", current_context.root_directory)
	]
	current_context.root_directory.child_files[0].set_content("Wawawaawa WELCOME to README dot TEXT\nTHIS is an IMPORTANT text file.\n\nVERY important- - - - - - - | | | | |\n\nThe End")
	current_context.root_directory.child_files[1].set_content("private :(")
	current_context.root_directory.child_files[2].set_content("hunter23")
	current_context.root_directory.subdirectories[0].child_files = [
		Document.new("message.txt", current_context.root_directory.subdirectories[0])
	]
	current_context.root_directory.subdirectories[0].child_files[0].set_content("take me tro your leader")
	print(current_context.root_directory.child_files)
