extends Node

var locations := {}

func _ready():
    load_locations()

func load_locations():
    var file := FileAccess.open("res://data/locations.json", FileAccess.READ)
    if file:
        locations.clear()
        var arr = JSON.parse_string(file.get_as_text())
        if typeof(arr) == TYPE_ARRAY:
            for loc in arr:
                locations[loc.get("id","" )] = loc

func get_location(id:String) -> Dictionary:
    return locations.get(id,{})

func all_locations() -> Array:
    return locations.values()
