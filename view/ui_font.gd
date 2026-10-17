class_name UiFont
extends RefCounted
## 默认字体没有中文，系统自动回退可能选到繁体字体（macOS 上 "PingFang SC" 会解析成 PingFang HK，"杀"显示成方框），
## 这里显式指定简体中文字体作为后备。每个场景在 _enter_tree 里调用一次（重复调用无害）。

static var _done := false


static func setup() -> void:
	if _done:
		return
	_done = true
	var cjk := SystemFont.new()
	cjk.font_names = PackedStringArray(["Hiragino Sans GB", "Microsoft YaHei", "Noto Sans CJK SC", "Heiti SC",
		"Source Han Sans SC", "WenQuanYi Micro Hei", "Arial Unicode MS"])
	var font: Font = ThemeDB.fallback_font.duplicate()
	font.fallbacks = [cjk]
	ThemeDB.fallback_font = font
