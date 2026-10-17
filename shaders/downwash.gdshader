// Rotor downwash on the ground: gusts of flattened dust or ruffled water streaming outward
// from under the choppa. `power` fades it with altitude; `tint` is dust or spray.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float power = 0.0;
uniform vec3 tint : source_color = vec3(0.8, 0.76, 0.66);

// sin-free hash: sin() of large arguments breaks into blocks on GPUs (see sky.gdshader).
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
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
	vec2 dir = c / max(r, 0.001);
	// Soft gusts streaming outward, no rings (owner: the old rings read as lines). The
	// direction vector instead of an angle keeps the pattern seamless all round.
	float flow = r * 4.0 - TIME * 3.2;
	float gust = noise(dir * 2.6 + vec2(flow, flow * 0.7));
	float grain = noise(dir * 7.0 + vec2(r * 9.0 - TIME * 6.0, -r * 5.0 + TIME * 2.0));
	float wisps = smoothstep(0.3, 0.85, gust * 0.7 + grain * 0.45);
	float body = smoothstep(0.06, 0.35, r) * (1.0 - smoothstep(0.5, 1.0, r));
	ALBEDO = tint * 0.9;
	ALPHA = clamp(body * wisps * power * 0.5, 0.0, 1.0);
}
