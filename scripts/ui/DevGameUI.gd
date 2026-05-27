extends Control

const PokerRoundManagerScript := preload("res://scripts/game/PokerRoundManager.gd")
const PokerRulesScript := preload("res://scripts/poker/PokerRules.gd")
const HandEvaluatorScript := preload("res://scripts/poker/HandEvaluator.gd")

const CARD_ASSET_PATH := "res://assets/cards/%s.svg"
const CARD_BACK_PATH := "res://assets/cards/back.svg"

@onready var phase_label: Label = %PhaseLabel
@onready var pot_label: Label = %PotLabel
@onready var current_bet_label: Label = %CurrentBetLabel
@onready var player_chips_label: Label = %PlayerChipsLabel
@onready var opponent_chips_label: Label = %OpponentChipsLabel
@onready var player_cards: HBoxContainer = %PlayerCards
@onready var opponent_cards: HBoxContainer = %OpponentCards
@onready var community_cards: HBoxContainer = %CommunityCards
@onready var log_label: RichTextLabel = %LogLabel
@onready var fold_button: Button = %FoldButton
@onready var check_button: Button = %CheckButton
@onready var call_button: Button = %CallButton
@onready var raise_button: Button = %RaiseButton
@onready var all_in_button: Button = %AllInButton
@onready var post_blinds_button: Button = %PostBlindsButton
@onready var new_round_button: Button = %NewRoundButton

var round_manager: PokerRoundManager
var last_state: Dictionary = {}
var reveal_opponent_cards := false


func _ready() -> void:
	round_manager = PokerRoundManagerScript.new()
	add_child(round_manager)
	_connect_round_signals()
	_connect_buttons()
	_start_round()


func _connect_round_signals() -> void:
	round_manager.round_started.connect(_on_round_started)
	round_manager.phase_changed.connect(_on_phase_changed)
	round_manager.player_updated.connect(_on_player_updated)
	round_manager.ai_acted.connect(_on_ai_acted)
	round_manager.showdown_finished.connect(_on_showdown_finished)
	round_manager.round_finished.connect(_on_round_finished)


func _connect_buttons() -> void:
	fold_button.pressed.connect(func() -> void: _act(PokerRules.Action.FOLD))
	check_button.pressed.connect(func() -> void: _act(PokerRules.Action.CHECK))
	call_button.pressed.connect(func() -> void: _act(PokerRules.Action.CALL))
	raise_button.pressed.connect(func() -> void: _act(PokerRules.Action.RAISE, PokerRules.MIN_RAISE))
	all_in_button.pressed.connect(func() -> void: _act(PokerRules.Action.ALL_IN))
	post_blinds_button.pressed.connect(_post_blinds)
	new_round_button.pressed.connect(_start_round)


func _start_round() -> void:
	reveal_opponent_cards = false
	round_manager.start_new_round()
	_clear_log()
	_append_log("New round started. Press Post Blinds to begin betting.")


func _post_blinds() -> void:
	round_manager.post_blinds()
	var state := round_manager.get_state()
	_append_log("Blinds posted: player 10, %s 20." % state.get("big_blind_opponent", "AI"))


func _act(action: PokerRules.Action, amount: int = 0) -> void:
	round_manager.player_action(action, amount)


func _on_round_started(state: Dictionary) -> void:
	_render_state(state)


func _on_phase_changed(new_phase: PokerRules.Phase, state: Dictionary) -> void:
	_append_log("Phase: %s" % PokerRulesScript.get_phase_name(new_phase))
	_render_state(state)


func _on_player_updated(state: Dictionary) -> void:
	_render_state(state)


func _on_ai_acted(action: Dictionary, state: Dictionary) -> void:
	_append_log("%s: %s" % [action.get("actor", "AI"), _action_to_text(action)])
	_render_state(state)


func _on_showdown_finished(result: Dictionary, state: Dictionary) -> void:
	reveal_opponent_cards = true
	_append_log("Showdown: %s" % _showdown_text(result.get("hands", {})))
	_render_state(state)


func _on_round_finished(result: Dictionary, state: Dictionary) -> void:
	reveal_opponent_cards = true
	if not result.get("showdown", false):
		_append_log("Board completed for dev showdown.")
		_append_log("Reveal: %s" % _revealed_cards_text(result.get("hole_cards", {})))
	_append_log("Round over: %s wins. %s" % [result.get("winner", "tie"), result.get("reason", "")])
	_render_state(round_manager.get_state())


func _render_state(state: Dictionary) -> void:
	last_state = state
	var player: Dictionary = state.get("player", {})
	var opponents: Array = state.get("opponents", [])
	var phase: PokerRules.Phase = state.get("phase", PokerRules.Phase.PRE_FLOP)
	var call_amount: int = state.get("call_amount", 0)
	var blinds_posted: bool = state.get("blinds_posted", false)
	var player_is_all_in: bool = player.get("is_all_in", false)
	var any_opponent_is_all_in := _any_opponent_all_in(opponents)

	phase_label.text = "Phase: %s" % state.get("phase_name", "Unknown")
	pot_label.text = "Pot: %d" % state.get("pot", 0)
	current_bet_label.text = "Current bet: %d" % state.get("current_bet", 0)
	player_chips_label.text = "Player chips: %d" % player.get("chips", 0)
	opponent_chips_label.text = _opponents_chip_text(opponents)

	_render_cards(player_cards, player.get("hole_cards", []), true)
	_render_opponents(opponent_cards, opponents, reveal_opponent_cards)
	_render_cards(community_cards, state.get("community_cards", []), true, 5)
	_update_buttons(phase, call_amount, blinds_posted, player_is_all_in, any_opponent_is_all_in)


func _render_opponents(container: HBoxContainer, opponents: Array, show_faces: bool) -> void:
	for child in container.get_children():
		child.queue_free()

	for opponent in opponents:
		var group := VBoxContainer.new()
		group.add_theme_constant_override("separation", 4)
		group.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		container.add_child(group)

		var name_label := Label.new()
		name_label.text = "%s: %d" % [opponent.get("name", "AI"), opponent.get("chips", 0)]
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		group.add_child(name_label)

		var cards_row := HBoxContainer.new()
		cards_row.add_theme_constant_override("separation", 6)
		cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
		group.add_child(cards_row)

		_render_cards(cards_row, opponent.get("hole_cards", []), show_faces)


func _opponents_chip_text(opponents: Array) -> String:
	var parts: Array[String] = []

	for opponent in opponents:
		parts.append("%s: %d" % [opponent.get("name", "AI"), opponent.get("chips", 0)])

	return " | ".join(parts)


func _any_opponent_all_in(opponents: Array) -> bool:
	for opponent in opponents:
		if opponent.get("is_all_in", false):
			return true

	return false


func _showdown_text(hands: Dictionary) -> String:
	var parts: Array[String] = []

	for player_name in hands.keys():
		parts.append("%s %s" % [player_name, HandEvaluatorScript.describe_result(hands[player_name])])

	return "; ".join(parts)


func _revealed_cards_text(hole_cards: Dictionary) -> String:
	var parts: Array[String] = []

	for player_name in hole_cards.keys():
		parts.append("%s %s" % [player_name, " ".join(hole_cards[player_name])])

	return "; ".join(parts)


func _render_cards(container: HBoxContainer, cards: Array, show_faces: bool, placeholders: int = 0) -> void:
	for child in container.get_children():
		child.queue_free()

	for card in cards:
		container.add_child(_make_card_view(card.get_code(), show_faces))

	for index in range(maxi(placeholders - cards.size(), 0)):
		container.add_child(_make_empty_card_slot())


func _make_card_view(card_code: String, show_face: bool) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(72, 101)
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.96, 0.93, 0.86) if show_face else Color(0.1, 0.2, 0.32)
	style.border_color = Color(0.08, 0.1, 0.12)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	slot.add_theme_stylebox_override("panel", style)

	var texture_rect := TextureRect.new()
	texture_rect.custom_minimum_size = Vector2(72, 101)
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.texture = load(CARD_ASSET_PATH % card_code) if show_face else load(CARD_BACK_PATH)
	texture_rect.tooltip_text = card_code if show_face else "Hidden card"
	texture_rect.modulate = Color(1, 1, 1, 0.35) if show_face else Color(1, 1, 1, 1)
	slot.add_child(texture_rect)

	if show_face:
		var face := VBoxContainer.new()
		face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		face.alignment = BoxContainer.ALIGNMENT_CENTER
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(face)

		var rank_label := Label.new()
		rank_label.text = _display_rank(card_code)
		rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rank_label.add_theme_font_size_override("font_size", 30)
		rank_label.add_theme_color_override("font_color", _card_text_color(card_code))
		face.add_child(rank_label)

		var suit_label := Label.new()
		suit_label.text = _display_suit(card_code)
		suit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		suit_label.add_theme_font_size_override("font_size", 26)
		suit_label.add_theme_color_override("font_color", _card_text_color(card_code))
		face.add_child(suit_label)

	return slot


func _make_empty_card_slot() -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(72, 101)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.32, 0.29)
	style.border_color = Color(0.45, 0.62, 0.55)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	slot.add_theme_stylebox_override("panel", style)
	return slot


func _card_text_color(card_code: String) -> Color:
	if card_code.ends_with("D") or card_code.ends_with("H"):
		return Color(0.79, 0.12, 0.21)

	return Color(0.08, 0.1, 0.12)


func _display_rank(card_code: String) -> String:
	if card_code.length() < 2:
		return "?"

	var rank := card_code.substr(0, card_code.length() - 1)
	return "10" if rank == "T" else rank


func _display_suit(card_code: String) -> String:
	if card_code.ends_with("C"):
		return "♣"
	if card_code.ends_with("D"):
		return "♦"
	if card_code.ends_with("H"):
		return "♥"
	if card_code.ends_with("S"):
		return "♠"

	return "?"


func _update_buttons(
	phase: PokerRules.Phase,
	call_amount: int,
	blinds_posted: bool,
	player_is_all_in: bool,
	opponent_is_all_in: bool
) -> void:
	var is_round_over := phase == PokerRules.Phase.ROUND_OVER
	var actions_disabled := is_round_over or not blinds_posted
	var all_in_locked := player_is_all_in or opponent_is_all_in
	fold_button.disabled = actions_disabled
	check_button.disabled = actions_disabled or call_amount > 0
	call_button.disabled = actions_disabled or call_amount == 0
	call_button.text = "Call %d" % call_amount if call_amount > 0 else "Call"
	raise_button.disabled = actions_disabled or all_in_locked
	all_in_button.disabled = actions_disabled or player_is_all_in
	post_blinds_button.disabled = is_round_over or blinds_posted
	new_round_button.disabled = not is_round_over


func _append_log(message: String) -> void:
	if log_label == null:
		return

	log_label.append_text("%s\n" % message)
	log_label.scroll_to_line(log_label.get_line_count())


func _clear_log() -> void:
	if log_label == null:
		return

	log_label.clear()


func _action_to_text(action: Dictionary) -> String:
	match action.get("action", PokerRules.Action.CHECK):
		PokerRules.Action.FOLD:
			return "Fold"
		PokerRules.Action.CALL:
			return "Call %d" % action.get("amount", 0)
		PokerRules.Action.RAISE:
			return "Raise %d" % action.get("amount", 0)
		PokerRules.Action.ALL_IN:
			return "All In"
		_:
			return "Check"
