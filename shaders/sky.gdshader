// Golden-hour sky: warm horizon, deep zenith, a hot sun with a wide glow, and three
// cloud layers (high cirrus streaks, mid cumulus, low haze bank), lit warm on the sun
// side and cool purple-grey away from it.
shader_type sky;

uniform vec3 zenith_color : source_color = vec3(0.12, 0.24, 0.42);
uniform vec3 horizon_color : source_color = vec3(0.92, 0.66, 0.46);
uniform vec3 opposite_horizon : source_color = vec3(0.55, 0.58, 0.66);
uniform vec3 ground_color : source_color = vec3(0.28, 0.22, 0.18);
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.52;
uniform float cloud_speed = 0.0015;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p, int octaves) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < octaves; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = EYEDIR;
	float up = dir.y;
	vec3 sun_dir = LIGHT0_DIRECTION;
	vec3 sun_col = LIGHT0_COLOR * LIGHT0_ENERGY;
	float sun = max(dot(dir, sun_dir), 0.0);
	// How much this direction faces the sun around the horizon (0 away .. 1 toward).
	float toward = dot(normalize(dir.xz + 0.0001), normalize(sun_dir.xz + 0.0001)) * 0.5 + 0.5;

	vec3 horizon = mix(opposite_horizon, horizon_color, pow(toward, 1.5));
	vec3 col = mix(horizon, zenith_color, pow(clamp(up, 0.0, 1.0), 0.55));
	if (up < 0.0) {
		col = mix(horizon * 0.85, ground_color, clamp(-up * 6.0, 0.0, 1.0));
	}
	col += sun_col * (pow(sun, 4.0) * 0.12 + pow(sun, 32.0) * 0.35 + pow(sun, 400.0) * 1.2);

	if (up > 0.0) {
		vec2 drift = vec2(TIME * cloud_speed, TIME * cloud_speed * 0.35);
		vec2 uv = dir.xz / (up + 0.08);
		// High cirrus: stretched streaks.
		float cirrus = fbm(vec2(uv.x * 0.6, uv.y * 2.4) * 0.8 + drift * 0.5, 5);
		cirrus = smoothstep(0.55, 0.85, cirrus) * 0.5;
		// Mid cumulus with fake self-shadowing toward the sun.
		float base = fbm(uv * 0.75 + drift, 6);
		float shape = base * 0.8 + fbm(uv * 2.7 - drift * 1.7, 4) * 0.2;
		float cover = 1.0 - cloud_coverage;
		float density = smoothstep(cover, cover + 0.2, shape);
		float toward_sun = fbm(uv * 0.75 + drift + sun_dir.xz * 0.12, 6);
		float lit = clamp(0.5 + (shape - toward_sun) * 4.0, 0.0, 1.0);
		vec3 shadow_col = vec3(0.36, 0.33, 0.42);
		vec3 lit_col = mix(vec3(1.0, 0.86, 0.7), vec3(1.0, 0.95, 0.9), up);
		vec3 cloud = mix(shadow_col, lit_col, lit);
		// Silver lining when looking toward the sun through thin edges.
		cloud += sun_col * pow(sun, 6.0) * (1.0 - density) * 0.9;
		float fade = smoothstep(0.0, 0.12, up);
		col = mix(col, mix(vec3(1.0, 0.85, 0.72), col, 0.4), cirrus * fade);
		col = mix(col, cloud, density * fade * 0.92);
	}
	// Low haze bank hugging the horizon.
	col = mix(col, horizon * 1.05, exp(-abs(up) * 18.0) * 0.6);
	COLOR = col;
}
