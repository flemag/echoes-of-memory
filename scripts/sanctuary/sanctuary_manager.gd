## SanctuaryManager — Manages the sanctuary/garden that grows over time.
## Tracks placed items, calculates growth based on real-time elapsed hours,
## handles idle resource generation (memory dust), and serialises state for saving.
extends Node
class_name SanctuaryManager

# ---------------------------------------------------------------------------
# Enums & Constants
# ---------------------------------------------------------------------------

## Types of items that can be placed in the sanctuary garden.
enum ItemType {
        TREE,
        FLOWER,
        CRYSTAL,
        WATER_FEATURE,
        LIGHT_SOURCE,
        DECORATION,
}

## Growth stages: seed → sprout → blooming → radiant.
enum GrowthStage {
        SEED = 0,
        SPROUT = 1,
        BLOOMING = 2,
        RADIANT = 3,
}

## Real-time duration (seconds) required for each growth transition.
const GROWTH_TIMES: Dictionary = {
        GrowthStage.SEED:    3600.0,   # 1 hour
        GrowthStage.SPROUT:  14400.0,  # 4 hours
        GrowthStage.BLOOMING: 43200.0, # 12 hours
}

## Memory dust generated per hour by each radiant item.
const DUST_PER_HOUR: float = 1.0

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when a new item is placed in the garden.
signal item_placed(item_data: Dictionary)
## Emitted when an item advances to a new growth stage.
signal item_grew(item_data: Dictionary, new_stage: int)
## Emitted when memory dust is passively collected from radiant items.
signal dust_collected(amount: int)

# ---------------------------------------------------------------------------
# Internal State
# ---------------------------------------------------------------------------

## All placed sanctuary items, keyed by their unique id.
var _items: Dictionary = {}
## Running total of uncollected memory dust.
var _pending_dust: float = 0.0
## Accumulated memory dust available for spending.
var memory_dust: int = 0
## Timestamp of the last time dust was calculated (UNIX epoch).
var _last_dust_check: float = 0.0
## Auto-incrementing id counter for new items.
var _next_id: int = 0

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
        _last_dust_check = Time.get_unix_time_from_system()
        # Load previously saved sanctuary data
        var saved_data = SaveManager.get_data().get("sanctuary_items", {})
        if saved_data is Dictionary and not saved_data.is_empty():
                load_sanctuary_data(saved_data)

func _process(_delta: float) -> void:
        # Check for dust generation every frame (lightweight — just a time compare).
        var now: float = Time.get_unix_time_from_system()
        var elapsed: float = now - _last_dust_check
        if elapsed >= 3600.0:
                var hours: int = int(elapsed / 3600.0)
                _collect_dust(hours)
                _last_dust_check = now

# ---------------------------------------------------------------------------
# Growth Calculation
# ---------------------------------------------------------------------------

## Returns the current growth stage (0-3) for an item based on how much
## real-world time has elapsed since [param placed_time].
func calculate_growth(placed_time: float) -> int:
        var elapsed: float = Time.get_unix_time_from_system() - placed_time
        var stage: int = GrowthStage.SEED

        # Walk through each threshold; the item is at the highest stage whose
        # cumulative time requirement has been met.
        var cumulative: float = 0.0
        for s: int in [GrowthStage.SEED, GrowthStage.SPROUT, GrowthStage.BLOOMING]:
                cumulative += GROWTH_TIMES[s]
                if elapsed >= cumulative:
                        stage = s + 1
                else:
                        break

        return mini(stage, GrowthStage.RADIANT)

# ---------------------------------------------------------------------------
# Item Placement
# ---------------------------------------------------------------------------

## Attempts to place a new item of [param item_type] at [param position]
## using [param emotion] from the player's collection.
## Returns [code]true[/code] on success, [code]false[/code] if the emotion
## fragment is not available.
func place_item(item_type: ItemType, position: Vector2, emotion: int) -> bool:
        # Check if the emotion exists in the collection
        if not CollectionManager.has_emotion(emotion):
                return false
        if CollectionManager.get_emotion_quantity(emotion) <= 0:
                return false

        # Consume one fragment via the CollectionManager autoload.
        if not CollectionManager.consume_emotion(emotion, 1):
                return false

        var now: float = Time.get_unix_time_from_system()
        var item_data: Dictionary = {
                "id":              "sanctuary_%d" % _next_id,
                "type":            item_type,
                "position":        position,
                "growth_stage":    GrowthStage.SEED,
                "emotion_needed":  emotion,
                "placed_time":     now,
        }

        _next_id += 1
        _items[item_data["id"]] = item_data
        item_placed.emit(item_data)
        _save()
        return true

## Returns items the player can currently afford to place (they possess the
## required emotion fragment for each).
func get_available_items() -> Array:
        var available: Array = []
        for type: int in ItemType.values():
                for emotion: int in GameManager.EmotionType.values():
                        if CollectionManager.has_emotion(emotion) and CollectionManager.get_emotion_quantity(emotion) > 0:
                                available.append({"type": type, "emotion": emotion})
        return available

# ---------------------------------------------------------------------------
# Dust (Idle Currency)
# ---------------------------------------------------------------------------

## Collect memory dust produced by radiant items over [param hours].
func _collect_dust(hours: int) -> void:
        var radiant_count: int = 0
        for item: Dictionary in _items.values():
                if item["growth_stage"] >= GrowthStage.RADIANT:
                        radiant_count += 1

        var earned: int = radiant_count * hours
        if earned > 0:
                memory_dust += earned
                dust_collected.emit(earned)
                _save()

# ---------------------------------------------------------------------------
# Biome Appearance
# ---------------------------------------------------------------------------

## Returns a dictionary of visual properties for the given [param biome].
func get_biome_appearance(biome: String) -> Dictionary:
        var appearances: Dictionary = {
                "meadow": {
                        "bg_top":    Color(0.55, 0.82, 0.45),
                        "bg_bottom": Color(0.28, 0.58, 0.22),
                        "particle":  "leaves",
                },
                "forest": {
                        "bg_top":    Color(0.18, 0.38, 0.14),
                        "bg_bottom": Color(0.08, 0.20, 0.06),
                        "particle":  "leaves",
                },
                "cavern": {
                        "bg_top":    Color(0.22, 0.12, 0.35),
                        "bg_bottom": Color(0.10, 0.05, 0.18),
                        "particle":  "crystals",
                },
                "ocean": {
                        "bg_top":    Color(0.18, 0.42, 0.72),
                        "bg_bottom": Color(0.05, 0.15, 0.40),
                        "particle":  "bubbles",
                },
                "cosmos": {
                        "bg_top":    Color(0.05, 0.02, 0.15),
                        "bg_bottom": Color(0.0, 0.0, 0.05),
                        "particle":  "stars",
                },
        }
        return appearances.get(biome, appearances["meadow"])

# ---------------------------------------------------------------------------
# Serialisation
# ---------------------------------------------------------------------------

## Returns a dictionary suitable for persisting via SaveManager.
func get_sanctuary_data() -> Dictionary:
        return {
                "items":         _items.duplicate(true),
                "memory_dust":   memory_dust,
                "pending_dust":  _pending_dust,
                "last_dust_check": _last_dust_check,
                "next_id":       _next_id,
        }

## Restores state from a dictionary previously saved by [method get_sanctuary_data].
func load_sanctuary_data(data: Dictionary) -> void:
        _items         = data.get("items", {})
        memory_dust    = data.get("memory_dust", 0)
        _pending_dust  = data.get("pending_dust", 0.0)
        _last_dust_check = data.get("last_dust_check", Time.get_unix_time_from_system())
        _next_id       = data.get("next_id", 0)

        # Refresh growth stages for all loaded items.
        for item: Dictionary in _items.values():
                var new_stage: int = calculate_growth(item["placed_time"])
                if new_stage != item["growth_stage"]:
                        var old_stage: int = item["growth_stage"]
                        item["growth_stage"] = new_stage
                        item_grew.emit(item, new_stage)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Persist current state through the SaveManager autoload.
func _save() -> void:
        SaveManager.get_data()["sanctuary_items"] = get_sanctuary_data()
        SaveManager.save_game()
