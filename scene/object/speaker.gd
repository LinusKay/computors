extends CSGBox3D

@onready var player: AudioStreamPlayer3D = $AudioStreamPlayer3D
var paused = false
var pause_position = null

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
