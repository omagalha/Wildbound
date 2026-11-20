class_name EnemyDefinition
extends Resource
## Dados de uma criatura hostil (Territory Raids 3.4 + combate do MVP). Sem lógica.

@export var species_id: StringName = &"spiny_boar"
@export var display_name: String = "Javali Espinhoso"
@export var max_health: float = 60.0
@export var wander_speed: float = 1.5
@export var chase_speed: float = 4.5
@export var charge_speed: float = 11.0
@export var home_radius: float = 6.0
@export var perception_radius: float = 18.0
## Mais longe do ninho que isto, desiste e volta (leash).
@export var leash_radius: float = 35.0
## Sem o jogador por perto por este tempo, esquece o alvo.
@export var forget_time: float = 8.0
## Aviso antes da investida (bufa e raspa o chão).
@export var telegraph_time: float = 0.8
@export var charge_damage: float = 15.0
@export var charge_hit_radius: float = 1.3
@export var charge_max_time: float = 1.6
## Investe de longe; perto, prefere morder.
@export var bite_range: float = 2.2
@export var bite_damage: float = 8.0
@export var bite_windup: float = 0.5
## Parado e vulnerável depois de investir.
@export var recover_time: float = 1.2
## Atordoado mais tempo ao bater numa parede.
@export var wall_stun_time: float = 2.0
@export var respawn_time: float = 90.0
## Itens deixados no chão ao morrer: id -> quantidade.
@export var loot: Dictionary = {}
