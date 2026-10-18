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
// Three variants share the body (lowpoly.gdshaderinc). This one, for figures, can fade (which
// needs `discard`) and draws both sides of every face, as the imported models expect.
// lowpoly_cut.gdshader is for the town chunks on the line of sight: the cutaway, back faces
// culled. lowpoly_solid.gdshader is for everything else: no `discard` (a shader with one loses
// the early depth test, so every hidden pixel behind it gets shaded too) and back faces culled
// (closed low-poly shapes never show them, and drawing them doubled the town's pixel work).
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

#define DISSOLVE
#include "res://scripts/view/lowpoly.gdshaderinc"
