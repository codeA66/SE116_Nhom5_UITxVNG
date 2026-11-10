shader_type spatial;
render_mode world_vertex_coords;
uniform bool stone = false;
uniform bool range_only = false;
uniform vec4 earth_color : source_color = vec4(0.22, 0.17, 0.12, 1.0);
uniform vec4 stone_color : source_color = vec4(0.31, 0.30, 0.23, 1.0);
uniform int dirt_layout : hint_range(0, 5) = 0;
uniform vec2 room_origin = vec2(0.0);
uniform vec2 map_offset = vec2(0.0);
uniform vec2 room_half_size = vec2(16.0);
varying vec3 world_position;
varying vec3 world_normal;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
 vec2 cell = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
 return mix(mix(hash(cell),hash(cell+vec2(1,0)),f.x),mix(hash(cell+vec2(0,1)),hash(cell+vec2(1,1)),f.x),f.y);
}
float dirt_mask(vec2 p) {
 vec2 q = (p-room_origin)/room_half_size;
 float rough = (noise(p*0.75)-0.5)*0.037+(noise(p*2.1)-0.5)*0.012;
 float edge = -2.0;
 if (dirt_layout == 1) {
  edge = max(max(-q.x-q.y-1.21,q.x-q.y-1.30),max(-q.x+q.y-1.34,q.x+q.y-1.40));
 } else if (dirt_layout == 2) {
  edge = max(abs(q.x)-0.85,q.y-0.82);
  // Khu bắn sao luôn lát gạch, kể cả biên nhiễu của mảng đất.
  if (abs(p.x-room_origin.x)<12.5 && p.y-room_origin.y<7.1 && p.y-room_origin.y>-13.8) edge = -2.0;
 } else if (dirt_layout == 3) {
  edge = max(-q.x-q.y-1.18,q.x-q.y-1.18);
  if (abs(q.x)<0.29) edge = -2.0;
 } else if (dirt_layout == 4) {
  // Thu gọn mũi đất cạnh cửa đi sang phòng ngoài cùng bên phải.
  float top = q.x < -0.45 ? mix(-0.35,-0.82,(q.x+1.0)/0.55) : q.x < 0.0 ? mix(-0.82,-0.20,(q.x+0.45)/0.45) : q.x < 0.55 ? mix(-0.20,-0.67,q.x/0.55) : mix(-0.67,-0.82,(q.x-0.55)/0.45);
  float bottom = q.x < -0.45 ? mix(0.32,0.82,(q.x+1.0)/0.55) : q.x < 0.0 ? mix(0.82,0.28,(q.x+0.45)/0.45) : q.x < 0.55 ? mix(0.28,0.80,q.x/0.55) : mix(0.80,0.40,(q.x-0.55)/0.45);
  edge = max(top-q.y-0.09,q.y-bottom-0.09);
 } else if (dirt_layout == 5) {
  edge = 0.45-abs(q.x)-abs(q.y);
 }
 float aa = max(fwidth(edge),0.002);
 return smoothstep(-aa,aa,edge+rough);
}
void vertex() { world_position = VERTEX; world_normal = NORMAL; }
void fragment() {
 vec2 p = world_position.xz-map_offset;
 vec2 cell = floor(p / 1.9);
 float variation = hash(cell);
 vec3 ground = earth_color.rgb * (0.90 + 0.2 * variation);
 bool inside_range = p.x > -43.0 && p.x < -21.0 && p.y > -5.0 && p.y < 13.3;
 if (stone && world_normal.y > 0.5 && (!range_only || inside_range)) {
  vec2 uv = fract(p / 1.9);
  float distance_edge = min(min(uv.x, 1.0-uv.x), min(uv.y,1.0-uv.y));
  float aa = max(fwidth(distance_edge), 0.001);
  float tile = smoothstep(0.018-aa,0.018+aa,distance_edge);
  ground = mix(ground, stone_color.rgb * (0.85 + variation*0.25), tile);
  if (dirt_layout > 0) {
   // Hạt đất và mặt vụn sắc nét trong world space; giảm chi tiết dưới một pixel để tránh nhấp nháy.
   vec2 gravel = p*9.0;
   vec2 facet_cell = floor(gravel);
   float facet = hash(facet_cell+vec2(step(1.0,fract(gravel).x+fract(gravel).y)));
   float detail = hash(floor(p*48.0));
   float visibility = 1.0-smoothstep(0.55,1.4,max(fwidth(p.x*48.0),fwidth(p.y*48.0)));
   float grain = mix(0.5,detail,visibility);
   vec3 soil = earth_color.rgb * (0.82+facet*0.25+grain*0.13);
   ground = mix(ground,soil,dirt_mask(p));
  }
 }
 ALBEDO = ground;
 ROUGHNESS = 1.0;
 SPECULAR = 0.05;
}
