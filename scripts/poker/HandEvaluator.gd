class_name HandEvaluator
extends RefCounted

const PokerRulesScript := preload("res://scripts/poker/PokerRules.gd")


static func evaluate(cards: Array[CardData]) -> Dictionary:
	if cards.size() < 5:
		push_warning("Hand evaluation needs at least 5 cards.")
		return _make_result(PokerRules.HandRank.HIGH_CARD, [], [])

	var best_result := _make_result(PokerRules.HandRank.HIGH_CARD, [], [])
	var combinations := _build_five_card_combinations(cards)

	for combination in combinations:
		var result := _evaluate_five_cards(combination)
		if compare_results(result, best_result) > 0:
			best_result = result

	return best_result


static func compare_results(left: Dictionary, right: Dictionary) -> int:
	var left_rank: int = left.get("rank", 0)
	var right_rank: int = right.get("rank", 0)

	if left_rank != right_rank:
		return 1 if left_rank > right_rank else -1

	var left_tiebreakers: Array = left.get("tiebreakers", [])
	var right_tiebreakers: Array = right.get("tiebreakers", [])
	var compare_count := mini(left_tiebreakers.size(), right_tiebreakers.size())

	for index in compare_count:
		if left_tiebreakers[index] != right_tiebreakers[index]:
			return 1 if left_tiebreakers[index] > right_tiebreakers[index] else -1

	if left_tiebreakers.size() == right_tiebreakers.size():
		return 0

	return 1 if left_tiebreakers.size() > right_tiebreakers.size() else -1


static func describe_result(result: Dictionary) -> String:
	return PokerRulesScript.get_hand_rank_name(result.get("rank", PokerRules.HandRank.HIGH_CARD))


static func _evaluate_five_cards(cards: Array) -> Dictionary:
	var sorted_ranks := _get_sorted_ranks(cards)
	var rank_counts := _get_rank_counts(cards)
	var groups := _get_rank_groups(rank_counts)
	var flush_cards := _get_flush_cards(cards)
	var straight_high := _get_straight_high(sorted_ranks)

	if not flush_cards.is_empty() and straight_high > 0:
		return _make_result(PokerRules.HandRank.STRAIGHT_FLUSH, [straight_high], cards)

	if groups[4].size() > 0:
		var four_rank: int = groups[4][0]
		var kicker := _highest_except(sorted_ranks, [four_rank])
		return _make_result(PokerRules.HandRank.FOUR_OF_A_KIND, [four_rank, kicker], cards)

	if groups[3].size() > 0 and groups[2].size() > 0:
		return _make_result(PokerRules.HandRank.FULL_HOUSE, [groups[3][0], groups[2][0]], cards)

	if not flush_cards.is_empty():
		return _make_result(PokerRules.HandRank.FLUSH, sorted_ranks, cards)

	if straight_high > 0:
		return _make_result(PokerRules.HandRank.STRAIGHT, [straight_high], cards)

	if groups[3].size() > 0:
		var three_rank: int = groups[3][0]
		var kickers := _highest_except_list(sorted_ranks, [three_rank], 2)
		return _make_result(PokerRules.HandRank.THREE_OF_A_KIND, [three_rank] + kickers, cards)

	if groups[2].size() >= 2:
		var high_pair: int = groups[2][0]
		var low_pair: int = groups[2][1]
		var kicker := _highest_except(sorted_ranks, [high_pair, low_pair])
		return _make_result(PokerRules.HandRank.TWO_PAIR, [high_pair, low_pair, kicker], cards)

	if groups[2].size() == 1:
		var pair_rank: int = groups[2][0]
		var kickers := _highest_except_list(sorted_ranks, [pair_rank], 3)
		return _make_result(PokerRules.HandRank.ONE_PAIR, [pair_rank] + kickers, cards)

	return _make_result(PokerRules.HandRank.HIGH_CARD, sorted_ranks, cards)


static func _build_five_card_combinations(cards: Array[CardData]) -> Array:
	var combinations := []

	for first in range(cards.size() - 4):
		for second in range(first + 1, cards.size() - 3):
			for third in range(second + 1, cards.size() - 2):
				for fourth in range(third + 1, cards.size() - 1):
					for fifth in range(fourth + 1, cards.size()):
						combinations.append([
							cards[first],
							cards[second],
							cards[third],
							cards[fourth],
							cards[fifth],
						])

	return combinations


static func _get_sorted_ranks(cards: Array) -> Array[int]:
	var ranks: Array[int] = []

	for card in cards:
		ranks.append(card.rank)

	ranks.sort()
	ranks.reverse()
	return ranks


static func _get_rank_counts(cards: Array) -> Dictionary:
	var counts := {}

	for card in cards:
		counts[card.rank] = counts.get(card.rank, 0) + 1

	return counts


static func _get_rank_groups(rank_counts: Dictionary) -> Dictionary:
	var groups := {
		4: [],
		3: [],
		2: [],
		1: [],
	}

	for rank in rank_counts.keys():
		var count: int = rank_counts[rank]
		groups[count].append(rank)

	for count in groups.keys():
		groups[count].sort()
		groups[count].reverse()

	return groups


static func _get_flush_cards(cards: Array) -> Array:
	var suit: String = cards[0].suit

	for card in cards:
		if card.suit != suit:
			return []

	return cards


static func _get_straight_high(sorted_ranks: Array[int]) -> int:
	var unique_ranks: Array[int] = []

	for rank in sorted_ranks:
		if not unique_ranks.has(rank):
			unique_ranks.append(rank)

	if unique_ranks == [14, 5, 4, 3, 2]:
		return 5

	if unique_ranks.size() != 5:
		return 0

	for index in range(unique_ranks.size() - 1):
		if unique_ranks[index] - 1 != unique_ranks[index + 1]:
			return 0

	return unique_ranks[0]


static func _highest_except(sorted_ranks: Array[int], excluded_ranks: Array[int]) -> int:
	for rank in sorted_ranks:
		if not excluded_ranks.has(rank):
			return rank

	return 0


static func _highest_except_list(sorted_ranks: Array[int], excluded_ranks: Array[int], amount: int) -> Array[int]:
	var values: Array[int] = []

	for rank in sorted_ranks:
		if values.size() >= amount:
			break
		if not excluded_ranks.has(rank):
			values.append(rank)

	return values


static func _make_result(rank: int, tiebreakers: Array, cards: Array) -> Dictionary:
	return {
		"rank": rank,
		"rank_name": PokerRulesScript.get_hand_rank_name(rank),
		"tiebreakers": tiebreakers,
		"cards": cards,
	}
