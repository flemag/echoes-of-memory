## CollectionManager — Manages the player's collection of emotion fragments.
## Tracks quantities, enforces consumption rules for the sanctuary, and
## emits signals so UI can react to collection changes.
extends Node
class_name CollectionManager

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when a new fragment is added or an existing quantity increases.
signal emotion_added(emotion_type: int, quantity: int)
## Emitted whenever the collection changes (add, consume, load).
signal collection_updated

# ---------------------------------------------------------------------------
# Internal State
# ---------------------------------------------------------------------------

## Maps emotion_type (int) → quantity (int).
var _collection: Dictionary = {}
## Maps emotion_type (int) → metadata dictionary {discovered_date, sources}.
var _metadata: Dictionary = {}

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
        # Load any previously saved fragment data.
        var saved = SaveManager.get_data().get("emotion_fragments", [])
        if saved is Array:
                for entry: Dictionary in saved:
                        var etype: int = entry.get("emotion_type", -1)
                        if etype >= 0:
                                _collection[etype] = entry.get("quantity", 0)
                                _metadata[etype] = {
                                        "discovered_date": entry.get("discovered_date", ""),
                                        "sources": entry.get("sources", []),
                                }

# ---------------------------------------------------------------------------
# Adding Emotions
# ---------------------------------------------------------------------------

## Add one fragment of [param emotion_type], optionally noting the [param source]
## string (e.g. "Level 5 Perfect").  Creates the entry if it's the first.
func add_emotion(emotion_type: int, source: String = "") -> void:
        var is_new: bool = not _collection.has(emotion_type)
        _collection[emotion_type] = _collection.get(emotion_type, 0) + 1

        if is_new:
                _metadata[emotion_type] = {
                        "discovered_date": Time.get_date_string_from_system(),
                        "sources": [],
                }

        if source != "" and _metadata.has(emotion_type):
                var sources: Array = _metadata[emotion_type].get("sources", [])
                if not sources.has(source):
                        sources.append(source)
                        _metadata[emotion_type]["sources"] = sources

        emotion_added.emit(emotion_type, _collection[emotion_type])
        collection_updated.emit()
        _persist()

# ---------------------------------------------------------------------------
# Querying
# ---------------------------------------------------------------------------

## Returns an array of dictionaries, one per discovered emotion, with all data.
func get_collection() -> Array[Dictionary]:
        var result: Array[Dictionary] = []
        for etype: int in _collection:
                var frag: EmotionFragment = EmotionFragment.new(etype, _collection[etype])
                var meta: Dictionary = _metadata.get(etype, {})
                result.append({
                        "emotion_type":   etype,
                        "quantity":       _collection[etype],
                        "rarity":         frag.rarity,
                        "color":          frag.get_color(),
                        "name":           frag.get_display_name(),
                        "icon":           frag.get_icon_symbol(),
                        "description":    frag.get_description(),
                        "discovered_date": meta.get("discovered_date", ""),
                        "sources":        meta.get("sources", []),
                })
        return result

## Total number of individual fragments across all emotions.
func get_total_fragments() -> int:
        var total: int = 0
        for qty: int in _collection.values():
                total += qty
        return total

## Percentage of unique emotions discovered (out of 8 total).
func get_completion_percentage() -> float:
        return (_collection.size() / 8.0) * 100.0

## Whether the player has discovered the given [param emotion_type].
func has_emotion(emotion_type: int) -> bool:
        return _collection.get(emotion_type, 0) > 0

## Quantity of a specific emotion currently owned.
func get_emotion_quantity(emotion_type: int) -> int:
        return _collection.get(emotion_type, 0)

# ---------------------------------------------------------------------------
# Consumption
# ---------------------------------------------------------------------------

## Attempt to spend [param amount] fragments of [param emotion_type].
## Returns [code]true[/code] on success; [code]false[/code] if insufficient.
func consume_emotion(emotion_type: int, amount: int = 1) -> bool:
        var current: int = _collection.get(emotion_type, 0)
        if current < amount:
                return false

        _collection[emotion_type] = current - amount

        # If quantity reaches zero, keep the metadata so the UI can still show
        # the emotion was once discovered, but mark it as depleted.
        collection_updated.emit()
        _persist()
        return true

# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

func _persist() -> void:
        var serialised: Array = []
        for etype: int in _collection:
                var meta: Dictionary = _metadata.get(etype, {})
                serialised.append({
                        "emotion_type":    etype,
                        "quantity":        _collection[etype],
                        "discovered_date": meta.get("discovered_date", ""),
                        "sources":         meta.get("sources", []),
                })
        SaveManager.get_data()["emotion_fragments"] = serialised
        SaveManager.save_game()
