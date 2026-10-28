shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform float age = -1.0;
uniform float sweep_time = 0.15;
uniform float reverse = 0.0;
uniform int layer = 0;
uniform float arc_radians = 2.530727;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void vertex(){
	if(COLOR.r<0.5){
		float a=atan(VERTEX.x,VERTEX.z)*arc_radians/2.530727;
		float r=length(VERTEX.xz);
		VERTEX.x=sin(a)*r;VERTEX.z=cos(a)*r;
	}
}
void fragment() {
	float u = mix(UV.x,1.0-UV.x,reverse);
	float t = max(age,0.0);
	float head = clamp(t/max(sweep_time,0.01),0.0,1.0)*1.10;
	float behind = head-u;
	float trail = smoothstep(-0.012,0.018,behind)*(1.0-smoothstep(0.14,0.72,behind));
	float across = max(1.0-abs(UV.y*2.0-1.0),0.0);
	float core = pow(across,3.0);
	float fade = 1.0-smoothstep(sweep_time,sweep_time+(layer==0?0.045:0.15),t);
	float strands = 0.4+0.6*pow(abs(sin(UV.y*23.0+UV.x*17.0-t*12.0)),5.0);
	float alpha = trail*fade*(layer==0?core:(pow(across,0.7)*strands));
	if(age<0.0) alpha=0.0;
	ALBEDO = layer==0?vec3(0.86,0.94,1.0):vec3(0.43,0.57,0.78);
	EMISSION = ALBEDO*(layer==0?2.5:0.7);
	ALPHA = alpha*(layer==0?0.95:(layer==1?0.40:0.16));
}
