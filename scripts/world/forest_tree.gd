class_name ForestTree
extends StaticBody3D
## Árvore viva da floresta procedural. Só cai com machado na mão e cliques.
##
## Cada golpe soma a força de corte do machado (chop_power); com
## [member toughness] pontos a árvore cai e dá madeira. Machados melhores
## derrubam em menos golpes e, com harvest_bonus, rendem mais.
## Não esgota nem é salva: depois de derrubada, precisa de [member regrow_time]
## segundos para render de novo (só na sessão). Sem get_resource_category,
## o Instinto Selvagem não a sinaliza (há centenas).

const WOOD := &"wood"

@export var wood_per_fell: int = 3
## Pontos de corte para derrubar (machado de pedra: 3 golpes).
@export var toughness: int = 3
@export var regrow_time: float = 240.0
## Sem golpes por este tempo, o corte recomeça do zero.
@export var progress_timeout: float = 12.0

var hits := 0
var _ready_at_msec: int = 0
var _last_hit_msec: int = 0


func get_interaction_prompt() -> String:
	return "Cortar árvore" if is_ready() else "Árvore cortada (volta a render)"


func get_interaction_prompt_for(_interactor: InteractionDetector) -> String:
	if not is_ready():
		return "Árvore cortada (volta a render)"
	_expire_progress()
	return "[Clique] Cortar árvore" + (" (%d/%d)" % [hits, toughness] if hits > 0 else "")


## Só vira alvo do aviso com um machado na mão (são centenas de árvores).
func can_interact(interactor: InteractionDetector) -> bool:
	return interactor != null and accepts_tool(interactor.held_tool)


func accepts_tool(tool: WeaponDefinition) -> bool:
	return tool != null and tool.chop_power > 0


func is_ready() -> bool:
	return Time.get_ticks_msec() >= _ready_at_msec


func interact(_interactor: InteractionDetector) -> Dictionary:
	return {"ok": false, "message": "Clique para cortar com o machado"}


## Um golpe de machado. Devolve o resultado (madeira só quando a árvore cai).
func tool_strike(interactor: InteractionDetector, tool: WeaponDefinition) -> Dictionary:
	if not accepts_tool(tool):
		return {"ok": false, "message": "Precisa de um machado na mão"}
	var inventory: Inventory = interactor.inventory if interactor != null else null
	if inventory == null:
		return {"ok": false, "message": "Sem inventário"}
	if not is_ready():
		return {"ok": false, "message": "Esta árvore já foi cortada; volte mais tarde"}
	_expire_progress()
	hits += tool.chop_power
	_last_hit_msec = Time.get_ticks_msec()
	if hits < toughness:
		return {"ok": true, "message": "Cortando… %d/%d" % [hits, toughness], "progress": hits}
	var amount := wood_per_fell + tool.harvest_bonus
	if not inventory.add_item(WOOD, amount):
		hits = toughness - 1
		return {"ok": false, "message": "Inventário cheio"}
	hits = 0
	_ready_at_msec = Time.get_ticks_msec() + int(regrow_time * 1000.0)
	return {"ok": true, "message": "Árvore derrubada! +%d Madeira" % amount, "item_id": WOOD, "amount": amount, "felled": true}


func _expire_progress() -> void:
	if hits > 0 and Time.get_ticks_msec() - _last_hit_msec > int(progress_timeout * 1000.0):
		hits = 0
