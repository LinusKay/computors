extends Sprite3D

@onready var printer = get_parent().get_parent()
@onready var sfx_print_start = preload("res://audio/sfx/printer/print_start.ogg")
@onready var sfx_print_mid = preload("res://audio/sfx/printer/print_mid.ogg")
@onready var sfx_print_stall = [
	preload("res://audio/sfx/printer/print_stall1.ogg"),
	preload("res://audio/sfx/printer/print_stall2.ogg"),
	preload("res://audio/sfx/printer/print_stall3.ogg"),
	preload("res://audio/sfx/printer/print_stall4.ogg"),
]
@onready var sfx_print_stop = preload("res://audio/sfx/printer/print_stop.ogg")

var print_start = false

@onready var animation_player = $AnimationPlayer

var stutter_delay_min: float = 1
var stutter_delay_max: float = 3
var stutter_duration_min: float = 0.01
var stutter_duration_max: float = 0.3

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "paper_fall": queue_free()
	if anim_name == "paper_print": 
		printer.printing = false
		$PrintAudio.stream = sfx_print_stop
		$PrintAudio.play()
	print_start = false


#@warning_ignore("unused_parameter")
#func _process(delta: float) -> void:
	#if animation_player.is_playing():
		#if animation_player.current_animation_position > 3.25:
			##$PauseDelayTimer.stop()
			##$PauseTimer.stop()
			#$PrintAudio.stream = sfx_print_stop
			#$PrintAudio.play()
	
# Print stuttering
# When printing starts, kick off a timer with a random duration
# When that timer runs out, start a secondary timer with a random duration
# Stall printing animation until secondary timer expires, then restart first timer
# When animation ends, both timers are stopped
func _on_animation_player_animation_started(anim_name: StringName) -> void:
	if anim_name == "paper_print" and !print_start:
		#var timer_time = randf_range(stutter_delay_min, stutter_delay_max)
		#$PauseDelayTimer.start(timer_time)
		print_start = true
		$PrintAudio.stream = sfx_print_start
		$PrintAudio.play()

#func _on_pause_delay_timer_timeout() -> void:
	#$AnimationPlayer.pause()
	#$PrintAudio.stream = sfx_print_stall.pick_random()
	#$PrintAudio.play()
	#var timer_time = randf_range(stutter_duration_min, stutter_duration_max)
	#$PauseTimer.start($PrintAudio.stream.get_length())
#
#func _on_pause_timer_timeout() -> void:
	#$AnimationPlayer.play()
	#$PrintAudio.stream = sfx_print_mid
	#var play_point = randf_range(0, sfx_print_mid.get_length())
	#$PrintAudio.play(play_point)
	#var timer_time = randf_range(stutter_delay_min, stutter_delay_max)
	#$PauseDelayTimer.start(timer_time)


func _on_print_audio_finished() -> void:
	print("audio finished")
	if $PrintAudio.stream == sfx_print_start:
		$PrintAudio.stream = sfx_print_mid
		$PrintAudio.play()
		
