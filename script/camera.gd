extends Camera3D

# target arrays
# extensible to new target rails (eg above/below), and new items
@export var focus_array: Array[Node3D]
@export var focus_array_above: Array[Node3D]
@export var pos_pull_back: Node3D
@export var pos_rest: Node3D
@onready var focus_array_selected: Array = focus_array

@export var focus_index: int

@onready var focus_target: Node3D = focus_array_selected[focus_index]
var focus_target_pos: Vector3
var focus_target_fov: float
var fov_offset: float

var current_focus = focus_target

var pulled_back: bool = false
var pullback_fov_offset: float = 10

var target_pos = Vector3.ZERO

# Makes FOV and camera direction changes instant, rather than gradual
var focus_snap: bool = false

const FOV_SMOOTH_RATE: float = 0.1
const CAMERA_SMOOTH_RATE: float = 10
const MOVE_RATE: float = 0.04

var started := false

func _ready() -> void:
	target_pos = pos_rest.global_position

# Reset FOV when alt+tab pressed
func _notification(what: int): 
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: 
		pulled_back = false
		fov_offset = 0

func set_focus_target_index(index: int) -> void:
	if index > focus_array_selected.size() - 1: index = 0
	if index < 0: index = focus_array_selected.size() - 1
	focus_index = index
	_set_focus_target(focus_array_selected[focus_index])
	audio_woosh()


func _set_focus_target(_focus_target: Node3D) -> void:
	focus_target = _focus_target
	var focus_origin = _focus_target.get_node("focus_origin")
	focus_target_pos = focus_origin.global_transform.origin
	focus_target_fov = _focus_target.focus_fov
	
	if _focus_target.has_node("Screen/SubViewportContainer/SubViewport/Control/InterfaceTerminal/TerminalInput/TextEdit"):
		var terminal_input = _focus_target.get_node("Screen/SubViewportContainer/SubViewport/Control/InterfaceTerminal/TerminalInput/TextEdit")
		await get_tree().process_frame
		terminal_input.grab_focus()
		current_focus = terminal_input
	elif _focus_target.has_node("Screen/SubViewportContainer/SubViewport/InterfaceInputCommand/TerminalInput/TextEdit"):
		var terminal_input = _focus_target.get_node("Screen/SubViewportContainer/SubViewport/InterfaceInputCommand/TerminalInput/TextEdit")
		terminal_input.grab_focus()
		current_focus = terminal_input
	else:
		current_focus.release_focus()


func start() -> void:
	_set_focus_target(focus_array[focus_index])
	started = true


# prevent TAB or ESC breaking focus, deselecting terminal input box
func _input(event):
	if event is InputEventKey and event.pressed and (event.keycode == KEY_TAB or event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		return


func _unhandled_input(event: InputEvent) -> void:
	if started:
		if event.is_action_pressed("pull_back"):
			fov_offset = pullback_fov_offset
			target_pos = pos_pull_back.position
			pulled_back = true
			
		if event.is_action_released("pull_back"):
			fov_offset = 0
			target_pos = pos_rest.position
			pulled_back = false
		
		if pulled_back:
			if Input.is_action_just_pressed("focus_right"):
				focus_index += 1
				set_focus_target_index(focus_index)
			if Input.is_action_just_pressed("focus_left"):
				focus_index -= 1
				set_focus_target_index(focus_index)
				
		if focus_target.has_node("Screen/SubViewportContainer/SubViewport"):
			var focus_input = focus_target.get_node("Screen/SubViewportContainer/SubViewport")
			focus_input.push_input(event)
		if focus_target.has_node("Screen/SubViewportContainer/SubViewport"):
			var focus_input = focus_target.get_node("Screen/SubViewportContainer/SubViewport")
			focus_input.push_input(event)


func audio_woosh() -> void:
	$AudioWoosh.pitch_scale = randf_range(0.9, 1.1)
	$AudioWoosh.play()

func _physics_process(delta: float) -> void:
	# Rotate camera to target 
	var to_target = (focus_target_pos - global_transform.origin).normalized()
	var current_rot = global_transform.basis.get_rotation_quaternion()
	var target_basis = Transform3D().looking_at(to_target, Vector3.UP).basis
	var target_rot = target_basis.get_rotation_quaternion()

	if pulled_back:
		var target_euler = target_rot.get_euler()
		var min_yaw = deg_to_rad(70.0)
		var max_yaw = deg_to_rad(110.0)
		target_euler.y = clampf(target_euler.y, min_yaw, max_yaw)
		target_euler.x = clampf(target_euler.x, 0, 10)
		target_rot = Quaternion.from_euler(target_euler)

	var new_rot = current_rot.slerp(target_rot, delta * CAMERA_SMOOTH_RATE)
	
	if global_position != target_pos:
		var move_rate = MOVE_RATE
		if pulled_back:
			move_rate = MOVE_RATE * 1
		global_position = lerp(global_position, target_pos, move_rate)
	
	if focus_snap: 
		global_transform.basis = Basis(target_basis)
		fov = focus_target_fov
	else:
		global_transform.basis = Basis(new_rot)
		fov = clampf(lerp(fov, focus_target_fov + fov_offset, FOV_SMOOTH_RATE), 1, 50)
