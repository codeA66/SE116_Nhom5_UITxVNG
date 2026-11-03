shader_type spatial;
render_mode cull_disabled;
uniform float dissolve : hint_range(0.0,1.0) = 0.0;
uniform bool banner = false;
uniform sampler2D banner_texture : source_color;
uniform vec4 wood_color : source_color = vec4(0.27,0.13,0.055,1.0);
uniform vec4 edge_color : source_color = vec4(1.0,0.65,0.19,1.0);
varying vec3 object_position;
float cell_noise(vec3 p) { return fract(sin(dot(p,vec3(12.9898,78.233,37.719)))*43758.5453); }
void vertex() { object_position = VERTEX; }
void fragment() {
 // Cùng trường dissolve hướng xuyên tâm của cửa Tier 2.
 float radial = distance(object_position.xy,vec2(0.0,1.58))/3.2;
 float pattern = radial*0.72 + cell_noise(floor(object_position*7.0))*0.28;
 float threshold = dissolve*1.4-0.2;
 if (pattern < threshold) discard;
 float edge = (1.0-smoothstep(threshold,threshold+0.07,pattern))*step(0.01,dissolve);
 float grain = 0.85 + 0.10*sin(object_position.x*70.0 + sin(object_position.y*5.0)*0.8);
 vec3 base = banner ? texture(banner_texture,UV).rgb*0.65 : wood_color.rgb*grain;
 ALBEDO = mix(base,edge_color.rgb,edge*0.65);
 ROUGHNESS = 0.95;
 SPECULAR = 0.12;
 EMISSION = edge_color.rgb*edge*2.6;
}
