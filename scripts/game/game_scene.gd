## GameScene — Main controller for the gameplay loop in "Echoes of Memory".
## Manages game states (IDLE → SHOWING_SEQUENCE → PLAYER_TURN → EVALUATING → GAME_OVER),
## creates the HUD and memory nodes programmatically, handles sequence display,
## player input, scoring, lives, level progression, and visual effects.
extends Control
class_name GameScene

## ── Game states ──────────────────────────────────────────────────────────────
enum GameState {
        IDLE,
        SHOWING_SEQUENCE,
        PLAYER_TURN,
        EVALUATING,
        ECHO_SEQUENCE,
        GAME_OVER,
}

## ── Constants ────────────────────────────────────────────────────────────────
const MAX_LIVES := 3
const SEQUENCES_PER_LEVEL := 3
const SHAKE_AMOUNT := 8.0
const SHAKE_DURATION := 0.3

## ── State ────────────────────────────────────────────────────────────────────
var _state: GameState = GameState.IDLE
var _current_sequence: Array[int] = []
var _player_index: int = 0
var _lives: int = MAX_LIVES
var _sequences_completed: int = 0
var _mistakes_this_sequence: int = 0
var _is_echo_round: bool = false
var _current_echo_data: Dictionary = {}

## ── Sub-systems ──────────────────────────────────────────────────────────────
var _sequence_generator: SequenceGenerator
var _echo_system: EchoSystem
var _score_system: ScoreSystem

## ── Node references ─────────────────────────────────────────────────────────
var _memory_nodes: Array[MemoryNode] = []
var _hud_container: VBoxContainer
var _score_label: Label
var _combo_label: Label
var _level_label: Label
var _lives_container: HBoxContainer
var _streak_label: Label
var _message_label: Label
var _back_button: Button
var _node_container: Control   # Holds the 6 memory nodes
var _particles: GPUParticles2D
var _camera: Camera2D

#region ── Lifecycle ───────────────────────────────────────────────────────────

func _ready() -> void:
        # Initialise sub-systems
        _sequence_generator = SequenceGenerator.new()
        _echo_system = EchoSystem.new()
        add_child(_echo_system)
        _score_system = ScoreSystem.new()
        add_child(_score_system)

        # Connect ScoreSystem signals
        _score_system.score_added.connect(_on_score_added)
        _score_system.combo_broken.connect(_on_combo_broken)
        _score_system.new_record.connect(_on_new_record)

        # Connect EchoSystem signals
        _echo_system.echo_available.connect(_on_echo_available)
        _echo_system.echo_completed.connect(_on_echo_completed)

        # Build the UI and memory nodes
        _create_ui()
        _create_memory_nodes()
        _create_particles()
        _create_camera()

        # Start the game after a short delay
        _state = GameState.IDLE
        _show_message("Get Ready")
        get_tree().create_timer(1.0).timeout.connect(_start_new_sequence)


func _input(event: InputEvent) -> void:
        # Back button via keyboard
        if event.is_action_pressed("ui_back") and _state != GameState.GAME_OVER:
                _on_back_pressed()

#endregion

#region ── UI creation ────────────────────────────────────────────────────────

## Build all HUD elements programmatically and position them for a 720×1280 viewport.
func _create_ui() -> void:
        # ── Top HUD bar ──────────────────────────────────────────────────────
        _hud_container = VBoxContainer.new()
        _hud_container.name = "HUD"
        _hud_container.set_anchors_preset(Control.PRESET_TOP_WIDE)
        _hud_container.offset_bottom = 160
        _hud_container.offset_top = 20
        add_child(_hud_container)

        # Score row
        var score_row := HBoxContainer.new()
        score_row.alignment = BoxContainer.ALIGNMENT_CENTER
        score_row.add_theme_constant_override("separation", 24)
        _hud_container.add_child(score_row)

        _score_label = _make_label("Score: 0", 24)
        score_row.add_child(_score_label)

        _combo_label = _make_label("Combo: 0", 24)
        score_row.add_child(_combo_label)

        # Level / streak row
        var level_row := HBoxContainer.new()
        level_row.alignment = BoxContainer.ALIGNMENT_CENTER
        level_row.add_theme_constant_override("separation", 24)
        _hud_container.add_child(level_row)

        _level_label = _make_label("Level: 1", 22)
        level_row.add_child(_level_label)

        _streak_label = _make_label("Streak: 0 days", 18)
        level_row.add_child(_streak_label)

        # Lives row (hearts)
        _lives_container = HBoxContainer.new()
        _lives_container.alignment = BoxContainer.ALIGNMENT_CENTER
        _lives_container.add_theme_constant_override("separation", 8)
        _hud_container.add_child(_lives_container)
        _refresh_lives_display()

        # ── Centre message label ─────────────────────────────────────────────
        _message_label = Label.new()
        _message_label.name = "MessageLabel"
        _message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        _message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        _message_label.set_anchors_preset(Control.PRESET_CENTER)
        _message_label.position = Vector2(-120, -30)
        _message_label.size = Vector2(240, 60)
        _message_label.add_theme_font_size_override("font_size", 36)
        _message_label.add_theme_color_override("font_color", Color.WHITE)
        _message_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
        _message_label.add_theme_constant_override("outline_size", 4)
        add_child(_message_label)

        # ── Back button (top-left) ───────────────────────────────────────────
        _back_button = Button.new()
        _back_button.name = "BackButton"
        _back_button.text = "← Back"
        _back_button.position = Vector2(12, 12)
        _back_button.size = Vector2(100, 40)
        _back_button.pressed.connect(_on_back_pressed)
        add_child(_back_button)

        # Show streak
        var streak := SaveManager.get_streak_days()
        _streak_label.text = "Streak: %d days" % streak


## Helper to create a styled Label.
func _make_label(text: String, font_size: int) -> Label:
        var label := Label.new()
        label.text = text
        label.add_theme_font_size_override("font_size", font_size)
        label.add_theme_color_override("font_color", Color.WHITE)
        label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
        label.add_theme_constant_override("outline_size", 3)
        return label

#endregion

#region ── Memory node creation ───────────────────────────────────────────────

## Create and position 6 MemoryNode instances in 2 rows of 3.
func _create_memory_nodes() -> void:
        _node_container = Control.new()
        _node_container.name = "MemoryNodes"
        _node_container.set_anchors_preset(Control.PRESET_CENTER)
        add_child(_node_container)

        var node_size := Vector2(160, 160)
        var gap := 24.0
        var cols := 3
        var rows := 2
        var total_w := float(cols) * node_size.x + float(cols - 1) * gap
        var total_h := float(rows) * node_size.y + float(rows - 1) * gap
        var start_x := -total_w / 2.0
        var start_y := -total_h / 2.0 + 40.0  # Offset down slightly from centre

        for i in range(6):
                var node := MemoryNode.new()
                node.color_index = i
                node.name = "MemoryNode%d" % i
                node.size = node_size

                var col := i % cols
                var row := i / cols
                node.position = Vector2(
                        start_x + float(col) * (node_size.x + gap),
                        start_y + float(row) * (node_size.y + gap)
                )

                node.tapped.connect(_on_node_tapped)
                _node_container.add_child(node)
                _memory_nodes.append(node)

                # Entrance animation with staggered delay
                node.play_entrance_animation(0.1 + float(i) * 0.08)

#endregion

#region ── Effects ────────────────────────────────────────────────────────────

## Create a simple GPUParticles2D for perfect-sequence celebrations.
func _create_particles() -> void:
        _particles = GPUParticles2D.new()
        _particles.name = "CelebrationParticles"
        _particles.emitting = false
        _particles.amount = 40
        _particles.lifetime = 1.2
        _particles.one_shot = true
        _particles.explosiveness = 0.9
        _particles.position = Vector2(0, 0)

        var process_mat := ParticleProcessMaterial.new()
        process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
        process_mat.direction = Vector3(0, -1, 0)
        process_mat.spread = 60.0
        process_mat.gravity = Vector3(0, 200, 0)
        process_mat.initial_velocity_min = 150.0
        process_mat.initial_velocity_max = 350.0
        process_mat.scale_min = 3.0
        process_mat.scale_max = 6.0

        # Use a simple gradient for particle colour (warm white → gold)
        var gradient := Gradient.new()
        gradient.colors = PackedColorArray([Color.WHITE, Color.GOLD])
        gradient.offsets = PackedFloat32Array([0.0, 1.0])
        var color_ramp := GradientTexture1D.new()
        color_ramp.gradient = gradient
        process_mat.color_ramp = color_ramp

        _particles.process_material = process_mat
        add_child(_particles)


## Create a Camera2D for screen-shake effects.
func _create_camera() -> void:
        _camera = Camera2D.new()
        _camera.name = "ShakeCamera"
        _camera.position_smoothing_enabled = false
        add_child(_camera)


## Trigger a small screen shake (used on failure).
func _shake_screen() -> void:
        if not _camera:
                return
        var tween := create_tween()
        for i in range(4):
                var offset := Vector2(randf_range(-SHAKE_AMOUNT, SHAKE_AMOUNT),
                                                          randf_range(-SHAKE_AMOUNT, SHAKE_AMOUNT))
                tween.tween_property(_camera, "offset", offset, SHAKE_DURATION / 4.0)\
                        .set_trans(Tween.TRANS_SINE)
        tween.tween_property(_camera, "offset", Vector2.ZERO, SHAKE_DURATION / 4.0)\
                .set_trans(Tween.TRANS_SINE)

#endregion

#region ── Game flow ──────────────────────────────────────────────────────────

## Generate and begin showing a new sequence to the player.
func _start_new_sequence() -> void:
        _mistakes_this_sequence = 0
        _player_index = 0
        _is_echo_round = false
        _current_echo_data = {}

        # Check if an echo should appear instead of a regular sequence
        var echo_data := _echo_system.check_echo_appearance()
        if echo_data != null and echo_data is Dictionary:
                _current_sequence = echo_data.get("sequence", [])
                _is_echo_round = true
                _current_echo_data = echo_data
                _show_message("Echo...")
                await get_tree().create_timer(0.8).timeout
        else:
                _current_sequence = _sequence_generator.generate_sequence(
                        GameManager.current_level
                )

        _show_message("")
        _show_sequence()


## Animate the sequence display: flash each node in order with a delay.
func _show_sequence() -> void:
        _state = GameState.SHOWING_SEQUENCE
        _set_nodes_interactive(false)

        var speed := GameManager.get_sequence_speed()

        for i in range(_current_sequence.size()):
                var color_idx: int = _current_sequence[i]
                var node := _memory_nodes[color_idx]

                # Schedule the flash
                get_tree().create_timer(float(i) * speed).timeout.connect(
                        func(): _flash_node_safe(node, speed * 0.8)
                )

        # After the entire sequence is shown, switch to player turn
        var total_time := float(_current_sequence.size()) * speed + 0.3
        get_tree().create_timer(total_time).timeout.connect(_begin_player_turn)


## Helper to safely flash a node (guards against null if scene changed).
func _flash_node_safe(node: MemoryNode, duration: float) -> void:
        if is_instance_valid(node):
                node.flash(duration)


## Switch to PLAYER_TURN state and enable interaction.
func _begin_player_turn() -> void:
        _state = GameState.PLAYER_TURN
        _player_index = 0
        _set_nodes_interactive(true)

        # Highlight nodes subtly to indicate they're tappable
        for node in _memory_nodes:
                if node.is_active:
                        node.set_active(true)


## Handle a memory node tap from the player.
func _on_node_tapped(index: int) -> void:
        if _state != GameState.PLAYER_TURN:
                return

        AudioManager.play_tone(index, 0.2)

        if index == _current_sequence[_player_index]:
                # Correct tap
                _player_index += 1

                if _player_index >= _current_sequence.size():
                        # Sequence fully completed
                        _set_nodes_interactive(false)
                        _on_sequence_success()
        else:
                # Wrong tap
                _set_nodes_interactive(false)
                _on_sequence_failure()

#endregion

#region ── Success / Failure handlers ─────────────────────────────────────────

## Handle a successfully completed sequence.
func _on_sequence_success() -> void:
        _state = GameState.EVALUATING

        var result := _score_system.on_sequence_completed(
                _current_sequence.size(), _mistakes_this_sequence
        )

        # Audio & visual feedback
        AudioManager.play_success_chime()

        # Floating score text
        var centre := size / 2.0
        _score_system.create_floating_text("+%d" % result.score, centre, self)

        if result.perfect:
                _particles.emitting = true
                _show_message("Perfect!")
                await get_tree().create_timer(0.8).timeout
                _show_message("")
        else:
                await get_tree().create_timer(0.3).timeout

        # Update HUD
        _refresh_hud()

        # Emotion reward
        var emotion := _score_system.calculate_emotion_reward(result.perfect, result.combo)
        GameManager.collect_emotion(emotion)

        # Handle echo round completion
        if _is_echo_round:
                _echo_system.complete_echo(_current_echo_data)

        # Level progression
        _sequences_completed += 1
        if _sequences_completed >= SEQUENCES_PER_LEVEL:
                _level_up()

        # Next sequence
        get_tree().create_timer(0.5).timeout.connect(_start_new_sequence)


## Handle a failed sequence.
func _on_sequence_failure() -> void:
        _state = GameState.EVALUATING

        _score_system.on_sequence_failed()
        AudioManager.play_failure_sound()
        _shake_screen()

        _lives -= 1
        _refresh_lives_display()
        _refresh_hud()

        _show_message("Miss!")
        await get_tree().create_timer(1.0).timeout
        _show_message("")

        # Register the failed sequence as a potential echo
        _echo_system.register_failed_sequence(_current_sequence, GameManager.current_level)

        if _lives <= 0:
                show_game_over()
        else:
                get_tree().create_timer(0.5).timeout.connect(_start_new_sequence)

#endregion

#region ── Level progression ──────────────────────────────────────────────────

## Level up: increase difficulty, play fanfare, and reset the per-level counter.
func _level_up() -> void:
        GameManager.current_level += 1
        GameManager.level_up.emit(GameManager.current_level)
        AudioManager.play_level_up_fanfare()

        _sequences_completed = 0
        _show_message("Level %d!" % GameManager.current_level)
        _refresh_hud()

        await get_tree().create_timer(1.2).timeout
        _show_message("")

#endregion

#region ── Game Over ──────────────────────────────────────────────────────────

## Display the game-over screen with run stats and a save button.
func show_game_over() -> void:
        _state = GameState.GAME_OVER
        _set_nodes_interactive(false)
        GameManager.end_game()

        var summary := _score_system.get_run_summary()

        # Build a panel overlay
        var overlay := ColorRect.new()
        overlay.name = "GameOverOverlay"
        overlay.color = Color(0, 0, 0, 0.85)
        overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
        overlay.mouse_filter = Control.MOUSE_FILTER_STOP
        add_child(overlay)

        var panel := VBoxContainer.new()
        panel.alignment = BoxContainer.ALIGNMENT_CENTER
        panel.set_anchors_preset(Control.PRESET_CENTER)
        panel.position = Vector2(-150, -200)
        panel.size = Vector2(300, 400)
        overlay.add_child(panel)

        # Title
        var title := _make_label("Game Over", 40)
        title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        panel.add_child(title)

        # Stats
        panel.add_child(_make_label("Score: %d" % summary.score, 28))
        panel.add_child(_make_label("Max Combo: %d" % summary.max_combo, 24))
        panel.add_child(_make_label("Perfect: %d" % summary.perfect_count, 22))
        panel.add_child(_make_label("Sequences: %d" % summary.sequences_completed, 22))
        if summary.is_new_record:
                panel.add_child(_make_label("★ NEW RECORD! ★", 26))

        # Save button
        var save_btn := Button.new()
        save_btn.text = "Save & Return"
        save_btn.custom_minimum_size = Vector2(200, 50)
        save_btn.pressed.connect(func():
                SaveManager.save_game()
                SceneManager.transition_to("main_menu")
        )
        panel.add_child(save_btn)

        # Retry button
        var retry_btn := Button.new()
        retry_btn.text = "Retry"
        retry_btn.custom_minimum_size = Vector2(200, 50)
        retry_btn.pressed.connect(func():
                overlay.queue_free()
                _restart_game()
        )
        panel.add_child(retry_btn)

#endregion

#region ── HUD refresh ────────────────────────────────────────────────────────

## Refresh all HUD labels with current values.
func _refresh_hud() -> void:
        _score_label.text = "Score: %d" % _score_system.run_score
        _combo_label.text = "Combo: %d" % _score_system.run_combo
        _level_label.text = "Level: %d" % GameManager.current_level


## Rebuild the lives display (heart icons as Unicode strings).
func _refresh_lives_display() -> void:
        for child in _lives_container.get_children():
                child.queue_free()

        for i in range(MAX_LIVES):
                var heart := Label.new()
                heart.add_theme_font_size_override("font_size", 28)
                if i < _lives:
                        heart.text = "♥"
                        heart.add_theme_color_override("font_color", Color("FF4B5C"))
                else:
                        heart.text = "♡"
                        heart.add_theme_color_override("font_color", Color.GRAY)
                _lives_container.add_child(heart)

#endregion

#region ── Utility ────────────────────────────────────────────────────────────

## Show a temporary message in the centre of the screen.
func _show_message(text: String) -> void:
        _message_label.text = text
        _message_label.visible = not text.is_empty()


## Set whether all memory nodes accept player input.
func _set_nodes_interactive(interactive: bool) -> void:
        for node in _memory_nodes:
                node.is_interactive = interactive


## Restart the game with a clean slate.
func _restart_game() -> void:
        _lives = MAX_LIVES
        _sequences_completed = 0
        _score_system.reset_run()
        GameManager.reset_run()
        GameManager.start_game()
        _refresh_hud()
        _refresh_lives_display()
        _state = GameState.IDLE
        _show_message("Get Ready")
        get_tree().create_timer(1.0).timeout.connect(_start_new_sequence)


## Navigate back to the main menu.
func _on_back_pressed() -> void:
        AudioManager.play_ui_click()
        if _state == GameState.GAME_OVER or _state == GameState.IDLE:
                SceneManager.transition_to("main_menu")
        else:
                # Confirm quit during gameplay
                _state = GameState.IDLE
                GameManager.end_game()
                SceneManager.transition_to("main_menu")

#endregion

#region ── Signal callbacks ───────────────────────────────────────────────────

func _on_score_added(amount: int, position: Vector2) -> void:
        _score_system.create_floating_text("+%d" % amount, position, self)


func _on_combo_broken() -> void:
        _show_message("Combo Broken!")
        await get_tree().create_timer(0.6).timeout
        _show_message("")


func _on_new_record(score: int) -> void:
        _show_message("★ New Record! ★")
        await get_tree().create_timer(1.0).timeout
        _show_message("")


func _on_echo_available(echo_data: Dictionary) -> void:
        print("[GameScene] Echo available from level %d" % echo_data.get("original_level", 0))


func _on_echo_completed(echo_data: Dictionary, bonus_xp: int) -> void:
        _score_system.create_floating_text("Echo +%d XP" % bonus_xp, size / 2.0, self)
        _refresh_hud()

#endregion
