## GardenElement — Visual representation of a sanctuary item on the garden grid.
## Draws different shapes based on item type and growth stage, with emotion-based
## colours, idle animations, radiant glow effects, and a tooltip on long press.
extends Control
class_name GardenElement

# ---------------------------------------------------------------------------
# Exports & Properties
# ---------------------------------------------------------------------------

## Unique identifier matching the SanctuaryManager entry.
@export var item_id: String = ""
## Which kind of sanctuary item this represents.
@export var item_type: int = 0  # SanctuaryManager.ItemType
## Current growth stage (0-3).
@export var growth_stage: int = 0
## Emotion that was spent to create this item.
@export var emotion_type: int = 0  # GameManager.EmotionType
## Base colour derived from [member emotion_type].
var base_color: Color = Color.WHITE

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Emotion → colour mapping used across the game.
const EMOTION_COLORS: Dictionary = {
        0: Color(1.0, 0.92, 0.40),   # JOY       — warm yellow
        1: Color(0.65, 0.50, 0.82),  # NOSTALGIA — soft purple
        2: Color(0.90, 0.22, 0.18),  # ANGER     — red
        3: Color(0.58, 0.82, 0.95),  # SERENITY  — light blue
        4: Color(0.20, 0.90, 0.90),  # WONDER    — cyan
        5: Color(0.52, 0.58, 0.72),  # MELANCHOLY — grey-blue
        6: Color(1.0, 0.60, 0.20),   # COURAGE   — orange
        7: Color(1.0, 0.95, 0.70),   # HOPE      — white-gold
}

## Friendly names for each growth stage.
const STAGE_NAMES: Array = ["Seed", "Sprout", "Blooming", "Radiant"]

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

var _float_tween: Tween
var _glow_alpha: float = 0.0
var _long_press_timer: float = 0.0
var _is_long_pressing: bool = false

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
        custom_minimum_size = Vector2(80, 80)
        base_color = EMOTION_COLORS.get(emotion_type, Color.WHITE)
        _start_idle_animation()

func _process(delta: float) -> void:
        # Handle long-press detection for tooltip.
        if _is_long_pressing:
                _long_press_timer += delta
                if _long_press_timer >= 0.6:
                        _show_tooltip()
                        _is_long_pressing = false

        queue_redraw()

# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
        if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
                if event.pressed:
                        _is_long_pressing = true
                        _long_press_timer = 0.0
                else:
                        _is_long_pressing = false
        elif event is InputEventScreenTouch:
                if event.pressed:
                        _is_long_pressing = true
                        _long_press_timer = 0.0
                else:
                        _is_long_pressing = false

# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw() -> void:
        var center: Vector2 = size / 2.0
        var c: Color = base_color

        # Radiant glow behind the element.
        if growth_stage >= 3:
                var glow_color: Color = Color(c.r, c.g, c.b, 0.18 + 0.08 * sin(Time.get_ticks_msec() / 400.0))
                draw_circle(center, 36.0, glow_color)

        # Dispatch drawing based on item type.
        match item_type:
                0: _draw_tree(center, c)
                1: _draw_flower(center, c)
                2: _draw_crystal(center, c)
                3: _draw_water(center, c)
                4: _draw_light(center, c)
                5: _draw_decoration(center, c)

# -- Tree -------------------------------------------------------------------

func _draw_tree(c: Vector2, col: Color) -> void:
        match growth_stage:
                0: # seed — small circle
                        draw_circle(c, 5.0, col)
                1: # sprout — triangle
                        var pts: PackedVector2Array = [
                                c + Vector2(0, -22), c + Vector2(-14, 12), c + Vector2(14, 12),
                        ]
                        draw_colored_polygon(pts, col)
                2: # blooming — trunk + circle canopy
                        draw_rect(Rect2(c.x - 3, c.y, 6, 18), Color(col.r * 0.5, col.g * 0.4, col.b * 0.2))
                        draw_circle(c + Vector2(0, -10), 16.0, col)
                3: # radiant — full tree with glow ring
                        draw_rect(Rect2(c.x - 4, c.y - 2, 8, 22), Color(col.r * 0.5, col.g * 0.4, col.b * 0.2))
                        draw_circle(c + Vector2(0, -14), 20.0, col)
                        draw_circle(c + Vector2(0, -14), 20.0, Color(col.r, col.g, col.b, 0.25))

# -- Flower -----------------------------------------------------------------

func _draw_flower(c: Vector2, col: Color) -> void:
        match growth_stage:
                0: draw_circle(c, 4.0, col)
                1:
                        for i: int in range(5):
                                var angle: float = TAU * i / 5.0
                                draw_circle(c + Vector2(cos(angle), sin(angle)) * 8.0, 5.0, col)
                2:
                        for i: int in range(7):
                                var angle: float = TAU * i / 7.0
                                draw_circle(c + Vector2(cos(angle), sin(angle)) * 12.0, 7.0, col)
                        draw_circle(c, 5.0, Color(col.r * 1.2, col.g * 1.2, col.b * 0.8))
                3:
                        for i: int in range(9):
                                var angle: float = TAU * i / 9.0 + Time.get_ticks_msec() / 3000.0
                                draw_circle(c + Vector2(cos(angle), sin(angle)) * 15.0, 8.0, col)
                        draw_circle(c, 6.0, Color(1.0, 1.0, 0.85))

# -- Crystal ----------------------------------------------------------------

func _draw_crystal(c: Vector2, col: Color) -> void:
        match growth_stage:
                0: _draw_diamond(c, 6.0, col)
                1: _draw_diamond(c + Vector2(0, 4), 10.0, col)
                2:
                        _draw_diamond(c + Vector2(0, 6), 12.0, col)
                        _draw_diamond(c + Vector2(-8, 2), 7.0, col)
                        _draw_diamond(c + Vector2(8, 2), 7.0, col)
                3:
                        _draw_diamond(c, 16.0, col)
                        _draw_diamond(c + Vector2(-10, 4), 9.0, col)
                        _draw_diamond(c + Vector2(10, 4), 9.0, col)
                        draw_circle(c, 20.0, Color(col.r, col.g, col.b, 0.15))

func _draw_diamond(c: Vector2, r: float, col: Color) -> void:
        var pts: PackedVector2Array = [
                c + Vector2(0, -r), c + Vector2(r * 0.6, 0),
                c + Vector2(0, r),  c + Vector2(-r * 0.6, 0),
        ]
        draw_colored_polygon(pts, col)

# -- Water Feature ----------------------------------------------------------

func _draw_water(c: Vector2, col: Color) -> void:
        var water_col: Color = Color(col.r * 0.6, col.g * 0.7, col.b)
        match growth_stage:
                0: draw_circle(c, 8.0, Color(water_col.r, water_col.g, water_col.b, 0.5))
                1:
                        draw_rect(Rect2(c.x - 18, c.y + 4, 36, 6), Color(water_col.r, water_col.g, water_col.b, 0.5))
                2:
                        draw_circle(c - Vector2(0, 8), 10.0, water_col)
                        draw_rect(Rect2(c.x - 14, c.y + 4, 28, 8), Color(water_col.r, water_col.g, water_col.b, 0.4))
                3:
                        draw_circle(c - Vector2(0, 10), 14.0, water_col)
                        draw_rect(Rect2(c.x - 18, c.y + 6, 36, 10), Color(water_col.r, water_col.g, water_col.b, 0.35))
                        draw_circle(c, 22.0, Color(water_col.r, water_col.g, water_col.b, 0.12))

# -- Light Source -----------------------------------------------------------

func _draw_light(c: Vector2, col: Color) -> void:
        match growth_stage:
                0: draw_circle(c, 3.0, col)
                1: _draw_flame(c, 10.0, col)
                2:
                        draw_rect(Rect2(c.x - 3, c.y, 6, 14), Color(0.55, 0.45, 0.30))
                        _draw_flame(c - Vector2(0, 10), 12.0, col)
                3:
                        draw_circle(c, 16.0, Color(col.r, col.g, col.b, 0.18 + 0.07 * sin(Time.get_ticks_msec() / 250.0)))
                        draw_circle(c, 8.0, col)

func _draw_flame(c: Vector2, h: float, col: Color) -> void:
        var pts: PackedVector2Array = [
                c + Vector2(-h * 0.4, h * 0.3),
                c + Vector2(0, -h * 0.7),
                c + Vector2(h * 0.4, h * 0.3),
        ]
        draw_colored_polygon(pts, col)

# -- Decoration -------------------------------------------------------------

func _draw_decoration(c: Vector2, col: Color) -> void:
        match growth_stage:
                0: draw_rect(Rect2(c.x - 5, c.y - 3, 10, 8), Color(0.6, 0.55, 0.50))
                1: draw_rect(Rect2(c.x - 8, c.y - 6, 16, 14), col.darkened(0.3))
                2:
                        draw_rect(Rect2(c.x - 10, c.y - 8, 20, 18), col)
                        draw_rect(Rect2(c.x - 3, c.y - 12, 6, 5), col.lightened(0.2))
                3:
                        draw_rect(Rect2(c.x - 12, c.y - 10, 24, 22), col)
                        draw_circle(c, 24.0, Color(col.r, col.g, col.b, 0.13))

# ---------------------------------------------------------------------------
# Animations
# ---------------------------------------------------------------------------

## Subtle floating / swaying idle animation.
func _start_idle_animation() -> void:
        _float_tween = create_tween().set_loops()
        _float_tween.tween_property(self, "position:y", position.y - 3.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        _float_tween.tween_property(self, "position:y", position.y + 3.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Transition to a new growth stage with a scale bounce.
func set_growth_stage(stage: int) -> void:
        growth_stage = stage
        var tween: Tween = create_tween()
        tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.15).set_trans(Tween.TRANS_BACK)
        tween.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC)
        queue_redraw()

## Bounce + sparkle when first placed.
func play_place_animation() -> void:
        var tween: Tween = create_tween()
        tween.tween_property(self, "scale", Vector2(1.3, 0.7), 0.08).set_trans(Tween.TRANS_SINE)
        tween.tween_property(self, "scale", Vector2(0.8, 1.2), 0.10).set_trans(Tween.TRANS_SINE)
        tween.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC)

# ---------------------------------------------------------------------------
# Tooltip
# ---------------------------------------------------------------------------

func _show_tooltip() -> void:
        var type_names: Array = ["Tree", "Flower", "Crystal", "Water Feature", "Light Source", "Decoration"]
        var tooltip_text: String = "%s (%s)\nStage: %s" % [
                type_names[item_type] if item_type < type_names.size() else "???",
                EmotionFragment.new(emotion_type).get_display_name(),
                STAGE_NAMES[growth_stage] if growth_stage < STAGE_NAMES.size() else "???"
        ]
        # Display a simple label tooltip above the element.
        var label: Label = Label.new()
        label.text = tooltip_text
        label.position = Vector2(0, -40)
        label.add_theme_font_size_override("font_size", 12)
        label.add_theme_color_override("font_color", Color.WHITE)
        label.add_theme_color_override("font_shadow_color", Color.BLACK)
        label.add_theme_constant_override("shadow_offset_x", 1)
        label.add_theme_constant_override("shadow_offset_y", 1)
        add_child(label)
        get_tree().create_timer(2.5).timeout.connect(label.queue_free)
