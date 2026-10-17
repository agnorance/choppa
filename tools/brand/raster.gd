extends SceneTree
## Renders SVGs to PNGs with Godot's own SVG renderer, for tools/brand/make_brand.py.
## Argument: a file of "source.svg|target.png|scale" lines.


func _init() -> void:
	var listing := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.READ)
	while listing and not listing.eof_reached():
		var line := listing.get_line().strip_edges()
		if line == "":
			continue
		var job := line.split("|")
		var image := Image.new()
		var err := image.load_svg_from_string(FileAccess.get_file_as_string(job[0]), float(job[2]))
		if err != OK:
			push_error("could not render " + job[0])
			continue
		image.save_png(job[1])
	quit()
