shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 base_color : source_color = vec4(0.6,0.5,0.4,1);
uniform vec4 accent : source_color = vec4(0.65,0.88,0.94,1);
uniform float dissolve = 0.0;
uniform float grain_scale = 25.0;
uniform float edge_width = 0.075;
uniform vec2 fade_range = vec2(0.15,0.90);
uniform float edge_strength = 0.12;
uniform float height_min = 0.0;
uniform float height_span = 1.0;
varying vec3 position_local;
void vertex() { position_local = VERTEX; }
void fragment() {
	float fade = smoothstep(fade_range.x,max(fade_range.y,fade_range.x+0.001),dissolve);
	float height = clamp((position_local.y-height_min)/max(height_span,0.0001),0.0,1.0);
	float front = fade+sin(position_local.x*grain_scale)*0.01;
	float edge = (1.0-smoothstep(0.0,max(edge_width,0.001),abs(height-front)))*sin(fade*3.141593);
	ALBEDO = mix(base_color.rgb,accent.rgb,edge*edge_strength);
	ALPHA = 1.0-fade;
}
