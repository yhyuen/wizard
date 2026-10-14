// The sim's ground marks (telegraphs, previews, zones, effects and the reticle), drawn by the
// arena in 2D and laid on the ground as a decal. Telegraph colours stay exactly what the sim
// draws, so readability is unchanged; a dry-brush grain breaks up the edges so they read as
// ink rather than vector lines.
shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D marks : source_color, filter_linear_mipmap, repeat_disable;
uniform float dry = 0.35;   // how much the brush grain eats into faint marks
uniform float boost = 1.0;  // > 1 lets the marks glow at dusk

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec4 m = texture(marks, UV);
	// bristle streaks: noise stretched one way, so washes look brushed, not flat
	float g = vnoise(UV * vec2(900.0, 220.0)) * 0.6 + vnoise(UV * vec2(260.0, 60.0)) * 0.4;
	// strong marks (rings, telegraph edges) keep their full colour; faint fills get grainy
	float keep = mix(1.0 - dry + dry * g, 1.0, smoothstep(0.55, 0.9, m.a));
	ALBEDO = m.rgb * keep * boost;
	ALPHA = m.a * keep;
}
