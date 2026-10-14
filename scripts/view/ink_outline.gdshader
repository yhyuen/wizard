// The inked line round a character: the back faces pushed out a fixed number of pixels, so the
// line keeps its weight at any zoom. A mesh's vertex colour (red) scales it per part (thin at
// fingers and hems, heavy at hair and the silhouette); a little noise makes it wobble like a brush.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;

uniform vec4 color : source_color = vec4(0.05, 0.06, 0.09, 1.0);
uniform float width = 1.6;       // pixels at 900 px screen height
uniform float wobble = 0.35;
uniform float fade = 0.0;

float bayer4(vec2 p) {
	ivec2 q = ivec2(mod(p, 4.0));
	int i = q.x + q.y * 4;
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[i]) + 0.5) / 16.0;
}

void vertex() {
	float n = fract(sin(dot(floor(VERTEX * 40.0), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	float w = width * COLOR.r * (1.0 - wobble * 0.5 + wobble * n) * VIEWPORT_SIZE.y / 900.0;
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 nv = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec2 dir = (PROJECTION_MATRIX * vec4(nv, 0.0)).xy;
	float l = length(dir);
	if (l > 1e-5) {
		clip.xy += dir / l * w * clip.w * 2.0 / VIEWPORT_SIZE;
	}
	POSITION = clip;
}

void fragment() {
	ALBEDO = color.rgb;
	if (fade > 0.0 && bayer4(FRAGCOORD.xy) < fade) {
		discard;
	}
}
