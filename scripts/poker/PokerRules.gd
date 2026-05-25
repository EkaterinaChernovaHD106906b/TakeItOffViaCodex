class_name PokerRules
extends RefCounted

enum Phase {
	PRE_FLOP,
	FLOP,
	TURN,
	RIVER,
	SHOWDOWN,
	ROUND_OVER,
}

enum Action {
	FOLD,
	CHECK,
	CALL,
	RAISE,
	ALL_IN,
}

enum HandRank {
	HIGH_CARD = 1,
	ONE_PAIR = 2,
	TWO_PAIR = 3,
	THREE_OF_A_KIND = 4,
	STRAIGHT = 5,
	FLUSH = 6,
	FULL_HOUSE = 7,
	FOUR_OF_A_KIND = 8,
	STRAIGHT_FLUSH = 9,
}

const STARTING_CHIPS := 1000
const SMALL_BLIND := 10
const BIG_BLIND := 20
const MIN_RAISE := 20
const CARDS_PER_PLAYER := 2
const MAX_COMMUNITY_CARDS := 5


static func get_hand_rank_name(rank: int) -> String:
	match rank:
		HandRank.STRAIGHT_FLUSH:
			return "Straight Flush"
		HandRank.FOUR_OF_A_KIND:
			return "Four of a Kind"
		HandRank.FULL_HOUSE:
			return "Full House"
		HandRank.FLUSH:
			return "Flush"
		HandRank.STRAIGHT:
			return "Straight"
		HandRank.THREE_OF_A_KIND:
			return "Three of a Kind"
		HandRank.TWO_PAIR:
			return "Two Pair"
		HandRank.ONE_PAIR:
			return "One Pair"
		_:
			return "High Card"


static func get_phase_name(phase: Phase) -> String:
	match phase:
		Phase.PRE_FLOP:
			return "Pre-Flop"
		Phase.FLOP:
			return "Flop"
		Phase.TURN:
			return "Turn"
		Phase.RIVER:
			return "River"
		Phase.SHOWDOWN:
			return "Showdown"
		_:
			return "Round Over"
