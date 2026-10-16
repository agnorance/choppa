// Grass tufts: real blade geometry (no alpha cards), swaying in the wind and blown flat
// and outward by the rotor downwash of up to four choppas (`wash`: xyz = the ground
// under the rotor, w = strength 0..1). Vertex colour alpha = height along the blade.
shader_type spatial;
render_mode cull_disabled;

uniform vec3 root_color : source_color = vec3(0.24, 0.29, 0.12);
uniform vec3 tip_color : source_color = vec3(0.6, 0.66, 0.3);
uniform vec3 dry_color : source_color = vec3(0.62, 0.55, 0.32);
uniform vec4 wash[4];

varying float height;
varying float dryness;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	height = COLOR.a;
	vec3 root = MODEL_MATRIX[3].xyz;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	dryness = noise(root.xz * 0.04);
	float bend = height * height;
	// Gusts roll across the field.
	float gust = noise(root.xz * 0.05 + vec2(TIME * 0.35, TIME * 0.2));
	vec3 push = vec3(sin(TIME * 1.6 + root.x * 0.4), 0.0, cos(TIME * 1.3 + root.z * 0.4)) * 0.08;
	push += vec3(0.6, 0.0, 0.35) * gust * 0.35;
	for (int k = 0; k < 4; k++) {
		vec2 away = root.xz - wash[k].xz;
		float d = length(away);
		float strength = wash[k].w * (1.0 - smoothstep(2.0, 11.0, d));
		if (strength > 0.0) {
			vec2 dir = away / max(d, 0.001);
			float flutter = 0.75 + 0.25 * sin(TIME * 22.0 + d * 2.5);
			push.xz += dir * strength * 1.1 * flutter;
			push.y -= strength * 0.45;
		}
	}
	world += push * bend;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
	// Normals lean up, so tufts shade like a lawn instead of a pile of slivers.
	NORMAL = normalize(mix(NORMAL, (inverse(MODEL_MATRIX) * vec4(0.0, 1.0, 0.0, 0.0)).xyz, 0.7));
}

void fragment() {
	vec3 tip = mix(tip_color, dry_color, smoothstep(0.45, 0.8, dryness));
	ALBEDO = mix(root_color, tip, height) * COLOR.rgb;
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
	BACKLIGHT = tip * 0.35 * height;
}
