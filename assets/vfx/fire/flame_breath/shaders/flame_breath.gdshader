shader_type spatial;
render_mode unshaded, cull_back, blend_mix, depth_prepass_alpha;
uniform sampler2D masks : repeat_enable, filter_linear;
uniform vec4 outer_color : source_color = vec4(0.84,0.075,0.025,1.0);
uniform vec4 flame_color : source_color = vec4(1.0,0.48,0.035,1.0);
uniform vec4 core_color : source_color = vec4(1.0,0.94,0.67,1.0);
uniform vec4 hot_color : source_color = vec4(1.0,0.77,0.24,1.0);
uniform float tip_curl = 0.13;
uniform float strength : hint_range(0.0,1.0) = 0.0;
uniform float clock = 0.0;
uniform float flow_speed = 3.0;
uniform float ground_mode = 0.0;
uniform float accent_mode = 0.0;
uniform float intensity = 1.0;
uniform float pressure = 1.0;
uniform float core_gain = 1.35;
uniform float core_length = 0.78;
uniform float star_power = 8.0;
uniform float front : hint_range(0.0, 1.0) = 1.0;
uniform float retreat : hint_range(0.0, 1.0) = 0.0;
uniform float edge_width = 0.018;
uniform float tongue_frequency = 3.0;
uniform float tongue_depth = 0.15;
uniform float roll_frequency = 19.0;
uniform float roll_speed = 17.0;
uniform float roll_amplitude = 0.16;
uniform float mask_repeat = 4.2;
uniform float curl_strength = 0.24;
uniform float curl_speed = 0.38;
uniform float crest_erosion_start = 0.97;
uniform float tip_erosion = 0.08;
uniform float ground_opacity = 0.18;
varying float crown;
void vertex(){
 crown=NORMAL.y*0.5+0.5;
 if(accent_mode>0.5){
  vec3 size=vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
  MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*size.x,INV_VIEW_MATRIX[1]*size.y,INV_VIEW_MATRIX[2]*size.z,MODEL_MATRIX[3]);
 }else if(ground_mode<0.5){
  float phase=UV.y*roll_frequency-clock*roll_speed;
  float roll=(sin(phase+UV.x*6.283)*0.7+sin(phase*1.43-UV.x*12.566)*0.3)*roll_amplitude;
  VERTEX.xy*=min((1.0+roll)*pressure,1.2);
  VERTEX.z-=pow(UV.y,6.0)*tip_curl*(0.5+0.5*sin(UV.x*18.85-clock*3.0));
 }
}
void fragment(){
 if(accent_mode>0.5){
  vec2 p=UV*2.0-1.0;
  float radius=length(p);
  float ray=pow(abs(cos(2.0*atan(p.y,p.x))),star_power);
  float shape=1.0-smoothstep(0.12+ray*0.63,0.17+ray*0.68,radius);
  ALBEDO=mix(hot_color.rgb,core_color.rgb,1.0-smoothstep(0.0,0.35,radius))*1.8;
  ALPHA=shape*intensity;
 }else{
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
  col=mix(col,hot_color.rgb,hot);
  col*=mix(0.9,1.0,smoothstep(0.12,0.65,crown));
  float tongues=(sin(UV.x*6.283*tongue_frequency+clock*3.0)*0.5+0.5)*tongue_depth;
  float tip=1.0-smoothstep(crest_erosion_start,1.0,t+(1.0-n)*tip_erosion*smoothstep(0.72,1.0,t)+tongues*smoothstep(0.65,1.0,t));
  tip*=1.0-smoothstep(front-edge_width,front,t);
  tip*=smoothstep(retreat-edge_width,retreat,t);
  float jet=smoothstep(0.62,0.94,crown)*(1.0-smoothstep(0.2,core_length,t));
  jet*=0.80+0.20*smoothstep(0.2,0.7,n);
  col=mix(col,core_color.rgb,jet*0.88);
  ALBEDO=col*(1.0+jet*core_gain);
  ALPHA=strength*tip;
 }
}
}
