class_name ForestTree
extends StaticBody3D
## Árvore viva da floresta procedural. Com um machado, dá madeira.
##
## Não esgota nem é salva: depois de cortada, precisa de [member regrow_time]
## segundos para render madeira de novo (só na sessão atual). Não tem
## get_resource_category, então o Instinto Selvagem não a sinaliza (há
## centenas delas; ele continua apontando as fontes de recurso de verdade).

const AXE := &"stone_axe"
const WOOD := &"wood"

@export var wood_per_chop: int = 3
@export var regrow_time: float = 240.0

var _ready_at_msec: int = 0


func get_interaction_prompt() -> String:
	return "Cortar árvore" if is_ready() else "Árvore cortada (volta a render)"


func can_interact(_interactor: InteractionDetector) -> bool:
	return true


func is_ready() -> bool:
	return Time.get_ticks_msec() >= _ready_at_msec


func interact(interactor: InteractionDetector) -> Dictionary:
	var inventory: Inventory = interactor.inventory if interactor != null else null
	if inventory == null:
		return {"ok": false, "message": "Sem inventário"}
	if not inventory.has_item(AXE):
		return {"ok": false, "message": "Precisa de um Machado de pedra (fabrique com [C])"}
	if not is_ready():
		return {"ok": false, "message": "Esta árvore já foi cortada; volte mais tarde"}
	if not inventory.add_item(WOOD, wood_per_chop):
		return {"ok": false, "message": "Inventário cheio"}
	_ready_at_msec = Time.get_ticks_msec() + int(regrow_time * 1000.0)
	return {"ok": true, "message": "+%d Madeira (Machado de pedra)" % wood_per_chop, "item_id": WOOD, "amount": wood_per_chop}
