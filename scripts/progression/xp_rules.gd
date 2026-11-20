class_name XPRules
extends Resource
## Valores de XP e limites anti-repetição (PROGRESSION.md 2.2). Só dados.

@export var collect_xp_per_unit: int = 1
## Máximo de XP de coleta por tipo de recurso dentro da janela.
@export var collect_cap_per_type: int = 20
## Janela da limitação de coleta, em segundos de jogo.
@export var collect_window_seconds: float = 600.0
## Primeira construção de cada tipo de peça.
@export var first_build_xp: int = 30
## Primeira fabricação de cada receita (crafting ainda não existe).
@export var first_recipe_xp: int = 25
## Primeira descoberta de uma região / ponto de interesse.
@export var discovery_xp: int = 50
## Primeira domesticação de cada espécie.
@export var tame_species_xp: int = 100
## Conclusão de desafio ancestral.
@export var challenge_xp: int = 150
