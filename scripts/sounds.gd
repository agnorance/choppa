class_name Sounds
extends RefCounted
## Sound effects (assets/sounds) and helpers to play them. A sound may come in takes,
## `name_1.wav` .. `name_N.wav`, and every play picks one, so a burst of fire or a row
## of impacts does not sound copied. The files are cut from recorded libraries by
## tools/audio/import_sounds.py into assets/sounds/library/ (kept out of git while the
## repo is public: the library licence forbids sharing the files), and the game prefers
## them there; otherwise it plays the synthesized stand-ins of make_sounds.py.
## One-shots free themselves when done; loops are owned by the caller.

const BUS := "Effects"  ## Every effect plays through this bus (Settings makes it).
const MUSIC_BUS := "Music"
const MUSIC_DB := -6.0
const MUSIC_FADE := 1.2  ## Seconds to fade one track out and the next in.

const LIBRARY := "res://assets/sounds/library/"  ## Recorded sounds, preferred when present.
const STAND_INS := "res://assets/sounds/"

## Sound name -> [folder, number of numbered takes (0: a single name.wav)]. Only paths
## and numbers, so nothing here keeps a stream alive past exit.
static var _takes := {}
static var _music: AudioStreamPlayer
static var _music_track := ""


## The bus for effects, or Master until the settings have created it (tests).
static func bus() -> String:
	return BUS if AudioServer.get_bus_index(BUS) >= 0 else "Master"


## A stream for `sound_name`: one of its takes at random. `*_loop` sounds always loop,
## whatever their import settings say. The ResourceLoader caches the files.
static func stream(sound_name: String) -> AudioStream:
	var source := _source(sound_name)
	var folder: String = source[0]
	var takes: int = source[1]
	var path := folder + sound_name + ".wav"
	if takes > 0:
		path = "%s%s_%d.wav" % [folder, sound_name, randi_range(1, takes)]
	var s: AudioStream = load(path)
	if sound_name.ends_with("_loop") and s is AudioStreamWAV:
		_make_loop(s as AudioStreamWAV)
	return s


static func _take_count(sound_name: String) -> int:
	return _source(sound_name)[1]


## Where a sound comes from: the recorded library when it has the sound, else the
## stand-ins; and how many takes it has there.
static func _source(sound_name: String) -> Array:
	if not _takes.has(sound_name):
		var found := [STAND_INS, 0]
		for folder in [LIBRARY, STAND_INS]:
			var count := 0
			while ResourceLoader.exists("%s%s_%d.wav" % [folder, sound_name, count + 1]):
				count += 1
			if count > 0 or ResourceLoader.exists(folder + sound_name + ".wav"):
				found = [folder, count]
				break
		_takes[sound_name] = found
	return _takes[sound_name]


static func _make_loop(s: AudioStreamWAV) -> void:
	if s.loop_mode != AudioStreamWAV.LOOP_DISABLED:
		return
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = roundi(s.get_length() * s.mix_rate)


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
	var s := stream(sound_name)
	player.stream = s
	player.volume_db = volume_db
	player.unit_size = 12.0 * reach
	player.max_distance = 450.0 * reach
	player.attenuation_filter_cutoff_hz = 9000.0
	parent.add_child(player)
	player.play(randf() * s.get_length())
	return player


## Plays a music loop (assets/sounds/music_<name>_loop.wav) on the Music bus, or fades
## the music out with "". A new track fades in after the old one fades out. Keeps
## playing across scene reloads; the same track is not restarted.
static func music(tree: SceneTree, track: String) -> void:
	if _music == null or not is_instance_valid(_music):
		_music = AudioStreamPlayer.new()
		_music.bus = MUSIC_BUS if AudioServer.get_bus_index(MUSIC_BUS) >= 0 else "Master"
		_music.volume_db = MUSIC_DB
		tree.root.add_child.call_deferred(_music)
		_music_track = ""
	if track == _music_track:
		return
	_music_track = track
	var player := _music
	var fade := tree.create_tween().bind_node(tree.root)
	if player.playing:
		fade.tween_property(player, "volume_db", -40.0, MUSIC_FADE * 0.5)
	if track == "":
		fade.tween_callback(player.stop)
		return
	var next := stream("music_%s_loop" % track)
	fade.tween_callback(func() -> void:
		player.stream = next
		player.volume_db = -40.0
		player.play())
	fade.tween_property(player, "volume_db", MUSIC_DB, MUSIC_FADE)


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
