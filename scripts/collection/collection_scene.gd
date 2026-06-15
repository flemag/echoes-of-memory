## CollectionScene — Gallery / collection view for emotion fragments.
## Shows all 8 emotion types as cards, with detail popups, completion stats,
## rarity glow effects for rare emotions, and navigation back.
extends Control

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const TOTAL_EMOTIONS: int = 8
const CARDS_PER_ROW: int = 4

# Rarity badge colours.
const RARITY_COLORS: Dictionary = {
	"common":   Color(0.7, 0.7, 0.7),
	"uncommon": Color(0.3, 0.8, 0.4),
	"rare":     Color(1.0, 0.75, 0.15),
}

# ---------------------------------------------------------------------------
# Internal References
# ---------------------------------------------------------------------------

var _cards_container: GridContainer
var _completion_label: Label
var _stats_panel: VBoxContainer
var _detail_popup: PanelContainer

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	AudioManager.play_ui_hover()

	# Root vertical layout.
	var root_vbox: VBoxContainer = VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 12)
	add_child(root_vbox)

	# Top bar: back button + completion %.
	var top_bar: HBoxContainer = HBoxContainer.new()
	var back_btn: Button = Button.new()
	back_btn.text = "< Back"
	back_btn.pressed.connect(_on_back_pressed)
	top_bar.add_child(back_btn)

	_completion_label = Label.new()
	_completion_label.add_theme_font_size_override("font_size", 18)
	top_bar.add_child(_completion_label)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	var title: Label = Label.new()
	title.text = "Emotion Collection"
	title.add_theme_font_size_override("font_size", 20)
	top_bar.add_child(title)

	root_vbox.add_child(top_bar)

	# Emotion cards grid.
	_create_emotion_cards(root_vbox)

	# Stats section.
	_create_stats_panel(root_vbox)

	_refresh_display()

# ---------------------------------------------------------------------------
# Emotion Cards
# ---------------------------------------------------------------------------

## Creates the 2×4 grid of emotion cards inside [param parent].
func _create_emotion_cards(parent: VBoxContainer) -> void:
	var center: CenterContainer = CenterContainer.new()
	_cards_container = GridContainer.new()
	_cards_container.columns = CARDS_PER_ROW
	_cards_container.add_theme_constant_override("h_separation", 10)
	_cards_container.add_theme_constant_override("v_separation", 10)

	for etype: int in range(TOTAL_EMOTIONS):
		var card: PanelContainer = _build_card(etype)
		_cards_container.add_child(card)

	center.add_child(_cards_container)
	parent.add_child(center)

## Build a single card for the given [param emotion_type].
func _build_card(emotion_type: int) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(140, 160)

	var discovered: bool = CollectionManager.has_emotion(emotion_type)
	var frag: EmotionFragment = EmotionFragment.new(emotion_type)
	var col: Color = frag.get_color() if discovered else Color(0.35, 0.35, 0.35)

	# Style the card background.
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(col.r * 0.15, col.g * 0.15, col.b * 0.15, 0.85) if discovered else Color(0.12, 0.12, 0.12, 0.8)
	style.border_color = col if discovered else Color(0.25, 0.25, 0.25)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", style)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)

	# Icon symbol.
	var icon_label: Label = Label.new()
	icon_label.text = frag.get_icon_symbol() if discovered else "?"
	icon_label.add_theme_font_size_override("font_size", 36)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_color_override("font_color", col)
	vbox.add_child(icon_label)

	# Name.
	var name_label: Label = Label.new()
	name_label.text = frag.get_display_name() if discovered else "???"
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", col)
	vbox.add_child(name_label)

	# Quantity.
	if discovered:
		var qty_label: Label = Label.new()
		qty_label.text = "x%d" % CollectionManager.get_emotion_quantity(emotion_type)
		qty_label.add_theme_font_size_override("font_size", 12)
		qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(qty_label)

	# Rarity badge.
	var badge: Label = Label.new()
	badge.text = frag.rarity.to_upper() if discovered else "???"
	badge.add_theme_font_size_override("font_size", 10)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_color_override("font_color", RARITY_COLORS.get(frag.rarity, Color.GRAY) if discovered else Color(0.3, 0.3, 0.3))
	vbox.add_child(badge)

	card.add_child(vbox)

	# Subtle glow animation for rare emotions.
	if discovered and frag.is_rare():
		_start_rare_glow(card, col)

	# Tap to see detail popup.
	if discovered:
		card.gui_input.connect(_on_card_input.bind(emotion_type))

	return card

# ---------------------------------------------------------------------------
# Rare Glow Animation
# ---------------------------------------------------------------------------

## Pulsing border glow for rare emotion cards.
func _start_rare_glow(card: PanelContainer, base_col: Color) -> void:
	var tween: Tween = create_tween().set_loops()
	var bright: Color = Color(base_col.r, base_col.g, base_col.b, 1.0)
	var dim: Color = Color(base_col.r * 0.5, base_col.g * 0.5, base_col.b * 0.5, 0.6)

	tween.tween_property(card, "theme_override_styles/panel:border_color", bright, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(card, "theme_override_styles/panel:border_color", dim, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# ---------------------------------------------------------------------------
# Card Interaction
# ---------------------------------------------------------------------------

func _on_card_input(event: InputEvent, emotion_type: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		AudioManager.play_ui_click()
		_show_emotion_detail(emotion_type)

# ---------------------------------------------------------------------------
# Emotion Detail Popup
# ---------------------------------------------------------------------------

## Show a detail overlay for the given [param emotion_type].
func _show_emotion_detail(emotion_type: int) -> void:
	# Close any existing popup first.
	if _detail_popup:
		_detail_popup.queue_free()

	var frag: EmotionFragment = EmotionFragment.new(emotion_type, CollectionManager.get_emotion_quantity(emotion_type))
	var meta: Dictionary = {}  # Fetch from CollectionManager metadata
	var collection: Array[Dictionary] = CollectionManager.get_collection()
	for entry: Dictionary in collection:
		if entry["emotion_type"] == emotion_type:
			meta = entry
			break

	_detail_popup = PanelContainer.new()
	_detail_popup.set_anchors_preset(Control.PRESET_CENTER)
	_detail_popup.custom_minimum_size = Vector2(320, 280)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	style.set_border_width_all(2)
	style.border_color = frag.get_color()
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	_detail_popup.add_theme_stylebox_override("panel", style)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	# Icon + Name.
	var header: Label = Label.new()
	header.text = "%s  %s" % [frag.get_icon_symbol(), frag.get_display_name()]
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", frag.get_color())
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	# Rarity.
	var rarity: Label = Label.new()
	rarity.text = "Rarity: %s" % frag.rarity.to_upper()
	rarity.add_theme_color_override("font_color", RARITY_COLORS.get(frag.rarity, Color.GRAY))
	rarity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(rarity)

	# Description.
	var desc: Label = Label.new()
	desc.text = frag.get_description()
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 13)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(desc)

	# Quantity.
	var qty: Label = Label.new()
	qty.text = "Quantity: %d" % frag.quantity
	qty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(qty)

	# Discovered date.
	var date: Label = Label.new()
	date.text = "Discovered: %s" % meta.get("discovered_date", "—")
	date.add_theme_font_size_override("font_size", 12)
	date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(date)

	# Sources.
	var sources: Label = Label.new()
	var src_list: Array = meta.get("sources", [])
	sources.text = "Sources: %s" % (", ".join(src_list) if src_list else "—")
	sources.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sources.add_theme_font_size_override("font_size", 12)
	sources.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sources)

	# Close button.
	var close: Button = Button.new()
	close.text = "Close"
	close.pressed.connect(func(): _detail_popup.queue_free())
	vbox.add_child(close)

	_detail_popup.add_child(vbox)
	add_child(_detail_popup)

# ---------------------------------------------------------------------------
# Stats Panel
# ---------------------------------------------------------------------------

## Builds the statistics section at the bottom of the view.
func _create_stats_panel(parent: VBoxContainer) -> void:
	_stats_panel = VBoxContainer.new()
	_stats_panel.add_theme_constant_override("separation", 4)

	var stats_title: Label = Label.new()
	stats_title.text = "— Stats —"
	stats_title.add_theme_font_size_override("font_size", 16)
	stats_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_panel.add_child(stats_title)

	parent.add_child(_stats_panel)

func _refresh_stats() -> void:
	# Clear old stat lines (keep the title at index 0).
	while _stats_panel.get_child_count() > 1:
		_stats_panel.get_child(1).queue_free()

	var total: int = CollectionManager.get_total_fragments()
	var pct: float = CollectionManager.get_completion_percentage()

	# Find most common and rarest.
	var most_common: String = "—"
	var rarest_found: String = "—"
	var max_qty: int = 0
	var min_rarity: int = 4  # 0=common, 1=uncommon, 2=rare — higher = rarer.

	for etype: int in range(TOTAL_EMOTIONS):
		if CollectionManager.has_emotion(etype):
			var qty: int = CollectionManager.get_emotion_quantity(etype)
			if qty > max_qty:
				max_qty = qty
				most_common = EmotionFragment.new(etype).get_display_name()

			var frag: EmotionFragment = EmotionFragment.new(etype)
			var rarity_rank: int = 0 if frag.rarity == "common" else (1 if frag.rarity == "uncommon" else 2)
			if rarity_rank > min_rarity or rarest_found == "—":
				# Find the rarest discovered.
				pass
			# Simple: just pick the first rare, then first uncommon if no rare.
			if frag.rarity == "rare" and rarest_found == "—":
				rarest_found = frag.get_display_name()

	if rarest_found == "—":
		for etype: int in range(TOTAL_EMOTIONS):
			if CollectionManager.has_emotion(etype):
				var frag2: EmotionFragment = EmotionFragment.new(etype)
				if frag2.rarity == "uncommon":
					rarest_found = frag2.get_display_name()
					break

	_add_stat_line("Total Fragments: %d" % total)
	_add_stat_line("Completion: %.0f%%" % pct)
	_add_stat_line("Most Common: %s" % most_common)
	_add_stat_line("Rarest Found: %s" % rarest_found)

func _add_stat_line(text: String) -> void:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_panel.add_child(lbl)

# ---------------------------------------------------------------------------
# Display Refresh
# ---------------------------------------------------------------------------

func _refresh_display() -> void:
	var discovered: int = 0
	for etype: int in range(TOTAL_EMOTIONS):
		if CollectionManager.has_emotion(etype):
			discovered += 1

	_completion_label.text = "%d/%d Emotions Discovered" % [discovered, TOTAL_EMOTIONS]
	_refresh_stats()

# ---------------------------------------------------------------------------
# Navigation
# ---------------------------------------------------------------------------

func _on_back_pressed() -> void:
	AudioManager.play_ui_click()
	SceneManager.go_back()
