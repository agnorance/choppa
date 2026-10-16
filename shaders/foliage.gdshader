// Conifer needles: alpha-cut cards that sway in the wind (more toward the tips and the
// top of the tree), with light shining through them from behind.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D needles : source_color, filter_linear_mipmap_anisotropic;
uniform vec3 tint : source_color = vec3(1.0);
uniform float sway = 0.06;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float height = max(VERTEX.y, 0.0) * 0.1;
	float tip = UV.y;  // Card tips flutter more than their stems.
	float t = TIME;
	vec3 wind = vec3(sin(t * 1.1 + world.x * 0.05), 0.0, cos(t * 0.9 + world.z * 0.05)) * height;
	wind += vec3(sin(t * 3.7 + world.y * 2.0 + world.x), sin(t * 4.3 + world.z * 2.0), 0.0) * tip * 0.35;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(wind * sway, 0.0)).xyz;
}

void fragment() {
	vec4 tex = texture(needles, UV);
	// Darker deep in the crown (low on each card), lit tips.
	ALBEDO = tex.rgb * tint * mix(0.75, 1.1, UV.y);
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.45;
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
	BACKLIGHT = tex.rgb * tint * 0.6;
}
