extends Control

@onready var speaker: CSGBox3D = get_node("/root/Node3D/Speaker")

var recently_played = []

func _ready() -> void:
	update_screen_playback_details()	
	update_screen_playback_tracker()
	update_screen_loop()
	update_screen_volume(-10)
	update_screen_pitch(1)
	update_screen_recently_played()

func update_screen() -> void:
	pass

func add_recently_played(audio_file: Array) -> void:
	if recently_played.has(audio_file):
		var existing_index = recently_played.find(audio_file)
		recently_played.pop_at(existing_index)
	recently_played.push_front(audio_file)
	
	if recently_played.size() > 5:
		recently_played.pop_back()
			
	update_screen_recently_played()

func update_screen_recently_played() -> void:
	var new_text = ""
	for audio_file_index in recently_played.size():
		var artist = "Unknown Artist"
		var title = "Unknown"
		var year = "Unknown"
		var audio_file = recently_played[audio_file_index]
		var metadata = audio_file[2]
		if metadata.has("artist"): artist = metadata.artist
		if metadata.has("title"): title = metadata.title
		if metadata.has("year"): year = metadata.year
		if title.length() > 25:
			title = title.left(22) + "..."
		var length = audio_file[3]
		var length_minutes = floor(length / 60)
		var length_seconds = length - length_minutes * 60
		var length_formatted = ("%02d:%02d" % [length_minutes, length_seconds])
		new_text += str(audio_file_index + 1) + "   " + length_formatted + "   " + title + "   " + artist + "   " + year + "\n"
	%LabelRecentlyPlayed.text = new_text

func update_screen_loop() -> void:
	if speaker.loop:
		%LabelLoop.text = "[x] loop"
	else:
		%LabelLoop.text = "[ ] loop"

func update_screen_volume(vol: int) -> void:
	%LabelVolume.text = "[" + str(vol) + "] volume (db)"

func update_screen_pitch(pitch: float) -> void:
	%LabelPitch.text = "[" + str(snapped(pitch, 0.1)) + "] pitch"

func update_screen_playback_tracker() -> void:
	%LabelPlayback.text = speaker.get_playback_tracker()

func update_screen_playback_details() -> void:
	%LabelPlaybackDetails.text = speaker.get_audio_details()

func load_recent(index: int) -> bool:
	if index > recently_played.size():
		print("no matching recently played index")
		return false
	var audio_file = recently_played[index - 1][1]
	speaker.load_audio(load(audio_file))
	speaker.play()
	update_screen_recently_played()
	%PlaybackTimer.start()
	%PlaybackTimer.paused = false
	update_screen_playback_tracker()
	update_screen_playback_details()
	return true

func _input(event: InputEvent) -> void:
	if %InterfaceSoundControl.visible:
		match event.keycode:
			KEY_1: load_recent(1); get_viewport().set_input_as_handled()
			KEY_2: load_recent(2); get_viewport().set_input_as_handled()
			KEY_3: load_recent(3); get_viewport().set_input_as_handled()
			KEY_4: load_recent(4); get_viewport().set_input_as_handled()
			KEY_5: load_recent(5); get_viewport().set_input_as_handled()
			KEY_6: load_recent(6); get_viewport().set_input_as_handled()
			KEY_7: load_recent(7); get_viewport().set_input_as_handled()
			KEY_8: load_recent(8); get_viewport().set_input_as_handled()
			KEY_9: load_recent(9); get_viewport().set_input_as_handled()
			KEY_0: load_recent(10); get_viewport().set_input_as_handled()
		if event.is_action_pressed("sound_control_play"):
			speaker.play()
			%PlaybackTimer.start()
			%PlaybackTimer.paused = false
			update_screen_playback_tracker()
			update_screen_playback_details()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("sound_control_pause"):
			speaker.pause()
			%PlaybackTimer.paused = true
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("sound_control_stop"):
			speaker.stop()
			%PlaybackTimer.stop()
			update_screen_playback_tracker()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("sound_control_vol_up"):
			var vol = speaker.volume_up()
			update_screen_volume(vol)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("sound_control_vol_down"):
			var vol = speaker.volume_down()
			update_screen_volume(vol)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("sound_control_pitch_up"):
			var pitch = speaker.pitch_up()
			update_screen_pitch(pitch)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("sound_control_pitch_down"):
			var pitch = speaker.pitch_down()
			update_screen_pitch(pitch)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("sound_control_loop"):
			speaker.loop_toggle()
			update_screen_loop()
			get_viewport().set_input_as_handled()


func _on_timer_timeout() -> void:
	update_screen_playback_tracker()
	print("time")
