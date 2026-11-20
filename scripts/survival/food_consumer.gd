class_name FoodConsumer
extends Node
## Come um alimento do inventário com a ação "eat" (GDD 006, seção 4).
##
## Recusas nunca consomem o item: fome cheia, sem comida, intervalo ativo
## ou personagem morto.

signal eat_result(ok: bool, reason: StringName, item: ItemDefinition)

const ACTION_EAT := &"eat"
const REASON_OK := &"ok"
const REASON_FULL := &"full"
const REASON_NO_ITEM := &"no_item"
const REASON_COOLDOWN := &"cooldown"
const REASON_DEAD := &"dead"

@export var inventory: Inventory
@export var hunger: HungerComponent
@export var health: HealthComponent
## Intervalo mínimo entre refeições, em segundos.
@export var cooldown: float = 1.0

var _cooldown_left := 0.0


func _physics_process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - delta, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION_EAT):
		try_eat()
		get_viewport().set_input_as_handled()


## Tenta comer o primeiro alimento disponível. Devolve o motivo.
func try_eat() -> StringName:
	var reason := _validate()
	var item: ItemDefinition = inventory.first_food() if inventory != null else null
	if reason == REASON_OK and item == null:
		reason = REASON_NO_ITEM
	if reason != REASON_OK:
		eat_result.emit(false, reason, item)
		return reason
	inventory.remove_item(item.id, 1)
	hunger.restore(item.food_value)
	_cooldown_left = cooldown
	eat_result.emit(true, REASON_OK, item)
	return REASON_OK


func _validate() -> StringName:
	if health != null and health.is_dead():
		return REASON_DEAD
	if _cooldown_left > 0.0:
		return REASON_COOLDOWN
	if hunger == null or hunger.is_full():
		return REASON_FULL
	return REASON_OK
