## GameManager — Autoload singleton managing game state, XP, difficulty, combos,
## biome progression, and emotion rewards for "Echoes of Memory".
extends Node

## ── Enums ────────────────────────────────────────────────────────────────────
enum EmotionType {
        JOY,         # 0
        NOSTALGIA,   # 1
        ANGER,       # 2
        SERENITY,    # 3
        WONDER,      # 4
        MELANCHOLY,  # 5
        COURAGE,     # 6
        HOPE,        # 7
}

## ── Signals ──────────────────────────────────────────────────────────────────
signal level_up(new_level: int)
signal xp_gained(amount: int)
signal combo_changed(new_combo: int)
signal score_changed(new_score: int)
signal game_started
signal game_ended
signal emotion_collected(emotion_type: EmotionType)

## ── Biome configuration ─────────────────────────────────────────────────────
## Ordered list of biome names and the level at which they unlock.
const BIOMES: Array[String] = ["meadow", "forest", "cavern", "ocean", "cosmos"]
const BIOME_UNLOCK_LEVELS: Array[int] = [1, 5, 12, 20, 30]

## Emotion rarity tiers used for reward logic.
const _COMMON_EMOTIONS: Array[EmotionType] = [
        EmotionType.JOY, EmotionType.SERENITY, EmotionType.COURAGE, EmotionType.HOPE,
]
const _RARE_EMOTIONS: Array[EmotionType] = [
        EmotionType.NOSTALGIA, EmotionType.ANGER, EmotionType.WONDER, EmotionType.MELANCHOLY,
]

## ── Public properties ────────────────────────────────────────────────────────
var current_level: int = 1
var current_xp: int = 0
var total_score: int = 0
var combo: int = 0:
        set(v):
                combo = v
                if combo > max_combo:
                        max_combo = combo
                combo_changed.emit(combo)
var max_combo: int = 0
var is_playing: bool = false
var current_difficulty: float = 1.0
var current_biome: String = "meadow"

## ── Internal state ───────────────────────────────────────────────────────────
var _play_time: float = 0.0          # Accumulated seconds this session
var _session_start: float = 0.0      # Timestamp when current run started

#region ── Lifecycle ───────────────────────────────────────────────────────────
func _ready() -> void:
        # Warm-up: ensure biome matches level on load
        current_biome = _biome_for_level(current_level)


func _process(delta: float) -> void:
        if is_playing:
                _play_time += delta
#endregion

#region ── XP & Level system ──────────────────────────────────────────────────
## Calculate XP required to reach the given level.
## Formula: level² × 100 (so level 1→2 needs 200 XP, 2→3 needs 900, etc.)
func xp_needed_for_level(level: int) -> int:
        return level * level * 100


## Grant XP and handle level-ups if threshold is crossed.
func add_xp(amount: int) -> void:
        if amount <= 0:
                return

        current_xp += amount
        xp_gained.emit(amount)

        # Check for one or more level-ups in a single grant
        while current_xp >= xp_needed_for_level(current_level):
                current_xp -= xp_needed_for_level(current_level)
                current_level += 1
                current_difficulty = float(current_level)
                current_biome = _biome_for_level(current_level)
                level_up.emit(current_level)
                print("[GameManager] Level up! Now level %d — biome: %s" % [current_level, current_biome])
#endregion

#region ── Difficulty scaling ──────────────────────────────────────────────────
## How many notes are in a memory sequence for the current level.
## Starts at 3, gains +1 every 3 levels, capping at 15.
func get_sequence_length() -> int:
        var length := 3 + (current_level - 1) / 3
        return mini(length, 15)


## Playback speed per note (seconds). Starts at 0.8s, −0.03 per level, min 0.3s.
func get_sequence_speed() -> float:
        var speed := 0.8 - (current_level - 1) * 0.03
        return maxf(speed, 0.3)


## Percentage chance that a failed sequence is added to the echo queue.
## Ranges from 10 % at level 1 up to 40 % at higher levels.
func get_echo_chance() -> float:
        var chance := 10.0 + current_level * 1.0
        return minf(chance, 40.0)
#endregion

#region ── Combo system ───────────────────────────────────────────────────────
## Increment the combo counter (called on each correct note in a sequence).
func increment_combo() -> void:
        combo += 1


## Reset the combo counter (called on a mistake or new round).
func reset_combo() -> void:
        combo = 0


## Multiplier applied to score based on current combo.
## 1.0 + combo × 0.1, capped at 3.0.
func get_combo_multiplier() -> float:
        return minf(1.0 + combo * 0.1, 3.0)
#endregion

#region ── Score calculation ───────────────────────────────────────────────────
## Compute score for a completed sequence.
## Base = sequence_length × 100, multiplied by combo, with a 1.5× bonus for perfect.
func calculate_score(sequence_length: int, p_combo: int, perfect: bool) -> int:
        var base := sequence_length * 100
        var multiplier := minf(1.0 + p_combo * 0.1, 3.0)
        var score := int(base * multiplier)
        if perfect:
                score = int(score * 1.5)
        return score
#endregion

#region ── Biome helpers ───────────────────────────────────────────────────────
## Return the biome name appropriate for the given level.
func _biome_for_level(level: int) -> String:
        var result := "meadow"
        for i in range(BIOMES.size()):
                if level >= BIOME_UNLOCK_LEVELS[i]:
                        result = BIOMES[i]
        return result


## Return the biome index (0–4) for the current level.
func get_current_biome_index() -> int:
        var idx := 0
        for i in range(BIOMES.size()):
                if current_level >= BIOME_UNLOCK_LEVELS[i]:
                        idx = i
        return idx
#endregion

#region ── Emotion rewards ─────────────────────────────────────────────────────
## Determine an emotion reward based on performance tier.
## - "perfect" → rare emotion
## - "good"    → common emotion
## - "ok"      → random emotion
func determine_emotion_reward(performance: String) -> EmotionType:
        var rng := RandomNumberGenerator.new()
        rng.randomize()

        match performance:
                "perfect":
                        return _RARE_EMOTIONS[rng.randi_range(0, _RARE_EMOTIONS.size() - 1)]
                "good":
                        return _COMMON_EMOTIONS[rng.randi_range(0, _COMMON_EMOTIONS.size() - 1)]
                "ok", _:
                        return rng.randi_range(0, EmotionType.size() - 1) as EmotionType


## Collect an emotion into the save data and emit the signal.
func collect_emotion(emotion: EmotionType) -> void:
        var save = _get_save_manager()
        if save:
                var fragments: Array = save.get_data().get("emotion_fragments", [])
                fragments.append(EmotionType.keys()[emotion])
                save.get_data()["emotion_fragments"] = fragments
        emotion_collected.emit(emotion)
        print("[GameManager] Emotion collected: %s" % EmotionType.keys()[emotion])
#endregion

#region ── Game flow ───────────────────────────────────────────────────────────
## Start a new game run.
func start_game() -> void:
        is_playing = true
        combo = 0
        max_combo = 0
        _play_time = 0.0
        _session_start = Time.get_ticks_msec() / 1000.0
        game_started.emit()
        print("[GameManager] Game started — level %d, biome %s" % [current_level, current_biome])


## End the current run, persist statistics, and signal completion.
func end_game() -> void:
        is_playing = false
        total_score += int(_play_time * 10)  # Participation bonus
        score_changed.emit(total_score)

        # Persist to SaveManager
        var save = _get_save_manager()
        if save:
            var data: Dictionary = save.get_data()  # ← Ajouter le type
                data["player_progress"]["total_score"] = total_score
                data["player_progress"]["level"] = current_level
                data["player_progress"]["xp"] = current_xp
                data["player_progress"]["current_biome"] = current_biome
                var stats: Dictionary = data.get("statistics", {})
                stats["total_plays"] = int(stats.get("total_plays", 0)) + 1
                stats["total_play_time"] = float(stats.get("total_play_time", 0.0)) + _play_time
                data["statistics"] = stats
                save.update_stat("total_plays", stats["total_plays"])

        game_ended.emit()
        print("[GameManager] Game ended — score %d, play time %.1fs" % [total_score, _play_time])


## Reset only the current run state (not persistent progress).
func reset_run() -> void:
        combo = 0
        max_combo = 0
        _play_time = 0.0
        print("[GameManager] Run reset")
#endregion

#region ── Utility ─────────────────────────────────────────────────────────────
## Safely retrieve the SaveManager autoload (may not exist in tests).
func _get_save_manager() -> Node:
        var node := get_tree().root.get_node_or_null("SaveManager")
        return node if node else null


## Return human-readable name for an EmotionType value.
func emotion_name(emotion: EmotionType) -> String:
        return EmotionType.keys()[emotion]


## Return total play time accumulated during this session (seconds).
func get_session_play_time() -> float:
        return _play_time
#endregion
