extends Node

var blessings := {}

func _ready():
    _load_defaults()

func _load_defaults():
    blessings = {
        "fortune": {"name":"Fortune","cost":10,"duration":120,"mods":{"luck":1.2,"gold_mult":1.3}},
        "wrath": {"name":"Wrath","cost":12,"duration":90,"mods":{"atk":5,"crit":0.05}},
        "bulwark": {"name":"Bulwark","cost":8,"duration":180,"mods":{"def":5,"block":0.1}},
        "serenity": {"name":"Serenity","cost":6,"duration":150,"mods":{"mood":5,"fatigue_mult":0.8}},
        "haste": {"name":"Haste","cost":9,"duration":120,"mods":{"speed":1.2,"travel_bonus":0.2}},
        "prosperity": {"name":"Prosperity","cost":11,"duration":150,"mods":{"xp_mult":1.2,"craft_bonus":0.1}}
    }

func get_blessing(id:String) -> Dictionary:
    return blessings.get(id,{})
