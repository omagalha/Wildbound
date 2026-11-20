class_name HungerComponent
extends Node
## Fome de 0 a 100, consumida por tempo (GDD 006).
##
## Não causa dano: quem transforma fome zero em dano é o StarvationDamage.
## O consumo usa delta do passo de física, então independe da taxa de quadros,
## e para naturalmente quando a árvore está pausada.

signal hunger_changed(current: float, maximum: float)
signal starving_started
signal starving_ended

@export var max_hunger: float = 100.0
## Pontos por minuto no Intermediário (multiplicador 1).
@export var base_rate_per_minute: float = 1.0
## Multiplicador do preset de dificuldade (Fácil 0,6 · Intermediário 1 · Difícil 1,5 · Hardcore 2).
@export var difficulty_multiplier: float = 1.0
## Multiplicador de depuração para acelerar testes manuais (não é um preset).
@export var debug_multiplier: float = 1.0
## Se false, a fome não diminui (jogador morto, carregamento).
@export var active: bool = true

var current_hunger: float = 0.0
var _starving := false


func _ready() -> void:
	current_hunger = max_hunger


func _physics_process(delta: float) -> void:
	tick(delta)


## Avança o consumo de fome por [param delta] segundos.
func tick(delta: float) -> void:
	if not active or delta <= 0.0 or current_hunger <= 0.0:
		return
	var rate_per_second := base_rate_per_minute * difficulty_multiplier * debug_multiplier / 60.0
	set_hunger(current_hunger - rate_per_second * delta)


func set_hunger(value: float) -> void:
	var clamped := clampf(value, 0.0, max_hunger)
	# Comparação exata de propósito: a 60 passos/s a fome muda ~0,0003 por passo,
	# abaixo da tolerância de is_equal_approx — com ela, a fome nunca diminuía.
	if clamped == current_hunger:
		return
	var previous := int(current_hunger)
	current_hunger = clamped
	# O HUD só precisa saber quando o valor inteiro muda.
	if int(current_hunger) != previous or current_hunger <= 0.0 or current_hunger >= max_hunger:
		hunger_changed.emit(current_hunger, max_hunger)
	_update_starving()


func is_starving() -> bool:
	return current_hunger <= 0.0


func is_full() -> bool:
	return current_hunger >= max_hunger


func ratio() -> float:
	return current_hunger / max_hunger if max_hunger > 0.0 else 0.0


## Soma fome sem passar do máximo. Devolve quanto foi recuperado.
func restore(amount: float) -> float:
	var before := current_hunger
	set_hunger(current_hunger + amount)
	return current_hunger - before


func _update_starving() -> void:
	var now_starving := is_starving()
	if now_starving == _starving:
		return
	_starving = now_starving
	if _starving:
		starving_started.emit()
	else:
		starving_ended.emit()
