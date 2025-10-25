extends CSGBox3D

@onready var player: AudioStreamPlayer3D = $AudioStreamPlayer3D
var audio_metadata = {}
var paused = false
var pause_position = null
var loop = false

var progress_bar_length = 30
var progress_bar_character = "░"
var index_character = "█"

func load_audio(audio_file: AudioStream) -> void:
	player.stream = audio_file

func play() -> void:
	if paused:
		paused = false
		player.play(pause_position)
	else:
		player.play()

func pause() -> void:
	pause_position = player.get_playback_position()
	paused = true
	player.stop()

func stop() -> void:
	paused = false
	pause_position = 0
	player.stop()

func pitch(pitch_value: float) -> void:
	player.pitch_scale = pitch_value

func volume(volume_value: float) -> void:
	player.volume_db = volume_value

func volume_up() -> float:
	player.volume_db = clamp(player.volume_db + 10, -80, 0)
	return player.volume_db
	
func volume_down() -> float:
	player.volume_db = clamp(player.volume_db - 10, -80, 0)
	return player.volume_db
	
func pitch_up() -> float:
	player.pitch_scale = clamp(player.pitch_scale + 0.1, -2, 2)
	return player.pitch_scale
	
func pitch_down() -> float:
	player.pitch_scale = clamp(player.pitch_scale - 0.1, -2, 2)
	return player.pitch_scale

func _on_audio_stream_player_3d_finished() -> void:
	if loop: play()
	else: stop()

func loop_toggle() -> void:
	loop = !loop

func get_audio_length() -> float:
	return player.stream.get_length()

func get_audio_details() -> String:
	var meta_artist = "Unknown Artist"
	var meta_title = "Unknown Audio"
	var meta_year = "Unknown Year"
		
	if audio_metadata.has("artist"): meta_artist = audio_metadata["artist"]
	if audio_metadata.has("title"): meta_title = audio_metadata["title"]
	if audio_metadata.has("year"): meta_year = audio_metadata["year"]
	
	return "Currently playing: " + meta_title + " (" + meta_year + ") by " + meta_artist

func get_playback_tracker() -> String:
	var audio_length = 1
	var audio_length_minutes: int = 0
	var audio_length_seconds: int = 0
	
	var playback_position = 0.0
	var playback_minutes: float = 0
	var playback_seconds: float = 0
		
	if player != null and player.stream != null:
		audio_length = player.stream.get_length()
		audio_length_minutes = floor(audio_length / 60)
		audio_length_seconds = audio_length - audio_length_minutes * 60
		
		playback_position = player.get_playback_position()
		playback_minutes = floor(playback_position / 60)
		playback_seconds = playback_position - playback_minutes * 60
	
	var progress_bar = ""
	for n in progress_bar_length:
		progress_bar += progress_bar_character
	var progress_percent = playback_position / audio_length

	var progress_index = progress_percent * progress_bar.length()
	var progress_bar_indexed = progress_bar.left(progress_index) + index_character + progress_bar.right(progress_bar.length() - (progress_index))
	
	return ("%02d:%02d" % [playback_minutes, playback_seconds]) + " [" + progress_bar_indexed + "] " + ("%02d:%02d" % [audio_length_minutes, audio_length_seconds])

func get_playback_tracker_detailed() -> String:
	return get_audio_details() + "\n" + get_playback_tracker()
