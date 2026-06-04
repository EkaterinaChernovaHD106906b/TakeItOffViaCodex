extends SceneTree

const CardDataScript := preload("res://scripts/poker/CardData.gd")
const DeckScript := preload("res://scripts/poker/Deck.gd")
const HandEvaluatorScript := preload("res://scripts/poker/HandEvaluator.gd")
const PokerRoundManagerScript := preload("res://scripts/game/PokerRoundManager.gd")
const PokerRulesScript := preload("res://scripts/poker/PokerRules.gd")


func _init() -> void:
	var failed := false
	failed = _test_deck() or failed
	failed = _test_hand_evaluator() or failed
	failed = _test_round_start() or failed
	failed = _test_busted_match_resets_chips() or failed
	failed = _test_all_in_betting_closed_with_non_all_in_ai() or failed

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


func _test_all_in_betting_closed_with_non_all_in_ai() -> bool:
	var manager := PokerRoundManagerScript.new()
	manager.start_new_round()
	manager.phase = PokerRulesScript.Phase.TURN
	manager.blinds_posted = true
	manager.community_cards = _cards(["AS", "KD", "7C", "2H"])
	manager.current_bet = 1000
	manager.pot = 3000

	manager.player.chips = 0
	manager.player.current_bet = 1000
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


func _cards(codes: Array[String]) -> Array[CardData]:
	var cards: Array[CardData] = []

	for code in codes:
		cards.append(CardDataScript.from_code(code))

	return cards


func _fail(message: String) -> bool:
	push_error(message)
	return true
