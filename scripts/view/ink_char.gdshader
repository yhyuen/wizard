// Ink-figure shading for characters (CharVisual, visuals.json "shader": "ink").
// Two light steps instead of a smooth falloff, a faint paper grain, and a cool rim so a figure
// separates from the ground. Works on the compatibility renderer (the browser build).
// Hit flash, the beaten darkening and the dithered fade-out are uniforms set per instance.
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform bool use_tex = false;
uniform float band = 0.04;      // where light turns to shadow (n.l)
uniform float high = 0.62;      // where the mid tone turns to full light
uniform float mid = 0.62;       // brightness of the mid step
uniform float soft = 0.045;     // width of each step's edge
uniform float grain = 0.06;     // paper grain
uniform vec4 rim_color : source_color = vec4(0.62, 0.72, 0.9, 1.0);
uniform float rim = 0.22;
uniform vec4 flash_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float flash = 0.0;
uniform float darken = 0.0;
uniform float fade = 0.0;       // 0 = solid, 1 = gone (dithered, so it stays opaque)
uniform int face = 0;           // face tile: 0 calm, 1 fierce, 2 hurt, 3 eyes shut
uniform float skin_soft = 0.3;  // edge width of the light steps on skin (vertex colour blue 0)
uniform float skin_wrap = 0.15;  // how much further round skin stays lit
uniform vec4 skin_warm : source_color = vec4(0.5, 0.16, 0.08, 1.0);  // light bleeding past skin's terminator

// 1 = the hard ink steps (cloth, and every mesh without vertex colours), 0 = soft skin
varying float hard;

void vertex() {
	hard = COLOR.b;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float bayer4(vec2 p) {
	ivec2 q = ivec2(mod(p, 4.0));
	int i = q.x + q.y * 4;
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[i]) + 0.5) / 16.0;
}

void fragment() {
	vec2 uv = UV;
	// the face row of the atlas holds four expressions side by side
	if (uv.y > 0.5 && uv.y < 0.75 && uv.x < 0.25) {
		uv.x += 0.25 * float(face);
	}
	vec4 c = use_tex ? texture(tex, uv) * albedo : albedo;
	float g = hash(floor(FRAGCOORD.xy * 0.5)) * 0.6 + hash(floor(FRAGCOORD.xy * 0.125)) * 0.4;
	ALBEDO = c.rgb * (1.0 - grain * g) * (1.0 - darken);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = flash_color.rgb * flash;
	if (fade > 0.0 && bayer4(FRAGCOORD.xy) < fade) {
		discard;
	}
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float shadow = smoothstep(0.25, 0.6, ATTENUATION);
	// a cast shadow only takes away the top step, so a hat's shadow on a face reads as a soft
	// mid tone rather than a hard dark patch
	float sf = mix(skin_soft, soft, hard);
	float b = band - skin_wrap * (1.0 - hard);  // skin wraps the light a little further round
	float lo = smoothstep(b - sf, b + sf, ndl) * mix(1.0, shadow, 0.35);
	float hi = smoothstep(high - sf, high + sf, ndl) * shadow;
	float k = lo * mid + hi * (1.0 - mid);
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * k;
	// skin: a little warm light where it turns into shadow, as light scatters under it
	float term = smoothstep(b - 0.35, b, ndl) * (1.0 - smoothstep(b, b + 0.4, ndl));
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * skin_warm.rgb * term * (1.0 - hard);
	float r = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	DIFFUSE_LIGHT += rim_color.rgb * rim * smoothstep(0.35, 0.6, r) * (0.4 + 0.6 * lo);
}
