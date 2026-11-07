shader_type spatial;
// Vòng sáng trên sàn quanh cáo. Pha bùng: một vòng nở ra rồi vỡ. Pha tụ (converge): vài vòng liên tục thu dần về chân cáo,
// nhịp theo clock, mờ ở mép ngoài, sáng dần khi tới gần tâm (năng lượng đang dồn về).
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 accent : source_color = vec4(0.65,0.88,0.94,1);
uniform float progress = 0.0;
uniform float clock = 0.0;
uniform float opacity = 0.0;
uniform float radius = 2.4;
uniform float width = 0.055;
uniform float floor_height = 0.035;
uniform bool converge = false;
// Số vòng thu vào cùng lúc và số vòng mỗi giây
uniform int converge_rings = 3;
uniform float converge_rate = 0.7;
void vertex() {
	VERTEX = vec3(VERTEX.x*radius*2.0,floor_height,VERTEX.y*radius*2.0);
}
void fragment() {
	float r = length(UV*2.0-1.0);
	if (converge) {
		float alpha = 0.0;
		for (int k = 0; k < converge_rings; k++) {
			float edge = 1.0-fract(clock*converge_rate+float(k)/float(max(converge_rings,1)));
			float band = 1.0-smoothstep(width*0.3,width,abs(r-edge));
			alpha += band*smoothstep(1.0,0.7,edge)*smoothstep(0.02,0.2,edge)*mix(0.4,1.0,1.0-edge);
		}
		ALBEDO = mix(accent.rgb,vec3(1),0.3);
		ALPHA = clamp(alpha,0.0,1.0)*opacity*smoothstep(0.0,0.15,progress);
	} else {
		float edge = mix(0.1,0.94,1.0-pow(1.0-progress,3.0));
		float band = 1.0-smoothstep(width*0.4,width,abs(r-edge));
		float angle = atan(UV.y-0.5,UV.x-0.5);
		float breakup = smoothstep(progress*0.7-0.1,progress*0.7+0.2,sin(angle*11.0+progress*2.0)*0.5+0.5);
		ALBEDO = mix(accent.rgb,vec3(1),band*0.45);
		ALPHA = band*opacity*(1.0-progress)*breakup;
	}
}
