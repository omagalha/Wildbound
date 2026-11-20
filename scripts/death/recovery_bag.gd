class_name RecoveryBag
extends StaticBody3D
## Mochila de Recuperação (GDD 008): guarda os itens deixados na morte.
##
## Não some com o tempo, não deteriora, não é destruída por inimigos e persiste
## no save. Interagir recupera o que couber no inventário (recuperação parcial);
## o resto fica. Vazia, ela se remove.
## Fica só na camada 3 (interativos): o jogador não tropeça nela, mas a encontra.

signal emptied(bag: RecoveryBag)
signal items_recovered(recovered: int, remaining: int)

var bag_id: StringName = &""
var contents: Dictionary = {}  # StringName -> int


func total_items() -> int:
	var total := 0
	for id in contents:
		total += int(contents[id])
	return total


func add_contents(items: Dictionary) -> void:
	for id in items:
		var amount := int(items[id])
		if amount > 0:
			contents[StringName(id)] = int(contents.get(StringName(id), 0)) + amount


func get_interaction_prompt() -> String:
	return "Recuperar mochila (%d itens)" % total_items()


func can_interact(_interactor: InteractionDetector) -> bool:
	return total_items() > 0


func interact(interactor: InteractionDetector) -> Dictionary:
	var inventory: Inventory = interactor.inventory if interactor != null else null
	if inventory == null:
		return {"ok": false, "message": "Sem inventário"}
	var recovered := 0
	for id in contents.keys():
		var moved := inventory.add_up_to(id, int(contents[id]))
		recovered += moved
		var left := int(contents[id]) - moved
		if left <= 0:
			contents.erase(id)
		else:
			contents[id] = left
	var remaining := total_items()
	items_recovered.emit(recovered, remaining)
	if remaining == 0:
		emptied.emit(self)
		queue_free()
		return {"ok": true, "message": "Mochila recuperada (+%d itens)" % recovered}
	if recovered == 0:
		return {"ok": false, "message": "Inventário cheio — a mochila continua aqui"}
	return {"ok": true, "message": "+%d itens; restam %d na mochila" % [recovered, remaining]}
