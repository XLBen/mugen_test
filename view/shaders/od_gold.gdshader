shader_type canvas_item;
// OD 金身（纯表现）：复古像素风。
//   本体：贴图亮度分 5 档映射到金色调色板（不做平滑过渡），加 1 像素闪烁描边和一道按贴图像素量化的斜向扫光；
//   残影：纯金色剪影，用 2x2 屏幕像素的棋盘格抖动做半透明（老游戏机的半透明做法）。
// 参数编在顶点颜色里：r = 动画相位（0..1，按仿真帧走）、g = 金色强度、b = 模式（0 本体 / 1 残影）、a = 透明度。

varying vec4 params;

const vec3 GOLD[5] = vec3[](
	vec3(0.24, 0.11, 0.02),
	vec3(0.56, 0.31, 0.04),
	vec3(0.89, 0.60, 0.10),
	vec3(1.00, 0.84, 0.30),
	vec3(1.00, 0.97, 0.74)
);

void vertex() {
	params = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float phase = params.r;
	float strength = params.g;
	bool ghost = params.b > 0.5;
	float alpha = params.a;
	vec2 px = TEXTURE_PIXEL_SIZE;

	if (ghost) {
		if (tex.a < 0.5) {
			discard;
		}
		vec2 cell = floor(FRAGCOORD.xy / 2.0);
		float checker = mod(cell.x + cell.y, 2.0);
		if (alpha < 0.6 && checker < 0.5) {
			discard;
		}
		COLOR = vec4(GOLD[3], alpha);
	} else if (tex.a < 0.5) {
		// 描边：四邻有像素的透明点画成亮金色，每 1/4 周期闪一次
		float n = texture(TEXTURE, UV + vec2(px.x, 0.0)).a + texture(TEXTURE, UV - vec2(px.x, 0.0)).a
			+ texture(TEXTURE, UV + vec2(0.0, px.y)).a + texture(TEXTURE, UV - vec2(0.0, px.y)).a;
		if (n < 0.5) {
			discard;
		}
		float blink = step(0.5, fract(phase * 4.0));
		COLOR = vec4(mix(GOLD[3], GOLD[4], blink), strength * alpha);
	} else {
		float lum = dot(tex.rgb, vec3(0.3, 0.59, 0.11));
		lum = lum * 0.85 + 0.12;
		// 扫光：按贴图像素量化的对角亮带，从左下往右上扫
		vec2 texel = floor(UV / px);
		float band = fract((texel.x - texel.y) * 0.012 - phase);
		lum += step(band, 0.05) * 0.4;
		int idx = clamp(int(lum * 5.0), 0, 4);
		COLOR = vec4(mix(tex.rgb, GOLD[idx], 0.85 * strength), alpha);
	}
}
