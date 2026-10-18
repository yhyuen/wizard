// The low-poly shader without the dissolve (see lowpoly.gdshader): for the ground, props and
// the town chunks away from the line of sight.
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

#include "res://scripts/view/lowpoly.gdshaderinc"
