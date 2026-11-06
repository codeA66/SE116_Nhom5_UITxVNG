shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 accent : source_color = vec4(0.65,0.88,0.94,1);
uniform vec4 hot_color : source_color = vec4(0.95,0.99,1,1);
uniform sampler2D mote_texture : source_color, filter_linear;
uniform bool textured = false;
uniform int phase = 1;
uniform float progress = 0.0;
uniform float clock = 0.0;
uniform float opacity = 0.0;
uniform float focus_height = 0.65;
uniform float radius = 6.2;
uniform float height_spread = 4.2;
uniform float spin = 2.2;
uniform float mote_size = 0.08;
uniform float foreground_size = 0.45;
uniform float foreground_depth = 6.0;
uniform float foreground_spread = 1.8;
uniform vec3 toward_camera = vec3(0,0.7,0.7);
uniform int foreground_count = 6;
uniform float spark_radius = 4.0;
uniform float dust_radius = 0.55;
uniform float landing_start = 0.78;
uniform float dust_size = 0.14;
uniform float dust_height = 0.06;
uniform float gather_acceleration = 2.0;
uniform float gather_stagger = 0.48;
uniform float mote_stretch = 5.0;
uniform float streak_ratio = 0.18;
uniform int total_count = 84;
uniform int linger_count = 24;
uniform float book_mote_size = 0.045;
uniform vec3 source_point = vec3(0,1,0);
varying float brightness;
varying float particle_alpha;
varying float streak;
void vertex() {
    float seed = INSTANCE_CUSTOM.b;
    float rnd = INSTANCE_CUSTOM.a;
    float depth = fract(seed*17.17+rnd*5.13);
    float angle = seed*6.283185;
    vec3 p = vec3(0);
    float size = mote_size*mix(0.6,1.6,rnd);
    brightness = 0.65+rnd*0.35;
    particle_alpha = 1.0;
    streak = 0.0;
    if (phase == 0) {
        float birth = seed*0.55;
        float lifetime = mix(0.18,0.43,rnd);
        float age = progress-birth;
        float t = clamp(age/lifetime,0.0,1.0);
        vec3 curl = vec3(sin(angle),sin(t*3.141593),cos(angle))*0.12*sin(t*3.141593);
        p = mix(source_point,vec3(0,focus_height,0),t*t*(3.0-2.0*t))+curl;
        size = book_mote_size;
        particle_alpha = step(0.0,age)*(1.0-step(lifetime,age))*smoothstep(0.0,0.2,t)*(1.0-smoothstep(0.7,1.0,t))*0.65;
    } else if (phase == 1) {
        float age = clock-INSTANCE_CUSTOM.r;
        float lifetime = max(INSTANCE_CUSTOM.g,0.000001);
        float life = clamp(age/lifetime,0.0,1.0);
        float travel = pow(life,max(gather_acceleration,0.1));
        float spin_direction = rnd < 0.5 ? -1.0 : 1.0;
        float orbit = angle+spin_direction*spin*life*mix(0.15,0.7,rnd);
        float r = radius*sqrt(max(depth,0.03))*(1.0-travel);
        p = vec3(sin(orbit)*r,focus_height+(rnd-0.25)*height_spread*(1.0-travel),cos(orbit)*r);
        particle_alpha = step(0.0,age)*(1.0-step(lifetime,age))*smoothstep(0.0,0.12,life)*(1.0-smoothstep(0.80,1.0,life));
        streak = step(seed,streak_ratio)*smoothstep(0.1,0.85,life);
        if (INSTANCE_ID < foreground_count) {
            p.xz *= foreground_spread;
            p += toward_camera*foreground_depth*(1.0-travel);
            size = mix(foreground_size,mote_size,travel);
            streak = 0.0;
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
    vec4 center = VIEW_MATRIX*MODEL_MATRIX*vec4(p,1);
    vec2 projected = (VIEW_MATRIX*MODEL_MATRIX*vec4(vec3(0,focus_height,0)-p,0)).xy;
    if (phase == 2) projected = -projected;
    vec2 axis = projected/max(length(projected),0.0001);
    if (dot(axis,axis)<0.01) axis = vec2(1,0);
    vec2 normal = vec2(-axis.y,axis.x);
    vec2 offset = (axis*VERTEX.x*mix(1.0,mote_stretch,streak)+normal*VERTEX.y)*size;
    POSITION = PROJECTION_MATRIX*(center+vec4(offset,0,0));
}
void fragment() {
    float r = length(UV*2.0-1.0);
    float alpha = 1.0-smoothstep(0.08,1.0,r);
    alpha *= mix(1.0,smoothstep(0.0,0.65,UV.x),streak);
    if (textured) alpha *= texture(mote_texture,UV).a;
    ALBEDO = mix(accent.rgb,hot_color.rgb,0.75+brightness*0.25);
    ALPHA = alpha*opacity*particle_alpha;
}
