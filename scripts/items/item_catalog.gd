class_name ItemCatalog
extends Resource
## Lista dos itens conhecidos pelo jogo. Sem lógica além de busca por id.

@export var items: Array[ItemDefinition] = []


func get_item(id: StringName) -> ItemDefinition:
	for item in items:
		if item != null and item.id == id:
			return item
	return null


func has_item(id: StringName) -> bool:
	return get_item(id) != null
