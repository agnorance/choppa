class_name Sounds
extends RefCounted
## Sound effects (assets/sounds, synthesized by tools/audio/make_sounds.py) and helpers
## to play them. One-shots free themselves when done; loops are owned by the caller.

## The ResourceLoader caches it, so no cache of our own (a static one would keep the
## streams alive past exit).
static func stream(sound_name: String) -> AudioStream:
	return load("res://assets/sounds/%s.wav" % sound_name)


## A one-shot at a point in the world. `parent` should be a long-lived node (the map or
## the game root), so the sound outlives whatever made it.
static func play_at(parent: Node, sound_name: String, at: Vector3, volume_db := 0.0, pitch := 1.0,
		reach := 1.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream(sound_name)
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.unit_size = 12.0 * reach
	player.max_distance = 450.0 * reach
	player.attenuation_filter_cutoff_hz = 9000.0  # Far sounds go dull, near ones stay crisp.
	parent.add_child(player)
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()


## A one-shot riding along with `parent` (e.g. a missile's launch).
static func play_on(parent: Node3D, sound_name: String, volume_db := 0.0, pitch := 1.0) -> void:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream(sound_name)
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.unit_size = 12.0
	player.max_distance = 450.0
	parent.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


## A non-positional one-shot for the local player (pickups, UI).
static func play_ui(parent: Node, sound_name: String, volume_db := 0.0) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream(sound_name)
	player.volume_db = volume_db
	parent.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


## A looping sound attached to `parent`, started with a random offset so many copies
## don't phase. The caller adjusts pitch and volume and frees it with the parent.
static func loop_on(parent: Node3D, sound_name: String, volume_db := 0.0, reach := 1.0) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream(sound_name)
	player.volume_db = volume_db
	player.unit_size = 12.0 * reach
	player.max_distance = 450.0 * reach
	player.attenuation_filter_cutoff_hz = 9000.0
	parent.add_child(player)
	player.play(randf() * (stream(sound_name) as AudioStreamWAV).get_length())
	return player
