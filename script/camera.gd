extends Camera3D

# target arrays
# extensible to new target rails (eg above/below), and new items
@export var focus_array: Array[Node3D]
@export var focus_array_above: Array[Node3D]
@onready var focus_array_selected: Array = focus_array

@export var focus_index: int:
	set(new_target):
		if new_target > focus_array_selected.size() - 1: new_target = 0
		if new_target < 0: new_target = focus_array_selected.size() - 1
		focus_index = new_target
		_set_focus_target(focus_array_selected[focus_index])

@onready var focus_target: Node3D = focus_array_selected[focus_index]
var focus_target_pos: Vector3
var focus_target_fov: float
var fov_offset: float

var pulled_back: bool = false
var pullback_fov_offset: float = 20

const FOV_SMOOTH_RATE: float = .3
const CAMERA_SMOOTH_RATE: float = 10.0

func _set_focus_target(_focus_target: Node3D) -> void:
	focus_target = _focus_target
	focus_target_pos = _focus_target.get_node("focus_origin").global_transform.origin
	focus_target_fov = _focus_target.focus_fov
	
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
		if Input.is_action_pressed("focus_left"):
			focus_index -= 1
			
	focus_target.get_node("Screen/SubViewportContainer/SubViewport").push_input(event)


func _physics_process(delta: float) -> void:
	# Rotate camera to target 
	var to_target = (focus_target_pos - global_transform.origin).normalized()
	var current_rot = global_transform.basis.get_rotation_quaternion()
	var target_basis = Transform3D().looking_at(to_target, Vector3.UP).basis
	var target_rot = target_basis.get_rotation_quaternion()
	var new_rot = current_rot.slerp(target_rot, delta * CAMERA_SMOOTH_RATE)
	global_transform.basis = Basis(new_rot)
	
	fov = lerp(fov, focus_target_fov + fov_offset, FOV_SMOOTH_RATE)
