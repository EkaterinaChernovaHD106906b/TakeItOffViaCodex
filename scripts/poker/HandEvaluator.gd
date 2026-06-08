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


static func apply_personal_showdown_tiebreakers(result: Dictionary, hole_cards: Array[CardData]) -> Dictionary:
	var adjusted := result.duplicate(true)
	var rank: int = adjusted.get("rank", PokerRules.HandRank.HIGH_CARD)
	var tiebreakers: Array = adjusted.get("tiebreakers", [])

	match rank:
		PokerRules.HandRank.FOUR_OF_A_KIND:
			adjusted["tiebreakers"] = [
				_tiebreaker(tiebreakers, 0),
				_highest_hole_rank_except(hole_cards, [_tiebreaker(tiebreakers, 0)]),
			]
		PokerRules.HandRank.FLUSH:
			adjusted["tiebreakers"] = [_highest_hole_rank(hole_cards)]
		PokerRules.HandRank.THREE_OF_A_KIND:
			adjusted["tiebreakers"] = [
				_tiebreaker(tiebreakers, 0),
				_highest_hole_rank_except(hole_cards, [_tiebreaker(tiebreakers, 0)]),
			]
		PokerRules.HandRank.TWO_PAIR:
			adjusted["tiebreakers"] = [
				_tiebreaker(tiebreakers, 0),
				_tiebreaker(tiebreakers, 1),
				_highest_hole_rank_except(hole_cards, [
					_tiebreaker(tiebreakers, 0),
					_tiebreaker(tiebreakers, 1),
				]),
			]
		PokerRules.HandRank.ONE_PAIR:
			adjusted["tiebreakers"] = [
				_tiebreaker(tiebreakers, 0),
				_highest_hole_rank_except(hole_cards, [_tiebreaker(tiebreakers, 0)]),
			]
		PokerRules.HandRank.HIGH_CARD:
			adjusted["tiebreakers"] = [_highest_hole_rank(hole_cards)]

	return adjusted


static func describe_result(result: Dictionary, include_kicker: bool = true) -> String:
	var rank: int = result.get("rank", PokerRules.HandRank.HIGH_CARD)
	var rank_name := PokerRulesScript.get_hand_rank_name(rank)
	var tiebreakers: Array = result.get("tiebreakers", [])

	if not include_kicker:
		return _describe_result_without_kicker(rank, rank_name, tiebreakers)

	return _describe_result_with_kicker(rank, rank_name, tiebreakers)


static func _describe_result_without_kicker(rank: int, rank_name: String, tiebreakers: Array) -> String:
	match rank:
		PokerRules.HandRank.STRAIGHT_FLUSH:
			return _describe_high_card_rank(rank_name, tiebreakers)
		PokerRules.HandRank.FOUR_OF_A_KIND:
			if _has_tiebreaker(tiebreakers, 0):
				return "%s (%s)" % [rank_name, _rank_label(_tiebreaker(tiebreakers, 0))]
			return rank_name
		PokerRules.HandRank.FULL_HOUSE:
			if _has_tiebreakers(tiebreakers, 2):
				return "%s (%s over %s)" % [
					rank_name,
					_rank_label(_tiebreaker(tiebreakers, 0)),
					_rank_label(_tiebreaker(tiebreakers, 1)),
				]
			return rank_name
		PokerRules.HandRank.FLUSH:
			return _describe_high_card_rank(rank_name, tiebreakers)
		PokerRules.HandRank.STRAIGHT:
			return _describe_high_card_rank(rank_name, tiebreakers)
		PokerRules.HandRank.THREE_OF_A_KIND:
			if _has_tiebreaker(tiebreakers, 0):
				return "%s (%s)" % [rank_name, _rank_label(_tiebreaker(tiebreakers, 0))]
			return rank_name
		PokerRules.HandRank.TWO_PAIR:
			if _has_tiebreakers(tiebreakers, 2):
				return "%s (%s and %s)" % [
					rank_name,
					_rank_label(_tiebreaker(tiebreakers, 0)),
					_rank_label(_tiebreaker(tiebreakers, 1)),
				]
			return rank_name
		PokerRules.HandRank.ONE_PAIR:
			if _has_tiebreaker(tiebreakers, 0):
				return "%s (%s)" % [rank_name, _rank_label(_tiebreaker(tiebreakers, 0))]
			return rank_name
		PokerRules.HandRank.HIGH_CARD:
			return _describe_high_card_rank(rank_name, tiebreakers)
		_:
			if tiebreakers.is_empty():
				return rank_name
			return "%s (%s)" % [rank_name, _rank_list(tiebreakers)]


static func _describe_result_with_kicker(rank: int, rank_name: String, tiebreakers: Array) -> String:
	match rank:
		PokerRules.HandRank.STRAIGHT_FLUSH:
			return "%s (%s high)" % [rank_name, _rank_label(_tiebreaker(tiebreakers, 0))]
		PokerRules.HandRank.FOUR_OF_A_KIND:
			return "%s (%s, kicker %s)" % [
				rank_name,
				_rank_label(_tiebreaker(tiebreakers, 0)),
				_rank_label(_tiebreaker(tiebreakers, 1)),
			]
		PokerRules.HandRank.FULL_HOUSE:
			return "%s (%s over %s)" % [
				rank_name,
				_rank_label(_tiebreaker(tiebreakers, 0)),
				_rank_label(_tiebreaker(tiebreakers, 1)),
			]
		PokerRules.HandRank.FLUSH:
			return "%s (%s high)" % [rank_name, _rank_label(_tiebreaker(tiebreakers, 0))]
		PokerRules.HandRank.STRAIGHT:
			return "%s (%s high)" % [rank_name, _rank_label(_tiebreaker(tiebreakers, 0))]
		PokerRules.HandRank.THREE_OF_A_KIND:
			return "%s (%s, kicker %s)" % [
				rank_name,
				_rank_label(_tiebreaker(tiebreakers, 0)),
				_rank_label(_tiebreaker(tiebreakers, 1)),
			]
		PokerRules.HandRank.TWO_PAIR:
			return "%s (%s and %s, kicker %s)" % [
				rank_name,
				_rank_label(_tiebreaker(tiebreakers, 0)),
				_rank_label(_tiebreaker(tiebreakers, 1)),
				_rank_label(_tiebreaker(tiebreakers, 2)),
			]
		PokerRules.HandRank.ONE_PAIR:
			return "%s (%s, kicker %s)" % [
				rank_name,
				_rank_label(_tiebreaker(tiebreakers, 0)),
				_rank_label(_tiebreaker(tiebreakers, 1)),
			]
		PokerRules.HandRank.HIGH_CARD:
			return "%s (%s)" % [rank_name, _rank_label(_tiebreaker(tiebreakers, 0))]
		_:
			return "%s (%s)" % [rank_name, _rank_list(tiebreakers)]


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


static func _tiebreaker(tiebreakers: Array, index: int) -> int:
	if index < 0 or index >= tiebreakers.size():
		return 0

	return tiebreakers[index]


static func _has_tiebreaker(tiebreakers: Array, index: int) -> bool:
	return index >= 0 and index < tiebreakers.size() and int(tiebreakers[index]) > 0


static func _has_tiebreakers(tiebreakers: Array, amount: int) -> bool:
	for index in range(amount):
		if not _has_tiebreaker(tiebreakers, index):
			return false

	return true


static func _describe_high_card_rank(rank_name: String, tiebreakers: Array) -> String:
	if not _has_tiebreaker(tiebreakers, 0):
		return rank_name

	return "%s (%s high)" % [rank_name, _rank_label(_tiebreaker(tiebreakers, 0))]


static func _rank_list(ranks: Array) -> String:
	var labels: Array[String] = []

	for rank in ranks:
		labels.append(_rank_label(rank))

	return ", ".join(labels)


static func _highest_hole_rank(hole_cards: Array[CardData]) -> int:
	var highest := 0

	for card in hole_cards:
		highest = maxi(highest, card.rank)

	return highest


static func _highest_hole_rank_except(hole_cards: Array[CardData], excluded_ranks: Array[int]) -> int:
	var highest := 0

	for card in hole_cards:
		if excluded_ranks.has(card.rank):
			continue
		highest = maxi(highest, card.rank)

	return highest


static func _rank_label(rank: int) -> String:
	match rank:
		14:
			return "Ace"
		13:
			return "King"
		12:
			return "Queen"
		11:
			return "Jack"
		10:
			return "10"
		0:
			return "-"
		_:
			return str(rank)


static func _make_result(rank: int, tiebreakers: Array, cards: Array) -> Dictionary:
	return {
		"rank": rank,
		"rank_name": PokerRulesScript.get_hand_rank_name(rank),
		"tiebreakers": tiebreakers,
		"cards": cards,
	}
