class_name FateStones
extends RefCounted
## The stone catalogue is data driven; effects are interpreted by the run.

const RARITIES := ["普通", "稀有", "传奇"]


static func catalogue() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for suit in FateRules.SUITS:
		var clean: String = suit.replace("空", "")
		result.append(_stone("suit_%s_base" % suit, "%s刻印" % clean, "每打出一张%s，基础值 +3。" % suit, "suit_base", 3.0, suit, "牌面", "普通"))
		result.append(_stone("suit_%s_power" % suit, "%s祝福" % clean, "每打出一张%s，命运之力 +0.25。" % suit, "suit_power", 0.25, suit, "牌面", "稀有"))
		result.append(_stone("suit_%s_mult" % suit, "%s星核" % clean, "每打出一张%s，命运之力 ×1.5。" % suit, "suit_multiplier", 1.5, suit, "牌面", "传奇"))
	for color in ["黑", "蓝", "绿", "金", "银"]:
		result.append(_stone("color_%s_base" % color, "%s棱镜" % color, "每打出一张%s色牌，基础值 +3。" % color, "color_base", 3.0, color, "色彩", "普通"))
		result.append(_stone("color_%s_power" % color, "%s辉光" % color, "每打出一张%s色牌，命运之力 +0.25。" % color, "color_power", 0.25, color, "色彩", "稀有"))
		result.append(_stone("color_%s_mult" % color, "%s核心" % color, "每打出一张%s色牌，命运之力 ×1.5。" % color, "color_multiplier", 1.5, color, "色彩", "传奇"))
	for rank in FateRules.RANKS:
		var name: String = FateRules.RANK_NAMES[rank]
		result.append(_stone("rank_%s_base" % rank, "%s铭文" % name, "%s的基础值 +15。" % name, "rank_base", 15.0, rank, "牌型", "普通"))
		result.append(_stone("rank_%s_power" % rank, "%s预言" % name, "%s的命运之力 +0.5。" % name, "rank_power", 0.5, rank, "牌型", "稀有"))
		result.append(_stone("rank_%s_mult" % rank, "%s至高环" % name, "%s的命运之力 ×2。" % name, "rank_multiplier", 2.0, rank, "牌型", "传奇"))
	result.append(_stone("growth_play_base", "行旅之痕", "每次占卜永久增加 +2 基础值。", "grow_play_base", 2.0, "", "成长", "普通"))
	result.append(_stone("growth_play_power", "升星之痕", "每次占卜，命运之力永久 +0.1。", "grow_play_power", 0.1, "", "成长", "稀有"))
	result.append(_stone("growth_play_mult", "连祷之环", "每次占卜后，此石的命运倍率 ×1.10。", "grow_play_mult", 1.10, "", "成长", "传奇"))
	result.append(_stone("growth_round_base", "昼夜刻度", "每幕开始，基础值永久 +8。", "grow_round_base", 8.0, "", "成长", "普通"))
	result.append(_stone("growth_round_power", "命运刻度", "每幕开始，此石积累 +0.2 命运之力。", "grow_round_power", 0.2, "", "成长", "稀有"))
	result.append(_stone("growth_round_mult", "轮回沙漏", "每幕开始，此石的命运倍率 ×1.25。", "grow_round_mult", 1.25, "", "成长", "传奇"))
	result.append(_stone("growth_add_mult", "繁生星核", "每增加一张牌，此石的命运倍率 ×1.10。", "grow_add_mult", 1.10, "", "成长", "稀有"))
	result.append(_stone("growth_delete_mult", "空缺星核", "每移除一张牌，此石的命运倍率 ×1.15。", "grow_delete_mult", 1.15, "", "成长", "稀有"))
	result.append(_stone("growth_hand_bonus", "星盘扩张", "每次占卜额外获得 2 点基础值。", "round_base", 2.0, "", "成长", "普通"))
	result.append(_stone("money_play", "金币骰子", "每次占卜获得 5 金币。", "play_coins", 5.0, "", "经济", "稀有"))
	result.append(_stone("money_round", "丰收契约", "每幕结束获得 12 金币。", "round_coins", 12.0, "", "经济", "稀有"))
	result.append(_stone("repeat_stars", "双星仪", "星空牌的每次牌面触发额外重复一次。", "repeat_stars", 1.0, "", "重复", "稀有"))
	result.append(_stone("repeat_card", "回声匣", "每张牌的牌面效果重复一次。", "repeat_card", 1.0, "", "重复", "传奇"))
	result.append(_stone("repeat_last_card", "终章回声", "每次出牌的最后一张牌额外触发一次。", "repeat_last_card", 1.0, "", "重复", "稀有"))
	result.append(_stone("repeat_rare", "稀色共鸣", "金、银、彩色牌的效果重复一次。", "repeat_rare", 1.0, "", "重复", "传奇"))
	result.append(_stone("repeat_last_play", "压轴时刻", "本幕最后一次占卜的牌面效果重复一次。", "repeat_last_play", 1.0, "", "重复", "传奇"))
	result.append(_stone("utility_hand", "宽阔星图", "手牌上限 +1。", "hand_limit", 1.0, "", "功能", "普通"))
	result.append(_stone("utility_redraw", "潮汐之眼", "每次弃换牌上限 +1。", "draw_limit", 1.0, "", "功能", "普通"))
	result.append(_stone("utility_play", "额外启示", "每幕额外获得一次占卜。", "extra_play", 1.0, "", "功能", "稀有"))
	result.append(_stone("utility_discard", "余烬炉", "每幕额外获得一次弃换牌。", "extra_discard", 1.0, "", "功能", "普通"))
	result.append(_stone("utility_force_sun", "太阳罗盘", "每幕开始时必定抽到一张日牌。", "force_suit", 1.0, "日", "功能", "稀有"))
	result.append(_stone("utility_level", "命数签", "每次占卜有 25% 概率使当前牌型升一级。", "level_chance", 0.25, "", "功能", "稀有"))
	result.append(_stone("utility_delete", "断因石", "每幕可主动从牌组移除一张非日月牌。", "active_delete", 1.0, "", "功能", "传奇"))
	result.append(_stone("utility_copy", "复相石", "每幕可复制一张非日月牌。", "active_copy", 1.0, "", "功能", "传奇"))
	result.append(_stone("utility_play_delete", "虚无之口", "出牌后永久删除打出的非日月牌。", "play_delete", 1.0, "", "功能", "稀有"))
	result.append(_stone("utility_play_copy", "映照之镜", "出牌后复制打出的非日月牌，加入本幕牌库。", "play_copy", 1.0, "", "功能", "传奇"))
	return result


static func by_id(id: String) -> Dictionary:
	for stone in catalogue():
		if stone.id == id:
			return stone
	return {}


static func draw_offers(rng: RandomNumberGenerator, count: int = 3, legendary: bool = false, excluded_ids: Array[String] = []) -> Array[Dictionary]:
	var pool := catalogue()
	pool = pool.filter(func(stone: Dictionary) -> bool: return stone.id not in excluded_ids)
	if legendary:
		pool = pool.filter(func(stone: Dictionary) -> bool: return stone.rarity == "传奇")
	var result: Array[Dictionary] = []
	while not pool.is_empty() and result.size() < count:
		var index := rng.randi_range(0, pool.size() - 1)
		result.append(pool.pop_at(index))
	return result


static func _stone(id: String, name: String, description: String, effect: String, amount: float, target: String, family: String, rarity: String) -> Dictionary:
	return {"id": id, "name": name, "description": description, "effect": effect, "amount": amount, "target": target, "family": family, "rarity": rarity, "cost": 20 if rarity == "传奇" else (15 if rarity == "稀有" else 12)}
