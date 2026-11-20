class_name TamingProfile
extends Resource
## Dados da domesticação por confiança (Caminho A). Valores do Wild Bond 5.2/5.3.

@export var max_trust: float = 100.0
@export var preferred_foods: Array[StringName] = [&"wild_berries"]
@export var preferred_gain: float = 25.0
@export var acceptable_foods: Array[StringName] = []
@export var acceptable_gain: float = 10.0
## Medo somado por segundo enquanto o jogador corre dentro do raio de alerta.
@export var aggressive_fear: float = 35.0
## Intervalo mínimo entre dois acréscimos de medo por aproximação agressiva.
@export var aggressive_interval: float = 1.0
## Confiança perdida cada vez que a criatura entra em fuga.
@export var scare_trust_penalty: float = 10.0
## Acima deste medo a criatura foge.
@export var flee_threshold: float = 70.0
## Só aceita comida com medo igual ou abaixo deste valor.
@export var accept_fear_max: float = 30.0
## Medo perdido por segundo quando ninguém a assusta.
@export var fear_decay_per_second: float = 5.0
@export var feed_cooldown: float = 8.0
@export var interaction_distance: float = 2.5
@export var alert_radius: float = 8.0
