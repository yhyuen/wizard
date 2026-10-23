// A soft glow around a spell: a camera-facing disc added on top of the scene, brightest in the
// middle. Kept apart from the solid shapes so they keep their colour while the air round them
// shines (the Magicka look). Strength above 1 crosses the bloom threshold.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0);
uniform float strength = 1.0;
// In a MultiMesh (spells3d.gd batches every halo of a frame), each halo's colour, linear and
// already times its strength, is its custom data instead.
uniform bool batched = false;
varying vec3 tint;

void vertex() {
	tint = batched ? INSTANCE_CUSTOM.rgb : color.rgb * strength;
	// face the camera, keeping the node's scale
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
}

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float a = clamp(1.0 - d, 0.0, 1.0);
	a = a * a * (0.6 + 0.4 * a);
	ALBEDO = tint * a;
}
