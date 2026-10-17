// Painted metal hull: panel seams and rivet rows in object space (no UVs needed),
// chipped paint showing bare metal, grime toward the belly, soot behind the exhausts.
// Camos (Progression.CAMOS) pick a pattern and up to four colours; finishes set how
// metallic and glossy the paint is; Apex lights the seams. Object space: -Z is the nose.
shader_type spatial;

uniform vec3 paint : source_color = vec3(0.42, 0.45, 0.3);
uniform vec3 bare_metal : source_color = vec3(0.6, 0.6, 0.58);
uniform vec3 grime : source_color = vec3(0.18, 0.15, 0.12);
uniform float wear : hint_range(0.0, 1.0) = 0.28;
uniform vec2 panel_size = vec2(1.35, 0.75);  // Along the length, around the body (metres).
// 0 solid, 1 blotches, 2 tiger stripes, 3 splinter, 4 digital, 5 racing stripes,
// 6 hornet stripes, 7 sunset, 8 checkerboard.
uniform int pattern = 0;
uniform vec3 camo_b : source_color = vec3(0.3, 0.32, 0.22);
uniform vec3 camo_c : source_color = vec3(0.2, 0.18, 0.14);
uniform vec3 camo_d : source_color = vec3(0.55, 0.5, 0.38);
uniform float pattern_scale = 1.0;
uniform float paint_metal : hint_range(0.0, 1.0) = 0.15;
uniform float paint_gloss : hint_range(0.0, 1.0) = 0.38;
uniform vec3 seam_color : source_color = vec3(0.0);
uniform float seam_glow = 0.0;

varying vec3 obj_pos;
varying vec3 obj_normal;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.1;
		a *= 0.5;
	}
	return v;
}

// The camo colour at an object-space point.
vec3 camo(vec3 p, vec3 base) {
	vec3 q = p / pattern_scale;
	if (pattern == 1) {
		// Blotches: two noise thresholds give three overlapping shapes on the base.
		float a = fbm(q * 0.9);
		float b = fbm(q * 0.9 + vec3(7.3, 1.7, 3.1));
		vec3 col = mix(base, camo_b, step(0.52, a));
		col = mix(col, camo_c, step(0.56, b) * step(a, 0.6));
		return mix(col, camo_d, step(0.62, fbm(q * 1.6 + 11.0)));
	}
	if (pattern == 2) {
		// Tiger: wavy dark stripes across the body.
		float s = sin((q.z + fbm(q * 1.2) * 1.4) * 4.2);
		vec3 col = mix(base, camo_b, smoothstep(0.35, 0.45, s));
		return mix(col, camo_c, smoothstep(0.82, 0.88, s));
	}
	if (pattern == 3) {
		// Splinter: straight-edged polygons from a few hashed half-planes.
		vec3 cell = floor(q * 0.8);
		float h = hash(cell);
		vec3 f = fract(q * 0.8);
		float cut1 = step(f.x + f.z * 0.6, 0.8 + h * 0.4);
		float cut2 = step(f.y - f.z * 0.4, 0.3 + hash(cell + 3.0) * 0.5);
		vec3 col = h < 0.33 ? base : (h < 0.66 ? camo_b : camo_c);
		col = mix(col, camo_d, cut1 * cut2);
		return mix(col, camo_b, (1.0 - cut1) * step(0.7, hash(cell + 9.0)));
	}
	if (pattern == 4) {
		// Digital: blotches sampled on a 12 cm grid.
		vec3 g = floor(q / 0.12) * 0.12;
		float a = fbm(g * 0.9);
		float b = fbm(g * 0.9 + vec3(7.3, 1.7, 3.1));
		vec3 col = mix(base, camo_b, step(0.5, a));
		col = mix(col, camo_c, step(0.55, b));
		return mix(col, camo_d, step(0.64, fbm(g * 1.7 + 4.0)));
	}
	if (pattern == 5) {
		// Racing: two stripes over the top along the length, a thin pinstripe beside.
		float x = abs(p.x);
		vec3 col = mix(base, camo_b, step(x, 0.16) * step(0.06, x));
		return mix(col, camo_c, step(abs(x - 0.26), 0.02) * step(0.0, p.y + 0.2));
	}
	if (pattern == 6) {
		// Hornet: diagonal hazard stripes, wider toward the tail.
		float d = fract((p.z * 0.8 + p.y * 0.6) * 1.6);
		return mix(base, camo_b, step(0.5, d));
	}
	if (pattern == 7) {
		// Sunset: a gradient from the belly up, with a band where the sun sits.
		float t = smoothstep(-0.8, 1.0, p.y + fbm(q * 0.6) * 0.15);
		vec3 col = mix(base, camo_b, t);
		col = mix(col, camo_c, smoothstep(0.75, 1.0, t));
		return mix(col, camo_d, step(abs(p.y - 0.15), 0.03));
	}
	if (pattern == 8) {
		// Checkerboard, 30 cm squares.
		vec3 c = floor(q / 0.3);
		return mod(c.x + c.y + c.z, 2.0) < 1.0 ? base : camo_b;
	}
	if (pattern == 9) {
		// Dazzle: bold bands at clashing angles, a new angle and width in every zone, as
		// warships wore to break up their outline.
		vec3 zone = floor(q * 0.45);
		float h = hash(zone + 0.5);
		float angle = h * 3.14159;
		float band = fract(dot(q.zy, vec2(cos(angle), sin(angle))) * (1.1 + h * 1.6) + q.x * 0.3);
		vec3 col = band < 0.5 ? base : camo_b;
		return hash(zone + 5.5) > 0.6 ? mix(col, camo_c, step(band, 0.22)) : col;
	}
	if (pattern == 10) {
		// Hex: a honeycomb of 16 cm cells on the side view, a few filled in, dark rims.
		vec2 uv = vec2(q.z + q.x * 0.5, q.y + q.x * 0.35) / 0.16;
		vec2 r = vec2(1.0, 1.7320508);
		vec2 a = mod(uv, r) - r * 0.5;
		vec2 b = mod(uv - r * 0.5, r) - r * 0.5;
		vec2 cell = dot(a, a) < dot(b, b) ? a : b;
		vec2 id = uv - cell;
		float d = max(abs(cell.x), dot(abs(cell), vec2(0.5, 0.8660254)));
		vec3 col = hash(vec3(id, 3.0)) > 0.72 ? camo_b : base;
		col = hash(vec3(id, 7.0)) > 0.93 ? camo_d : col;
		return mix(col, camo_c, smoothstep(0.44, 0.47, d));
	}
	return base;
}

void vertex() {
	obj_pos = VERTEX;
	obj_normal = NORMAL;
}

void fragment() {
	vec3 an = abs(obj_normal);
	// Project panels onto the plane the surface mostly faces; Z (length) first.
	vec2 uv = an.x > an.y ? vec2(obj_pos.z, obj_pos.y) : vec2(obj_pos.z, obj_pos.x);
	vec2 cell = uv / panel_size;
	// Stagger alternate rows like real skin panels.
	cell.x += step(0.5, fract(cell.y * 0.5)) * 0.37;
	vec2 f = abs(fract(cell) - 0.5);
	float seam = smoothstep(0.484, 0.495, max(f.x, f.y));
	// Rivets: a row of dots just inside each seam.
	vec2 rv = uv / 0.075;
	float along_x = smoothstep(0.455, 0.462, f.y) * (1.0 - smoothstep(0.468, 0.475, f.y));
	float along_y = smoothstep(0.455, 0.462, f.x) * (1.0 - smoothstep(0.468, 0.475, f.x));
	float dots_x = 1.0 - smoothstep(0.18, 0.3, length(vec2(fract(rv.x) - 0.5, 0.0)));
	float dots_y = 1.0 - smoothstep(0.18, 0.3, length(vec2(fract(rv.y) - 0.5, 0.0)));
	float rivet = max(along_x * dots_x, along_y * dots_y);

	// Wear: chips cluster where a big noise is high, broken up by fine noise.
	float n_big = fbm(obj_pos * 1.3);
	float n_fine = noise(obj_pos * 18.0);
	float chip = smoothstep(1.0 - wear * 0.55, 1.0 - wear * 0.45, n_big * 0.75 + n_fine * 0.35 + seam * 0.2);
	float dirt = clamp(smoothstep(0.3, -1.1, obj_pos.y) * 0.6 + fbm(obj_pos * 4.0) * 0.25, 0.0, 1.0);
	// Soot streaks behind the exhaust stacks (they sit above and behind the cabin).
	float soot = smoothstep(1.4, 2.2, obj_pos.z) * smoothstep(0.2, 0.7, obj_pos.y)
		* (1.0 - smoothstep(0.6, 1.1, abs(obj_pos.x))) * (0.6 + 0.4 * noise(obj_pos * vec3(6.0, 6.0, 1.0)));

	vec3 col = mix(camo(obj_pos, paint) * (0.92 + n_fine * 0.12), bare_metal, chip);
	col = mix(col, grime, dirt * 0.45 + soot * 0.7);
	col *= 1.0 - seam * 0.45;
	col = mix(col, seam_color, seam * step(0.001, seam_glow + length(seam_color)));
	ALBEDO = col;
	EMISSION = seam_color * seam * seam_glow;
	METALLIC = mix(paint_metal, 0.85, chip);
	ROUGHNESS = mix(1.0 - paint_gloss, 0.35, chip) + dirt * 0.2;

	// Bump from seams (sunken) and rivets (raised) via screen-space derivatives.
	float h = rivet * 0.8 - seam * 1.0 - chip * 0.25;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	float dhdx = dFdx(h);
	float dhdy = dFdy(h);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dhdx * r1 + dhdy * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad * 0.004);
}
