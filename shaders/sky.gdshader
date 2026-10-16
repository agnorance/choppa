// Afternoon sky: gradient, sun with glow, and two layers of drifting fbm clouds lit
// from the sun side.
shader_type sky;

uniform vec3 zenith_color : source_color = vec3(0.13, 0.3, 0.6);
uniform vec3 horizon_color : source_color = vec3(0.62, 0.7, 0.78);
uniform vec3 ground_color : source_color = vec3(0.32, 0.27, 0.22);
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.5;
uniform float cloud_speed = 0.002;

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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 6; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = EYEDIR;
	float up = dir.y;
	vec3 col = mix(horizon_color, zenith_color, pow(clamp(up, 0.0, 1.0), 0.45));
	if (up < 0.0) {
		col = mix(horizon_color * 0.9, ground_color, clamp(-up * 5.0, 0.0, 1.0));
	}
	vec3 sun_dir = LIGHT0_DIRECTION;
	float sun = max(dot(dir, sun_dir), 0.0);
	vec3 sun_col = LIGHT0_COLOR * LIGHT0_ENERGY;
	// Warm haze around the sun, stronger near the horizon.
	col += sun_col * (pow(sun, 6.0) * 0.18 + pow(sun, 48.0) * 0.35) * (1.0 - clamp(up, 0.0, 1.0) * 0.5);
	if (up > 0.0) {
		vec2 uv = dir.xz / (up + 0.12);
		vec2 drift = vec2(TIME * cloud_speed, TIME * cloud_speed * 0.4);
		float base = fbm(uv * 0.9 + drift);
		float detail = fbm(uv * 3.1 - drift * 2.0);
		float shape = base * 0.75 + detail * 0.25;
		float cover = 1.0 - cloud_coverage;
		float density = smoothstep(cover, cover + 0.22, shape);
		// Fake lighting: sample the cloud a little towards the sun; thick = darker.
		float toward_sun = fbm(uv * 0.9 + drift + sun_dir.xz * 0.08);
		float shade = clamp(1.0 - (toward_sun - shape) * 3.0, 0.45, 1.0);
		vec3 lit = mix(vec3(0.55, 0.58, 0.66), vec3(1.0, 0.97, 0.93), shade);
		lit += sun_col * pow(sun, 5.0) * 0.25 * (1.0 - density * 0.5);
		float fade = smoothstep(0.0, 0.18, up);
		col = mix(col, lit, density * fade * 0.95);
	}
	// Sun disc on top of everything (it peeks through thin cloud edges).
	col += sun_col * smoothstep(0.9994, 0.9997, sun) * 8.0;
	COLOR = col;
}
