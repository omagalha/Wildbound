class_name NightHunt
extends Node3D
## Perigo noturno: matilhas de Lobos Sombrios caçam o jogador à noite.
##
## - Pouco depois do anoitecer, uma matilha surge na mata, longe da vista
##   (entre [member spawn_min_distance] e [member spawn_max_distance]).
##   Novas matilhas vêm a cada [member wave_interval] s, até [member max_alive].
## - Os lobos temem o fogo: tocha acesa ou fogueira por perto e eles não atacam.
## - Zonas seguras continuam seguras (regra comum das criaturas hostis).
## - Ao amanhecer, todos recuam e somem. Nada disso é salvo: ao carregar à
##   noite, a caçada recomeça sozinha.

signal pack_spawned(count: int)
signal wolves_dismissed(count: int)

@export var day_night: DayNightCycle
@export var player: CharacterBody3D
@export var difficulty: DifficultyManager
@export var wolf_scene: PackedScene
@export var hud: SurvivalHUD
@export var enabled: bool = true
## Segundos de noite antes da primeira matilha.
@export var first_wave_delay: float = 20.0
@export var wave_interval: float = 75.0
@export var max_alive: int = 4
@export var spawn_min_distance: float = 30.0
@export var spawn_max_distance: float = 42.0
## Metade do lado do mapa (lobos não nascem fora dele).
@export var map_half_size: float = 140.0
## Tamanho da matilha por preset de dificuldade.
@export var pack_size_by_preset: Dictionary = {&"easy": 1, &"intermediate": 2, &"hard": 3, &"hardcore": 3}

var _night_time := 0.0
var _since_wave := 0.0
var _waves := 0
var _was_night := false
var _check_left := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func _physics_process(delta: float) -> void:
	tick(delta)


## Avança a caçada (separado para testes).
func tick(delta: float) -> void:
	if not enabled or day_night == null:
		return
	var night := day_night.is_night()
	if night and not _was_night:
		_night_time = 0.0
		_since_wave = 0.0
		_waves = 0
		_say("A noite caiu… algo se move entre as árvores. Fique perto do fogo.")
	elif not night and _was_night:
		var gone := dismiss_all()
		if gone > 0:
			_say("Amanheceu. Os lobos recuam para a floresta.")
	_was_night = night
	if not night:
		return
	_night_time += delta
	_since_wave += delta
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = 1.0
	var due := (_waves == 0 and _night_time >= first_wave_delay) or (_waves > 0 and _since_wave >= wave_interval)
	if due and alive_count() < max_alive:
		spawn_pack()


func wolves() -> Array[HostileCreature]:
	var out: Array[HostileCreature] = []
	for child in get_children():
		if child is HostileCreature and not (child as HostileCreature).is_dead() and not child.is_queued_for_deletion():
			out.append(child)
	return out


func alive_count() -> int:
	return wolves().size()


func pack_size() -> int:
	var id: StringName = difficulty.current.id if difficulty != null and difficulty.current != null else &"intermediate"
	return int(pack_size_by_preset.get(id, 2))


## Solta uma matilha perto (mas fora de vista) do jogador. Devolve quantos nasceram.
func spawn_pack() -> int:
	if wolf_scene == null or player == null:
		return 0
	var room := max_alive - alive_count()
	var count := mini(pack_size(), room)
	if count <= 0:
		return 0
	var center := _spawn_center()
	for i in count:
		var wolf := wolf_scene.instantiate() as HostileCreature
		wolf.player = player
		var offset := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / count) * 1.6
		wolf.position = center + offset - global_position
		add_child(wolf)
		wolf.home = wolf.global_position
		if difficulty != null and difficulty.current != null:
			wolf.apply_multipliers(difficulty.current.enemy_damage_multiplier, difficulty.current.enemy_health_multiplier)
	_waves += 1
	_since_wave = 0.0
	pack_spawned.emit(count)
	if _waves == 1:
		_say("Uivos ao longe…")
	return count


## Remove todos os lobos (amanhecer). Devolve quantos havia.
func dismiss_all() -> int:
	var count := 0
	for child in get_children():
		if child is HostileCreature:
			count += 1
			child.queue_free()
	if count > 0:
		wolves_dismissed.emit(count)
	return count


## Ponto na mata a uma distância do jogador, dentro do mapa e fora de zona segura e do fogo.
func _spawn_center() -> Vector3:
	var origin := player.global_position
	var best := origin + Vector3(spawn_max_distance, 0, 0)
	for attempt in 16:
		var angle := _rng.randf() * TAU
		var dist := _rng.randf_range(spawn_min_distance, spawn_max_distance)
		var p := origin + Vector3(cos(angle), 0, sin(angle)) * dist
		p.x = clampf(p.x, -map_half_size, map_half_size)
		p.z = clampf(p.z, -map_half_size, map_half_size)
		var terrain := IslandTerrain.find(get_tree())
		p.y = (terrain.height_at(p.x, p.z) if terrain != null else 0.0) + 0.3
		if terrain != null and terrain.is_water(p.x, p.z):
			continue
		best = p
		if TerritoryZone.is_safe(get_tree(), p) or FireLight.is_point_lit(get_tree(), p, 3.0):
			continue
		return p
	return best


func _say(text: String) -> void:
	if hud != null:
		hud.show_message(text, 4.0)
