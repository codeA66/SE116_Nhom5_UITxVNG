shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 accent : source_color = vec4(0.65,0.88,0.94,1);
uniform float progress = 0.0;
uniform float opacity = 0.0;
uniform float radius = 2.4;
uniform float width = 0.055;
uniform float floor_height = 0.035;
void vertex() {
	VERTEX = vec3(VERTEX.x*radius*2.0,floor_height,VERTEX.y*radius*2.0);
}
void fragment() {
	float r = length(UV*2.0-1.0);
	float edge = mix(0.1,0.94,1.0-pow(1.0-progress,3.0));
	float band = 1.0-smoothstep(width*0.4,width,abs(r-edge));
	float inner = 1.0-smoothstep(width*0.2,width*0.45,abs(r-edge*0.82));
	float angle = atan(UV.y-0.5,UV.x-0.5);
	float breakup = smoothstep(progress*0.7-0.1,progress*0.7+0.2,sin(angle*11.0+progress*2.0)*0.5+0.5);
	ALBEDO = mix(accent.rgb,vec3(1),band*0.45);
	ALPHA = max(band,inner*0.25) * opacity * (1.0-progress)*mix(1.0,breakup,progress);
}
