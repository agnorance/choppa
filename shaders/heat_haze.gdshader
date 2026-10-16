// Heat shimmer: camera-facing puffs that bend whatever is behind them. Each particle's
// vertex colour alpha sets its strength (fades in and out over its life).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 0.004;

void vertex() {
	// Billboard that keeps the particle's scale.
	mat4 face = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	face = face * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0), vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0),
		vec4(0, 0, length(MODEL_MATRIX[2].xyz), 0), vec4(0, 0, 0, 1));
	MODELVIEW_MATRIX = VIEW_MATRIX * face;
}

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float fall = clamp(1.0 - dot(c, c), 0.0, 1.0);
	float t = TIME * 7.0;
	vec2 wobble = vec2(sin(UV.y * 23.0 + t + COLOR.r * 40.0), cos(UV.x * 19.0 - t * 1.3 + COLOR.g * 40.0));
	// Weaker when far away, so distant choppas don't smear the whole screen.
	float near = clamp(6.0 / max(-VERTEX.z, 1.0), 0.15, 1.0);
	vec2 offset = wobble * strength * fall * COLOR.a * near;
	ALBEDO = textureLod(screen, SCREEN_UV + offset, 0.0).rgb;
	ALPHA = smoothstep(0.0, 0.3, fall) * COLOR.a;
}
