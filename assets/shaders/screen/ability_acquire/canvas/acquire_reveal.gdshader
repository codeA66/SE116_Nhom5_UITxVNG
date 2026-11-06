shader_type canvas_item;
uniform float progress = 0.0;
uniform vec4 accent : source_color = vec4(0.65,0.88,0.94,1);
void fragment() {
	vec4 art = texture(TEXTURE,UV)*COLOR;
	float sweep = 1.0-UV.y;
	float grain = fract(sin(dot(floor(UV*64.0),vec2(12.9898,78.233)))*43758.5453);
	float threshold = sweep*0.88+grain*0.12;
	float reveal = smoothstep(threshold-0.025,threshold+0.025,progress*1.1);
	float rim = (1.0-smoothstep(0.0,0.08,abs(threshold-progress)))*(1.0-step(0.98,progress));
	COLOR = vec4(mix(art.rgb,accent.rgb,rim*0.6),art.a*reveal);
}
