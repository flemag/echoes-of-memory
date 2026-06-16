## EchoSystem — Manages the "Echo" mechanic in "Echoes of Memory".
## Failed sequences return as modified "echoes" that the player may encounter
## later. Successfully completing an echo grants bonus XP. Echoes expire after
## 24 real hours, and the queue is capped at 5 entries.
extends Node

## ── Signals ──────────────────────────────────────────────────────────────────
signal echo_available(echo_data: Dictionary)
signal echo_completed(echo_data: Dictionary, bonus_xp: int)

## ── Constants ────────────────────────────────────────────────────────────────
const MAX_ECHOES := 5
const ECHO_EXPIRY_HOURS := 24.0
const ECHO_SEQUENCES_BETWEEN_CHECKS := 2  # Check every N successful sequences

## ── Internal state ───────────────────────────────────────────────────────────
var echo_queue: Array[Dictionary] = []   # Each entry: { sequence, original_level, timestamp, variant_count }
var _sequences_since_last_check: int = 0
var _sequence_generator: SequenceGenerator

#region ── Lifecycle ───────────────────────────────────────────────────────────

func _ready() -> void:
        _sequence_generator = SequenceGenerator.new()
        _load_echo_queue()


func _process(_delta: float) -> void:
        # Periodically purge expired echoes
        _purge_expired()

#endregion

#region ── Public API ──────────────────────────────────────────────────────────

## Called when the player fails a sequence. May register the failed sequence
## as an echo depending on GameManager.get_echo_chance().
func register_failed_sequence(sequence: Array[int], level: int) -> void:
        if sequence.is_empty():
                return

        # Cap the queue
        if echo_queue.size() >= MAX_ECHOES:
                return

        # Roll for echo chance
        var chance := GameManager.get_echo_chance()
        var rng := RandomNumberGenerator.new()
        rng.randomize()
        if rng.randf() * 100.0 > chance:
                return  # No echo this time

        # Create the echo variant
        var variant := _sequence_generator.generate_echo_variant(sequence)

        var echo_data := {
                "sequence": variant,
                "original_level": level,
                "timestamp": Time.get_unix_time_from_system(),
                "variant_count": 1,
        }

        echo_queue.append(echo_data)
        _save_echo_queue()

        echo_available.emit(echo_data)
        print("[EchoSystem] Echo registered — level %d, length %d" % [level, variant.size()])


## Called after each successful sequence. Returns a Dictionary (echo_data) if an
## echo should appear now, or null if none is due.
func check_echo_appearance() -> Variant:
        _sequences_since_last_check += 1

        if _sequences_since_last_check < ECHO_SEQUENCES_BETWEEN_CHECKS:
                return null

        _sequences_since_last_check = 0

        # Check if there are pending echoes
        if echo_queue.is_empty():
                return null

        # Pick the oldest echo (FIFO)
        var echo_data: Dictionary = echo_queue[0]

        # Play the echo sound to build atmosphere
        AudioManager.play_echo_sound()

        return echo_data


## Called when the player successfully completes an echo sequence.
## Grants 1.5× bonus XP and removes the echo from the queue.
func complete_echo(echo_data: Dictionary) -> void:
        var base_xp := echo_data.sequence.size() * 25
        var combo_mult := GameManager.get_combo_multiplier()
        var bonus_xp := int(float(base_xp) * 1.5 * combo_mult)

        GameManager.add_xp(bonus_xp)

        # Remove from queue
        var idx := echo_queue.find(echo_data)
        if idx >= 0:
                echo_queue.remove_at(idx)
                _save_echo_queue()

        echo_completed.emit(echo_data, bonus_xp)
        print("[EchoSystem] Echo completed! Bonus XP: %d" % bonus_xp)


## Return the number of pending echoes in the queue.
func get_pending_echoes() -> int:
        return echo_queue.size()


## Return a flavour-text description of the next pending echo (for UI display).
func get_echo_preview() -> String:
        if echo_queue.is_empty():
                return ""

        var echo: Dictionary = echo_queue[0]
        var level: int = echo.get("original_level", 1)
        var age_seconds := Time.get_unix_time_from_system() - float(echo.get("timestamp", 0.0))
        var age_hours := age_seconds / 3600.0

        # Generate narrative flavour text based on age
        if age_hours < 1.0:
                return "A recent memory from Level %d echoes softly..." % level
        elif age_hours < 6.0:
                return "A fading memory from Level %d resonates..." % level
        else:
                return "A distant memory from Level %d calls out through the haze..." % level

#endregion

#region ── Expiry management ──────────────────────────────────────────────────

## Remove echoes that have been in the queue longer than ECHO_EXPIRY_HOURS.
func _purge_expired() -> void:
        var now := Time.get_unix_time_from_system()
        var i := echo_queue.size() - 1
        while i >= 0:
                var age := now - float(echo_queue[i].get("timestamp", 0.0))
                if age > ECHO_EXPIRY_HOURS * 3600.0:
                        var expired_level: int = echo_queue[i].get("original_level", 0)
                        echo_queue.remove_at(i)
                        print("[EchoSystem] Expired echo from level %d purged" % expired_level)
                i -= 1

#endregion

#region ── Save / Load integration ────────────────────────────────────────────

## Persist the echo queue to SaveManager.
func _save_echo_queue() -> void:
        var save = _get_save_manager()
        if save:
                save.get_data()["echo_queue"] = echo_queue.duplicate(true)


## Load the echo queue from SaveManager on startup.
func _load_echo_queue() -> void:
        var save = _get_save_manager()
        if save:
                var loaded: Variant = save.get_data().get("echo_queue", [])
                if loaded is Array:
                        echo_queue.clear()
                        for entry in loaded:
                                if entry is Dictionary and entry.has("sequence"):
                                        echo_queue.append(entry)
                        # Immediately purge any that expired while the game was closed
                        _purge_expired()

        print("[EchoSystem] Loaded %d pending echoes" % echo_queue.size())


## Safely retrieve the SaveManager autoload.
func _get_save_manager() -> Node:
        var node := get_tree().root.get_node_or_null("SaveManager")
        return node if node else null

#endregion
