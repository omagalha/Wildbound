class_name Inventory
extends Node
## Inventário mínimo por pilhas (WLD-006).
##
## Guarda quantidades por id de item. A capacidade é medida em espaços:
## cada espaço comporta até [member ItemDefinition.max_stack] unidades de um item.
## Todas as operações são atômicas: ou acontecem por inteiro, ou nada muda.

signal changed

## Itens que este inventário aceita.
@export var catalog: ItemCatalog
## Número de espaços (provisório — pendência P-DR-07).
@export_range(1, 200) var capacity: int = 20

var _counts: Dictionary = {}  # StringName -> int


func count(id: StringName) -> int:
	return _counts.get(id, 0)


func has_item(id: StringName, amount: int = 1) -> bool:
	return amount > 0 and count(id) >= amount


func get_all() -> Dictionary:
	return _counts.duplicate()


func used_slots() -> int:
	var total := 0
	for id in _counts:
		total += _slots_for(id, _counts[id])
	return total


func free_slots() -> int:
	return capacity - used_slots()


## Quantas unidades deste item ainda cabem.
func space_for(id: StringName) -> int:
	var item := _definition(id)
	if item == null:
		return 0
	var current: int = count(id)
	var room_in_current_slots := _slots_for(id, current) * item.max_stack - current
	return room_in_current_slots + free_slots() * item.max_stack


func can_add(id: StringName, amount: int) -> bool:
	return amount > 0 and space_for(id) >= amount


## Adiciona tudo ou nada. Devolve true se adicionou.
func add_item(id: StringName, amount: int) -> bool:
	if not can_add(id, amount):
		return false
	_counts[id] = count(id) + amount
	changed.emit()
	return true


## Remove tudo ou nada. Devolve true se removeu.
func remove_item(id: StringName, amount: int = 1) -> bool:
	if not has_item(id, amount):
		return false
	var remaining := count(id) - amount
	if remaining == 0:
		_counts.erase(id)
	else:
		_counts[id] = remaining
	changed.emit()
	return true


## true se há todas as quantidades de {id: quantidade}.
func has_all(costs: Dictionary) -> bool:
	for id in costs:
		if not has_item(id, int(costs[id])):
			return false
	return true


## true se todas as quantidades de {id: quantidade} cabem juntas.
func can_add_all(amounts: Dictionary) -> bool:
	var simulated := _counts.duplicate()
	for id in amounts:
		var amount := int(amounts[id])
		if amount <= 0:
			continue
		if _definition(id) == null:
			return false
		simulated[id] = simulated.get(id, 0) + amount
	var slots := 0
	for id in simulated:
		slots += _slots_for(id, simulated[id])
	return slots <= capacity


## Remove várias quantidades de uma vez: tudo ou nada.
func remove_all(costs: Dictionary) -> bool:
	if not has_all(costs):
		return false
	for id in costs:
		var amount := int(costs[id])
		if amount <= 0:
			continue
		var remaining := count(id) - amount
		if remaining == 0:
			_counts.erase(id)
		else:
			_counts[id] = remaining
	changed.emit()
	return true


## Adiciona várias quantidades de uma vez: tudo ou nada.
func add_all(amounts: Dictionary) -> bool:
	if not can_add_all(amounts):
		return false
	var any := false
	for id in amounts:
		var amount := int(amounts[id])
		if amount > 0:
			_counts[id] = count(id) + amount
			any = true
	if any:
		changed.emit()
	return true


## Substitui todo o conteúdo (usado ao carregar o save). Ids fora do catálogo são ignorados.
func load_counts(data: Dictionary) -> void:
	_counts.clear()
	for id in data:
		var amount := int(data[id])
		if amount > 0 and _definition(StringName(id)) != null:
			_counts[StringName(id)] = amount
	changed.emit()


## Adiciona o quanto couber (recuperação parcial). Devolve quanto foi adicionado.
func add_up_to(id: StringName, amount: int) -> int:
	var fits := mini(amount, space_for(id))
	if fits <= 0:
		return 0
	_counts[id] = count(id) + fits
	changed.emit()
	return fits


## Primeiro item de comida disponível (ordem do catálogo), ou null.
func first_food() -> ItemDefinition:
	if catalog == null:
		return null
	for item in catalog.items:
		if item != null and item.is_food() and has_item(item.id):
			return item
	return null


func _definition(id: StringName) -> ItemDefinition:
	if catalog == null:
		push_warning("Inventory: sem catálogo; item '%s' recusado." % id)
		return null
	return catalog.get_item(id)


func _slots_for(id: StringName, amount: int) -> int:
	if amount <= 0:
		return 0
	var item := _definition(id)
	var stack := item.max_stack if item != null else 1
	return int(ceil(float(amount) / float(stack)))
