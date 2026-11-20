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
## Ferramenta exigida para a coleta completa: &"axe", &"pickaxe" ou &"" (nenhuma).
## Vazio usa o padrão da categoria (madeira -> machado, pedra -> picareta).
@export var tool_kind: StringName = &""
## Com ferramenta exigida, quanto a coleta à mão ([E]) rende.
@export var hand_amount: int = 1
## Verbo da coleta à mão ("Juntar galhos", "Pegar pedrinhas").
@export var hand_verb: String = ""
## Força mínima da ferramenta (minérios melhores pedem picaretas melhores).
@export var min_tool_power: int = 1
## Item extra que às vezes sai nos golpes de ferramenta (sílex nas pedras).
@export var bonus_item: ItemDefinition
## Chance do item extra por golpe, somada a 10% por ponto de força acima de 1.
@export_range(0.0, 1.0) var bonus_chance: float = 0.0
const DEFAULT_TOOLS := {&"wood": &"axe", &"stone": &"pickaxe"}
const TOOL_VERBS := {&"axe": "Cortar", &"pickaxe": "Quebrar"}
const TOOL_NAMES := {&"axe": "um machado", &"pickaxe": "uma picareta"}
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
	if required_tool() != &"" and hand_verb != "":
		return hand_verb
	return "%s %s" % [action_verb, item_name]


## Aviso conforme o que o jogador segura: com a ferramenta certa, pede o clique.
func get_interaction_prompt_for(interactor: InteractionDetector) -> String:
	if accepts_tool(interactor.held_tool if interactor != null else null):
		return "[Clique] %s %s" % [TOOL_VERBS.get(required_tool(), action_verb), item.display_name if item != null else "?"]
	return get_interaction_prompt()


## Ferramenta que esta fonte pede (&"axe", &"pickaxe" ou &"").
func required_tool() -> StringName:
	return tool_kind if tool_kind != &"" else DEFAULT_TOOLS.get(category, &"")


## A ferramenta [param tool] serve para esta fonte?
func accepts_tool(tool: WeaponDefinition) -> bool:
	if tool == null or is_depleted():
		return false
	match required_tool():
		&"axe": return tool.chop_power >= min_tool_power
		&"pickaxe": return tool.mine_power >= min_tool_power
	return false


func can_interact(_interactor: InteractionDetector) -> bool:
	return item != null and not is_depleted()


func interact(interactor: InteractionDetector) -> Dictionary:
	if not can_interact(interactor):
		return {"ok": false, "message": "Esgotado"}
	var inventory: Inventory = interactor.inventory if interactor != null else null
	if inventory == null:
		return {"ok": false, "message": "Sem inventário"}
	var tool := required_tool()
	if tool != &"" and accepts_tool(interactor.held_tool):
		return {"ok": false, "message": "Clique para %s" % TOOL_VERBS.get(tool, "coletar").to_lower()}
	var amount := roll_amount() if tool == &"" else maxi(hand_amount, 1)
	var result := _harvest(inventory, amount, "")
	if result["ok"] and tool != &"":
		result["message"] += "  ·  com %s rende mais" % TOOL_NAMES.get(tool, "ferramenta")
	return result


## Golpe de ferramenta (clique com machado/picareta na mão): coleta completa + bônus.
func tool_strike(interactor: InteractionDetector, tool: WeaponDefinition) -> Dictionary:
	if not accepts_tool(tool):
		return {"ok": false, "message": ""}
	var inventory: Inventory = interactor.inventory if interactor != null else null
	if inventory == null:
		return {"ok": false, "message": "Sem inventário"}
	var result := _harvest(inventory, roll_amount() + tool.harvest_bonus, tool.display_name)
	if result["ok"] and bonus_item != null:
		var power := maxi(tool.mine_power, tool.chop_power)
		if rng.randf() < bonus_chance + 0.1 * (power - 1) and inventory.add_item(bonus_item.id, 1):
			result["message"] += "  ·  +1 %s!" % bonus_item.display_name
			result["bonus_item"] = bonus_item.id
	return result


func _harvest(inventory: Inventory, amount: int, tool_name: String) -> Dictionary:
	if not inventory.add_item(item.id, amount):
		return {"ok": false, "message": "Inventário cheio"}
	harvests_left -= 1
	harvested.emit(item.id, amount)
	if is_depleted():
		_regrow_left = regrow_time
		_update_visual()
		depleted.emit()
	var message := "+%d %s" % [amount, item.display_name]
	if tool_name != "":
		message += " (%s)" % tool_name
	return {"ok": true, "message": message, "item_id": item.id, "amount": amount}


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
