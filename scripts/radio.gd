class_name Radio
extends RefCounted
## The in-game radio for battles and races: stations of music, switched with N (or the
## d-pad right), remembered in Settings "radio_station". Built in: CHOPPA FM, the
## synthesized techno (tools/audio/make_music.py). More stations: one folder of
## royalty-free tracks (mp3, ogg, wav) per station in assets/music/library/<Station>/,
## played one after another. That folder is git-ignored while the repo is public: the
## licences (Pixabay and the like) forbid sharing the files. Real radio stations and
## commercial songs are out: they would need a licence for every track.

const LIBRARY := "res://assets/music/library/"
const BUILT_IN := "CHOPPA FM"
const OFF := "RADIO OFF"
const FORMATS := ["mp3", "ogg", "wav"]

static var _stations: Array = []  ## [{name, tracks: [res paths]}], built on first use.
static var _track := 0


## Every station: the built-in one first, the library's folders, then "off".
static func stations() -> Array:
	if _stations.is_empty():
		_stations.append({"name": BUILT_IN, "tracks": ["res://assets/sounds/music_techno_loop.ogg"]})
		if DirAccess.dir_exists_absolute(LIBRARY):
			var folders := Array(DirAccess.get_directories_at(LIBRARY))
			folders.sort()
			for folder: String in folders:
				var tracks := []
				for file: String in DirAccess.get_files_at(LIBRARY + folder):
					# Exported builds list "x.mp3.import" or ".remap" instead of the file.
					var track := file.trim_suffix(".import").trim_suffix(".remap")
					var path := LIBRARY + folder + "/" + track
					if track.get_extension().to_lower() in FORMATS and not tracks.has(path):
						tracks.append(path)
				if not tracks.is_empty():
					tracks.sort()
					_stations.append({"name": folder.to_upper(), "tracks": tracks})
		_stations.append({"name": OFF, "tracks": []})
	return _stations


static func current() -> Dictionary:
	var all := stations()
	return all[clampi(int(Settings.value("radio_station")), 0, all.size() - 1)]


## Plays the chosen station (from a random track), or fades the music out if it is off.
static func play(tree: SceneTree) -> void:
	var station := current()
	var tracks: Array = station.tracks
	if tracks.is_empty():
		Sounds.music(tree, "")
		return
	_track = randi() % tracks.size()
	_play_track(tree, station)


static func _play_track(tree: SceneTree, station: Dictionary) -> void:
	var tracks: Array = station.tracks
	var path: String = tracks[_track % tracks.size()]
	var s: AudioStream = load(path)
	var looping := tracks.size() == 1 and path.get_file().begins_with("music_")
	_set_loop(s, looping)
	Sounds.play_music(tree, "radio:" + path, s, func() -> void:
		# A track ended: the next one on the same station.
		if current() == station:
			_track += 1
			_play_track(tree, station))


static func _set_loop(s: AudioStream, looping: bool) -> void:
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = looping
	elif s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = looping
	elif s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if looping else AudioStreamWAV.LOOP_DISABLED
		if looping:
			(s as AudioStreamWAV).loop_end = roundi(s.get_length() * (s as AudioStreamWAV).mix_rate)


## Tunes to the next station and plays it; returns what to show ("RADIO  ·  CHOPPA FM").
static func next_station(tree: SceneTree) -> String:
	var index := (clampi(int(Settings.value("radio_station")), 0, stations().size() - 1) + 1) % stations().size()
	Settings.set_value("radio_station", index)
	Settings.save()
	play(tree)
	var name: String = current().name
	return name if name == OFF else "RADIO  ·  " + name
