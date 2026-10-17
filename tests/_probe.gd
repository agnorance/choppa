extends SceneTree
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	MapKit.block(world, Vector3(0.0, -1.0, 0.0), Vector3(400.0, 2.0, 400.0), Color.GRAY)
	var c := Choppa.new()
	world.add_child(c)
	c.spawn_on_ground(Transform3D(), true)
	c.set_physics_process(false)
	var line := ""
	for t in 330:
		c.input.collective = 1.0
		await physics_frame
		c.step(1.0 / 60.0)
		if t % 30 == 0 or (t > 200 and t < 206):
			line += " %d:y%.3f vy%.2f s%.2f T%.1f up%.2f n%d" % [t, c.global_position.y, c.velocity.y, c.spool, c._thrust, c.global_transform.basis.y.y, c.get_slide_collision_count()]
	print(line)
	quit()
