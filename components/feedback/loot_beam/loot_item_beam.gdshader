shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color = vec4(1.0,0.8,0.15,1.0);
uniform float opacity = 0.2;
uniform float energy = 1.5;
void fragment() {
 float fade = smoothstep(0.0,0.24,UV.y);
 float pulse = 0.86 + 0.14*sin(TIME*2.5);
 ALBEDO = tint.rgb;
 EMISSION = tint.rgb*energy;
 ALPHA = opacity*fade*pulse;
}
