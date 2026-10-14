shader_type spatial;
// Ink-brush skill effects on the ground (scripts/fx.gd sets the uniforms each frame).
// Meshes come from scripts/geo.gd with UV.x along the stroke (angle or length) and UV.y across
// it (inner -> outer radius, or one side -> the other). The visible shape never goes past the
// mesh, so the mesh is the hit area: the effect can look like ink and still read true.
//   mode 0 wash:   a mottled ink wash over the whole area, deepest at the edge it reaches.
//   mode 1 sweep:  a brush stroke laid down along UV.x, hugging the outer edge (cones, circles).
//   mode 2 edge:   a thin dry-brush line (the exact reach).
//   mode 3 thrust: a centred stroke along UV.x that narrows to a point at the tip (lines).
//   mode 4 splat:  an ink blot with a ragged rim (a disc, UV.y = radius).
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

uniform vec4 col : source_color = vec4(1.0);
uniform int mode = 0;
uniform float alpha = 1.0;
uniform float prog = 1.0;   // how far along UV.x the brush has travelled (0..1)
uniform float fade = 0.0;   // 0 fresh .. 1 gone; ink breaks up as it dries instead of going see-through
uniform float seed = 0.0;
uniform float thick = 0.6;  // sweep/thrust: share of the band the stroke covers at its widest
uniform float rough = 1.0;  // how dry the brush is (gaps, ragged rims)
uniform float rep = 1.0;    // stroke length in brush widths, so long strokes keep fine bristles
uniform bool centred = false;  // wash: the area's edges are both sides of UV.y (a line), not UV.y = 1

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	return 0.55 * noise(p) + 0.3 * noise(p * 2.13 + 7.1) + 0.15 * noise(p * 4.7 + 3.3);
}

void fragment() {
	float u = UV.x;
	float v = UV.y;
	vec2 sp = vec2(seed * 3.7, seed * 1.9);
	float a = 0.0;
	vec3 c = col.rgb;
	// Drying: grains drop out as `fade` rises (dry-brush break-up, not a uniform fade).
	float grain = fbm(vec2(u * 9.0 * rep, v * 7.0) + sp);
	float dry = smoothstep(fade * 1.15 - 0.12, fade * 1.15, grain);

	if (mode == 0) {
		float m = fbm(vec2(u * 5.0 * rep, v * 3.0) + sp);
		float vv = centred ? abs(v - 0.5) * 2.0 : v;
		float deep = mix(0.45, 1.0, smoothstep(0.0, 1.0, vv));
		float edge = (centred ? 1.0 : smoothstep(0.0, 0.06, v)) * smoothstep(0.0, 0.02, u) * smoothstep(1.0, 0.98, u);
		a = deep * (0.55 + 0.6 * m) * edge;
	} else if (mode == 1 || mode == 3) {
		// The brush loads, presses, lifts: wide in the middle, thin at both ends. A thrust
		// swells from the hand and ends in a point at the tip.
		float uc = clamp(u, 0.0, 1.0);
		float env = mode == 1 ? pow(sin(3.14159 * uc), 0.45)
			: smoothstep(0.0, 0.3, uc) * pow(1.0 - uc, 0.3);
		float wob = fbm(vec2(u * 6.0 * rep, seed)) - 0.5;
		float w = thick * env * (0.85 + 0.3 * wob);
		float inside;
		if (mode == 1) {
			// Hug the outer edge (v = 1 is the reach); grow inward.
			inside = smoothstep(1.0 - w - 0.05, 1.0 - w + 0.02, v) * smoothstep(1.0, 0.985, v);
		} else {
			inside = 1.0 - smoothstep(w - 0.08, w, abs(v - 0.5) * 2.0);
		}
		// Bristle streaks run along the stroke.
		float br = noise(vec2(u * 2.0 * rep, v * 38.0) + sp);
		float bristle = mix(1.0, smoothstep(0.18, 0.5, br), rough * (0.35 + 0.65 * u));
		// Only what the brush has passed shows; its head is brighter and wetter.
		float head = smoothstep(prog + 0.02, prog - 0.06, u);
		float wet = smoothstep(prog - 0.25, prog, u) * step(prog, 0.999);
		c = mix(c, vec3(1.0), 0.35 * wet);
		a = inside * bristle * head;
	} else if (mode == 2) {
		float gap = noise(vec2(u * 26.0 * rep, seed));
		a = mix(1.0, smoothstep(0.15, 0.4, gap), rough) * smoothstep(0.0, 0.25, v) * smoothstep(1.0, 0.75, v);
		a *= smoothstep(prog + 0.02, prog - 0.04, u);
	} else {
		float rim = 1.0 - 0.45 * rough * fbm(vec2(u * 7.0, seed));
		a = smoothstep(rim, rim - 0.12, v);
		a *= 0.8 + 0.2 * noise(vec2(u * 11.0, v * 5.0) + sp);
	}
	ALBEDO = c;
	ALPHA = clamp(a * dry * alpha, 0.0, 1.0);
}
