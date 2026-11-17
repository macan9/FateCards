extends SceneTree

var failures: Array[String] = []
var checks := 0
var table


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _ids(count: int) -> Array[int]:
	var ids: Array[int] = []
	for index in range(count):
		ids.append(table.hand[index].id)
	return ids


func _find(suit: String) -> Dictionary:
	for card in table.master_deck:
		if card.suit == suit:
			return card
	return {}


func _give_tarot(action: String) -> void:
	table.tarot_inventory.clear()
	table.tarot_inventory.append(action)
	table.tarot_cards = 1


func _run() -> void:
	table = load("res://scenes/game_table.tscn").instantiate()
	root.add_child(table)
	current_scene = table
	await process_frame
	await process_frame
	table.rng.seed = 1763
	table._new_run()
	table.stage_target = 99999999
	_check(table.master_deck.size() == 27, "New run creates 27 cards")
	_check(table.hand.size() == 6 and table.plays_left == 2 and table.discards_left == 2, "Six cards, two divinations, two discards")
	_check(table.stone_slots == 4 and table.stones.is_empty(), "Four initially empty stone slots")
	table.selected_ids.assign(_ids(5))
	table._play_selected()
	_check(table.plays_left == 2 and table.seen_count == 6, "Five-card play is rejected")
	table.selected_ids.assign(_ids(4))
	table._discard_selected()
	_check(table.discards_left == 2, "Four-card discard is rejected without a stone")
	for action in range(2):
		table.selected_ids.assign(_ids(3))
		table._discard_selected()
	_check(table.seen_count == 12 and table.discards_left == 0 and table.hand.size() == 6, "Two three-card exchanges see twelve cards")
	table.selected_ids.assign(_ids(4))
	table._play_selected()
	_check(table.hand.size() == 6 and table.seen_count == 16 and table.plays_left == 1, "First four-card play replenishes to six, sees sixteen total")
	var draw_before_last: int = table.draw_pile.size()
	table.selected_ids.assign(_ids(4))
	table._play_selected()
	_check(table.draw_pile.size() == draw_before_last and table.hand.size() == 2 and table.seen_count == 16, "Last divination never draws extra cards")
	_check(table.stage_finished and not table.round_won, "Exhausted divinations below target end the run")

	table._retry_run()
	table.stage_target = 99999999
	var one_card: Array[Dictionary] = [table.hand[0]]
	table.stage_target = FateRules.evaluate(one_card, table.levels).score
	table.selected_ids.assign(_ids(1))
	table._play_selected()
	_check(not table.stage_finished and table.round_score == table.stage_target, "Exactly equal to havoc is not a win")
	table.selected_ids.assign(_ids(1))
	table._play_selected()
	_check(table.stage_finished and table.round_won, "Cumulative score strictly above target wins")
	_check(table.origin_cards == 1 and table.tarot_cards == 1 and table.coins == 32, "Clear rewards twelve coins, one tarot, one source card")
	table._enter_intermission()
	var old_level: int = table.levels.pair
	table._upgrade_origin("pair")
	_check(table.levels.pair == old_level + 1 and table.origin_cards == 0, "Source card upgrades chosen hand level")

	_give_tarot("add_value")
	var sun_id: int = _find("日").id
	table._begin_tarot_action("add_value")
	table._select_deck_card(sun_id)
	await process_frame
	_check(table._master_card(sun_id).value_bonus == 10 and table.tarot_cards == 0, "Value tarot adds the printed card value")
	_give_tarot("add_value")
	table._begin_tarot_action("add_value")
	table._select_deck_card(sun_id)
	await process_frame
	_check(table._master_card(sun_id).value_bonus == 20, "Value tarot stacks without a cap")
	_give_tarot("rainbow")
	table._begin_tarot_action("rainbow")
	table._cancel_card_selection()
	_check(table.tarot_cards == 1 and table.tarot_inventory[0] == "rainbow", "Cancelling refunds the exact tarot")
	table._begin_tarot_action("rainbow")
	table._select_deck_card(sun_id)
	await process_frame
	_check(table._master_card(sun_id).color == "彩", "Tarot colors any chosen card")
	_give_tarot("economy")
	table._begin_tarot_action("economy")
	table._select_deck_card(sun_id)
	await process_frame
	_check(table._master_card(sun_id).tag == "economy", "Economy tag applies once")
	_give_tarot("origin")
	table._begin_tarot_action("origin")
	_check(not table.pending_card_filter.call(table._master_card(sun_id)), "Existing tag blocks mutually exclusive tags")
	table._cancel_card_selection()

	table.coins = 100
	table._show_shop()
	var first_offer: String = table.shop_offers[0].id
	table._show_intermission()
	table._show_shop()
	_check(table.shop_offers[0].id == first_offer, "Leaving the shop does not reroll its offers")
	var stone: Dictionary = table.shop_offers[0]
	var cost: int = stone.cost
	table._buy_stone(stone)
	_check(table.stones.size() == 1 and table.coins == 100 - cost and table.shop_used, "Purchase charges the displayed cost and equips stone")
	var before_event: int = table.coins
	table._event_take_twenty()
	_check(table.event_used and table.coins == before_event + 20, "Guaranteed event grants twenty coins")
	table.stones.clear()
	table.stones.append(FateStones.by_id("utility_hand"))
	table.stones.append(FateStones.by_id("utility_play"))
	table.stones.append(FateStones.by_id("utility_discard"))
	table.stones.append(FateStones.by_id("utility_force_sun"))
	table._advance_stage()
	_check(table.stage == 2 and table.hand.size() == 7 and table._hand_limit() == 7, "Hand stone adds one drawn card and one slot")
	_check(table.plays_left == 3 and table.discards_left == 3, "Utility stones grant extra play and exchange")
	_check(table.hand.any(func(card: Dictionary) -> bool: return card.suit == "日"), "Guaranteed sun appears without exceeding hand limit")

	table.stones.clear()
	table.stones.append(FateStones.by_id("growth_add_mult"))
	table.stones.append(FateStones.by_id("growth_delete_mult"))
	var earth_id: int = _find("大地").id
	var old_deck_size: int = table.master_deck.size()
	table._copy_master_card(earth_id)
	_check(table.master_deck.size() == old_deck_size + 1 and is_equal_approx(table.stones[0].mult_growth, 1.1), "Deck expansion grows its equipped stone")
	table._remove_master_card(earth_id)
	_check(table.master_deck.size() == old_deck_size and is_equal_approx(table.stones[1].mult_growth, 1.15), "Deck removal grows its equipped stone")
	table._copy_master_card(sun_id)
	_check(table.master_deck.size() == old_deck_size and not table._remove_master_card(sun_id), "Sun and moon cannot be added or removed")

	table.stage = 4
	table.round_score = 999999
	table._finish_stage(true)
	_check(table.current_phase == "coupon" and table.boss_offers.size() >= 3, "Boss victory offers coupons")
	var offered: String = table.boss_offers[0]
	table._show_boss_coupon()
	_check(table.boss_offers[0] == offered, "Reopening rewards cannot reroll coupons")
	table._claim_coupon("额外占卜")
	_check(table.current_phase == "dream", "Coupon reward advances to dream choice")
	table._dream_delete()
	_check(not table.pending_card_filter.call(_find("月")), "Dream selection protects sun and moon")
	var dream_ids: Array[int] = [_find("森林").id, _find("海洋").id]
	table._resolve_dream_delete(dream_ids)
	_check(table.master_deck.size() == old_deck_size - 2 and table.current_phase == "victory", "Dream removes two specified cards")
	table._continue_chapter()
	table._advance_stage()
	_check(table.chapter == 2 and table.stage == 1 and table.vouchers.play == 1 and table.plays_left == 3, "Boss rewards carry into the next chapter")
	_check(table.stage_target == FateRules.ROUND_TARGETS[1] * 2, "Next chapter raises the havoc target")

	table._retry_run()
	table.stage_target = 99999999
	table.stones.append(FateStones.by_id("repeat_card"))
	table.stones.append(FateStones.by_id("growth_play_base"))
	table.hand[0].tag = "economy"
	table.selected_ids.assign(_ids(1))
	table._play_selected()
	_check(table.coins == 40, "Repeated economy card pays ten coins per trigger")
	_check(table.stones[1].base_growth == 2, "Play growth is stored on its equipped stone")
	table.hand[0].tag = "tarot"
	table.selected_ids.assign(_ids(1))
	table._discard_selected()
	_check(table.tarot_cards == 1 and table.tarot_inventory[0] in table.TAROT_ACTIONS, "Discarding a tarot-tagged card generates one random tarot")

	table._retry_run()
	table.hand[0].tag = "origin"
	table.stage_target = 0
	table.selected_ids.assign(_ids(1))
	table._play_selected()
	_check(table.levels.single == 2, "Winning levels the hand rank of the played origin-tagged card")

	table._retry_run()
	table.stage_target = 99999999
	for stone_id in ["utility_play_copy", "utility_play_delete", "growth_add_mult", "growth_delete_mult"]:
		table.stones.append(FateStones.by_id(stone_id))
	var mutable: Array = table.hand.filter(func(card: Dictionary) -> bool: return card.suit not in ["日", "月"])
	var removed_id: int = mutable[0].id
	table.selected_ids.assign([removed_id])
	table._play_selected()
	_check(table.master_deck.size() == 27 and table._master_card(removed_id).is_empty(), "Played copy and delete replace the original with one new card")
	_check(table.draw_pile.any(func(card: Dictionary) -> bool: return card.id == 27), "Played copy is added to the current draw pile")
	_check(is_equal_approx(table.stones[2].mult_growth, 1.1) and is_equal_approx(table.stones[3].mult_growth, 1.15), "Play mutations trigger deck growth exactly once")
	table._use_active_stone(FateStones.by_id("utility_copy"))
	_check(not table.pending_card_filter.call(_find("日")), "Active copy selection excludes protected cards")
	table._cancel_card_selection()

	table._enter_intermission()
	var transform_ids: Array[int] = [_find("海洋").id, _find("大地").id]
	table._master_card(transform_ids[0]).value_bonus = 6
	table._master_card(transform_ids[0]).tag = "economy"
	table._master_card(transform_ids[0]).color = "蓝"
	table._resolve_transform(transform_ids, "森林")
	await process_frame
	var transformed: Dictionary = table._master_card(transform_ids[0])
	_check(transformed.suit == "森林" and transformed.base == 3 and transformed.value_bonus == 6 and transformed.tag == "economy" and transformed.color == "蓝", "Transform preserves upgrades, tags and color while changing printed value")
	var target_id: int = transform_ids[1]
	var replace_ids: Array[int] = [target_id]
	table._tarot_replace_target(replace_ids, transform_ids[0])
	await process_frame
	_check(table._master_card(target_id).id == target_id and table._master_card(target_id).value_bonus == 6 and table._master_card(target_id).tag == "economy", "A-over-B copies properties while preserving the target ID")

	table.pending_tarot_spent = true
	table.pending_tarot_action = "delete"
	table.pending_card_count = 1
	table._retry_run()
	_check(not table.pending_tarot_spent and table.pending_card_count == 0 and table.latest_result.is_empty(), "New run resets pending choices and score previews")
	table._show_score_details()
	await process_frame
	await process_frame
	_check(table.card_row.get_child(0).focus_mode == Control.FOCUS_NONE, "Modal prevents keyboard focus on underlying cards")
	_check(table.modal.is_ancestor_of(root.gui_get_focus_owner()), "Modal focuses its own first enabled button")
	table._close_modal()
	_check(table.card_row.get_child(0).focus_mode == Control.FOCUS_ALL, "Closing a modal restores card keyboard focus")
	table.stage_target = 99999999
	table.hand.resize(1)
	table.draw_pile.clear()
	table.discard_pile.append(_find("森林").duplicate(true))
	table.selected_ids.assign(_ids(1))
	table._play_selected()
	_check(table.stage_finished and not table.round_won, "No playable cards ends a stage even when discarded cards remain")

	if failures.is_empty():
		print("GAMEPLAY_SMOKE_PASS: %d checks" % checks)
		quit(0)
	else:
		push_error("GAMEPLAY_SMOKE_FAIL: %d of %d checks failed." % [failures.size(), checks])
		quit(1)
