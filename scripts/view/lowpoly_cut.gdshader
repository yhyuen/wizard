// The low-poly shader for the town chunks on the line of sight (see lowpoly.gdshader): with the
// dithered cutaway, back faces culled.
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

#define DISSOLVE
#include "res://scripts/view/lowpoly.gdshaderinc"
