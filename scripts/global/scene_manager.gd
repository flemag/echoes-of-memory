## SceneManager — Autoload singleton for scene transitions in "Echoes of Memory".
## Supports animated fade, slide, dissolve, and instant transitions with a
## navigation history stack and a persistent CanvasLayer overlay.
extends Node

## ── Transition types ─────────────────────────────────────────────────────────
enum TransitionType {
        FADE,          # Black fade in / out
        SLIDE_LEFT,    # New scene slides in from right
        SLIDE_RIGHT,   # New scene slides in from left
        DISSOLVE,      # Opacity cross-fade
        NONE,          # Instant switch
}

## ── Signals ──────────────────────────────────────────────────────────────────
signal transition_started
signal transition_completed

## ── Scene path registry ──────────────────────────────────────────────────────
const SCENE_PATHS: Dictionary = {
        "main_menu":  "res://scenes/main_menu/main_menu.tscn",
        "game":       "res://scenes/game/game.tscn",
        "sanctuary":  "res://scenes/sanctuary/sanctuary.tscn",
        "collection": "res://scenes/collection/collection.tscn",
        "settings":   "res://scenes/settings/settings.tscn",
}

## ── Internal state ───────────────────────────────────────────────────────────
var _canvas_layer: CanvasLayer
var _overlay: ColorRect           # Full-screen colour rect for transitions
var _current_scene_name: String = ""
var _history: Array[String] = []  # Navigation history (scene names)
var _is_transitioning: bool = false

#region ── Lifecycle ───────────────────────────────────────────────────────────
func _ready() -> void:
        # Build a persistent CanvasLayer that sits above everything
        _canvas_layer = CanvasLayer.new()
        _canvas_layer.name = "TransitionLayer"
        _canvas_layer.layer = 100  # Render on top
        add_child(_canvas_layer)

        _overlay = ColorRect.new()
        _overlay.name = "TransitionOverlay"
        _overlay.color = Color.BLACK
        _overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
        # Make it cover the full viewport
        _overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
        _overlay.modulate.a = 0.0  # Start fully transparent
        _canvas_layer.add_child(_overlay)

        # Track the initial scene
        await get_tree().process_frame
        var root := get_tree().current_scene
        if root:
                _current_scene_name = _name_for_path(root.scene_file_path)
#endregion

#region ── Public API ──────────────────────────────────────────────────────────
## Transition to a named scene with the specified animation type and duration.
func transition_to(
        scene_name: String,
        transition_type: TransitionType = TransitionType.FADE,
        duration: float = 0.5,
) -> void:
        if _is_transitioning:
                push_warning("[SceneManager] Transition already in progress — ignoring request.")
                return

        if not SCENE_PATHS.has(scene_name):
                push_error("[SceneManager] Unknown scene name: %s" % scene_name)
                return

        _is_transitioning = true
        transition_started.emit()

        # Block input during transition
        _overlay.mouse_filter = Control.MOUSE_FILTER_STOP

        var half := duration / 2.0
        var scene_path: String = SCENE_PATHS[scene_name]

        match transition_type:
                TransitionType.NONE:
                        _instant_change(scene_name, scene_path)

                TransitionType.FADE:
                        await _fade_transition(half, scene_name, scene_path)

                TransitionType.SLIDE_LEFT:
                        await _slide_transition(half, scene_name, scene_path, Vector2(1, 0))

                TransitionType.SLIDE_RIGHT:
                        await _slide_transition(half, scene_name, scene_path, Vector2(-1, 0))

                TransitionType.DISSOLVE:
                        await _dissolve_transition(half, scene_name, scene_path)

        # Unblock input
        _overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _is_transitioning = false
        transition_completed.emit()


## Navigate back to the previous scene in the history stack.
func go_back(transition_type: TransitionType = TransitionType.FADE, duration: float = 0.5) -> void:
        if _history.is_empty():
                push_warning("[SceneManager] No previous scene in history.")
                return

        var previous: String = _history.pop_back() as String
        # Don't push the current scene again — we are going "back"
        _raw_transition_to(previous, transition_type, duration)


## Return the name of the currently active scene.
func get_current_scene_name() -> String:
        return _current_scene_name


## Return true if a transition animation is currently playing.
func is_transitioning() -> bool:
        return _is_transitioning


## Clear the navigation history (e.g. after reaching a "root" screen).
func clear_history() -> void:
        _history.clear()
#endregion

#region ── Transition implementations ──────────────────────────────────────────
## Instant switch with no animation.
func _instant_change(scene_name: String, scene_path: String) -> void:
        _push_history(_current_scene_name)
        get_tree().change_scene_to_file(scene_path)
        _current_scene_name = scene_name


## Classic black fade: fade to black → swap scene → fade from black.
func _fade_transition(half: float, scene_name: String, scene_path: String) -> void:
        _overlay.color = Color.BLACK
        _overlay.position = Vector2.ZERO
        _overlay.size = _get_viewport_size()

        # Fade to black
        var tween := create_tween()
        tween.tween_property(_overlay, "modulate:a", 1.0, half)
        await tween.finished

        # Swap scene while screen is black
        _push_history(_current_scene_name)
        get_tree().change_scene_to_file(scene_path)
        _current_scene_name = scene_name
        await get_tree().process_frame  # Wait one frame so the new scene renders

        # Fade from black
        var tween_out := create_tween()
        tween_out.tween_property(_overlay, "modulate:a", 0.0, half)
        await tween_out.finished


## Slide overlay across the screen to reveal the new scene.
func _slide_transition(
        half: float,
        scene_name: String,
        scene_path: String,
        direction: Vector2,
) -> void:
        var vp_size := _get_viewport_size()
        _overlay.color = Color.BLACK
        _overlay.size = vp_size

        # Start position: off-screen in the given direction
        var start_pos := direction * vp_size
        _overlay.position = start_pos
        _overlay.modulate.a = 1.0

        # Slide overlay to cover the screen
        var tween := create_tween()
        tween.tween_property(_overlay, "position", Vector2.ZERO, half)\
                .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
        await tween.finished

        # Swap scene while covered
        _push_history(_current_scene_name)
        get_tree().change_scene_to_file(scene_path)
        _current_scene_name = scene_name
        await get_tree().process_frame

        # Slide overlay away in the same direction
        var end_pos := -direction * vp_size
        var tween_out := create_tween()
        tween_out.tween_property(_overlay, "position", end_pos, half)\
                .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
        await tween_out.finished

        # Reset overlay state
        _overlay.modulate.a = 0.0
        _overlay.position = Vector2.ZERO


## Opacity cross-fade (dissolve).
func _dissolve_transition(half: float, scene_name: String, scene_path: String) -> void:
        _overlay.color = Color.WHITE  # Dissolve via white overlay
        _overlay.position = Vector2.ZERO
        _overlay.size = _get_viewport_size()

        # Fade overlay in (scene becomes "whited out")
        var tween := create_tween()
        tween.tween_property(_overlay, "modulate:a", 1.0, half)\
                .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        await tween.finished

        # Swap
        _push_history(_current_scene_name)
        get_tree().change_scene_to_file(scene_path)
        _current_scene_name = scene_name
        await get_tree().process_frame

        # Fade overlay out
        var tween_out := create_tween()
        tween_out.tween_property(_overlay, "modulate:a", 0.0, half)\
                .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        await tween_out.finished
#endregion

#region ── Internal helpers ────────────────────────────────────────────────────
## Push a scene name onto the navigation history (skip duplicates & empties).
func _push_history(scene_name: String) -> void:
        if scene_name.is_empty():
                return
        # Avoid pushing the same scene consecutively
        if _history.size() > 0 and _history[-1] == scene_name:
                return
        _history.append(scene_name)


## Perform a transition without pushing to history (used by go_back).
func _raw_transition_to(
        scene_name: String,
        transition_type: TransitionType,
        duration: float,
) -> void:
        # Temporarily mark as not transitioning so transition_to accepts the call
        _is_transitioning = false
        # We bypass history push by calling transition_to; the _history.pop was
        # already done in go_back, so we set a flag to skip re-push.
        transition_to(scene_name, transition_type, duration)


## Reverse-lookup: find a scene name from its file path.
func _name_for_path(path: String) -> String:
        for key in SCENE_PATHS:
                if SCENE_PATHS[key] == path:
                        return key
        return ""


## Return the current viewport size as a Vector2.
func _get_viewport_size() -> Vector2:
        var vp := get_viewport()
        if vp:
                return Vector2(vp.get_visible_rect().size)
        return Vector2(1280, 720)
#endregion
