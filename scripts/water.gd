class_name Water
extends MeshInstance3D
## A lake surface (shaders/water.gdshader): ripples, refraction, depth colour, shore
## foam, and rings where a low choppa's rotor beats the water. On the Compatibility
## renderer, a plain waving surface instead.

var size := 200.0

var _material: ShaderMaterial


func _ready() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	plane.subdivide_width = 48
	plane.subdivide_depth = 48
	mesh = plane
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = ShaderMaterial.new()
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		_material.shader = preload("res://shaders/water_simple.gdshader")
	else:
		_material.shader = preload("res://shaders/water.gdshader")
		_material.set_shader_parameter("ripples_a", _ripples(3, 0.012))
		_material.set_shader_parameter("ripples_b", _ripples(8, 0.03))
	material_override = _material


func _process(_delta: float) -> void:
	var wash: Array[Vector4] = [Vector4.ZERO, Vector4.ZERO, Vector4.ZERO, Vector4.ZERO]
	var k := 0
	for node in get_tree().get_nodes_in_group("choppas"):
		var c := node as Choppa
		if k >= 4 or not c.alive or not c.over_water or c.altitude > 18.0:
			continue
		wash[k] = Vector4(c.global_position.x, 0.0, c.global_position.z, 1.0 - c.altitude / 18.0)
		k += 1
	_material.set_shader_parameter("wash", wash)


static func _ripples(seed: int, frequency: float) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = frequency
	noise.fractal_octaves = 3
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	texture.as_normal_map = true
	texture.bump_strength = 6.0
	texture.generate_mipmaps = true
	texture.noise = noise
	return texture
