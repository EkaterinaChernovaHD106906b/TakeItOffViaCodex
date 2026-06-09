extends SceneTree

const CardDataScript := preload("res://scripts/poker/CardData.gd")
const DeckScript := preload("res://scripts/poker/Deck.gd")
const HandEvaluatorScript := preload("res://scripts/poker/HandEvaluator.gd")
const PokerRoundManagerScript := preload("res://scripts/game/PokerRoundManager.gd")
const PokerRulesScript := preload("res://scripts/poker/PokerRules.gd")
const PokerAIScript := preload("res://scripts/ai/PokerAI.gd")


func _init() -> void:
	var failed := false
	failed = _test_deck() or failed
	failed = _test_hand_evaluator() or failed
	failed = _test_personal_showdown_kicker() or failed
	failed = _test_describe_result_can_hide_kicker() or failed
	failed = _test_round_start() or failed
	failed = _test_busted_match_resets_chips() or failed
	failed = _test_preflop_ai_can_fold_weak_call() or failed
	failed = _test_preflop_ai_uses_pot_odds() or failed
	failed = _test_turn_river_straight_or_flush_forces_ai_all_in() or failed
	failed = _test_all_in_betting_closed_with_non_all_in_ai() or failed
	failed = _test_low_player_chips_force_round_finish() or failed
	failed = _test_low_opponent_chips_force_all_in() or failed
	failed = _test_player_call_for_full_stack_becomes_all_in() or failed
	failed = _test_ai_call_for_full_stack_becomes_all_in() or failed
	failed = _test_capped_ai_raise_becomes_all_in() or failed

	quit(1 if failed else 0)


func _test_deck() -> bool:
	var deck := DeckScript.new()

	if deck.remaining_count() != 52:
		return _fail("Deck should start with 52 cards.")

	var drawn_cards := deck.draw_cards(2)
	if drawn_cards.size() != 2 or deck.remaining_count() != 50:
		return _fail("Deck draw should remove cards.")

	return false


func _test_hand_evaluator() -> bool:
	var straight_flush := HandEvaluatorScript.evaluate(_cards([
		"AS",
		"KS",
		"QS",
		"JS",
		"TS",
		"2C",
		"3D",
	]))
	if straight_flush["rank"] != PokerRulesScript.HandRank.STRAIGHT_FLUSH:
		return _fail("Expected straight flush.")

	var full_house := HandEvaluatorScript.evaluate(_cards([
		"AH",
		"AD",
		"AC",
		"KH",
		"KD",
		"2S",
		"3C",
	]))
	if full_house["rank"] != PokerRulesScript.HandRank.FULL_HOUSE:
		return _fail("Expected full house.")

	if HandEvaluatorScript.compare_results(straight_flush, full_house) <= 0:
		return _fail("Straight flush should beat full house.")

	return false


func _test_personal_showdown_kicker() -> bool:
	var community := _cards(["AS", "QD", "9C", "7H", "2S"])
	var king_kicker_hole := _cards(["AH", "KD"])
	var jack_kicker_hole := _cards(["AC", "JD"])

	var king_result := HandEvaluatorScript.evaluate(king_kicker_hole + community)
	king_result = HandEvaluatorScript.apply_personal_showdown_tiebreakers(king_result, king_kicker_hole)
	var jack_result := HandEvaluatorScript.evaluate(jack_kicker_hole + community)
	jack_result = HandEvaluatorScript.apply_personal_showdown_tiebreakers(jack_result, jack_kicker_hole)

	if king_result["rank"] != PokerRulesScript.HandRank.ONE_PAIR:
		return _fail("Expected one pair for the king kicker hand.")
	if king_result["tiebreakers"] != [14, 13]:
		return _fail("Personal kicker should exclude the pair rank from hole cards.")
	if jack_result["tiebreakers"] != [14, 11]:
		return _fail("Lower personal kicker should be preserved after excluding the pair rank.")
	if HandEvaluatorScript.compare_results(king_result, jack_result) <= 0:
		return _fail("King kicker should beat jack kicker when both players have the same pair.")

	return false


func _test_describe_result_can_hide_kicker() -> bool:
	var result := {
		"rank": PokerRulesScript.HandRank.TWO_PAIR,
		"tiebreakers": [14, 12, 13],
	}

	var with_kicker := HandEvaluatorScript.describe_result(result)
	var without_kicker := HandEvaluatorScript.describe_result(result, false)

	if with_kicker != "Two Pair (Ace and Queen, kicker King)":
		return _fail("Two pair description should include kicker by default.")
	if without_kicker != "Two Pair (Ace and Queen)":
		return _fail("Two pair description should hide only kicker details when requested.")

	return false


func _test_round_start() -> bool:
	var manager := PokerRoundManagerScript.new()
	manager.start_new_round()
	var state := manager.get_state()

	if state["pot"] != 0:
		return _fail("Round should start before blinds are posted.")
	if state["blinds_posted"]:
		return _fail("Blinds should wait for the explicit Post Blinds action.")
	if state["community_cards"].size() != 0:
		return _fail("Pre-flop should not reveal community cards.")
	if state["player"]["hole_cards"].size() != 2:
		return _fail("Player should receive two hole cards.")
	if state["opponent"]["hole_cards"].size() != 2:
		return _fail("First opponent should receive two hole cards.")
	if state["opponents"].size() != 2:
		return _fail("Round should include two AI opponents.")
	for opponent in state["opponents"]:
		if opponent["hole_cards"].size() != 2:
			return _fail("Each AI opponent should receive two hole cards.")

	manager.post_blinds()
	state = manager.get_state()
	if state["pot"] != PokerRulesScript.SMALL_BLIND + PokerRulesScript.BIG_BLIND:
		return _fail("Post Blinds should move blinds into the pot.")
	if not state["blinds_posted"]:
		return _fail("Post Blinds should mark blinds as posted.")
	var big_blind_index: int = state["big_blind_opponent_index"]
	if big_blind_index < 0 or big_blind_index >= state["opponents"].size():
		return _fail("Big blind should belong to one of the AI opponents.")
	if state["opponents"][big_blind_index]["chips"] != PokerRulesScript.STARTING_CHIPS - PokerRulesScript.BIG_BLIND:
		return _fail("Selected big blind opponent should pay the big blind.")

	return false


func _test_busted_match_resets_chips() -> bool:
	var manager := PokerRoundManagerScript.new()
	manager.player.chips = 0
	manager.opponent.chips = 1200
	manager.start_new_round()
	var state := manager.get_state()

	if state["player"]["chips"] != PokerRulesScript.STARTING_CHIPS:
		return _fail("Busted player should reset to starting chips on a new round.")
	if state["opponent"]["chips"] != PokerRulesScript.STARTING_CHIPS:
		return _fail("First opponent should reset with the player when the match restarts.")
	for opponent in state["opponents"]:
		if opponent["chips"] != PokerRulesScript.STARTING_CHIPS:
			return _fail("Each AI opponent should reset with the player when the match restarts.")

	return false


func _test_preflop_ai_can_fold_weak_call() -> bool:
	var ai := PokerAIScript.new()
	ai.bluff_chance = 0.0
	var action := ai.decide_action(
		_cards(["2C", "7D"]),
		[],
		PokerRulesScript.BIG_BLIND,
		false,
		PokerRulesScript.STARTING_CHIPS,
		PokerRulesScript.Phase.PRE_FLOP
	)

	if action["action"] != PokerRulesScript.Action.FOLD:
		return _fail("Weak preflop hand should be able to fold when facing a call.")

	return false


func _test_preflop_ai_uses_pot_odds() -> bool:
	var ai := PokerAIScript.new()
	ai.bluff_chance = 0.0
	var action := ai.decide_action(
		_cards(["2C", "7D"]),
		[],
		PokerRulesScript.SMALL_BLIND,
		false,
		PokerRulesScript.STARTING_CHIPS,
		PokerRulesScript.Phase.PRE_FLOP,
		300
	)

	if action["action"] != PokerRulesScript.Action.CALL:
		return _fail("Cheap preflop call into a large pot should be allowed by pot odds.")

	return false


func _test_turn_river_straight_or_flush_forces_ai_all_in() -> bool:
	var ai := PokerAIScript.new()
	ai.bluff_chance = 0.0
	var action := ai.decide_action(
		_cards(["AS", "9S"]),
		_cards(["2S", "4S", "7S", "KD", "3C"]),
		0,
		true,
		640,
		PokerRulesScript.Phase.RIVER,
		420
	)

	if action["action"] != PokerRulesScript.Action.ALL_IN:
		return _fail("AI should force all-in with a made flush on river.")
	if action["amount"] != 640:
		return _fail("Forced turn/river all-in should use all available chips.")

	return false


func _test_all_in_betting_closed_with_non_all_in_ai() -> bool:
	var manager := PokerRoundManagerScript.new()
	manager.start_new_round()
	manager.phase = PokerRulesScript.Phase.TURN
	manager.blinds_posted = true
	manager.community_cards = _cards(["AS", "KD", "7C", "2H"])
	manager.current_bet = 1000
	manager.pot = 2860

	manager.player.chips = 0
	manager.player.current_bet = 860
	manager.player.is_all_in = true

	manager.opponents[0].chips = 340
	manager.opponents[0].current_bet = 1000
	manager.opponents[0].is_all_in = false

	manager.opponents[1].chips = 0
	manager.opponents[1].current_bet = 1000
	manager.opponents[1].is_all_in = true

	manager._settle_unmatched_ai_bets_after_player_all_in()
	var state := manager.get_state()

	if state["phase"] != PokerRulesScript.Phase.ROUND_OVER:
		return _fail("Closed all-in betting should finish the round even if one AI still has chips.")
	if state["community_cards"].size() != PokerRulesScript.MAX_COMMUNITY_CARDS:
		return _fail("Closed all-in betting should deal remaining community cards before showdown.")

	return false


func _test_low_player_chips_force_round_finish() -> bool:
	var manager := PokerRoundManagerScript.new()
	manager.start_new_round()
	manager.phase = PokerRulesScript.Phase.TURN
	manager.blinds_posted = true
	manager.community_cards = _cards(["AS", "KD", "7C", "2H"])
	manager.current_bet = 100
	manager.pot = 300

	manager.player.chips = PokerRulesScript.MIN_RAISE - 5
	manager.player.current_bet = 100
	manager.player.is_all_in = false

	for opponent in manager.opponents:
		opponent.chips = 800
		opponent.current_bet = 115
		opponent.is_all_in = false

	if not manager._force_low_chip_players_all_in():
		return _fail("Player with chips below the minimum raise should be forced all-in.")
	if manager.player.chips != 0 or not manager.player.is_all_in:
		return _fail("Forced low-chip player should spend remaining chips and become all-in.")
	if not manager._finish_if_all_in_betting_is_closed():
		return _fail("Forced low-chip all-in should close betting when opponents already cover it.")

	var state := manager.get_state()
	if state["phase"] != PokerRulesScript.Phase.ROUND_OVER:
		return _fail("Forced low-chip all-in should finish the round.")
	if state["community_cards"].size() != PokerRulesScript.MAX_COMMUNITY_CARDS:
		return _fail("Forced low-chip all-in should deal remaining community cards.")

	return false


func _test_low_opponent_chips_force_all_in() -> bool:
	var manager := PokerRoundManagerScript.new()
	manager.start_new_round()
	manager.phase = PokerRulesScript.Phase.FLOP
	manager.blinds_posted = true
	manager.community_cards = _cards(["AS", "KD", "7C"])
	manager.current_bet = 100
	manager.pot = 250

	manager.player.chips = 600
	manager.player.current_bet = 100
	manager.player.is_all_in = false

	manager.opponents[0].chips = PokerRulesScript.MIN_RAISE - 5
	manager.opponents[0].current_bet = 100
	manager.opponents[0].is_all_in = false

	manager.opponents[1].chips = 500
	manager.opponents[1].current_bet = 115
	manager.opponents[1].is_all_in = false

	if not manager._force_low_chip_players_all_in():
		return _fail("Opponent with chips below the minimum raise should be forced all-in.")
	if manager.opponents[0].chips != 0 or not manager.opponents[0].is_all_in:
		return _fail("Forced low-chip opponent should spend remaining chips and become all-in.")
	if manager.current_bet != 115:
		return _fail("Forced low-chip opponent should update current bet with their final chips.")

	return false


func _test_player_call_for_full_stack_becomes_all_in() -> bool:
	var manager := PokerRoundManagerScript.new()
	manager.start_new_round()
	manager.current_bet = 100
	manager.player.current_bet = 0
	manager.player.chips = 100

	var action := manager._normalize_player_action(PokerRulesScript.Action.CALL)
	if action != PokerRulesScript.Action.ALL_IN:
		return _fail("Player call for the full stack should become all in.")

	return false


func _test_ai_call_for_full_stack_becomes_all_in() -> bool:
	var manager := PokerRoundManagerScript.new()
	manager.start_new_round()
	var ai_player = manager.opponents[0]
	ai_player.current_bet = 0
	ai_player.chips = 100

	var action := manager._normalize_ai_action(ai_player, {
		"action": PokerRulesScript.Action.CALL,
		"amount": 100,
	}, 100)
	if action.get("action") != PokerRulesScript.Action.ALL_IN:
		return _fail("AI call for the full stack should become all in.")
	if action.get("amount") != 100:
		return _fail("AI all in should use all available chips.")

	return false


func _test_capped_ai_raise_becomes_all_in() -> bool:
	var manager := PokerRoundManagerScript.new()
	manager.start_new_round()
	manager.ai_raise_count = manager.MAX_AI_RAISES_PER_BETTING_ROUND
	manager.opponents[0].chips = 420

	var action := manager._normalize_capped_ai_raise_action(manager.opponents[0], {
		"action": PokerRulesScript.Action.RAISE,
		"amount": PokerRulesScript.MIN_RAISE,
	})

	if action["action"] != PokerRulesScript.Action.ALL_IN:
		return _fail("AI raise after the cap should become all-in.")
	if action["amount"] != 420:
		return _fail("Capped AI all-in should use all remaining chips.")

	return false


func _cards(codes: Array[String]) -> Array[CardData]:
	var cards: Array[CardData] = []

	for code in codes:
		cards.append(CardDataScript.from_code(code))

	return cards


func _fail(message: String) -> bool:
	push_error(message)
	return true
