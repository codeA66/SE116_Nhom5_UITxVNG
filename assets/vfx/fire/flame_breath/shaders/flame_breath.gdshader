shader_type spatial;
render_mode unshaded, cull_back, blend_mix, depth_prepass_alpha;
uniform sampler2D masks : repeat_enable, filter_linear;
uniform vec4 outer_color : source_color = vec4(1.0,0.22,0.008,1.0);
uniform vec4 flame_color : source_color = vec4(1.0,0.64,0.025,1.0);
uniform vec4 core_color : source_color = vec4(1.0,0.96,0.52,1.0);
uniform float strength : hint_range(0.0,1.0) = 0.0;
uniform float clock = 0.0;
uniform float flow_speed = 2.2;
uniform float ground_mode = 0.0;
uniform float bloom_mode = 0.0;
uniform float roll_frequency = 19.0;
uniform float roll_speed = 17.0;
uniform float roll_amplitude = 0.16;
uniform float mask_repeat = 2.8;
uniform float curl_strength = 0.24;
uniform float curl_speed = 0.38;
uniform float crest_erosion_start = 0.90;
uniform float tip_erosion = 0.25;
uniform float ground_opacity = 0.18;
varying float crown;
void vertex(){
 crown=NORMAL.y*0.5+0.5;
 if(ground_mode<0.5){
  float roll=sin(UV.y*roll_frequency-clock*roll_speed+UV.x*6.283)*roll_amplitude;
  VERTEX.xy*=1.0+roll;
 }
}
void fragment(){
 float t=UV.y;
 vec2 flowing=vec2(UV.x*1.6,t*mask_repeat-clock*flow_speed);
 float curl=texture(masks,flowing*0.53+vec2(clock*curl_speed,0.31)).r-0.5;
 flowing+=vec2(curl,-curl*0.65)*curl_strength;
 float n=texture(masks,flowing).r;
 if(ground_mode>0.5){
  float x=abs(UV.x*2.0-1.0);
  float width=sin(t*3.14159)*0.88;
  float edge=1.0-smoothstep(width*0.55,width+0.02,x);
  ALBEDO=vec3(0.19,0.065,0.025);
  ALPHA=edge*sin(t*3.14159)*strength*ground_opacity;
 }else{
  float band=smoothstep(0.34,0.43,n+0.12*sin(t*26.0-clock*roll_speed+UV.x*10.0));
  float hot=smoothstep(0.43,0.60,n)*mix(0.45,1.0,crown);
  vec3 col=mix(outer_color.rgb,flame_color.rgb,band);
  col=mix(col,core_color.rgb,hot);
  col*=mix(0.9,1.0,smoothstep(0.12,0.65,crown));
  float tip=mix(1.0-smoothstep(crest_erosion_start,1.0,t+(1.0-n)*tip_erosion*smoothstep(0.72,1.0,t)),1.0,bloom_mode);
  float jet=pow(1.0-abs(UV.x*2.0-1.0),2.0)*(1.0-bloom_mode);
  col=mix(col,core_color.rgb,jet*0.7);
  ALBEDO=col;
  ALPHA=strength*tip;
 }
}
