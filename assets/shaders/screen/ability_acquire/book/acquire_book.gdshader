shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 base_color : source_color = vec4(0.6,0.5,0.4,1);
uniform vec4 accent : source_color = vec4(0.65,0.88,0.94,1);
uniform float dissolve = 0.0;
uniform float grain_scale = 25.0;
uniform float edge_width = 0.075;
varying vec3 position_local;
void vertex() { position_local = VERTEX; }
void fragment() {
	float grain = fract(sin(dot(floor(position_local*grain_scale),vec3(12.9898,78.233,37.719)))*43758.5453);
	float edge = 1.0-smoothstep(0.0,edge_width,grain-dissolve);
	ALBEDO = mix(base_color.rgb,accent.rgb,edge);
	ALPHA = smoothstep(dissolve-edge_width,dissolve,grain)*(1.0-step(0.999,dissolve));
}
