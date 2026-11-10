shader_type spatial;
// Đường biên và màu lấy từ mesh logo gốc của garden_door_locked.glb, không qua texture raster.
uniform vec2 panel_size = vec2(8.0,5.8);
uniform float crest_height_ratio = 0.65;
varying vec3 panel_position;
varying vec3 panel_normal;
void vertex() { panel_position = VERTEX; panel_normal = NORMAL; }
float cross2(vec2 a, vec2 b) { return a.x*b.y-a.y*b.x; }
float triangle_coverage(vec2 p, vec2 a, vec2 b, vec2 c) {
 float winding = sign(cross2(b-a,c-a));
 float d = min(min(cross2(b-a,p-a)/length(b-a),cross2(c-b,p-b)/length(c-b)),cross2(a-c,p-c)/length(a-c));
 if (winding<0.0) { d = min(min(-cross2(b-a,p-a)/length(b-a),-cross2(c-b,p-b)/length(c-b)),-cross2(a-c,p-c)/length(a-c)); }
 float aa = max(max(fwidth(p.x),fwidth(p.y))*0.6,0.000001);
 return smoothstep(-aa,aa,d);
}
void fragment() {
 vec3 background = vec3(0.21568627,0.39607843,0.40000000);
 vec2 p = panel_position.xy / (panel_size.y*crest_height_ratio);
 if (panel_normal.z<0.0) { p.x = -p.x; }
 float coverage = 0.0;
 vec3 ink = vec3(0.0);
 float part = 0.0;
 part = triangle_coverage(p,vec2(-0.06242239,0.15217393),vec2(-0.08322984,-0.15217393),vec2(0.06935818,0.13043477)); coverage += part; ink += part*vec3(0.30980392,0.46274510,0.43137255);
 part = triangle_coverage(p,vec2(-0.00000003,-0.50000000),vec2(0.08322984,-0.15217393),vec2(-0.08322984,-0.15217393)); coverage += part; ink += part*vec3(0.30980392,0.46274510,0.43137255);
 part = triangle_coverage(p,vec2(0.08322984,-0.15217393),vec2(0.06935818,0.13043477),vec2(-0.08322984,-0.15217393)); coverage += part; ink += part*vec3(0.30980392,0.46274510,0.43137255);
 part = triangle_coverage(p,vec2(0.06935818,0.13043477),vec2(-0.00000003,0.50000000),vec2(-0.06242239,0.15217393)); coverage += part; ink += part*vec3(0.30980392,0.46274510,0.43137255);
 part = triangle_coverage(p,vec2(-0.15952385,0.19565225),vec2(-0.34679091,0.30434781),vec2(-0.29824015,-0.06521742)); coverage += part; ink += part*vec3(0.30980392,0.46274510,0.43137255);
 part = triangle_coverage(p,vec2(-0.05548653,-0.20652177),vec2(-0.02080748,-0.08695645),vec2(-0.29824015,-0.06521742)); coverage += part; ink += part*vec3(0.30980392,0.46274510,0.43137255);
 part = triangle_coverage(p,vec2(-0.02080748,-0.08695645),vec2(-0.15952385,0.19565225),vec2(-0.29824015,-0.06521742)); coverage += part; ink += part*vec3(0.30980392,0.46274510,0.43137255);
 part = triangle_coverage(p,vec2(0.29824021,-0.06521742),vec2(0.15952379,0.19565225),vec2(0.02080742,-0.08695645)); coverage += part; ink += part*vec3(0.31372549,0.47058824,0.43921569);
 part = triangle_coverage(p,vec2(0.02080742,-0.08695645),vec2(0.05548653,-0.20652177),vec2(0.29824021,-0.06521742)); coverage += part; ink += part*vec3(0.31372549,0.47058824,0.43921569);
 part = triangle_coverage(p,vec2(0.29824021,-0.06521742),vec2(0.34679091,0.30434781),vec2(0.15952379,0.19565225)); coverage += part; ink += part*vec3(0.31372549,0.47058824,0.43921569);
 ALBEDO = abs(panel_normal.z)>0.5 ? mix(background,ink/max(coverage,0.000001),clamp(coverage,0.0,1.0)) : background;
 ROUGHNESS = 0.93;
 SPECULAR = 0.05;
}
