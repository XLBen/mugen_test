shader_type canvas_item;
// 受击闪光：按贴图的透明度画一个纯色剪影（颜色和强度来自顶点颜色 / modulate）。
// 片段阶段的 COLOR 已经乘过贴图颜色，所以在顶点阶段先把纯色存下来。

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	COLOR = vec4(tint.rgb, texture(TEXTURE, UV).a * tint.a);
}
