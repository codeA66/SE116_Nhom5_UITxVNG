shader_type spatial;
// Hạt của chuỗi nhận kỹ năng. Mọi chuyển động chạy trong shader, CPU chỉ gửi thời gian (clock / progress).
// Pha: 0 sách tan, 4 nổ ra + lơ lửng, 1 thu về (đốm xoáy vào + tia nhọn lao vào), 2 bùng, 3 đọng lại / bụi tiếp đất.
// Cộng sáng (additive): đốm phát sáng trên nền tối thay vì thành chấm xám.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 accent : source_color = vec4(0.65,0.88,0.94,1);
uniform vec4 hot_color : source_color = vec4(0.95,0.99,1,1);
uniform sampler2D mote_texture : source_color, filter_linear;
uniform bool textured = false;
uniform int phase = 1;
uniform float progress = 0.0;
uniform float clock = 0.0;
uniform float opacity = 0.0;
uniform float focus_height = 0.65;
uniform float mote_size = 0.08;
uniform vec3 toward_camera = vec3(0,0.7,0.7);
uniform float spark_radius = 4.0;
uniform float dust_radius = 0.55;
uniform float landing_start = 0.78;
uniform float dust_size = 0.14;
uniform float dust_height = 0.06;
uniform float mote_stretch = 5.0;
uniform int total_count = 84;
uniform int linger_count = 24;
uniform float book_mote_size = 0.045;
uniform vec3 source_point = vec3(0,1,0);
uniform float glow_gain = 1.8;
// Đốm tròn: nổ ra từ cáo, chậm dần, trôi lơ lửng và lấp lánh (pha 4), rồi xoáy thu vào (pha 1)
uniform int orb_count = 140;
uniform float orb_radius = 7.0;
uniform float orb_screen_size = 0.012;
uniform float explode_rate = 3.5;
uniform float drift_amp = 0.35;
uniform float drift_speed = 0.5;
uniform float twinkle_speed = 3.0;
// Phần nhỏ số đốm đặt gần camera, to và mờ (như hạt bụi sát ống kính)
uniform float foreground_ratio = 0.06;
uniform float foreground_scale = 3.5;
uniform float foreground_depth = 6.0;
// Thời điểm kết thúc pha nổ ra: pha thu vào bắt đầu từ đúng vị trí đốm lúc đó
uniform float scatter_end = 3.0;
uniform float swirl_radius = 0.9;
uniform float swirl_speed = 5.0;
// Phần thời gian thu vào để đốm bay từ chỗ lơ lửng tới vòng xoáy (phần còn lại vòng xoáy co về tâm)
uniform float converge_portion = 0.7;
uniform float gather_window = 2.0;
// Tia sáng nhọn lao thẳng vào cáo trong pha thu vào
uniform int spike_count = 16;
uniform float spike_life = 0.35;
uniform float spike_start_radius = 5.0;
uniform float spike_length = 1.6;
uniform float spike_screen_width = 0.012;
uniform float arrival_time = 0.18;
uniform float arrival_size = 3.0;
varying float brightness;
varying float particle_alpha;
varying float streak;
varying float spike;
varying float glint;

float hash(float n) {
	return fract(sin(n)*43758.5453);
}

// Hướng ngẫu nhiên đều trên mặt cầu, hơi nghiêng lên (đốm bay lên nhiều hơn chui xuống sàn)
vec3 sphere_dir(float seed, float rnd) {
	float a = seed*6.283185;
	float y = hash(seed*13.7+rnd)*1.6-0.6;
	float r = sqrt(max(1.0-y*y,0.0));
	return vec3(sin(a)*r,y,cos(a)*r);
}

// Chiều cao khung nhìn (đơn vị view) ở độ sâu này: đổi cỡ theo màn hình sang cỡ thật
float view_height(float depth_view, mat4 projection) {
	if (projection[3][3] > 0.5) return 2.0/projection[1][1];
	return 2.0*max(depth_view,0.01)/projection[1][1];
}

// Vị trí đốm ở thời điểm t của pha nổ ra
vec3 scatter_point(float t, float seed, float rnd, float depth) {
	vec3 dir = sphere_dir(seed,rnd);
	float reach = orb_radius*sqrt(max(depth,0.04));
	float spread = reach*(1.0-exp(-t*explode_rate));
	vec3 drift = vec3(sin(t*drift_speed+seed*10.0),sin(t*drift_speed*0.7+rnd*9.0)*0.6,cos(t*drift_speed*0.8+seed*7.0))*drift_amp*smoothstep(0.0,1.0,t);
	vec3 p = vec3(0,focus_height,0)+dir*spread+drift;
	p.y = max(p.y,0.08);
	if (rnd > 1.0-foreground_ratio) p += toward_camera*foreground_depth*smoothstep(0.0,0.6,t);
	return p;
}

void vertex() {
	float seed = INSTANCE_CUSTOM.b;
	float rnd = INSTANCE_CUSTOM.a;
	float depth = fract(seed*17.17+rnd*5.13);
	float angle = seed*6.283185;
	vec3 p = vec3(0);
	float size = mote_size*mix(0.6,1.6,rnd);
	bool screen_sized = false;
	brightness = 0.65+rnd*0.35;
	particle_alpha = 1.0;
	streak = 0.0;
	spike = 0.0;
	glint = 0.0;
	bool foreground = rnd > 1.0-foreground_ratio;
	if (phase == 0) {
		float birth = seed*0.55;
		float lifetime = mix(0.18,0.43,rnd);
		float age = progress-birth;
		float t = clamp(age/lifetime,0.0,1.0);
		vec3 curl = vec3(sin(angle),sin(t*3.141593),cos(angle))*0.12*sin(t*3.141593);
		p = mix(source_point,vec3(0,focus_height,0),t*t*(3.0-2.0*t))+curl;
		size = book_mote_size;
		particle_alpha = step(0.0,age)*(1.0-step(lifetime,age))*smoothstep(0.0,0.2,t)*(1.0-smoothstep(0.7,1.0,t))*0.65;
	} else if (phase == 4) {
		p = scatter_point(clock,seed,rnd,depth);
		screen_sized = true;
		size = orb_screen_size*mix(0.35,1.6,rnd*rnd)*(foreground ? foreground_scale : 1.0);
		float twinkle = 0.55+0.45*sin(clock*twinkle_speed*mix(0.5,1.5,rnd)+seed*20.0);
		particle_alpha = smoothstep(0.0,0.08,clock)*twinkle*(foreground ? 0.3 : 1.0);
		brightness = 0.8+rnd*0.2;
	} else if (phase == 1) {
		if (INSTANCE_ID < orb_count) {
			// Đốm bay từ chỗ lơ lửng vào vòng xoáy sát cáo, vòng xoáy co dần về tâm
			vec3 start = scatter_point(scatter_end,seed,rnd,depth);
			float delay = rnd*0.25*gather_window;
			float t = clamp((clock-delay)/max(gather_window*converge_portion,0.001),0.0,1.0);
			float collapse = clamp(clock/max(gather_window,0.001),0.0,1.0);
			float ring = swirl_radius*mix(0.4,1.0,depth)*(1.0-collapse*collapse);
			float a = angle+clock*swirl_speed*(seed < 0.5 ? -1.0 : 1.0)*mix(0.6,1.2,rnd);
			vec3 swirl = vec3(sin(a)*ring,focus_height+(rnd-0.5)*ring*1.2,cos(a)*ring);
			p = mix(start,swirl,t*t*(3.0-2.0*t));
			screen_sized = true;
			size = orb_screen_size*mix(0.35,1.3,rnd*rnd)*mix(foreground ? foreground_scale : 1.0,0.8,t);
			float twinkle = 0.7+0.3*sin(clock*twinkle_speed*2.0*mix(0.5,1.5,rnd)+seed*20.0);
			particle_alpha = twinkle*(1.0-smoothstep(0.92,1.0,collapse))*mix(foreground ? 0.3 : 1.0,1.0,t);
			brightness = 0.85+0.15*t;
		} else if (INSTANCE_ID < orb_count+spike_count) {
			// Tia nhọn: lao thẳng vào ngực cáo từ mọi phía, mỗi tia một lúc khác nhau
			float launch = hash(seed*31.0)*max(gather_window-spike_life,0.0);
			float age = clock-launch;
			float t = clamp(age/max(spike_life,0.001),0.0,1.0);
			vec3 dir = sphere_dir(seed*3.1,rnd);
			vec3 center = vec3(0,focus_height,0);
			if (age > spike_life) {
				// Chạm cáo: chấm sáng + tia sao nhỏ tại ngực
				float h = clamp((age-spike_life)/max(arrival_time,0.0001),0.0,1.0);
				p = center;
				screen_sized = true;
				size = spike_screen_width*arrival_size*mix(0.6,1.0,h);
				particle_alpha = (1.0-h)*(1.0-step(1.0,h))*0.8;
				glint = 1.0;
			} else {
				spike = 1.0;
				float travel = t*t;
				vec3 head = center+dir*spike_start_radius*(1.0-travel);
				vec3 tail = head+dir*spike_length*mix(0.5,1.0,rnd);
				vec4 head_view = VIEW_MATRIX*MODEL_MATRIX*vec4(head,1);
				vec4 tail_view = VIEW_MATRIX*MODEL_MATRIX*vec4(tail,1);
				float width = spike_screen_width*view_height(-head_view.z,PROJECTION_MATRIX)*mix(0.7,1.3,rnd);
				vec2 along = head_view.xy-tail_view.xy;
				float len = length(along);
				vec2 forward = len > 0.00001 ? along/len : vec2(1,0);
				vec2 side = vec2(-forward.y,forward.x);
				vec4 middle = mix(tail_view,head_view,0.5);
				vec2 offset = forward*VERTEX.x*(len+width)+side*VERTEX.y*width;
				particle_alpha = step(0.0,age)*smoothstep(0.0,0.15,t);
				POSITION = PROJECTION_MATRIX*(middle+vec4(offset,0,0));
			}
		} else {
			particle_alpha = 0.0;
		}
	} else if (phase == 2) {
		float t = 1.0-pow(1.0-progress,3.0);
		float r = spark_radius*t*mix(0.3,1.0,depth);
		p = vec3(sin(angle)*r,focus_height+sin(progress*3.141593)*(0.4+rnd),cos(angle)*r);
		size *= mix(1.4,0.65,progress);
		particle_alpha = mix(1.0,0.35,progress);
		streak = step(seed,0.4)*(1.0-progress);
	} else if (INSTANCE_ID < linger_count) {
		float r = spark_radius*mix(0.3,1.0,depth)*(1.0-progress*0.15);
		angle += clock*0.2;
		p = vec3(sin(angle)*r,focus_height+sin(angle)*0.15-progress*0.35,cos(angle)*r);
		size *= 0.65;
		particle_alpha = 0.35*pow(1.0-progress,1.5);
	} else {
		float landing = clamp(landing_start,0.1,0.95);
		float t = clamp((progress-landing)/(1.0-landing),0.0,1.0);
		float r = dust_radius*mix(0.2,1.0,t);
		p = vec3(sin(angle)*r,dust_height+sin(t*3.141593)*dust_size,cos(angle)*r);
		size = dust_size*sin(t*3.141593)*mix(0.7,1.3,rnd);
		particle_alpha = 1.0-t;
	}
	if (spike < 0.5) {
		vec4 center = VIEW_MATRIX*MODEL_MATRIX*vec4(p,1);
		if (screen_sized) size *= view_height(-center.z,PROJECTION_MATRIX);
		vec2 projected = (VIEW_MATRIX*MODEL_MATRIX*vec4(vec3(0,focus_height,0)-p,0)).xy;
		if (phase == 2) projected = -projected;
		vec2 axis = projected/max(length(projected),0.0001);
		if (dot(axis,axis)<0.01) axis = vec2(1,0);
		vec2 normal = vec2(-axis.y,axis.x);
		vec2 offset = (axis*VERTEX.x*mix(1.0,mote_stretch,streak)+normal*VERTEX.y)*size;
		POSITION = PROJECTION_MATRIX*(center+vec4(offset,0,0));
	}
}

void fragment() {
	if (spike > 0.5) {
		// Tia nhọn: rộng và chói ở đầu (UV.x = 1, phía cáo), thon dần về đuôi
		float across = abs(UV.y*2.0-1.0)/max(UV.x,0.05);
		float body = smoothstep(1.0,0.0,across)*smoothstep(0.0,0.5,UV.x)*(1.0-smoothstep(0.95,1.0,UV.x));
		ALBEDO = mix(accent.rgb,hot_color.rgb,0.85)*glow_gain;
		ALPHA = body*opacity*particle_alpha;
	} else if (glint > 0.5) {
		// Chạm cáo: chấm sáng + tia hình sao 4 cánh
		vec2 c = UV*2.0-1.0;
		float dot_light = 1.0-smoothstep(0.0,0.45,length(c));
		float arms = max(1.0-smoothstep(0.0,0.06,abs(c.x)),1.0-smoothstep(0.0,0.06,abs(c.y)))*(1.0-smoothstep(0.2,1.0,length(c)));
		ALBEDO = mix(accent.rgb,hot_color.rgb,0.7)*glow_gain;
		ALPHA = clamp(dot_light+arms,0.0,1.0)*opacity*particle_alpha;
	} else {
		// Đốm tròn mềm: lõi trắng nhỏ + quầng
		float r = length(UV*2.0-1.0);
		float core = 1.0-smoothstep(0.15,0.5,r);
		float halo = 1.0-smoothstep(0.2,1.0,r);
		float alpha = max(core,halo*halo*0.7);
		alpha *= mix(1.0,smoothstep(0.0,0.65,UV.x),streak);
		if (textured) alpha *= texture(mote_texture,UV).a;
		ALBEDO = mix(accent.rgb,hot_color.rgb,clamp(0.5+brightness*0.5,0.0,1.0)*mix(0.7,1.0,core))*mix(1.0,glow_gain,core);
		ALPHA = alpha*opacity*particle_alpha;
	}
}
