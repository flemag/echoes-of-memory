## Main Menu — The landing screen for "Echoes of Memory".
## Builds the entire UI programmatically: animated title, typewriter subtitle,
## styled menu buttons, player-info panel, floating memory-fragment particles,
## and a dark gradient background.  All elements fade in sequentially on load.
extends Control

## ── Theme colours ──────────────────────────────────────────────────────────────
const COLOR_PRIMARY   := Color(0.85, 0.65, 1.0)    # Soft lavender
const COLOR_ACCENT    := Color(1.0, 0.85, 0.4)     # Warm gold
const COLOR_FLAME     := Color(1.0, 0.45, 0.1)     # Streak fire
const COLOR_GLOW      := Color(1.0, 0.92, 0.5, 0.6)

## ── Internal node references ───────────────────────────────────────────────────
var _title_label: Label
var _subtitle_label: Label
var _level_label: Label
var _xp_bar: ProgressBar
var _streak_label: Label
var _daily_label: Label
var _version_label: Label
var _button_container: VBoxContainer
var _particles: GPUParticles2D
var _float_tween: Tween

## ── Lifecycle ──────────────────────────────────────────────────────────────────
func _ready() -> void:
	# Ensure the control fills the viewport
	anchors_preset = Control.PRESET_FULL_RECT
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical   = Control.SIZE_EXPAND_FILL

	_create_background()
	_create_title()
	_create_info_panel()
	_create_menu_buttons()

	_version_label = Label.new()
	_version_label.text = "v1.0.0"
	_version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_version_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	_version_label.add_theme_font_size_override("font_size", 14)
	_version_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_version_label.position.y = -30
	add_child(_version_label)

	# Sequential fade-in for every child
	_entrance_animation()

	# Start continuous title float
	_start_title_float()

	# Begin typewriter for subtitle
	_typewriter_subtitle()

	# Refresh player info whenever save data changes
	if SaveManager:
		SaveManager.load_completed.connect(_refresh_info_panel)


func _exit_tree() -> void:
	if _float_tween and _float_tween.is_valid():
		_float_tween.kill()

## ── Background: dark gradient + floating memory-fragment particles ─────────────
func _create_background() -> void:
	# Gradient from deep navy to dark purple
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(0.04, 0.02, 0.12),  # Top — deep space
		Color(0.10, 0.05, 0.18),  # Mid
		Color(0.06, 0.03, 0.10),  # Bottom — darker
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])

	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to   = Vector2(0.5, 1.0)
	tex.width  = 720
	tex.height = 1280

	var bg := TextureRect.new()
	bg.texture = tex
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Particle system — small coloured dots (memory fragments)
	var particle_mat := ParticleProcessMaterial.new()
	particle_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX  # Changé à BOX
	particle_mat.alpha_curve = alpha_curve  # Cette propriété n'existe plus !
	particle_mat.direction = Vector3(0, -1, 0)
	particle_mat.spread = 30.0
	particle_mat.gravity = Vector3(0, -15, 0)
	particle_mat.initial_velocity_min = 10.0
	particle_mat.initial_velocity_max = 40.0
	particle_mat.scale_min = 2.0
	particle_mat.scale_max = 5.0
	particle_mat.color = Color(0.8, 0.6, 1.0, 0.5)

	# Curve to make particles fade in/out over lifetime
	var alpha_curve := Curve.new()
	alpha_curve.add_point(Vector2(0, 0))
	alpha_curve.add_point(Vector2(0.3, 1))
	alpha_curve.add_point(Vector2(0.7, 0.8))
	alpha_curve.add_point(Vector2(1, 0))
	# À la place de alpha_curve, utilisez:
	particle_mat.scale_curve = alpha_curve  # ou une autre propriété compatible

	_particles = GPUParticles2D.new()
	_particles.process_material = particle_mat
	_particles.amount = 60
	_particles.lifetime = 8.0
	_particles.explosiveness = 0.0
	_particles.randomness = 0.7
	_particles.position = Vector2(360, 640)
	add_child(_particles)

## ── Title and subtitle ─────────────────────────────────────────────────────────
func _create_title() -> void:
	var container := VBoxContainer.new()
	container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	container.anchor_left   = 0.1
	container.anchor_right  = 0.9
	container.offset_top    = 120
	container.offset_left   = 0
	container.offset_right  = 0
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(container)

	# Main title
	_title_label = Label.new()
	_title_label.text = "Echoes of Memory"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_color_override("font_color", COLOR_PRIMARY)
	_title_label.add_theme_font_size_override("font_size", 42)
	_title_label.modulate.a = 0.0
	container.add_child(_title_label)

	# Subtitle (typewriter)
	_subtitle_label = Label.new()
	_subtitle_label.text = ""
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	_subtitle_label.add_theme_font_size_override("font_size", 16)
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.modulate.a = 0.0
	container.add_child(_subtitle_label)

## ── Info panel: level, XP bar, streak, daily bonus ─────────────────────────────
func _create_info_panel() -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.anchor_left   = 0.15
	panel.anchor_right  = 0.85
	panel.offset_top    = 280
	panel.offset_left   = 0
	panel.offset_right  = 0
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_theme_constant_override("separation", 6)
	add_child(panel)

	# Level label
	_level_label = Label.new()
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.add_theme_color_override("font_color", COLOR_ACCENT)
	_level_label.add_theme_font_size_override("font_size", 18)
	_level_label.modulate.a = 0.0
	panel.add_child(_level_label)

	# XP progress bar
	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(300, 10)
	_xp_bar.show_percentage = false
	_xp_bar.modulate.a = 0.0
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.2, 0.15, 0.3)
	bar_style.corner_radius_top_left     = 5
	bar_style.corner_radius_top_right    = 5
	bar_style.corner_radius_bottom_left  = 5
	bar_style.corner_radius_bottom_right = 5
	_xp_bar.add_theme_stylebox_override("background", bar_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = COLOR_PRIMARY
	fill_style.corner_radius_top_left     = 5
	fill_style.corner_radius_top_right    = 5
	fill_style.corner_radius_bottom_left  = 5
	fill_style.corner_radius_bottom_right = 5
	_xp_bar.add_theme_stylebox_override("fill", fill_style)
	panel.add_child(_xp_bar)

	# Streak label
	_streak_label = Label.new()
	_streak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_streak_label.add_theme_color_override("font_color", COLOR_FLAME)
	_streak_label.add_theme_font_size_override("font_size", 16)
	_streak_label.modulate.a = 0.0
	panel.add_child(_streak_label)

	# Daily bonus label
	_daily_label = Label.new()
	_daily_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_daily_label.add_theme_color_override("font_color", COLOR_ACCENT)
	_daily_label.add_theme_font_size_override("font_size", 16)
	_daily_label.modulate.a = 0.0
	panel.add_child(_daily_label)

	_refresh_info_panel()

## ── Menu buttons ───────────────────────────────────────────────────────────────
func _create_menu_buttons() -> void:
	_button_container = VBoxContainer.new()
	_button_container.set_anchors_preset(Control.PRESET_CENTER)
	_button_container.anchor_left   = 0.2
	_button_container.anchor_right  = 0.8
	_button_container.offset_top    = 40   # nudge below true centre
	_button_container.offset_left   = 0
	_button_container.offset_right  = 0
	_button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_button_container.add_theme_constant_override("separation", 14)
	add_child(_button_container)

	# Determine whether this is a new player
	var has_save := SaveManager.has_save() if SaveManager else false

	if has_save:
		_add_menu_button("PLAY", "_on_play_pressed", true)       # Primary / glowing
	else:
		_add_menu_button("New Journey", "_on_play_pressed", true)

	_add_menu_button("SANCTUARY",  "_on_sanctuary_pressed",  false)
	_add_menu_button("COLLECTION", "_on_collection_pressed", false)
	_add_menu_button("SETTINGS",   "_on_settings_pressed",   false)

## Helper: create a single styled button and wire its signals.
func _add_menu_button(text: String, callback: String, primary: bool) -> void:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 54) if not primary else Vector2(0, 64)

	var normal_style := StyleBoxFlat.new()
	normal_style.corner_radius_top_left     = 12
	normal_style.corner_radius_top_right    = 12
	normal_style.corner_radius_bottom_left  = 12
	normal_style.corner_radius_bottom_right = 12
	normal_style.content_margin_top    = 8
	normal_style.content_margin_bottom = 8

	if primary:
		normal_style.bg_color = Color(0.45, 0.25, 0.65)
		normal_style.border_color = COLOR_ACCENT
		normal_style.border_width_top    = 2
		normal_style.border_width_bottom = 2
		normal_style.border_width_left   = 2
		normal_style.border_width_right  = 2
		btn.add_theme_color_override("font_color", COLOR_ACCENT)
		btn.add_theme_font_size_override("font_size", 24)
	else:
		normal_style.bg_color = Color(0.18, 0.10, 0.28)
		btn.add_theme_color_override("font_color", Color(0.85, 0.82, 0.95))
		btn.add_theme_font_size_override("font_size", 20)

	btn.add_theme_stylebox_override("normal", normal_style)

	# Hover style — slightly brighter, scaled up via tween
	var hover_style := normal_style.duplicate()
	hover_style.bg_color = Color(
		normal_style.bg_color.r + 0.12,
		normal_style.bg_color.g + 0.08,
		normal_style.bg_color.b + 0.15,
	)
	btn.add_theme_stylebox_override("hover", hover_style)

	btn.modulate.a = 0.0
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	btn.pressed.connect(Callable(self, callback))
	btn.mouse_entered.connect(_on_button_hover.bind(btn))
	btn.mouse_exited.connect(_on_button_hover_end.bind(btn))

	_button_container.add_child(btn)

## ── Button callbacks ───────────────────────────────────────────────────────────
func _on_play_pressed() -> void:
	AudioManager.play_ui_click()
	# Record today's streak before starting
	if SaveManager:
		SaveManager.add_streak_day()
	GameManager.start_game()
	SceneManager.transition_to("game", SceneManager.TransitionType.FADE, 0.6)


func _on_sanctuary_pressed() -> void:
	AudioManager.play_ui_click()
	SceneManager.transition_to("sanctuary", SceneManager.TransitionType.DISSOLVE, 0.5)


func _on_collection_pressed() -> void:
	AudioManager.play_ui_click()
	SceneManager.transition_to("collection", SceneManager.TransitionType.DISSOLVE, 0.5)


func _on_settings_pressed() -> void:
	AudioManager.play_ui_click()
	SceneManager.transition_to("settings", SceneManager.TransitionType.SLIDE_LEFT, 0.4)

## ── Button hover effects ──────────────────────────────────────────────────────
func _on_button_hover(btn: Button) -> void:
	AudioManager.play_ui_hover()
	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "scale", Vector2(1.06, 1.06), 0.15)


func _on_button_hover_end(btn: Button) -> void:
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(btn, "scale", Vector2.ONE, 0.15)

## ── Info panel refresh ─────────────────────────────────────────────────────────
func _refresh_info_panel() -> void:
	if not _level_label:
		return

	var level := GameManager.current_level
	var xp    := GameManager.current_xp
	var needed := GameManager.xp_needed_for_level(level)

	_level_label.text = "Level %d" % level
	_xp_bar.max_value = needed
	_xp_bar.value = xp

	# Streak display
	var streak := SaveManager.get_streak_days() if SaveManager else 0
	if streak > 0:
		_streak_label.text = "%d Day Streak \U0001F525" % streak
		_streak_label.visible = true
	else:
		_streak_label.visible = false

	# Daily bonus indicator
	if _check_daily_bonus():
		_daily_label.text = "Daily Bonus!"
		_daily_label.visible = true
		# Pulsing glow animation
		var pulse := create_tween().set_loops()
		pulse.tween_property(_daily_label, "modulate", Color(COLOR_ACCENT, 1.0), 0.6)
		pulse.tween_property(_daily_label, "modulate", Color(COLOR_ACCENT, 0.4), 0.6)
	else:
		_daily_label.visible = false

## ── Check whether a daily bonus is available ───────────────────────────────────
func _check_daily_bonus() -> bool:
	if not SaveManager:
		return false
	var streak_data: Dictionary = SaveManager.get_data().get("streak_data", {})
	var last_play: String = streak_data.get("last_play_date", "")
	var today := Time.get_date_string_from_system()
	return last_play != today  # Bonus available if they haven't played today

## ── Entrance animation: sequential fade-in ─────────────────────────────────────
func _entrance_animation() -> void:
	var elements: Array[Control] = []
	# Collect all top-level children in order for staggered reveal
	for child in get_children():
		if child is Control:
			elements.append(child)

	var delay := 0.0
	for elem in elements:
		var t := create_tween()
		t.tween_delay(delay)
		t.tween_property(elem, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)
		delay += 0.1

## ── Continuous title floating animation ────────────────────────────────────────
func _start_title_float() -> void:
	_float_tween = create_tween().set_loops()
	_float_tween.tween_property(_title_label, "position:y", -6.0, 2.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_float_tween.tween_property(_title_label, "position:y", 6.0, 2.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## ── Typewriter animation for the subtitle ──────────────────────────────────────
func _typewriter_subtitle() -> void:
	var full_text := "Reconstruct your past, one memory at a time..."
	# Fade in subtitle container first
	var fade_in := create_tween()
	fade_in.tween_property(_subtitle_label, "modulate:a", 1.0, 0.5)

	# Type one character at a time
	for i in range(full_text.length()):
		var idx := i  # Capture for lambda
		get_tree().create_timer(0.5 + i * 0.04).timeout.connect(
			func(): _subtitle_label.text = full_text.left(idx + 1)
		)
