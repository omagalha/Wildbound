class_name WeaponDefinition
extends Resource
## Dados de uma arma corpo a corpo (Ancestral Powers 4.3). Nenhuma lógica aqui.

@export var id: StringName = &"improvised_club"
@export var display_name: String = "Clava improvisada"
@export var damage: float = 12.0
@export var reach: float = 1.8
## Arco total do golpe à frente do personagem, em graus.
@export var arc_degrees: float = 90.0
## Intervalo mínimo entre golpes (preparação + golpe ativo + recuperação).
@export var interval: float = 0.6
@export var windup: float = 0.15
@export var active_time: float = 0.1
## Se houver inimigo até esta distância num cone de assist_cone_degrees, vira para ele.
@export var assist_distance: float = 2.5
@export var assist_cone_degrees: float = 60.0
## Empurrão aplicado ao alvo atingido (m/s).
@export var knockback: float = 3.0
