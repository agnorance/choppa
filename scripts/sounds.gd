class_name Sounds
extends RefCounted
## Sound effects (assets/sounds, synthesized by tools/audio/make_sounds.py) and helpers
## to play them. One-shots free themselves when done; loops are owned by the caller.

const BUS := "Effects"  ## Every effect plays through this bus (Settings makes it).
const MUSIC_BUS := "Music"


## The bus for effects, or Master until the settings have created it (tests).
static func bus() -> String:
	return BUS if AudioServer.get_bus_index(BUS) >= 0 else "Master"


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
	player.bus = bus()
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
	player.bus = bus()
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
	player.bus = bus()
	player.stream = stream(sound_name)
	player.volume_db = volume_db
	parent.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


## A looping sound attached to `parent`, started with a random offset so many copies
## don't phase. The caller adjusts pitch and volume and frees it with the parent.
static func loop_on(parent: Node3D, sound_name: String, volume_db := 0.0, reach := 1.0) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.bus = bus()
	player.stream = stream(sound_name)
	player.volume_db = volume_db
	player.unit_size = 12.0 * reach
	player.max_distance = 450.0 * reach
	player.attenuation_filter_cutoff_hz = 9000.0
	parent.add_child(player)
	player.play(randf() * (stream(sound_name) as AudioStreamWAV).get_length())
	return player


static var _music: AudioStreamPlayer


## Plays a music loop (assets/sounds/music_<name>_loop.wav) on the Music bus, or stops
## the music with "". Keeps playing across scene reloads; the same track is not restarted.
static func music(tree: SceneTree, track: String) -> void:
	if _music == null or not is_instance_valid(_music):
		_music = AudioStreamPlayer.new()
		_music.bus = MUSIC_BUS if AudioServer.get_bus_index(MUSIC_BUS) >= 0 else "Master"
		_music.volume_db = -6.0
		tree.root.add_child.call_deferred(_music)
	var path := "music_%s_loop" % track
	if track == "":
		_music.stop()
		return
	if _music.stream and _music.stream.resource_path.ends_with(path + ".wav") and _music.playing:
		return
	_music.stream = stream(path)
	_music.play.call_deferred()


## Like play_on, but returns the player so the caller can stop it early.
static func play_on_returning(parent: Node3D, sound_name: String, volume_db := 0.0) -> AudioStreamPlayer3D:
	if parent == null or not parent.is_inside_tree():
		return null
	var player := AudioStreamPlayer3D.new()
	player.bus = bus()
	player.stream = stream(sound_name)
	player.volume_db = volume_db
	player.unit_size = 12.0
	player.max_distance = 300.0
	parent.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	return player
