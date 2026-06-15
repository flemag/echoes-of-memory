## HUD — In-game overlay for "Echoes of Memory".
## Displays score, level, lives (hearts), combo multiplier, streak icon,
## echo indicator, and a pause button with pause menu.  Extends CanvasLayer
## so it renders above the game scene without affecting its transform.
extends CanvasLayer

## ── Constants ──────────────────────────────────────────────────────────────────
const HEART_RADIUS   := 10.0
const HEART_COLOR    := Color(0.95, 0.22, 0.25)
const HEART_EMPTY    := Color(0.25, 0.12, 0.15)
const COMBO_COLORS   := [Color(1, 1, 1), Color(1, 0.9, 0.4), Color(1, 0.6, 0.2), Color(1, 0.3, 0.3)]

## ── Internal state ─────────────────────────────────────────────────────────────
var _displayed_score: int = 0
var _target_score: int    = 0
var _current_lives: int   = 3
var _current_combo: int   = 0
var _current_level: int   = 1
var _streak_days: int     = 0
var _is_paused: bool      = false

## ── Node references ────────────────────────────────────────────────────────────
var _root_panel: Control
var _score_label: Label
var _level_label: Label
var _hearts_container: Control
var _combo_label: Label
var _streak_icon: Label
var _echo_label: Label
var _pause_button: Button
var _pause_menu: Panel
var _score_tween: Tween
var _combo_tween: Tween

## ── Lifecycle ──────────────────────────────────────────────────────────────────
func _ready() -> void:
	layer = 10  # Render above default

	# Root control that fills the viewport
	_root_panel = Control.new()
	_root_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root_panel)

	_build_top_bar()
	_build_combo_display()
	_build_streak_icon()
	_build_echo_indicator()
	_build_pause_button()
	_build_pause_menu()

	# Wire GameManager signals for live updates
	if GameManager:
		GameManager.score_changed.connect(_on_game_score_changed)
		GameManager.level_up.connect(func(l): update_level(l))
		GameManager.combo_changed.connect(func(c): update_combo(c))

## ── Top bar: Score (left), Level (centre), Hearts (right) ─────────────────────
func _build_top_bar() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_top    = 12
	bar.offset_left   = 16
	bar.offset_right  = -16
	bar.offset_bottom = 48
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_root_panel.add_child(bar)

	# Score — left
	_score_label = Label.new()
	_score_label.text = "0"
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_score_label.add_theme_font_size_override("font_size", 22)
	_score_label.add_theme_color_override("font_color", Color(1, 0.92, 0.5))
	_score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_score_label)

	# Level — centre
	_level_label = Label.new()
	_level_label.text = "Level 1"
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.add_theme_font_size_override("font_size", 20)
	_level_label.add_theme_color_override("font_color", Color(0.85, 0.65, 1.0))
	_level_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bar.add_child(_level_label)

	# Hearts container — right (custom drawn)
	_hearts_container = Control.new()
	_hearts_container.custom_minimum_size = Vector2(80, 24)
	_hearts_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hearts_container.draw.connect(_draw_hearts)
	bar.add_child(_hearts_container)

## ── Combo display below score ──────────────────────────────────────────────────
func _build_combo_display() -> void:
	_combo_label = Label.new()
	_combo_label.text = ""
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_combo_label.add_theme_font_size_override("font_size", 28)
	_combo_label.add_theme_color_override("font_color", COMBO_COLORS[0])
	_combo_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_combo_label.offset_top    = 44
	_combo_label.offset_left   = 16
	_combo_label.offset_right  = 160
	_combo_label.offset_bottom = 80
	_combo_label.visible = false
	_root_panel.add_child(_combo_label)

## ── Streak icon (small indicator in top-left corner) ──────────────────────────
func _build_streak_icon() -> void:
	_streak_icon = Label.new()
	_streak_icon.text = ""
	_streak_icon.add_theme_font_size_override("font_size", 14)
	_streak_icon.add_theme_color_override("font_color", Color(1, 0.5, 0.15))
	_streak_icon.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_streak_icon.offset_top    = 78
	_streak_icon.offset_left   = 16
	_streak_icon.offset_right  = 160
	_streak_icon.offset_bottom = 96
	_streak_icon.visible = false
	_root_panel.add_child(_streak_icon)

## ── Echo indicator: pulsing glow when echoes are pending ───────────────────────
func _build_echo_indicator() -> void:
	_echo_label = Label.new()
	_echo_label.text = "Echo Available!"
	_echo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_echo_label.add_theme_font_size_override("font_size", 18)
	_echo_label.add_theme_color_override("font_color", Color(0.5, 0.9, 1.0))
	_echo_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_echo_label.offset_top    = -50
	_echo_label.offset_bottom = -20
	_echo_label.offset_left   = 40
	_echo_label.offset_right  = -40
	_echo_label.visible = false
	_root_panel.add_child(_echo_label)

## ── Pause button (top-right) ──────────────────────────────────────────────────
func _build_pause_button() -> void:
	_pause_button = Button.new()
	_pause_button.text = "||"
	_pause_button.custom_minimum_size = Vector2(44, 44)
	_pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_pause_button.offset_top    = 8
	_pause_button.offset_right  = -8
	_pause_button.offset_left   = -52
	_pause_button.offset_bottom = 52
	_pause_button.pressed.connect(_on_pause_pressed)
	_root_panel.add_child(_pause_button)

## ── Pause menu overlay ────────────────────────────────────────────────────────
func _build_pause_menu() -> void:
	_pause_menu = Panel.new()
	_pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_menu.visible = false

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)

	var menu_style := StyleBoxFlat.new()
	menu_style.bg_color = Color(0.05, 0.02, 0.10, 0.92)
	menu_style.corner_radius_top_left     = 16
	menu_style.corner_radius_top_right    = 16
	menu_style.corner_radius_bottom_left  = 16
	menu_style.corner_radius_bottom_right = 16
	_pause_menu.add_theme_stylebox_override("panel", menu_style)

	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.85, 0.65, 1.0))
	vbox.add_child(title)

	var resume_btn := Button.new()
	resume_btn.text = "Resume"
	resume_btn.custom_minimum_size = Vector2(200, 50)
	resume_btn.pressed.connect(_on_resume_pressed)
	vbox.add_child(resume_btn)

	var quit_btn := Button.new()
	quit_btn.text = "Quit to Menu"
	quit_btn.custom_minimum_size = Vector2(200, 50)
	quit_btn.pressed.connect(_on_quit_to_menu_pressed)
	vbox.add_child(quit_btn)

	_pause_menu.add_child(vbox)
	_root_panel.add_child(_pause_menu)

## ── Public update methods ──────────────────────────────────────────────────────

## Smoothly roll the score counter up to the new value.
func update_score(score: int) -> void:
	_target_score = score
	if _score_tween and _score_tween.is_valid():
		_score_tween.kill()
	_score_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_score_tween.tween_method(_set_displayed_score, _displayed_score, score, 0.5)


## Animate the combo text with a bounce and colour intensity.
func update_combo(combo: int) -> void:
	_current_combo = combo
	if combo >= 2:
		_combo_label.visible = true
		_combo_label.text = "x%d" % combo
		# Colour intensity increases with combo
		var color_idx := mini(combo - 2, COMBO_COLORS.size() - 1)
		_combo_label.add_theme_color_override("font_color", COMBO_COLORS[color_idx])
		# Scale bounce on increment
		if _combo_tween and _combo_tween.is_valid():
			_combo_tween.kill()
		_combo_label.scale = Vector2(1.4, 1.4)
		_combo_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_combo_tween.tween_property(_combo_label, "scale", Vector2.ONE, 0.25)
	else:
		_combo_label.visible = false


## Update lives display; hearts shrink on loss.
func update_lives(lives: int) -> void:
	var old_lives := _current_lives
	_current_lives = lives
	_hearts_container.queue_redraw()
	# Shrink animation on loss
	if lives < old_lives:
		var t := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		_hearts_container.scale = Vector2(0.7, 0.7)
		t.tween_property(_hearts_container, "scale", Vector2.ONE, 0.4)


## Update the level text in the top bar.
func update_level(level: int) -> void:
	_current_level = level
	_level_label.text = "Level %d" % level


## Show or hide the echo indicator with a pulsing glow.
func show_echo_indicator(show: bool) -> void:
	_echo_label.visible = show
	if show:
		var pulse := create_tween().set_loops()
		pulse.tween_property(_echo_label, "modulate:a", 1.0, 0.5)
		pulse.tween_property(_echo_label, "modulate:a", 0.35, 0.5)


## Show the streak indicator icon.
func show_streak(days: int) -> void:
	_streak_days = days
	if days > 0:
		_streak_icon.text = "%d Day Streak" % days
		_streak_icon.visible = true
	else:
		_streak_icon.visible = false

## ── Pause handling ─────────────────────────────────────────────────────────────
func _on_pause_pressed() -> void:
	AudioManager.play_ui_click()
	_is_paused = true
	get_tree().paused = true
	_show_pause_menu()


func _show_pause_menu() -> void:
	_pause_menu.visible = true
	# Slide-in effect
	_pause_menu.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_pause_menu, "modulate:a", 1.0, 0.2)


func _on_resume_pressed() -> void:
	AudioManager.play_ui_click()
	_is_paused = false
	_pause_menu.visible = false
	get_tree().paused = false


func _on_quit_to_menu_pressed() -> void:
	AudioManager.play_ui_click()
	_is_paused = false
	get_tree().paused = false
	GameManager.end_game()
	SceneManager.transition_to("main_menu", SceneManager.TransitionType.FADE, 0.5)

## ── Heart drawing ──────────────────────────────────────────────────────────────
func _draw_hearts() -> void:
	var c := _hearts_container
	for i in range(3):
		var x := float(i) * 26.0 + 4.0
		var y := 8.0
		var color := HEART_COLOR if i < _current_lives else HEART_EMPTY
		c.draw_circle(Vector2(x, y), HEART_RADIUS, color)
		# Small highlight for a 3D look
		if i < _current_lives:
			c.draw_circle(Vector2(x - 3, y - 3), 3.0, Color(1, 0.5, 0.55, 0.6))

## ── Internal helpers ───────────────────────────────────────────────────────────

## Callback for tween_method to smoothly animate the score counter.
func _set_displayed_score(value: int) -> void:
	_displayed_score = value
	_score_label.text = str(value)


## Forward GameManager score changes to the animated counter.
func _on_game_score_changed(new_score: int) -> void:
	update_score(new_score)
