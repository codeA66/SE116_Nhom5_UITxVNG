// Đổi các mảng màu đỏ (vertex color của model) sang màu tint, giữ độ sáng: một model chìa / cửa dùng được cho nhiều màu khoá.
// Chỉ phần đỏ trội mới đổi; đá, gỗ, kim loại giữ nguyên. strength = 0 thì không đổi gì.
vec3 recolor_red(vec3 c, vec3 tint, float strength, float lift) {
	float red_dominance = smoothstep(0.06, 0.22, c.r - max(c.g, c.b));
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	float tint_lum = max(dot(tint, vec3(0.299, 0.587, 0.114)), 0.001);
	vec3 target = tint * (lum / tint_lum) * lift;
	return mix(c, target, red_dominance * strength);
}
