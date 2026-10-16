// Lake water: two scrolling ripple normal maps over a gentle swell, refraction of the
// lake bed (bent by the ripples), colour that deepens with water depth, foam along the
// shore, and rings plus foam where a choppa's rotor beats the surface (`wash`: xyz =
// the point under the rotor, w = strength 0..1). Needs the screen and depth textures
// (Forward+ and Mobile); the Compatibility renderer uses a simpler material.
shader_type spatial;
render_mode blend_mix, cull_back, specular_schlick_ggx;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth : hint_depth_texture, filter_nearest;
uniform sampler2D ripples_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D ripples_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 shallow : source_color = vec3(0.16, 0.42, 0.4);
uniform vec3 deep : source_color = vec3(0.04, 0.18, 0.22);
uniform vec3 sky_tint : source_color = vec3(0.72, 0.7, 0.68);  // Fake sky reflection at grazing angles.
uniform vec3 foam_color : source_color = vec3(0.92, 0.93, 0.88);
uniform float clarity = 0.35;  // How fast light dies with depth (per metre).
uniform vec4 wash[4];

varying vec3 world;

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
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(world.x * 0.12 + TIME * 1.1) * 0.08 + cos(world.z * 0.1 + TIME * 0.9) * 0.08;
	world.y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	vec2 uv = world.xz;
	vec3 n = normalize(texture(ripples_a, uv * 0.045 + TIME * vec2(0.012, 0.007)).rgb * 2.0 - 1.0
		+ texture(ripples_b, uv * 0.11 - TIME * vec2(0.01, 0.018)).rgb * 2.0 - 1.0);
	vec2 bend = n.xy;

	// Rotor downwash: fast rings racing outward, churned foam right underneath.
	float churn = 0.0;
	for (int k = 0; k < 4; k++) {
		vec2 away = uv - wash[k].xz;
		float d = length(away);
		float s = wash[k].w * (1.0 - smoothstep(2.0, 16.0, d));
		if (s > 0.0) {
			float ring = sin(d * 2.6 - TIME * 13.0);
			bend += away / max(d, 0.01) * ring * s * 0.9;
			churn += s * (smoothstep(0.55, 1.0, ring) * 0.5 + (1.0 - smoothstep(0.0, 7.0, d)) * 0.7)
				* (0.5 + noise(uv * 2.5 + TIME * 3.0));
		}
	}
	NORMAL_MAP = normalize(vec3(bend * 0.5 + 0.5, 1.0));
	NORMAL_MAP_DEPTH = 1.0;

	// How much water lies between the surface and whatever is behind it.
	float raw = texture(depth, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw, 1.0);
	float thickness = max(0.0, -behind.z / behind.w + VERTEX.z);
	vec2 refracted_uv = SCREEN_UV + bend * 0.025 * clamp(thickness * 0.3, 0.0, 1.0);
	// Don't pull in things in front of the water.
	float raw2 = texture(depth, refracted_uv).r;
	vec4 behind2 = INV_PROJECTION_MATRIX * vec4(refracted_uv * 2.0 - 1.0, raw2, 1.0);
	if (-behind2.z / behind2.w < -VERTEX.z) {
		refracted_uv = SCREEN_UV;
	}
	vec3 bed = textureLod(screen, refracted_uv, 0.0).rgb;
	float through = exp(-thickness * clarity);
	vec3 body = mix(deep, shallow, exp(-thickness * 0.12));

	// Foam: a broken band along the shore plus the rotor churn.
	float shore = (1.0 - smoothstep(0.0, 0.9, thickness)) * smoothstep(0.35, 0.75, noise(uv * 1.7 + TIME * 0.4));
	float foam = clamp(shore + churn, 0.0, 1.0);

	ALBEDO = mix(body * (1.0 - through), foam_color, foam);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	EMISSION = (bed * through * shallow * 1.6 + sky_tint * fresnel * 0.7) * (1.0 - foam);
	ROUGHNESS = mix(0.04, 0.7, foam);
	SPECULAR = 0.6;
	ALPHA = 1.0;
}
