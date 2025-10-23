extends Label

const WAVE_CHANGE_RATE := 0.05

var wave_changing := false
var target_transparency := 0.5
var curr_transparency := target_transparency
var target_wave_height := 0.0
var curr_wave_height := target_wave_height

func selected() -> void:
	target_transparency = 1.0
	target_wave_height = 2.0
	
func deselected() -> void:
	target_transparency = 0.5
	target_wave_height = 0.0

@warning_ignore("unused_parameter")
func _process(delta: float) -> void:
	curr_transparency = lerp(curr_transparency, target_transparency, WAVE_CHANGE_RATE)
	curr_wave_height = lerp(curr_wave_height, target_wave_height, WAVE_CHANGE_RATE)
	add_theme_color_override("font_color", Color(255,255,255,curr_transparency))
	material.set("shader_parameter/height", curr_wave_height)
