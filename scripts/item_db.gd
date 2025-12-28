extends Node

var items := {}

func _ready():
    load_items()

func load_items():
    var file := FileAccess.open("res://data/items.json", FileAccess.READ)
    if file:
        items.clear()
        var arr = JSON.parse_string(file.get_as_text())
        if typeof(arr) == TYPE_ARRAY:
            for item in arr:
                items[item.get("id","" )] = item

func get_item(id:String) -> Dictionary:
    return items.get(id, {})

func random_item_by_type(typ:String) -> Dictionary:
    var filtered: Array = []
    for item in items.values():
        if item.get("type","") == typ:
            filtered.append(item)
    if filtered.is_empty():
        return {}
    filtered.shuffle()
    return filtered[0]
