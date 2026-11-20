class_name AbilityDefinition
extends Resource
## Dados de uma habilidade ancestral (ANCESTRAL_POWERS.md 4). Sem lógica.

@export var id: StringName = &""
@export var display_name: String = ""
## "fire", "nature"... (afinidade; só informativa no MVP).
@export var affinity: StringName = &""
## &"projectile" ou &"heal".
@export var effect: StringName = &""
@export var energy_cost: float = 20.0
@export var cooldown: float = 3.0
## Dano (projétil) ou cura (heal).
@export var power: float = 25.0
## Projétil: alcance (m) e velocidade (m/s).
@export var projectile_range: float = 15.0
@export var projectile_speed: float = 20.0
@export var color: Color = Color(1, 0.55, 0.15)
## Começa liberada (Pulso Vital). Falso: precisa de desbloqueio (conhecimento "ability_<id>").
@export var starts_unlocked: bool = false
