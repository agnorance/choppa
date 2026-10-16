// Lake water for the Compatibility renderer: waves and a fresnel tint, no refraction.
shader_type spatial;
render_mode blend_mix, specular_schlick_ggx;
uniform vec3 deep : source_color = vec3(0.04, 0.2, 0.3);
uniform vec3 shallow : source_color = vec3(0.12, 0.45, 0.5);
varying vec2 world_xz;
void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	VERTEX.y += sin(world_xz.x * 0.15 + TIME * 1.3) * 0.15 + cos(world_xz.y * 0.12 + TIME) * 0.15;
}
void fragment() {
	float ripple = sin(world_xz.x * 0.7 + TIME * 2.0) * sin(world_xz.y * 0.6 - TIME * 1.6);
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = mix(shallow, deep, facing) + ripple * 0.03;
	ROUGHNESS = 0.06;
	SPECULAR = 0.8;
	ALPHA = mix(0.95, 0.75, facing);
}
