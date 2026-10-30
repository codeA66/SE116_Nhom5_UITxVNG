// Mảng sáng mềm giả ánh sáng (kiểu Hollow Knight: hình sáng trong suốt thay cho đèn thật, không tốn tính bóng).
// QuadMesh: billboard = true thì quay mặt camera (quầng quanh vật), false thì nằm theo mesh (vũng sáng trên sàn).
// Quad chữ nhật thì quầng thành elip theo quad. breathe: thở sáng chậm, không nhấp nháy gắt.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 glow_color : source_color = vec4(0.45, 0.75, 1.0, 1.0);
uniform float intensity = 0.6;
uniform bool billboard = false;
// Độ dốc tắt dần ra mép: lớn = gọn, nhỏ = loang
uniform float falloff = 2.0;
uniform float breathe = 0.12;
uniform float breathe_speed = 1.4;
// Script tween lúc xuất hiện / chớp
uniform float boost = 0.0;

void vertex() {
	if (billboard) {
		float sx = length(MODEL_MATRIX[0].xyz);
		float sy = length(MODEL_MATRIX[1].xyz);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * sx, INV_VIEW_MATRIX[1] * sy, INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	}
}

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float glow = pow(clamp(1.0 - r, 0.0, 1.0), falloff);
	float wave = 1.0 + breathe * sin(TIME * breathe_speed);
	ALBEDO = glow_color.rgb * intensity * wave * (1.0 + boost * 2.5);
	ALPHA = clamp(glow, 0.0, 1.0);
}
