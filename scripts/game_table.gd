extends Control
## Main loop for the Fortune run: score hands, manage the deck, and grow a build.

const RUN_LENGTH := 4
const REWARD_NAMES := ["命运珍藏", "天启之刃", "额外占卜", "额外弃换", "星界手牌", "丰收契约", "塔罗储备"]
const TAROT_ACTIONS := ["add_value", "economy", "origin", "tarot", "common_colors", "rare_color", "rainbow", "delete", "transform_two", "replace"]
const TAROT_NAMES := ["增添基础值", "金运标签", "原初标签", "塔罗标签", "改两张普通色", "改一张稀有色", "赋予彩色", "指定移除一张", "变化指定两张", "以牌 A 覆盖牌 B"]

var rng := RandomNumberGenerator.new()
var master_deck: Array[Dictionary] = []
var draw_pile: Array[Dictionary] = []
var discard_pile: Array[Dictionary] = []
var hand: Array[Dictionary] = []
var played_pile: Array[Dictionary] = []
var stones: Array[Dictionary] = []
var levels := {}
var selected_ids: Array[int] = []
var pending_ids: Array[int] = []
var pending_card_count := 0
var pending_card_purpose := ""
var pending_card_filter: Callable
var pending_card_callback: Callable
var pending_offer: Dictionary = {}
var pending_offer_cost := 0
var pending_tarot_spent := false
var pending_tarot_action := ""
var modal: Control
var previous_focus: Control
var page: VBoxContainer
var card_row: HandFan
var stone_row: FlowContainer
var stage_label: Label
var status_label: Label
var score_label: Label
var target_label: Label
var progress: ProgressBar
var hand_label: Label
var coin_label: Label
var message_label: Label
var stone_slots_label: Label
var play_button: Button
var discard_button: Button
var selected_label: Label
var sort_color_button: Button
var sort_type_button: Button
var stage := 1
var chapter := 1
var round_score := 0
var plays_left := FateRules.STARTING_PLAYS
var discards_left := FateRules.STARTING_DISCARDS
var coins := 20
var tarot_cards := 0
var tarot_inventory: Array[String] = []
var permanent_base := 0.0
var permanent_power := 1.0
var play_flat := 0.0
var hand_bonus := 0
var play_bonus := 0
var discard_bonus := 0
var draw_bonus := 0
var stone_slots := FateRules.STARTING_STONE_SLOTS
var stage_target := 0
var stage_finished := false
var shop_used := false
var event_used := false
var active_used := {}
var vouchers := {}
var current_phase := "play"
var rng_seed := 0
var latest_result := {}
var current_rank := ""
var shop_offers: Array[Dictionary] = []
var boss_offers: Array[String] = []
var round_won := false
var origin_cards := 0
var seen_count := 0


func _ready() -> void:
	theme = MenuTheme.create()
	rng.randomize()
	rng_seed = rng.randi()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed=") and argument.get_slice("=", 1).is_valid_int():
			rng_seed = argument.get_slice("=", 1).to_int()
	rng.seed = rng_seed
	_build_layout()
	resized.connect(_resize_cards)
	_new_run()
	print("[命运占卜] 开始新局；种子：", rng_seed, "；牌组：27 张；牌型：7 种。")


func _build_layout() -> void:
	var margin := MarginContainer.new()
	margin.name = "PageMargin"
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 28)
	page = VBoxContainer.new()
	page.name = "Page"
	page.add_theme_constant_override("separation", 10)
	margin.add_child(page)
	_build_header()
	_build_scoreboard()
	message_label = MenuTheme.label("选择 1–4 张手牌，占卜牌型。", 15, MenuTheme.MUTED)
	page.add_child(message_label)
	var hand_heading := HBoxContainer.new()
	hand_heading.add_theme_constant_override("separation", 10)
	page.add_child(hand_heading)
	hand_label = MenuTheme.label("手牌", 15, MenuTheme.GOLD)
	hand_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_heading.add_child(hand_label)
	sort_color_button = MenuTheme.button("按花色整理", _sort_hand.bind("color"))
	sort_color_button.custom_minimum_size = Vector2(144, 38)
	sort_color_button.tooltip_text = "按无色、黑、蓝、绿、金、银、彩分组；同花色再按类型排列。"
	hand_heading.add_child(sort_color_button)
	sort_type_button = MenuTheme.button("按类型整理", _sort_hand.bind("type"))
	sort_type_button.custom_minimum_size = Vector2(144, 38)
	sort_type_button.tooltip_text = "按日、月、星空、大地、海洋、森林分组；同类型再按花色排列。"
	hand_heading.add_child(sort_type_button)
	card_row = HandFan.new()
	card_row.name = "Hand"
	card_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_row.card_clicked.connect(_toggle_card)
	card_row.card_reordered.connect(_reorder_hand_card)
	page.add_child(card_row)
	_build_actions()
	_build_stone_strip()


func _build_header() -> void:
	var row := HBoxContainer.new()
	page.add_child(row)
	row.add_child(MenuTheme.label("命运占卜", 29))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	stage_label = MenuTheme.label("", 16, MenuTheme.GOLD)
	row.add_child(stage_label)
	coin_label = MenuTheme.label("", 16, MenuTheme.GOLD)
	coin_label.custom_minimum_size.x = 120
	coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(coin_label)
	row.add_child(MenuTheme.button("Ⅱ 暂停", _pause_game))
	row.add_child(MenuTheme.button("← 主菜单", _confirm_leave))


func _build_scoreboard() -> void:
	var score_row := HBoxContainer.new()
	page.add_child(score_row)
	score_label = MenuTheme.label("", 19, MenuTheme.IVORY)
	score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_row.add_child(score_label)
	target_label = MenuTheme.label("", 16, MenuTheme.GOLD)
	target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_row.add_child(target_label)
	score_row.add_child(MenuTheme.button("明细 / 牌型", _show_score_details))
	progress = ProgressBar.new()
	progress.custom_minimum_size.y = 12
	progress.show_percentage = false
	page.add_child(progress)
	status_label = MenuTheme.label("", 14, MenuTheme.MUTED)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(status_label)


func _build_actions() -> void:
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	page.add_child(actions)
	play_button = MenuTheme.button("占卜（打出 1–4 张）", _play_selected)
	play_button.custom_minimum_size = Vector2(260, 48)
	MenuTheme.primary(play_button)
	actions.add_child(play_button)
	discard_button = MenuTheme.button("弃换（换入 1–3 张）", _discard_selected)
	discard_button.custom_minimum_size = Vector2(260, 48)
	actions.add_child(discard_button)
	selected_label = MenuTheme.label("尚未选择", 14, MenuTheme.MUTED)
	actions.add_child(selected_label)


func _build_stone_strip() -> void:
	var heading := HBoxContainer.new()
	page.add_child(heading)
	heading.add_child(MenuTheme.label("命运石", 15, MenuTheme.GOLD))
	stone_slots_label = MenuTheme.label("", 13, MenuTheme.MUTED)
	heading.add_child(stone_slots_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(spacer)
	heading.add_child(MenuTheme.button("石之功能", _show_stone_actions))
	stone_row = FlowContainer.new()
	stone_row.add_theme_constant_override("h_separation", 8)
	stone_row.add_theme_constant_override("v_separation", 6)
	page.add_child(stone_row)


func _new_run() -> void:
	pending_ids.clear()
	pending_card_count = 0
	pending_tarot_spent = false
	pending_tarot_action = ""
	pending_offer = {}
	pending_offer_cost = 0
	latest_result = {}
	current_rank = ""
	master_deck = FateRules.create_deck(rng)
	stones.clear()
	levels.clear()
	for rank in FateRules.RANKS:
		levels[rank] = 1
	stage = 1
	chapter = 1
	origin_cards = 0
	coins = 20
	tarot_cards = 0
	tarot_inventory.clear()
	permanent_base = 0.0
	permanent_power = 1.0
	play_flat = 0.0
	hand_bonus = 0
	play_bonus = 0
	discard_bonus = 0
	draw_bonus = 0
	stone_slots = FateRules.STARTING_STONE_SLOTS
	active_used.clear()
	vouchers.clear()
	boss_offers.clear()
	_new_stage()


func _new_stage() -> void:
	latest_result = {}
	stage_target = int(FateRules.ROUND_TARGETS[mini(stage, RUN_LENGTH)])
	stage_target = roundi(stage_target * pow(2.0, chapter - 1))
	stage_label.text = "第%d章 · %s" % [chapter, "Boss" if stage == RUN_LENGTH else "第 %d 幕" % stage]
	var round_extra_plays := play_bonus + int(vouchers.get("play", 0))
	var round_extra_discards := discard_bonus + int(vouchers.get("discard", 0))
	for stone in stones:
		match stone.effect:
			"grow_round_base": stone["base_growth"] = float(stone.get("base_growth", 0.0)) + float(stone.amount)
			"grow_round_power": stone["power_growth"] = float(stone.get("power_growth", 0.0)) + float(stone.amount)
			"grow_round_mult": stone["mult_growth"] = float(stone.get("mult_growth", 1.0)) * float(stone.amount)
			"extra_play": round_extra_plays += int(stone.amount)
			"extra_discard": round_extra_discards += int(stone.amount)
	draw_pile = FateRules.shuffled(master_deck, rng)
	discard_pile.clear()
	hand.clear()
	played_pile.clear()
	selected_ids.clear()
	active_used.clear()
	round_score = 0
	plays_left = FateRules.STARTING_PLAYS + round_extra_plays
	discards_left = FateRules.STARTING_DISCARDS + round_extra_discards
	shop_used = false
	shop_offers.clear()
	event_used = false
	stage_finished = false
	current_phase = "play"
	seen_count = 0
	_draw_cards(_hand_limit())
	_force_starting_card()
	message_label.text = "点击选牌 · 按住拖动换位 · 从左到右结算；黑蓝绿 +5 基础，金银彩 ×3 命运之力。"
	_refresh()


func _force_starting_card() -> void:
	for stone in stones:
		if stone.effect != "force_suit":
			continue
		if hand.any(func(card: Dictionary) -> bool: return card.suit == stone.target):
			continue
		for index in range(draw_pile.size()):
			if draw_pile[index].suit == stone.target:
				var replaced: Dictionary = hand.pop_back()
				draw_pile.append(replaced)
				hand.append(draw_pile.pop_at(index))
				return


func _draw_cards(count: int) -> int:
	var drawn := 0
	for index in range(count):
		if hand.size() >= _hand_limit():
			break
		if draw_pile.is_empty():
			break
		hand.append(draw_pile.pop_back())
		drawn += 1
		seen_count += 1
	return drawn


func _hand_limit() -> int:
	var limit := FateRules.HAND_LIMIT + hand_bonus + int(vouchers.get("hand", 0))
	for stone in stones:
		if stone.effect == "hand_limit":
			limit += int(stone.amount)
	return limit


func _draw_limit() -> int:
	var limit := FateRules.DISCARD_LIMIT + draw_bonus
	for stone in stones:
		if stone.effect == "draw_limit":
			limit += int(stone.amount)
	return limit


func _render_cards() -> void:
	card_row.sync_hand(hand, selected_ids, _hand_can_interact())
	hand_label.text = "手牌 %d / %d   ·   牌库 %d   ·   已见 %d 张   ·   塔罗 %d" % [hand.size(), _hand_limit(), draw_pile.size(), seen_count, tarot_cards]


func _hand_can_interact() -> bool:
	return current_phase == "play" and not stage_finished and not is_instance_valid(modal)


func _sort_hand(mode: String) -> void:
	if not _hand_can_interact():
		return
	card_row.cancel_drag()
	hand.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_type := FateRules.SUITS.find(a.suit)
		var b_type := FateRules.SUITS.find(b.suit)
		var a_color := FateRules.COLORS.find(a.color)
		var b_color := FateRules.COLORS.find(b.color)
		if mode == "color":
			if a_color != b_color:
				return a_color < b_color
			if a_type != b_type:
				return a_type < b_type
		else:
			if a_type != b_type:
				return a_type < b_type
			if a_color != b_color:
				return a_color < b_color
		return int(a.id) < int(b.id))
	message_label.text = "已按%s整理；拖动手牌可调整顺序，出牌按从左到右结算。" % ("花色" if mode == "color" else "类型")
	_update_score_preview()


func _reorder_hand_card(id: int, target_index: int) -> void:
	if not _hand_can_interact():
		return
	var source := -1
	for index in range(hand.size()):
		if hand[index].id == id:
			source = index
			break
	if source < 0:
		return
	var card: Dictionary = hand.pop_at(source)
	hand.insert(clampi(target_index, 0, hand.size()), card)
	message_label.text = "已调整手牌顺序。点击选牌；按住拖动；出牌按从左到右结算。"
	_update_score_preview()


func _resize_cards() -> void:
	if not is_instance_valid(card_row):
		return
	card_row.arrange(false)


func _show_score_details() -> void:
	var content := _open_modal("星盘 · 计分与牌型", "命运数值 = 基础值 × 命运之力；两次占卜累计分 > 浩劫值过关。", 800)
	if not latest_result.is_empty():
		for text: String in latest_result.get("details", []):
			content.add_child(MenuTheme.label(text, 14, MenuTheme.MUTED))
		content.add_child(MenuTheme.label("最终：%d × %0.2f = %d" % [latest_result.base, latest_result.power, latest_result.score], 20, MenuTheme.GOLD))
	for rank in FateRules.RANKS:
		var level := int(levels.get(rank, 1))
		content.add_child(MenuTheme.label("%s  Lv.%d    基础 %d × 命运之力 %0.2f" % [FateRules.RANK_NAMES[rank], level, FateRules.RANK_BASE[rank] + (level - 1) * FateRules.RANK_GROWTH_BASE[rank], FateRules.RANK_POWER[rank] + (level - 1) * FateRules.RANK_GROWTH_POWER], 15))
	content.add_child(MenuTheme.label("四张同色组成同花，彩色可补任意颜色；无色不参与同花。\n按手牌从左到右触发效果，可拖动调整；牌型优先四同花、四条、同花、三条、对子。\n日月恰好两张组成命运。基础值包括所有打出牌与牌型基础。", 13, MenuTheme.MUTED))
	content.add_child(MenuTheme.button("返回", _resume_phase))


func _apply_play_mutations(chosen: Array[Dictionary]) -> void:
	var delete_played := stones.any(func(stone: Dictionary) -> bool: return stone.effect == "play_delete")
	var copy_played := stones.any(func(stone: Dictionary) -> bool: return stone.effect == "play_copy")
	for card in chosen:
		if card.suit in ["日", "月"]:
			continue
		if copy_played:
			_copy_master_card(card.id)
		if delete_played:
			_remove_master_card(card.id)


func _grow_deck_stones(event: String) -> void:
	for stone in stones:
		if stone.effect == event:
			stone["mult_growth"] = float(stone.get("mult_growth", 1.0)) * float(stone.amount)


func _remove_master_card(id: int) -> bool:
	var card := _master_card(id)
	if card.is_empty() or card.suit in ["日", "月"]:
		return false
	master_deck.erase(card)
	_sync_run_card_removed(id)
	_grow_deck_stones("grow_delete_mult")
	return true


func _refresh() -> void:
	if not is_instance_valid(page):
		return
	_render_cards()
	var rank_text: String = latest_result.get("rank_name", "尚未占卜")
	var rank_score: int = latest_result.get("score", 0)
	var rank_formula := ""
	if not latest_result.is_empty():
		rank_formula = "     %s  ·  %d × %0.2f = %d" % [rank_text, int(latest_result.base), float(latest_result.power), rank_score]
	score_label.text = "本幕占卜分  %d%s" % [round_score, rank_formula]
	target_label.text = "浩劫值  %d" % stage_target
	progress.max_value = stage_target
	progress.value = mini(round_score, stage_target)
	status_label.text = "占卜 %d 次     ·     弃换 %d 次     ·     弃换上限 %d     ·     %s" % [plays_left, discards_left, _draw_limit(), "已超越浩劫" if round_score > stage_target else "累计分须 > 浩劫值"]
	coin_label.text = "◈  %d 金币" % coins
	stone_slots_label.text = "     %d / %d 已装备" % [stones.size(), stone_slots]
	for child in stone_row.get_children():
		stone_row.remove_child(child)
		child.queue_free()
	if stones.is_empty():
		stone_row.add_child(MenuTheme.label("尚无命运石。清除一幕后可前往商店。", 13, MenuTheme.MUTED))
	else:
		for stone in stones:
			var chip := Button.new()
			chip.text = "%s  ·  %s" % [stone.name, stone.rarity]
			chip.tooltip_text = stone.description
			chip.custom_minimum_size.y = 34
			chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			chip.pressed.connect(_inspect_stone.bind(stone.id))
			stone_row.add_child(chip)
	play_button.disabled = current_phase != "play" or stage_finished or plays_left <= 0 or selected_ids.is_empty() or selected_ids.size() > FateRules.PLAY_LIMIT
	discard_button.disabled = current_phase != "play" or stage_finished or discards_left <= 0 or selected_ids.is_empty() or selected_ids.size() > _draw_limit()
	discard_button.text = "弃换（1–%d 张）" % _draw_limit()
	selected_label.text = "已选 %d 张" % selected_ids.size() if not selected_ids.is_empty() else "尚未选择"
	sort_color_button.disabled = not _hand_can_interact()
	sort_type_button.disabled = not _hand_can_interact()
	if is_instance_valid(modal):
		_set_page_focus_enabled(false)


func _toggle_card(id: int) -> void:
	if not _hand_can_interact():
		return
	if id in selected_ids:
		selected_ids.erase(id)
	else:
		selected_ids.append(id)
	_update_score_preview()


func _selected_cards() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for card in hand:
		if card.id in selected_ids:
			result.append(card)
	return result


func _update_score_preview() -> void:
	var cards := _selected_cards()
	if cards.is_empty():
		latest_result = {}
		_refresh()
		return
	latest_result = FateRules.evaluate(cards, levels, stones, permanent_base + play_flat, permanent_power, plays_left == 1)
	_refresh()


func _play_selected() -> void:
	if current_phase != "play" or stage_finished or plays_left <= 0 or selected_ids.is_empty() or selected_ids.size() > FateRules.PLAY_LIMIT:
		return
	var chosen := _selected_cards()
	var is_last_play := plays_left == 1
	var result := FateRules.evaluate(chosen, levels, stones, permanent_base + play_flat, permanent_power, is_last_play)
	current_rank = result.rank
	latest_result = result
	round_score += int(result.score)
	plays_left -= 1
	var paid := 0
	for index in range(chosen.size()):
		var card: Dictionary = chosen[index]
		if card.tag == "economy":
			paid += 10 * int(result.trigger_counts[index])
		var played_card := card.duplicate(true)
		played_card["played_rank"] = result.rank
		played_pile.append(played_card)
	_remove_hand_cards(selected_ids, null)
	selected_ids.clear()
	_apply_play_mutations(chosen)
	for stone in stones:
		if stone.effect == "play_coins":
			paid += int(stone.amount)
		elif stone.effect == "grow_play_base":
			stone["base_growth"] = float(stone.get("base_growth", 0.0)) + float(stone.amount)
		elif stone.effect == "grow_play_power":
			stone["power_growth"] = float(stone.get("power_growth", 0.0)) + float(stone.amount)
		elif stone.effect == "grow_play_mult":
			stone["mult_growth"] = float(stone.get("mult_growth", 1.0)) * float(stone.amount)
	coins += paid
	message_label.text = "占卜收入 +%d 金币。" % paid if paid > 0 else "%s：基础 %d × 命运之力 %0.2f = %d。" % [result.rank_name, int(result.base), float(result.power), int(result.score)]
	print("[计分] 第%d幕 %s：基础 %d × 力量 %0.2f = %d；累计 %d/%d。" % [stage, result.rank_name, int(result.base), float(result.power), int(result.score), round_score, stage_target])
	_maybe_level_rank(result.rank)
	if round_score > stage_target:
		_finish_stage(true)
	elif plays_left <= 0:
		_finish_stage(false)
	elif hand.is_empty() and draw_pile.is_empty():
		_finish_stage(false)
	else:
		_draw_cards(chosen.size())
		_refresh()


func _discard_selected() -> void:
	if current_phase != "play" or stage_finished or discards_left <= 0 or selected_ids.is_empty() or selected_ids.size() > _draw_limit():
		return
	var count := selected_ids.size()
	var discarded := _remove_hand_cards(selected_ids, discard_pile)
	selected_ids.clear()
	discards_left -= 1
	var tarot_count := 0
	for card in discarded:
		if card.tag == "tarot":
			tarot_count += 1
	_add_tarot(tarot_count)
	var drawn := _draw_cards(count)
	latest_result = {}
	message_label.text = "弃换 %d 张，补入 %d 张%s。" % [count, drawn, "；塔罗牌生成 %d 个解读机会" % tarot_count if tarot_count > 0 else ""]
	print("[弃换] 弃 %d，补 %d；塔罗 %d；剩余弃换 %d。" % [count, drawn, tarot_count, discards_left])
	_refresh()


func _remove_hand_cards(ids: Array[int], destination: Variant) -> Array[Dictionary]:
	var removed: Array[Dictionary] = []
	for index in range(hand.size() - 1, -1, -1):
		var card: Dictionary = hand[index]
		if card.id in ids:
			removed.push_front(card)
			hand.remove_at(index)
	if destination is Array:
		for card in removed:
			destination.append(card)
	return removed


func _finish_stage(won: bool) -> void:
	if stage_finished:
		return
	stage_finished = true
	round_won = won
	current_phase = "round_result"
	if won:
		coins += 12 + int(vouchers.get("end_coins", 0))
		origin_cards += 1
		_add_tarot(1)
		for stone in stones:
			if stone.effect == "round_coins":
				coins += int(stone.amount)
		_apply_origin_tags()
		message_label.text = "命运暂时站在你这边。" if stage < RUN_LENGTH else "你以 %d 分超越 Boss 的浩劫值。" % round_score
		print("[通关] 第%d幕成功，获得 12 金币。" % stage)
		if stage == RUN_LENGTH:
			_show_boss_coupon()
		else:
			_show_stage_result()
	else:
		message_label.text = "浩劫吞没了星盘。本次占卜结束。"
		print("[失败] 第%d幕结束，总分 %d/%d。" % [stage, round_score, stage_target])
		_show_stage_result()
	_refresh()


func _show_stage_result() -> void:
	if round_won:
		_show_result("占卜成功", "%d > 浩劫值 %d\n获得 12 金币、1 张随机塔罗和 1 张源初牌。" % [round_score, stage_target], "前往幕间准备", _enter_intermission)
	else:
		_show_result("浩劫降临", "%d / %d\n第 %d 幕未能超越浩劫值。" % [round_score, stage_target, stage], "再启命运", _retry_run, true)


func _apply_origin_tags() -> void:
	for card in played_pile:
		if card.tag == "origin":
			var rank: String = card.get("played_rank", current_rank)
			levels[rank] = int(levels.get(rank, 1)) + 1
			message_label.text = "原初之力：%s 升至 Lv.%d。" % [FateRules.RANK_NAMES[rank], levels[rank]]


func _maybe_level_rank(rank: String) -> void:
	var chance := 0.0
	for stone in stones:
		if stone.effect == "level_chance":
			chance += stone.amount
	if chance > 0 and rng.randf() < minf(chance, 0.9):
		levels[rank] = int(levels.get(rank, 1)) + 1
		message_label.text = "命数签触发：%s 升至 Lv.%d。" % [FateRules.RANK_NAMES[rank], levels[rank]]


func _enter_intermission() -> void:
	current_phase = "intermission"
	_show_intermission()


func _show_intermission() -> void:
	var content := _open_modal("幕间准备", "选择塔罗、命运石商店或进入下一幕。石槽上限 %d。" % stone_slots, 680)
	content.add_child(MenuTheme.button("命运石商店  ·  12 / 15 / 20 金币", _show_shop))
	if shop_used:
		content.get_child(0).disabled = true
	if tarot_cards > 0:
		content.add_child(MenuTheme.button("阅读塔罗  ·  剩余 %d 张" % tarot_cards, _show_tarot_workshop))
	else:
		content.add_child(_disabled_option("没有待解读的塔罗牌"))
	if origin_cards > 0:
		content.add_child(MenuTheme.button("源初牌升级  ·  剩余 %d 张" % origin_cards, _show_origin_choice))
	content.add_child(MenuTheme.button("遭遇随机事件", _show_event) if not event_used else _disabled_option("本幕的随机事件已完成"))
	for stone in stones:
		if stone.effect in ["active_delete", "active_copy"] and not bool(active_used.get(stone.id, false)):
			content.add_child(MenuTheme.button("使用命运石功能：%s" % stone.name, _use_active_stone.bind(stone)))
	var advance_text := "进入第 %d 章 · 第 1 幕" % (chapter + 1) if stage == RUN_LENGTH else "进入第 %d 幕" % (stage + 1)
	var advance := MenuTheme.button(advance_text, _advance_stage)
	MenuTheme.primary(advance)
	content.add_child(advance)


func _show_origin_choice() -> void:
	var content := _open_modal("源初牌 · 牌型成长", "消耗一张源初牌，将指定牌型升一级；本次旅程内保留。", 680)
	for rank in FateRules.RANKS:
		content.add_child(MenuTheme.button("%s Lv.%d   →   +%d 基础 / +1 命运之力" % [FateRules.RANK_NAMES[rank], levels[rank], FateRules.RANK_GROWTH_BASE[rank]], _upgrade_origin.bind(rank)))
	content.add_child(MenuTheme.button("返回幕间", _show_intermission))


func _upgrade_origin(rank: String) -> void:
	if origin_cards <= 0:
		return
	origin_cards -= 1
	levels[rank] = int(levels.get(rank, 1)) + 1
	message_label.text = "%s 升至 Lv.%d。" % [FateRules.RANK_NAMES[rank], levels[rank]]
	_show_intermission()
	_refresh()


func _advance_stage() -> void:
	_close_modal()
	stage += 1
	if stage > RUN_LENGTH:
		chapter += 1
		stage = 1
	latest_result = {}
	_new_stage()


func _show_shop() -> void:
	if shop_used:
		return
	if coins < FateRules.STONE_SHOP_COST:
		_show_result("金币不足", "命运石价格 12 金币；当前只有 %d 金币。" % coins, "返回幕间", _show_intermission)
		return
	var content := _open_modal("命运石商店", "随机出现三块命运石。购买后会立即生效。", 740)
	if shop_offers.is_empty():
		shop_offers = FateStones.draw_offers(rng, 3, false, _equipped_stone_ids())
	for stone in shop_offers:
		var choice := MenuTheme.button("%s  ·  %s  ·  %d 金币\n%s" % [stone.name, stone.rarity, stone.cost, stone.description], _buy_stone.bind(stone))
		choice.custom_minimum_size.y = 64
		choice.disabled = coins < int(stone.cost)
		content.add_child(choice)
	content.add_child(MenuTheme.button("暂不购买", _show_intermission))


func _buy_stone(stone: Dictionary) -> void:
	if shop_used or coins < int(stone.cost) or stone.id in _equipped_stone_ids():
		return
	if stones.size() < stone_slots:
		coins -= int(stone.cost)
		stones.append(stone)
		shop_used = true
		message_label.text = "已装备命运石：%s。" % stone.name
		_close_modal()
		_show_intermission()
		_refresh()
	else:
		pending_offer = stone
		pending_offer_cost = int(stone.cost)
		var content := _open_modal("命运石槽已满", "选择一块已装备的石头替换。确认后支付 %d 金币。" % pending_offer_cost, 680)
		for index in range(stones.size()):
			content.add_child(MenuTheme.button("替换 %s  ·  %s" % [stones[index].name, stones[index].description], _replace_stone_for_offer.bind(index)))
		content.add_child(MenuTheme.button("取消", _show_intermission))


func _replace_stone_for_offer(index: int) -> void:
	if coins < pending_offer_cost:
		return
	coins -= pending_offer_cost
	stones[index] = pending_offer
	shop_used = true
	pending_offer = {}
	_close_modal()
	_show_intermission()
	_refresh()


func _show_tarot_workshop() -> void:
	if tarot_cards <= 0:
		return
	_sync_tarot_inventory()
	var content := _open_modal("塔罗改牌", "消耗 1 张塔罗。选择效果，再选择牌组中的目标卡牌。", 720)
	for action in tarot_inventory:
		var index := TAROT_ACTIONS.find(action)
		var button := MenuTheme.button(TAROT_NAMES[index], _begin_tarot_action.bind(action))
		button.disabled = not _tarot_action_available(action)
		content.add_child(button)
	content.add_child(MenuTheme.button("返回幕间", _show_intermission))


func _add_tarot(count: int) -> void:
	for index in range(count):
		tarot_inventory.append(TAROT_ACTIONS[rng.randi_range(0, TAROT_ACTIONS.size() - 1)])
	tarot_cards = tarot_inventory.size()


func _sync_tarot_inventory() -> void:
	while tarot_inventory.size() < tarot_cards:
		tarot_inventory.append(TAROT_ACTIONS[rng.randi_range(0, TAROT_ACTIONS.size() - 1)])
	while tarot_inventory.size() > tarot_cards:
		tarot_inventory.pop_back()


func _tarot_action_available(action: String) -> bool:
	if action == "common_colors":
		return master_deck.size() >= 2
	if action in ["delete", "transform_two"]:
		return _eligible_deck_count(func(card: Dictionary) -> bool: return card.suit not in ["日", "月"]) >= (2 if action == "transform_two" else 1)
	if action == "replace":
		return _eligible_deck_count(func(card: Dictionary) -> bool: return card.suit not in ["日", "月"]) >= 2
	if action in ["rare_color", "rainbow", "add_value"]:
		return not master_deck.is_empty()
	return _eligible_deck_count(func(card: Dictionary) -> bool: return card.tag.is_empty()) > 0


func _begin_tarot_action(action: String) -> void:
	if tarot_cards <= 0 or not _tarot_action_available(action):
		return
	_sync_tarot_inventory()
	if action not in tarot_inventory:
		return
	tarot_inventory.erase(action)
	tarot_cards -= 1
	pending_tarot_spent = true
	pending_tarot_action = action
	var action_index := TAROT_ACTIONS.find(action)
	if action == "common_colors":
		_select_deck_cards("选择两张牌改成普通色", 2, func(_card: Dictionary) -> bool: return true, _choose_common_color.bind(action))
	elif action == "rare_color":
		_select_deck_cards("选择一张牌改成稀有色", 1, func(_card: Dictionary) -> bool: return true, _choose_rare_color.bind(action))
	elif action == "delete":
		_select_deck_cards("选择要移除的一张牌（日月不选）", 1, func(card: Dictionary) -> bool: return card.suit not in ["日", "月"], _tarot_remove_card)
	elif action == "transform_two":
		_select_deck_cards("选择两张牌改变种类（日月不选）", 2, func(card: Dictionary) -> bool: return card.suit not in ["日", "月"], _tarot_transform)
	elif action == "rainbow":
		_select_deck_cards("选择获得彩色的一张牌", 1, func(_card: Dictionary) -> bool: return true, _tarot_rainbow)
	elif action == "replace":
		_select_deck_cards("选择牌 A（作为覆盖来源，日月不选）", 1, func(card: Dictionary) -> bool: return card.suit not in ["日", "月"], _tarot_replace_source)
	elif action == "add_value":
		_select_deck_cards("选择一张牌，基础增加该牌的原始分值（可叠加）", 1, func(_card: Dictionary) -> bool: return true, _apply_simple_tarot.bind(action))
	else:
		_select_deck_cards("选择要改造的一张牌", 1, func(card: Dictionary) -> bool: return card.tag.is_empty(), _apply_simple_tarot.bind(action))
	message_label.text = "消耗 1 张塔罗：%s。" % TAROT_NAMES[action_index]
	_refresh()


func _apply_simple_tarot(ids: Array[int], action: String) -> void:
	var card := _master_card(ids[0])
	match action:
		"add_value": card.value_bonus = int(card.get("value_bonus", 0)) + int(card.base)
		"economy": card.tag = "economy"
		"origin": card.tag = "origin"
		"tarot": card.tag = "tarot"
	_sync_run_card(card)
	_finish_tarot("%s 已应用到 %s 牌。" % [TAROT_NAMES[TAROT_ACTIONS.find(action)], card.suit])


func _choose_common_color(ids: Array[int], _action: String) -> void:
	_choose_color("普通色", ["无色", "黑", "蓝", "绿"], func(color: String) -> void:
		for id in ids:
			_master_card(id).color = color
			_sync_run_card(_master_card(id))
		_finish_tarot("两张牌已改为%s色。" % color))


func _choose_rare_color(ids: Array[int], _action: String) -> void:
	_choose_color("稀有色", ["金", "银", "彩"], func(color: String) -> void:
		_master_card(ids[0]).color = color
		_sync_run_card(_master_card(ids[0]))
		_finish_tarot("牌色已改为%s。" % color))


func _choose_color(title: String, colors: Array[String], callback: Callable) -> void:
	var content := _open_modal("选择" + title, "所有变化均会永久保留在本次牌局的牌组中。", 500)
	for color in colors:
		content.add_child(MenuTheme.button("%s  %s" % [FateRules.COLOR_GLYPHS[color], color], callback.bind(color)))


func _tarot_remove_card(ids: Array[int]) -> void:
	var card := _master_card(ids[0])
	_remove_master_card(ids[0])
	_finish_tarot("已从牌组移除 %s 牌。" % card.suit)


func _tarot_transform(ids: Array[int]) -> void:
	var content := _open_modal("变化两张牌", "选择新的种类。数值增益、颜色和标签保留。", 560)
	for suit: String in ["星空", "大地", "海洋", "森林"]:
		content.add_child(MenuTheme.button("变为" + suit, _resolve_transform.bind(ids, suit)))


func _resolve_transform(ids: Array[int], suit: String) -> void:
	for id in ids:
		var card := _master_card(id)
		card.suit = suit
		card.base = FateRules.SUIT_VALUES[suit]
		_sync_run_card(card)
	_finish_tarot("两张牌已经变为%s。" % suit)


func _tarot_rainbow(ids: Array[int]) -> void:
	_master_card(ids[0]).color = "彩"
	_sync_run_card(_master_card(ids[0]))
	_finish_tarot("目标牌获得彩色。")


func _tarot_replace_source(ids: Array[int]) -> void:
	var source_id := ids[0]
	_select_deck_cards("选择牌 B（将被牌 A 覆盖，日月不选）", 1, func(card: Dictionary) -> bool: return card.id != source_id and card.suit not in ["日", "月"], _tarot_replace_target.bind(source_id))


func _tarot_replace_target(ids: Array[int], source_id: int) -> void:
	var source := _master_card(source_id).duplicate(true)
	var target := _master_card(ids[0])
	var target_id: int = target.id
	target.assign(source)
	target.id = target_id
	_sync_run_card(target)
	_finish_tarot("牌 A 已覆盖牌 B，目标牌保留自己的牌位。")


func _finish_tarot(text: String) -> void:
	pending_tarot_spent = false
	pending_tarot_action = ""
	message_label.text = text
	print("[塔罗] ", text)
	_refresh()
	call_deferred("_show_intermission")


func _show_event() -> void:
	if event_used:
		return
	var content := _open_modal("塔罗事件", "选择一种预言。每幕可遭遇一次。", 620)
	content.add_child(MenuTheme.button("猜一张牌的花色  ·  猜中 +40 金币", _event_guess))
	content.add_child(MenuTheme.button("立即取走 20 金币", _event_take_twenty))
	content.add_child(MenuTheme.button("押注 1/4 机会获得 100 金币", _event_gamble))
	content.add_child(MenuTheme.button("选择两张牌  ·  1/2 概率摧毁", _event_destroy))
	content.add_child(MenuTheme.button("返回幕间", _show_intermission))


func _event_guess() -> void:
	var content := _open_modal("猜测牌面", "选择六种花色之一；各花色命中概率与牌组数量对应。", 560)
	for suit in FateRules.SUITS:
		content.add_child(MenuTheme.button(suit, _resolve_guess.bind(suit)))


func _resolve_guess(guess: String) -> void:
	var selected: String = master_deck[rng.randi_range(0, master_deck.size() - 1)].suit
	event_used = true
	if guess == selected:
		coins += 40
		message_label.text = "猜中了%s。获得 40 金币。" % selected
	else:
		message_label.text = "翻开的是%s。" % selected
	_close_modal()
	_show_intermission()
	_refresh()


func _event_take_twenty() -> void:
	event_used = true
	coins += 20
	message_label.text = "你选择了稳妥的 20 金币。"
	_close_modal()
	_show_intermission()
	_refresh()


func _event_gamble() -> void:
	event_used = true
	var won := rng.randi_range(1, 4) == 1
	if won:
		coins += 100
	message_label.text = "四分之一的奇迹成真：获得 100 金币！" if won else "赌注落空，没有获得金币。"
	_close_modal()
	_show_intermission()
	_refresh()


func _event_destroy() -> void:
	_select_deck_cards("选择两张牌参加命运赌局（日月不选）", 2, func(card: Dictionary) -> bool: return card.suit not in ["日", "月"], _resolve_destroy)


func _resolve_destroy(ids: Array[int]) -> void:
	event_used = true
	var destroyed := rng.randi_range(0, 1) == 0
	if destroyed:
		for id in ids:
			_remove_master_card(id)
	message_label.text = "赌局获胜：两张牌被命运吞噬。" if destroyed else "赌局失败：两张牌安然无恙。"
	_close_modal()
	_show_intermission()
	_refresh()


func _show_boss_coupon() -> void:
	current_phase = "coupon"
	var descriptions := {"命运珍藏": "最终命运之力倍率 +0.5（初始 ×1）。", "天启之刃": "永久获得 +20 基础值。", "额外占卜": "以后每幕 +1 次占卜。", "额外弃换": "以后每幕 +1 次弃换。", "星界手牌": "以后每幕手牌上限 +1。", "丰收契约": "立即获得 40 金币。", "塔罗储备": "立即获得 3 张塔罗。"}
	if boss_offers.is_empty():
		boss_offers.assign(REWARD_NAMES)
		for i in range(boss_offers.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var temporary: String = boss_offers[i]
			boss_offers[i] = boss_offers[j]
			boss_offers[j] = temporary
	var content := _open_modal("Boss 已击败  ·  选择一份优惠券", "选择一项永久祝福，然后挑选梦境牌。", 720)
	for i in range(3):
		var name: String = boss_offers[i]
		content.add_child(MenuTheme.button("%s\n%s" % [name, descriptions[name]], _claim_coupon.bind(name)))


func _claim_coupon(name: String) -> void:
	match name:
		"命运珍藏": permanent_power += 0.5
		"天启之刃": permanent_base += 20
		"额外占卜": vouchers["play"] = int(vouchers.get("play", 0)) + 1
		"额外弃换": vouchers["discard"] = int(vouchers.get("discard", 0)) + 1
		"星界手牌": vouchers["hand"] = int(vouchers.get("hand", 0)) + 1
		"丰收契约": coins += 40
		"塔罗储备": _add_tarot(3)
	boss_offers.clear()
	_close_modal()
	_show_dream_choice()


func _show_dream_choice() -> void:
	current_phase = "dream"
	var content := _open_modal("梦境牌", "选择一种终局改写。日月不受梦境的增删效果影响。", 720)
	content.add_child(MenuTheme.button("指定删除两张牌（不含日月）", _dream_delete))
	content.add_child(MenuTheme.button("选择两张牌，各复制一次（不含日月）", _dream_copy))
	content.add_child(MenuTheme.button("指定一张牌获得彩色", _dream_rainbow))
	content.add_child(MenuTheme.button("获得随机传奇命运石", _dream_stone))


func _dream_delete() -> void:
	_select_deck_cards("梦境：选择两张要删除的牌（不能选日/月）", 2, func(card: Dictionary) -> bool: return card.suit not in ["日", "月"], _resolve_dream_delete)


func _resolve_dream_delete(ids: Array[int]) -> void:
	for id in ids:
		_remove_master_card(id)
	_finish_dream("梦境删除了两张牌。")


func _dream_copy() -> void:
	_select_deck_cards("梦境：选择两张牌，各复制一次（不能选日/月）", 2, func(card: Dictionary) -> bool: return card.suit not in ["日", "月"], _resolve_dream_copy)


func _resolve_dream_copy(ids: Array[int]) -> void:
	for id in ids:
		_copy_master_card(id)
	_finish_dream("梦境复制了两张牌。")


func _dream_rainbow() -> void:
	_select_deck_cards("梦境：选择一张牌获得彩色", 1, func(_card: Dictionary) -> bool: return true, _resolve_dream_rainbow)


func _resolve_dream_rainbow(ids: Array[int]) -> void:
	_master_card(ids[0]).color = "彩"
	_sync_run_card(_master_card(ids[0]))
	_finish_dream("梦境使一张牌获得彩色。")


func _dream_stone() -> void:
	var stone := FateStones.draw_offers(rng, 1, true, _equipped_stone_ids())[0]
	if stones.size() < stone_slots:
		stones.append(stone)
		_finish_dream("梦境带来传奇命运石：%s。" % stone.name)
		return
	pending_offer = stone
	var content := _open_modal("梦境传奇命运石", "%s：%s\n选择一块命运石替换。" % [stone.name, stone.description], 700)
	for index in range(stones.size()):
		content.add_child(MenuTheme.button("替换 %s" % stones[index].name, _replace_stone_for_dream.bind(index)))


func _replace_stone_for_dream(index: int) -> void:
	var stone_name: String = pending_offer.get("name", "传奇命运石")
	stones[index] = pending_offer
	pending_offer = {}
	_finish_dream("获得 %s，并替换一块旧石。" % stone_name)


func _finish_dream(text: String) -> void:
	_close_modal()
	message_label.text = text
	_refresh()
	_show_victory()


func _show_victory() -> void:
	current_phase = "victory"
	var content := _open_modal("星盘归你所有", "完成四幕占卜，击败浩劫。\n牌组 %d 张  ·  最终金币 %d  ·  命运石 %d/%d" % [master_deck.size(), coins, stones.size(), stone_slots], 640)
	var continuation := MenuTheme.button("携带牌组与奖励，前往下一章", _continue_chapter)
	MenuTheme.primary(continuation)
	content.add_child(continuation)
	content.add_child(MenuTheme.button("再启一局", _retry_run))
	content.add_child(MenuTheme.button("返回主菜单", _return_to_menu))


func _continue_chapter() -> void:
	shop_used = false
	shop_offers.clear()
	event_used = false
	_enter_intermission()


func _retry_run() -> void:
	_close_modal()
	latest_result = {}
	_new_run()


func _show_stone_actions() -> void:
	var active: Array[Dictionary] = []
	for stone in stones:
		if stone.effect in ["active_delete", "active_copy"] and not bool(active_used.get(stone.id, false)):
			active.append(stone)
	var content := _open_modal("命运石功能", "主动命运石每幕可使用一次。", 600)
	if active.is_empty():
		content.add_child(MenuTheme.label("尚未装备可主动使用的命运石。", 15, MenuTheme.MUTED))
	else:
		for stone in active:
			content.add_child(MenuTheme.button("%s\n%s" % [stone.name, stone.description], _use_active_stone.bind(stone)))
	content.add_child(MenuTheme.button("关闭", _show_intermission if current_phase == "intermission" else _close_modal))


func _use_active_stone(stone: Dictionary) -> void:
	var effect: String = stone.effect
	if effect == "active_delete":
		_select_deck_cards("%s：选择一张要移除的牌（日/月不能移除）" % stone.name, 1, func(card: Dictionary) -> bool: return card.suit not in ["日", "月"], _resolve_active_delete.bind(stone.id))
	elif effect == "active_copy":
		_select_deck_cards("%s：选择一张要复制的牌（日月不选）" % stone.name, 1, func(card: Dictionary) -> bool: return card.suit not in ["日", "月"], _resolve_active_copy.bind(stone.id))


func _resolve_active_delete(ids: Array[int], stone_id: String) -> void:
	active_used[stone_id] = true
	_remove_master_card(ids[0])
	_close_modal()
	message_label.text = "命运石已移除一张牌。"
	if current_phase == "play" and hand.is_empty():
		_draw_cards(1)
		if hand.is_empty():
			_finish_stage(false)
	_refresh()
	if current_phase == "intermission":
		_show_intermission()


func _resolve_active_copy(ids: Array[int], stone_id: String) -> void:
	active_used[stone_id] = true
	_copy_master_card(ids[0])
	_close_modal()
	message_label.text = "命运石复制了一张牌。"
	_refresh()
	if current_phase == "intermission":
		_show_intermission()


func _inspect_stone(id: String) -> void:
	var stone := FateStones.by_id(id)
	_show_result(stone.get("name", "命运石"), stone.get("description", ""), "关闭", _resume_phase)


func _equipped_stone_ids() -> Array[String]:
	var ids: Array[String] = []
	for stone in stones:
		ids.append(stone.id)
	return ids


func _show_result(title: String, subtitle: String, button_text: String, callback: Callable, primary: bool = false) -> void:
	var content := _open_modal(title, subtitle, 620)
	var action := MenuTheme.button(button_text, callback)
	if primary:
		MenuTheme.primary(action)
	content.add_child(action)


func _open_modal(title: String, subtitle: String, width: float = 640) -> VBoxContainer:
	if not is_instance_valid(modal):
		previous_focus = get_viewport().gui_get_focus_owner()
	_close_modal(false)
	_set_page_focus_enabled(false)
	modal = Control.new()
	modal.name = "Modal"
	add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.035, 0.04, 0.86)
	modal.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	modal.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = minf(width, size.x - 36)
	panel.custom_minimum_size.y = minf(650, size.y - 70)
	panel.custom_maximum_size.y = size.y - 48
	center.add_child(panel)
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 20)
	panel.add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 13)
	margin.add_child(outer)
	outer.add_child(MenuTheme.label(title, 26))
	var detail := MenuTheme.label(subtitle, 14, MenuTheme.MUTED)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(detail)
	outer.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 100
	outer.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)
	call_deferred("_focus_modal")
	return content


func _set_page_focus_enabled(enabled: bool) -> void:
	card_row.set_interaction_enabled(enabled and current_phase == "play" and not stage_finished)
	for node in page.find_children("*", "Control", true, false):
		var control := node as Control
		if enabled:
			if control.has_meta("modal_focus_mode"):
				control.focus_mode = int(control.get_meta("modal_focus_mode"))
				control.remove_meta("modal_focus_mode")
		elif not control.has_meta("modal_focus_mode"):
			control.set_meta("modal_focus_mode", control.focus_mode)
			control.focus_mode = Control.FOCUS_NONE


func _focus_modal() -> void:
	if not is_instance_valid(modal):
		return
	var first_button: Button
	for node in modal.find_children("*", "Button", true, false):
		var button := node as Button
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if not button.disabled and not is_instance_valid(first_button):
			first_button = button
	if is_instance_valid(first_button):
		first_button.grab_focus()


func _disabled_option(text: String) -> Label:
	return MenuTheme.label(text, 13, MenuTheme.MUTED)


func _select_deck_cards(prompt: String, count: int, filter: Callable, callback: Callable) -> void:
	pending_ids.clear()
	pending_card_count = count
	pending_card_purpose = prompt
	pending_card_filter = filter
	pending_card_callback = callback
	_show_deck_picker()


func _show_deck_picker() -> void:
	var content := _open_modal("选择牌组", "%s  ·  已选 %d / %d" % [pending_card_purpose, pending_ids.size(), pending_card_count], 1060)
	content.add_child(MenuTheme.button("取消选择（Esc）", _cancel_card_selection))
	var grid := FlowContainer.new()
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.alignment = FlowContainer.ALIGNMENT_CENTER
	content.add_child(grid)
	for card: Dictionary in master_deck:
		var view := GameCard.new()
		view.setup(card, card.id in pending_ids)
		view.custom_minimum_size = Vector2(124, 170)
		view.disabled = not pending_card_filter.call(card) or card.id in pending_ids
		if view.disabled and card.id not in pending_ids:
			view.modulate = Color(0.55, 0.55, 0.55, 0.7)
		view.pressed.connect(_select_deck_card.bind(int(card.id)))
		grid.add_child(view)


func _select_deck_card(id: int) -> void:
	if pending_ids.has(id):
		return
	pending_ids.append(id)
	if pending_ids.size() >= pending_card_count:
		var ids := pending_ids.duplicate()
		var callback := pending_card_callback
		pending_ids.clear()
		pending_card_count = 0
		_close_modal()
		callback.call(ids)
	else:
		_show_deck_picker()


func _cancel_card_selection() -> void:
	pending_ids.clear()
	pending_card_count = 0
	if pending_tarot_spent:
		tarot_cards += 1
		tarot_inventory.append(pending_tarot_action)
		pending_tarot_spent = false
		pending_tarot_action = ""
	_close_modal()
	if current_phase == "intermission" or current_phase == "dream":
		_show_intermission() if current_phase == "intermission" else _show_dream_choice()
	else:
		_refresh()


func _eligible_deck_count(filter: Callable) -> int:
	var result := 0
	for card in master_deck:
		if filter.call(card):
			result += 1
	return result


func _master_card(id: int) -> Dictionary:
	for card in master_deck:
		if card.id == id:
			return card
	return {}


func _sync_run_card(master: Dictionary) -> void:
	for cards in [hand, draw_pile, discard_pile]:
		for index in range(cards.size()):
			if cards[index].id == master.id:
				cards[index] = master.duplicate(true)


func _sync_run_card_removed(id: int) -> void:
	for cards in [hand, draw_pile, discard_pile]:
		for index in range(cards.size() - 1, -1, -1):
			if cards[index].id == id:
				cards.remove_at(index)
	selected_ids.erase(id)


func _copy_master_card(id: int) -> void:
	var source := _master_card(id).duplicate(true)
	if source.is_empty() or source.suit in ["日", "月"]:
		return
	source.id = _next_card_id()
	source.copies = int(source.get("copies", 0)) + 1
	master_deck.append(source)
	if current_phase == "play":
		draw_pile.push_front(source.duplicate(true))
	_grow_deck_stones("grow_add_mult")


func _next_card_id() -> int:
	var highest := -1
	for card in master_deck:
		highest = maxi(highest, int(card.id))
	return highest + 1


func _pause_game() -> void:
	var content := _open_modal("占卜暂停", "本幕占卜状态会在离开时结束。", 540)
	content.add_child(MenuTheme.button("继续占卜", _resume_phase))
	content.add_child(MenuTheme.button("放弃本局并返回菜单", _return_to_menu))


func _confirm_leave() -> void:
	var content := _open_modal("离开本局？", "返回主菜单会结束当前牌局。", 540)
	content.add_child(MenuTheme.button("继续占卜", _resume_phase))
	content.add_child(MenuTheme.button("结束牌局并返回", _return_to_menu))


func _return_to_menu() -> void:
	var error := get_tree().change_scene_to_file("res://control.tscn")
	if error != OK:
		push_error("返回主菜单失败：%s" % error_string(error))


func _close_modal(restore_focus: bool = true) -> void:
	if is_instance_valid(modal):
		modal.hide()
		modal.queue_free()
		modal = null
	_set_page_focus_enabled(true)
	if restore_focus and is_instance_valid(previous_focus) and previous_focus.is_inside_tree() and previous_focus.is_visible_in_tree() and previous_focus.focus_mode != Control.FOCUS_NONE:
		previous_focus.grab_focus()


func _resume_phase() -> void:
	if pending_tarot_spent or pending_card_count > 0:
		_cancel_card_selection()
		return
	match current_phase:
		"intermission": _show_intermission()
		"round_result": _show_stage_result()
		"coupon": _show_boss_coupon()
		"dream": _show_dream_choice()
		"victory": _show_victory()
		_: _close_modal()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("ui_cancel"):
		if is_instance_valid(modal):
			_resume_phase()
		else:
			_pause_game()
		get_viewport().set_input_as_handled()
