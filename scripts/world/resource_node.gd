class_name ResourceNode
extends StaticBody3D
## Fonte de recurso coletável no mundo: árvore seca, pedra, fibra, arbusto de frutas.
##
## Cumpre o contrato de interativo do InteractionDetector e o contrato de
## recurso detectável do Wild Companions (get_resource_category + depleted).
## Fica nas camadas 1 (world, colide com jogador e câmera) e 3 (resources).
##
## Cada coleta entrega [member amount_per_harvest] unidades. Depois de
## [member max_harvests] coletas, a fonte se esgota e volta após [member regrow_time].
## Se o inventário não comportar a coleta inteira, nada é consumido.

signal harvested(item_id: StringName, amount: int)
signal depleted
signal regrown

@export var item: ItemDefinition
@export var amount_per_harvest: int = 2
@export var max_harvests: int = 4
## Segundos de jogo até voltar depois de esgotar. 0 = não volta.
@export var regrow_time: float = 120.0
## Categoria para o Instinto Selvagem: "wood", "stone", "fiber" ou "fruit".
@export var category: StringName = &"wood"
## Verbo exibido no aviso de interação.
@export var action_verb: String = "Coletar"
## Nó visual reduzido quando esgotado.
@export var visual: Node3D
## Unidades extras por coleta quando o jogador tem a ferramenta da categoria.
@export var tool_bonus: int = 2
## Ferramenta que aumenta a coleta de cada categoria.
const TOOLS := {&"wood": &"stone_axe", &"stone": &"stone_pickaxe"}
## Multiplicador de recursos do preset (injetado pelo DifficultyManager).
var yield_multiplier: float = 1.0
## Gerador para o arredondamento probabilístico; injetável para testes determinísticos.
var rng := RandomNumberGenerator.new()

var harvests_left: int = 0
var _regrow_left := 0.0


func _ready() -> void:
	harvests_left = max_harvests
	_update_visual()


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if harvests_left > 0 or regrow_time <= 0.0:
		return
	_regrow_left -= delta
	if _regrow_left <= 0.0:
		harvests_left = max_harvests
		_update_visual()
		regrown.emit()


func get_resource_category() -> StringName:
	return category


func is_depleted() -> bool:
	return harvests_left <= 0


func get_interaction_prompt() -> String:
	var item_name := item.display_name if item != null else "?"
	return "%s %s" % [action_verb, item_name]


func can_interact(_interactor: InteractionDetector) -> bool:
	return item != null and not is_depleted()


func interact(interactor: InteractionDetector) -> Dictionary:
	if not can_interact(interactor):
		return {"ok": false, "message": "Esgotado"}
	var inventory: Inventory = interactor.inventory if interactor != null else null
	if inventory == null:
		return {"ok": false, "message": "Sem inventário"}
	var amount := roll_amount()
	var used_tool := tool_for(inventory)
	if used_tool != &"":
		amount += tool_bonus
	if not inventory.add_item(item.id, amount):
		return {"ok": false, "message": "Inventário cheio"}
	harvests_left -= 1
	harvested.emit(item.id, amount)
	if is_depleted():
		_regrow_left = regrow_time
		_update_visual()
		depleted.emit()
	var message := "+%d %s" % [amount, item.display_name]
	if used_tool != &"":
		var tool_item := inventory.catalog.get_item(used_tool) if inventory.catalog != null else null
		message += " (%s)" % (tool_item.display_name if tool_item != null else String(used_tool))
	return {"ok": true, "message": message, "item_id": item.id, "amount": amount, "tool": used_tool}


## A ferramenta do inventário que melhora esta fonte, ou &"" se nenhuma.
func tool_for(inventory: Inventory) -> StringName:
	var tool: StringName = TOOLS.get(category, &"")
	if tool != &"" and inventory != null and inventory.has_item(tool):
		return tool
	return &""


## Quantidade de uma coleta com o multiplicador do preset (SURVIVAL_DIFFICULTY.md 2.3):
## parte inteira + 1 com probabilidade igual à parte fracionária. Mínimo de 1.
func roll_amount() -> int:
	var exact := amount_per_harvest * yield_multiplier
	var whole := int(floor(exact))
	if rng.randf() < exact - whole:
		whole += 1
	return maxi(whole, 1)


func get_save_data() -> Dictionary:
	return {"harvests_left": harvests_left, "regrow_left": _regrow_left}


func apply_save_data(data: Dictionary) -> void:
	harvests_left = clampi(int(data.get("harvests_left", max_harvests)), 0, max_harvests)
	_regrow_left = maxf(float(data.get("regrow_left", 0.0)), 0.0)
	_update_visual()


func _update_visual() -> void:
	if visual != null:
		visual.scale = Vector3.ONE * (0.35 if is_depleted() else 1.0)
