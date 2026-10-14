// The yard's ground: an ink wash on paper rather than a tile grid (the Wuxia ground, trimmed to
// what the Mill needs). Two tones blotch together with a brushed streak and fine grain; dirt,
// grass and wet patches and paths lie over it with ragged edges; past the yard it fades to ink.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform vec3 base_col : source_color;
uniform vec3 wash_col : source_color;
uniform vec3 dirt_col : source_color;
uniform vec3 grass_col : source_color;
uniform vec3 wet_col : source_color;
uniform vec3 ink_col : source_color;
uniform float grain = 1.0;
uniform vec2 half_size = vec2(14.0, 8.0);  // the yard, in metres from its centre
uniform vec2 seed = vec2(31.0, 77.0);
uniform int seg_n = 0;
uniform vec4 segs[16];      // path segments: a.xy, b.xy (metres)
uniform vec4 seg_info[16];  // x = width, y = kind (0 dirt, 1 grass, 2 wet)
uniform int patch_n = 0;
uniform vec4 patches[16];   // x, z, radius, kind
varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
vec2 hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) { s += a * vnoise(p); p = p * 2.03 + vec2(17.1, 9.2); a *= 0.5; }
	return s / 0.9375;
}
float seg_dist(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-4), 0.0, 1.0);
	return length(p - a - ab * t);
}
vec3 onehot(float k) { return vec3(equal(vec3(k), vec3(0.0, 1.0, 2.0))); }

void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	vec2 p = wpos.xz + seed;
	float big = fbm(p * 0.06);
	float mid = fbm(p * 0.27 + 3.1);
	float fine = vnoise(p * 3.1);
	float streak = fbm(vec2(p.x * 0.05, p.y * 0.42) + 7.7);

	vec3 col = mix(base_col, wash_col, smoothstep(0.32, 0.72, big));
	col *= 0.9 + 0.2 * streak;
	col *= 1.0 + (mid - 0.5) * 0.18 * grain + (fine - 0.5) * 0.1 * grain;

	float wob = vnoise(p * 0.55 + 11.0) - 0.5;
	float speck = vnoise(p * 4.2 + 2.0) - 0.5;
	vec3 cov = vec3(0.0);
	for (int i = 0; i < seg_n; i++) {
		vec4 s = segs[i];
		vec4 info = seg_info[i];
		float half_w = info.x * 0.5;
		float feather = 0.3 + info.x * 0.22;
		float d = seg_dist(wpos.xz, s.xy, s.zw) + wob * info.x * 0.3;
		cov = max(cov, onehot(info.y) * (1.0 - smoothstep(half_w - feather, half_w + feather, d)));
	}
	for (int i = 0; i < patch_n; i++) {
		vec4 q = patches[i];
		float d = length(wpos.xz - q.xy) + (wob * 0.6 + (big - 0.5) * 0.8) * q.z;
		cov = max(cov, onehot(q.w) * (1.0 - smoothstep(q.z * 0.55, q.z * 1.1, d)));
	}
	cov = clamp(cov + speck * 0.55 * cov * (1.0 - cov) * 4.0, 0.0, 1.0);

	float blade = vnoise(vec2(p.x * 9.0 + p.y * 3.0, p.y * 5.0)) * 0.6 + vnoise(p * 2.3 + 5.0) * 0.4;
	vec3 grass = grass_col * (0.92 + 0.18 * smoothstep(0.5, 0.8, blade) - 0.08 * smoothstep(0.5, 0.25, blade));
	grass *= 0.9 + 0.22 * smoothstep(0.3, 0.8, big);
	col = mix(col, grass, cov.y);

	vec2 gc = p * 7.0;
	vec2 go = hash2(floor(gc)) * 0.5 + 0.25;
	float grit = step(0.9, hash(floor(gc) + 4.3)) * (1.0 - smoothstep(0.06, 0.16, length(fract(gc) - go))) * 0.5;
	vec3 dirt = dirt_col * (0.9 + 0.16 * mid + 0.06 * (fine - 0.5) + grit * 0.25);
	dirt *= 0.94 + 0.1 * smoothstep(0.55, 1.0, cov.x);
	col = mix(col, dirt, cov.x * 0.92);

	col = mix(col, wet_col * (0.85 + 0.3 * mid), cov.z);

	// Past the yard the ground fades into ink, not a grid to the horizon.
	vec2 q = abs(wpos.xz) / half_size;
	float r = max(q.x, q.y) + (big - 0.5) * 0.35;
	col = mix(col, ink_col, smoothstep(1.0, 1.6, r) * 0.85);

	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.75, cov.z);
}
