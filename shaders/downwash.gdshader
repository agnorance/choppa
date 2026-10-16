// Rotor downwash on the ground: rings of flattened dust or ruffled water racing outward
// from under the choppa. `power` fades it with altitude; `tint` is dust or spray.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float power = 0.0;
uniform vec3 tint : source_color = vec3(0.8, 0.76, 0.66);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float r = length(c);
	float a = atan(c.y, c.x);
	// Rings move outward; streaks break them up around the circle.
	float rings = 0.5 + 0.5 * sin(r * 26.0 - TIME * 14.0);
	float streaks = noise(vec2(a * 6.0, r * 3.0 - TIME * 2.5));
	float body = smoothstep(0.08, 0.3, r) * (1.0 - smoothstep(0.6, 1.0, r));
	ALBEDO = tint;
	ALPHA = clamp(body * (rings * 0.6 + 0.4) * streaks * power, 0.0, 1.0);
}
