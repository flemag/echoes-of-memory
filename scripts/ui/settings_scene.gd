## Settings Scene — Full settings panel for "Echoes of Memory".
## Sections: Audio, Gameplay, Theme, Data.  All changes persist immediately
## via SaveManager and are reflected in AudioManager in real-time.
extends Control

## ── Theme colours ──────────────────────────────────────────────────────────────
const COLOR_DARK_BG   := Color(0.06, 0.03, 0.10)
const COLOR_LIGHT_BG  := Color(0.92, 0.90, 0.95)
const COLOR_DARK_TEXT := Color(0.88, 0.85, 0.95)
const COLOR_LIGHT_TEXT := Color(0.15, 0.10, 0.20)
const COLOR_ACCENT    := Color(0.85, 0.65, 1.0)
const COLOR_SECTION   := Color(0.75, 0.58, 1.0, 0.85)

## ── Internal references ────────────────────────────────────────────────────────
var _scroll_container: ScrollContainer
var _content: VBoxContainer
var _back_button: Button
var _confirm_dialog: ConfirmationDialog
var _is_dark_theme: bool = true

## ── Lifecycle ──────────────────────────────────────────────────────────────────
func _ready() -> void:
	anchors_preset = Control.PRESET_FULL_RECT

	# Load current theme preference
	if SaveManager:
		var theme_name: String = SaveManager.get_data().get("settings", {}).get("theme", "dark")
		_is_dark_theme = (theme_name == "dark")

	# Back button (top-left)
	_back_button = Button.new()
	_back_button.text = "<  Back"
	_back_button.position = Vector2(16, 16)
	_back_button.custom_minimum_size = Vector2(100, 40)
	_back_button.pressed.connect(_on_back_pressed)
	add_child(_back_button)

	# Title
	var title := Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.anchor_left  = 0.1
	title.anchor_right = 0.9
	title.offset_top   = 20
	title.offset_left  = 0
	title.offset_right = 0
	add_child(title)

	# Scrollable content area
	_scroll_container = ScrollContainer.new()
	_scroll_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll_container.offset_top    = 80
	_scroll_container.offset_bottom = -20
	_scroll_container.offset_left   = 40
	_scroll_container.offset_right  = -40
	add_child(_scroll_container)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 24)
	_scroll_container.add_child(_content)

	# Build sections
	_create_audio_section()
	_create_gameplay_section()
	_create_theme_section()
	_create_data_section()

	# Confirmation dialog for reset
	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.dialog_text = "This will erase all your memories. Are you sure?"
	_confirm_dialog.ok_button_text = "Confirm"
	_confirm_dialog.cancel_button_text = "Cancel"
	_confirm_dialog.confirmed.connect(_on_reset_confirmed)
	add_child(_confirm_dialog)

	# Apply theme on first frame
	_apply_theme()

	# Entrance fade
	modulate.a = 0.0
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.3)

## ── Audio section: Music & SFX volume sliders ─────────────────────────────────
func _create_audio_section() -> void:
	_add_section_header("AUDIO")

	# Music Volume
	var music_data := _create_slider_row("Music Volume", 0, 100, _get_saved_music_vol())
	music_data.slider.value_changed.connect(_on_music_volume_changed)
	_content.add_child(music_data.row)

	# SFX Volume
	var sfx_data := _create_slider_row("SFX Volume", 0, 100, _get_saved_sfx_vol())
	sfx_data.slider.value_changed.connect(_on_sfx_volume_changed)
	_content.add_child(sfx_data.row)

## ── Gameplay section: haptic & notifications toggles ──────────────────────────
func _create_gameplay_section() -> void:
	_add_section_header("GAMEPLAY")

	var settings: Dictionary = SaveManager.get_data().get("settings", {}) if SaveManager else {}

	# Haptic Feedback
	var haptic_btn := CheckButton.new()
	haptic_btn.text = "Haptic Feedback"
	haptic_btn.button_pressed = settings.get("haptic", true)
	haptic_btn.toggled.connect(_on_haptic_toggled)
	_content.add_child(haptic_btn)

	# Notifications
	var notif_btn := CheckButton.new()
	notif_btn.text = "Notifications"
	notif_btn.button_pressed = settings.get("notifications", true)
	notif_btn.toggled.connect(_on_notifications_toggled)
	_content.add_child(notif_btn)

## ── Theme section: dark / light toggle ─────────────────────────────────────────
func _create_theme_section() -> void:
	_add_section_header("THEME")

	var theme_btn := CheckButton.new()
	theme_btn.text = "Dark Mode"
	theme_btn.button_pressed = _is_dark_theme
	theme_btn.toggled.connect(_on_theme_toggled)
	_content.add_child(theme_btn)

## ── Data section: reset progress & export save ────────────────────────────────
func _create_data_section() -> void:
	_add_section_header("DATA")

	# Reset Progress
	var reset_btn := Button.new()
	reset_btn.text = "Reset Progress"
	reset_btn.custom_minimum_size = Vector2(0, 48)
	var reset_style := StyleBoxFlat.new()
	reset_style.bg_color = Color(0.55, 0.12, 0.12)
	reset_style.corner_radius_top_left     = 8
	reset_style.corner_radius_top_right    = 8
	reset_style.corner_radius_bottom_left  = 8
	reset_style.corner_radius_bottom_right = 8
	reset_style.content_margin_top    = 6
	reset_style.content_margin_bottom = 6
	reset_btn.add_theme_stylebox_override("normal", reset_style)
	reset_btn.pressed.connect(_on_reset_pressed)
	_content.add_child(reset_btn)

	# Export Save
	var export_btn := Button.new()
	export_btn.text = "Export Save"
	export_btn.custom_minimum_size = Vector2(0, 48)
	var export_style := StyleBoxFlat.new()
	export_style.bg_color = Color(0.20, 0.30, 0.50)
	export_style.corner_radius_top_left     = 8
	export_style.corner_radius_top_right    = 8
	export_style.corner_radius_bottom_left  = 8
	export_style.corner_radius_bottom_right = 8
	export_style.content_margin_top    = 6
	export_style.content_margin_bottom = 6
	export_btn.add_theme_stylebox_override("normal", export_style)
	export_btn.pressed.connect(_on_export_pressed)
	_content.add_child(export_btn)

## ── Slider change handlers ─────────────────────────────────────────────────────
func _on_music_volume_changed(value: float) -> void:
	# Slider is 0–100; AudioManager expects 0.0–1.0
	var normalized := value / 100.0
	AudioManager.music_volume = normalized
	if SaveManager:
		SaveManager.get_data()["settings"]["music_volume"] = normalized
		SaveManager.save_game()


func _on_sfx_volume_changed(value: float) -> void:
	var normalized := value / 100.0
	AudioManager.sfx_volume = normalized
	if SaveManager:
		SaveManager.get_data()["settings"]["sfx_volume"] = normalized
		SaveManager.save_game()

## ── Toggle handlers ────────────────────────────────────────────────────────────
func _on_haptic_toggled(pressed: bool) -> void:
	AudioManager.play_ui_click()
	if SaveManager:
		SaveManager.get_data()["settings"]["haptic"] = pressed
		SaveManager.save_game()


func _on_notifications_toggled(pressed: bool) -> void:
	AudioManager.play_ui_click()
	if SaveManager:
		SaveManager.get_data()["settings"]["notifications"] = pressed
		SaveManager.save_game()


func _on_theme_toggled(pressed: bool) -> void:
	AudioManager.play_ui_click()
	_is_dark_theme = pressed
	var theme_name := "dark" if pressed else "light"
	if SaveManager:
		SaveManager.get_data()["settings"]["theme"] = theme_name
		SaveManager.save_game()
	_apply_theme()

## ── Data handlers ──────────────────────────────────────────────────────────────
func _on_reset_pressed() -> void:
	AudioManager.play_ui_click()
	_confirm_dialog.popup_centered(Vector2i(400, 160))


func _on_reset_confirmed() -> void:
	if SaveManager:
		SaveManager.reset_save()
		# Reset GameManager state to defaults
		GameManager.current_level = 1
		GameManager.current_xp    = 0
		GameManager.total_score   = 0
		GameManager.current_biome = "meadow"
	AudioManager.play_ui_click()
	# Return to main menu after reset
	SceneManager.transition_to("main_menu", SceneManager.TransitionType.FADE, 0.5)


func _on_export_pressed() -> void:
	AudioManager.play_ui_click()
	var save_path := SaveManager.SAVE_FILE if SaveManager else "user://echo_save.json"
	DisplayServer.clipboard_set(save_path)
	# Brief visual feedback
	_export_feedback(save_path)

## ── Theme application ──────────────────────────────────────────────────────────
func _apply_theme() -> void:
	var bg_color   := COLOR_DARK_BG    if _is_dark_theme else COLOR_LIGHT_BG
	var text_color := COLOR_DARK_TEXT   if _is_dark_theme else COLOR_LIGHT_TEXT

	# Set self background via a ColorRect behind everything
	var bg := get_node_or_null("ThemeBackground") as ColorRect
	if not bg:
		bg = ColorRect.new()
		bg.name = "ThemeBackground"
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(bg)
		move_child(bg, 0)
	bg.color = bg_color

	# Recursively apply text colour to all Label and Button children
	_apply_text_color(self, text_color)

## Recursively walk the tree and override font_color on labels and buttons.
func _apply_text_color(node: Node, color: Color) -> void:
	if node is Label:
		node.add_theme_color_override("font_color", color)
	elif node is Button:
		node.add_theme_color_override("font_color", color)
	for child in node.get_children():
		_apply_text_color(child, color)

## ── Helpers ────────────────────────────────────────────────────────────────────
func _add_section_header(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", COLOR_SECTION)
	_content.add_child(label)

	# Thin divider line
	var divider := HSeparator.new()
	divider.add_theme_stylebox_override("separator", _make_line_style(Color(1, 1, 1, 0.15)))
	_content.add_child(divider)


## Create a labelled HSlider row; returns a Dictionary with .row and .slider.
func _create_slider_row(label_text: String, min_val: int, max_val: int, initial: int) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 130
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value  = min_val
	slider.max_value  = max_val
	slider.step       = 1
	slider.value      = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 200
	row.add_child(slider)

	var val_label := Label.new()
	val_label.text = str(initial)
	val_label.custom_minimum_size.x = 36
	val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slider.value_changed.connect(func(v): val_label.text = str(int(v)))
	row.add_child(val_label)

	return {"row": row, "slider": slider}


func _make_line_style(color: Color) -> StyleBoxLine:
	var style := StyleBoxLine.new()
	style.color = color
	style.thickness = 1
	return style


func _get_saved_music_vol() -> int:
	if SaveManager:
		var v: float = SaveManager.get_data().get("settings", {}).get("music_volume", 0.8)
		return int(v * 100)
	return 80


func _get_saved_sfx_vol() -> int:
	if SaveManager:
		var v: float = SaveManager.get_data().get("settings", {}).get("sfx_volume", 1.0)
		return int(v * 100)
	return 100


func _export_feedback(path: String) -> void:
	var label := Label.new()
	label.text = "Save path copied to clipboard:\n" + path
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	label.add_theme_font_size_override("font_size", 14)
	label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	label.offset_bottom = -60
	label.offset_left   = 40
	label.offset_right  = -40
	add_child(label)

	# Auto-remove after 3 seconds
	var t := create_tween()
	t.tween_interval(3.0)
	t.tween_callback(label.queue_free)

## ── Navigation ─────────────────────────────────────────────────────────────────
func _on_back_pressed() -> void:
	AudioManager.play_ui_click()
	SceneManager.transition_to("main_menu", SceneManager.TransitionType.SLIDE_RIGHT, 0.4)
