## Share Panel — "Shared Dreams" async social sharing panel for "Echoes of Memory".
## Generates and decodes share codes so players can exchange memory sequences.
## The panel slides in from the right side of the screen.
extends Control

## ── Signals ────────────────────────────────────────────────────────────────────
signal shared_dream_requested(sequence_data: Dictionary)
signal code_generated(code: String)
signal code_invalid

## ── Constants ──────────────────────────────────────────────────────────────────
const CODE_PREFIX := "EOM-"
const PANEL_WIDTH := 340.0
const SLIDE_DURATION := 0.35

## ── Internal state ─────────────────────────────────────────────────────────────
var _player_id: String = ""
var _last_sequence: Array[int] = []
var _last_level: int = 1
var _is_visible: bool = false

## ── Node references ────────────────────────────────────────────────────────────
var _panel: Panel
var _share_code_field: LineEdit
var _receive_code_field: LineEdit
var _preview_label: Label
var _copy_button: Button
var _play_shared_button: Button
var _close_button: Button

## ── Lifecycle ──────────────────────────────────────────────────────────────────
func _ready() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Generate a stable player ID from save data
	_generate_player_id()

	# Build the panel off-screen (right side)
	_build_panel()

	# Semi-transparent backdrop (click to close)
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0, 0, 0, 0.45)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_backdrop_input)
	add_child(backdrop)
	move_child(backdrop, 0)  # Behind the panel
	backdrop.visible = false

## ── Panel construction ─────────────────────────────────────────────────────────
func _build_panel() -> void:
	_panel = Panel.new()
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_panel.offset_left = PANEL_WIDTH  # Start off-screen to the right
	_panel.offset_right = 0

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.04, 0.14, 0.97)
	panel_style.border_color = Color(0.45, 0.30, 0.65)
	panel_style.border_width_left = 2
	panel_style.corner_radius_top_left     = 16
	panel_style.corner_radius_bottom_left  = 16
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	var content := VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_top    = 24
	content.offset_bottom = -24
	content.offset_left   = 20
	content.offset_right  = -20
	content.add_theme_constant_override("separation", 14)
	_panel.add_child(content)

	# Close button (top-right of panel)
	_close_button = Button.new()
	_close_button.text = "X"
	_close_button.custom_minimum_size = Vector2(36, 36)
	_close_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_close_button.offset_top    = 12
	_close_button.offset_right  = -12
	_close_button.offset_left   = -48
	_close_button.offset_bottom = 48
	_close_button.pressed.connect(hide_panel)
	_panel.add_child(_close_button)

	# ── "Share a Memory" section ────────────────────────────────────────────
	var share_header := Label.new()
	share_header.text = "Share a Memory"
	share_header.add_theme_font_size_override("font_size", 22)
	share_header.add_theme_color_override("font_color", Color(0.85, 0.65, 1.0))
	content.add_child(share_header)

	var share_btn := Button.new()
	share_btn.text = "Generate Code"
	share_btn.custom_minimum_size = Vector2(0, 44)
	share_btn.pressed.connect(_on_generate_code)
	content.add_child(share_btn)

	_share_code_field = LineEdit.new()
	_share_code_field.placeholder_text = "Share code will appear here"
	_share_code_field.editable = false
	_share_code_field.custom_minimum_size = Vector2(0, 40)
	content.add_child(_share_code_field)

	_copy_button = Button.new()
	_copy_button.text = "Copy"
	_copy_button.custom_minimum_size = Vector2(0, 36)
	_copy_button.pressed.connect(_on_copy_code)
	_copy_button.disabled = true
	content.add_child(_copy_button)

	# ── "Receive a Memory" section ──────────────────────────────────────────
	var divider := HSeparator.new()
	content.add_child(divider)

	var receive_header := Label.new()
	receive_header.text = "Receive a Memory"
	receive_header.add_theme_font_size_override("font_size", 22)
	receive_header.add_theme_color_override("font_color", Color(0.5, 0.9, 1.0))
	content.add_child(receive_header)

	_receive_code_field = LineEdit.new()
	_receive_code_field.placeholder_text = "Paste share code here"
	_receive_code_field.custom_minimum_size = Vector2(0, 40)
	content.add_child(_receive_code_field)

	_play_shared_button = Button.new()
	_play_shared_button.text = "Play Shared Dream"
	_play_shared_button.custom_minimum_size = Vector2(0, 44)
	_play_shared_button.pressed.connect(_on_play_shared)
	content.add_child(_play_shared_button)

	# Preview label (shows decoded level & length before playing)
	_preview_label = Label.new()
	_preview_label.text = ""
	_preview_label.add_theme_font_size_override("font_size", 14)
	_preview_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_preview_label)

## ── Encode / Decode ────────────────────────────────────────────────────────────

## Encode a completed sequence into a shareable string.
## Format: "EOM-" + base64( JSON{v, seq, lvl, pid} )
func encode_sequence(sequence: Array[int], level: int, player_id: String) -> String:
	var payload := {
		"v": 1,                    # Code version
		"seq": sequence,
		"lvl": level,
		"pid": player_id,
	}
	var json_str := JSON.stringify(payload)
	var b64 := Marshalls.raw_to_base64(json_str.to_utf8_buffer())
	return CODE_PREFIX + b64


## Decode a share code back into its components.
## Returns a Dictionary {sequence, level, player_id} or null if invalid.
func decode_sequence(code: String) -> Dictionary:
	if not code.begins_with(CODE_PREFIX):
		return {}

	var b64 := code.substr(CODE_PREFIX.length())
	var raw_bytes := Marshalls.base64_to_raw(b64)
	if raw_bytes.is_empty():
		return {}

	var json_str := raw_bytes.get_string_from_utf8()
	var parsed := JSON.parse_string(json_str)
	if parsed == null or not parsed is Dictionary:
		return {}

	var data: Dictionary = parsed
	# Version check (future-proofing)
	if int(data.get("v", 0)) != 1:
		return {}

	var seq_array: Array = data.get("seq", [])
	var typed_seq: Array[int] = []
	for item in seq_array:
		if item is int or item is float:
			typed_seq.append(int(item))
		else:
			return {}  # Invalid sequence entry

	return {
		"sequence":  typed_seq,
		"level":     int(data.get("lvl", 1)),
		"player_id": str(data.get("pid", "")),
	}

## ── Player ID generation ───────────────────────────────────────────────────────
func _generate_player_id() -> void:
	# Create a stable ID from save creation data + random salt
	if SaveManager:
		var data := SaveManager.get_data()
		var stats: Dictionary = data.get("statistics", {})
		var existing_id: String = str(stats.get("player_id", ""))
		if not existing_id.is_empty():
			_player_id = existing_id
			return

	# Generate new ID: hash of timestamp + random
	var timestamp := str(Time.get_ticks_msec())
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var salt := str(rng.randi())
	_player_id = str(hash(timestamp + salt)).substr(0, 12)

	# Persist it
	if SaveManager:
		var stats: Dictionary = SaveManager.get_data().get("statistics", {})
		stats["player_id"] = _player_id
		SaveManager.get_data()["statistics"] = stats
		SaveManager.save_game()

## ── Show / Hide panel ──────────────────────────────────────────────────────────
func show_panel() -> void:
	if _is_visible:
		return
	_is_visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Show backdrop
	var backdrop := get_node_or_null("Backdrop")
	if backdrop:
		backdrop.visible = true
		backdrop.modulate.a = 0.0
		var bt := create_tween()
		bt.tween_property(backdrop, "modulate:a", 1.0, SLIDE_DURATION)

	# Slide panel in from right
	var t := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_panel, "offset_left", 0.0, SLIDE_DURATION)


func hide_panel() -> void:
	if not _is_visible:
		return
	_is_visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Hide backdrop
	var backdrop := get_node_or_null("Backdrop")
	if backdrop:
		var bt := create_tween()
		bt.tween_property(backdrop, "modulate:a", 0.0, SLIDE_DURATION)
		bt.tween_callback(func(): backdrop.visible = false)

	# Slide panel out to the right
	var t := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(_panel, "offset_left", PANEL_WIDTH, SLIDE_DURATION)

## ── Button handlers ────────────────────────────────────────────────────────────
func _on_generate_code() -> void:
	AudioManager.play_ui_click()
	if _last_sequence.is_empty():
		_share_code_field.text = "Play a sequence first!"
		return
	var code := encode_sequence(_last_sequence, _last_level, _player_id)
	_share_code_field.text = code
	_copy_button.disabled = false
	code_generated.emit(code)


func _on_copy_code() -> void:
	AudioManager.play_ui_click()
	DisplayServer.clipboard_set(_share_code_field.text)
	_copy_button.text = "Copied!"
	var t := create_tween()
	t.tween_interval(1.5)
	t.tween_callback(func(): _copy_button.text = "Copy")


func _on_play_shared() -> void:
	AudioManager.play_ui_click()
	var code := _receive_code_field.text.strip_edges()
	var decoded := decode_sequence(code)
	if decoded.is_empty():
		_preview_label.add_theme_color_override("font_color", Color(1, 0.35, 0.35))
		_preview_label.text = "Invalid code. Please check and try again."
		code_invalid.emit()
		return

	# Show preview
	_preview_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	_preview_label.text = "Level %d — %d notes in sequence\nFrom player: %s" % [
		decoded.level,
		decoded.sequence.size(),
		decoded.player_id,
	]

	# Emit signal so the game scene can start the Shared Dream mode
	shared_dream_requested.emit(decoded)

	# Hide the panel after a brief delay
	var t := create_tween()
	t.tween_interval(0.8)
	t.tween_callback(hide_panel)


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		hide_panel()

## ── Public API: set the last completed sequence (called from game scene) ───────
func set_last_sequence(sequence: Array[int], level: int) -> void:
	_last_sequence = sequence
	_last_level = level
