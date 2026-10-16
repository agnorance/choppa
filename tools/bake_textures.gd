extends SceneTree
## Draws every procedural texture listed in Baked.generators() and saves it as a PNG in
## assets/textures/baked/. Run through tools/bake.ps1 or tools/bake.sh, which re-import
## afterwards (new PNGs need their .import files set to VRAM compression and mipmaps).
##   godot --headless --path . --script res://tools/bake_textures.gd


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Baked.DIR))
	var generators := Baked.generators()
	for name: String in generators:
		var image: Image = generators[name].call()
		var path: String = Baked.DIR + name + ".png"
		var err := image.save_png(path)
		print("%s: %dx%d %s" % [path, image.get_width(), image.get_height(), "ok" if err == OK else error_string(err)])
	quit()
