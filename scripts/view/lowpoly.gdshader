// Low-poly shapes under real-feeling light (the moody-night look, GDD 6.3). `facet` 1 gives every
// face one light value from its own normal (worked out from screen-space derivatives); 0 keeps the
// smooth vertex normal. On top of that, per finish: a bump from a shared noise normal map
// projected from the three world axes (so code-made meshes need no UVs or tangents), albedo
// mottling from a shared noise, and an optional specular highlight. A soft wrap and a cool rim
// keep figures off the ground; `vcol_albedo` takes the colour from the vertices, for the town's
// merged meshes;
// `glow` makes a surface emit its own colour (spell shapes).
// Hit flash, the beaten darkening and the dithered fade-out are per-instance uniforms.
// Works on the Compatibility renderer (the browser build).
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform vec4 albedo : source_color = vec4(1.0);
uniform bool use_vcol = false;       // the ground: UV.x picks a kind colour, COLOR.r shades the face
uniform vec3 kind_cols[4];           // the ground's dirt, grass, hill and path colours
uniform bool vcol_albedo = false;    // merged scenery: COLOR.rgb (linear) is the colour
uniform float glow = 0.0;            // > 0: emits albedo * glow (blooms at night)
uniform float facet = 1.0;           // 1 = flat faces, 0 = smooth
uniform float wrap = 0.25;           // how far round the light reaches
uniform vec4 rim_color : source_color = vec4(0.62, 0.72, 0.9, 1.0);
uniform float rim = 0.15;
uniform float bump = 0.0;            // procedural bump strength
uniform float bump_scale = 0.5;      // noise texture repeats per metre
uniform sampler2D bump_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D mottle_tex : filter_linear_mipmap, repeat_enable;
uniform float mottle = 0.0;          // albedo variation from the same noise
uniform float spec = 0.0;            // specular strength
uniform float gloss = 24.0;          // specular exponent
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash = 0.0;
uniform float darken = 0.0;
uniform float fade = 0.0;            // 0 = solid, 1 = gone (dithered, so it stays opaque)
// The open world's cutaway: walls and roofs between the camera and the wizard dissolve in a
// dithered cylinder round the line of sight, so the close camera never loses you behind a house.
uniform float cut = 0.0;             // 0 off .. 1 on
uniform vec3 cut_cam = vec3(0.0);    // the camera, in world space
uniform vec3 cut_at = vec3(0.0);     // the wizard's chest, in world space
uniform float cut_r = 1.8;           // metres round the line of sight

varying vec3 wpos;
varying vec3 wnrm;

float bayer4(vec2 p) {
	ivec2 q = ivec2(mod(p, 4.0));
	int i = q.x + q.y * 4;
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[i]) + 0.5) / 16.0;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// one normal per face, blended with the smooth one
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	n = dot(n, VIEW) < 0.0 ? -n : n;  // whichever way the face was wound, it faces us
	vec3 sn = dot(NORMAL, VIEW) < 0.0 ? -NORMAL : NORMAL;
	vec3 N = normalize(mix(sn, n, facet));
	vec3 b = pow(abs(wnrm), vec3(4.0));
	b /= b.x + b.y + b.z;
	vec3 q = wpos * bump_scale;
	float h = 0.5;
	if (mottle > 0.0) {
		h = texture(mottle_tex, q.zy).r * b.x + texture(mottle_tex, q.xz).r * b.y + texture(mottle_tex, q.xy).r * b.z;
	}
	if (bump > 0.0) {
		// each axis' normal-map tilt, laid onto that plane in world space, then back to view space
		vec2 tx = texture(bump_tex, q.zy).xy * 2.0 - 1.0;
		vec2 ty = texture(bump_tex, q.xz).xy * 2.0 - 1.0;
		vec2 tz = texture(bump_tex, q.xy).xy * 2.0 - 1.0;
		vec3 d = vec3(0.0, tx.y, tx.x) * b.x + vec3(ty.x, 0.0, ty.y) * b.y + vec3(tz.x, tz.y, 0.0) * b.z;
		N = normalize(N + (VIEW_MATRIX * vec4(d * bump, 0.0)).xyz);
	}
	NORMAL = N;
	vec3 c = albedo.rgb;
	if (use_vcol) {
		c = kind_cols[clamp(int(UV.x + 0.5), 0, 3)] * COLOR.r;
	} else if (vcol_albedo) {
		c = COLOR.rgb * albedo.rgb;
	}
	c *= 1.0 - mottle + mottle * 2.0 * h;
	ALBEDO = c * (1.0 - darken);
	ROUGHNESS = 1.0;
	EMISSION = c * glow + flash_color.rgb * flash;
	if (fade > 0.0 && bayer4(FRAGCOORD.xy) < fade) {
		discard;
	}
	if (cut > 0.0 && wpos.y > 0.35) {
		vec3 ray = cut_at - cut_cam;
		float len = length(ray);
		float t = dot(wpos - cut_cam, ray) / (len * len);
		if (t > 0.0 && t < 1.0 - 0.6 / len) {
			float d = length(wpos - (cut_cam + ray * t));
			float k = cut * (1.0 - smoothstep(cut_r * 0.55, cut_r, d)) * smoothstep(0.0, 0.25, 1.0 - t);
			if (bayer4(FRAGCOORD.xy) < k) {
				discard;
			}
		}
	}
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float k = clamp((ndl + wrap) / (1.0 + wrap), 0.0, 1.0);
	// the moon's shadows only darken so far; lamps and spells fall off with distance
	float shadow = LIGHT_IS_DIRECTIONAL ? mix(0.35, 1.0, ATTENUATION) : ATTENUATION;
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * k * shadow;
	float r = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	DIFFUSE_LIGHT += rim_color.rgb * rim * r * k;
	if (spec > 0.0) {
		vec3 hv = normalize(LIGHT + VIEW);
		float s = pow(clamp(dot(NORMAL, hv), 0.0, 1.0), gloss) * clamp(ndl, 0.0, 1.0);
		SPECULAR_LIGHT += LIGHT_COLOR * spec * s * ATTENUATION;
	}
}
