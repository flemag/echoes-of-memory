## EmotionFragment — Lightweight data class for a single emotion fragment type.
## Provides display name, description, colour, icon symbol, and rarity info.
## Extends RefCounted (not Node) as it is a pure-data object.
extends RefCounted
class_name EmotionFragment

# ---------------------------------------------------------------------------
# Properties
# ---------------------------------------------------------------------------

## Which emotion this fragment represents (index into GameManager.EmotionType).
var emotion_type: int
## How many of this fragment the player owns.
var quantity: int = 0
## ISO-date string when this emotion was first discovered.
var discovered_date: String = ""
## Origin descriptor, e.g. "Level 5 Perfect".
var source: String = ""
## Rarity tier: "common", "uncommon", or "rare".
var rarity: String = "common"

# ---------------------------------------------------------------------------
# Static Mappings
# ---------------------------------------------------------------------------

## Emotion index → rarity tier.
const RARITY_MAP: Dictionary = {
        0: "common",    # JOY
        1: "uncommon",  # NOSTALGIA
        2: "common",    # ANGER
        3: "uncommon",  # SERENITY
        4: "rare",      # WONDER
        5: "uncommon",  # MELANCHOLY
        6: "rare",      # COURAGE
        7: "rare",      # HOPE
}

## Emotion index → display colour.
const COLOR_MAP: Dictionary = {
        0: Color(1.0, 0.92, 0.40),   # JOY       — warm yellow
        1: Color(0.65, 0.50, 0.82),  # NOSTALGIA — soft purple
        2: Color(0.90, 0.22, 0.18),  # ANGER     — red
        3: Color(0.58, 0.82, 0.95),  # SERENITY  — light blue
        4: Color(0.20, 0.90, 0.90),  # WONDER    — cyan
        5: Color(0.52, 0.58, 0.72),  # MELANCHOLY — grey-blue
        6: Color(1.0, 0.60, 0.20),   # COURAGE   — orange
        7: Color(1.0, 0.95, 0.70),   # HOPE      — white-gold
}

## Emotion index → unicode icon symbol.
const SYMBOL_MAP: Dictionary = {
        0: "☀",   # JOY
        1: "☽",   # NOSTALGIA
        2: "⚡",  # ANGER
        3: "☯",   # SERENITY
        4: "✦",   # WONDER
        5: "☂",   # MELANCHOLY
        6: "⚔",   # COURAGE
        7: "✧",   # HOPE
}

## Emotion index → human-readable name.
const NAME_MAP: Dictionary = {
        0: "Joy",
        1: "Nostalgia",
        2: "Anger",
        3: "Serenity",
        4: "Wonder",
        5: "Melancholy",
        6: "Courage",
        7: "Hope",
}

## Emotion index → flavour description.
const DESC_MAP: Dictionary = {
        0: "A warm glow of happiness, found in moments of pure delight.",
        1: "A bittersweet shimmer of times gone by, treasured and tender.",
        2: "A fierce ember of righteous fury, burning bright and unyielding.",
        3: "A calm ripple of inner peace, still and reflective as a mountain lake.",
        4: "A brilliant spark of awe, igniting the desire to explore the unknown.",
        5: "A quiet mist of sorrow, carrying the weight of beautiful losses.",
        6: "A blazing brand of bravery, standing firm against the darkness.",
        7: "A radiant star of optimism, guiding the way through the longest night.",
}

# ---------------------------------------------------------------------------
# Constructor
# ---------------------------------------------------------------------------

func _init(emotion: int = 0, qty: int = 0, date: String = "", src: String = "") -> void:
        emotion_type = emotion
        quantity = qty
        discovered_date = date
        source = src
        rarity = RARITY_MAP.get(emotion, "common")

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Returns the human-readable name for this emotion.
func get_display_name() -> String:
        return NAME_MAP.get(emotion_type, "Unknown")

## Returns the flavour text description for this emotion.
func get_description() -> String:
        return DESC_MAP.get(emotion_type, "???")

## Returns the colour associated with this emotion.
func get_color() -> Color:
        return COLOR_MAP.get(emotion_type, Color.GRAY)

## Returns the unicode symbol used as an icon for this emotion.
func get_icon_symbol() -> String:
        return SYMBOL_MAP.get(emotion_type, "?")

## Convenience: whether this fragment's rarity is "rare".
func is_rare() -> bool:
        return rarity == "rare"
