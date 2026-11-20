class_name DifficultySettings
extends Resource
## Preset de dificuldade (GDD 006): só dados. Uma única lógica de sobrevivência
## consulta estes multiplicadores; cada um é aplicado em um único ponto.

## Id estável salvo com o mundo: easy, intermediate, hard, hardcore.
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Versão dos valores, salva com o mundo para auditoria (P-SV-05).
@export var version: int = 1
@export var hunger_multiplier: float = 1.0
@export var enemy_damage_multiplier: float = 1.0
@export var enemy_health_multiplier: float = 1.0
@export var resource_multiplier: float = 1.0
@export var exploration_reward_multiplier: float = 1.0
## Morte permanente (só o Hardcore oficial, versão 1.0).
@export var permadeath: bool = false
## Preset marcado como experimental (Hardcore no MVP).
@export var experimental: bool = false
@export var death_rules: DeathRules
