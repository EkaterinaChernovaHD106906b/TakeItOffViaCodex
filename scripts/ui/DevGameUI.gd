extends Control

const PokerRoundManagerScript := preload("res://scripts/game/PokerRoundManager.gd")
const PokerRulesScript := preload("res://scripts/poker/PokerRules.gd")
const HandEvaluatorScript := preload("res://scripts/poker/HandEvaluator.gd")

const CARD_ASSET_PATH := "res://assets/cards/%s.svg"
const CARD_BACK_PATH := "res://assets/cards/back.svg"
const CARD_SIZE := Vector2(86, 120)
const OPPONENT_PORTRAIT_SIZE := Vector2(330, 560)
const OPPONENT_IMAGE_SIZE := Vector2(300, 460)
const HEROINE_EXPRESSIONS := {
	"neutral": {
		"mouth": "res://assets/opponents/ai1/Expressions/mouth_smile.png",
	},
	"happy": {
		"eyes": "res://assets/opponents/ai1/Expressions/eyes_wink.png",
		"mouth": "res://assets/opponents/ai1/Expressions/mouth_smile.png",
	},
	"smirk": {
		"eyes": "res://assets/opponents/ai1/Expressions/eyes_wink.png",
		"mouth": "res://assets/opponents/ai1/Expressions/mouth_smirk.png",
	},
	"talk": {
		"mouth": "res://assets/opponents/ai1/Expressions/mouth_talk.png",
	},
	"worried": {
		"eyes": "res://assets/opponents/ai1/Expressions/eyes_closed.png",
		"mouth": "res://assets/opponents/ai1/Expressions/mouth_pout.png",
	},
	"embarrassed": {
		"eyes": "res://assets/opponents/ai1/Expressions/eyes_closed.png",
		"mouth": "res://assets/opponents/ai1/Expressions/mouth_pout.png",
	},
}
const OPPONENT_REACTION_PROFILES := {
	"AI 1": {
		PokerRules.Action.RAISE: "smirk",
		PokerRules.Action.ALL_IN: "smirk",
		PokerRules.Action.FOLD: "worried",
		PokerRules.Action.CALL: "talk",
		PokerRules.Action.CHECK: "neutral",
		"win": "happy",
		"lose": "embarrassed",
		"tie": "talk",
		"other_win": "worried",
	},
	"AI 2": {
		PokerRules.Action.RAISE: "talk",
		PokerRules.Action.ALL_IN: "happy",
		PokerRules.Action.FOLD: "embarrassed",
		PokerRules.Action.CALL: "neutral",
		PokerRules.Action.CHECK: "worried",
		"win": "smirk",
		"lose": "worried",
		"tie": "neutral",
		"other_win": "embarrassed",
	},
}
const OPPONENT_OUTFIT_SETS := {
	"AI 1": [
		"res://assets/opponents/ai1/layers",
		"res://assets/opponents/ai1/layers2",
	],
	"AI 2": [
		"res://assets/opponents/ai2/layers",
		"res://assets/opponents/ai2/layers2",
		"res://assets/opponents/ai2/layers3",
	],
}
const OUTFIT_UNLOCK_SEQUENCE := ["AI 2", "AI 1"]
const OPPONENT_AGES := {
	"AI 1": 22,
	"AI 2": 24,
}
const OPPONENT_DISPLAY_NAMES := {
	"AI 1": "Selene Noir",
	"AI 2": "Sylvaine",
}
const MAX_CLOTHING_LAYERS := 4
const CLOTHING_CHIP_STEP := 250
const MAX_LOG_EVENTS := 5

@onready var phase_label: Label = %PhaseLabel
@onready var pot_label: Label = %PotLabel
@onready var current_bet_label: Label = %CurrentBetLabel
@onready var player_chips_label: Label = %PlayerChipsLabel
@onready var opponent_chips_label: Label = %OpponentChipsLabel
@onready var player_cards: HBoxContainer = %PlayerCards
@onready var left_opponent_slot: VBoxContainer = %LeftOpponentSlot
@onready var right_opponent_slot: VBoxContainer = %RightOpponentSlot
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
var opponent_reactions := {
	"AI 1": "neutral",
	"AI 2": "neutral",
}
var log_events: Array[String] = []
var reaction_reset_timers := {}
var opponent_outfit_indices := {
	"AI 1": 0,
	"AI 2": 0,
}
var unlocked_outfit_counts := {
	"AI 1": 1,
	"AI 2": 1,
}
var opponent_clothing_stages := {
	"AI 1": 1,
	"AI 2": 1,
}
var outfit_unlock_turn := 0
var outfit_popup: AcceptDialog


func _ready() -> void:
	round_manager = PokerRoundManagerScript.new()
	add_child(round_manager)
	_setup_outfit_popup()
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


func _setup_outfit_popup() -> void:
	outfit_popup = AcceptDialog.new()
	outfit_popup.title = "Outfit unlocked"
	outfit_popup.dialog_text = "You unlocked a new outfit."
	add_child(outfit_popup)


func _start_round() -> void:
	reveal_opponent_cards = false
	round_manager.start_new_round()
	_clear_log()
	_set_all_opponent_reactions("neutral")
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
	_react_to_ai_action(action)
	_append_log("%s: %s" % [action.get("actor", "AI"), _action_to_text(action)])
	_render_state(state)


func _on_showdown_finished(result: Dictionary, state: Dictionary) -> void:
	reveal_opponent_cards = true
	_append_log("Showdown: %s" % _showdown_text(result.get("hands", {})))
	_render_state(state)


func _on_round_finished(result: Dictionary, state: Dictionary) -> void:
	reveal_opponent_cards = true
	_react_to_round_result(result)
	if result.get("winner", "") == "You":
		_unlock_next_outfit()
	if not result.get("showdown", false):
		_append_log("Board completed for dev showdown.")
		_append_log("Reveal: %s" % _revealed_cards_text(result.get("hole_cards", {})))
	_append_log("Round over: %s wins. %s" % [result.get("winner", "tie"), result.get("reason", "")])
	_render_state(round_manager.get_state())


func _make_portrait_layer(path: String, flip_h: bool = false) -> TextureRect:
	var layer := TextureRect.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.flip_h = flip_h
	if not path.is_empty():
		layer.texture = load(path)
	return layer


func _set_opponent_reaction(opponent_name: String, reaction_name: String) -> void:
	opponent_reactions[opponent_name] = reaction_name
	if not last_state.is_empty():
		_render_state(last_state)


func _set_temporary_opponent_reaction(opponent_name: String, reaction_name: String, duration: float = 1.4) -> void:
	_set_opponent_reaction(opponent_name, reaction_name)
	var timer := get_tree().create_timer(duration)
	reaction_reset_timers[opponent_name] = timer
	timer.timeout.connect(func() -> void:
		if reaction_reset_timers.get(opponent_name) == timer:
			_set_opponent_reaction(opponent_name, "neutral")
	)


func _set_all_opponent_reactions(reaction_name: String) -> void:
	for opponent_name in opponent_reactions.keys():
		opponent_reactions[opponent_name] = reaction_name
	if not last_state.is_empty():
		_render_state(last_state)


func _react_to_ai_action(action: Dictionary) -> void:
	var actor: String = action.get("actor", "")
	if not opponent_reactions.has(actor):
		return

	var profile: Dictionary = OPPONENT_REACTION_PROFILES.get(actor, {})
	var reaction_name: String = profile.get(action.get("action", PokerRules.Action.CHECK), "neutral")
	if reaction_name == "neutral":
		_set_opponent_reaction(actor, reaction_name)
	else:
		_set_temporary_opponent_reaction(actor, reaction_name)


func _react_to_round_result(result: Dictionary) -> void:
	var winner: String = result.get("winner", "")
	for opponent_name in opponent_reactions.keys():
		var profile: Dictionary = OPPONENT_REACTION_PROFILES.get(opponent_name, {})
		if winner == opponent_name:
			_set_temporary_opponent_reaction(opponent_name, profile.get("win", "happy"), 2.0)
		elif winner == "You":
			_set_temporary_opponent_reaction(opponent_name, profile.get("lose", "embarrassed"), 2.0)
		elif winner == "tie":
			_set_temporary_opponent_reaction(opponent_name, profile.get("tie", "talk"), 2.0)
		else:
			_set_temporary_opponent_reaction(opponent_name, profile.get("other_win", "worried"), 2.0)


func _unlock_next_outfit() -> void:
	if OUTFIT_UNLOCK_SEQUENCE.is_empty():
		return

	var opponent_name: String = OUTFIT_UNLOCK_SEQUENCE[outfit_unlock_turn % OUTFIT_UNLOCK_SEQUENCE.size()]
	outfit_unlock_turn += 1

	var outfit_sets: Array = OPPONENT_OUTFIT_SETS.get(opponent_name, [])
	if outfit_sets.size() <= 1:
		return

	var current_index: int = opponent_outfit_indices.get(opponent_name, 0)
	opponent_outfit_indices[opponent_name] = (current_index + 1) % outfit_sets.size()

	var unlocked_count: int = unlocked_outfit_counts.get(opponent_name, 1)
	if unlocked_count < outfit_sets.size():
		unlocked_outfit_counts[opponent_name] = unlocked_count + 1
		_show_outfit_unlocked_popup()

	if not last_state.is_empty():
		_render_state(last_state)


func _show_outfit_unlocked_popup() -> void:
	if outfit_popup == null:
		return

	outfit_popup.dialog_text = "You unlocked a new outfit."
	outfit_popup.popup_centered()


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
	_render_opponents(opponents, reveal_opponent_cards, phase != PokerRules.Phase.ROUND_OVER)
	_render_cards(community_cards, state.get("community_cards", []), true, 5)
	_update_buttons(phase, call_amount, blinds_posted, player_is_all_in, any_opponent_is_all_in)


func _render_opponents(opponents: Array, show_faces: bool, include_committed_chips: bool) -> void:
	_render_single_opponent(left_opponent_slot, opponents[0] if opponents.size() > 0 else {}, show_faces, include_committed_chips)
	_render_single_opponent(right_opponent_slot, opponents[1] if opponents.size() > 1 else {}, show_faces, include_committed_chips)


func _render_single_opponent(
	container: VBoxContainer,
	opponent: Dictionary,
	show_faces: bool,
	include_committed_chips: bool
) -> void:
	for child in container.get_children():
		child.queue_free()

	if opponent.is_empty():
		return

	container.add_theme_constant_override("separation", 8)

	var name_label := Label.new()
	name_label.text = "%s: %d" % [opponent.get("name", "AI"), opponent.get("chips", 0)]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	container.add_child(name_label)

	container.add_child(_make_opponent_portrait(opponent, include_committed_chips))

	var cards_row := HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", 8)
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_child(cards_row)

	_render_cards(cards_row, opponent.get("hole_cards", []), show_faces)


func _make_opponent_portrait(opponent: Dictionary, include_committed_chips: bool) -> PanelContainer:
	var opponent_name: String = opponent.get("name", "AI")
	var chips: int = opponent.get("chips", 0)
	var layer_chips := _chips_for_clothing_layers(opponent, include_committed_chips)
	var clothing_stage := _update_clothing_stage(opponent_name, layer_chips)
	var portrait := PanelContainer.new()
	portrait.custom_minimum_size = OPPONENT_PORTRAIT_SIZE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.17)
	style.border_color = Color(0.36, 0.42, 0.49)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	portrait.add_theme_stylebox_override("panel", style)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	portrait.add_child(stack)

	stack.add_child(_make_layered_opponent_portrait(opponent_name, clothing_stage))

	var age_label := Label.new()
	age_label.text = "%s, %d+" % [opponent_name, OPPONENT_AGES.get(opponent_name, 18)]
	age_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	age_label.add_theme_font_size_override("font_size", 13)
	age_label.add_theme_color_override("font_color", Color(0.92, 0.9, 0.84))
	stack.add_child(age_label)

	var layer_label := Label.new()
	layer_label.text = "Layer: %d/%d" % [clothing_stage, MAX_CLOTHING_LAYERS]
	layer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer_label.add_theme_font_size_override("font_size", 12)
	layer_label.add_theme_color_override("font_color", Color(0.72, 0.82, 0.9))
	stack.add_child(layer_label)

	var pips := HBoxContainer.new()
	pips.alignment = BoxContainer.ALIGNMENT_CENTER
	pips.add_theme_constant_override("separation", 4)
	stack.add_child(pips)

	for index in range(MAX_CLOTHING_LAYERS):
		pips.add_child(_make_clothing_pip(index + 1 < clothing_stage))

	return portrait


func _make_layered_opponent_portrait(opponent_name: String, clothing_stage: int) -> Control:
	var portrait := Control.new()
	portrait.custom_minimum_size = OPPONENT_IMAGE_SIZE
	portrait.tooltip_text = OPPONENT_DISPLAY_NAMES.get(opponent_name, opponent_name)
	var flip_h := opponent_name == "AI 2"

	portrait.add_child(_make_portrait_layer(_opponent_sprite_path(opponent_name, clothing_stage), flip_h))

	var reaction_name: String = opponent_reactions.get(opponent_name, "neutral")
	var config: Dictionary = HEROINE_EXPRESSIONS.get(reaction_name, HEROINE_EXPRESSIONS["neutral"])
	for layer_name in ["eyes", "mouth", "blush"]:
		var path: String = config.get(layer_name, "")
		if not path.is_empty():
			portrait.add_child(_make_portrait_layer(path, flip_h))

	return portrait


func _make_clothing_pip(is_active: bool) -> ColorRect:
	var pip := ColorRect.new()
	pip.custom_minimum_size = Vector2(18, 5)
	pip.color = Color(0.94, 0.76, 0.34) if is_active else Color(0.28, 0.3, 0.33)
	return pip


func _chips_for_clothing_layers(opponent: Dictionary, include_committed_chips: bool) -> int:
	var chips: int = opponent.get("chips", 0)
	if include_committed_chips:
		chips += opponent.get("round_contribution", 0)

	return chips


func _target_clothing_stage(chips: int) -> int:
	var lost_chips := PokerRules.STARTING_CHIPS - maxi(chips, 0)
	return clampi(floori(float(lost_chips) / float(CLOTHING_CHIP_STEP)) + 1, 1, MAX_CLOTHING_LAYERS)


func _update_clothing_stage(opponent_name: String, chips: int) -> int:
	var current_stage: int = opponent_clothing_stages.get(opponent_name, 1)
	var target_stage := _target_clothing_stage(chips)
	var next_stage := maxi(current_stage, target_stage)
	opponent_clothing_stages[opponent_name] = next_stage
	return next_stage


func _opponent_sprite_path(opponent_name: String, clothing_stage: int) -> String:
	var outfit_sets: Array = OPPONENT_OUTFIT_SETS.get(opponent_name, [])
	if outfit_sets.is_empty():
		return ""

	var outfit_index: int = opponent_outfit_indices.get(opponent_name, 0) % outfit_sets.size()
	var layer_number := clampi(clothing_stage, 1, MAX_CLOTHING_LAYERS)
	return "%s/layer%d.png" % [outfit_sets[outfit_index], layer_number]


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
	slot.custom_minimum_size = CARD_SIZE
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
	texture_rect.custom_minimum_size = CARD_SIZE
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
	slot.custom_minimum_size = CARD_SIZE

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
	var actions_disabled := is_round_over or not blinds_posted or player_is_all_in
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

	log_events.append(message)
	while log_events.size() > MAX_LOG_EVENTS:
		log_events.pop_front()

	log_label.clear()
	for event in log_events:
		log_label.append_text("%s\n" % event)
	log_label.scroll_to_line(log_label.get_line_count())


func _clear_log() -> void:
	if log_label == null:
		return

	log_events.clear()
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
