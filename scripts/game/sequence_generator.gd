## SequenceGenerator — Procedural memory-sequence generation for "Echoes of Memory".
## Creates reproducible, themed sequences using seeded randomness. Each "memory tree"
## (level) has dominant colours that give it a unique feel, with difficulty modifiers
## and trap patterns introduced at higher levels.
extends RefCounted
class_name SequenceGenerator

## ── Constants ────────────────────────────────────────────────────────────────
const COLOR_COUNT := 6          # Indices 0–5
const MIN_THEME_COLORS := 3     # Minimum dominant colours per level theme
const MAX_THEME_COLORS := 4     # Maximum dominant colours per level theme
const TRAP_PATTERN_THRESHOLD := 6  # Level at which trap patterns may appear
const TRAP_CHANCE := 0.15       # Probability of inserting a trap at eligible levels

## ── Internal state ───────────────────────────────────────────────────────────
var _rng: RandomNumberGenerator
var _theme_colors: Array[int] = []   # Dominant colour indices for current level
var _theme_weights: Array[float] = [] # Bias weights matching _theme_colors

#region ── Public API ──────────────────────────────────────────────────────────

## Generate a full memory sequence for the given level.
## `seed_value` of 0 means "use time-based random" (non-reproducible).
## Returns an Array[int] of colour indices (0–5).
func generate_sequence(level: int, seed_value: int = 0) -> Array[int]:
	# Initialise the RNG — a non-zero seed gives reproducible results
	_rng = RandomNumberGenerator.new()
	if seed_value != 0:
		_rng.seed = hash(seed_value)
	else:
		_rng.randomize()

	# Build the colour theme for this level's "memory tree"
	_build_theme(level)

	var length := GameManager.get_sequence_length()
	var sequence: Array[int] = []

	for i in range(length):
		sequence.append(_pick_biased_color())

	# At higher levels, potentially inject a trap pattern
	if level >= TRAP_PATTERN_THRESHOLD and _rng.randf() < TRAP_CHANCE:
		sequence = _inject_trap(sequence)

	return sequence


## Given a failed sequence, produce an "echo variant" — a modified version that
## the player may encounter later. The modification is one of:
##   • Add one extra element at a random position
##   • Swap two random elements
##   • Change one element to a different colour
func generate_echo_variant(failed_sequence: Array[int]) -> Array[int]:
	if failed_sequence.is_empty():
		return []

	_rng = RandomNumberGenerator.new()
	_rng.randomize()

	var variant: Array[int] = failed_sequence.duplicate()
	var modification := _rng.randi_range(0, 2)

	match modification:
		0:  # Add one element
			var new_color := _rng.randi_range(0, COLOR_COUNT - 1)
			var pos := _rng.randi_range(0, variant.size())
			variant.insert(pos, new_color)

		1:  # Swap two elements
			if variant.size() >= 2:
				var idx_a := _rng.randi_range(0, variant.size() - 1)
				var idx_b := _rng.randi_range(0, variant.size() - 1)
				# Ensure they differ
				while idx_b == idx_a and variant.size() > 1:
					idx_b = _rng.randi_range(0, variant.size() - 1)
				var tmp := variant[idx_a]
				variant[idx_a] = variant[idx_b]
				variant[idx_b] = tmp

		2:  # Change one element to a different colour
			var idx := _rng.randi_range(0, variant.size() - 1)
			var old_color := variant[idx]
			var new_color := (old_color + _rng.randi_range(1, COLOR_COUNT - 1)) % COLOR_COUNT
			variant[idx] = new_color

	return variant


## Analyse a sequence and return its theme information.
## Returns: { colors: Array[int], frequencies: Dictionary, dominant: int }
func get_sequence_theme(sequence: Array[int]) -> Dictionary:
	if sequence.is_empty():
		return { colors = [], frequencies = {}, dominant = -1 }

	var frequencies: Dictionary = {}
	for color_idx in sequence:
		if not frequencies.has(color_idx):
			frequencies[color_idx] = 0
		frequencies[color_idx] += 1

	# Sort colours by frequency (descending)
	var sorted_colors: Array[int] = []
	for key in frequencies:
		sorted_colors.append(key)
	sorted_colors.sort_custom(func(a, b): return frequencies[a] > frequencies[b])

	var dominant: int = sorted_colors[0] if sorted_colors.size() > 0 else -1

	return {
		colors = sorted_colors,
		frequencies = frequencies,
		dominant = dominant,
	}

#endregion

#region ── Theme generation ────────────────────────────────────────────────────

## Choose 3–4 dominant colours for this level and assign bias weights.
## Theme colours get significantly higher weight so the sequence feels cohesive.
func _build_theme(level: int) -> void:
	var theme_size := MIN_THEME_COLORS
	if _rng.randf() < 0.5:
		theme_size = MAX_THEME_COLORS

	# Pick unique colour indices for the theme
	var available: Array[int] = []
	for i in range(COLOR_COUNT):
		available.append(i)
	available.shuffle()

	_theme_colors = []
	for i in range(theme_size):
		_theme_colors.append(available[i])

	# Build weight table — theme colours are heavily biased
	# Non-theme colours still appear rarely (10 % each) for variety
	_theme_weights = []
	for i in range(COLOR_COUNT):
		if i in _theme_colors:
			_theme_weights.append(3.0)   # Strong bias for themed colours
		else:
			_theme_weights.append(0.3)   # Rare outlier


## Pick a random colour index weighted by the current theme.
func _pick_biased_color() -> int:
	var total_weight := 0.0
	for w in _theme_weights:
		total_weight += w

	var roll := _rng.randf() * total_weight
	var cumulative := 0.0
	for i in range(_theme_weights.size()):
		cumulative += _theme_weights[i]
		if roll < cumulative:
			return i

	# Fallback (should not reach here)
	return _rng.randi_range(0, COLOR_COUNT - 1)

#endregion

#region ── Trap patterns ──────────────────────────────────────────────────────

## Inject a "trap" pattern into an existing sequence. Trap patterns are
## deliberately tricky sequences such as the same colour 3× in a row, or a
## strict alternating ABABAB pattern. This raises the difficulty ceiling.
func _inject_trap(sequence: Array[int]) -> Array[int]:
	if sequence.size() < 4:
		return sequence  # Too short for meaningful traps

	var trap_type := _rng.randi_range(0, 1)

	match trap_type:
		0:  # Triple-repeat: force 3 consecutive identical colours
			var color := _rng.randi_range(0, COLOR_COUNT - 1)
			var start := _rng.randi_range(0, sequence.size() - 3)
			for i in range(3):
				sequence[start + i] = color

		1:  # Alternating pattern ABAB… for 4+ elements
			var a := _rng.randi_range(0, COLOR_COUNT - 1)
			var b := (a + _rng.randi_range(1, COLOR_COUNT - 1)) % COLOR_COUNT
			var start := _rng.randi_range(0, maxi(sequence.size() - 4, 0))
			var length := mini(4 + _rng.randi_range(0, 2), sequence.size() - start)
			for i in range(length):
				sequence[start + i] = a if i % 2 == 0 else b

	return sequence

#endregion
