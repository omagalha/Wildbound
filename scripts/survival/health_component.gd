class_name HealthComponent
extends Node
## Vida compartilhada por jogador, criaturas e companheiros (GDD 004/006).
##
## Não decide o que acontece na morte: só informa. Quem é dono decide
## (respawn, incapacitação, memorial do Hardcore).

signal health_changed(current: float, maximum: float)
signal damaged(info: DamageInfo)
signal died(cause: StringName)
signal revived(current: float)

@export var max_health: float = 100.0
## Se false, todo dano é ignorado (proteção de carregamento, por exemplo).
@export var accepts_damage: bool = true

var current_health: float = 0.0
var _dead := false


func _ready() -> void:
	current_health = max_health


func is_dead() -> bool:
	return _dead


func ratio() -> float:
	return current_health / max_health if max_health > 0.0 else 0.0


## Aplica um pacote de dano. Devolve o dano efetivamente aplicado.
func apply_damage(info: DamageInfo) -> float:
	if info == null or not info.is_valid():
		push_error("HealthComponent: pacote de dano sem valor ou sem causa foi recusado.")
		return 0.0
	if _dead or not accepts_damage:
		return 0.0
	var applied := minf(info.amount, current_health)
	current_health -= applied
	damaged.emit(info)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		current_health = 0.0
		_dead = true
		died.emit(info.cause)
	return applied


## Cura sem passar do máximo. Devolve a cura aplicada. Mortos não são curados.
func heal(amount: float) -> float:
	if _dead or amount <= 0.0:
		return 0.0
	var applied := minf(amount, max_health - current_health)
	if applied > 0.0:
		current_health += applied
		health_changed.emit(current_health, max_health)
	return applied


## Volta à vida com a vida informada (respawn). Só funciona se estiver morto.
func revive(health: float) -> void:
	if not _dead:
		return
	_dead = false
	current_health = clampf(health, 1.0, max_health)
	revived.emit(current_health)
	health_changed.emit(current_health, max_health)
