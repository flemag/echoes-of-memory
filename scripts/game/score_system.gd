## ScoreSystem — Scoring, combos, XP, and emotion rewards for "Echoes of Memory".
## Tracks per-run statistics, calculates score/XP for completed sequences, and
## determines which EmotionType the player earns based on performance.
extends Node
class_name ScoreSystem

## ── Signals ──────────────────────────────────────────────────────────────────
signal score_added(amount: int, position: Vector2)
signal combo_broken
signal new_record(score: int)

## ── Run statistics ───────────────────────────────────────────────────────────
var run_score: int = 0
var run_combo: int = 0
var run_perfect_count: int = 0
var sequences_in_run: int = 0
var _best_score: int = 0        # Lifetime best for new-record detection

#region ── Lifecycle ───────────────────────────────────────────────────────────

func _ready() -> void:
	# Load best score from save data
	var save: SaveManager = _get_save_manager()
	if save:
		_best_score = int(save.get_data().get("player_progress", {}).get("total_score", 0))

#endregion

#region ── Public API ──────────────────────────────────────────────────────────

## Called when a sequence is completed. Calculates score, XP, and emotion reward.
## Returns: { score: int, xp: int, perfect: bool, combo: int }
func on_sequence_completed(sequence_length: int, mistakes: int) -> Dictionary:
	var perfect := mistakes == 0
	if perfect:
		run_perfect_count += 1

	# Increment combo
	run_combo += 1
	sequences_in_run += 1
	GameManager.increment_combo()

	# Calculate multiplier
	var combo_mult := GameManager.get_combo_multiplier()

	# Score = sequence_length × 100 × combo_multiplier × (1.5 if perfect)
	var score := int(float(sequence_length) * 100.0 * combo_mult)
	if perfect:
		score = int(float(score) * 1.5)

	# XP = sequence_length × 25 × combo_multiplier × (2.0 if perfect)
	var xp := int(float(sequence_length) * 25.0 * combo_mult)
	if perfect:
		xp = int(float(xp) * 2.0)

	# Apply to run total and global
	run_score += score
	GameManager.add_xp(xp)

	# Check for new record
	if run_score > _best_score:
		_best_score = run_score
		new_record.emit(run_score)

	return {
		"score": score,
		"xp": xp,
		"perfect": perfect,
		"combo": run_combo,
	}


## Called when the player fails a sequence. Resets combo, no score added.
func on_sequence_failed() -> void:
	if run_combo > 0:
		combo_broken.emit()
	run_combo = 0
	GameManager.reset_combo()


## Return a summary Dictionary of the current run for the game-over screen.
func get_run_summary() -> Dictionary:
	return {
		"score": run_score,
		"combo": run_combo,
		"max_combo": GameManager.max_combo,
		"perfect_count": run_perfect_count,
		"sequences_completed": sequences_in_run,
		"is_new_record": run_score >= _best_score and run_score > 0,
	}


## Determine which EmotionType to reward based on performance.
##   Perfect + combo >= 5 → rare (WONDER, COURAGE, HOPE)
##   Perfect              → uncommon (SERENITY, NOSTALGIA)
##   Good (combo >= 2)    → common (JOY)
##   Default              → random
func calculate_emotion_reward(perfect: bool, combo: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	if perfect and combo >= 5:
		# Rare emotions: WONDER, COURAGE, HOPE
		var rare := [
			GameManager.EmotionType.WONDER,
			GameManager.EmotionType.COURAGE,
			GameManager.EmotionType.HOPE,
		]
		return rare[rng.randi_range(0, rare.size() - 1)]

	if perfect:
		# Uncommon emotions: SERENITY, NOSTALGIA
		var uncommon := [
			GameManager.EmotionType.SERENITY,
			GameManager.EmotionType.NOSTALGIA,
		]
		return uncommon[rng.randi_range(0, uncommon.size() - 1)]

	if combo >= 2:
		# Common emotion: JOY
		return GameManager.EmotionType.JOY

	# Default: truly random from all emotions
	return rng.randi_range(0, GameManager.EmotionType.size() - 1)


## Create a floating score Label that rises and fades out at the given position.
## The label is added as a child of `parent` and auto-frees after the animation.
func create_floating_text(text: String, position: Vector2, parent: Node) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Style the label with a bold white font and dark outline
	var theme := Theme.new()
	var default_font := ThemeDB.fallback_font
	var font_size := 28
	theme.set_font("font", "Label", default_font)
	theme.set_font_size("font_size", "Label", font_size)
	theme.set_color("font_color", "Label", Color.WHITE)
	theme.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.7))
	theme.set_constant("outline_size", "Label", 3)
	label.theme = theme

	label.position = position - Vector2(60, 20)
	label.size = Vector2(120, 40)
	parent.add_child(label)

	# Animate: rise up + fade out
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 80.0, 1.0)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)


## Reset all run statistics for a new game session.
func reset_run() -> void:
	run_score = 0
	run_combo = 0
	run_perfect_count = 0
	sequences_in_run = 0

#endregion

#region ── Private helpers ────────────────────────────────────────────────────

## Safely retrieve the SaveManager autoload.
func _get_save_manager() -> SaveManager:
	if not get_tree():
		return null
	var node := get_tree().root.get_node_or_null("SaveManager")
	return node as SaveManager if node else null

#endregion
