shader_type spatial;
uniform vec4 dark_wood : source_color = vec4(0.17,0.105,0.046,1.0);
uniform vec4 light_wood : source_color = vec4(0.43,0.31,0.165,1.0);
uniform float edge_roughness : hint_range(0.0,0.15) = 0.09;
uniform bool upright = false;
varying vec3 timber_position;
varying vec3 timber_normal;
varying float worn_edge;
float hash(float p) { return fract(sin(p*127.1)*43758.5453); }
void vertex() {
 timber_position = VERTEX;
 timber_normal = NORMAL;
 vec2 face_uv = fract(UV*vec2(3.0,2.0));
 float edge_distance = min(min(face_uv.x,1.0-face_uv.x),min(face_uv.y,1.0-face_uv.y));
 worn_edge = 1.0-smoothstep(0.0,0.18,edge_distance);
 // Nhiễu theo vị trí dùng chung ở mép hai mặt: không tạo khe hở giữa các mặt gỗ.
 vec3 warp = vec3(sin(VERTEX.y*4.1+VERTEX.z*3.3),sin(VERTEX.x*3.2+VERTEX.z*3.9),sin(VERTEX.x*4.3+VERTEX.y*4.7));
 VERTEX += (warp*0.65-sign(VERTEX)*0.28)*edge_roughness*worn_edge;
}
void fragment() {
 vec3 n = abs(timber_normal);
 vec2 p = n.y>0.7 ? timber_position.xz : (n.x>0.7 ? timber_position.zy : timber_position.xy);
 if (upright && n.y<0.7) { p = p.yx; }
 float plank = floor((p.y+0.21)/0.42);
 float seed = hash(plank+3.0);
 float v = mod(p.y+0.21,0.42)-0.21;
 float fiber_warp = sin(p.x*1.8+seed*8.0)*0.025+sin(p.x*0.56+seed*3.0)*0.038;
 vec2 knot = vec2(mod(p.x+seed*3.6,3.6)-1.8,(v+fiber_warp)*3.5);
 float knot_radius = length(knot*vec2(2.2,1.0));
 float knot_influence = exp(-knot_radius*3.0);
 float fibers = (v+fiber_warp)*110.0+knot_influence*6.0;
 float thin_detail = 1.0-smoothstep(0.6,1.8,fwidth(fibers));
 float grain = mix(0.5,0.5+0.5*sin(fibers),thin_detail);
 float broad = sin((v+fiber_warp)*27.0+seed*7.0)*0.12;
 vec3 wood = mix(dark_wood.rgb,light_wood.rgb,clamp(0.42+grain*0.23+broad+seed*0.14,0.0,1.0));
 float knot_rings = sin(knot_radius*40.0)*0.5+0.5;
 wood *= 1.0-knot_influence*(0.22+0.18*knot_rings);
 float seam = smoothstep(0.0,0.012,0.21-abs(v));
 wood *= mix(0.40,1.0,seam);
 // Vết dao/rách thớ thưa, không dùng hoa văn lặp nổi bật.
 vec2 scar_uv = vec2(mod(p.x+seed*4.0,4.0)/4.0-0.5,v/0.42);
 float scar = (1.0-smoothstep(0.006,0.018,abs(scar_uv.x+scar_uv.y*0.10)))*(1.0-smoothstep(0.13,0.30,abs(scar_uv.y)))*step(0.70,seed);
 wood *= 1.0-scar*0.45;
 float weather = (sin(p.x*0.7+p.y*2.8)*0.5+0.5)*0.09+worn_edge*0.10;
 ALBEDO = mix(wood,vec3(0.43,0.36,0.24),weather);
 EMISSION = ALBEDO*0.12;
 ROUGHNESS = 0.97;
 SPECULAR = 0.06;
}
