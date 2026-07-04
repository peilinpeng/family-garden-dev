shader_type canvas_item;

// 把贴图的透明剪影模糊成一团柔和的黑色投影，而不是原图的硬边复制体。
// 用于 globalmap 图层悬浮时的“抬起”投影，让高亮看起来有体积感。
uniform float blur_amount : hint_range(0.0, 0.02) = 0.006;

void fragment() {
	float alpha_sum = 0.0;
	float taps = 0.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			vec2 offset = vec2(float(x), float(y)) * blur_amount;
			alpha_sum += texture(TEXTURE, UV + offset).a;
			taps += 1.0;
		}
	}
	COLOR = vec4(0.0, 0.0, 0.0, alpha_sum / taps);
}
