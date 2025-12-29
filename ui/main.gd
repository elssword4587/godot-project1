extends Control

@onready var avatar = $Margin/HSplit/MapPanel/Avatar
@onready var markers_root = $Margin/HSplit/MapPanel/Markers
@onready var npc_list = $Margin/HSplit/RightPanel/VBox/Tabs/Location/NPCList
@onready var location_label = $Margin/HSplit/RightPanel/VBox/Tabs/Location/LocationLabel
@onready var stats_label = $Margin/HSplit/RightPanel/VBox/Tabs/Character/Stats
@onready var inventory_list = $Margin/HSplit/RightPanel/VBox/Tabs/Inventory/InventoryList
@onready var log_list = $Margin/HSplit/RightPanel/VBox/Tabs/Log/LogList
@onready var time_label = $Margin/HSplit/RightPanel/VBox/Footer/TimeLabel
@onready var map_texture = $Margin/HSplit/MapPanel/MapTexture

func _ready():
    GameState.connect("log_updated", Callable(self, "_on_log"))
    GameState.connect("inventory_updated", Callable(self, "_refresh_inventory"))
    GameState.connect("stats_updated", Callable(self, "_refresh_stats"))
    GameState.connect("travel_started", Callable(self, "_on_travel_started"))
    GameState.connect("travel_arrived", Callable(self, "_on_travel_arrived"))
    _apply_placeholder_map_texture()
    _bind_buttons()
    _build_location_markers()
    _refresh_stats()
    _refresh_inventory()
    _refresh_location_panel(GameState.current_location_id)
    GameState.load_game()

func _process(delta):
    GameState.process_tick(delta)
    _update_avatar_position()
    var needs := GameState.player.get("needs", {})
    time_label.text = "Intent: %d | Mood %.1f" % [GameState.intent_queue.size(), needs.get("mood",0.0)]

func _bind_buttons():
    $Margin/HSplit/RightPanel/VBox/TimeBar/Play.pressed.connect(func(): GameState.set_time_scale(1.0))
    $Margin/HSplit/RightPanel/VBox/TimeBar/Double.pressed.connect(func(): GameState.set_time_scale(2.0))
    $Margin/HSplit/RightPanel/VBox/TimeBar/Quad.pressed.connect(func(): GameState.set_time_scale(4.0))
    $Margin/HSplit/RightPanel/VBox/TimeBar/Pause.pressed.connect(func(): GameState.set_time_scale(0.0))
    var cmd_root = $Margin/HSplit/RightPanel/VBox/Tabs/Command/CommandButtons
    cmd_root.get_node("TravelBtn").pressed.connect(_queue_travel)
    cmd_root.get_node("HuntBtn").pressed.connect(func(): GameState.enqueue_intent("hunt"))
    cmd_root.get_node("GatherBtn").pressed.connect(func(): GameState.enqueue_intent("gather"))
    cmd_root.get_node("MineBtn").pressed.connect(func(): GameState.enqueue_intent("mine"))
    cmd_root.get_node("RestBtn").pressed.connect(func(): GameState.enqueue_intent("rest"))
    cmd_root.get_node("CraftBtn").pressed.connect(func(): GameState.enqueue_intent("craft"))
    cmd_root.get_node("ShopBtn").pressed.connect(func(): GameState.enqueue_intent("shop"))
    cmd_root.get_node("QuestBtn").pressed.connect(func(): GameState.enqueue_intent("quest"))
    $Margin/HSplit/RightPanel/VBox/Footer/SaveBtn.pressed.connect(GameState.save_game)
    $Margin/HSplit/RightPanel/VBox/Footer/LoadBtn.pressed.connect(GameState.load_game)
    $Margin/HSplit/RightPanel/VBox/Footer/BlessingBtn.pressed.connect(func(): GameState.enqueue_intent("blessing", {"id": "fortune"}))
    npc_list.item_selected.connect(_on_npc_selected)

func _queue_travel():
    var locs = LocationDB.all_locations()
    locs.shuffle()
    if locs.size() > 0:
        GameState.enqueue_intent("travel", {"target": locs[0].get("id")})

func _build_location_markers():
    for child in markers_root.get_children():
        child.queue_free()
    for loc in LocationDB.all_locations():
        var btn = Button.new()
        btn.text = loc.get("name")
        btn.size_flags_horizontal = 0
        btn.size_flags_vertical = 0
        btn.pressed.connect(func(id=loc.get("id")): GameState.enqueue_intent("travel", {"target": id}))
        markers_root.add_child(btn)
        btn.position = _map_to_local(loc.get("pos")) - Vector2(btn.size.x/2, btn.size.y/2)

func _update_avatar_position():
    avatar.position = _map_to_local(GameState.current_location().get("pos", [0.5,0.5])) - avatar.size/2
    if GameState.target_location_id != "":
        avatar.color = Color(0.9,0.6,0.1)
    else:
        avatar.color = Color(0.9,0.15,0.15)

func _map_to_local(pos_array: Array) -> Vector2:
    var rect = map_texture.get_global_rect()
    var x = rect.position.x + rect.size.x * pos_array[0]
    var y = rect.position.y + rect.size.y * pos_array[1]
    return Vector2(x,y) - map_texture.global_position

func _apply_placeholder_map_texture():
    var map_path = "res://map.png"
    if ResourceLoader.exists(map_path, "Texture2D"):
        var tex = ResourceLoader.load(map_path)
        if tex is Texture2D:
            map_texture.texture = tex
            return
    var gradient = Gradient.new()
    gradient.colors = PackedColorArray([
        Color(0.09, 0.15, 0.26),
        Color(0.12, 0.32, 0.24),
        Color(0.28, 0.25, 0.18)
    ])
    gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
    var tex = GradientTexture2D.new()
    tex.gradient = gradient
    tex.width = 1280
    tex.height = 720
    tex.fill = GradientTexture2D.FILL_LINEAR
    map_texture.texture = tex

func _refresh_inventory():
    inventory_list.clear()
    for item in GameState.player.get("inventory", []):
        inventory_list.add_item("%s (%s)" % [item.get("name"), item.get("type")])

func _refresh_stats():
    var p = GameState.player
    var needs = p.get("needs", {})
    stats_label.text = "[b]%s[/b]\nLV %d XP %d\nGold: %d DP: %d\nHP %.1f/%.1f Stamina %.1f Mood %.1f\nHunger %.1f Fatigue %.1f\nTraits: %s" % [p.get("name",""), p.get("level",1), p.get("xp",0), p.get("gold",0), p.get("divine_power",0), needs.get("hp",0.0), p.get("stats", {}).get("max_hp", 0), needs.get("stamina",0.0), needs.get("mood",0.0), needs.get("hunger",0.0), needs.get("fatigue",0.0), ", ".join(p.get("traits", []))]

func _refresh_location_panel(loc_id: String):
    var loc = LocationDB.get_location(loc_id)
    location_label.text = "At %s (%s)" % [loc.get("name"), loc.get("type")]
    npc_list.clear()
    for npc in loc.get("npcs", []):
        npc_list.add_item(npc.capitalize())

func _on_log(message: String):
    log_list.add_item(message)
    log_list.ensure_current_is_visible()

func _on_travel_started(target_id: String):
    _refresh_location_panel(GameState.current_location_id)

func _on_travel_arrived(location_id: String):
    _refresh_location_panel(location_id)

func _on_npc_selected(index: int):
    var npc_name = npc_list.get_item_text(index)
    match npc_name.to_lower():
        "inn":
            GameState.enqueue_intent("rest")
        "blacksmith":
            GameState.enqueue_intent("craft")
        "quest_guild":
            GameState.enqueue_intent("quest")
        "general_store", "weaponsmith", "armorer", "stable", "alchemist":
            GameState.enqueue_intent("shop")
        _:
            GameState.enqueue_intent("rest")
