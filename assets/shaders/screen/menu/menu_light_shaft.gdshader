shader_type canvas_item;
render_mode blend_add;
// Vệt sáng xiên rọi từ trên xuống, thở chậm (cộng sáng nên không che chữ menu)

uniform vec4 shaft_color : source_color = vec4(0.7, 0.82, 0.95, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.07;
// Vị trí vệt ở mép trên (0..1 theo bề ngang) và độ xiên
uniform float center = 0.62;
uniform float slant = 0.35;
uniform float width = 0.11;
uniform float breathe_speed = 0.25;

void fragment() {
	float x = UV.x + (UV.y - 0.0) * slant;
	float beam = exp(-pow((x - center - slant * 0.5) / width, 2.0));
	float fall = 1.0 - smoothstep(0.1, 1.0, UV.y);
	float breathe = 0.75 + 0.25 * sin(TIME * breathe_speed * 6.2831);
	COLOR = vec4(shaft_color.rgb * beam * fall * breathe * strength, 1.0);
}
