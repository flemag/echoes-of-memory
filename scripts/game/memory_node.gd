## MemoryNode — Interactive colour pad for "Echoes of Memory".
## A Control-based node that draws a rounded-rectangle pad with glow effects,
## handles touch/mouse input, and animates flashes, pulses, and entrances.
extends Control
class_name MemoryNode

## ── Signals ──────────────────────────────────────────────────────────────────
signal tapped(color_index: int)

## ── Colour schemes (base / highlight pairs) ──────────────────────────────────
const COLOR_SCHEMES: Array[Dictionary] = [
        { base = Color("FF4B5C"), highlight = Color("FF8A94") },  # 0: Red
        { base = Color("4B9FFF"), highlight = Color("8AC4FF") },  # 1: Blue
        { base = Color("4BFF7C"), highlight = Color("8AFFA8") },  # 2: Green
        { base = Color("FFD84B"), highlight = Color("FFE98A") },  # 3: Yellow
        { base = Color("B44BFF"), highlight = Color("D18AFF") },  # 4: Purple
        { base = Color("FF8A4B"), highlight = Color("FFB88A") },  # 5: Orange
]

## ── Exported / public properties ─────────────────────────────────────────────
@export var color_index: int = 0:
        set(v):
                color_index = clampi(v, 0, COLOR_SCHEMES.size() - 1)
                _apply_colors()

var base_color: Color = Color.WHITE
var highlight_color: Color = Color.WHITE
var is_active: bool = true         # Whether this node participates in the current round
var is_interactive: bool = false   # Whether the player can tap it right now

## ── Internal state ───────────────────────────────────────────────────────────
var _corner_radius: float = 18.0
var _glow_intensity: float = 0.0   # 0–1, drives glow overlay opacity
var _pulse_tween: Tween
var _flash_tween: Tween
var _entrance_tween: Tween
var _dimmed_alpha: float = 0.35    # Opacity when inactive

#region ── Lifecycle ───────────────────────────────────────────────────────────

func _ready() -> void:
        custom_minimum_size = Vector2(100, 100)
        _apply_colors()
        # Start invisible for entrance animation
        modulate.a = 0.0
        scale = Vector2.ZERO


func _draw() -> void:
        var rect := Rect2(Vector2.ZERO, size)
        var bg_alpha := 1.0 if is_active else _dimmed_alpha

        # 1. Draw glow behind the pad when active and glowing
        if _glow_intensity > 0.0 and is_active:
                var glow_color := highlight_color
                glow_color.a = _glow_intensity * 0.6
                var glow_rect := rect.grow(8.0 * _glow_intensity)
                draw_rounded_rect(glow_rect, glow_color, _corner_radius + 4.0)

        # 2. Main pad body
        var body_color := base_color
        body_color.a = bg_alpha
        draw_rounded_rect(rect, body_color, _corner_radius)

        # 3. Highlight overlay (used during flash animation)
        if _glow_intensity > 0.0:
                var hl := highlight_color
                hl.a = _glow_intensity * bg_alpha
                draw_rounded_rect(rect, hl, _corner_radius)

#endregion

#region ── Input handling ─────────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
        if not is_interactive or not is_active:
                return

        # Respond to press (touch is emulated as mouse via project settings)
        if event is InputEventMouseButton:
                if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
                        tapped.emit(color_index)
                        _quick_press_feedback()

#endregion

#region ── Public methods ─────────────────────────────────────────────────────

## Flash this node — animate scale up, switch to highlight colour, play tone.
func flash(duration: float = 0.35) -> void:
        _kill_tween(_flash_tween)

        # Play the corresponding tone via AudioManager
        AudioManager.play_tone(color_index, duration)

        _glow_intensity = 1.0
        queue_redraw()

        _flash_tween = create_tween().set_parallel(true)
        _flash_tween.tween_property(self, "scale", Vector2(1.12, 1.12), duration * 0.3)\
                .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        _flash_tween.tween_property(self, "_glow_intensity", 0.0, duration)\
                .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        _flash_tween.chain().tween_property(self, "scale", Vector2.ONE, duration * 0.4)\
                .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        _flash_tween.finished.connect(func(): queue_redraw())


## Toggle active state with visual feedback — pulse if active, dim if not.
func set_active(active: bool) -> void:
        is_active = active
        _kill_tween(_pulse_tween)

        if active:
                modulate.a = 1.0
                _start_pulse()
        else:
                modulate.a = _dimmed_alpha
                _glow_intensity = 0.0

        queue_redraw()


## Play a spring-like entrance animation with a given delay (seconds).
func play_entrance_animation(delay: float = 0.0) -> void:
        _kill_tween(_entrance_tween)
        modulate.a = 0.0
        scale = Vector2(0.3, 0.3)

        _entrance_tween = create_tween()
        _entrance_tween.tween_interval(delay)
        _entrance_tween.tween_property(self, "modulate:a", 1.0, 0.25)\
                .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        _entrance_tween.tween_property(self, "scale", Vector2.ONE, 0.5)\
                .set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

#endregion

#region ── Private helpers ────────────────────────────────────────────────────

## Apply colours from the scheme table based on color_index.
func _apply_colors() -> void:
        if color_index < 0 or color_index >= COLOR_SCHEMES.size():
                return
        base_color = COLOR_SCHEMES[color_index].base
        highlight_color = COLOR_SCHEMES[color_index].highlight
        queue_redraw()


## Draw a rounded rectangle (filled) using arc segments.
func draw_rounded_rect(rect: Rect2, color: Color, radius: float) -> void:
        var r := minf(radius, minf(rect.size.x, rect.size.y) / 2.0)
        var pos := rect.position
        var s := rect.size

        # Build the polygon using line + arc approximation
        var points := PackedVector2Array()

        # Top-left corner
        points.append(pos + Vector2(r, 0))
        points.append(pos + Vector2(s.x - r, 0))
        # Top-right corner arc
        for i in range(8):
                var angle := -PI / 2.0 + PI / 2.0 * float(i + 1) / 8.0
                points.append(pos + Vector2(s.x - r, r) + Vector2(cos(angle), sin(angle)) * r)
        # Bottom-right corner arc
        points.append(pos + Vector2(s.x, s.y - r))
        for i in range(8):
                var angle := 0.0 + PI / 2.0 * float(i + 1) / 8.0
                points.append(pos + Vector2(s.x - r, s.y - r) + Vector2(cos(angle), sin(angle)) * r)
        # Bottom-left corner arc
        points.append(pos + Vector2(r, s.y))
        for i in range(8):
                var angle := PI / 2.0 + PI / 2.0 * float(i + 1) / 8.0
                points.append(pos + Vector2(r, s.y - r) + Vector2(cos(angle), sin(angle)) * r)
        # Top-left corner arc (close)
        points.append(pos + Vector2(0, r))
        for i in range(8):
                var angle := PI + PI / 2.0 * float(i + 1) / 8.0
                points.append(pos + Vector2(r, r) + Vector2(cos(angle), sin(angle)) * r)

        draw_colored_polygon(points, color)


## Start a gentle idle pulse animation (scale oscillation) for active nodes.
func _start_pulse() -> void:
        _kill_tween(_pulse_tween)
        _pulse_tween = create_tween().set_loops()
        _pulse_tween.tween_property(self, "scale", Vector2(1.04, 1.04), 0.8)\
                .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        _pulse_tween.tween_property(self, "scale", Vector2.ONE, 0.8)\
                .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Small visual feedback on press (quick shrink) before the caller runs flash().
func _quick_press_feedback() -> void:
        var t := create_tween()
        t.tween_property(self, "scale", Vector2(0.92, 0.92), 0.06)\
                .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        t.tween_property(self, "scale", Vector2.ONE, 0.12)\
                .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Safely kill a tween reference.
func _kill_tween(tween: Tween) -> void:
        if tween and tween.is_valid():
                tween.kill()

#endregion
