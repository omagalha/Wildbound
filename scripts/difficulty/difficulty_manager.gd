class_name DifficultyManager
extends Node
## Guarda o preset do mundo e o entrega a quem precisa (GDD 006). Sem autoload.
##
## Escolhido ao criar o mundo e salvo com ele; não muda durante a partida.
## Pontos de aplicação (um por multiplicador): fome no HungerComponent, coleta nas
## fontes de recurso, regras de morte no respawn. Dano e vida de inimigos virão
## com o combate.

signal settings_applied(settings: DifficultySettings)
signal selection_requested

@export var presets: Array[DifficultySettings] = []
@export var default_preset_id: StringName = &"intermediate"
## Ao criar um mundo novo, pedir a escolha ao jogador (tela de dificuldade).
@export var ask_on_new_world: bool = true
@export var hunger: HungerComponent
@export var respawn: SimpleRespawn
## Descendentes ResourceNode recebem o multiplicador de recursos.
@export var resources_root: Node
@export var save_manager: SaveManager
## Criaturas hostis (HostileCreature) recebem os multiplicadores de dano e vida.
@export var enemies_root: Node

var current: DifficultySettings = null
var _chosen := false


func _ready() -> void:
	apply(get_preset(default_preset_id))
	if save_manager != null:
		save_manager.load_status.connect(_on_load_status)


func get_preset(id: StringName) -> DifficultySettings:
	for preset in presets:
		if preset != null and preset.id == id:
			return preset
	return null


func is_chosen() -> bool:
	return _chosen


## Aplica um preset em todos os pontos. Devolve false se o preset não existe.
func apply(settings: DifficultySettings) -> bool:
	if settings == null:
		return false
	current = settings
	if hunger != null:
		hunger.difficulty_multiplier = settings.hunger_multiplier
	if respawn != null:
		respawn.death_rules = settings.death_rules
	if resources_root != null:
		for node in resources_root.find_children("*", "ResourceNode", true, false):
			(node as ResourceNode).yield_multiplier = settings.resource_multiplier
	if enemies_root != null:
		for node in enemies_root.find_children("*", "HostileCreature", true, false):
			(node as HostileCreature).apply_multipliers(settings.enemy_damage_multiplier, settings.enemy_health_multiplier)
	settings_applied.emit(settings)
	return true


## Escolha feita na criação do mundo (uma vez). Grava imediatamente.
func choose(id: StringName) -> bool:
	if _chosen or not apply(get_preset(id)):
		return false
	_chosen = true
	if save_manager != null:
		save_manager.save_game()
	return true


## Restaurado pelo save: o preset do mundo não muda depois de criado.
func restore(id: StringName) -> void:
	if apply(get_preset(id)) or apply(get_preset(default_preset_id)):
		_chosen = true


func get_save_data() -> Dictionary:
	return {"preset_id": String(current.id) if current != null else "", "version": current.version if current != null else 0}


func _on_load_status(status: StringName) -> void:
	if status != SaveManager.STATUS_LOADED and not _chosen:
		if ask_on_new_world:
			selection_requested.emit()
		else:
			choose(default_preset_id)
