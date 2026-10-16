// Terrain splatting: grass, dirt and sand on flat ground (top projection), sandstone
// cliffs on steep slopes (triplanar, so the strata stay horizontal). Two texture scales
// and a macro noise hide tiling.
shader_type spatial;

uniform sampler2D grass_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cliff_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cliff_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D macro_noise : filter_linear_mipmap, repeat_enable;

uniform float ground_scale = 0.15;  // Texture repeats per metre on the ground.
uniform float cliff_scale = 0.08;
uniform float water_level = -2.5;
uniform float cliff_slope = 0.38;  // 1 - normal.y where rock takes over.
uniform vec3 strata_tint : source_color = vec3(0.86, 0.72, 0.66);

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 unpack(vec4 t) {
	return t.xyz * 2.0 - 1.0;
}

// Ground textures, sampled at two scales and blended to hide repetition.
vec3 ground_tex(sampler2D tex, vec2 uv, float mixer) {
	vec3 a = texture(tex, uv).rgb;
	vec3 b = texture(tex, uv * 0.37 + vec2(0.31, 0.77)).rgb;
	return mix(a, b, mixer);
}

vec3 ground_nrm(sampler2D tex, vec2 uv, float mixer) {
	vec3 a = unpack(texture(tex, uv));
	vec3 b = unpack(texture(tex, uv * 0.37 + vec2(0.31, 0.77)));
	return normalize(mix(a, b, mixer));
}

void fragment() {
	vec3 n = normalize(world_normal);
	float slope = 1.0 - n.y;
	vec2 uv = world_pos.xz * ground_scale;
	float macro = texture(macro_noise, world_pos.xz * 0.0035).r;
	float macro2 = texture(macro_noise, world_pos.xz * 0.019 + vec2(0.5)).r;
	float mixer = smoothstep(0.3, 0.7, macro2);

	// Weights.
	float rock_w = smoothstep(cliff_slope - 0.08, cliff_slope + 0.06, slope + (macro2 - 0.5) * 0.1);
	float sand_w = 1.0 - smoothstep(water_level + 0.8, water_level + 3.0, world_pos.y + (macro2 - 0.5) * 1.5);
	float dirt_w = clamp(smoothstep(0.12, 0.28, slope) + smoothstep(0.55, 0.75, macro) * 0.8, 0.0, 1.0);

	vec3 grass = ground_tex(grass_albedo, uv, mixer) * mix(vec3(1.05, 1.0, 0.85), vec3(0.85, 0.95, 0.8), macro);
	vec3 dirt = ground_tex(dirt_albedo, uv * 1.3, mixer);
	vec3 sand = ground_tex(sand_albedo, uv * 0.8, mixer);
	vec3 flat_col = mix(mix(grass, dirt, dirt_w), sand, sand_w);
	vec3 flat_n = normalize(mix(mix(ground_nrm(grass_normal, uv, mixer), ground_nrm(dirt_normal, uv * 1.3, mixer), dirt_w),
		ground_nrm(sand_normal, uv * 0.8, mixer), sand_w));

	// Triplanar cliffs.
	vec3 bw = pow(abs(n), vec3(4.0));
	bw /= (bw.x + bw.y + bw.z);
	vec3 p = world_pos * cliff_scale;
	vec2 uvx = vec2(p.z, -p.y);
	vec2 uvy = p.xz;
	vec2 uvz = vec2(p.x, -p.y);
	vec3 cx = texture(cliff_albedo, uvx).rgb;
	vec3 cy = texture(cliff_albedo, uvy).rgb;
	vec3 cz = texture(cliff_albedo, uvz).rgb;
	vec3 cliff = cx * bw.x + cy * bw.y + cz * bw.z;
	// Big strata bands on top of the texture's fine ones.
	float band = sin(world_pos.y * 0.45 + macro * 6.0) * 0.5 + 0.5;
	cliff *= mix(vec3(1.0), strata_tint, band * 0.6);
	cliff *= mix(0.85, 1.1, macro2);
	vec3 tx = unpack(texture(cliff_normal, uvx));
	vec3 ty = unpack(texture(cliff_normal, uvy));
	vec3 tz = unpack(texture(cliff_normal, uvz));
	// Whiteout blend into world space.
	tx = vec3(tx.xy + n.zy, abs(tx.z) * n.x);
	ty = vec3(ty.xy + n.xz, abs(ty.z) * n.y);
	tz = vec3(tz.xy + n.xy, abs(tz.z) * n.z);
	vec3 cliff_wn = normalize(tx.zyx * bw.x + ty.xzy * bw.y + tz.xyz * bw.z);

	// Flat textures are mapped along world X/Z: turn their tangent normal into world space.
	vec3 flat_wn = normalize(vec3(flat_n.x + n.x, abs(flat_n.z) * n.y, flat_n.y + n.z));

	vec3 wn = normalize(mix(flat_wn, cliff_wn, rock_w));
	ALBEDO = mix(flat_col, cliff, rock_w);
	ROUGHNESS = mix(0.92, 0.85, rock_w);
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
}
