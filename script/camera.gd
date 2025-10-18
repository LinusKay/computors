extends Camera3D

# target arrays
# extensible to new target rails (eg above/below), and new items
@export var focus_array: Array[Node3D]
@export var focus_array_above: Array[Node3D]
@onready var focus_array_selected: Array = focus_array

@export var focus_index: int

@onready var focus_target: Node3D = focus_array_selected[focus_index]
var focus_target_pos: Vector3
var focus_target_fov: float
var fov_offset: float

var pulled_back: bool = false
var pullback_fov_offset: float = 20

var focus_snap: bool = false

const FOV_SMOOTH_RATE: float = .3
const CAMERA_SMOOTH_RATE: float = 10

func _set_focus_target(_focus_target: Node3D) -> void:
	focus_target = _focus_target
	
	focus_target_pos = _focus_target.get_node("focus_origin").global_transform.origin
	focus_target_fov = _focus_target.focus_fov
	
	if _focus_target.has_node("Screen/SubViewportContainer/SubViewport/Control/TerminalInput/TextEdit"):
		var terminal_input = _focus_target.get_node("Screen/SubViewportContainer/SubViewport/Control/TerminalInput/TextEdit")
		terminal_input.grab_focus()


func _ready() -> void:
	await get_tree().process_frame
	_set_focus_target(focus_array[focus_index])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pull_back"):
		fov_offset = pullback_fov_offset
		pulled_back = true
		
	if event.is_action_released("pull_back"):
		fov_offset = 0
		pulled_back = false
	
	if pulled_back:
		if Input.is_action_pressed("focus_right"):
			focus_index += 1
			if focus_index > focus_array_selected.size() - 1: focus_index = 0
			if focus_index < 0: focus_index = focus_array_selected.size() - 1
			_set_focus_target(focus_array_selected[focus_index])
		if Input.is_action_pressed("focus_left"):
			focus_index -= 1
			if focus_index > focus_array_selected.size() - 1: focus_index = 0
			if focus_index < 0: focus_index = focus_array_selected.size() - 1
			_set_focus_target(focus_array_selected[focus_index])
			
	if focus_target.has_node("Screen/SubViewportContainer/SubViewport"):
		var focus_input = focus_target.get_node("Screen/SubViewportContainer/SubViewport")
		focus_input.push_input(event)


func _physics_process(delta: float) -> void:
	# Rotate camera to target 
	var to_target = (focus_target_pos - global_transform.origin).normalized()
	var current_rot = global_transform.basis.get_rotation_quaternion()
	var target_basis = Transform3D().looking_at(to_target, Vector3.UP).basis
	var target_rot = target_basis.get_rotation_quaternion()
	var new_rot = current_rot.slerp(target_rot, delta * CAMERA_SMOOTH_RATE)
	
	if focus_snap: 
		global_transform.basis = Basis(target_basis)
		fov = focus_target_fov
	else:
		global_transform.basis = Basis(new_rot)
		fov = lerp(fov, focus_target_fov + fov_offset, FOV_SMOOTH_RATE)
	
	
