// The sim's flat telegraphs (rings, cones, lines, hold-to-aim previews, the reticle), drawn by
// the arena in 2D and laid on the ground as a decal, so each stays exactly its hitbox. Colours
// are what the sim draws; `boost` lets them glow a little at dusk.
shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D marks : source_color, filter_linear_mipmap, repeat_disable;
uniform float boost = 1.0;

void fragment() {
	vec4 m = texture(marks, UV);
	ALBEDO = m.rgb * boost;
	ALPHA = m.a;
}
