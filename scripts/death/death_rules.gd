class_name DeathRules
extends Resource
## Regras de morte de um preset (GDD 008). Um único fluxo de morte usa estes dados.
## O Hardcore oficial (1.0) não usa estas regras: tem fluxo próprio (GDD 007).

## Itens do inventário vão para a Mochila de Recuperação.
@export var drop_carried_items: bool = false
## Equipamento vestido também vai para a mochila (ainda não há equipamento no MVP).
@export var drop_equipped_items: bool = false
@export_range(0.0, 1.0) var respawn_health_ratio: float = 1.0
@export_range(0.0, 1.0) var respawn_hunger_ratio: float = 0.75
## Energia mágica ainda não existe; guardado para o combate (GDD 004).
@export_range(0.0, 1.0) var respawn_energy_ratio: float = 1.0
## Exaustão (Difícil, versão 1.0) — sem efeito no MVP.
@export var exhaustion_enabled: bool = false
