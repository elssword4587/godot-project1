extends Node

var traits := {}

func _ready():
    load_traits()

func load_traits():
    var file := FileAccess.open("res://data/traits.json", FileAccess.READ)
    if file:
        traits.clear()
        var arr = JSON.parse_string(file.get_as_text())
        if typeof(arr) == TYPE_ARRAY:
            for trait in arr:
                traits[trait.get("id", "")] = trait

func get_trait(id: String) -> Dictionary:
    return traits.get(id, {})

func random_trait_ids(count:int=2) -> Array:
    var keys = traits.keys()
    keys.shuffle()
    return keys.slice(0, count)
