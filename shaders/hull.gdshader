// Painted metal hull: panel seams and rivet rows in object space (no UVs needed),
// chipped paint showing bare metal, grime toward the belly, soot behind the exhausts.
shader_type spatial;

uniform vec3 paint : source_color = vec3(0.42, 0.45, 0.3);
uniform vec3 bare_metal : source_color = vec3(0.6, 0.6, 0.58);
uniform vec3 grime : source_color = vec3(0.18, 0.15, 0.12);
uniform float wear : hint_range(0.0, 1.0) = 0.28;
uniform vec2 panel_size = vec2(1.35, 0.75);  // Along the length, around the body (metres).

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

	vec3 col = mix(paint * (0.92 + n_fine * 0.12), bare_metal, chip);
	col = mix(col, grime, dirt * 0.45 + soot * 0.7);
	col *= 1.0 - seam * 0.45;
	ALBEDO = col;
	METALLIC = mix(0.15, 0.85, chip);
	ROUGHNESS = mix(0.62, 0.35, chip) + dirt * 0.2;

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
