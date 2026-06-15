## SanctuaryScene — Main sanctuary / garden view.
## Displays a 2D garden with a biome-themed background, grid-based placement,
## ambient particles, an item palette, dust counter, and offline-rewards popup.
extends Control

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const GRID_COLS: int = 6
const GRID_ROWS: int = 8
const CELL_SIZE: Vector2 = Vector2(80, 80)
const PALETTE_HEIGHT: float = 120.0

# Biome background gradients (top / bottom colours).
const BIOME_GRADIENTS: Dictionary = {
        "meadow":  [Color(0.55, 0.82, 0.45), Color(0.28, 0.58, 0.22)],
        "forest":  [Color(0.18, 0.38, 0.14), Color(0.08, 0.20, 0.06)],
        "cavern":  [Color(0.22, 0.12, 0.35), Color(0.10, 0.05, 0.18)],
        "ocean":   [Color(0.18, 0.42, 0.72), Color(0.05, 0.15, 0.40)],
        "cosmos":  [Color(0.05, 0.02, 0.15), Color(0.0, 0.0, 0.05)],
}

# Particle config per biome: colour, amount, direction, speed.
const PARTICLE_CONFIG: Dictionary = {
        "meadow":  {"color": Color(0.4, 0.7, 0.2), "amount": 12, "direction": Vector3(30, 80, 0), "speed": 30},
        "forest":  {"color": Color(0.2, 0.5, 0.1), "amount": 18, "direction": Vector3(-20, 100, 0), "speed": 25},
        "cavern":  {"color": Color(0.5, 0.4, 0.8), "amount": 10, "direction": Vector3(0, -40, 0), "speed": 15},
        "ocean":   {"color": Color(0.6, 0.85, 1.0), "amount": 20, "direction": Vector3(5, -60, 0), "speed": 20},
        "cosmos":  {"color": Color(1.0, 1.0, 0.9), "amount": 30, "direction": Vector3(0, 10, 0), "speed": 8},
}

# ---------------------------------------------------------------------------
# Internal References
# ---------------------------------------------------------------------------

var _grid_container: GridContainer
var _palette_panel: HBoxContainer
var _dust_label: Label
var _biome_label: Label
var _background: ColorRect
var _particles: GPUParticles2D
var _selected_item_type: int = -1  # SanctuaryManager.ItemType
var _selected_emotion: int = -1

# Track cell buttons for the grid.
var _cell_buttons: Array = []

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
        # Build the scene hierarchy.
        _create_background()
        _create_ambient_particles(GameManager.current_biome)
        _create_grid()
        _create_item_palette()
        _create_hud()
        _load_placed_items()
        _check_offline_growth()

        AudioManager.play_sanctuary_ambient(GameManager.current_biome)

# ---------------------------------------------------------------------------
# Background
# ---------------------------------------------------------------------------

## Draw a full-screen gradient appropriate for the current biome.
func _create_background() -> void:
        _background = ColorRect.new()
        _background.set_anchors_preset(Control.PRESET_FULL_RECT)

        var gradient: Gradient = Gradient.new()
        var colors: Array = BIOME_GRADIENTS.get(GameManager.current_biome, BIOME_GRADIENTS["meadow"])
        gradient.set_colors(PackedColorArray([colors[0], colors[1]]))
        gradient.set_offsets(PackedFloat32Array([0.0, 1.0]))

        var stylebox: StyleBoxTexture = StyleBoxTexture.new()
        var tex: GradientTexture2D = GradientTexture2D.new()
        tex.gradient = gradient
        tex.fill = GradientTexture2D.FILL_VERTICAL
        tex.fill_from = Vector2(0.5, 0.0)
        tex.fill_to = Vector2(0.5, 1.0)
        tex.size = Vector2(2, 256)
        stylebox.texture = tex
        stylebox.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

        _background.add_theme_stylebox_override("panel", stylebox)
        add_child(_background)

# ---------------------------------------------------------------------------
# Ambient Particles
# ---------------------------------------------------------------------------

## Creates a [GPUParticles2D] node configured for the given [param biome].
func _create_ambient_particles(biome: String) -> void:
        # Remove previous particles if swapping biomes.
        if _particles:
                _particles.queue_free()

        var config: Dictionary = PARTICLE_CONFIG.get(biome, PARTICLE_CONFIG["meadow"])

        _particles = GPUParticles2D.new()
        _particles.amount = config["amount"]
        _particles.process_material = ParticleProcessMaterial.new()
        var mat: ParticleProcessMaterial = _particles.process_material

        mat.particle_flag_disable_z = true
        mat.direction = config["direction"]
        mat.spread = 30.0
        mat.initial_velocity_min = config["speed"] * 0.5
        mat.initial_velocity_max = config["speed"]
        mat.gravity = Vector3(0, 20, 0)
        mat.scale_min = 2.0
        mat.scale_max = 5.0
        mat.color = config["color"]

        # Set emission area to cover the screen.
        mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
        mat.emission_box_extents = Vector3(600, 10, 1)

        _particles.position = Vector2(40, -20)
        _particles.lifetime = 6.0
        _particles.explosiveness = 0.0
        _particles.randomness = 0.8

        add_child(_particles)

# ---------------------------------------------------------------------------
# Placement Grid
# ---------------------------------------------------------------------------

## Build the 6×8 grid of tappable cells.
func _create_grid() -> void:
        var grid_wrapper: CenterContainer = CenterContainer.new()
        grid_wrapper.set_anchors_preset(Control.PRESET_CENTER)
        grid_wrapper.position = Vector2(0, 60)
        grid_wrapper.size = Vector2(CELL_SIZE.x * GRID_COLS, CELL_SIZE.y * GRID_ROWS)

        _grid_container = GridContainer.new()
        _grid_container.columns = GRID_COLS
        _grid_container.add_theme_constant_override("h_separation", 2)
        _grid_container.add_theme_constant_override("v_separation", 2)

        for row: int in range(GRID_ROWS):
                for col: int in range(GRID_COLS):
                        var btn: Button = Button.new()
                        btn.custom_minimum_size = CELL_SIZE
                        btn.flat = true
                        btn.add_theme_stylebox_override("normal", _make_cell_style(Color(1, 1, 1, 0.06)))
                        btn.add_theme_stylebox_override("hover", _make_cell_style(Color(1, 1, 1, 0.12)))
                        btn.add_theme_stylebox_override("pressed", _make_cell_style(Color(1, 1, 1, 0.18)))
                        btn.pressed.connect(_on_grid_cell_tapped.bind(Vector2(col, row)))
                        _cell_buttons.append(btn)
                        _grid_container.add_child(btn)

        grid_wrapper.add_child(_grid_container)
        add_child(grid_wrapper)

func _make_cell_style(bg: Color) -> StyleBoxFlat:
        var s: StyleBoxFlat = StyleBoxFlat.new()
        s.bg_color = bg
        s.corner_radius_top_left = 4
        s.corner_radius_top_right = 4
        s.corner_radius_bottom_left = 4
        s.corner_radius_bottom_right = 4
        return s

# ---------------------------------------------------------------------------
# Item Palette
# ---------------------------------------------------------------------------

## Bottom panel listing items the player can afford to place.
func _create_item_palette() -> void:
        var panel: PanelContainer = PanelContainer.new()
        panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
        panel.custom_minimum_size.y = PALETTE_HEIGHT

        var scroll: ScrollContainer = ScrollContainer.new()
        scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
        scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

        _palette_panel = HBoxContainer.new()
        _palette_panel.add_theme_constant_override("separation", 8)

        scroll.add_child(_palette_panel)
        panel.add_child(scroll)
        add_child(panel)

        _refresh_palette()

func _refresh_palette() -> void:
        for child: Node in _palette_panel.get_children():
                child.queue_free()

        var available: Array = SanctuaryManager.get_available_items()
        for entry: Dictionary in available:
                var btn: Button = Button.new()
                var type_names: Array = ["Tree", "Flower", "Crystal", "Water", "Light", "Decor"]
                var frag: EmotionFragment = EmotionFragment.new(entry["emotion"])
                btn.text = "%s %s" % [type_names[entry["type"]] if entry["type"] < type_names.size() else "?", frag.get_icon_symbol()]
                btn.custom_minimum_size = Vector2(90, 60)
                btn.pressed.connect(_on_palette_item_selected.bind(entry["type"], entry["emotion"]))
                _palette_panel.add_child(btn)

func _on_palette_item_selected(item_type: int, emotion: int) -> void:
        _selected_item_type = item_type
        _selected_emotion = emotion
        AudioManager.play_ui_click()

# ---------------------------------------------------------------------------
# HUD
# ---------------------------------------------------------------------------

func _create_hud() -> void:
        # Top bar.
        var top_bar: HBoxContainer = HBoxContainer.new()
        top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
        top_bar.offset_bottom = 50

        # Back button.
        var back: Button = Button.new()
        back.text = "< Back"
        back.pressed.connect(_on_back_pressed)
        top_bar.add_child(back)

        # Biome label.
        _biome_label = Label.new()
        _biome_label.text = _format_biome_display()
        _biome_label.add_theme_font_size_override("font_size", 18)
        top_bar.add_child(_biome_label)

        # Spacer.
        var spacer: Control = Control.new()
        spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        top_bar.add_child(spacer)

        # Dust counter.
        _dust_label = Label.new()
        _dust_label.text = "Dust: %d" % SanctuaryManager.memory_dust
        _dust_label.add_theme_font_size_override("font_size", 16)
        top_bar.add_child(_dust_label)

        add_child(top_bar)

func _format_biome_display() -> String:
        var biome: String = GameManager.current_biome.capitalize()
        var level: int = GameManager.current_level
        var next_req: int = (GameManager.BIOMES.find(GameManager.current_biome) + 1) * 5
        return "%s  (Lv %d — Next at %d)" % [biome, level, next_req]

# ---------------------------------------------------------------------------
# Grid Interaction
# ---------------------------------------------------------------------------

## Handle a tap on grid cell at [param cell_position] (col, row).
func _on_grid_cell_tapped(cell_position: Vector2) -> void:
        AudioManager.play_ui_click()

        if _selected_item_type < 0:
                return

        var pos: Vector2 = cell_position
        if SanctuaryManager.place_item(_selected_item_type, pos, _selected_emotion):
                _spawn_garden_element(_selected_item_type, pos, _selected_emotion)
                _refresh_palette()
                _dust_label.text = "Dust: %d" % SanctuaryManager.memory_dust

        _selected_item_type = -1
        _selected_emotion = -1

# ---------------------------------------------------------------------------
# Placed Items
# ---------------------------------------------------------------------------

func _load_placed_items() -> void:
        for item: Dictionary in SanctuaryManager._items.values():
                _spawn_garden_element(item["type"], item["position"], item["emotion_needed"], item.get("placed_time", Time.get_unix_time_from_system()))

func _spawn_garden_element(item_type: int, cell_pos: Vector2, emotion: int, placed_time: float = 0.0) -> void:
        var elem: Control = GardenElement.new()
        elem.item_type = item_type
        elem.emotion_type = emotion
        if placed_time > 0.0:
                elem.growth_stage = SanctuaryManager.calculate_growth(placed_time)
        else:
                elem.growth_stage = 0  # Newly placed items start as seeds
        elem.position = Vector2(cell_pos.x * CELL_SIZE.x, cell_pos.y * CELL_SIZE.y)
        add_child(elem)
        elem.play_place_animation()

# ---------------------------------------------------------------------------
# Offline Rewards
# ---------------------------------------------------------------------------

func _check_offline_growth() -> void:
        var last_ts: float = SaveManager.get_data().get("sanctuary_items", {}).get("last_dust_check", Time.get_unix_time_from_system())
        var rewards: Dictionary = IdleGrowth.calculate_offline_growth(last_ts)
        if rewards.get("time_away", 0.0) >= 600.0:
                if not rewards["grown_items"].is_empty() or rewards["dust_earned"] > 0:
                        _show_offline_rewards(rewards)

## Display a popup summarising what happened while the player was away.
func _show_offline_rewards(rewards: Dictionary) -> void:
        var popup: PanelContainer = PanelContainer.new()
        popup.set_anchors_preset(Control.PRESET_CENTER)
        popup.custom_minimum_size = Vector2(340, 220)

        var vbox: VBoxContainer = VBoxContainer.new()
        var title: Label = Label.new()
        title.text = "While you were away..."
        title.add_theme_font_size_override("font_size", 20)
        title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        vbox.add_child(title)

        var hours: float = rewards["time_away"] / 3600.0
        var info: Label = Label.new()
        info.text = "Away for %.1f hours" % hours
        info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        vbox.add_child(info)

        for g: Dictionary in rewards["grown_items"]:
                var lbl: Label = Label.new()
                lbl.text = "  %s grew to stage %d" % [g["id"], g["new_stage"]]
                vbox.add_child(lbl)

        if rewards["dust_earned"] > 0:
                var dust_lbl: Label = Label.new()
                dust_lbl.text = "  +%d Memory Dust" % rewards["dust_earned"]
                vbox.add_child(dust_lbl)

        var ok: Button = Button.new()
        ok.text = "Collect"
        ok.pressed.connect(func(): popup.queue_free())
        vbox.add_child(ok)

        popup.add_child(vbox)
        add_child(popup)

# ---------------------------------------------------------------------------
# Navigation
# ---------------------------------------------------------------------------

func _on_back_pressed() -> void:
        AudioManager.play_ui_click()
        SceneManager.go_back()
