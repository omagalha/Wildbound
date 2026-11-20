class_name EnergyComponent
extends Node
## Energia mágica compartilhada (ANCESTRAL_POWERS.md 5): gasto e regeneração
## (6/s, começando 1 s depois do último gasto). Ataques com arma não gastam.

signal energy_changed(current: float, maximum: float)

@export var max_energy: float = 100.0
@export var regen_per_second: float = 6.0
@export var regen_delay: float = 1.0

var current_energy: float = 100.0
var _delay_left := 0.0


func _ready() -> void:
	current_energy = max_energy


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if _delay_left > 0.0:
		_delay_left -= delta
		return
	if current_energy < max_energy:
		current_energy = minf(current_energy + regen_per_second * delta, max_energy)
		energy_changed.emit(current_energy, max_energy)


func has(amount: float) -> bool:
	return current_energy + 0.001 >= amount


## Gasta se houver. Devolve true se gastou.
func spend(amount: float) -> bool:
	if not has(amount):
		return false
	current_energy -= amount
	_delay_left = regen_delay
	energy_changed.emit(current_energy, max_energy)
	return true


func refill(ratio: float = 1.0) -> void:
	current_energy = clampf(max_energy * ratio, 0.0, max_energy)
	energy_changed.emit(current_energy, max_energy)
