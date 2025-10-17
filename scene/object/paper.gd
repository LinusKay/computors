extends Sprite3D

@onready var printer = get_parent().get_parent()
var print_start = false

@onready var animation_player = $AnimationPlayer

var stutter_delay_min: float = 0.01
var stutter_delay_max: float = 0.5
var stutter_duration_min: float = 0.01
var stutter_duration_max: float = 0.3

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "paper_fall": queue_free()
	if anim_name == "paper_print": printer.printing = false
	print_start = false


@warning_ignore("unused_parameter")
func _process(delta: float) -> void:
	if animation_player.is_playing():
		if animation_player.current_animation_position > 3.25:
			$PauseDelayTimer.stop()
			$PauseTimer.stop()
	
# Print stuttering
# When printing starts, kick off a timer with a random duration
# When that timer runs out, start a secondary timer with a random duration
# Stall printing animation until secondary timer expires, then restart first timer
# When animation ends, both timers are stopped
func _on_animation_player_animation_started(anim_name: StringName) -> void:
	if anim_name == "paper_print" and !print_start:
		var timer_time = randf_range(stutter_delay_min, stutter_delay_max)
		print(timer_time)
		print("anim start: pausedelaytimerstart")
		$PauseDelayTimer.start(timer_time)
		print_start = true

func _on_pause_delay_timer_timeout() -> void:
	$AnimationPlayer.pause()
	var timer_time = randf_range(stutter_duration_min, stutter_duration_max)
	print(timer_time)
	$PauseTimer.start(timer_time)

func _on_pause_timer_timeout() -> void:
	$AnimationPlayer.play()
	var timer_time = randf_range(stutter_delay_min, stutter_delay_max)
	print(timer_time)
	$PauseDelayTimer.start(timer_time)
