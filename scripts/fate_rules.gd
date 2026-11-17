class_name FateRules
extends RefCounted
## Data and deterministic scoring for the 27-card Fortune run.

const SUITS := ["日", "月", "星空", "大地", "海洋", "森林"]
const SHORT_SUITS := ["日", "月", "星", "地", "海", "森"]
const SUIT_VALUES := {"日": 10, "月": 9, "星空": 6, "大地": 5, "海洋": 3, "森林": 3}
const SUIT_COUNTS := {"日": 1, "月": 1, "星空": 3, "大地": 6, "海洋": 8, "森林": 8}
const COLORS := ["无色", "黑", "蓝", "绿", "金", "银", "彩"]
const COLOR_GLYPHS := {"无色": "○", "黑": "●", "蓝": "◈", "绿": "✦", "金": "✧", "银": "◇", "彩": "✴"}
const COLOR_TINTS := {
	"无色": Color("b9c4be"), "黑": Color("94a0aa"), "蓝": Color("77b9e7"),
	"绿": Color("83c79c"), "金": Color("e5c17a"), "银": Color("c7d9e7"), "彩": Color("e3a2d9")
}
const RANKS := ["single", "pair", "three", "four", "flush", "four_flush", "fate"]
const RANK_NAMES := {
	"single": "单牌", "pair": "对子", "three": "三条", "four": "四条",
	"flush": "同花", "four_flush": "同花四条", "fate": "命运（日月）"
}
const RANK_BASE := {"single": 10, "pair": 10, "three": 20, "four": 25, "flush": 25, "four_flush": 40, "fate": 40}
const RANK_POWER := {"single": 1.0, "pair": 2.0, "three": 3.0, "four": 4.0, "flush": 4.0, "four_flush": 4.0, "fate": 2.0}
const RANK_GROWTH_BASE := {"single": 5, "pair": 10, "three": 15, "four": 20, "flush": 20, "four_flush": 25, "fate": 20}
const RANK_GROWTH_POWER := 1.0
const SUIT_SPECIAL := {"日:金": 5.0, "月:银": 5.0, "星空:蓝": 3.0, "星空:黑": 3.0, "大地:黑": 3.0, "海洋:蓝": 2.0, "森林:绿": 2.0}
const ROUND_TARGETS := {1: 75, 2: 125, 3: 190, 4: 290}
const STARTING_HAND_SIZE := 6
const HAND_LIMIT := 6
const PLAY_LIMIT := 4
const MIN_PLAY := 1
const DISCARD_LIMIT := 3
const STARTING_PLAYS := 2
const STARTING_DISCARDS := 2
const STARTING_STONE_SLOTS := 4
const STONE_SHOP_COST := 12


static func create_deck(rng: RandomNumberGenerator) -> Array[Dictionary]:
	var deck: Array[Dictionary] = []
	var id := 0
	for suit in SUITS:
		for copy_index in range(SUIT_COUNTS[suit]):
			deck.append({"id": id, "suit": suit, "base": SUIT_VALUES[suit], "value_bonus": 0, "color": "无色", "tag": "", "copies": 0})
			id += 1
	var pool := range(deck.size())
	var paints := [["金", 1], ["银", 1], ["黑", 2], ["蓝", 2], ["绿", 2]]
	for paint in paints:
		for copy_index in range(paint[1]):
			var pool_index := rng.randi_range(0, pool.size() - 1)
			var card_index: int = pool[pool_index]
			pool.remove_at(pool_index)
			deck[card_index]["color"] = paint[0]
	return deck


static func shuffled(cards: Array[Dictionary], rng: RandomNumberGenerator) -> Array[Dictionary]:
	var result := cards.duplicate(true)
	for i in range(result.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temporary: Dictionary = result[i]
		result[i] = result[j]
		result[j] = temporary
	return result


static func evaluate(cards: Array[Dictionary], levels: Dictionary = {}, stones: Array[Dictionary] = [], play_flat: float = 0.0, play_power: float = 1.0, last_play: bool = false) -> Dictionary:
	if cards.is_empty() or cards.size() > PLAY_LIMIT:
		return {"rank": "", "rank_name": "", "base": 0.0, "power": 0.0, "score": 0, "details": []}
	var counts := {}
	var color_counts := {}
	var base := 0.0
	for card in cards:
		var suit: String = card.get("suit", "")
		counts[suit] = int(counts.get(suit, 0)) + 1
		var color: String = card.get("color", "无色")
		color_counts[color] = int(color_counts.get(color, 0)) + 1
	var rank := _rank(cards, counts, color_counts)
	var level := int(levels.get(rank, 1))
	base += float(RANK_BASE[rank]) + float(maxi(0, level - 1) * int(RANK_GROWTH_BASE[rank]))
	var power := float(RANK_POWER[rank]) + float(maxi(0, level - 1)) * RANK_GROWTH_POWER
	base += play_flat
	var details: Array[String] = []
	details.append("%s Lv.%d：%d 基础 / %0.2f 命运之力" % [RANK_NAMES[rank], level, int(base - play_flat), power])
	var trigger_counts: Array[int] = []
	var repeat_card := _has_stone(stones, "repeat_card")
	var repeat_stars := _has_stone(stones, "repeat_stars")
	var repeat_last_card := _has_stone(stones, "repeat_last_card")
	var repeat_rare := _has_stone(stones, "repeat_rare")
	var repeat_last_play := last_play and _has_stone(stones, "repeat_last_play")
	var trigger_count := 0
	for index in range(cards.size()):
		var card: Dictionary = cards[index]
		var suit: String = card.get("suit", "")
		var color: String = card.get("color", "无色")
		var times := 1 + int(repeat_card) + int(repeat_stars and suit == "星空") + int(repeat_last_card and index == cards.size() - 1) + int(repeat_rare and color in ["金", "银", "彩"]) + int(repeat_last_play)
		trigger_counts.append(times)
		var card_base := float(card.get("base", 0)) + float(card.get("value_bonus", 0))
		details.append("%s · %s色：%d 基础，触发 %d 次" % [suit, color, int(card_base), times])
		for trigger in range(times):
			base += card_base
			var special_key := "%s:%s" % [suit, color]
			if color in ["黑", "蓝", "绿"]:
				base += 5
			if color in ["金", "银", "彩"]:
				power *= 3.0
			if SUIT_SPECIAL.has(special_key):
				power *= float(SUIT_SPECIAL[special_key])
			var card_triggers := _card_stone_triggers(stones, suit, color)
			for stone in card_triggers:
				if stone.effect == "suit_base" or stone.effect == "color_base":
					base += float(stone.amount)
				elif stone.effect == "suit_power" or stone.effect == "color_power":
					power += float(stone.amount)
				elif stone.effect == "suit_multiplier" or stone.effect == "color_multiplier":
					power *= float(stone.amount)
				trigger_count += 1
	if rank == "single" or rank == "pair" or rank == "three" or rank == "four" or rank == "flush" or rank == "four_flush" or rank == "fate":
		for stone in stones:
			if stone.effect == "rank_base" and stone.target == rank:
				base += float(stone.amount)
				details.append("%s +%d 基础" % [stone.name, int(stone.amount)])
			elif stone.effect == "rank_power" and stone.target == rank:
				power += float(stone.amount)
				details.append("%s +%0.2f 命运之力" % [stone.name, stone.amount])
			elif stone.effect == "rank_multiplier" and stone.target == rank:
				power *= float(stone.amount)
				details.append("%s ×%0.2f 命运之力" % [stone.name, stone.amount])
		for stone in stones:
			if stone.effect == "play_base":
				base += float(stone.amount)
			elif stone.effect == "play_power":
				power += float(stone.amount)
	for stone in stones:
		if stone.effect == "round_base":
			base += float(stone.amount)
		elif stone.effect == "round_power":
			power += float(stone.amount)
		base += float(stone.get("base_growth", 0.0))
		power += float(stone.get("power_growth", 0.0))
	for stone in stones:
		power *= float(stone.get("mult_growth", 1.0))
	power *= play_power
	power = maxf(0.0, power)
	base = maxf(0.0, base)
	return {"rank": rank, "rank_name": RANK_NAMES[rank], "base": base, "power": power, "score": floori(base * power), "details": details, "card_triggers": trigger_count, "trigger_counts": trigger_counts, "level": level}


static func _rank(cards: Array[Dictionary], counts: Dictionary, color_counts: Dictionary) -> String:
	var colors := color_counts.keys()
	colors.erase("彩")
	var is_flush: bool = colors.size() <= 1 and not colors.has("无色")
	var four := false
	var three := false
	var pairs := 0
	for amount in counts.values():
		four = four or amount == 4
		three = three or amount == 3
		pairs += int(amount == 2)
	if cards.size() == 2 and counts.get("日", 0) == 1 and counts.get("月", 0) == 1:
		return "fate"
	if cards.size() == 4 and is_flush and four:
		return "four_flush"
	if cards.size() == 4 and four:
		return "four"
	if cards.size() == 4 and is_flush:
		return "flush"
	if three:
		return "three"
	if pairs >= 1:
		return "pair"
	return "single"


static func _has_stone(stones: Array[Dictionary], id: String) -> bool:
	for stone in stones:
		if stone.id == id:
			return true
	return false


static func _card_stone_triggers(stones: Array[Dictionary], suit: String, color: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for stone in stones:
		if (stone.effect == "suit_base" or stone.effect == "suit_power" or stone.effect == "suit_multiplier") and stone.target == suit:
			result.append(stone)
		elif (stone.effect == "color_base" or stone.effect == "color_power" or stone.effect == "color_multiplier") and stone.target == color:
			result.append(stone)
	return result
