## AudioManager — Autoload singleton that generates ALL audio procedurally for
## "Echoes of Memory". No external audio files are required.  Uses a pool of
## AudioStreamPlayer nodes for polyphony and AudioStreamGenerator for synthesis.
class_name AudioManager
extends Node

## ── Constants ────────────────────────────────────────────────────────────────
const POOL_SIZE := 8
const SAMPLE_RATE := 44100.0

## Musical tones mapped to the six memory-node colours.
const COLOR_FREQUENCIES: Array[float] = [
	261.63,  # Red    — C4
	329.63,  # Blue   — E4
	392.00,  # Green  — G4
	523.25,  # Yellow — C5
	659.25,  # Purple — E5
	783.99,  # Orange — G5
]

## ADSR defaults (seconds).
const ATTACK  := 0.02
const DECAY   := 0.08
const SUSTAIN := 0.45   # amplitude multiplier during sustain
const RELEASE := 0.12

## ── Signals ──────────────────────────────────────────────────────────────────
signal music_fade_in_started
signal music_fade_out_completed

## ── Public properties ────────────────────────────────────────────────────────
var master_volume: float = 1.0:
	set(v): master_volume = clampf(v, 0.0, 1.0)
var music_volume: float = 0.8:
	set(v): music_volume = clampf(v, 0.0, 1.0)
var sfx_volume: float = 1.0:
	set(v): sfx_volume = clampf(v, 0.0, 1.0)

## ── Internal state ───────────────────────────────────────────────────────────
var _pool: Array[AudioStreamPlayer] = []
var _pool_index: int = 0
var _music_player: AudioStreamPlayer
var _music_generator: AudioStreamGenerator
var _music_playing: bool = false
var _music_fade_tween: Tween
var _ambient_drone_player: AudioStreamPlayer

#region ── Lifecycle ───────────────────────────────────────────────────────────
func _ready() -> void:
	# Build the polyphony player pool
	for i in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "SFXPlayer%d" % i
		add_child(player)
		_pool.append(player)

	# Background music player (ambient pad)
	_music_generator = AudioStreamGenerator.new()
	_music_generator.mix_rate = SAMPLE_RATE
	_music_generator.buffer_length = 0.5

	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.stream = _music_generator
	_music_player.volume_db = -12.0  # Start quiet; fade in later
	add_child(_music_player)

	# Ambient drone player (separate from music for layering)
	_ambient_drone_player = AudioStreamPlayer.new()
	_ambient_drone_player.name = "AmbientDrone"
	var drone_gen := AudioStreamGenerator.new()
	drone_gen.mix_rate = SAMPLE_RATE
	drone_gen.buffer_length = 0.5
	_ambient_drone_player.stream = drone_gen
	add_child(_ambient_drone_player)
#endregion

#region ── Tone playback (memory nodes) ───────────────────────────────────────
## Play a musical tone for the given colour index (0–5).
func play_tone(color_index: int, duration: float = 0.3) -> void:
	if color_index < 0 or color_index >= COLOR_FREQUENCIES.size():
		push_warning("[AudioManager] Invalid color_index: %d" % color_index)
		return

	var freq := COLOR_FREQUENCIES[color_index]
	var samples := _generate_adsr_tone(freq, duration)
	_play_samples(samples)
	vibrate(30)


## Play a success chime — ascending 3-note chord (C5, E5, G5).
func play_success_chime() -> void:
	var notes: Array[float] = [523.25, 659.25, 783.99]
	var offset := 0.0
	for i in range(notes.size()):
		var dur := 0.22
		var samples := _generate_adsr_tone(notes[i], dur)
		_play_samples_delayed(samples, offset)
		offset += dur * 0.6
	vibrate(50)


## Play a failure sound — descending tone.
func play_failure_sound() -> void:
	var samples := _generate_sweep(440.0, 220.0, 0.4)
	_play_samples(samples)
	vibrate(100)


## Play a short level-up fanfare melody.
func play_level_up_fanfare() -> void:
	var melody: Array[float] = [523.25, 659.25, 783.99, 1046.50]
	var offset := 0.0
	for i in range(melody.size()):
		var dur := 0.18
		var samples := _generate_adsr_tone(melody[i], dur)
		_play_samples_delayed(samples, offset)
		offset += dur * 0.5
	vibrate(80)


## Play an eerie echo / reverb-like effect for failed sequences.
func play_echo_sound() -> void:
	# Two detuned tones create a haunting beating effect
	var s1 := _generate_adsr_tone(392.00, 0.8, 0.04, 0.15, 0.30, 0.35)
	var s2 := _generate_adsr_tone(396.00, 0.8, 0.04, 0.15, 0.30, 0.35)
	var mixed := _mix_buffers(s1, s2, 0.5, 0.5)
	_play_samples(mixed)
	vibrate(60)


## Play a subtle biome-specific ambient drone.
func play_sanctuary_ambient(biome: String) -> void:
	var base_freq := _biome_drone_freq(biome)
	var samples := _generate_drone(base_freq, 4.0)
	var data := samples.to_float32_array()
	var buf := AudioStreamGeneratorPlayback()
	if _ambient_drone_player.playing:
		_ambient_drone_player.stop()
	if _ambient_drone_player.stream is AudioStreamGenerator:
		_ambient_drone_player.play()
		buf = _ambient_drone_player.get_stream_playback() as AudioStreamGeneratorPlayback
		var frames_to_push := mini(data.size(), buf.get_frames_available())
		buf.push_buffer(data.slice(0, frames_to_push))
	_ambient_drone_player.volume_db = -18.0


## UI feedback sounds.
func play_ui_click() -> void:
	var samples := _generate_adsr_tone(880.0, 0.05, 0.005, 0.01, 0.2, 0.02)
	_play_samples(samples)


func play_ui_hover() -> void:
	var samples := _generate_adsr_tone(660.0, 0.04, 0.005, 0.01, 0.15, 0.01)
	_play_samples(samples)
#endregion

#region ── Background music (ambient pad) ──────────────────────────────────────
## Start the generative ambient pad.
func start_music() -> void:
	if _music_playing:
		return
	_music_playing = true
	_music_player.play()
	music_fade_in_started.emit()
	# Continuously push samples each frame
	set_process(true)


## Stop the ambient pad with a fade-out.
func stop_music(fade_duration: float = 1.0) -> void:
	if not _music_playing:
		return
	if _music_fade_tween and _music_fade_tween.is_valid():
		_music_fade_tween.kill()
	_music_fade_tween = create_tween()
	_music_fade_tween.tween_property(_music_player, "volume_db", -40.0, fade_duration)
	_music_fade_tween.tween_callback(func():
		_music_player.stop()
		_music_playing = false
		music_fade_out_completed.emit()
	)


## Push generative pad samples every frame.
func _process(_delta: float) -> void:
	if not _music_playing or not _music_player.playing:
		set_process(false)
		return

	var playback: AudioStreamGeneratorPlayback = _music_player.get_stream_playback()
	if not playback:
		return

	# Generate a slow-evolving pad from three detuned sine waves
	var frames_available := playback.get_frames_available()
	if frames_available <= 0:
		return

	var base_freq := 110.0  # A2
	var time_offset := Time.get_ticks_msec() / 1000.0

	var data := PackedVector2Array()
	data.resize(frames_available)
	for i in range(frames_available):
		var t := (time_offset + float(i) / SAMPLE_RATE)
		var sample := 0.0
		# Three sine oscillators with slow vibrato
		sample += sin(t * base_freq * TAU) * 0.35
		sample += sin(t * base_freq * 1.498 * TAU) * 0.25  # ~perfect fifth
		sample += sin(t * base_freq * 2.003 * TAU) * 0.20  # octave, slightly detuned
		# Slow LFO tremolo
		sample *= 0.6 + 0.4 * sin(t * 0.3 * TAU)
		sample *= master_volume * music_volume * 0.3
		data[i] = Vector2(sample, sample)

	playback.push_buffer(data)
#endregion

#region ── Sample generation helpers ───────────────────────────────────────────
## Generate a sine-wave tone shaped by an ADSR envelope.
func _generate_adsr_tone(
	freq: float,
	duration: float,
	attack: float = ATTACK,
	decay: float = DECAY,
	sustain: float = SUSTAIN,
	release: float = RELEASE,
) -> PackedVector2Array:
	var total_samples := int(duration * SAMPLE_RATE)
	var arr := PackedVector2Array()
	arr.resize(total_samples)

	var attack_samples := int(attack * SAMPLE_RATE)
	var decay_samples  := int(decay * SAMPLE_RATE)
	var release_samples := int(release * SAMPLE_RATE)
	var sustain_end    := total_samples - release_samples

	for i in range(total_samples):
		var t := float(i) / SAMPLE_RATE
		var sample := sin(t * freq * TAU)

		# ADSR envelope
		if i < attack_samples:
			sample *= float(i) / maxf(float(attack_samples), 1.0)
		elif i < attack_samples + decay_samples:
			var decay_progress := float(i - attack_samples) / maxf(float(decay_samples), 1.0)
			sample *= 1.0 - (1.0 - sustain) * decay_progress
		elif i < sustain_end:
			sample *= sustain
		else:
			var rel_progress := float(i - sustain_end) / maxf(float(release_samples), 1.0)
			sample *= sustain * (1.0 - rel_progress)

		sample *= master_volume * sfx_volume
		arr[i] = Vector2(sample, sample)

	return arr


## Generate a frequency sweep from freq_start to freq_end.
func _generate_sweep(freq_start: float, freq_end: float, duration: float) -> PackedVector2Array:
	var total_samples := int(duration * SAMPLE_RATE)
	var arr := PackedVector2Array()
	arr.resize(total_samples)

	var phase := 0.0
	for i in range(total_samples):
		var progress := float(i) / float(total_samples)
		var freq := lerpf(freq_start, freq_end, progress)
		phase += freq / SAMPLE_RATE
		var sample := sin(phase * TAU)
		# Simple fade-out envelope
		sample *= (1.0 - progress) * master_volume * sfx_volume
		arr[i] = Vector2(sample, sample)

	return arr


## Generate a long ambient drone with slow modulation.
func _generate_drone(base_freq: float, duration: float) -> PackedVector2Array:
	var total_samples := int(duration * SAMPLE_RATE)
	var arr := PackedVector2Array()
	arr.resize(total_samples)

	for i in range(total_samples):
		var t := float(i) / SAMPLE_RATE
		var sample := sin(t * base_freq * TAU) * 0.5
		sample += sin(t * base_freq * 1.5 * TAU) * 0.3
		sample *= 0.5 + 0.5 * sin(t * 0.2 * TAU)  # Tremolo
		sample *= master_volume * music_volume * 0.15
		arr[i] = Vector2(sample, sample)

	return arr
#endregion

#region ── Playback helpers ────────────────────────────────────────────────────
## Push a PackedVector2Array to the next available pool player.
func _play_samples(samples: PackedVector2Array) -> void:
	var player := _next_player()
	if not player:
		return

	var gen := AudioStreamGenerator.new()
	gen.mix_rate = SAMPLE_RATE
	gen.buffer_length = 0.1
	player.stream = gen
	player.volume_db = 0.0
	player.play()

	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback()
	if playback:
		var data := samples.to_float32_array() if samples else PackedFloat32Array()
		# to_float32_array on PackedVector2Array gives interleaved L/R
		# We need to push via push_buffer which expects PackedVector2Array directly
		var frames_available := playback.get_frames_available()
		var frames_to_push := mini(samples.size(), frames_available)
		if frames_to_push > 0:
			playback.push_buffer(samples.slice(0, frames_to_push))


## Play samples after a delay (for sequential notes in melodies).
func _play_samples_delayed(samples: PackedVector2Array, delay: float) -> void:
	get_tree().create_timer(delay).timeout.connect(func(): _play_samples(samples))


## Grab the next player from the pool (round-robin).
func _next_player() -> AudioStreamPlayer:
	var player := _pool[_pool_index]
	_pool_index = (_pool_index + 1) % POOL_SIZE
	# Stop any currently playing sound on this player
	if player.playing:
		player.stop()
	return player


## Mix two sample buffers with given weights.
func _mix_buffers(
	a: PackedVector2Array,
	b: PackedVector2Array,
	weight_a: float,
	weight_b: float,
) -> PackedVector2Array:
	var size := maxi(a.size(), b.size())
	var result := PackedVector2Array()
	result.resize(size)
	for i in range(size):
		var va := a[i] if i < a.size() else Vector2.ZERO
		var vb := b[i] if i < b.size() else Vector2.ZERO
		result[i] = va * weight_a + vb * weight_b
	return result
#endregion

#region ── Biome drone frequency ───────────────────────────────────────────────
func _biome_drone_freq(biome: String) -> float:
	match biome:
		"meadow":  return 130.81  # C3 — warm, open
		"forest":  return 146.83  # D3 — deeper, mysterious
		"cavern":  return 98.00   # G2 — low, resonant
		"ocean":   return 110.00  # A2 — flowing, wavelike
		"cosmos":  return 65.41   # C2 — vast, deep space
		_:         return 130.81
#endregion

#region ── Haptic feedback ─────────────────────────────────────────────────────
## Trigger device vibration if supported; otherwise print debug message.
func vibrate(duration_ms: int) -> void:
	if Engine.has_singleton("GodotVibrate"):
		var vibrate = Engine.get_singleton("GodotVibrate")
		if vibrate.has_method("vibrate"):
			vibrate.vibrate(duration_ms)
	else:
		print("[AudioManager] Vibrate %d ms" % duration_ms)
#endregion
