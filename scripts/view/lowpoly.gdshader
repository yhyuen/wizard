// Flat-shaded low-poly: every face takes one light value from its own normal (worked out from
// screen-space derivatives, so any mesh reads faceted however it was exported). A soft wrap and a
// cool rim keep figures off the ground; `glow` makes a surface emit its own colour (spell shapes).
// Hit flash, the beaten darkening and the dithered fade-out are per-instance uniforms.
// Works on the Compatibility renderer (the browser build).
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, specular_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform bool use_vcol = false;       // the ground: UV.x picks a kind colour, COLOR.r shades the face
uniform vec3 kind_cols[4];           // the ground's dirt, grass, hill and path colours
uniform float glow = 0.0;            // > 0: emits albedo * glow (blooms at dusk)
uniform float wrap = 0.25;           // how far round the light reaches
uniform vec4 rim_color : source_color = vec4(0.62, 0.72, 0.9, 1.0);
uniform float rim = 0.15;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash = 0.0;
uniform float darken = 0.0;
uniform float fade = 0.0;            // 0 = solid, 1 = gone (dithered, so it stays opaque)

varying vec3 vpos;

float bayer4(vec2 p) {
	ivec2 q = ivec2(mod(p, 4.0));
	int i = q.x + q.y * 4;
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[i]) + 0.5) / 16.0;
}

void vertex() {
	vpos = VERTEX;
}

void fragment() {
	// one normal per face
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	NORMAL = dot(n, VIEW) < 0.0 ? -n : n;  // whichever way the face was wound, it faces us
	vec3 c = albedo.rgb;
	if (use_vcol) {
		c = kind_cols[clamp(int(UV.x + 0.5), 0, 3)] * COLOR.r;
	}
	ALBEDO = c * (1.0 - darken);
	ROUGHNESS = 1.0;
	EMISSION = c * glow + flash_color.rgb * flash;
	if (fade > 0.0 && bayer4(FRAGCOORD.xy) < fade) {
		discard;
	}
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float k = clamp((ndl + wrap) / (1.0 + wrap), 0.0, 1.0);
	float shadow = mix(0.45, 1.0, ATTENUATION);
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * k * shadow;
	float r = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	DIFFUSE_LIGHT += rim_color.rgb * rim * r * k;
}
