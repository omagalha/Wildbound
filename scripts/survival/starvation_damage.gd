class_name StarvationDamage
extends Node
## Transforma fome zero em dano periódico (GDD 006).
##
## Dano em intervalos fixos, nunca a cada quadro. O primeiro tique acontece
## um intervalo depois de a fome chegar a zero. Usa o pacote de dano comum.
## Também pausa a fome enquanto o dono estiver morto.

@export var hunger: HungerComponent
@export var health: HealthComponent
@export var damage_per_tick: float = 2.0
@export var tick_interval: float = 5.0

var _elapsed := 0.0


func _ready() -> void:
	if health != null:
		health.died.connect(_on_died)
		health.revived.connect(_on_revived)
	if hunger != null:
		hunger.starving_started.connect(_reset_timer)
		hunger.starving_ended.connect(_reset_timer)


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if hunger == null or health == null or health.is_dead() or not hunger.is_starving():
		return
	_elapsed += delta
	# Pequena folga para o acúmulo de ponto flutuante não "perder" um tique (59,9999 s ≠ 60 s).
	while _elapsed + 0.0001 >= tick_interval and not health.is_dead():
		_elapsed -= tick_interval
		health.apply_damage(DamageInfo.create(damage_per_tick, DamageInfo.CAUSE_STARVATION, &"starvation", owner))


func _reset_timer() -> void:
	_elapsed = 0.0


func _on_died(_cause: StringName) -> void:
	_reset_timer()
	if hunger != null:
		hunger.active = false


func _on_revived(_current: float) -> void:
	_reset_timer()
	if hunger != null:
		hunger.active = true
