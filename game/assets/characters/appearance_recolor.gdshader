shader_type canvas_item;

uniform sampler2D recolor_mask : filter_nearest, repeat_disable;
uniform vec4 hair_target : source_color = vec4(0.44, 0.26, 0.18, 1.0);
uniform float hair_strength : hint_range(0.0, 1.0) = 0.0;

vec3 rgb_to_hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 recolor_shaded(vec3 source, vec3 target) {
	vec3 hsv = rgb_to_hsv(source);
	float shade = clamp(hsv.z / 0.62, 0.34, 1.28);
	return clamp(target * shade, vec3(0.0), vec3(1.0));
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	if (source.a <= 0.01) {
		COLOR = source;
	} else {
		float mask = texture(recolor_mask, UV).r;
		vec3 result = source.rgb;
		if (mask > 0.5 && hair_strength > 0.001) {
			result = mix(result, recolor_shaded(source.rgb, hair_target.rgb), hair_strength * mask);
		}
		COLOR = vec4(result, source.a);
	}
}
