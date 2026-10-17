extends TestCase
## 表现层里可以单独验证的规则（静态函数）：红色延迟扣血、绘制顺序、镜头缩放。


func test_red_health_waits_for_the_combo_to_end() -> void:
	var r: Array = HudView.red_step(1.0, 0, 0.8, true)
	check_eq(r[0], 1.0, "red stays while the combo goes on")
	r = HudView.red_step(r[0], r[1], 0.8, false)
	check_eq(r[1], HudView.RED_DELAY - 1, "after the combo it waits")
	var red: float = r[0]
	var delay: int = r[1]
	for i in 200:
		var s: Array = HudView.red_step(red, delay, 0.8, false)
		red = s[0]
		delay = s[1]
	check(is_equal_approx(red, 0.8), "then drains down to the real health (%f)" % red)
	check_eq(HudView.red_step(0.5, 10, 1.0, false)[0], 1.0, "refill catches up immediately")


func test_attacker_is_drawn_on_top() -> void:
	var sim := adjacent_sim()
	check_eq(MatchView.draw_order(sim, 1), 1, "nobody attacking: keep the previous order")
	play(sim, "5LP")
	check_eq(MatchView.draw_order(sim, 1), 0, "P1 attacking: P1 on top")
	play(sim, "5x3")
	check_eq(MatchView.draw_order(sim, 1), 0, "P2 in hitstun stays behind")


func test_camera_zoom() -> void:
	check_eq(MatchView.zoom_for(800.0, -1), 1.0, "far apart: no zoom")
	check(MatchView.zoom_for(100.0, -1) > 1.0 and MatchView.zoom_for(100.0, -1) <= MatchView.ZOOM_NEAR, "close: slight zoom")
	check(MatchView.zoom_for(100.0, 0, 3) > MatchView.zoom_for(100.0, 0, 1), "level 3 super zooms in more")
