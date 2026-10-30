shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never;
uniform vec4 flash_color : source_color = vec4(1.0,0.26,0.025,1.0);
uniform float intensity : hint_range(0.0,1.0) = 0.7;
void fragment(){ALBEDO=flash_color.rgb; ALPHA=intensity;}
