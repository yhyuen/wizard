// A lamp's pool of warm light on the ground, faked: an additive quad that fades from the centre.
// Costs one draw for every lamp in the town together, where a real light would re-draw every
// mesh it touches in the browser renderer.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float strength = 0.5;

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float k = pow(clamp(1.0 - d, 0.0, 1.0), 2.2);
	ALBEDO = COLOR.rgb * k * strength;
}
