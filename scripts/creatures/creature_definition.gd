class_name CreatureDefinition
extends Resource
## Dados de uma espécie. Nenhuma lógica aqui.

@export var species_id: StringName = &"lumaru"
@export var display_name: String = "Lumaru"
@export var walk_speed: float = 2.0
@export var flee_speed: float = 7.0
## Raio da área de origem onde a criatura vaga.
@export var home_radius: float = 10.0
## Distância que tenta abrir do jogador ao fugir.
@export var flee_distance: float = 15.0
## A fuga nunca passa desta distância do centro da área.
@export var flee_max_from_home: float = 25.0
@export var max_health: float = 50.0
## Conhecimento exigido para domesticar (categoria I = vínculo inicial, nível 1).
@export var required_knowledge: StringName = &"knowledge_initial_bond"
@export var taming: TamingProfile
## Companheiro: começa a andar acima disto e para abaixo de follow_stop_distance.
@export var follow_start_distance: float = 3.5
@export var follow_stop_distance: float = 2.5
## Mais longe que isto por 2 s, ou preso, reaparece atrás do jogador.
@export var recover_distance: float = 20.0
