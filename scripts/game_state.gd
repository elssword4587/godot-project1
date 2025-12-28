extends Node

var player = {
    "name": "Nameless",
    "level": 1,
    "xp": 0,
    "gold": 50,
    "divine_power": 20,
    "traits": [],
    "stats": {"atk":5, "def":3, "max_hp":30, "crit":0.05, "block":0.02, "speed":1.0},
    "needs": {"hunger":10.0, "fatigue":10.0, "stamina":30.0, "hp":30.0, "mood":5.0},
    "inventory": [],
    "equipment": {},
    "active_blessings": []
}
var current_location_id : String = "lustel"
var target_location_id : String = ""
var travel_time := 0.0
var travel_elapsed := 0.0
var intent_queue : Array = []
var log_messages : Array = []
var time_scale := 1.0
var accum := 0.0
var last_save_time := 0.0

signal log_updated(message: String)
signal inventory_updated
signal stats_updated
signal travel_started(target_id: String)
signal travel_arrived(location_id: String)

func _ready():
    randomize()
    if player.get("traits", []).is_empty():
        player["traits"] = TraitDB.random_trait_ids(2)
    _apply_trait_mods()
    add_to_log("Awakening in the Pandemos Empire.")

func _apply_trait_mods():
    for trait_id in player.get("traits", []):
        var trait = TraitDB.get_trait(trait_id)
        var mods = trait.get("mods", {})
        for key in mods.keys():
            if key in player.get("stats", {}):
                player["stats"][key] += mods[key]
        player["needs"]["mood"] = player.get("needs", {}).get("mood", 0) + mods.get("mood", 0)

func _get_blessing_mods() -> Dictionary:
    var mods := {
        "atk": 0,
        "def": 0,
        "crit": 0.0,
        "block": 0.0,
        "speed_mult": 1.0,
        "gold_mult": 1.0,
        "xp_mult": 1.0,
        "fatigue_mult": 1.0,
        "travel_bonus": 0.0,
        "craft_bonus": 0.0,
        "mood_bonus": 0.0
    }
    for bless in player.get("active_blessings", []):
        var data = bless.get("mods", {})
        mods["atk"] += data.get("atk", 0)
        mods["def"] += data.get("def", 0)
        mods["crit"] += data.get("crit", 0.0)
        mods["block"] += data.get("block", 0.0)
        mods["speed_mult"] *= data.get("speed", 1.0)
        mods["gold_mult"] *= data.get("gold_mult", 1.0)
        mods["xp_mult"] *= data.get("xp_mult", 1.0)
        mods["fatigue_mult"] *= data.get("fatigue_mult", 1.0)
        mods["travel_bonus"] += data.get("travel_bonus", 0.0)
        mods["craft_bonus"] += data.get("craft_bonus", 0.0)
        mods["mood_bonus"] += data.get("mood", 0.0)
    return mods

func set_time_scale(scale: float):
    time_scale = scale

func enqueue_intent(action: String, data := {}):
    intent_queue.append({"action": action, "data": data})
    add_to_log("Queued intent: %s" % action)

func process_tick(delta: float):
    if time_scale <= 0:
        return
    delta *= time_scale
    accum += delta
    while accum >= 1.0:
        accum -= 1.0
        _tick_one_second()

func _tick_one_second():
    _update_needs()
    _process_blessings()
    if target_location_id != "":
        _process_travel()
    elif not intent_queue.is_empty():
        _process_intent_queue()
    else:
        _autopilot_choose_action()

func _update_needs():
    var blessing_mods = _get_blessing_mods()
    var hunger_increase = 0.05 * _need_multiplier("hunger")
    var fatigue_increase = 0.04 * _need_multiplier("fatigue")
    player["needs"]["hunger"] = clamp(player.get("needs", {}).get("hunger", 0.0) + hunger_increase, 0.0, 100.0)
    player["needs"]["fatigue"] = clamp(player.get("needs", {}).get("fatigue", 0.0) + fatigue_increase, 0.0, 100.0)
    player["needs"]["stamina"] = clamp(player.get("needs", {}).get("stamina", 0.0) - 0.3, 0.0, 100.0)
    if player.get("needs", {}).get("stamina", 0.0) <= 0:
        player["needs"]["hp"] = max(1.0, player.get("needs", {}).get("hp", 0.0) - 0.5)
    player["needs"]["mood"] = clamp(player.get("needs", {}).get("mood", 0.0) - (player.get("needs", {}).get("hunger",0.0)/200.0) - (player.get("needs", {}).get("fatigue",0.0)/200.0) + 0.01 + blessing_mods.get("mood_bonus", 0.0), -10, 20)
    if player.get("needs", {}).get("hp",0.0) < player.get("stats", {}).get("max_hp", 0):
        player["needs"]["hp"] = clamp(player.get("needs", {}).get("hp",0.0) + 0.05, 0.0, player.get("stats", {}).get("max_hp", 0))
    emit_signal("stats_updated")

func _need_multiplier(kind: String) -> float:
    var mult := 1.0
    for trait_id in player.get("traits", []):
        var t = TraitDB.get_trait(trait_id)
        mult *= t.get("mods", {}).get(kind+"_mult", 1.0)
    for bless in player.get("active_blessings", []):
        mult *= bless.get("mods", {}).get(kind+"_mult", 1.0)
    return max(mult, 0.1)

func _process_blessings():
    for b in player.get("active_blessings", []):
        b.duration -= 1
    player["active_blessings"] = player.get("active_blessings", []).filter(func(b): return b.duration > 0)

func _process_travel():
    travel_elapsed += 1.0
    var speed_mult = player.get("stats", {}).get("speed", 1.0)
    for trait_id in player.get("traits", []):
        speed_mult *= TraitDB.get_trait(trait_id).get("mods",{}).get("speed",1.0)
    var blessing_mods = _get_blessing_mods()
    speed_mult *= blessing_mods.get("speed_mult", 1.0)
    speed_mult *= 1.0 + blessing_mods.get("travel_bonus", 0.0)
    for item in player.get("inventory", []):
        if item.get("type","") == "mount":
            speed_mult *= item.get("mount_speed",1.0)
    var fatigue_penalty = 1.0 - (player.get("needs", {}).get("fatigue",0.0)/200.0)
    var hunger_penalty = 1.0 - (player.get("needs", {}).get("hunger",0.0)/200.0)
    speed_mult *= max(0.5, fatigue_penalty*hunger_penalty)
    if _roll_random_event():
        player["gold"] = player.get("gold",0) + int(2 * blessing_mods.get("gold_mult", 1.0))
        add_to_log("Found coins while traveling.")
    if travel_elapsed * speed_mult >= travel_time:
        current_location_id = target_location_id
        target_location_id = ""
        travel_elapsed = 0
        add_to_log("Arrived at %s" % LocationDB.get_location(current_location_id).get("name","?"))
        emit_signal("travel_arrived", current_location_id)
        _on_arrival_behaviors()
    emit_signal("stats_updated")

func _roll_random_event() -> bool:
    return randi() % 20 == 0

func _process_intent_queue():
    var intent = intent_queue.pop_front()
    if _will_refuse():
        add_to_log("Refused intent %s" % intent.get("action"))
        _autopilot_choose_action()
        return
    _execute_intent(intent)

func _will_refuse() -> bool:
    var base := 0.05
    for trait_id in player.get("traits", []):
        base += TraitDB.get_trait(trait_id).get("behavior",{}).get("refusal_chance",0.0)
    if player.get("needs", {}).get("mood",0.0) < 0:
        base += 0.1
    return randf() < min(base,0.9)

func _execute_intent(intent: Dictionary):
    var action = intent.get("action", "")
    match action:
        "travel":
            _begin_travel(intent.get("data",{}).get("target",""))
        "hunt":
            _do_hunt()
        "gather":
            _do_gather()
        "mine":
            _do_mine()
        "rest":
            _do_rest()
        "shop":
            _do_shop()
        "craft":
            _do_craft()
        "quest":
            _do_quest()
        "blessing":
            _do_blessing(intent.get("data",{}).get("id",""))
        _:
            add_to_log("No idea how to %s" % action)

func _begin_travel(target_id: String):
    if target_id == "":
        return
    if target_id == current_location_id:
        add_to_log("Already at target")
        return
    var current = LocationDB.get_location(current_location_id)
    var target = LocationDB.get_location(target_id)
    if target.is_empty():
        add_to_log("Unknown destination")
        return
    var dx = current.get("pos")[0]-target.get("pos")[0]
    var dy = current.get("pos")[1]-target.get("pos")[1]
    var distance = sqrt(dx*dx+dy*dy)
    travel_time = max(5.0, distance*200.0)
    travel_elapsed = 0.0
    target_location_id = target_id
    add_to_log("Traveling to %s (%.1fs)" % [target.get("name","?"), travel_time])
    emit_signal("travel_started", target_id)

func _autopilot_choose_action():
    # Decide simple priority order
    if player.get("needs", {}).get("hunger",0.0) > 70:
        _consume_food()
        return
    if player.get("needs", {}).get("fatigue",0.0) > 70:
        _do_rest()
        return
    if player.get("needs", {}).get("hp",0.0) < player.get("stats", {}).get("max_hp", 1) * 0.5:
        _do_heal()
        return
    if randi()%3 == 0:
        _do_hunt()
    elif randi()%3 == 1:
        _do_gather()
    else:
        _do_shop()

func _consume_food():
    for item in player.get("inventory", []):
        if item.get("type") in ["consumable","potion"]:
            var effect = item.get("effect",{})
            player["needs"]["hunger"] = clamp(player.get("needs", {}).get("hunger",0.0) + effect.get("hunger", -10),0,100)
            player["needs"]["stamina"] = clamp(player.get("needs", {}).get("stamina",0.0) + effect.get("stamina",5),0,100)
            player["needs"]["hp"] = clamp(player.get("needs", {}).get("hp",0.0) + effect.get("heal",0),0,player.get("stats", {}).get("max_hp", 0))
            player.get("inventory", []).erase(item)
            add_to_log("Auto-consumed %s" % item.get("name"))
            emit_signal("inventory_updated")
            return
    add_to_log("No food to consume.")

func _do_rest():
    player["needs"]["fatigue"] = max(0.0, player.get("needs", {}).get("fatigue",0.0) - 30.0)
    player["needs"]["stamina"] = min(100.0, player.get("needs", {}).get("stamina",0.0) + 30.0)
    player["needs"]["mood"] = player.get("needs", {}).get("mood",0.0) + 2
    add_to_log("Rested for a while.")

func _do_heal():
    player["needs"]["hp"] = min(player.get("stats", {}).get("max_hp", 0), player.get("needs", {}).get("hp",0.0) + 10)
    add_to_log("Bandaged wounds.")

func _do_hunt():
    var reward = 8 + randi()%6
    var blessing_mods = _get_blessing_mods()
    reward = int(reward * blessing_mods.get("gold_mult", 1.0))
    player["gold"] = player.get("gold",0) + reward
    player["needs"]["stamina"] = max(0.0, player.get("needs", {}).get("stamina",0.0) - 10)
    player["needs"]["fatigue"] = player.get("needs", {}).get("fatigue",0.0) + 8 * blessing_mods.get("fatigue_mult", 1.0)
    add_to_log("Hunted creatures, earned %d gold." % reward)

func _do_gather():
    var blessing_mods = _get_blessing_mods()
    var reward = ItemDB.random_item_by_type("material")
    if not reward.is_empty():
        player.get("inventory", []).append(reward)
        emit_signal("inventory_updated")
        add_to_log("Gathered %s." % reward.get("name"))
    player["needs"]["fatigue"] = player.get("needs", {}).get("fatigue",0.0) + 6 * blessing_mods.get("fatigue_mult", 1.0)

func _do_mine():
    var blessing_mods = _get_blessing_mods()
    var reward = ItemDB.random_item_by_type("material")
    if not reward.is_empty():
        player.get("inventory", []).append(reward)
        emit_signal("inventory_updated")
        add_to_log("Mined ore %s." % reward.get("name"))
    player["needs"]["fatigue"] = player.get("needs", {}).get("fatigue",0.0) + 8 * blessing_mods.get("fatigue_mult", 1.0)

func _do_shop():
    var city = LocationDB.get_location(current_location_id)
    if city.get("type") != "city":
        add_to_log("Need a city to shop.")
        return
    var bias = "balanced"
    for t in player.get("traits", []):
        bias = TraitDB.get_trait(t).get("behavior",{}).get("shop_bias",bias)
    var purchase = ItemDB.random_item_by_type("consumable")
    if bias == "greedy":
        purchase = ItemDB.random_item_by_type("weapon")
    if purchase.is_empty():
        add_to_log("Shop had nothing appealing.")
        return
    var price = purchase.get("price",10)
    if player.get("gold",0) >= price:
        player["gold"] = player.get("gold",0) - price
        player.get("inventory", []).append(purchase)
        emit_signal("inventory_updated")
        add_to_log("Bought %s for %d gold." % [purchase.get("name"), price])
    else:
        add_to_log("Not enough gold to shop.")

func _do_craft():
    var blessing_mods = _get_blessing_mods()
    if player.get("inventory", []).size() < 2:
        add_to_log("No materials to craft.")
        return
    var failure_chance = max(0.0, 0.2 - blessing_mods.get("craft_bonus", 0.0))
    var success = randf() > failure_chance
    for t in player.get("traits", []):
        if TraitDB.get_trait(t).get("behavior",{}).get("craft_bias","") == "material":
            success = randf() > 0.1
    if success:
        var crafted = ItemDB.random_item_by_type("weapon")
        if crafted.is_empty():
            crafted = ItemDB.random_item_by_type("armor")
        if not crafted.is_empty():
            player.get("inventory", []).append(crafted)
            add_to_log("Crafted %s." % crafted.get("name"))
            emit_signal("inventory_updated")
    else:
        add_to_log("Crafting failed, materials wasted.")
        if not player.get("inventory", []).is_empty():
            player.get("inventory", []).pop_front()

func _do_quest():
    var blessing_mods = _get_blessing_mods()
    var xp_gain = 10 + randi()%10
    xp_gain = int(round(xp_gain * blessing_mods.get("xp_mult", 1.0)))
    player["xp"] = player.get("xp",0) + xp_gain
    add_to_log("Completed a minor quest for %d XP." % xp_gain)
    if player.get("xp",0) > player.get("level",1) * 50:
        player["level"] = player.get("level",1) + 1
        player["stats"]["max_hp"] = player.get("stats", {}).get("max_hp", 0) + 5
        add_to_log("Level up to %d!" % player.get("level",1))

func _do_blessing(id: String):
    var bless = BlessingDB.get_blessing(id)
    if bless.is_empty():
        add_to_log("Unknown blessing.")
        return
    var cost = bless.get("cost",0)
    if player.get("divine_power",0) < cost:
        add_to_log("Not enough divine power.")
        return
    player["divine_power"] = player.get("divine_power",0) - cost
    var data = bless.duplicate(true)
    data.duration = bless.get("duration",60)
    player.get("active_blessings", []).append(data)
    add_to_log("Invoked %s blessing." % bless.get("name"))

func _on_arrival_behaviors():
    var loc = LocationDB.get_location(current_location_id)
    if loc.get("type") == "city":
        add_to_log("The city's services are available.")
    else:
        add_to_log("Exploring the wilds of %s." % loc.get("name"))

func add_to_log(text: String):
    var time_str = Time.get_datetime_string_from_unix_time(Time.get_unix_time_from_system()).right(8)
    var final_text = "%s | %s" % [time_str, text]
    log_messages.append(final_text)
    if log_messages.size() > 200:
        log_messages.pop_front()
    emit_signal("log_updated", final_text)

func save_game():
    var save_data = {
        "player": player,
        "current_location_id": current_location_id,
        "target_location_id": target_location_id,
        "travel_time": travel_time,
        "travel_elapsed": travel_elapsed,
        "intent_queue": intent_queue,
        "last_save_time": Time.get_unix_time_from_system()
    }
    var file = FileAccess.open("user://save.json", FileAccess.WRITE)
    file.store_string(JSON.stringify(save_data))
    add_to_log("Game saved.")

func load_game():
    if not FileAccess.file_exists("user://save.json"):
        return
    var file = FileAccess.open("user://save.json", FileAccess.READ)
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) == TYPE_DICTIONARY:
        player = parsed.get("player", player)
        current_location_id = parsed.get("current_location_id", current_location_id)
        target_location_id = parsed.get("target_location_id", "")
        travel_time = parsed.get("travel_time", 0.0)
        travel_elapsed = parsed.get("travel_elapsed", 0.0)
        intent_queue = parsed.get("intent_queue", [])
        last_save_time = parsed.get("last_save_time", Time.get_unix_time_from_system())
        _simulate_offline(Time.get_unix_time_from_system() - last_save_time)
        add_to_log("Game loaded.")

func _simulate_offline(seconds: float):
    var clamped = min(seconds, 8*3600)
    for i in range(int(clamped)):
        _tick_one_second()

func current_location() -> Dictionary:
    return LocationDB.get_location(current_location_id)
