shader_type canvas_item;
render_mode blend_add, unshaded;
// 打击 / 防御 / 超杀火花：加色混合，按像素块量化、亮度分档，配合像素画风格。
// 每个特效画一个四边形（局部 -1..1），参数编在顶点颜色里（见 FxLayer.Sparks）：
//   r = 进度 t（0 → 1）  g = 随机种子  b = 强度（0 轻 / 0.5 中 / 1 重）  a = (模式 * 8 + 配色) / 32
// 四边形已经按打击方向翻转：局部 +x = 打击方向，攻击方在 -x 一侧。

uniform float cells = 40.0; // 四边形宽度方向的像素块数

varying vec4 params; // 顶点颜色原样传下来（片段阶段的 COLOR 会乘上贴图颜色）

// 每套配色三色：中心 / 中间 / 外缘
const vec3 PAL[24] = vec3[](
	vec3(1.0, 1.0, 0.92), vec3(1.0, 0.86, 0.34), vec3(1.0, 0.42, 0.08),  // 0 命中
	vec3(1.0, 0.96, 0.9), vec3(1.0, 0.55, 0.25), vec3(0.95, 0.1, 0.08),  // 1 Counter
	vec3(1.0, 0.92, 0.96), vec3(1.0, 0.4, 0.62), vec3(0.85, 0.02, 0.32), // 2 Punish Counter
	vec3(1.0, 1.0, 1.0), vec3(1.0, 0.92, 0.45), vec3(1.0, 0.62, 0.12),   // 3 超杀
	vec3(0.95, 1.0, 1.0), vec3(0.5, 0.88, 1.0), vec3(0.12, 0.38, 1.0),   // 4 防御
	vec3(1.0, 0.95, 1.0), vec3(0.85, 0.6, 1.0), vec3(0.45, 0.15, 0.9),   // 5 霸体
	vec3(1.0, 1.0, 1.0), vec3(0.92, 0.94, 1.0), vec3(0.6, 0.65, 1.0),    // 6 相杀
	vec3(1.0, 1.0, 0.95), vec3(1.0, 0.95, 0.7), vec3(1.0, 0.75, 0.3)     // 7 闪光
);

float hash(float n) {
	return fract(sin(n * 12.9898 + 4.1414) * 43758.5453);
}

vec3 ramp(int pal, float i) {
	vec3 c = mix(PAL[pal * 3 + 2], PAL[pal * 3 + 1], smoothstep(0.25, 0.6, i));
	return mix(c, PAL[pal * 3], smoothstep(0.65, 0.95, i));
}

// 放射尖刺：每个扇区一根，长度随机、打击方向更长；尖端向外飞，尾部随后收回。
float spikes(vec2 p, float t, float seed, float n, float reach, float bias) {
	float r = length(p);
	float s = (atan(p.y, p.x) / TAU + 0.5) * n;
	float id = floor(s);
	float f = abs(fract(s) - 0.5);
	if (hash(id * 3.1 + seed) < 0.18) {
		return 0.0;
	}
	float center = (id + 0.5) / n * TAU - PI;
	float len = reach * (0.5 + 0.5 * hash(id + seed)) * (1.0 - bias + bias * max(cos(center), 0.0));
	float e = 1.0 - pow(1.0 - t, 3.0);
	float head = len * min(e * 1.25, 1.0);
	float tail = len * max(t * 1.5 - 0.35, 0.0);
	if (r < tail || r > head) {
		return 0.0;
	}
	float w = 0.62 * (1.0 - (r - tail) / max(head - tail, 0.001));
	return step(f, w * 0.5) * (1.0 - t * 0.7) * (0.55 + 0.45 * (1.0 - r / len));
}

float burst(vec2 p, float t, float seed, float power) {
	float r = length(p);
	float e = 1.0 - pow(1.0 - t, 3.0);
	float core = (1.0 - smoothstep(0.0, mix(0.34, 0.08, t), r)) * (1.0 - t * t) * 1.3;
	float sp = spikes(p, t, seed, 10.0, 0.85 + 0.15 * power, 0.45) * 1.2;
	float ring_r = e * (0.5 + 0.35 * power);
	float ring = (1.0 - smoothstep(0.0, 0.04 + 0.04 * power, abs(r - ring_r))) * (1.0 - t) * 0.75;
	// 中 / 重攻击：沿打击方向的一道斩光（带一点随机倾角）
	float tilt = (hash(seed * 7.0) - 0.5) * 0.9;
	float slash = power * exp(-abs(p.y - p.x * tilt) * 26.0)
		* (1.0 - smoothstep(0.15, 1.0, abs(p.x - e * 0.25))) * (1.0 - t) * (1.0 - t) * 1.3;
	return max(max(core, sp), max(ring, slash));
}

// 防御：朝向攻击方的半边六角护盾 + 少量短火花
float guard(vec2 p, float t, float seed) {
	float r = length(p);
	float a = atan(p.y, -p.x);
	float e = 1.0 - pow(1.0 - t, 2.0);
	float face = 1.0 - smoothstep(1.0, 1.6, abs(a));
	float hex_r = r * (1.0 + 0.07 * cos(6.0 * a));
	float big = 0.38 + 0.4 * e;
	float shell = (1.0 - smoothstep(0.0, 0.05, abs(hex_r - big))) * face;
	float inner = (1.0 - smoothstep(0.0, 0.03, abs(hex_r - big * 0.72))) * face * 0.6;
	float core = (1.0 - smoothstep(0.0, mix(0.22, 0.05, t), r)) * (1.0 - t) * 1.2;
	float sp = spikes(vec2(-p.x, p.y), t, seed, 8.0, 0.55, 0.6);
	return max(max(core, sp), max(shell, inner) * (1.0 - t * t));
}

// 超杀 / KO 闪光：大范围细光线 + 外扩光环
float flash(vec2 p, float t, float seed) {
	float r = length(p);
	float e = 1.0 - pow(1.0 - t, 2.0);
	float core = (1.0 - smoothstep(0.0, mix(0.3, 0.02, t), r)) * (1.0 - t) * 1.4;
	float sp = spikes(p, t, seed, 26.0, 1.0, 0.0);
	float ring = (1.0 - smoothstep(0.0, 0.03, abs(r - e * 0.95))) * (1.0 - t);
	return max(core, max(sp * 0.9, ring));
}

void vertex() {
	params = COLOR;
}

void fragment() {
	vec2 uv = (floor(UV * cells) + 0.5) / cells;
	vec2 p = uv * 2.0 - 1.0;
	float t = params.r;
	float seed = params.g * 97.0;
	float power = params.b;
	int code = int(params.a * 32.0);
	int mode = code / 8;
	int pal = code - mode * 8;
	float i;
	if (mode == 1) {
		i = guard(p, t, seed);
	} else if (mode == 2) {
		// 火星粒子：小方块光点
		i = (1.0 - smoothstep(0.35, 1.0, max(abs(p.x), abs(p.y)))) * (1.0 - t * 0.6) * 1.2;
	} else if (mode == 3) {
		i = flash(p, t, seed);
	} else {
		i = burst(p, t, seed, power);
	}
	i = clamp(i, 0.0, 1.0);
	i = i < 0.1 ? 0.0 : ceil(i * 4.0) / 4.0;
	COLOR = vec4(ramp(pal, i), i);
}
