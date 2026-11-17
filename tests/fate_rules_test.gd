extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _card(id: int, suit: String, color: String = "无色", bonus: int = 0) -> Dictionary:
	return {"id": id, "suit": suit, "base": FateRules.SUIT_VALUES[suit], "value_bonus": bonus, "color": color, "tag": "", "copies": 0}


func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90731
	var deck := FateRules.create_deck(rng)
	_check(deck.size() == 27, "Deck contains exactly 27 cards")
	_check(FateRules.SUITS.all(func(suit: String) -> bool: return deck.filter(func(card: Dictionary) -> bool: return card.suit == suit).size() == FateRules.SUIT_COUNTS[suit]), "Suit counts match the requested distribution")
	var expected_colors := {"无色": 19, "金": 1, "银": 1, "黑": 2, "蓝": 2, "绿": 2, "彩": 0}
	for color in expected_colors:
		_check(deck.filter(func(card: Dictionary) -> bool: return card.color == color).size() == expected_colors[color], "%s color distribution" % color)
	_check(deck.all(func(card: Dictionary) -> bool: return card.value_bonus == 0 and card.tag.is_empty()), "New deck starts without upgrades or tags")
	var sorted := FateRules.shuffled(deck, rng)
	_check(sorted.size() == 27 and sorted.map(func(card: Dictionary) -> int: return card.id).all(func(id: int) -> bool: return deck.any(func(card: Dictionary) -> bool: return card.id == id)), "Shuffle preserves every card")

	var stones := FateStones.catalogue()
	_check(stones.size() == 80, "Complete stone catalogue has 80 entries")
	var family_counts := {"牌面": 18, "色彩": 15, "牌型": 21, "成长": 9, "经济": 2, "重复": 5, "功能": 10}
	for family in family_counts:
		_check(stones.filter(func(stone: Dictionary) -> bool: return stone.family == family).size() == family_counts[family], "%s stone count" % family)
	_check(stones.filter(func(stone: Dictionary) -> bool: return stone.family == "牌型").size() == 21, "There are three stones for all seven hand ranks")
	for seed in range(4):
		var offer_rng := RandomNumberGenerator.new()
		offer_rng.seed = seed
		var offers := FateStones.draw_offers(offer_rng, 3)
		_check(offers.size() == 3 and offers[0].id != offers[1].id and offers[1].id != offers[2].id and offers[0].id != offers[2].id, "Shop offers are unique")
	var legendary_rng := RandomNumberGenerator.new()
	legendary_rng.seed = 42
	var legendary := FateStones.draw_offers(legendary_rng, 12, true)
	_check(legendary.all(func(stone: Dictionary) -> bool: return stone.rarity == "传奇"), "Dream reward only draws legendary stones")
	var excluded_ids: Array[String] = [stones[0].id, stones[1].id]
	var unowned := FateStones.draw_offers(legendary_rng, 100, false, excluded_ids)
	_check(unowned.size() == 78 and unowned.all(func(stone: Dictionary) -> bool: return stone.id not in excluded_ids), "Offers exclude already equipped stones")

	var levels := {}
	for rank in FateRules.RANKS:
		levels[rank] = 1
	_check(FateRules.evaluate([_card(1, "日")], levels).rank == "single", "Single-card hand")
	_check(FateRules.evaluate([_card(1, "星空"), _card(2, "星空")], levels).rank == "pair", "Pair hand")
	_check(FateRules.evaluate([_card(1, "大地"), _card(2, "大地"), _card(3, "大地")], levels).rank == "three", "Three-of-a-kind hand")
	_check(FateRules.evaluate([_card(1, "森林"), _card(2, "森林"), _card(3, "森林"), _card(4, "森林")], levels).rank == "four", "Four-of-a-kind hand")
	_check(FateRules.evaluate([_card(1, "月", "蓝"), _card(2, "星空", "蓝"), _card(3, "大地", "蓝"), _card(4, "海洋", "蓝")], levels).rank == "flush", "Four-card flush hand")
	_check(FateRules.evaluate([_card(1, "森林", "银"), _card(2, "森林", "银"), _card(3, "森林", "银"), _card(4, "森林", "银")], levels).rank == "four_flush", "Four-of-a-kind flush hand")
	_check(FateRules.evaluate([_card(1, "日"), _card(2, "月")], levels).rank == "fate", "Sun and moon make the fate hand")
	_check(FateRules.evaluate([_card(1, "星空", "无色"), _card(2, "月", "无色"), _card(3, "海洋", "无色"), _card(4, "森林", "无色")], levels).rank != "flush", "Colorless cards do not create a flush")
	_check(FateRules.evaluate([_card(1, "日")], levels).score == 20, "Single-card base score includes the card and rank")
	_check(FateRules.evaluate([_card(1, "日", "金")], levels).score == 300, "Gold and sun multiply fate by three and five")
	_check(FateRules.evaluate([_card(1, "月", "银")], levels).score == 285, "Silver and moon each multiply fate")
	_check(FateRules.evaluate([_card(1, "星空", "蓝")], levels).score == 63, "Blue adds five base and star multiplies fate by three")
	_check(FateRules.evaluate([_card(1, "日")], levels, [FateStones.by_id("suit_日_base")]).base == 23, "Suit stone increases per-card base")
	_check(FateRules.evaluate([_card(1, "日", "蓝")], levels, [FateStones.by_id("color_蓝_mult")]).power == 1.5, "Color multiplier stone multiplies fate")
	_check(FateRules.evaluate([_card(1, "星空", "蓝")], levels, [FateStones.by_id("repeat_stars")]).power == 9, "Star repeat replays the blue-star trigger")
	_check(FateRules.evaluate([_card(1, "日")], levels, [FateStones.by_id("suit_日_mult")]).power == 1.5, "Suit multiplier stones multiply fate")
	_check(FateRules.evaluate([_card(1, "星空", "蓝")], levels, [FateStones.by_id("repeat_last_card")]).power == 9, "Final card trigger repeats")
	_check(FateRules.evaluate([_card(1, "日", "金")], levels, [FateStones.by_id("repeat_rare")]).power == 225, "Rare-color repeat replays color and destiny bonuses")
	levels["pair"] = 3
	_check(FateRules.evaluate([_card(1, "海洋"), _card(2, "海洋")], levels).base == 36, "Pair source level adds ten base per level")
	_check(FateRules.evaluate([_card(1, "海洋"), _card(2, "海洋")], levels).power == 4.0, "Each source level adds one fate power")
	_check(FateRules.evaluate([_card(1, "海洋", "黑")], levels).base == 18, "Black color adds five base")
	_check(FateRules.evaluate([_card(1, "海洋", "蓝")], levels).score == 36, "Blue sea also applies its special multiplier")
	_check(FateRules.evaluate([_card(1, "森林", "绿")], levels).score == 36, "Green forest also applies its special multiplier")
	_check(FateRules.evaluate([_card(1, "月", "蓝"), _card(2, "星空", "彩"), _card(3, "大地", "蓝"), _card(4, "海洋", "彩")], levels).rank == "flush", "Rainbow completes a flush of one other color")
	_check(FateRules.evaluate([_card(1, "月", "蓝"), _card(2, "星空", "彩"), _card(3, "大地", "绿"), _card(4, "海洋", "彩")], levels).rank != "flush", "Rainbow cannot reconcile two different fixed colors")
	_check(FateRules.evaluate([_card(1, "森林"), _card(2, "森林"), _card(3, "森林"), _card(4, "日")], levels).rank == "three", "Three-of-a-kind is retained with one additional card")
	_check(FateRules.evaluate([_card(1, "月")], levels, [FateStones.by_id("repeat_card")]).base == 28, "Repeat replays the card's printed base as well")
	_check(FateRules.evaluate([_card(1, "日")], levels, [], 10, 1.5).score == 45, "Run-wide base and power modifiers apply")
	var invalid := FateRules.evaluate([], levels)
	_check(invalid.score == 0 and invalid.rank.is_empty(), "Empty hand cannot be scored")
	if failures.is_empty():
		print("FATE_RULES_PASS: %d checks" % checks)
		quit(0)
	else:
		push_error("FATE_RULES_FAIL: %d of %d checks failed." % [failures.size(), checks])
		quit(1)
